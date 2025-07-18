#!/usr/bin/env python3
"""
AI Backend Server for MT5 Crash/Boom Scalping EA (Simplified Version)
Handles OpenAI integration and basic analysis without pandas/numpy dependencies
"""

import os
import json
import logging
import requests
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from flask_cors import CORS
from typing import Dict, List, Optional, Tuple
import threading
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('ai_backend.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for MT5 client

# Load environment variables from config file
def load_config():
    try:
        with open('config.env', 'r') as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    key, value = line.strip().split('=', 1)
                    os.environ[key] = value
    except FileNotFoundError:
        pass  # Use default values if config file doesn't exist

# Load configuration
load_config()

# Configuration
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY', 'your-openai-api-key-here')
OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-4')
SERVER_PORT = int(os.getenv('SERVER_PORT', 5001))
SERVER_HOST = os.getenv('SERVER_HOST', '0.0.0.0')

# Global storage for analysis results
analysis_cache = {}
last_analysis_time = {}
analysis_lock = threading.Lock()

def calculate_mean(values):
    """Simple mean calculation without numpy"""
    if not values:
        return 0
    return sum(values) / len(values)

class SpikeAnalyzer:
    """Handles spike detection and analysis"""
    
    def __init__(self):
        self.min_spike_size = 50  # pips
        self.spike_threshold_percent = 1.0
        
    def detect_spikes(self, price_data: List[float]) -> List[Dict]:
        """Detect spikes in price data"""
        spikes = []
        
        if len(price_data) < 3:
            return spikes
            
        for i in range(1, len(price_data) - 1):
            current_price = price_data[i]
            prev_price = price_data[i-1]
            next_price = price_data[i+1]
            
            # Calculate price changes
            change_to_current = abs(current_price - prev_price)
            change_from_current = abs(next_price - current_price)
            
            # Detect spike (sudden large movement followed by reversal)
            if (change_to_current > self.min_spike_size and 
                change_from_current > change_to_current * 0.5):
                
                spike = {
                    'timestamp': datetime.now().isoformat(),
                    'price': current_price,
                    'spike_size': change_to_current,
                    'is_crash': current_price < prev_price,
                    'recovery_time': self._calculate_recovery_time(price_data, i),
                    'max_retracement': self._calculate_max_retracement(price_data, i)
                }
                spikes.append(spike)
                
        return spikes
    
    def _calculate_recovery_time(self, price_data: List[float], spike_index: int) -> int:
        """Calculate time to recover from spike"""
        spike_price = price_data[spike_index]
        
        for i in range(spike_index + 1, min(spike_index + 100, len(price_data))):
            if abs(price_data[i] - spike_price) < self.min_spike_size * 0.1:
                return 60  # Default 1 minute recovery time
        
        return 300  # Default 5 minutes if no recovery detected
    
    def _calculate_max_retracement(self, price_data: List[float], spike_index: int) -> float:
        """Calculate maximum retracement after spike"""
        spike_price = price_data[spike_index]
        max_retracement = 0
        
        for i in range(spike_index + 1, min(spike_index + 50, len(price_data))):
            retracement = abs(price_data[i] - spike_price)
            max_retracement = max(max_retracement, retracement)
            
        return max_retracement

class AIAnalyzer:
    """Handles OpenAI integration and analysis"""
    
    def __init__(self):
        self.api_key = OPENAI_API_KEY
        self.model = OPENAI_MODEL
        self.base_url = "https://api.openai.com/v1/chat/completions"
        
    def analyze_spikes(self, spikes: List[Dict], market_data: Dict) -> Dict:
        """Analyze spikes using OpenAI"""
        if not spikes:
            return self._get_default_recommendations()
            
        # Prepare analysis prompt
        prompt = self._create_analysis_prompt(spikes, market_data)
        
        try:
            response = self._call_openai(prompt)
            return self._parse_ai_response(response)
        except Exception as e:
            logger.error(f"AI analysis failed: {e}")
            return self._get_default_recommendations()
    
    def _create_analysis_prompt(self, spikes: List[Dict], market_data: Dict) -> str:
        """Create analysis prompt for OpenAI"""
        
        # Calculate statistics without numpy
        crash_spikes = [s for s in spikes if s['is_crash']]
        boom_spikes = [s for s in spikes if not s['is_crash']]
        
        crash_sizes = [s['spike_size'] for s in crash_spikes]
        boom_sizes = [s['spike_size'] for s in boom_spikes]
        recovery_times = [s['recovery_time'] for s in spikes]
        
        avg_crash_size = calculate_mean(crash_sizes)
        avg_boom_size = calculate_mean(boom_sizes)
        avg_recovery_time = calculate_mean(recovery_times)
        
        prompt = f"""
You are an expert forex trading analyst specializing in Crash/Boom synthetic indices. Analyze the following spike data and provide trading recommendations.

MARKET DATA:
- Symbol: {market_data.get('symbol', 'Unknown')}
- Current Price: {market_data.get('current_price', 0)}
- Spread: {market_data.get('spread', 0)}
- Volatility: {market_data.get('volatility', 0)}

SPIKE ANALYSIS:
- Total Spikes: {len(spikes)}
- Crash Spikes: {len(crash_spikes)}
- Boom Spikes: {len(boom_spikes)}
- Average Crash Size: {avg_crash_size:.2f} pips
- Average Boom Size: {avg_boom_size:.2f} pips
- Average Recovery Time: {avg_recovery_time:.0f} seconds

RECENT SPIKE DETAILS (last 10):
{self._format_spike_details(spikes[-10:])}

Please provide recommendations in the following JSON format:
{{
    "spike_threshold": <optimal spike size threshold in pips>,
    "cooldown_seconds": <recommended cooldown period in seconds>,
    "stop_loss_pips": <suggested stop loss in pips>,
    "take_profit_pips": <suggested take profit in pips>,
    "risk_score": <risk assessment 1-10>,
    "confidence": <confidence level 0-100>,
    "market_trend": "<current market trend analysis>",
    "reasoning": "<detailed reasoning for recommendations>"
}}

Focus on:
1. Optimal spike size threshold for entry
2. Appropriate cooldown periods
3. Risk management parameters
4. Current market conditions
5. Historical pattern analysis
"""
        return prompt
    
    def _format_spike_details(self, spikes: List[Dict]) -> str:
        """Format spike details for prompt"""
        details = []
        for spike in spikes:
            direction = "CRASH" if spike['is_crash'] else "BOOM"
            details.append(
                f"- {direction}: {spike['spike_size']:.1f} pips, "
                f"Recovery: {spike['recovery_time']}s, "
                f"Max Retrace: {spike['max_retracement']:.1f} pips"
            )
        return "\n".join(details)
    
    def _call_openai(self, prompt: str) -> str:
        """Call OpenAI API"""
        if self.api_key == 'your-openai-api-key-here':
            logger.warning("OpenAI API key not configured, using default recommendations")
            return ""
            
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        data = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": "You are an expert forex trading analyst."},
                {"role": "user", "content": prompt}
            ],
            "max_tokens": 1000,
            "temperature": 0.3
        }
        
        try:
            response = requests.post(self.base_url, headers=headers, json=data, timeout=30)
            response.raise_for_status()
            result = response.json()
            return result['choices'][0]['message']['content']
        except Exception as e:
            logger.error(f"OpenAI API call failed: {e}")
            return ""
    
    def _parse_ai_response(self, response: str) -> Dict:
        """Parse AI response"""
        if not response:
            return self._get_default_recommendations()
            
        try:
            # Try to extract JSON from response
            start = response.find('{')
            end = response.rfind('}') + 1
            if start != -1 and end != 0:
                json_str = response[start:end]
                return json.loads(json_str)
        except:
            pass
            
        return self._get_default_recommendations()
    
    def _get_default_recommendations(self) -> Dict:
        """Get default recommendations when AI is not available"""
        return {
            "spike_threshold": 50,
            "cooldown_seconds": 60,
            "stop_loss_pips": 30,
            "take_profit_pips": 100,
            "risk_score": 5,
            "confidence": 70,
            "market_trend": "Neutral - using default parameters",
            "reasoning": "Default conservative parameters applied due to limited data or AI unavailability"
        }

