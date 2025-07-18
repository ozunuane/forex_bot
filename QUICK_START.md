# ⚡ Quick Start Card

## 🚀 Start Backend (Terminal)

```bash
cd /Users/godspowerunuane/Desktop/Forex
./start_backend.sh
```

## ✅ Verify Backend

```bash
curl http://localhost:5001/health
# Should show: {"status":"healthy"}
```

## 🎯 MT5 Setup

1. **Enable WebRequest**: Tools → Options → Expert Advisors → Add `localhost:5001`
2. **Compile EA**: Open `CrashBoomScalper_Backend.mq5` in MetaEditor → F7
3. **Attach to Chart**: Drag EA to Crash/Boom chart

## 🔧 Test Everything

```bash
python3 test_mt5_communication.py
# Should show: ✓ All tests passed!
```

## 📊 Monitor

- **Backend**: `tail -f ai_backend.log`
- **MT5**: Check Expert/Journal tabs
- **Status**: `curl http://localhost:5001/stats`

## 🚨 If Issues

- **Port 5000 busy**: Already using port 5001 ✅
- **WebRequest errors**: Check MT5 allowed URLs
- **No trades**: Check spread, lot size, account balance

---

**🎉 Ready to trade!** 