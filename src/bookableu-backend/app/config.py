from dotenv import load_dotenv
import os
from typing import Optional, List

# Load environment variables from .env file
load_dotenv()

class Settings:
    """
    Application configuration settings loaded from environment variables.
    
    This class manages all configuration settings for the BookableU application,
    including database connections, AWS S3 storage, OpenAI integration, and security settings.
    It provides sensible defaults for local development while enforcing strict validation
    for production environments.
    
    Attributes:
        ENVIRONMENT (str): Current environment ('local' or 'production')
        SECRET_KEY (str): Secret key for JWT token generation
        ALGORITHM (str): Algorithm used for JWT token signing
        ACCESS_TOKEN_EXPIRE_MINUTES (int): JWT token expiration time in minutes
        DATABASE_URL (str): Database connection string
        AWS_REGION (str): AWS region for S3 operations
        AWS_ACCESS_KEY_ID (Optional[str]): AWS access key for S3 authentication
        AWS_SECRET_ACCESS_KEY (Optional[str]): AWS secret key for S3 authentication
        BUCKET_NAME (str): Name of the S3 bucket for file storage
        OPENAI_API_KEY (Optional[str]): API key for OpenAI services
        OPENAI_MODEL (str): Default OpenAI model to use
        OPENAI_TEMPERATURE (float): Temperature setting for OpenAI model
        OPENAI_MAX_TOKENS (int): Maximum tokens for OpenAI responses
        BOOK_QUERY_INSTRUCTION_STYLE (str): Style of book query instructions
        ADMIN_EMAILS (List[str]): List of admin user email addresses
    """
    
    # General settings
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "local")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key")  # Must be overridden in production
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 7 * 24 * 60  # 7 days

    # Database settings - Uses SQLite for local development, configured database for production
    DATABASE_URL: str = (
        os.getenv("LOCAL_DATABASE_URL", "sqlite:///./test.db")
        if ENVIRONMENT == "local"
        else os.getenv("PROD_DATABASE_URL", "")
    )

    # AWS S3 settings for file storage
    AWS_REGION: str = os.getenv("AWS_REGION", "us-east-1")
    AWS_ACCESS_KEY_ID: Optional[str] = os.getenv("AWS_ACCESS_KEY_ID")
    AWS_SECRET_ACCESS_KEY: Optional[str] = os.getenv("AWS_SECRET_ACCESS_KEY")
    BUCKET_NAME: str = os.getenv("BUCKET_NAME")

    # OpenAI API settings for AI-powered features
    OPENAI_API_KEY: Optional[str] = os.getenv("OPENAI_API_KEY")
    OPENAI_MODEL: str = os.getenv("OPENAI_MODEL", "gpt-3.5-turbo")
    OPENAI_TEMPERATURE: float = float(os.getenv("OPENAI_TEMPERATURE", "0.3"))
    OPENAI_MAX_TOKENS: int = int(os.getenv("OPENAI_MAX_TOKENS", "500"))

    # LLM prompt customization - Controls the style of AI-generated responses
    BOOK_QUERY_INSTRUCTION_STYLE: str = os.getenv("BOOK_QUERY_INSTRUCTION_STYLE", "academic")

    # Admin settings - List of email addresses with administrative privileges
    ADMIN_EMAILS: List[str] = [
        email.strip() for email in os.getenv("ADMIN_EMAILS", "").split(",") if email.strip()
    ]

    def __init__(self):
        """
        Initialize the Settings object and validate all configuration values.
        """
        self._validate_settings()

    def _validate_settings(self) -> None:
        """
        Validate critical settings to ensure the application can run safely.
        
        This method performs environment-specific validation:
        - In production: Enforces strict validation of all required settings
        - In local development: Allows default values for easier development
        
        Raises:
            ValueError: If required settings are missing or invalid in production environment
        """
        if self.ENVIRONMENT != "local":
            # Production-specific validations
            if not self.SECRET_KEY or self.SECRET_KEY == "your-secret-key":
                raise ValueError("SECRET_KEY must be set to a secure value in production")
            if not self.DATABASE_URL:
                raise ValueError("PROD_DATABASE_URL must be set in production")
            if not all([self.AWS_ACCESS_KEY_ID, self.AWS_SECRET_ACCESS_KEY]):
                raise ValueError("AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set in production")
            if not self.BUCKET_NAME:
                raise ValueError("BUCKET_NAME must be set in production")
            if not self.OPENAI_API_KEY:
                raise ValueError("OPENAI_API_KEY must be set in production")

# Create a global settings instance for application-wide use
settings = Settings()

# Debug information (remove in production)
if __name__ == "__main__":
    print(f"Environment: {settings.ENVIRONMENT}")
    print(f"Database URL: {settings.DATABASE_URL}")
    print(f"AWS Region: {settings.AWS_REGION}")
    print(f"Admin Emails: {settings.ADMIN_EMAILS}")
    print(f"OpenAI API Key: {settings.OPENAI_API_KEY}")