"""
AWS S3 Service Module

This module provides asynchronous wrapper functions for AWS S3 operations,
handling file uploads, downloads, URL generation, and object deletion.
It uses boto3 for AWS interactions and includes proper error handling and logging.
"""

import boto3
from botocore.exceptions import ClientError
from botocore.config import Config
import logging
from typing import Optional
from io import BytesIO
import asyncio

from app.config import settings

logger = logging.getLogger(__name__)

# Initialize S3 client with retry configuration and connection pooling
s3_client = boto3.client(
    "s3",
    region_name=settings.AWS_REGION,
    aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
    aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    config=Config(retries={"max_attempts": 10, "mode": "standard"}, max_pool_connections=50)
)

async def upload_fileobj_to_s3(
    file_obj: BytesIO,
    bucket_name: str,
    file_key: str,
    content_type: Optional[str] = None
) -> None:
    """
    Asynchronously upload a file-like object to an S3 bucket.

    This function handles the upload of file data to S3, supporting custom content types
    and proper error handling. The file object is automatically reset to the beginning
    before upload to ensure complete data transfer.

    Args:
        file_obj (BytesIO): The file-like object containing the data to upload.
        bucket_name (str): The name of the target S3 bucket.
        file_key (str): The desired key (path) under which the file will be stored in S3.
        content_type (Optional[str]): The MIME type of the file. If provided, sets the Content-Type metadata.

    Raises:
        ClientError: If the upload fails due to AWS S3 API errors.
    """
    file_obj.seek(0)
    extra_args = {"ContentType": content_type} if content_type else {}
    try:
        await asyncio.to_thread(
            s3_client.upload_fileobj,
            file_obj, bucket_name, file_key, ExtraArgs=extra_args
        )
        logger.info(f"Successfully uploaded file with key '{file_key}' to bucket '{bucket_name}'.")
    except ClientError as e:
        logger.error(f"Failed to upload file with key '{file_key}' to bucket '{bucket_name}': {e}")
        raise

async def generate_presigned_url(
    bucket_name: str,
    file_key: str,
    expires_in: int = 3600
) -> str:
    """
    Generate a presigned URL for temporary access to an S3 object.

    Creates a time-limited URL that can be used to access an S3 object without AWS credentials.
    The URL is valid for the specified duration (default 1 hour).

    Args:
        bucket_name (str): The name of the S3 bucket containing the object.
        file_key (str): The key (path) of the object in the S3 bucket.
        expires_in (int): The number of seconds until the URL expires (default: 3600).

    Returns:
        str: A presigned URL that can be used to access the S3 object.

    Raises:
        ClientError: If URL generation fails due to AWS S3 API errors.
    """
    try:
        url = await asyncio.to_thread(
            s3_client.generate_presigned_url,
            "get_object",
            Params={"Bucket": bucket_name, "Key": file_key},
            ExpiresIn=expires_in
        )
        logger.info(f"Successfully generated presigned URL for key '{file_key}' in bucket '{bucket_name}'.")
        return url
    except ClientError as e:
        logger.error(f"Failed to generate presigned URL for key '{file_key}' in bucket '{bucket_name}': {e}")
        raise

async def delete_object(bucket_name: str, file_key: str) -> bool:
    """
    Asynchronously delete an object from an S3 bucket.

    Removes the specified object from the S3 bucket. This operation is permanent
    and cannot be undone. The function includes proper error handling and logging.

    Args:
        bucket_name (str): The name of the S3 bucket containing the object.
        file_key (str): The key (path) of the object to delete in the S3 bucket.

    Returns:
        bool: True if the deletion was successful.

    Raises:
        ClientError: If the deletion fails due to AWS S3 API errors.
    """
    try:
        await asyncio.to_thread(
            s3_client.delete_object,
            Bucket=bucket_name,
            Key=file_key
        )
        logger.info(f"Successfully deleted object with key '{file_key}' from bucket '{bucket_name}'.")
        return True
    except ClientError as e:
        logger.error(f"Failed to delete object with key '{file_key}' from bucket '{bucket_name}': {e}")
        raise

async def download_fileobj_from_s3(
    bucket_name: str,
    file_key: str
) -> BytesIO:
    """
    Asynchronously download an object from S3 and return its contents.

    Downloads the specified object from S3 and returns its contents as a BytesIO object,
    which can be used for further processing or streaming. The function includes
    proper error handling and logging.

    Args:
        bucket_name (str): The name of the S3 bucket containing the object.
        file_key (str): The key (path) of the object to download from the S3 bucket.

    Returns:
        BytesIO: A BytesIO object containing the downloaded file data.

    Raises:
        ClientError: If the download fails due to AWS S3 API errors.
    """
    try:
        response = await asyncio.to_thread(
            s3_client.get_object,
            Bucket=bucket_name,
            Key=file_key
        )
        data = response["Body"].read()
        logger.info(f"Successfully downloaded file with key '{file_key}' from bucket '{bucket_name}'.")
        return BytesIO(data)
    except ClientError as e:
        logger.error(f"Failed to download object with key '{file_key}' from bucket '{bucket_name}': {e}")
        raise
