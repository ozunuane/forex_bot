#!/usr/bin/env python3
"""
AI Backend Server for MT5 Crash/Boom Scalping EA
Handles OpenAI integration, historical analysis, and parameter optimization
"""

import os
import json
import logging
import requests
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import numpy as np
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

class SpikeAnalyzer:
    """Handles spike detection and analysis"""
    
    def __init__(self):
        self.min_spike_size = 50  # pips
        self.spike_threshold_percent = 1.0
        
    def detect_spikes(self, price_data: List[Dict]) -> List[Dict]:
        """Detect spikes in price data"""
        spikes = []
        
        if len(price_data) < 3:
            return spikes
            
        for i in range(1, len(price_data) - 1):
            current = price_data[i]
            prev = price_data[i-1]
            next_price = price_data[i+1]
            
            # Calculate price changes
            change_to_current = abs(current['close'] - prev['close'])
            change_from_current = abs(next_price['close'] - current['close'])
            
            # Detect spike (sudden large movement followed by reversal)
            if (change_to_current > self.min_spike_size and 
                change_from_current > change_to_current * 0.5):
                
                spike = {
                    'timestamp': current['timestamp'],
                    'price': current['close'],
                    'spike_size': change_to_current,
                    'is_crash': current['close'] < prev['close'],
                    'recovery_time': self._calculate_recovery_time(price_data, i),
                    'max_retracement': self._calculate_max_retracement(price_data, i)
                }
                spikes.append(spike)
                
        return spikes
    
    def _calculate_recovery_time(self, price_data: List[Dict], spike_index: int) -> int:
        """Calculate time to recover from spike"""
        spike_price = price_data[spike_index]['close']
        spike_time = price_data[spike_index]['timestamp']
        
        for i in range(spike_index + 1, min(spike_index + 100, len(price_data))):
            if abs(price_data[i]['close'] - spike_price) < self.min_spike_size * 0.1:
                return int((price_data[i]['timestamp'] - spike_time).total_seconds())
        
        return 300  # Default 5 minutes if no recovery detected
    
    def _calculate_max_retracement(self, price_data: List[Dict], spike_index: int) -> float:
        """Calculate maximum retracement after spike"""
        spike_price = price_data[spike_index]['close']
        max_retracement = 0
        
        for i in range(spike_index + 1, min(spike_index + 50, len(price_data))):
            retracement = abs(price_data[i]['close'] - spike_price)
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
        
        # Calculate statistics
        crash_spikes = [s for s in spikes if s['is_crash']]
        boom_spikes = [s for s in spikes if not s['is_crash']]
        
        avg_crash_size = np.mean([s['spike_size'] for s in crash_spikes]) if crash_spikes else 0
        avg_boom_size = np.mean([s['spike_size'] for s in boom_spikes]) if boom_spikes else 0
        avg_recovery_time = np.mean([s['recovery_time'] for s in spikes]) if spikes else 0
        
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
                f"Retracement: {spike['max_retracement']:.1f} pips"
            )
        return "\n".join(details)
    
    def _call_openai(self, prompt: str) -> str:
        """Call OpenAI API"""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        data = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": "You are an expert forex trading analyst. Provide concise, actionable recommendations."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.3,
            "max_tokens": 1000
        }
        
        response = requests.post(self.base_url, headers=headers, json=data, timeout=30)
        response.raise_for_status()
        
        result = response.json()
        return result['choices'][0]['message']['content']
    
    def _parse_ai_response(self, response: str) -> Dict:
        """Parse AI response and extract recommendations"""
        try:
            # Extract JSON from response
            start = response.find('{')
            end = response.rfind('}') + 1
            json_str = response[start:end]
            
            recommendations = json.loads(json_str)
            
            # Validate and set defaults
            return {
                "spike_threshold": float(recommendations.get("spike_threshold", 50)),
                "cooldown_seconds": int(recommendations.get("cooldown_seconds", 300)),
                "stop_loss_pips": float(recommendations.get("stop_loss_pips", 20)),
                "take_profit_pips": float(recommendations.get("take_profit_pips", 40)),
                "risk_score": float(recommendations.get("risk_score", 5)),
                "confidence": float(recommendations.get("confidence", 70)),
                "market_trend": recommendations.get("market_trend", "Neutral"),
                "reasoning": recommendations.get("reasoning", "Analysis unavailable"),
                "timestamp": datetime.now().isoformat()
            }
        except Exception as e:
            logger.error(f"Failed to parse AI response: {e}")
            return self._get_default_recommendations()
    
    def _get_default_recommendations(self) -> Dict:
        """Get default recommendations when AI analysis fails"""
        return {
            "spike_threshold": 50.0,
            "cooldown_seconds": 300,
            "stop_loss_pips": 20.0,
            "take_profit_pips": 40.0,
            "risk_score": 5.0,
            "confidence": 50.0,
            "market_trend": "Neutral",
            "reasoning": "Using default parameters due to analysis failure",
            "timestamp": datetime.now().isoformat()
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
        "openai_configured": bool(OPENAI_API_KEY and OPENAI_API_KEY != 'your-openai-api-key-here')
    })

