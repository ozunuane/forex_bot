#!/usr/bin/env python3
"""
Test MT5 EA Communication with Backend Server
Simulates the exact data format MT5 would send
"""

import requests
import json
from datetime import datetime, timedelta

# Configuration
BACKEND_URL = "http://localhost:5001"

def test_mt5_data_format():
    """Test the exact data format MT5 EA would send"""
    print("=== Testing MT5 EA Communication ===")
    
    # Simulate MT5 price data collection (last 1000 M1 bars)
    price_data = []
    base_price = 10000.0
    
    # Generate realistic price data with spikes
    for i in range(1000):
        timestamp = datetime.now() - timedelta(minutes=1000-i)
        
        # Add some realistic spikes
        if i in [200, 450, 700]:  # Crash spikes
            price_change = -120 - (i % 50)
        elif i in [350, 600, 850]:  # Boom spikes
            price_change = 110 + (i % 50)
        else:
            # Normal price movement
            price_change = (i % 20 - 10) * 0.5
        
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
    
    # Simulate MT5 market info
    market_info = {
        "spread": 15,
        "volatility": 0.85
    }
    
    # Create the exact request MT5 would send
    mt5_request = {
        "symbol": "CRASH_1000",
        "price_data": price_data,
        "market_info": market_info
    }
    
    print(f"Sending {len(price_data)} price points to backend...")
    
    try:
        response = requests.post(
            f"{BACKEND_URL}/analyze",
            json=mt5_request,
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✓ MT5 communication successful!")
            print(f"  Symbol: CRASH_1000")
            print(f"  Price Points Sent: {len(price_data)}")
            print(f"  AI Recommendations:")
            print(f"    - Spike Threshold: {data.get('spike_threshold')} pips")
            print(f"    - Cooldown: {data.get('cooldown_seconds')} seconds")
            print(f"    - Stop Loss: {data.get('stop_loss_pips')} pips")
            print(f"    - Take Profit: {data.get('take_profit_pips')} pips")
            print(f"    - Risk Score: {data.get('risk_score')}/10")
            print(f"    - Confidence: {data.get('confidence')}%")
            print(f"    - Market Trend: {data.get('market_trend')}")
            print(f"    - Reasoning: {data.get('reasoning')[:100]}...")
            
            return True
        else:
            print(f"✗ Communication failed: HTTP {response.status_code}")
            print(f"  Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"✗ Communication error: {e}")
        return False

def test_backend_stats():
    """Test getting backend statistics"""
    print("\n=== Testing Backend Statistics ===")
    
    try:
        response = requests.get(f"{BACKEND_URL}/stats", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✓ Backend statistics retrieved")
            print(f"  Total Symbols Analyzed: {data.get('total_symbols_analyzed')}")
            print(f"  OpenAI Model: {data.get('openai_model')}")
            
            if 'last_analyses' in data:
                for symbol, analysis in data['last_analyses'].items():
                    print(f"  {symbol}: {analysis['spikes_analyzed']} spikes analyzed")
            
            return True
        else:
            print(f"✗ Stats failed: HTTP {response.status_code}")
            return False
            
    except Exception as e:
        print(f"✗ Stats error: {e}")
        return False

def main():
    """Run MT5 communication tests"""
    print("MT5 EA Communication Test")
    print("=" * 40)
    
    tests = [
        ("MT5 Data Format", test_mt5_data_format),
        ("Backend Statistics", test_backend_stats)
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
        print("✓ All MT5 communication tests passed!")
        print("✓ Backend server is ready for MT5 EA integration")
        print("\nNext steps:")
        print("1. Compile CrashBoomScalper_Backend.mq5 in MetaEditor")
        print("2. Enable WebRequest in MT5 (Tools → Options → Expert Advisors)")
        print("3. Add 'localhost:5001' to allowed URLs")
        print("4. Attach the EA to a chart")
    else:
        print("✗ Some tests failed. Please check the configuration.")
    
    print(f"Test completed at: {datetime.now()}")

if __name__ == "__main__":
    main() 