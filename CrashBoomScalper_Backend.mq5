//+------------------------------------------------------------------+
//|                                        CrashBoomScalper_Backend.mq5 |
//|                         Backend-Connected Crash/Boom Scalping EA    |
//|                                   Copyright 2025, Ozimede           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, YourName"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Crash/Boom Scalping EA with Backend AI Analysis"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscilators.mqh>

//--- Input parameters
input group "=== BACKEND CONNECTION ==="
input string   InpBackendURL = "https://forex-bot-ffiu.onrender.com";     // Backend Server URL
input int      InpBackendTimeout = 15;                      // Request timeout (seconds)
input bool     InpUseBackendAI = true;                      // Use Backend AI Analysis
input int      InpAnalysisInterval = 1800;                  // Analysis interval (seconds)
input bool     InpSimulateBackendInTester = true;           // Simulate backend in Strategy Tester

input group "=== TRADING PARAMETERS ==="
input double   InpLotSize = 0.01;                           // Lot Size
input int      InpMagicNumber = 12345;                      // Magic Number
input double   InpSpikeThreshold = 50.0;                    // Spike Threshold (pips)
input int      InpCooldownPeriod = 300;                     // Cooldown Period (seconds)
input double   InpStopLoss = 20.0;                          // Stop Loss (pips)
input double   InpTakeProfit = 40.0;                        // Take Profit (pips)
input int      InpMaxTrades = 1;                            // Maximum Open Trades
input double   InpTrailingStop = 10.0;                      // Trailing Stop (pips)

input group "=== RISK MANAGEMENT ==="
input double   InpMaxDailyLoss = 100.0;                     // Maximum Daily Loss ($)
input double   InpMaxDailyProfit = 500.0;                   // Maximum Daily Profit ($)
input double   InpMaxSpread = 50.0;                         // Maximum Spread (points)

input group "=== TECHNICAL INDICATORS ==="
input bool     InpUseRSIFilter = true;                      // Use RSI Filter
input int      InpRSIPeriod = 14;                           // RSI Period
input double   InpRSIOverBought = 70.0;                     // RSI Overbought Level
input double   InpRSIOverSold = 30.0;                       // RSI Oversold Level
input bool     InpUseTrendFilter = true;                    // Use EMA Trend Filter
input int      InpEMAPeriod = 20;                           // EMA Period

input group "=== TIME FILTER ==="
input bool     InpUseTimeFilter = false;                    // Use Time Filter
input int      InpStartHour = 8;                            // Start Hour (0-23)
input int      InpEndHour = 20;                             // End Hour (0-23)

//--- Global variables
CTrade         trade;
CPositionInfo  position;
int            rsiHandle;
int            emaHandle;
double         rsiBuffer[];
double         emaBuffer[];
datetime       lastTradeTime = 0;
datetime       lastAnalysisTime = 0;
double         dailyProfit = 0.0;
datetime       currentDay = 0;

//--- AI Backend variables
struct BackendRecommendation
{
   double   spikeThreshold;
   int      cooldownSeconds;
   double   stopLossPips;
   double   takeProfitPips;
   double   riskScore;
   double   confidence;
   string   marketTrend;
   string   reasoning;
   datetime timestamp;
};

