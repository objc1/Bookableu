from pydantic import BaseModel, EmailStr, Field
from typing import Optional, Dict
from datetime import datetime
import uuid

from app.models import BookStatus

class UserCreate(BaseModel):
    """
    Schema for creating a new user account.
    
    Attributes:
        email (EmailStr): User's email address, must be valid email format
        password (str): User's password (will be hashed before storage)
        name (Optional[str]): User's display name, optional
    """
    email: EmailStr
    password: str
    name: Optional[str] = None

class UserOut(BaseModel):
    """
    Schema for user data returned to the client.
    Excludes sensitive information like password.
    
    Attributes:
        id (uuid.UUID): Unique identifier for the user
        email (EmailStr): User's email address
        name (Optional[str]): User's display name
        profile_picture (Optional[str]): URL to user's profile picture
        created_at (datetime): Timestamp of account creation
        updated_at (datetime): Timestamp of last update
        preferences (Dict): User's application preferences
        books_finished (int): Count of books completed by user
    """
    id: uuid.UUID
    email: EmailStr
    name: Optional[str] = None
    profile_picture: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    preferences: Dict = Field(default_factory=dict)
    books_finished: int

class BookOut(BaseModel):
    """
    Schema for book data returned to the client.
    Contains all book information including reading progress.
    
    Attributes:
        id (int): Unique identifier for the book
        title (str): Book title
        file_key (str): Storage key for the book file
        text_key (Optional[str]): Storage key for processed text content
        author (Optional[str]): Book author name
        total_pages (Optional[int]): Total number of pages in the book
        current_page (int): User's current reading position
        status (BookStatus): Current reading status (e.g., reading, completed)
        user_id (uuid.UUID): ID of the user who owns this book
        book_metadata (Dict): Additional book-specific metadata
    """
    id: int
    title: str
    file_key: str
    text_key: Optional[str] = None
    author: Optional[str] = None
    total_pages: Optional[int] = None
    current_page: int
    status: BookStatus
    user_id: uuid.UUID
    book_metadata: Dict = Field(default_factory=dict)

class BookCreate(BaseModel):
    """
    Schema for creating a new book entry.
    Contains only the essential information needed for book creation.
    
    Attributes:
        title (str): Book title
        file_key (str): Storage key for the book file
        text_key (Optional[str]): Storage key for processed text content
        author (Optional[str]): Book author name
        total_pages (Optional[int]): Total number of pages in the book
    """
    title: str
    file_key: str
    text_key: Optional[str] = None
    author: Optional[str] = None
    total_pages: Optional[int] = None

class BookUpdate(BaseModel):
    """
    Schema for updating an existing book's information.
    All fields are optional to allow partial updates.
    
    Attributes:
        current_page (Optional[int]): Updated reading position
        status (Optional[BookStatus]): Updated reading status
        book_metadata (Optional[Dict]): Updated book metadata
    """
    current_page: Optional[int] = None
    status: Optional[BookStatus] = None
    book_metadata: Optional[Dict] = None
    
class LLMPreferences(BaseModel):
    """
    Schema for user's Large Language Model (LLM) preferences.
    Used to customize AI interactions and responses.
    
    Attributes:
        model (Optional[str]): Name of the LLM model to use
        temperature (Optional[float]): Controls randomness in responses (0.0-1.0)
        max_tokens (Optional[int]): Maximum length of generated responses
        instruction_style (Optional[str]): Style of instructions for the LLM
    """
    model: Optional[str] = None
    temperature: Optional[float] = None
    max_tokens: Optional[int] = None
    instruction_style: Optional[str] = None

class Token(BaseModel):
    """
    Schema for authentication tokens.
    
    Attributes:
        access_token (str): JWT token for API authentication
        token_type (str): Type of token (typically "bearer")
    """
    access_token: str
    token_type: str

class QueryResult(BaseModel):
    """
    Schema for book query results containing text chunks and their metadata.
    Used for semantic search and text retrieval operations.
    
    Attributes:
        text (str): The actual text content of the chunk
        similarity_score (float): Score indicating relevance to the query (0.0-1.0)
        chunk_index (int): Position of the chunk in the original text
    """
    text: str
    similarity_score: float
    chunk_index: int 