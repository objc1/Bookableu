# Bookableu Backend

[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.68.0+-green.svg)](https://fastapi.tiangolo.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-13+-blue.svg)](https://www.postgresql.org/)

<img src="../../demo/logo.png" width="200" style="border-radius: 20px;"/>

This repository contains the backend API for the Bookableu application, a comprehensive platform for managing and discovering books. The backend provides a robust RESTful API with features for book management, user authentication, and content processing.

## Features

- 🔐 Secure user authentication and authorization
- 📚 Comprehensive book catalog management
- 🔍 Advanced search functionality with machine learning
- 📖 E-book processing and content extraction
- 🤖 AI-powered book recommendations
- 📊 Analytics and usage tracking
- 🔄 Real-time updates and notifications

## Technologies Used

- **FastAPI**: Modern, fast web framework for building APIs
- **SQLAlchemy**: SQL toolkit and ORM
- **PostgreSQL**: Database (via psycopg2)
- **PyJWT**: JSON Web Token implementation
- **Passlib**: Password hashing library
- **PyMuPDF & ebooklib**: E-book processing libraries
- **scikit-learn & faiss-cpu**: Machine learning and similarity search
- **OpenAI**: AI integration for content features
- **Boto3**: AWS SDK for Python
- **Pytest**: Testing framework

## Setup and Installation

### Prerequisites

- Python 3.8 or higher
- PostgreSQL 13 or higher
- AWS Account (for S3 storage)
- OpenAI API key (for AI features)

### Environment Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/bookableu-backend.git
   cd bookableu-backend
   ```

2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Set up the database:
   ```bash
   createdb bookableu
   ```

5. Configure environment variables:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your configuration:
   ```
   DATABASE_URL=postgresql://user:password@localhost:5432/bookableu
   SECRET_KEY=your-secret-key
   ALGORITHM=HS256
   ACCESS_TOKEN_EXPIRE_MINUTES=30
   AWS_ACCESS_KEY_ID=your-aws-access-key
   AWS_SECRET_ACCESS_KEY=your-aws-secret-key
   AWS_REGION=your-aws-region
   S3_BUCKET=your-bucket-name
   OPENAI_API_KEY=your-openai-api-key
   ```

### Running Locally

1. Start the development server:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

2. The API will be available at http://localhost:8000

## API Documentation

The API documentation is automatically generated and available at:

- **Swagger UI**: http://localhost:8000/docs
  - Interactive documentation
  - Try out API endpoints directly
  - View request/response schemas

- **ReDoc**: http://localhost:8000/redoc
  - Clean, organized documentation
  - Better for sharing with non-technical users

## Project Structure

```
bookableu-backend/
├── app/                     # Main application package
│   ├── main.py              # Application entry point
│   ├── config.py            # Configuration settings
│   ├── dependencies.py      # Dependency injection
│   ├── models.py            # Database models
│   ├── schemas.py           # Pydantic schemas
│   ├── routes/              # API endpoints
│   │   ├── auth.py          # Authentication routes
│   │   ├── books.py         # Book management routes
│   │   └── users.py         # User management routes
│   ├── services/            # Business logic
│   │   ├── auth.py          # Authentication service
│   │   ├── books.py         # Book processing service
│   │   └── search.py        # Search functionality
│   └── static/              # Static files
├── tests/                   # Test suite
│   ├── conftest.py          # Test configuration
│   ├── test_auth.py         # Authentication tests
│   └── test_books.py        # Book management tests
├── .env.example             # Example environment variables
├── requirements.txt         # Project dependencies
└── README.md                # This file
```

## Code Statistics

The project consists of the following code distribution:

```
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
Python                          15            432            916           1564
JavaScript                       1             59             16            517
CSS                              1             59             13            353
Markdown                         1             34              0            121
HTML                             1             10              8            119
Bourne Shell                     1              6              5             32
Text                             1              0              0             19
-------------------------------------------------------------------------------
SUM:                            21            600            958           2725
-------------------------------------------------------------------------------
```

## Testing

Run the test suite:

```bash
# Run all tests
pytest

# Run with coverage report
pytest --cov=app tests/

# Run specific test file
pytest tests/test_auth.py
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

Maxim Leypunskiy - max.leypunskiy@outlook.com

Project Link: [https://github.com/yourusername/bookableu-backend](https://github.com/yourusername/bookableu-backend)