BackendRecommendation currentRecommendation;
bool                 backendConnected = false;
string               lastBackendError = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   //--- Initialize indicators
   if(InpUseRSIFilter)
   {
      rsiHandle = iRSI(_Symbol, PERIOD_M1, InpRSIPeriod, PRICE_CLOSE);
      if(rsiHandle == INVALID_HANDLE)
      {
         Print("Error creating RSI indicator");
         return INIT_FAILED;
      }
      ArraySetAsSeries(rsiBuffer, true);
   }
   
   if(InpUseTrendFilter)
   {
      emaHandle = iMA(_Symbol, PERIOD_M1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(emaHandle == INVALID_HANDLE)
      {
         Print("Error creating EMA indicator");
         return INIT_FAILED;
      }
      ArraySetAsSeries(emaBuffer, true);
   }
   
   //--- Test backend connection
   if(InpUseBackendAI)
   {
      // Check if running in Strategy Tester
      if(MQLInfoInteger(MQL_TESTER))
      {
         if(InpSimulateBackendInTester)
         {
            Print("Strategy Tester detected - Using simulated backend AI");
            backendConnected = SimulateBackendConnection();
         }
         else
         {
            Print("Strategy Tester detected - Backend AI disabled");
            backendConnected = false;
         }
      }
      else
      {
         Print("Live environment - Connecting to real backend");
         backendConnected = TestBackendConnection();
      }
      
      if(backendConnected)
      {
         Print("Backend AI connection established successfully");
         //--- Get initial recommendations
         RequestBackendAnalysis();
      }
      else
      {
         Print("Warning: Backend AI connection failed. Using default parameters.");
         if(!MQLInfoInteger(MQL_TESTER))
            Print("Error: ", lastBackendError);
      }
   }
   
   Print("Backend-Connected CrashBoomScalper EA initialized successfully");
   Print("Symbol: ", _Symbol);
   Print("Backend AI: ", InpUseBackendAI ? "Enabled" : "Disabled");
   Print("Backend URL: ", InpBackendURL);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   if(emaHandle != INVALID_HANDLE)
      IndicatorRelease(emaHandle);
   
   Print("Backend-Connected CrashBoomScalper EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Update daily profit tracking
   UpdateDailyProfit();
   
   //--- Check daily limits
   if(CheckDailyLimits())
      return;
   
   //--- Check if can open new trade
   if(!CanOpenNewTrade())
      return;
   
   //--- Check spread condition
   if(CheckSpread())
      return;
   
   //--- Check time filter
   if(!CheckTimeFilter())
      return;
   
   //--- Request backend analysis periodically
   if(InpUseBackendAI && ShouldRequestAnalysis())
   {
      RequestBackendAnalysis();
   }
   
   //--- Detect and trade spikes
   DetectAndTradeSpikes();
   
   //--- Update trailing stops
   UpdateTrailingStops();
}

//+------------------------------------------------------------------+
//| Simulate backend connection for Strategy Tester                 |
//+------------------------------------------------------------------+
bool SimulateBackendConnection()
{
   Print("Simulating backend AI connection for Strategy Tester");
   
   // Set simulated AI parameters based on market conditions
   currentRecommendation.spikeThreshold = 45.0;
   currentRecommendation.cooldownSeconds = 450;
   currentRecommendation.stopLossPips = 18.0;
   currentRecommendation.takeProfitPips = 42.0;
   currentRecommendation.riskScore = 6.5;
   currentRecommendation.confidence = 75.0;
   currentRecommendation.marketTrend = "Simulated - Conservative";
   currentRecommendation.reasoning = "Using simulated AI parameters for backtesting";
   currentRecommendation.timestamp = TimeCurrent();
   
   Print("Simulated AI Parameters:");
   Print("  Spike Threshold: ", DoubleToString(currentRecommendation.spikeThreshold, 2));
   Print("  Cooldown: ", IntegerToString(currentRecommendation.cooldownSeconds), "s");
   Print("  Stop Loss: ", DoubleToString(currentRecommendation.stopLossPips, 2), " pips");
   Print("  Take Profit: ", DoubleToString(currentRecommendation.takeProfitPips, 2), " pips");
   Print("  Risk Score: ", DoubleToString(currentRecommendation.riskScore, 1));
   Print("  Confidence: ", DoubleToString(currentRecommendation.confidence, 1), "%");
   
   return true;
}

//+------------------------------------------------------------------+
//| Update simulated parameters based on market conditions           |
//+------------------------------------------------------------------+
void UpdateSimulatedParameters()
{
   // Simulate dynamic parameter updates based on market volatility
   double currentVolatility = GetCurrentVolatility();
   
   // Adjust parameters based on volatility
   if(currentVolatility > 0.5)
   {
      // High volatility - more conservative
      currentRecommendation.spikeThreshold = 55.0;
      currentRecommendation.cooldownSeconds = 600;
      currentRecommendation.stopLossPips = 25.0;
      currentRecommendation.takeProfitPips = 50.0;
      currentRecommendation.riskScore = 8.0;
      currentRecommendation.confidence = 65.0;
      currentRecommendation.marketTrend = "Simulated - High Volatility";
   }
   else if(currentVolatility < 0.2)
   {
      // Low volatility - more aggressive
      currentRecommendation.spikeThreshold = 35.0;
      currentRecommendation.cooldownSeconds = 300;
      currentRecommendation.stopLossPips = 15.0;
      currentRecommendation.takeProfitPips = 35.0;
      currentRecommendation.riskScore = 4.0;
      currentRecommendation.confidence = 85.0;
      currentRecommendation.marketTrend = "Simulated - Low Volatility";
   }
   else
   {
      // Normal volatility - balanced
      currentRecommendation.spikeThreshold = 45.0;
      currentRecommendation.cooldownSeconds = 450;
      currentRecommendation.stopLossPips = 18.0;
      currentRecommendation.takeProfitPips = 42.0;
      currentRecommendation.riskScore = 6.5;
      currentRecommendation.confidence = 75.0;
      currentRecommendation.marketTrend = "Simulated - Normal Volatility";
   }
   
   currentRecommendation.reasoning = "Simulated AI analysis based on market volatility";
   currentRecommendation.timestamp = TimeCurrent();
   
   Print("Updated Simulated AI Parameters:");
   Print("  Volatility: ", DoubleToString(currentVolatility, 3));
   Print("  Spike Threshold: ", DoubleToString(currentRecommendation.spikeThreshold, 2));
   Print("  Cooldown: ", IntegerToString(currentRecommendation.cooldownSeconds), "s");
   Print("  Market Trend: ", currentRecommendation.marketTrend);
}

//+------------------------------------------------------------------+
//| Get current market volatility                                    |
//+------------------------------------------------------------------+
double GetCurrentVolatility()
{
   // Simple volatility calculation based on recent price movements
   double close[];
   ArraySetAsSeries(close, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 20, close) < 20)
      return 0.5; // Default moderate volatility
   
   double sum = 0;
   for(int i = 1; i < 20; i++)
   {
      sum += MathAbs(close[i-1] - close[i]);
   }
   
   double avgMovement = sum / 19;
   double currentPrice = close[0];
   
   // Normalize volatility (0-1 scale)
   return MathMin(avgMovement / currentPrice * 1000, 1.0);
}

