"""
Book management routes for the BookableU application.

This module handles all book-related operations including:
- Uploading and processing books (PDF/EPUB)
- Text extraction and chunking
- Vector search and semantic querying
- Book metadata management
- Reading progress tracking
- File storage and retrieval
"""

import os
import pickle
import logging
import tempfile
from typing import List, Optional
from concurrent.futures import ThreadPoolExecutor
import numpy as np
import faiss
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, BackgroundTasks
from sqlalchemy.orm import Session

from app.models import Book, User
from app.schemas import BookOut, BookStatus, QueryResult
from app.dependencies import get_db, get_current_user
from app.services.s3_service import generate_presigned_url, download_fileobj_from_s3, delete_object
from app.config import settings
from app.services.book_service import (
    ALLOWED_EXTENSIONS,
    MAX_FILE_SIZE,
    process_book,
    generate_unique_keys,
    generate_chat_answer
)

# Configure logger
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Initialize router with books prefix and tags
router = APIRouter(prefix="/books", tags=["books"])

# Create a thread pool for parallel processing
thread_pool = ThreadPoolExecutor(max_workers=4)

@router.post("/upload", response_model=BookOut)
async def upload_book(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    author: Optional[str] = Form(None),
    total_pages: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Upload a new book to the system.
    
    This endpoint handles the initial upload of a book file (PDF/EPUB),
    creates a database entry, and initiates background processing.
    
    Args:
        background_tasks (BackgroundTasks): FastAPI background tasks handler
        file (UploadFile): The book file to upload
        author (Optional[str]): Book author if provided
        total_pages (Optional[str]): Total number of pages if provided
        current_user (User): Current authenticated user
        db (Session): Database session
        
    Returns:
        BookOut: The created book entry
        
    Raises:
        HTTPException: If file format is invalid or size exceeds limit
    """
    logger.info(f"Received upload request for file: {file.filename} (user_id={current_user.id})")
    
    if not any(file.filename.endswith(ext) for ext in ALLOWED_EXTENSIONS):
        logger.warning(f"Invalid file extension for {file.filename}. Allowed: {ALLOWED_EXTENSIONS}")
        raise HTTPException(status_code=400, detail="Only PDF or EPUB files allowed")
    if file.size > MAX_FILE_SIZE:
        logger.warning(f"File {file.filename} exceeds size limit: {file.size} > {MAX_FILE_SIZE} bytes")
        raise HTTPException(status_code=400, detail="File size exceeds 20MB limit")

    # Convert total_pages to integer if provided
    total_pages_int = None
    if total_pages:
        try:
            total_pages_int = int(total_pages)
        except ValueError:
            logger.warning(f"Invalid total_pages value: {total_pages}")
            raise HTTPException(status_code=400, detail="total_pages must be a valid integer")

    # Generate unique file_key and text_key
    file_key, text_key = generate_unique_keys(file.filename, current_user.id, db)
    
    logger.debug(f"Reading file content for {file.filename}")
    file_content = await file.read()
    logger.debug(f"File content read (size: {len(file_content)} bytes)")
    
    # Create a new book entry in the database
    book = Book(
        user_id=current_user.id,
        title=os.path.splitext(file.filename)[0],
        author=author,
        file_key=file_key,
        text_key=text_key,
        total_pages=total_pages_int,
        status=BookStatus.PROCESSING
    )
    
    try:
        db.add(book)
        db.commit()
        db.refresh(book)
        logger.info(f"Created book entry in database: {book.id}")
        
        # Add background task to process the book
        background_tasks.add_task(
            process_book,
            file_content=file_content,
            file_key=file_key,
            text_key=text_key,
            filename=file.filename,
            user_id=current_user.id,
            author=author,
            total_pages=total_pages_int,
            db=db
        )
        
        return book
    except Exception as e:
        logger.error(f"Failed to create book entry: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create book entry")

@router.get("", response_model=List[BookOut])
async def list_books(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 10
):
    """
    List books owned by the current user.
    
    Args:
        current_user (User): Current authenticated user
        db (Session): Database session
        skip (int): Number of records to skip (for pagination)
        limit (int): Maximum number of records to return
        
    Returns:
        List[BookOut]: List of books owned by the user
        
    Raises:
        HTTPException: If database query fails
    """
    logger.info(f"Listing books for user_id={current_user.id} (skip={skip}, limit={limit})")
    try:
        books = db.query(Book).filter(Book.user_id == current_user.id).offset(skip).limit(limit).all()
        logger.info(f"Listed {len(books)} books for user_id={current_user.id}")
        return books
    except Exception as e:
        logger.error(f"Failed to list books for user_id={current_user.id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to retrieve books")

@router.get("/download/{book_id}", response_model=dict)
async def download_book(
    book_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Generate a presigned URL for downloading a book.
    
    Args:
        book_id (int): ID of the book to download
        current_user (User): Current authenticated user
        db (Session): Database session
        
    Returns:
        dict: Dictionary containing the download URL
        
    Raises:
        HTTPException: If book not found or URL generation fails
    """
    logger.info(f"Download request received for book_id={book_id} (user_id={current_user.id})")
    book = db.query(Book).filter(Book.id == book_id, Book.user_id == current_user.id).first()
    if not book:
        logger.warning(f"Book not found for book_id={book_id} (user_id={current_user.id})")
        raise HTTPException(status_code=404, detail="Book not found")
    
    try:
        url = await generate_presigned_url(settings.BUCKET_NAME, book.file_key)
        logger.info(f"Generated download URL for book_id={book_id}")
        return {"download_url": url}
    except Exception as e:
        logger.error(f"Failed to generate download URL for book_id={book_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to generate download URL")
    
@router.delete("/{book_id}", response_model=BookOut)
async def delete_book(
    book_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete a book and its associated files.
    
    This endpoint deletes both the database entry and all associated files from S3.
    Only the book owner can delete their books.
    
    Args:
        book_id (int): ID of the book to delete
        current_user (User): Current authenticated user
        db (Session): Database session
        
    Returns:
        BookOut: The deleted book entry
        
    Raises:
        HTTPException: If book not found or deletion fails
    """
    # Get the book and verify ownership
    book = db.query(Book).filter(Book.id == book_id, Book.user_id == current_user.id).first()
    if not book:
        raise HTTPException(
            status_code=404,
            detail="Book not found or you don't have permission to delete it"
        )

    try:
        # Delete associated files from S3 if they exist
        if book.file_key:
            await delete_object(settings.BUCKET_NAME, book.file_key)
        if book.text_key:
            await delete_object(settings.BUCKET_NAME, book.text_key)

        # Delete the book from database
        db.delete(book)
        db.commit()

        logger.info(f"Book {book_id} deleted successfully by user {current_user.id}")
        return book

    except Exception as e:
        db.rollback()
        logger.error(f"Error deleting book {book_id}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Failed to delete book"
        )

@router.put("/{book_id}", response_model=BookOut)
async def update_book(
    book_id: int,
    status: BookStatus = Form(...),
    current_page: int = Form(0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update a book's reading status and progress.
    
    Args:
        book_id (int): ID of the book to update
        status (BookStatus): New reading status
        current_page (int): Current page number
        current_user (User): Current authenticated user
        db (Session): Database session
        
    Returns:
        BookOut: The updated book entry
        
    Raises:
        HTTPException: If book not found or update fails
    """
    logger.info(f"Update request for book_id={book_id} (user_id={current_user.id}), status={status}, current_page={current_page}")
    book = db.query(Book).filter(Book.id == book_id, Book.user_id == current_user.id).first()
    if not book:
        logger.warning(f"Book not found for book_id={book_id} (user_id={current_user.id})")
        raise HTTPException(status_code=404, detail="Book not found")

    try:
        was_finished = book.status == BookStatus.FINISHED
        book.status = status
        book.current_page = max(0, current_page)

        if status == BookStatus.FINISHED and not was_finished:
            current_user.books_finished += 1
            logger.debug(f"Incremented books_finished for user_id={current_user.id} to {current_user.books_finished}")

        db.commit()
        db.refresh(book)
        logger.info(f"Updated book_id={book_id} (user_id={current_user.id}) to status={status} with current_page={book.current_page}")
        return book
    except Exception as e:
        logger.error(f"Failed to update book_id={book_id}: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to update book")

@router.get("/query/{book_id}", response_model=dict)
async def query_book(
    book_id: int,
    query: str,
    no_spoilers: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Query a book's content using semantic search and generate a contextual response.
    
    This endpoint performs the following steps:
    1. Retrieves relevant text chunks using FAISS similarity search
    2. Filters out spoilers if requested
    3. Generates a contextual response using OpenAI's API
    
    Args:
        book_id (int): ID of the book to query
        query (str): The user's question
        no_spoilers (bool): Whether to avoid content beyond current reading progress
        current_user (User): Current authenticated user
        db (Session): Database session
        
    Returns:
        dict: Dictionary containing search results and generated response
        
    Raises:
        HTTPException: If book not found or query processing fails
    """
    try:
        # Get the book and verify ownership - more explicit check
        book = db.query(Book).filter(Book.id == book_id, Book.user_id == current_user.id).first()
        if not book:
            logger.warning(f"Book not found for book_id={book_id} (user_id={current_user.id})")
            raise HTTPException(
                status_code=404, 
                detail="Book not found or you don't have permission to access it"
            )
        
        if not book.book_metadata.get("extracted"):
            raise HTTPException(status_code=400, detail="Book text not yet extracted")
        
        # Download the necessary files from S3
        index_key = book.book_metadata["index_key"]
        vectorizer_key = book.book_metadata["vectorizer_key"]
        chunks_key = book.book_metadata["chunks_key"]
        
        # Download and load the vectorizer
        vectorizer_data = await download_fileobj_from_s3(settings.BUCKET_NAME, vectorizer_key)
        vectorizer = pickle.loads(vectorizer_data.read())
        
        # Transform the query using the same vectorizer
        query_vector = vectorizer.transform([query]).toarray().astype(np.float32)
        
        # Download and load the FAISS index
        index_data = await download_fileobj_from_s3(settings.BUCKET_NAME, index_key)
        
        # Save to temporary file and load the index
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            temp_file.write(index_data.read())
            temp_file_path = temp_file.name
        
        try:
            # Load the FAISS index
            index = faiss.read_index(temp_file_path)
            
            # Search for similar chunks
            k = min(5, len(chunks))  # Get top 5 chunks or less if fewer chunks exist
            distances, indices = index.search(query_vector, k)
            
            # Download and load the chunks
            chunks_data = await download_fileobj_from_s3(settings.BUCKET_NAME, chunks_key)
            chunks = pickle.loads(chunks_data.read())
            
            # Get the relevant chunks
            relevant_chunks = [chunks[i] for i in indices[0]]
            
            # Filter out spoilers if requested
            if no_spoilers and book.current_page and book.total_pages:
                # Calculate approximate chunk boundaries based on current page
                current_chunk = int((book.current_page / book.total_pages) * len(chunks))
                relevant_chunks = [chunk for i, chunk in enumerate(relevant_chunks) if indices[0][i] <= current_chunk]
            
            # Generate response using the relevant chunks
            response = await generate_chat_answer(query, relevant_chunks, book, current_user)
            
            return {
                "response": response,
                "chunks": [
                    QueryResult(
                        text=chunk,
                        similarity_score=float(distances[0][i]),
                        chunk_index=int(indices[0][i])
                    )
                    for i, chunk in enumerate(relevant_chunks)
                ]
            }
            
        finally:
            # Clean up temporary file
            if os.path.exists(temp_file_path):
                os.remove(temp_file_path)
                
    except Exception as e:
        logger.error(f"Failed to process query for book_id={book_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to process query")

@router.get("/{book_id}", response_model=BookOut)
async def get_book(
    book_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get a specific book by ID.
    
    Args:
        book_id (int): ID of the book to retrieve
        current_user (User): Current authenticated user
        db (Session): Database session
        
    Returns:
        BookOut: The requested book entry
        
    Raises:
        HTTPException: If book not found or access is denied
    """
    logger.info(f"Fetching book_id={book_id} for user_id={current_user.id}")
    
    # Get the book and verify ownership
    book = db.query(Book).filter(Book.id == book_id, Book.user_id == current_user.id).first()
    if not book:
        logger.warning(f"Book not found for book_id={book_id} (user_id={current_user.id})")
        raise HTTPException(
            status_code=404,
            detail="Book not found or you don't have permission to access it"
        )
    
    # Add reading progress percentage if total_pages is available
    if book.total_pages > 0:
        book.book_metadata = book.book_metadata or {}
        book.book_metadata["reading_progress"] = round((book.current_page / book.total_pages) * 100, 1)
    
    logger.info(f"Successfully retrieved book_id={book_id} for user_id={current_user.id}")
    return book