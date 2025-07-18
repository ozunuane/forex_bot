#!/usr/bin/env python3
"""
MT5 Backend Connection Test
Simulates how the MT5 EA communicates with the production backend
"""

import urllib.request
import urllib.parse
import json
import time
import random

# Configuration - Same as MT5 EA
BACKEND_URL = "https://forex-bot-ffiu.onrender.com"
TIMEOUT = 15
SYMBOL = "CRASH_1000"

def make_request(url, method="GET", data=None):
    """Simulate MT5 WebRequest"""
    try:
        if data:
            data = json.dumps(data).encode('utf-8')
            req = urllib.request.Request(url, data=data, method=method)
            req.add_header('Content-Type', 'application/json')
        else:
            req = urllib.request.Request(url, method=method)
        
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            return response.read().decode('utf-8'), response.status
    except Exception as e:
        return str(e), 0

def test_backend_health():
    """Test backend health (MT5 EA startup)"""
    print("🔍 Testing Backend Health (EA Startup)...")
    
    response, status = make_request(f"{BACKEND_URL}/health")
    if status == 200:
        result = json.loads(response)
        print("✅ Backend health check passed")
        print(f"   Server: {result.get('server', 'Unknown')}")
        print(f"   Status: {result.get('status', 'Unknown')}")
        print(f"   Version: {result.get('version', 'Unknown')}")
        return True
    else:
        print(f"❌ Backend health check failed: {status}")
        return False

def simulate_mt5_price_data():
    """Simulate MT5 price data collection"""
    print("\n📊 Simulating MT5 Price Data Collection...")
    
    # Simulate 1 minute of price data (60 seconds)
    prices = []
    base_price = 1.0
    
    for i in range(60):
        # Simulate realistic price movements
        if random.random() < 0.05:  # 5% chance of significant movement
            if random.random() < 0.5:
                change = random.uniform(0.1, 0.3)  # 10-30% increase
            else:
                change = random.uniform(-0.2, -0.05)  # 5-20% decrease
        else:
            change = random.uniform(-0.02, 0.03)  # Small movements
        
        base_price = base_price * (1 + change)
        prices.append(max(0.1, base_price))
    
    print(f"   Collected {len(prices)} price points")
    print(f"   Price range: {min(prices):.3f} - {max(prices):.3f}")
    return prices

def test_backend_analysis():
    """Test backend analysis (MT5 EA analysis request)"""
    print(f"\n🧠 Testing Backend Analysis (EA Analysis Request)...")
    
    # Simulate MT5 price data
    prices = simulate_mt5_price_data()
    
    # Prepare payload like MT5 EA would
    payload = {
        "symbol": SYMBOL,
        "prices": prices,
        "timeframe": "1m"
    }
    
    print("   Sending analysis request to backend...")
    start_time = time.time()
    response, status = make_request(f"{BACKEND_URL}/analyze", method="POST", data=payload)
    end_time = time.time()
    
    if status == 200:
        result = json.loads(response)
        print("✅ Backend analysis successful")
        print(f"   Response time: {end_time - start_time:.3f}s")
        print(f"   Success: {result.get('success', False)}")
        print(f"   Spikes detected: {result.get('spikes_detected', 0)}")
        
        # Show recommendations
        recommendations = result.get('recommendations', {})
        if recommendations:
            print(f"   Spike threshold: {recommendations.get('spike_threshold', 0)} pips")
            print(f"   Stop loss: {recommendations.get('stop_loss_pips', 0)} pips")
            print(f"   Take profit: {recommendations.get('take_profit_pips', 0)} pips")
            print(f"   Confidence: {recommendations.get('confidence', 0):.1f}%")
            print(f"   Risk score: {recommendations.get('risk_score', 0)}/10")
        
        return True
    else:
        print(f"❌ Backend analysis failed: {status}")
        print(f"   Response: {response}")
        return False