//+------------------------------------------------------------------+
//| Test backend connection                                          |
//+------------------------------------------------------------------+
bool TestBackendConnection()
{
   string url = InpBackendURL + "/health";
   uchar post[], result[];
   string headers = "";
   string response;
   
   Print("Testing backend connection to: ", url);
   
   int res = WebRequest("GET", url, headers, 10000, post, result, response);
   
   Print("WebRequest result: ", res);
   Print("Response: ", response);
   
   if(res == 200)
   {
      Print("Backend health check successful: ", response);
      return true;
   }
   else
   {
      lastBackendError = "HTTP " + IntegerToString(res);
      Print("Backend connection failed: ", lastBackendError);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Request backend analysis                                         |
//+------------------------------------------------------------------+
void RequestBackendAnalysis()
{
   if(!InpUseBackendAI || !backendConnected)
      return;
   
   // If in tester mode and simulation is enabled, update simulated parameters
   if(MQLInfoInteger(MQL_TESTER) && InpSimulateBackendInTester)
   {
      UpdateSimulatedParameters();
      lastAnalysisTime = TimeCurrent();
      return;
   }
   
   //--- Collect recent price data
   string priceData = CollectPriceData();
   if(StringLen(priceData) == 0)
      return;
   
   //--- Prepare request data
   string requestData = "{";
   requestData += "\"symbol\":\"" + _Symbol + "\",";
   requestData += "\"price_data\":" + priceData;
   requestData += "}";
   
   //--- Send request to backend
   string url = InpBackendURL + "/analyze";
   uchar post[], result[];
   string headers = "Content-Type: application/json\r\n";
   string response;
   
   StringToCharArray(requestData, post);
   
   Print("Sending analysis request to: ", url);
   Print("Request data: ", requestData);
   
   int res = WebRequest("POST", url, headers, 5000, post, result, response);
   
   Print("Analysis WebRequest result: ", res);
   
   if(res == 200)
   {
      if(ParseBackendResponse(response))
      {
         Print("Backend analysis completed successfully");
         Print("New Spike Threshold: ", DoubleToString(currentRecommendation.spikeThreshold, 2));
         Print("New Cooldown: ", IntegerToString(currentRecommendation.cooldownSeconds), "s");
         Print("AI Confidence: ", DoubleToString(currentRecommendation.confidence, 1), "%");
         lastAnalysisTime = TimeCurrent();
      }
      else
      {
         Print("Failed to parse backend response");
      }
   }
   else
   {
      lastBackendError = "HTTP " + IntegerToString(res);
      Print("Backend analysis failed: ", lastBackendError);
      
      // If server error (500), try to use cached or default parameters
      if(res >= 500)
      {
         Print("Server error detected - using fallback parameters");
         // Set conservative default parameters
         currentRecommendation.spikeThreshold = InpSpikeThreshold;
         currentRecommendation.cooldownSeconds = InpCooldownPeriod;
         currentRecommendation.stopLossPips = InpStopLoss;
         currentRecommendation.takeProfitPips = InpTakeProfit;
         currentRecommendation.riskScore = 7.0;
         currentRecommendation.confidence = 60.0;
         currentRecommendation.marketTrend = "Fallback - Server Error";
         currentRecommendation.reasoning = "Using fallback parameters due to server error";
         currentRecommendation.timestamp = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| Collect price data for analysis                                  |
//+------------------------------------------------------------------+
string CollectPriceData()
{
   //--- Get last 200 price points (about 3 hours of M1 data) - reduced for better performance
   int bars = 200;
   double close[], high[], low[], open[];
   datetime time[];
   string priceData = "";
   
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(time, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, bars, close) <= 0 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, bars, high) <= 0 ||
      CopyLow(_Symbol, PERIOD_M1, 0, bars, low) <= 0 ||
      CopyOpen(_Symbol, PERIOD_M1, 0, bars, open) <= 0 ||
      CopyTime(_Symbol, PERIOD_M1, 0, bars, time) <= 0)
   {
      return "";
   }
   
   priceData = "[";
   for(int i = bars - 1; i >= 0; i--)
   {
      if(i < bars - 1) priceData += ",";
      priceData += DoubleToString(close[i], _Digits);
   }
   priceData += "]";
   
   return priceData;
}

//+------------------------------------------------------------------+
//| Parse backend response                                           |
//+------------------------------------------------------------------+
bool ParseBackendResponse(string response)
{
   //--- Extract JSON values from recommendations object
   currentRecommendation.spikeThreshold = ExtractDoubleFromJson(response, "spike_threshold");
   currentRecommendation.cooldownSeconds = (int)ExtractDoubleFromJson(response, "cooldown_seconds");
   currentRecommendation.stopLossPips = ExtractDoubleFromJson(response, "stop_loss_pips");
   currentRecommendation.takeProfitPips = ExtractDoubleFromJson(response, "take_profit_pips");
   currentRecommendation.riskScore = ExtractDoubleFromJson(response, "risk_score");
   currentRecommendation.confidence = ExtractDoubleFromJson(response, "confidence");
   currentRecommendation.marketTrend = ExtractStringFromJson(response, "market_trend");
   currentRecommendation.reasoning = ExtractStringFromJson(response, "reasoning");
   currentRecommendation.timestamp = TimeCurrent();
   
   //--- If no values found, try recommendations object
   if(currentRecommendation.spikeThreshold == 0)
   {
      currentRecommendation.spikeThreshold = ExtractDoubleFromJson(response, "recommendations", "spike_threshold");
      currentRecommendation.cooldownSeconds = (int)ExtractDoubleFromJson(response, "recommendations", "cooldown_seconds");
      currentRecommendation.stopLossPips = ExtractDoubleFromJson(response, "recommendations", "stop_loss_pips");
      currentRecommendation.takeProfitPips = ExtractDoubleFromJson(response, "recommendations", "take_profit_pips");
      currentRecommendation.riskScore = ExtractDoubleFromJson(response, "recommendations", "risk_score");
      currentRecommendation.confidence = ExtractDoubleFromJson(response, "recommendations", "confidence");
      currentRecommendation.marketTrend = ExtractStringFromJson(response, "recommendations", "market_trend");
      currentRecommendation.reasoning = ExtractStringFromJson(response, "recommendations", "reasoning");
   }
   
   return currentRecommendation.spikeThreshold > 0;
}

//+------------------------------------------------------------------+
//| Extract double value from JSON                                   |
//+------------------------------------------------------------------+
double ExtractDoubleFromJson(string json, string key)
{
   string searchStr = "\"" + key + "\":";
   int pos = StringFind(json, searchStr);
   if(pos == -1)
      return 0.0;
   
   pos += StringLen(searchStr);
   
   //--- Skip whitespace
   while(pos < StringLen(json) && (StringGetCharacter(json, pos) == ' ' || StringGetCharacter(json, pos) == '\t'))
      pos++;
   
   //--- Find end of number
   int endPos = pos;
   while(endPos < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, endPos);
      if(ch != '.' && ch != '-' && (ch < '0' || ch > '9'))
         break;
      endPos++;
   }
   
   if(endPos > pos)
   {
      string numStr = StringSubstr(json, pos, endPos - pos);
      return StringToDouble(numStr);
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Extract double value from nested JSON                            |
//+------------------------------------------------------------------+
double ExtractDoubleFromJson(string json, string parent, string key)
{
   string searchStr = "\"" + parent + "\":{";
   int pos = StringFind(json, searchStr);
   if(pos == -1)
      return 0.0;
   
   pos += StringLen(searchStr);
   
   //--- Find the key within the parent object
   string nestedSearchStr = "\"" + key + "\":";
   int nestedPos = StringFind(json, nestedSearchStr, pos);
   if(nestedPos == -1)
      return 0.0;
   
   nestedPos += StringLen(nestedSearchStr);
   
   //--- Skip whitespace
   while(nestedPos < StringLen(json) && (StringGetCharacter(json, nestedPos) == ' ' || StringGetCharacter(json, nestedPos) == '\t'))
      nestedPos++;
   
   //--- Find end of number
   int endPos = nestedPos;
   while(endPos < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, endPos);
      if(ch != '.' && ch != '-' && (ch < '0' || ch > '9'))
         break;
      endPos++;
   }
   
   if(endPos > nestedPos)
   {
      string numStr = StringSubstr(json, nestedPos, endPos - nestedPos);
      return StringToDouble(numStr);
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Extract string value from JSON                                   |
//+------------------------------------------------------------------+
string ExtractStringFromJson(string json, string key)
{
   string searchStr = "\"" + key + "\":\"";
   int pos = StringFind(json, searchStr);
   if(pos == -1)
      return "";
   
   pos += StringLen(searchStr);
   int endPos = StringFind(json, "\"", pos);
   
   if(endPos > pos)
   {
      return StringSubstr(json, pos, endPos - pos);
   }
   
   return "";
}

//+------------------------------------------------------------------+
//| Extract string value from nested JSON                            |
//+------------------------------------------------------------------+
string ExtractStringFromJson(string json, string parent, string key)
{
   string searchStr = "\"" + parent + "\":{";
   int pos = StringFind(json, searchStr);
   if(pos == -1)
      return "";
   
   pos += StringLen(searchStr);
   
   //--- Find the key within the parent object
   string nestedSearchStr = "\"" + key + "\":\"";
   int nestedPos = StringFind(json, nestedSearchStr, pos);
   if(nestedPos == -1)
      return "";
   
   nestedPos += StringLen(nestedSearchStr);
   int endPos = StringFind(json, "\"", nestedPos);
   
   if(endPos > nestedPos)
   {
      return StringSubstr(json, nestedPos, endPos - nestedPos);
   }
   
   return "";
}

//+------------------------------------------------------------------+
//| Check if should request analysis                                 |
//+------------------------------------------------------------------+
bool ShouldRequestAnalysis()
{
   return (TimeCurrent() - lastAnalysisTime) >= InpAnalysisInterval;
}

//+------------------------------------------------------------------+
//| Detect and trade spikes                                          |
//+------------------------------------------------------------------+
void DetectAndTradeSpikes()
{
   //--- Get current spike threshold
   double spikeThreshold = InpUseBackendAI && backendConnected ? 
                          currentRecommendation.spikeThreshold : InpSpikeThreshold;
   
   //--- Get current cooldown period
   int cooldownPeriod = InpUseBackendAI && backendConnected ? 
                       currentRecommendation.cooldownSeconds : InpCooldownPeriod;
   
   //--- Check cooldown period
   if(TimeCurrent() - lastTradeTime < cooldownPeriod)
   {
      return;
   }
   
   //--- Get recent price data
   double close[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 3, close) < 3 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 3, high) < 3 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 3, low) < 3)
   {
      return;
   }
   
   //--- Calculate price changes
   double currentChange = MathAbs(close[0] - close[1]);
   double previousChange = MathAbs(close[1] - close[2]);
   
   //--- Convert to pips
   double currentChangePips = currentChange / _Point;
   double previousChangePips = previousChange / _Point;
   
   //--- Detect crash spike (sudden drop)
   if(close[0] < close[1] && currentChangePips >= spikeThreshold && previousChangePips < spikeThreshold * 0.5)
   {
      Print("CRASH SPIKE DETECTED! Size: ", DoubleToString(currentChangePips, 1), " pips (",
            "Threshold: ", DoubleToString(spikeThreshold, 1), ")");
      
      if(CheckRSIFilter(true) && CheckTrendFilter(true))
      {
         ExecuteSpikeTrade(ORDER_TYPE_BUY, close[0], "CRASH_SPIKE");
      }
   }
   
   //--- Detect boom spike (sudden rise)
   if(close[0] > close[1] && currentChangePips >= spikeThreshold && previousChangePips < spikeThreshold * 0.5)
   {
      Print("BOOM SPIKE DETECTED! Size: ", DoubleToString(currentChangePips, 1), " pips (",
            "Threshold: ", DoubleToString(spikeThreshold, 1), ")");
      
      if(CheckRSIFilter(false) && CheckTrendFilter(false))
      {
         ExecuteSpikeTrade(ORDER_TYPE_SELL, close[0], "BOOM_SPIKE");
      }
   }
}

//+------------------------------------------------------------------+
//| Execute spike trade                                              |
//+------------------------------------------------------------------+
void ExecuteSpikeTrade(ENUM_ORDER_TYPE orderType, double entryPrice, string comment)
{
   //--- Get current stop loss and take profit
   double stopLoss = InpUseBackendAI && backendConnected ? 
                    currentRecommendation.stopLossPips : InpStopLoss;
   double takeProfit = InpUseBackendAI && backendConnected ? 
                      currentRecommendation.takeProfitPips : InpTakeProfit;
   
   //--- Calculate SL and TP prices
   double slPrice, tpPrice;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      slPrice = entryPrice - (stopLoss * _Point);
      tpPrice = entryPrice + (takeProfit * _Point);
   }
   else
   {
      slPrice = entryPrice + (stopLoss * _Point);
      tpPrice = entryPrice - (takeProfit * _Point);
   }
   
   //--- Add AI info to comment
   if(InpUseBackendAI && backendConnected)
   {
      comment += "_AI_" + DoubleToString(currentRecommendation.confidence, 0) + "%";
   }
   
   if(trade.PositionOpen(_Symbol, orderType, InpLotSize, entryPrice, slPrice, tpPrice, comment))
   {
      Print("Spike trade executed: ", EnumToString(orderType), 
            " at ", DoubleToString(entryPrice, _Digits),
            " SL:", DoubleToString(slPrice, _Digits),
            " TP:", DoubleToString(tpPrice, _Digits));
      
      if(InpUseBackendAI && backendConnected)
      {
         Print("AI Confidence: ", DoubleToString(currentRecommendation.confidence, 1), "%");
         Print("AI Risk Score: ", DoubleToString(currentRecommendation.riskScore, 1), "/10");
      }
      
      lastTradeTime = TimeCurrent();
   }
   else
   {
      Print("Failed to execute spike trade. Error: ", IntegerToString(trade.ResultRetcode()));
   }
}

//+------------------------------------------------------------------+
//| Check RSI filter                                                 |
//+------------------------------------------------------------------+
bool CheckRSIFilter(bool isCrashSpike)
{
   if(!InpUseRSIFilter || rsiHandle == INVALID_HANDLE)
      return true;
   
   if(CopyBuffer(rsiHandle, 0, 0, 2, rsiBuffer) <= 0)
      return true;
   
   double currentRSI = rsiBuffer[0];
   
   if(isCrashSpike)
   {
      return currentRSI <= InpRSIOverSold;
   }
   else
   {
      return currentRSI >= InpRSIOverBought;
   }
}

//+------------------------------------------------------------------+
//| Check trend filter                                               |
//+------------------------------------------------------------------+
bool CheckTrendFilter(bool isCrashSpike)
{
   if(!InpUseTrendFilter || emaHandle == INVALID_HANDLE)
      return true;
   
   if(CopyBuffer(emaHandle, 0, 0, 2, emaBuffer) <= 0)
      return true;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ema = emaBuffer[0];
   
   if(isCrashSpike)
   {
      return currentPrice < ema;
   }
   else
   {
      return currentPrice > ema;
   }
}

//+------------------------------------------------------------------+
//| Check if can open new trade                                      |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
   int totalPositions = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber)
         {
            totalPositions++;
         }
      }
   }
   
   return totalPositions < InpMaxTrades;
}

