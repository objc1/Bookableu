"""
Tests for user-related endpoints in the Bookableu API.
This module contains test cases for user management functionality including:
- Getting all users (admin only)
- Getting current user profile
- Updating user profile information
"""
import uuid
from fastapi.testclient import TestClient
from app.models import User
from datetime import datetime, timezone

def test_get_users(client: TestClient, db_session, monkeypatch):
    """
    Test the GET /users endpoint which returns all users.
    This endpoint is restricted to admin users only.
    
    Test flow:
    1. Clear existing users from the database
    2. Create an admin user and a regular user
    3. Override the current user dependency to simulate admin authentication
    4. Verify the endpoint returns both users
    5. Clean up by restoring original settings
    """
    from app.dependencies import get_current_user
    from app.config import settings
    
    # Clear any existing data to ensure a clean test state
    db_session.query(User).delete()
    db_session.commit()
    
    # Create an admin test user with predefined UUID for consistency
    admin_email = "admin@example.com"
    admin_id = uuid.uuid4()
    
    # Temporarily modify admin emails list to include our test admin
    original_admin_emails = settings.ADMIN_EMAILS
    settings.ADMIN_EMAILS = [admin_email]
    
    # Create admin user with test data
    admin_user = User(
        id=admin_id,
        email=admin_email,
        password_hash="test_hash",
        name="Admin User",
        profile_picture=None,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        preferences={},
        books_finished=0
    )
    
    # Create a regular user for comparison
    regular_user = User(
        id=uuid.uuid4(),
        email="regular@example.com",
        password_hash="test_hash",
        name="Regular User",
        profile_picture=None,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        preferences={},
        books_finished=0
    )
    
    # Add both users to the database
    db_session.add(admin_user)
    db_session.add(regular_user)
    db_session.commit()
    db_session.refresh(admin_user)
    
    # Override the authentication dependency to return our admin user
    async def override_get_current_user():
        return db_session.query(User).filter_by(id=admin_id).first()
    
    from app.main import app
    app.dependency_overrides[get_current_user] = override_get_current_user
    
    try:
        # Make the request and verify response
        response = client.get("/users")
        assert response.status_code == 200
        assert isinstance(response.json(), list)
        # Verify both users are returned in the response
        assert len(response.json()) == 2
    finally:
        # Restore original settings and remove dependency override
        settings.ADMIN_EMAILS = original_admin_emails
        del app.dependency_overrides[get_current_user]

def test_get_me(client: TestClient, db_session, monkeypatch):
    """
    Test the GET /users/me endpoint which returns the current user's profile.
    
    Test flow:
    1. Clear existing users from the database
    2. Create a test user
    3. Override the current user dependency to simulate authentication
    4. Verify the endpoint returns the correct user data
    5. Clean up by removing dependency override
    """
    from app.dependencies import get_current_user
    
    # Clear any existing data to ensure a clean test state
    db_session.query(User).delete()
    db_session.commit()
    
    # Create a test user with predefined UUID for consistency
    test_id = uuid.uuid4()
    test_user = User(
        id=test_id,
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
    db_session.refresh(test_user)
    
    # Override the authentication dependency to return our test user
    async def override_get_current_user():
        return db_session.query(User).filter_by(id=test_id).first()
    
    from app.main import app
    app.dependency_overrides[get_current_user] = override_get_current_user
    
    try:
        # Make the request and verify response
        response = client.get("/users/me")
        assert response.status_code == 200
        assert "id" in response.json()
        assert "email" in response.json()
        assert response.json()["email"] == "test@example.com"
    finally:
        # Remove the dependency override
        del app.dependency_overrides[get_current_user]

def test_update_user(client: TestClient, db_session, monkeypatch):
    """
    Test the PUT /users/me endpoint which updates the current user's profile.
    
    Test flow:
    1. Clear existing users from the database
    2. Create a test user
    3. Override the current user dependency to simulate authentication
    4. Send an update request with new user data
    5. Verify the update was successful both in response and database
    6. Clean up by removing dependency override
    """
    from app.dependencies import get_current_user
    
    # Clear any existing data to ensure a clean test state
    db_session.query(User).delete()
    db_session.commit()
    
    # Create a test user with predefined UUID for consistency
    test_id = uuid.uuid4()
    test_user = User(
        id=test_id,
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
    db_session.refresh(test_user)
    
    # Override the authentication dependency to return our test user
    # Using a fresh database query to avoid detached object issues
    async def override_get_current_user():
        return db_session.query(User).filter_by(id=test_id).first()
    
    from app.main import app
    app.dependency_overrides[get_current_user] = override_get_current_user
    
    try:
        # Send update request with new user data using multipart/form-data format
        response = client.put(
            "/users/me",
            data={"name": "Updated User"}  # Form data for name update
        )
        
        # Verify the response
        assert response.status_code == 200
        assert response.json()["name"] == "Updated User"
        
        # Verify the update in the database with a fresh query
        updated_user = db_session.query(User).filter_by(id=test_id).first()
        assert updated_user is not None
        assert updated_user.name == "Updated User"
    finally:
        # Remove the dependency override
        del app.dependency_overrides[get_current_user] 