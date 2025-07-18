# AI Backend Server for MT5 Crash/Boom Scalping EA

This system provides a powerful AI-powered backend server that analyzes market data and provides trading recommendations to your MT5 Expert Advisor. By moving AI analysis to a separate server, we eliminate the limitations of MT5's WebRequest functionality and provide more robust, scalable AI integration.

## 🚀 Features

- **Advanced Spike Detection**: Sophisticated algorithms to identify crash and boom spikes
- **OpenAI Integration**: Leverages GPT-4 for intelligent market analysis
- **Real-time Recommendations**: Dynamic parameter optimization based on market conditions
- **Caching System**: Efficient caching of analysis results to reduce API calls
- **RESTful API**: Clean HTTP endpoints for easy integration
- **Comprehensive Logging**: Detailed logs for monitoring and debugging
- **Health Monitoring**: Built-in health checks and statistics

## 📁 File Structure

```
├── ai_backend_server.py      # Main Flask server
├── requirements_backend.txt  # Python dependencies
├── start_backend.sh         # Startup script
├── test_backend.py          # Test suite
├── CrashBoomScalper_Backend.mq5  # Updated MT5 EA
└── README_Backend.md        # This file
```

## 🛠️ Installation

### Prerequisites

- Python 3.8 or higher
- OpenAI API key
- MT5 with WebRequest enabled

### Step 1: Set Up Python Environment

```bash
# Make startup script executable
chmod +x start_backend.sh

# Run the startup script (it will handle everything)
./start_backend.sh
```

### Step 2: Configure OpenAI API Key

Set your OpenAI API key as an environment variable:

```bash
export OPENAI_API_KEY="your-openai-api-key-here"
```

Or create a `.env` file:

```
OPENAI_API_KEY=your-openai-api-key-here
```

### Step 3: Test the Backend

```bash
python3 test_backend.py
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENAI_API_KEY` | Required | Your OpenAI API key |
| `OPENAI_MODEL` | `gpt-4` | OpenAI model to use |
| `SERVER_PORT` | `5000` | Server port |
| `SERVER_HOST` | `0.0.0.0` | Server host (0.0.0.0 for all interfaces) |

### MT5 EA Configuration

In the `CrashBoomScalper_Backend.mq5` EA:

```mql5
input string   InpBackendURL = "http://localhost:5000";     // Backend Server URL
input int      InpBackendTimeout = 10;                      // Request timeout (seconds)
input bool     InpUseBackendAI = true;                      // Use Backend AI Analysis
input int      InpAnalysisInterval = 3600;                  // Analysis interval (seconds)
```

## 🌐 API Endpoints

### Health Check
```
GET /health
```
Returns server status and OpenAI configuration.

### Market Analysis
```
POST /analyze
```
Main endpoint for MT5 EA to request analysis.

**Request Body:**
```json
{
  "symbol": "CRASH_1000",
  "price_data": [
    {
      "timestamp": "2025-01-15T10:30:00",
      "open": 10000.0,
      "high": 10005.0,
      "low": 9995.0,
      "close": 10002.0
    }
  ],
  "market_info": {
    "spread": 15,
    "volatility": 0.85
  }
}
```

**Response:**
```json
{
  "spike_threshold": 45.2,
  "cooldown_seconds": 280,
  "stop_loss_pips": 18.5,
  "take_profit_pips": 37.0,
  "risk_score": 6.2,
  "confidence": 78.5,
  "market_trend": "Bullish",
  "reasoning": "Recent spike patterns indicate...",
  "timestamp": "2025-01-15T10:30:00"
}
```

### Get Cached Recommendations
```
GET /recommendations/{symbol}
```
Retrieve cached analysis for a specific symbol.

### Server Statistics
```
GET /stats
```
Get server statistics and analysis history.

### Clear Cache
```
POST /clear_cache
```
Clear all cached analysis results.

## 🔄 How It Works

### 1. Data Collection
The MT5 EA collects recent price data (last 1000 M1 bars) and market information.

### 2. Spike Detection
The backend analyzes the price data to identify:
- **Crash Spikes**: Sudden price drops
- **Boom Spikes**: Sudden price rises
- **Recovery Patterns**: How quickly prices recover
- **Retracement Levels**: Maximum retracement after spikes

### 3. AI Analysis
OpenAI GPT-4 analyzes the spike data and provides:
- Optimal spike threshold for entry
- Recommended cooldown periods
- Risk management parameters
- Market trend analysis
- Confidence levels

### 4. Parameter Optimization
The EA automatically adjusts its parameters based on AI recommendations:
- Spike detection threshold
- Cooldown periods
- Stop loss and take profit levels
- Risk assessment

## 📊 Monitoring

### Server Logs
Check `ai_backend.log` for detailed server logs.

### Health Monitoring
```bash
curl http://localhost:5000/health
```

### Statistics
```bash
curl http://localhost:5000/stats
```

## 🧪 Testing

Run the comprehensive test suite:

```bash
python3 test_backend.py
```

This will test:
- Server connectivity
- API endpoints
- Analysis functionality
- MT5 data format compatibility
- Caching system

## 🔒 Security Considerations

1. **API Key Protection**: Never commit your OpenAI API key to version control
2. **Network Security**: Consider using HTTPS in production
3. **Rate Limiting**: The server includes basic rate limiting
4. **Input Validation**: All inputs are validated and sanitized

## 🚨 Troubleshooting

### Common Issues

1. **Connection Refused**
   - Check if the server is running
   - Verify the port is not blocked by firewall
   - Ensure MT5 WebRequest is enabled

2. **OpenAI API Errors**
   - Verify your API key is correct
   - Check your OpenAI account balance
   - Ensure the API key has proper permissions

3. **MT5 WebRequest Issues**
   - Enable WebRequest in MT5 Tools → Options → Expert Advisors
   - Add `localhost:5000` to allowed URLs
   - Check MT5 logs for WebRequest errors

### Debug Mode

Enable debug logging by modifying `ai_backend_server.py`:

```python
logging.basicConfig(level=logging.DEBUG)
```

## 📈 Performance Optimization

1. **Caching**: Analysis results are cached to reduce API calls
2. **Batch Processing**: Multiple symbols can be analyzed efficiently
3. **Connection Pooling**: HTTP connections are reused
4. **Async Processing**: Non-blocking request handling

## 🔄 Updates and Maintenance

### Updating Dependencies
```bash
pip install -r requirements_backend.txt --upgrade
```

### Restarting the Server
```bash
# Stop the server (Ctrl+C)
# Then restart
./start_backend.sh
```

### Backup and Recovery
- Analysis cache is stored in memory (cleared on restart)
- Logs are preserved in `ai_backend.log`
- Configuration can be backed up via environment variables

## 📞 Support

For issues and questions:
1. Check the logs in `ai_backend.log`
2. Run the test suite: `python3 test_backend.py`
3. Verify MT5 WebRequest settings
4. Check OpenAI API key and permissions

## 🎯 Next Steps

1. **Production Deployment**: Consider using Gunicorn for production
2. **Load Balancing**: Add multiple server instances
3. **Database Integration**: Store analysis results in a database
4. **Advanced Analytics**: Add more sophisticated market analysis
5. **Real-time Streaming**: Implement WebSocket connections for real-time updates

---

**Note**: This system is designed for educational and research purposes. Always test thoroughly on demo accounts before using with real money. 