//+------------------------------------------------------------------+
//| Update trailing stops                                            |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber)
         {
            double currentPrice, newStopLoss;
            
            if(position.PositionType() == POSITION_TYPE_BUY)
            {
               currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               newStopLoss = currentPrice - (InpTrailingStop * _Point);
               
               if(newStopLoss > position.StopLoss() && newStopLoss < currentPrice)
               {
                  trade.PositionModify(position.Ticket(), 
                                       NormalizeDouble(newStopLoss, _Digits), 
                                       position.TakeProfit());
               }
            }
            else if(position.PositionType() == POSITION_TYPE_SELL)
            {
               currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               newStopLoss = currentPrice + (InpTrailingStop * _Point);
               
               if((position.StopLoss() == 0 || newStopLoss < position.StopLoss()) && 
                  newStopLoss > currentPrice)
               {
                  trade.PositionModify(position.Ticket(), 
                                       NormalizeDouble(newStopLoss, _Digits), 
                                       position.TakeProfit());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check spread condition                                           |
//+------------------------------------------------------------------+
bool CheckSpread()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return spread > InpMaxSpread;
}

//+------------------------------------------------------------------+
//| Check time filter                                                |
//+------------------------------------------------------------------+
bool CheckTimeFilter()
{
   if(!InpUseTimeFilter)
      return true;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
}

//+------------------------------------------------------------------+
//| Update daily profit tracking                                     |
//+------------------------------------------------------------------+
void UpdateDailyProfit()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   
   if(today != currentDay)
   {
      currentDay = today;
      dailyProfit = 0.0;
   }
   
   dailyProfit = CalculateDailyProfit();
}

//+------------------------------------------------------------------+
//| Calculate daily profit                                           |
//+------------------------------------------------------------------+
double CalculateDailyProfit()
{
   double profit = 0.0;
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   
   HistorySelect(today, TimeCurrent());
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
            HistoryDealGetInteger(ticket, DEAL_TYPE) <= 1)
         {
            profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         }
      }
   }
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == InpMagicNumber)
         {
            profit += position.Profit();
         }
      }
   }
   
   return profit;
}

