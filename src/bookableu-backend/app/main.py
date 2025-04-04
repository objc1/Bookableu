"""
Main application entry point for the Bookableu API.
This module initializes the FastAPI application, sets up logging,
configures database connections, and defines core routes and middleware.
"""

import logging
from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.exceptions import RequestValidationError
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import uvicorn

from app.models import Base
from app.dependencies import engine
from app.routes import auth, books, users

# Configure logging to write to app.log with timestamp, logger name, level, and message
logging.basicConfig(
    filename="app.log",
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager that handles startup and shutdown events.
    Creates database tables on startup and logs any initialization errors.
    """
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables initialized")
        yield
    except Exception as e:
        logger.error(f"Failed to initialize database: {str(e)}")
        raise

# Initialize FastAPI application with title and lifespan manager
app = FastAPI(title="Bookableu API", lifespan=lifespan)

# Mount static files directory for serving frontend assets
app.mount("/static", StaticFiles(directory="app/static"), name="static")

# Include routers for different API endpoints
app.include_router(auth.router)    # Authentication routes
app.include_router(books.router)   # Book-related routes
app.include_router(users.router)   # User management routes

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """
    Global exception handler for request validation errors.
    Formats validation errors into a consistent JSON response structure.
    """
    errors = [{"loc": e["loc"], "msg": str(e["msg"]), "type": e["type"]} for e in exc.errors()]
    logger.error(f"Validation error: {errors}")
    return JSONResponse(status_code=422, content={"detail": errors, "message": "Invalid input"})

@app.get("/")
async def read_root():
    """
    Root endpoint that serves the main frontend application.
    Returns index.html for the root path, with appropriate error handling.
    """
    try:
        return FileResponse(
            "app/static/index.html",
            media_type="text/html"
        )
    except FileNotFoundError:
        logger.error("index.html not found")
        return JSONResponse(
            status_code=404,
            content={"message": "Frontend not found"}
        )
    except Exception as e:
        logger.error(f"Error serving index.html: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"message": "Internal server error"}
        )

# Entry point for running the application directly
if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000)
