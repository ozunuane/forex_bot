# 🚀 Quick Setup Guide: AI Backend + MT5 EA

## 📋 Prerequisites

- **Python 3.8+** (already installed on your Mac)
- **MT5** with WebRequest enabled
- **OpenAI API Key** (optional - system works without it)

---

## 🔧 Step 1: Backend Server Setup

### 1.1 Start the Backend Server

```bash
# Navigate to your project folder
cd /Users/godspowerunuane/Desktop/Forex

# Make startup script executable
chmod +x start_backend.sh

# Run the startup script
./start_backend.sh
```

**What this does:**
- Creates Python virtual environment
- Installs required packages
- Starts the AI backend server on port 5001

### 1.2 Verify Server is Running

```bash
# Test server health
curl http://localhost:5001/health

# Expected response:
# {"status":"healthy","openai_configured":false}
```

### 1.3 (Optional) Configure OpenAI API Key

```bash
# Run the setup script
python3 setup_openai.py

# Choose option 1 to set up your API key
# Enter your OpenAI API key when prompted
```

---

## 🎯 Step 2: MT5 Configuration

### 2.1 Enable WebRequest in MT5

1. Open **MT5**
2. Go to **Tools** → **Options** → **Expert Advisors**
3. Check **"Allow WebRequest for listed URL"**
4. Add `localhost:5001` to the allowed URLs list
5. Click **OK**

### 2.2 Compile the EA

1. Open **MetaEditor** (F4 in MT5)
2. Open `CrashBoomScalper_Backend.mq5`
3. Click **Compile** (F7)
4. Ensure no errors

### 2.3 Attach EA to Chart

1. Open a **Crash/Boom chart** (e.g., CRASH_1000, BOOM_1000)
2. Drag the EA from Navigator to the chart
3. Configure parameters:
   - **Backend URL**: `http://localhost:5001` (default)
   - **Use Backend AI**: `true` (recommended)
   - **Lot Size**: `0.01` (start small)
   - **Magic Number**: `12345` (unique identifier)

---

## ✅ Step 3: Testing

### 3.1 Test Backend Communication

```bash
# Run the test suite
python3 test_mt5_communication.py

# Expected output:
# ✓ All MT5 communication tests passed!
# ✓ Backend server is ready for MT5 EA integration
```

### 3.2 Test in MT5

1. **Check MT5 Logs** (Ctrl+F12)
2. Look for messages like:
   ```
   Backend-Connected CrashBoomScalper EA initialized successfully
   Backend AI: Enabled
   ```

3. **Monitor EA Performance**:
   - Check the chart for trade signals
   - Monitor daily profit/loss
   - Review AI recommendations in logs

---

## 🔍 Troubleshooting

### Backend Server Issues

**Problem**: Port 5000 in use
```bash
# Solution: Use port 5001 (already configured)
SERVER_PORT=5001 python3 ai_backend_server.py
```

**Problem**: Python modules not found
```bash
# Solution: Activate virtual environment
source venv/bin/activate
python3 ai_backend_server.py
```

### MT5 Issues

**Problem**: WebRequest errors
- Ensure `localhost:5001` is in allowed URLs
- Check MT5 logs for specific error messages

**Problem**: EA not connecting
- Verify backend server is running: `curl http://localhost:5001/health`
- Check MT5 Expert tab for connection status

**Problem**: No trades executing
- Check spread conditions
- Verify lot size and account balance
- Review risk management settings

---

## 📊 Monitoring

### Backend Monitoring

```bash
# Check server status
curl http://localhost:5001/health

# View server statistics
curl http://localhost:5001/stats

# Check server logs
tail -f ai_backend.log
```

### MT5 Monitoring

1. **Expert Tab**: Shows EA status and errors
2. **Journal Tab**: Shows detailed logs
3. **Chart**: Shows trade signals and positions
4. **Terminal**: Shows account information

---

## ⚙️ Configuration Options

### Backend Configuration (`config.env`)

```bash
# Server settings
SERVER_PORT=5001
SERVER_HOST=0.0.0.0
OPENAI_MODEL=gpt-4

# OpenAI API (optional)
OPENAI_API_KEY=your-api-key-here
```

### EA Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Backend URL | `http://localhost:5001` | Backend server address |
| Use Backend AI | `true` | Enable AI analysis |
| Analysis Interval | `3600` | Seconds between analyses |
| Lot Size | `0.01` | Trading volume |
| Spike Threshold | `50.0` | Minimum spike size (pips) |
| Stop Loss | `20.0` | Stop loss (pips) |
| Take Profit | `40.0` | Take profit (pips) |

---

## 🚨 Important Notes

### Security
- Never share your OpenAI API key
- Keep `config.env` file secure
- Use demo accounts for testing

### Performance
- Backend server uses minimal resources
- EA updates every hour by default
- Caching reduces API calls

### Risk Management
- Start with small lot sizes
- Monitor daily profit/loss limits
- Test thoroughly on demo accounts

---

## 📞 Support

### Common Commands

```bash
# Start backend server
./start_backend.sh

# Test system
python3 test_mt5_communication.py

# Check server status
curl http://localhost:5001/health

# View logs
tail -f ai_backend.log
```

### Log Files
- `ai_backend.log`: Backend server logs
- MT5 Expert/Journal tabs: EA logs

### Getting Help
1. Check the logs for error messages
2. Verify all prerequisites are met
3. Test each component individually
4. Review this guide for troubleshooting steps

---

## 🎯 Quick Start Checklist

- [ ] Python 3.8+ installed
- [ ] Backend server running on port 5001
- [ ] Health check passes: `curl http://localhost:5001/health`
- [ ] MT5 WebRequest enabled for `localhost:5001`
- [ ] EA compiled successfully
- [ ] EA attached to Crash/Boom chart
- [ ] Test communication: `python3 test_mt5_communication.py`
- [ ] Monitor MT5 logs for successful initialization

**🎉 You're ready to trade!** 