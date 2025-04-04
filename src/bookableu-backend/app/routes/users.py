from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Body
from sqlalchemy.orm import Session
import logging
from typing import Optional, List, Dict, Any
import os

from app.models import User, Book
from app.schemas import UserOut, LLMPreferences
from app.dependencies import get_db, get_current_user
from app.services.s3_service import upload_fileobj_to_s3, generate_presigned_url, delete_object
from app.config import settings

# Initialize router and logger for user-related endpoints
router = APIRouter(prefix="/users", tags=["users"])
logger = logging.getLogger(__name__)

# Define allowed image file extensions for profile pictures
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif"}

def is_admin(user: User) -> bool:
    """
    Check if a user has admin privileges based on their email.
    
    Args:
        user (User): The user to check
        
    Returns:
        bool: True if the user's email is in the admin list, False otherwise
    """
    return user.email in settings.ADMIN_EMAILS

@router.get("/me", response_model=UserOut)
async def get_profile(current_user: User = Depends(get_current_user)):
    """
    Retrieve the current user's profile information.
    
    Args:
        current_user (User): The authenticated user (injected by FastAPI)
        
    Returns:
        UserOut: The user's profile information
    """
    logger.info(f"Profile accessed for user_id={str(current_user.id)}")
    return current_user

@router.put("/me", response_model=UserOut)
async def update_profile(
    name: Optional[str] = Form(None),
    picture: Optional[UploadFile] = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update the current user's profile information.
    
    Args:
        name (Optional[str]): New name for the user
        picture (Optional[UploadFile]): New profile picture file
        current_user (User): The authenticated user
        db (Session): Database session
        
    Returns:
        UserOut: Updated user profile information
        
    Raises:
        HTTPException: If the uploaded image format is not supported
    """
    if name:
        current_user.name = name
    
    if picture:
        file_ext = os.path.splitext(picture.filename.lower())[1]
        if file_ext not in ALLOWED_EXTENSIONS:
            raise HTTPException(status_code=400, detail="Invalid image format")
        
        # Generate a unique key for the profile picture in S3
        picture_key = f"users/{str(current_user.id)}/profile_picture{file_ext}"
        content_type = f"image/{file_ext[1:] if file_ext != '.jpg' else 'jpeg'}"
        
        # Delete old profile picture if it exists
        if current_user.profile_picture:
            await delete_object(settings.BUCKET_NAME, current_user.profile_picture)
        
        # Upload new profile picture to S3
        await upload_fileobj_to_s3(picture.file, settings.BUCKET_NAME, picture_key, content_type=content_type)
        current_user.profile_picture = picture_key
    
    db.commit()
    db.refresh(current_user)
    logger.info(f"Profile updated for user_id={str(current_user.id)}")
    return current_user

@router.get("/me/picture-url")
async def get_profile_picture_url(current_user: User = Depends(get_current_user)):
    """
    Generate a presigned URL for the user's profile picture.
    
    Args:
        current_user (User): The authenticated user
        
    Returns:
        dict: Contains the presigned URL for the profile picture
        
    Raises:
        HTTPException: If the user has no profile picture
    """
    if not current_user.profile_picture:
        raise HTTPException(status_code=404, detail="No profile picture")
    url = await generate_presigned_url(settings.BUCKET_NAME, current_user.profile_picture)
    return {"url": url}

@router.delete("/me", status_code=204)
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Permanently delete the current user's account and all associated data.
    This includes:
    - Profile picture from S3 storage
    - All books associated with the user
    - User record from the database
    
    Args:
        current_user (User): The authenticated user
        db (Session): Database session
        
    Raises:
        HTTPException: If account deletion fails
    """
    try:
        # Delete profile picture from S3 if it exists
        if current_user.profile_picture:
            await delete_object(settings.BUCKET_NAME, current_user.profile_picture)
        
        # Delete all associated books
        books = db.query(Book).filter(Book.user_id == current_user.id).all()
        for book in books:
            db.delete(book)
        
        # Delete user from database
        db.delete(current_user)
        db.commit()
        
        logger.info(f"Account deleted for user_id={str(current_user.id)}")
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to delete account: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to delete account")

@router.get("", response_model=List[UserOut])
async def list_users(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    List all users in the system (admin only).
    
    Args:
        skip (int): Number of records to skip (for pagination)
        limit (int): Maximum number of records to return
        current_user (User): The authenticated user
        db (Session): Database session
        
    Returns:
        List[UserOut]: List of user profiles
        
    Raises:
        HTTPException: If the current user is not an admin
    """
    if not is_admin(current_user):
        raise HTTPException(status_code=403, detail="Admin access required")
    
    users = db.query(User).offset(skip).limit(limit).all()
    logger.info(f"Listed {len(users)} users by admin user_id={str(current_user.id)}")
    return users

@router.put("/llm-preferences", response_model=Dict[str, Any])
async def update_llm_preferences(
    preferences: LLMPreferences,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update the user's LLM preferences for book queries.
    These settings override the global defaults and affect how the AI responds to book-related queries.
    
    Args:
        preferences (LLMPreferences): New LLM preferences to apply
        current_user (User): The authenticated user
        db (Session): Database session
        
    Returns:
        Dict[str, Any]: Success status and updated preferences
        
    Raises:
        HTTPException: If preferences are invalid or update fails
    """
    try:
        # Initialize preferences if they don't exist
        if not current_user.preferences:
            current_user.preferences = {}
        if "llm" not in current_user.preferences:
            current_user.preferences["llm"] = {}
        
        # Update only the provided fields with validation
        if preferences.model is not None:
            current_user.preferences["llm"]["model"] = preferences.model
            
        if preferences.temperature is not None:
            # Validate temperature is between 0 and 1
            if 0 <= preferences.temperature <= 1:
                current_user.preferences["llm"]["temperature"] = preferences.temperature
            else:
                raise HTTPException(status_code=400, detail="Temperature must be between 0 and 1")
                
        if preferences.max_tokens is not None:
            # Validate max_tokens is reasonable
            if 50 <= preferences.max_tokens <= 1000:
                current_user.preferences["llm"]["max_tokens"] = preferences.max_tokens
            else:
                raise HTTPException(status_code=400, detail="max_tokens must be between 50 and 1000")
                
        if preferences.instruction_style is not None:
            # Validate instruction_style is one of the allowed values
            allowed_styles = ["academic", "casual", "concise"]
            if preferences.instruction_style.lower() in allowed_styles:
                current_user.preferences["llm"]["instruction_style"] = preferences.instruction_style.lower()
            else:
                raise HTTPException(
                    status_code=400, 
                    detail=f"instruction_style must be one of: {', '.join(allowed_styles)}"
                )
        
        # Save changes to database
        db.commit()
        logger.info(f"Updated LLM preferences for user_id={current_user.id}")
        
        return {"success": True, "preferences": current_user.preferences["llm"]}
        
    except Exception as e:
        logger.error(f"Failed to update LLM preferences: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to update LLM preferences")