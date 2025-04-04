from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, JSON, Enum as SAEnum
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime, timezone
from enum import Enum
from passlib.context import CryptContext
import uuid
from sqlalchemy.dialects.postgresql import UUID

Base = declarative_base()

class BookStatus(str, Enum):
    """Enumeration of possible book reading statuses."""
    UNREAD = "unread"      # Book has been added but not started
    READING = "reading"    # Book is currently being read
    FINISHED = "finished"  # Book has been completed
    PROCESSING = "processing"  # Book is being processed (e.g., text extraction)

class User(Base):
    """
    User model representing a Bookableu user.
    
    Attributes:
        id (UUID): Unique identifier for the user
        email (str): User's email address (unique)
        password_hash (str): Hashed password using bcrypt
        name (str): User's display name (optional)
        profile_picture (str): URL to user's profile picture (optional)
        created_at (datetime): Timestamp of account creation
        updated_at (datetime): Timestamp of last update
        preferences (dict): User preferences stored as JSON
        books_finished (int): Counter for completed books
        books (relationship): One-to-many relationship with Book model
    """
    __tablename__ = "users"
    id = Column(UUID(as_uuid=True), primary_key=True, index=True, default=uuid.uuid4)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    name = Column(String, nullable=True)
    profile_picture = Column(String, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc))
    preferences = Column(JSON, default=dict, nullable=False)
    books_finished = Column(Integer, default=0, nullable=False)
    books = relationship("Book", back_populates="user")

    def verify_password(self, password: str) -> bool:
        """
        Verify a password against the stored hash using bcrypt.
        
        Args:
            password (str): The plain text password to verify
            
        Returns:
            bool: True if password matches, False otherwise
        """
        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
        return pwd_context.verify(password, self.password_hash)

class Book(Base):
    """
    Book model representing a user's book in the system.
    
    Attributes:
        id (int): Unique identifier for the book
        user_id (UUID): Foreign key to the owning user
        title (str): Book title
        file_key (str): Storage key for the book file
        text_key (str): Storage key for extracted text (optional)
        author (str): Book author (optional)
        total_pages (int): Total number of pages (optional)
        current_page (int): Current reading progress
        status (BookStatus): Current reading status
        book_metadata (dict): Additional book metadata stored as JSON
        created_at (datetime): Timestamp of book addition
        updated_at (datetime): Timestamp of last update
        user (relationship): Many-to-one relationship with User model
    """
    __tablename__ = "books"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String, nullable=False)
    file_key = Column(String, nullable=False)
    text_key = Column(String, nullable=True)
    author = Column(String, nullable=True)
    total_pages = Column(Integer, nullable=True)
    current_page = Column(Integer, default=0, nullable=False)
    status = Column(SAEnum(BookStatus), default=BookStatus.UNREAD, nullable=False)
    book_metadata = Column(JSON, default=dict, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc))
    user = relationship("User", back_populates="books")
