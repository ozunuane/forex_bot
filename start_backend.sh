#!/bin/bash

# AI Backend Server Startup Script
# For MT5 Crash/Boom Scalping EA

echo "=== AI Backend Server Startup ==="
echo "Starting at: $(date)"
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed. Please install Python 3.8+ first."
    exit 1
fi

echo "Python version: $(python3 --version)"

# Check if virtual environment exists, create if not
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install/upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "Installing requirements..."
pip install -r requirements_backend.txt

# Check if OpenAI API key is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo ""
    echo "WARNING: OPENAI_API_KEY environment variable is not set."
    echo "Please set it before starting the server:"
    echo "export OPENAI_API_KEY='your-openai-api-key-here'"
    echo ""
    echo "Or create a .env file with:"
    echo "OPENAI_API_KEY=your-openai-api-key-here"
    echo ""
fi

# Set default environment variables if not set
export SERVER_PORT=${SERVER_PORT:-5000}
export SERVER_HOST=${SERVER_HOST:-0.0.0.0}
export OPENAI_MODEL=${OPENAI_MODEL:-gpt-4}

echo ""
echo "Configuration:"
echo "- Server Host: $SERVER_HOST"
echo "- Server Port: $SERVER_PORT"
echo "- OpenAI Model: $OPENAI_MODEL"
echo "- OpenAI API Key: ${OPENAI_API_KEY:0:10}..."  # Show first 10 chars only
echo ""

# Start the server
echo "Starting AI Backend Server..."
echo "Server will be available at: http://$SERVER_HOST:$SERVER_PORT"
echo "Press Ctrl+C to stop the server"
echo ""

python3 ai_backend_server.py 