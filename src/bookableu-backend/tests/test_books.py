"""
Tests for book-related endpoints in the Bookableu application.
This module contains test cases for the book management functionality including:
- Retrieving all books for a user
- Downloading individual books
- Uploading new books
"""
import os
import uuid
from fastapi.testclient import TestClient
from app.models import Book, User, BookStatus
from app.dependencies import get_current_user
from datetime import datetime, timezone

def test_get_books(client: TestClient, db_session, monkeypatch):
    """
    Test the GET /books endpoint that retrieves all books for the authenticated user.
    
    This test:
    1. Cleans the database to ensure a clean test state
    2. Creates a test user with necessary attributes
    3. Adds a sample book to the user's collection
    4. Overrides the authentication to simulate a logged-in user
    5. Makes the API request and verifies the response
    
    Expected response:
    - Status code: 200
    - Response body: List of books (at least one book)
    """
    # Clear existing data
    db_session.query(Book).delete()
    db_session.query(User).delete()
    db_session.commit()
    
    # Create test user
    test_user = User(
        id=uuid.uuid4(),
        email="test@example.com",
        password_hash="test_hash",
        name="Test User",
        profile_picture=None,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        preferences={},
        books_finished=0
    )
    db_session.add(test_user)
    db_session.commit()
    
    # Add a test book to ensure there's at least one
    book = Book(
        user_id=test_user.id,
        title="Test Book",
        file_key="test.pdf",
        text_key="test.txt",
        author="Test Author",
        total_pages=100,
        current_page=0,
        status=BookStatus.UNREAD,
        book_metadata={},
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    db_session.add(book)
    db_session.commit()
    
    # Override authentication dependency
    async def override_get_current_user():
        return db_session.query(User).filter_by(id=test_user.id).first()
    
    from app.main import app
    app.dependency_overrides[get_current_user] = override_get_current_user
    
    try:
        response = client.get("/books")
        assert response.status_code == 200
        assert isinstance(response.json(), list)
        assert len(response.json()) > 0
    finally:
        del app.dependency_overrides[get_current_user]

def test_download_book(client: TestClient, db_session, monkeypatch):
    """
    Test the GET /books/download/{book_id} endpoint for downloading a specific book.
    
    This test:
    1. Sets up a clean test environment
    2. Creates a test user and a sample book
    3. Simulates user authentication
    4. Attempts to download the book and verifies the response
    
    Expected response:
    - Status code: 200
    - Response body: Contains a 'download_url' for the book
    """
    # Clear existing data
    db_session.query(Book).delete()
    db_session.query(User).delete()
    db_session.commit()
    
    # Create test user
    test_user = User(
        id=uuid.uuid4(),
        email="test@example.com",
        password_hash="test_hash",
        name="Test User",
        profile_picture=None,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        preferences={},
        books_finished=0
    )
    db_session.add(test_user)
    db_session.commit()
    
    # Create a test book
    book = Book(
        user_id=test_user.id,
        title="Test Book",
        file_key="test.pdf",
        text_key="test.txt",
        author="Test Author",
        total_pages=100,
        current_page=0,
        status=BookStatus.UNREAD,
        book_metadata={},
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    db_session.add(book)
    db_session.commit()
    
    # Override authentication dependency
    async def override_get_current_user():
        return db_session.query(User).filter_by(id=test_user.id).first()
    
    from app.main import app
    app.dependency_overrides[get_current_user] = override_get_current_user
    
    try:
        response = client.get(f"/books/download/{book.id}")
        assert response.status_code == 200
        assert "download_url" in response.json()
    finally:
        del app.dependency_overrides[get_current_user]

def test_upload_book(client: TestClient, db_session, monkeypatch):
    """
    Test the POST /books/upload endpoint for uploading new books.
    
    This test:
    1. Prepares a clean test environment
    2. Creates a test user
    3. Creates a temporary PDF file for testing
    4. Simulates user authentication
    5. Uploads the test file with book metadata
    6. Verifies the response and cleans up temporary files
    
    Expected response:
    - Status code: 200
    - Response body: Contains book details including 'id' and 'title'
    
    Note: The test creates and removes a temporary PDF file during execution.
    """
    # Clear existing data
    db_session.query(Book).delete()
    db_session.query(User).delete()
    db_session.commit()
    
    # Create test user
    test_user = User(
        id=uuid.uuid4(),
        email="test@example.com",
        password_hash="test_hash",
        name="Test User",
        profile_picture=None,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        preferences={},
        books_finished=0
    )
    db_session.add(test_user)
    db_session.commit()
    
    # Override authentication dependency
    async def override_get_current_user():
        return db_session.query(User).filter_by(id=test_user.id).first()
    
    from app.main import app
    app.dependency_overrides[get_current_user] = override_get_current_user
    
    try:
        # Create a temporary test file
        with open("test.pdf", "wb") as f:
            f.write(b"test content")
        
        try:
            with open("test.pdf", "rb") as f:
                response = client.post(
                    "/books/upload",
                    files={"file": ("test.pdf", f, "application/pdf")},
                    data={
                        "title": "Test Book",
                        "author": "Test Author",
                        "total_pages": "100"
                    }
                )
            
            assert response.status_code == 200
            assert "id" in response.json()
            assert "title" in response.json()
        finally:
            # Clean up temporary file
            if os.path.exists("test.pdf"):
                os.remove("test.pdf")
    finally:
        del app.dependency_overrides[get_current_user] 