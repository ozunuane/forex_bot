# 🚀 CrashBoom Scalper EA for MetaTrader 5

**Professional Expert Advisor for Crash & Boom Spike Scalping**

![Version](https://img.shields.io/badge/version-1.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-MetaTrader%205-green.svg)
![Strategy](https://img.shields.io/badge/strategy-Spike%20Scalping-orange.svg)

## 📋 Overview

The CrashBoom Scalper is a sophisticated Expert Advisor designed specifically for trading Crash and Boom indices on MetaTrader 5. It uses advanced spike detection algorithms to identify profitable scalping opportunities in these highly volatile synthetic instruments.

## ✨ Key Features

### 🎯 **Spike Detection System**
- Advanced multi-candle spike analysis
- Configurable spike threshold and minimum pip requirements
- Real-time spike size calculation and percentage analysis
- Separate detection for Crash and Boom spikes

### 🛡️ **Risk Management**
- Daily profit and loss limits
- Maximum concurrent trades control
- Trailing stop functionality
- Spread filtering
- Position sizing controls

### 📊 **Technical Analysis**
- RSI overbought/oversold filtering
- EMA trend direction confirmation
- Multiple timeframe compatibility
- Customizable indicator periods

### ⏰ **Time Management**
- Trading session filtering
- Cooldown periods between trades
- Server time-based controls
- News event avoidance

## 🚀 Installation

### Step 1: Download Files
1. Download `CrashBoomScalper.mq5`
2. Download `CrashBoomSettings.set` (optional preset configurations)

### Step 2: Install in MetaTrader 5
1. Open MetaTrader 5
2. Press `Ctrl+Shift+D` to open MetaEditor
3. In MetaEditor: File → Open → Select `CrashBoomScalper.mq5`
4. Press `F7` to compile the EA
5. Close MetaEditor

### Step 3: Attach to Chart
1. Open a Crash or Boom chart (Crash 1000, Boom 1000, etc.)
2. Drag the EA from Navigator → Expert Advisors
3. Configure parameters (see Configuration section)
4. Enable "Allow live trading" and "Allow DLL imports"
5. Click OK

## ⚙️ Configuration

### Basic Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| **Lot Size** | 0.01 | Trade volume per position |
| **Magic Number** | 123456 | Unique identifier for EA trades |
| **Max Spread** | 50 | Maximum allowed spread in points |

### Spike Detection

| Parameter | Default | Description |
|-----------|---------|-------------|
| **Spike Candles** | 5 | Number of candles to analyze |
| **Spike Threshold** | 1.5% | Minimum percentage price change |
| **Min Spike Pips** | 100 | Minimum spike size in pips |
| **Cooldown Period** | 300s | Time between trades |

### Risk Management

| Parameter | Default | Description |
|-----------|---------|-------------|
| **Stop Loss** | 20 pips | Maximum loss per trade |
| **Take Profit** | 15 pips | Target profit per trade |
| **Trailing Stop** | 10 pips | Dynamic stop loss adjustment |
| **Max Trades** | 5 | Maximum concurrent positions |
| **Max Daily Loss** | $100 | Daily loss limit |
| **Max Daily Profit** | $200 | Daily profit target |

## 📈 Trading Strategy

### How It Works

1. **Spike Detection**: The EA continuously monitors price action for significant spikes
2. **Filter Application**: RSI and EMA filters confirm trading conditions
3. **Trade Execution**: After spike detection, the EA trades the expected reversion:
   - **Crash Spike** → Expect bounce UP → Place BUY order
   - **Boom Spike** → Expect pullback DOWN → Place SELL order
4. **Risk Management**: Automatic stop loss, take profit, and trailing stops

### Trading Logic

```
Crash Spike Detected (Large Drop):
├── Check RSI is Oversold (< 30)
├── Confirm Price Below EMA (Trend Filter)
├── Wait for Cooldown Period
└── Execute BUY Trade (Expecting Bounce)

Boom Spike Detected (Large Rise):
├── Check RSI is Overbought (> 70)
├── Confirm Price Above EMA (Trend Filter)
├── Wait for Cooldown Period
└── Execute SELL Trade (Expecting Pullback)
```

## 🔧 Preset Configurations

Use the included `CrashBoomSettings.set` file for optimized configurations:

### 🟢 **CONSERVATIVE** (Beginners)
- Lower risk settings
- Larger stop losses
- Fewer trades
- Higher spike thresholds

### 🔴 **AGGRESSIVE** (Experienced)
- Higher risk/reward
- Smaller stop losses
- More frequent trades
- Lower spike thresholds

### 🎯 **CRASH_1000** / **BOOM_1000**
- Optimized specifically for each instrument
- Tailored parameters for volatility patterns

### ⚡ **TURBO_SCALPING**
- Ultra-fast scalping
- Very short cooldowns
- Small profit targets

## 📊 Recommended Timeframes

| Timeframe | Best For | Settings Profile |
|-----------|----------|------------------|
| **M1** | High-frequency scalping | TURBO_SCALPING |
| **M5** | Standard scalping | CONSERVATIVE/AGGRESSIVE |
| **M15** | Swing spike trading | CRASH_1000/BOOM_1000 |
| **H1** | Trend-following spikes | HIGH_VOLATILITY |

## 💡 Optimization Tips

### Backtesting
1. Use quality tick data
2. Test on multiple symbols (Crash 300, 500, 1000, Boom 300, 500, 1000)
3. Optimize for different market conditions
4. Use walk-forward analysis

### Live Trading
1. Start with demo account
2. Use conservative settings initially
3. Monitor performance for at least 1 month
4. Gradually increase lot sizes
5. Keep detailed trading logs

## 📈 Performance Metrics

The EA tracks and displays:
- **Daily P&L**: Current day profit/loss
- **Win Rate**: Percentage of winning trades
- **Average Trade**: Mean profit per trade
- **Maximum Drawdown**: Largest peak-to-trough decline
- **Profit Factor**: Gross profit / Gross loss

## ⚠️ Risk Warning

**IMPORTANT DISCLAIMERS:**

- **High Risk**: Crash and Boom indices are extremely volatile
- **Demo First**: Always test thoroughly on demo accounts
- **Capital Risk**: Only trade with money you can afford to lose
- **No Guarantees**: Past performance doesn't guarantee future results
- **Market Conditions**: Performance varies with market volatility
- **Broker Dependent**: Results may vary between brokers

## 🛠️ Troubleshooting

### Common Issues

**EA Not Trading:**
- Check "Allow live trading" is enabled
- Verify symbol name matches (Crash 1000, Boom 1000)
- Ensure spread is within limits
- Check time filter settings

**Poor Performance:**
- Adjust spike detection parameters
- Optimize for current market conditions
- Review risk management settings
- Consider different timeframes

**High Drawdown:**
- Reduce lot sizes
- Increase stop losses
- Lower maximum trades
- Use more conservative settings

## 📞 Support

For support and updates:
1. Check the EA logs in MetaTrader 5
2. Review parameter settings
3. Test with different configurations
4. Monitor broker-specific conditions

## 📄 License

This Expert Advisor is provided for educational purposes. Use at your own risk. The developer is not responsible for any trading losses.

## 🔄 Version History

**v1.0** (Current)
- Initial release
- Advanced spike detection
- Comprehensive risk management
- Multiple preset configurations
- Real-time performance tracking

---

**Happy Trading! 📈💰**

*Remember: Successful trading requires patience, discipline, and proper risk management.* 