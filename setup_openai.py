#!/usr/bin/env python3
"""
OpenAI API Key Setup Script
Helps configure the OpenAI API key for the backend server
"""

import os
import getpass

def setup_openai_key():
    """Setup OpenAI API key"""
    print("=== OpenAI API Key Setup ===")
    print()
    
    # Check if config file exists
    config_file = 'config.env'
    
    if os.path.exists(config_file):
        print("✓ Configuration file found: config.env")
        
        # Read current config
        current_key = None
        with open(config_file, 'r') as f:
            for line in f:
                if line.startswith('OPENAI_API_KEY='):
                    current_key = line.split('=', 1)[1].strip()
                    break
        
        if current_key and current_key != 'your-openai-api-key-here':
            print(f"Current API key: {current_key[:10]}...{current_key[-4:]}")
            response = input("Do you want to update it? (y/n): ").lower()
            if response != 'y':
                print("Keeping existing API key.")
                return
    else:
        print("Creating new configuration file...")
    
    print()
    print("Please enter your OpenAI API key:")
    print("(You can get one from: https://platform.openai.com/api-keys)")
    print()
    
    # Get API key securely
    api_key = getpass.getpass("OpenAI API Key: ").strip()
    
    if not api_key:
        print("No API key provided. Skipping setup.")
        return
    
    if api_key == 'your-openai-api-key-here':
        print("Please enter your actual API key, not the placeholder.")
        return
    
    # Validate API key format (basic check)
    if not api_key.startswith('sk-'):
        print("Warning: API key doesn't start with 'sk-'. Please check your key.")
        response = input("Continue anyway? (y/n): ").lower()
        if response != 'y':
            return
    
    # Write to config file
    config_content = f"""# OpenAI Configuration
OPENAI_API_KEY={api_key}

# Server Configuration
SERVER_PORT=5001
SERVER_HOST=0.0.0.0
OPENAI_MODEL=gpt-4
"""
    
    with open(config_file, 'w') as f:
        f.write(config_content)
    
    print()
    print("✓ API key saved to config.env")
    print("✓ Configuration complete!")
    print()
    print("To restart the server with the new API key:")
    print("1. Stop the current server (Ctrl+C)")
    print("2. Run: source venv/bin/activate && python3 ai_backend_server.py")
    print()

def test_openai_connection():
    """Test OpenAI connection"""
    print("=== Testing OpenAI Connection ===")
    
    # Load config
    if os.path.exists('config.env'):
        with open('config.env', 'r') as f:
            for line in f:
                if line.startswith('OPENAI_API_KEY='):
                    api_key = line.split('=', 1)[1].strip()
                    break
            else:
                api_key = None
    else:
        api_key = None
    
    if not api_key or api_key == 'your-openai-api-key-here':
        print("No valid API key found. Please run setup first.")
        return False
    
    try:
        import requests
        
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        data = {
            "model": "gpt-4",
            "messages": [
                {"role": "user", "content": "Hello"}
            ],
            "max_tokens": 10
        }
        
        response = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers=headers,
            json=data,
            timeout=10
        )
        
        if response.status_code == 200:
            print("✓ OpenAI connection successful!")
            return True
        else:
            print(f"✗ OpenAI connection failed: HTTP {response.status_code}")
            print(f"  Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"✗ OpenAI connection error: {e}")
        return False

def main():
    """Main setup function"""
    print("AI Backend Server - OpenAI Setup")
    print("=" * 40)
    print()
    
    while True:
        print("Options:")
        print("1. Setup OpenAI API Key")
        print("2. Test OpenAI Connection")
        print("3. Exit")
        print()
        
        choice = input("Enter your choice (1-3): ").strip()
        
        if choice == '1':
            setup_openai_key()
        elif choice == '2':
            test_openai_connection()
        elif choice == '3':
            print("Setup complete!")
            break
        else:
            print("Invalid choice. Please try again.")
        
        print()

if __name__ == "__main__":
    main() 