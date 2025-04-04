"""
Book processing service for the BookableU application.

This module handles all book processing operations including:
- Text extraction from PDF/EPUB files
- Text chunking
- Vector search and semantic querying
- File storage and retrieval
"""

import os
import pickle
import asyncio
import logging
import tempfile
from io import BytesIO
from typing import List, Optional
from concurrent.futures import ThreadPoolExecutor
import numpy as np
import faiss
from fastapi import HTTPException
import fitz  # PyMuPDF
from ebooklib import epub
from sklearn.feature_extraction.text import TfidfVectorizer
from openai import AsyncOpenAI
from sqlalchemy.orm import Session

from app.models import Book, User
from app.schemas import BookStatus
from app.services.s3_service import upload_fileobj_to_s3
from app.config import settings

# Configure logger
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Constants for file handling
ALLOWED_EXTENSIONS = {".pdf", ".epub"}
MAX_FILE_SIZE = 20 * 1024 * 1024  # 20MB
EXTRACTION_TIMEOUT = 60  # 1 minute timeout for text extraction

# Create a thread pool for parallel processing
thread_pool = ThreadPoolExecutor(max_workers=4)

# Simple cache for processed texts
text_cache = {}

def chunk_text(text: str, chunk_size: int = 500) -> List[str]:
    """
    Split the full text into chunks of approximately 'chunk_size' words.
    
    Args:
        text (str): The full text to be chunked
        chunk_size (int): Target number of words per chunk
        
    Returns:
        List[str]: List of text chunks
    """
    logger.debug("Starting chunking of text.")
    words = text.split()
    chunks = []
    for i in range(0, len(words), chunk_size):
        chunk = " ".join(words[i:i+chunk_size])
        chunks.append(chunk)
    logger.debug(f"Created {len(chunks)} chunks from text.")
    return chunks

async def extract_text(file_obj: BytesIO, filename: str) -> str:
    """
    Extract text from a PDF or EPUB file.
    
    Args:
        file_obj (BytesIO): The file object to process
        filename (str): Name of the file (used to determine format)
        
    Returns:
        str: Extracted text content
        
    Raises:
        HTTPException: If text extraction fails or file format is unsupported
    """
    file_obj.seek(0)
    logger.debug(f"Starting text extraction for file: {filename}")
    
    # Check cache first
    cache_key = f"{filename}_{hash(file_obj.getvalue())}"
    if cache_key in text_cache:
        logger.debug(f"Using cached text for {filename}")
        return text_cache[cache_key]
    
    if filename.endswith(".pdf"):
        try:
            # Save to temporary file for PyMuPDF to process
            with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as temp_file:
                temp_file.write(file_obj.read())
                temp_pdf_path = temp_file.name
            
            text = ""
            try:
                # Use PyMuPDF to extract text - much faster than pdfminer
                pdf_document = fitz.open(temp_pdf_path)
                
                # Process pages in parallel for large documents
                page_count = len(pdf_document)
                
                if page_count > 10:  # Only use parallel processing for larger documents
                    # Extract text from pages in parallel
                    loop = asyncio.get_event_loop()
                    
                    def extract_page_text(page_num):
                        page = pdf_document.load_page(page_num)
                        return page.get_text()
                    
                    # Process pages in batches to avoid too many threads
                    batch_size = min(10, page_count)
                    text_parts = []
                    
                    for i in range(0, page_count, batch_size):
                        batch_end = min(i + batch_size, page_count)
                        batch_futures = [
                            loop.run_in_executor(thread_pool, extract_page_text, page_num)
                            for page_num in range(i, batch_end)
                        ]
                        batch_results = await asyncio.gather(*batch_futures)
                        text_parts.extend(batch_results)
                    
                    text = "".join(text_parts)
                else:
                    # For smaller documents, process sequentially
                    for page_num in range(page_count):
                        page = pdf_document.load_page(page_num)
                        text += page.get_text()
                    
                pdf_document.close()
                logger.debug(f"Completed PDF text extraction for {filename} (length: {len(text)} characters)")
                
                # Store in cache
                text_cache[cache_key] = text
                
                return text or ""
            finally:
                # Clean up temporary file
                if os.path.exists(temp_pdf_path):
                    os.remove(temp_pdf_path)
                    
        except Exception as e:
            logger.error(f"PDF text extraction failed for {filename}: {str(e)}", exc_info=True)
            raise HTTPException(status_code=500, detail="Text extraction failed")
            
    elif filename.endswith(".epub"):
        book = epub.read_epub(file_obj)
        text = "\n".join(
            item.get_content().decode("utf-8", errors="ignore")
            for item in book.get_items_of_type(epub.ITEM_DOCUMENT)
        )
        logger.debug(f"Completed EPUB text extraction for {filename} (length: {len(text)} characters)")
        
        # Store in cache
        text_cache[cache_key] = text
        
        return text
        
    logger.error(f"Unsupported file format for file: {filename}")
    raise HTTPException(status_code=400, detail="Unsupported file format")

