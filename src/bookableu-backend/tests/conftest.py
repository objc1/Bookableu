"""
Test configuration and fixtures for Bookableu backend tests.

This module provides pytest fixtures for testing the Bookableu backend application.
It sets up a test database, mocks external services (S3), and provides test user data.
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from datetime import datetime, timezone
import uuid

from app.main import app
from app.models import Base, User
from app.dependencies import get_db, get_current_user
from app.services import s3_service

# Configure in-memory SQLite database for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="session")
def db_engine():
    """Create and manage the test database engine.
    
    This fixture creates all database tables at the start of the test session
    and drops them when the session ends.
    """
    Base.metadata.create_all(bind=engine)
    yield engine
    Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def db_session(db_engine):
    """Provide a database session for each test function.
    
    Creates a new transaction for each test and rolls it back after the test
    completes, ensuring test isolation.
    """
    connection = db_engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)
    
    yield session
    
    session.close()
    if transaction.is_active:
        transaction.rollback()
    connection.close()

@pytest.fixture(scope="function")
def override_get_current_user(test_user):
    """Override the current user dependency for testing.
    
    Returns a function that always returns the test user, bypassing
    authentication checks during tests.
    """
    async def get_current_test_user():
        return test_user
    return get_current_test_user

@pytest.fixture(scope="function")
def mock_s3(monkeypatch):
    """Mock S3 service functions for testing.
    
    Replaces all S3-related functions with mock implementations that return
    predictable test data without making actual AWS calls.
    """
    # Create mock functions
    async def mock_upload(*args, **kwargs):
        return "mock_key"
    
    async def mock_url(*args, **kwargs):
        return "https://mock-presigned-url.com"
    
    async def mock_download(*args, **kwargs):
        return b"mock file content"
    
    async def mock_delete(*args, **kwargs):
        return True
    
    # Patch the S3 service functions
    monkeypatch.setattr(s3_service, "upload_fileobj_to_s3", mock_upload)
    monkeypatch.setattr(s3_service, "generate_presigned_url", mock_url)
    monkeypatch.setattr(s3_service, "download_fileobj_from_s3", mock_download)
    monkeypatch.setattr(s3_service, "delete_object", mock_delete)
    
    yield

@pytest.fixture(scope="function")
def client(db_session, override_get_current_user, mock_s3):
    """Create a test client with mocked dependencies.
    
    Provides a FastAPI TestClient instance with overridden database and
    authentication dependencies, along with mocked S3 service.
    """
    def override_get_db():
        try:
            yield db_session
        finally:
            pass
    
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user
    
    with TestClient(app) as test_client:
        yield test_client
    
    app.dependency_overrides.clear()

@pytest.fixture(scope="function")
def test_user(db_session):
    """Create a test user for authentication and testing.
    
    Creates and returns a User instance with test data that can be used
    throughout the test suite.
    """
    user = User(
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
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user 