//+------------------------------------------------------------------+
//| Check daily limits                                               |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
   if(dailyProfit <= -InpMaxDailyLoss)
   {
      Print("Daily loss limit reached: $", DoubleToString(dailyProfit, 2));
      return true;
   }
   
   if(dailyProfit >= InpMaxDailyProfit)
   {
      Print("Daily profit target reached: $", DoubleToString(dailyProfit, 2));
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Display information on chart                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   string info = StringFormat("Backend CrashBoom Scalper | Daily P&L: $%.2f | Spread: %d", 
                              dailyProfit, 
                              SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
   
   if(InpUseBackendAI && backendConnected)
   {
      info += StringFormat("\nBackend AI: Connected | Confidence: %.1f%% | Risk: %.1f/10", 
                           currentRecommendation.confidence, currentRecommendation.riskScore);
      info += StringFormat("\nAI Params: Thresh=%.2f%% CD=%ds SL=%.1f TP=%.1f", 
                           currentRecommendation.spikeThreshold, 
                           currentRecommendation.cooldownSeconds, 
                           currentRecommendation.stopLossPips, 
                           currentRecommendation.takeProfitPips);
   }
   else if(InpUseBackendAI && !backendConnected)
   {
      info += "\nBackend AI: Disconnected - Using Default Parameters";
      info += StringFormat("\nDefault Params: Thresh=%.2f%% CD=%ds SL=%.1f TP=%.1f", 
                           InpSpikeThreshold, InpCooldownPeriod, InpStopLoss, InpTakeProfit);
   }
   else
   {
      info += StringFormat("\nStandard Params: Thresh=%.2f%% CD=%ds SL=%.1f TP=%.1f", 
                           InpSpikeThreshold, InpCooldownPeriod, InpStopLoss, InpTakeProfit);
   }
   
   Comment(info);
}

//+------------------------------------------------------------------+ 