async def process_book(
    file_content: bytes,
    file_key: str,
    text_key: str,
    filename: str,
    user_id: int,
    author: Optional[str],
    total_pages: Optional[int],
    db: Session
):
    """
    Background task to process an uploaded book.
    
    This function handles the complete book processing pipeline:
    1. Uploads the original file to S3
    2. Extracts text from the file
    3. Chunks the text for efficient retrieval
    4. Generates TF-IDF vectors for semantic search
    5. Builds a FAISS index for similarity search
    6. Uploads processed data to S3
    7. Updates the database entry
    
    Args:
        file_content (bytes): Raw file content
        file_key (str): S3 key for the original file
        text_key (str): S3 key for the extracted text
        filename (str): Original filename
        user_id (int): ID of the user who uploaded the book
        author (Optional[str]): Book author if provided
        total_pages (Optional[int]): Total number of pages if provided
        db (Session): Database session
    """
    try:
        logger.info(f"Starting background processing for book: {filename} (user_id={user_id})")
        
        # Upload the original file to S3
        file_io = BytesIO(file_content)
        content_type = "application/pdf" if filename.lower().endswith('.pdf') else "application/epub+zip" if filename.lower().endswith('.epub') else None
        await upload_fileobj_to_s3(file_io, settings.BUCKET_NAME, file_key, content_type=content_type)
        logger.debug(f"Uploaded original file to S3 with key: {file_key}")
        
        # Extract text from the file
        file_io_for_extraction = BytesIO(file_content)
        text = await extract_text(file_io_for_extraction, filename)
        logger.debug(f"Extracted text from {filename} (length: {len(text)} characters)")
        
        # Get actual page count for PDFs if not provided
        detected_pages = None
        if filename.endswith('.pdf'):
            with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as temp_file:
                temp_file.write(file_content)
                temp_pdf_path = temp_file.name
            
            try:
                # Use PyMuPDF to get page count
                pdf_document = fitz.open(temp_pdf_path)
                detected_pages = len(pdf_document)
                pdf_document.close()
                logger.debug(f"Detected {detected_pages} pages in PDF: {filename}")
            finally:
                if os.path.exists(temp_pdf_path):
                    os.remove(temp_pdf_path)
        
        # Chunk the text
        chunks = chunk_text(text, chunk_size=500)
        logger.debug(f"Created {len(chunks)} text chunks from extracted content")
        
        # Create TF-IDF vectors for each chunk
        vectorizer = TfidfVectorizer(max_features=1000)
        tfidf_matrix = vectorizer.fit_transform(chunks)
        logger.debug("Created TF-IDF vectors for text chunks")
        
        # Convert TF-IDF matrix to numpy array for FAISS
        embeddings = tfidf_matrix.toarray().astype(np.float32)
        
        # Build a FAISS index from the embeddings
        dimension = embeddings.shape[1]
        index = faiss.IndexFlatL2(dimension)
        index.add(embeddings)
        logger.debug("Built FAISS index for embeddings")
        
        # Save the FAISS index to a temporary file and upload to S3
        index_file_path = f"/tmp/{filename}_index.faiss"
        faiss.write_index(index, index_file_path)
        logger.debug(f"Saved FAISS index to temporary file: {index_file_path}")
        
        with open(index_file_path, "rb") as index_file:
            index_content = index_file.read()
        index_key = f"users/{user_id}/{os.path.splitext(filename)[0]}_index.faiss"
        index_io = BytesIO(index_content)
        await upload_fileobj_to_s3(index_io, settings.BUCKET_NAME, index_key, content_type="application/octet-stream")
        logger.debug(f"Uploaded FAISS index to S3 with key: {index_key}")
        
        # Clean up temporary file
        os.remove(index_file_path)
        logger.debug(f"Removed temporary file: {index_file_path}")
        
        # Save the vectorizer for later use
        vectorizer_data = pickle.dumps(vectorizer)
        vectorizer_key = f"users/{user_id}/{os.path.splitext(filename)[0]}_vectorizer.pkl"
        vectorizer_io = BytesIO(vectorizer_data)
        await upload_fileobj_to_s3(vectorizer_io, settings.BUCKET_NAME, vectorizer_key, content_type="application/octet-stream")
        logger.debug(f"Uploaded vectorizer to S3 with key: {vectorizer_key}")
        
        # Also store chunks in S3 for efficient retrieval during queries
        chunks_data = pickle.dumps(chunks)
        chunks_key = f"users/{user_id}/{os.path.splitext(filename)[0]}_chunks.pkl"
        chunks_io = BytesIO(chunks_data)
        await upload_fileobj_to_s3(chunks_io, settings.BUCKET_NAME, chunks_key, content_type="application/octet-stream")
        logger.debug(f"Uploaded chunked text to S3 with key: {chunks_key}")
        
        # Upload the extracted text to S3
        text_io = BytesIO(text.encode("utf-8"))
        await upload_fileobj_to_s3(text_io, settings.BUCKET_NAME, text_key, content_type="text/plain")
        logger.debug(f"Uploaded extracted text to S3 with key: {text_key}")
        
        # Update the book entry in the database
        book = db.query(Book).filter(Book.user_id == user_id, Book.file_key == file_key).first()
        if book:
            # Use detected page count if available and total_pages wasn't provided
            if detected_pages and (not total_pages or total_pages == 0):
                book.total_pages = detected_pages
                logger.debug(f"Updated total_pages to {detected_pages} for {filename}")
            
            book.book_metadata = {
                "extracted": True, 
                "index_key": index_key,
                "vectorizer_key": vectorizer_key,
                "chunks_key": chunks_key,
                "num_chunks": len(chunks)
            }
            book.status = BookStatus.UNREAD
            db.commit()
            logger.info(f"Processed book: {filename} (user_id={user_id}) and updated DB entry")
        else:
            logger.warning(f"Book with file_key={file_key} not found in DB for user_id={user_id}")
    except Exception as e:
        logger.error(f"Failed processing {filename}: {str(e)}", exc_info=True)
        db.rollback()