# Initialize analyzers
spike_analyzer = SpikeAnalyzer()
ai_analyzer = AIAnalyzer()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "server": "AI Backend Server",
        "version": "1.0.0"
    })

@app.route('/analyze', methods=['POST'])
def analyze_market():
    """Analyze market data and provide recommendations"""
    try:
        # Debug: Log request details
        logger.info(f"Request method: {request.method}")
        logger.info(f"Request headers: {dict(request.headers)}")
        logger.info(f"Request content type: {request.content_type}")
        logger.info(f"Request content length: {request.content_length}")
        
        # Try to get raw data first
        raw_data = request.get_data()
        logger.info(f"Raw request data: {raw_data[:200]}...")  # First 200 chars
        
        # Clean the data by removing null terminators and other invalid characters
        cleaned_data = raw_data.decode('utf-8', errors='ignore').rstrip('\x00')
        logger.info(f"Cleaned data: {cleaned_data[:200]}...")  # First 200 chars
        
        # Try to parse JSON
        try:
            # First try the cleaned data
            data = json.loads(cleaned_data)
            logger.info(f"Parsed JSON data from cleaned data: {data}")
        except Exception as json_error:
            logger.error(f"JSON parsing failed with cleaned data: {json_error}")
            # Fallback to Flask's built-in JSON parsing
            try:
                data = request.get_json()
                logger.info(f"Parsed JSON data from Flask: {data}")
            except Exception as flask_json_error:
                logger.error(f"Flask JSON parsing also failed: {flask_json_error}")
                logger.error(f"Raw data that failed to parse: {raw_data}")
                return jsonify({
                    'success': False,
                    'error': f'Invalid JSON: {str(json_error)}'
                }), 400
        
        symbol = data.get('symbol', 'CRASH_1000')
        price_data = data.get('price_data', [])
        
        logger.info(f"Received analysis request for {symbol} with {len(price_data)} price points")
        
        # Detect spikes
        spikes = spike_analyzer.detect_spikes(price_data)
        logger.info(f"Detected {len(spikes)} spikes")
        
        # Prepare market data
        market_data = {
            'symbol': symbol,
            'current_price': price_data[-1] if price_data else 0,
            'spread': data.get('spread', 0),
            'volatility': data.get('volatility', 0)
        }
        
        # Get AI analysis
        recommendations = ai_analyzer.analyze_spikes(spikes, market_data)
        
        # Cache results
        with analysis_lock:
            analysis_cache[symbol] = {
                'recommendations': recommendations,
                'spikes': spikes,
                'timestamp': datetime.now(),
                'price_data_count': len(price_data)
            }
            last_analysis_time[symbol] = datetime.now()
        
        logger.info(f"Analysis completed for {symbol}")
        
        # Return a simplified format that's easier for MQL5 to parse
        response_data = {
            'success': True,
            'symbol': symbol,
            'spikes_detected': len(spikes),
            'spike_threshold': recommendations['spike_threshold'],
            'cooldown_seconds': recommendations['cooldown_seconds'],
            'stop_loss_pips': recommendations['stop_loss_pips'],
            'take_profit_pips': recommendations['take_profit_pips'],
            'risk_score': recommendations['risk_score'],
            'confidence': recommendations['confidence'],
            'market_trend': recommendations['market_trend'],
            'reasoning': recommendations['reasoning'],
            'timestamp': datetime.now().isoformat()
        }
        
        return jsonify(response_data)
        
    except Exception as e:
        logger.error(f"Analysis error: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/recommendations/<symbol>', methods=['GET'])
def get_recommendations(symbol):
    """Get cached recommendations for a symbol"""
    with analysis_lock:
        if symbol in analysis_cache:
            return jsonify(analysis_cache[symbol])
        else:
            return jsonify({'error': 'No analysis found for symbol'}), 404

@app.route('/stats', methods=['GET'])
def get_stats():
    """Get server statistics"""
    with analysis_lock:
        stats = {
            'total_analyses': len(analysis_cache),
            'symbols_analyzed': list(analysis_cache.keys()),
            'last_analysis': {k: v.isoformat() for k, v in last_analysis_time.items()},
            'server_uptime': 'running',
            'timestamp': datetime.now().isoformat()
        }
        return jsonify(stats)

@app.route('/clear_cache', methods=['POST'])
def clear_cache():
    """Clear analysis cache"""
    with analysis_lock:
        analysis_cache.clear()
        last_analysis_time.clear()
    return jsonify({'success': True, 'message': 'Cache cleared'})

if __name__ == '__main__':
    logger.info(f"Starting AI Backend Server on {SERVER_HOST}:{SERVER_PORT}")
    logger.info(f"OpenAI Model: {OPENAI_MODEL}")
    
    if OPENAI_API_KEY == 'your-openai-api-key-here':
        logger.warning("Please set OPENAI_API_KEY environment variable")
    
    app.run(host=SERVER_HOST, port=SERVER_PORT, debug=False) 