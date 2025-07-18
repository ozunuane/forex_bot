#!/usr/bin/env python3
"""
Test script for AI Backend Server
Verifies connectivity and functionality
"""

import requests
import json
import time
from datetime import datetime, timedelta

# Configuration
BACKEND_URL = "http://localhost:5001"
TIMEOUT = 10

def test_health_check():
    """Test health check endpoint"""
    print("=== Testing Health Check ===")
    try:
        response = requests.get(f"{BACKEND_URL}/health", timeout=TIMEOUT)
        if response.status_code == 200:
            data = response.json()
            print("✓ Health check successful")
            print(f"  Status: {data.get('status')}")
            print(f"  OpenAI Configured: {data.get('openai_configured')}")
            return True
        else:
            print(f"✗ Health check failed: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Health check error: {e}")
        return False

def test_stats():
    """Test stats endpoint"""
    print("\n=== Testing Stats Endpoint ===")
    try:
        response = requests.get(f"{BACKEND_URL}/stats", timeout=TIMEOUT)
        if response.status_code == 200:
            data = response.json()
            print("✓ Stats endpoint successful")
            print(f"  Total Symbols Analyzed: {data.get('total_symbols_analyzed')}")
            print(f"  OpenAI Model: {data.get('openai_model')}")
            return True
        else:
            print(f"✗ Stats failed: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Stats error: {e}")
        return False

def test_analysis():
    """Test analysis endpoint with sample data"""
    print("\n=== Testing Analysis Endpoint ===")
    
    # Generate sample price data
    sample_data = generate_sample_data()
    
    try:
        response = requests.post(
            f"{BACKEND_URL}/analyze",
            json=sample_data,
            timeout=TIMEOUT
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✓ Analysis successful")
            print(f"  Spike Threshold: {data.get('spike_threshold')} pips")
            print(f"  Cooldown: {data.get('cooldown_seconds')} seconds")
            print(f"  Stop Loss: {data.get('stop_loss_pips')} pips")
            print(f"  Take Profit: {data.get('take_profit_pips')} pips")
            print(f"  Risk Score: {data.get('risk_score')}/10")
            print(f"  Confidence: {data.get('confidence')}%")
            print(f"  Market Trend: {data.get('market_trend')}")
            return True
        else:
            print(f"✗ Analysis failed: HTTP {response.status_code}")
            print(f"  Response: {response.text}")
            return False
    except Exception as e:
        print(f"✗ Analysis error: {e}")
        return False

def generate_sample_data():
    """Generate sample price data for testing"""
    base_price = 10000.0
    price_data = []
    
    # Generate 100 price points with some spikes
    for i in range(100):
        timestamp = datetime.now() - timedelta(minutes=100-i)
        
        # Add some random spikes
        if i in [20, 45, 70]:  # Crash spikes
            price_change = -80 - (i * 2)
        elif i in [35, 60, 85]:  # Boom spikes
            price_change = 75 + (i * 2)
        else:
            price_change = (i % 10 - 5) * 2  # Small random changes
        
        current_price = base_price + price_change
        base_price = current_price
        
        price_point = {
            "timestamp": timestamp.isoformat(),
            "open": current_price - 1,
            "high": current_price + 2,
            "low": current_price - 2,
            "close": current_price
        }
        price_data.append(price_point)
    
    return {
        "symbol": "CRASH_1000",
        "price_data": price_data,
        "market_info": {
            "spread": 15,
            "volatility": 0.85
        }
    }

def test_recommendations():
    """Test getting cached recommendations"""
    print("\n=== Testing Recommendations Endpoint ===")
    try:
        response = requests.get(f"{BACKEND_URL}/recommendations/CRASH_1000", timeout=TIMEOUT)
        if response.status_code == 200:
            data = response.json()
            print("✓ Recommendations retrieved successfully")
            print(f"  Spikes Analyzed: {data.get('spikes_analyzed')}")
            print(f"  Last Analysis: {data.get('last_analysis')}")
            return True
        elif response.status_code == 404:
            print("ℹ No cached recommendations found (this is normal for first run)")
            return True
        else:
            print(f"✗ Recommendations failed: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Recommendations error: {e}")
        return False

def test_mt5_compatibility():
    """Test data format compatibility with MT5"""
    print("\n=== Testing MT5 Compatibility ===")
    
    # Test the exact format MT5 would send
    mt5_data = {
        "symbol": "CRASH_1000",
        "price_data": [
            {
                "timestamp": "2025-01-15T10:30:00",
                "open": 10000.0,
                "high": 10005.0,
                "low": 9995.0,
                "close": 10002.0
            },
            {
                "timestamp": "2025-01-15T10:31:00",
                "open": 10002.0,
                "high": 10008.0,
                "low": 9998.0,
                "close": 10006.0
            }
        ],
        "market_info": {
            "spread": 20,
            "volatility": 0.90
        }
    }
    
    try:
        response = requests.post(
            f"{BACKEND_URL}/analyze",
            json=mt5_data,
            timeout=TIMEOUT
        )
        
        if response.status_code == 200:
            print("✓ MT5 data format compatible")
            return True
        else:
            print(f"✗ MT5 compatibility failed: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ MT5 compatibility error: {e}")
        return False

def main():
    """Run all tests"""
    print("AI Backend Server Test Suite")
    print("=" * 40)
    print(f"Testing server at: {BACKEND_URL}")
    print(f"Test started at: {datetime.now()}")
    print()
    
    tests = [
        ("Health Check", test_health_check),
        ("Stats", test_stats),
        ("Analysis", test_analysis),
        ("Recommendations", test_recommendations),
        ("MT5 Compatibility", test_mt5_compatibility)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
        except Exception as e:
            print(f"✗ {test_name} failed with exception: {e}")
    
    print("\n" + "=" * 40)
    print(f"Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("✓ All tests passed! Backend server is ready for MT5 EA.")
    else:
        print("✗ Some tests failed. Please check the server configuration.")
    
    print(f"Test completed at: {datetime.now()}")

if __name__ == "__main__":
    main() 