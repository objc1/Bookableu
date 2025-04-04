#!/bin/bash
PEM_FILE=${PEM_FILE:-"$HOME/.ssh/bookreader-key.pem"}
EC2_IP=${EC2_IP:-"18.214.98.248"}

# Check if .pem file exists
if [ ! -f "$PEM_FILE" ]; then
    echo "Error: .pem file not found at $PEM_FILE"
    echo "Set PEM_FILE environment variable or place your-key.pem in this directory"
    exit 1
fi

# Upload files to EC2 (including app directory)
echo "Uploading files to EC2..."
scp -r -i "$PEM_FILE" app/ requirements.txt .gitignore ec2-user@$EC2_IP:/home/ec2-user/ || {
    echo "Error: SCP upload failed"
    exit 1
}

# Setup virtual environment and install requirements on EC2
echo "Setting up virtual environment and installing requirements..."
ssh -i "$PEM_FILE" ec2-user@$EC2_IP "cd /home/ec2-user && \
    rm -rf venv && \
    python3 -m venv venv && \
    source venv/bin/activate && \
    pip install --upgrade pip && \
    pip install -r requirements.txt && \
    sudo chown -R ec2-user:ec2-user venv" || {
    echo "Error: Failed to setup virtual environment and install requirements"
    exit 1
}

# Restart FastAPI service on EC2
echo "Restarting FastAPI service..."
ssh -i "$PEM_FILE" ec2-user@$EC2_IP "sudo systemctl restart fastapi" || {
    echo "Error: SSH command failed"
    exit 1
}

# Verify service status
echo "Checking service status..."
ssh -i "$PEM_FILE" ec2-user@$EC2_IP "sudo systemctl status fastapi | grep Active"

echo "Deployment completed successfully!"