@app.route('/analyze', methods=['POST'])
def analyze_market():
    """Main analysis endpoint for MT5 EA"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({"error": "No data provided"}), 400
        
        symbol = data.get('symbol', 'Unknown')
        price_data = data.get('price_data', [])
        market_info = data.get('market_info', {})
        
        logger.info(f"Received analysis request for {symbol} with {len(price_data)} price points")
        
        # Detect spikes
        spikes = spike_analyzer.detect_spikes(price_data)
        logger.info(f"Detected {len(spikes)} spikes")
        
        # Perform AI analysis
        recommendations = ai_analyzer.analyze_spikes(spikes, {
            'symbol': symbol,
            'current_price': price_data[-1]['close'] if price_data else 0,
            'spread': market_info.get('spread', 0),
            'volatility': market_info.get('volatility', 0)
        })
        
        # Cache results
        with analysis_lock:
            analysis_cache[symbol] = {
                'recommendations': recommendations,
                'spikes_analyzed': len(spikes),
                'last_analysis': datetime.now().isoformat()
            }
            last_analysis_time[symbol] = datetime.now()
        
        logger.info(f"Analysis completed for {symbol}")
        return jsonify(recommendations)
        
    except Exception as e:
        logger.error(f"Analysis error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/recommendations/<symbol>', methods=['GET'])
def get_recommendations(symbol):
    """Get cached recommendations for a symbol"""
    with analysis_lock:
        if symbol in analysis_cache:
            return jsonify(analysis_cache[symbol])
        else:
            return jsonify({"error": "No analysis available for symbol"}), 404

@app.route('/stats', methods=['GET'])
def get_stats():
    """Get server statistics"""
    with analysis_lock:
        stats = {
            "total_symbols_analyzed": len(analysis_cache),
            "last_analyses": {},
            "server_uptime": "running",
            "openai_model": OPENAI_MODEL
        }
        
        for symbol, data in analysis_cache.items():
            stats["last_analyses"][symbol] = {
                "spikes_analyzed": data["spikes_analyzed"],
                "last_analysis": data["last_analysis"]
            }
        
        return jsonify(stats)

@app.route('/clear_cache', methods=['POST'])
def clear_cache():
    """Clear analysis cache"""
    with analysis_lock:
        analysis_cache.clear()
        last_analysis_time.clear()
    logger.info("Analysis cache cleared")
    return jsonify({"message": "Cache cleared successfully"})

if __name__ == '__main__':
    logger.info(f"Starting AI Backend Server on {SERVER_HOST}:{SERVER_PORT}")
    logger.info(f"OpenAI Model: {OPENAI_MODEL}")
    
    if OPENAI_API_KEY == 'your-openai-api-key-here':
        logger.warning("Please set OPENAI_API_KEY environment variable")
    
    app.run(host=SERVER_HOST, port=SERVER_PORT, debug=False, threaded=True) 