def test_recommendations_endpoint():
    """Test recommendations endpoint (MT5 EA decision making)"""
    print(f"\n💡 Testing Recommendations (EA Decision Making)...")
    
    response, status = make_request(f"{BACKEND_URL}/recommendations/{SYMBOL}")
    if status == 200:
        result = json.loads(response)
        print("✅ Recommendations received")
        
        recommendations = result.get('recommendations', {})
        if recommendations:
            print(f"   Spike threshold: {recommendations.get('spike_threshold', 0)} pips")
            print(f"   Cooldown: {recommendations.get('cooldown_seconds', 0)} seconds")
            print(f"   Stop loss: {recommendations.get('stop_loss_pips', 0)} pips")
            print(f"   Take profit: {recommendations.get('take_profit_pips', 0)} pips")
            print(f"   Confidence: {recommendations.get('confidence', 0):.1f}%")
            print(f"   Market trend: {recommendations.get('market_trend', 'Unknown')}")
            
            # Simulate MT5 EA decision making
            confidence = recommendations.get('confidence', 0)
            risk_score = recommendations.get('risk_score', 5)
            
            print(f"\n   🤖 MT5 EA Decision Simulation:")
            if confidence > 70 and risk_score < 7:
                print("   ✅ High confidence, low risk - Ready to trade")
            elif confidence > 50:
                print("   ⚠️  Moderate confidence - Consider trading with caution")
            else:
                print("   ⏸️  Low confidence - Wait for better conditions")
        
        return True
    else:
        print(f"❌ Recommendations failed: {status}")
        return False

def test_error_handling():
    """Test error handling (MT5 EA error scenarios)"""
    print(f"\n🛡️  Testing Error Handling (EA Error Scenarios)...")
    
    # Test with invalid data
    invalid_payload = {
        "symbol": "INVALID_SYMBOL",
        "prices": [],
        "timeframe": "invalid"
    }
    
    response, status = make_request(f"{BACKEND_URL}/analyze", method="POST", data=invalid_payload)
    if status == 400:
        print("✅ Error handling working correctly")
        print("   Backend properly rejected invalid data")
        return True
    else:
        print(f"❌ Expected error, got status {status}")
        return False

def test_performance():
    """Test performance (MT5 EA real-time requirements)"""
    print(f"\n⚡ Testing Performance (EA Real-time Requirements)...")
    
    # Test multiple requests to simulate real-time usage
    response_times = []
    
    for i in range(3):
        start_time = time.time()
        response, status = make_request(f"{BACKEND_URL}/health")
        end_time = time.time()
        
        if status == 200:
            response_times.append(end_time - start_time)
            print(f"   Request {i+1}: {response_times[-1]:.3f}s")
        else:
            print(f"   Request {i+1}: Failed")
    
    if response_times:
        avg_time = sum(response_times) / len(response_times)
        print(f"   Average response time: {avg_time:.3f}s")
        
        if avg_time < 2.0:
            print("✅ Performance is excellent for real-time trading")
        elif avg_time < 5.0:
            print("✅ Performance is acceptable for real-time trading")
        else:
            print("⚠️  Performance may be too slow for real-time trading")
        
        return True
    else:
        print("❌ No successful requests to measure performance")
        return False

def main():
    """Run MT5 backend connection tests"""
    print("🚀 MT5 Backend Connection Test")
    print("=" * 60)
    print(f"Testing connection to: {BACKEND_URL}")
    print(f"Timeout: {TIMEOUT} seconds")
    print(f"Symbol: {SYMBOL}")
    print("=" * 60)
    
    tests = [
        ("Backend Health", test_backend_health),
        ("Backend Analysis", test_backend_analysis),
        ("Recommendations", test_recommendations_endpoint),
        ("Error Handling", test_error_handling),
        ("Performance", test_performance)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n{'='*25} {test_name} {'='*25}")
        if test_func():
            passed += 1
        time.sleep(1)
    
    print("\n" + "=" * 60)
    print(f"📋 MT5 Backend Connection Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All MT5 backend connection tests passed!")
        print("\n✅ Your MT5 EA is ready to connect to the production backend!")
        print("\n📋 Next Steps:")
        print("   1. Compile CrashBoomScalper_Backend.mq5 in MetaEditor")
        print("   2. Attach to CRASH_1000 or BOOM_1000 chart")
        print("   3. Configure parameters as shown in MT5_Production_Config.txt")
        print("   4. Enable AutoTrading")
        print("   5. Monitor the EA logs")
        print(f"\n🌐 Backend URL: {BACKEND_URL}")
    else:
        print("⚠️  Some connection tests failed.")
        print("   Check your internet connection and backend server status.")
    
    print("=" * 60)

if __name__ == "__main__":
    main() 