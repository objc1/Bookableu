"""
Authentication routes for the BookableU application.

This module handles user registration, login, and token generation.
It provides endpoints for user authentication using JWT tokens and bcrypt password hashing.
"""

from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
from jose import jwt
import logging

from app.models import User
from app.schemas import UserCreate, Token
from app.dependencies import get_db
from app.config import settings

# Initialize router with auth prefix and tags
router = APIRouter(prefix="/auth", tags=["auth"])

# Initialize password hashing context using bcrypt
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Set up logging
logger = logging.getLogger(__name__)

def create_access_token(email: str) -> str:
    """
    Create a JWT access token for a user.
    
    Args:
        email (str): The user's email address to be encoded in the token
        
    Returns:
        str: A JWT token containing the user's email and expiration time
    """
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode({"sub": email, "exp": expire}, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

@router.post("/register")
async def register(user: UserCreate, db: Session = Depends(get_db)):
    """
    Register a new user in the system.
    
    Args:
        user (UserCreate): User registration data containing email, password, and name
        db (Session): Database session dependency
        
    Returns:
        dict: A message confirming user creation
        
    Raises:
        HTTPException: If the email is already registered
    """
    if db.query(User).filter(User.email == user.email).first():
        logger.warning(f"Email already registered: {user.email}")
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_password = pwd_context.hash(user.password)
    db_user = User(email=user.email.lower(), password_hash=hashed_password, name=user.name)
    db.add(db_user)
    db.commit()
    logger.info(f"User registered: {user.email}")
    return {"message": "User created"}

@router.post("/login", response_model=Token)
async def login(user: UserCreate, db: Session = Depends(get_db)):
    """
    Authenticate a user and return a JWT access token.
    
    Args:
        user (UserCreate): User login credentials (email and password)
        db (Session): Database session dependency
        
    Returns:
        Token: A dictionary containing the access token and token type
        
    Raises:
        HTTPException: If the credentials are invalid
    """
    db_user = db.query(User).filter(User.email == user.email.lower()).first()
    if not db_user or not pwd_context.verify(user.password, db_user.password_hash):
        logger.warning(f"Login failed for {user.email}")
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    token = create_access_token(db_user.email)
    logger.info(f"User logged in: {user.email}")
    return {"access_token": token, "token_type": "bearer"}