def generate_unique_keys(base_filename: str, user_id: int, db: Session) -> tuple[str, str]:
    """
    Generate unique S3 keys for file storage by appending a number if needed.
    
    Args:
        base_filename (str): Original filename
        user_id (int): ID of the user
        db (Session): Database session
        
    Returns:
        tuple[str, str]: Tuple containing (file_key, text_key)
    """
    base_name, ext = os.path.splitext(base_filename)
    file_key = f"users/{user_id}/{base_filename}"
    text_key = f"users/{user_id}/{base_name}_text.txt"
    counter = 1

    while db.query(Book).filter(Book.user_id == user_id, Book.file_key == file_key).first():
        file_key = f"users/{user_id}/{base_name}{counter}{ext}"
        text_key = f"users/{user_id}/{base_name}{counter}_text.txt"
        counter += 1
    
    logger.debug(f"Generated unique keys: file_key={file_key}, text_key={text_key}")
    return file_key, text_key

async def generate_chat_answer(query: str, context_chunks: List[str], book: Book = None, user: User = None) -> str:
    """
    Generate a chat-like answer using the retrieved document chunks as context.
    
    This function uses OpenAI's API to generate contextual responses based on the book content
    and user preferences for response style.
    
    Args:
        query (str): The user's question
        context_chunks (List[str]): Relevant text chunks from the book
        book (Book, optional): The book being queried
        user (User, optional): The user making the query
        
    Returns:
        str: Generated response based on the context and user preferences
    """
    client = AsyncOpenAI()  # Ensure your API key is set in the environment or config
    
    # Join context chunks with clear separators
    context = "\n\n---\n\n".join(context_chunks)
    
    # Get user-specific preferences if available, otherwise use defaults
    model = settings.OPENAI_MODEL
    temperature = settings.OPENAI_TEMPERATURE
    max_tokens = settings.OPENAI_MAX_TOKENS
    instruction_style = settings.BOOK_QUERY_INSTRUCTION_STYLE.lower()
    
    # Override with user preferences if available
    if user and user.preferences and "llm" in user.preferences:
        user_llm_prefs = user.preferences["llm"]
        
        if "model" in user_llm_prefs:
            model = user_llm_prefs["model"]
            
        if "temperature" in user_llm_prefs:
            temperature = user_llm_prefs["temperature"]
            
        if "max_tokens" in user_llm_prefs:
            max_tokens = user_llm_prefs["max_tokens"]
            
        if "instruction_style" in user_llm_prefs:
            instruction_style = user_llm_prefs["instruction_style"]
    
    # Define different instruction styles
    instruction_styles = {
        "academic": (
            "You are a scholarly assistant analyzing literary texts. "
            "Your answers should be: "
            "\n- Precise and well-researched, with careful analysis"
            "\n- Structured with clear arguments and evidence from the text"
            "\n- Properly contextualized with relevant literary or historical background"
            "\n- Include direct quotes when relevant, properly attributed"
            "\n- Academic in tone but still accessible"
            "\n- Clear about limitations when the text doesn't provide sufficient information"
        ),
        "casual": (
            "You are a friendly book club discussion leader. "
            "Your answers should be: "
            "\n- Conversational and engaging"
            "\n- Easy to understand with minimal jargon"
            "\n- Include interesting observations from the text"
            "\n- Sometimes pose thought-provoking questions"
            "\n- Honest about when you don't have enough information"
            "\n- Focus on the most interesting and relevant points"
        ),
        "concise": (
            "You are a direct and efficient research assistant. "
            "Your answers should be: "
            "\n- Brief and to the point"
            "\n- Focused only on the most relevant information"
            "\n- Use bullet points when appropriate"
            "\n- Avoid unnecessary elaboration"
            "\n- Clear when information is limited or unavailable"
            "\n- Prioritize accuracy over thoroughness"
        )
    }
    
    # Get the appropriate system prompt based on style, with fallback to default
    system_prompt = instruction_styles.get(
        instruction_style, 
        instruction_styles["academic"]  # Default to academic if style not found
    )
    
    # Include book information if available
    book_info = ""
    if book:
        book_info = f"Book Information:\n"
        if book.title:
            book_info += f"- Title: {book.title}\n"
        if book.author:
            book_info += f"- Author: {book.author}\n"
        if book.current_page and book.total_pages:
            book_info += f"- Reading Progress: Page {book.current_page} of {book.total_pages}\n"
        book_info += "\n"
    
    user_prompt = (
        f"{book_info}Here are relevant excerpts from the book:\n\n{context}\n\n"
        f"Question: {query}"
    )
    
    response = await client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=temperature,
        max_tokens=max_tokens,
        top_p=0.9,
        presence_penalty=0.1,
    )
    
    return response.choices[0].message.content
