//+------------------------------------------------------------------+
//|                                    CrashBoomScalper_AI.mq5       |
//|                      AI-Enhanced Crash & Boom Spike Scalper     |
//|                                    Copyright 2025, YourName     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, YourName"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property description "AI-Enhanced Crash & Boom Spike Scalping EA with OpenAI Integration"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input parameters
input group "=== AI INTEGRATION ==="
input bool     InpUseAIRecommendations = true;       // Use AI Recommendations
input double   InpAIAdaptationRate = 0.7;            // AI Adaptation Rate (0.1-1.0)
input int      InpAIUpdateCheckMinutes = 30;         // Check for AI updates (minutes)

input group "=== TRADING SETTINGS ==="
input double   InpLotSize = 0.01;                    // Lot Size
input int      InpMagicNumber = 123456;              // Magic Number
input int      InpMaxSpread = 50;                    // Maximum Spread (points)

input group "=== SPIKE DETECTION (AI Adaptive) ==="
input int      InpSpikeCandles = 5;                  // Candles to analyze for spike
input double   InpSpikeThreshold = 1.5;              // Spike threshold (% price change)
input int      InpMinSpikePips = 100;                // Minimum spike size in pips
input int      InpCooldownPeriod = 300;              // Cooldown between trades (seconds)

input group "=== RISK MANAGEMENT (AI Adaptive) ==="
input double   InpStopLoss = 20.0;                   // Stop Loss (pips)
input double   InpTakeProfit = 15.0;                 // Take Profit (pips)
input double   InpTrailingStop = 10.0;               // Trailing Stop (pips)
input bool     InpUseTrailingStop = true;            // Use Trailing Stop
input int      InpMaxTrades = 5;                     // Maximum concurrent trades
input double   InpMaxDailyLoss = 100.0;              // Maximum daily loss ($)
input double   InpMaxDailyProfit = 200.0;            // Maximum daily profit ($)

input group "=== TIME FILTERS ==="
input bool     InpUseTimeFilter = true;              // Use Time Filter
input int      InpStartHour = 8;                     // Start Hour (server time)
input int      InpEndHour = 22;                      // End Hour (server time)

input group "=== TECHNICAL FILTERS ==="
input int      InpRSIPeriod = 14;                    // RSI Period
input double   InpRSIOverBought = 70.0;              // RSI Overbought Level
input double   InpRSIOverSold = 30.0;                // RSI Oversold Level
input bool     InpUseRSIFilter = true;               // Use RSI Filter
input int      InpEMAPeriod = 21;                    // EMA Period for trend
input bool     InpUseTrendFilter = true;             // Use Trend Filter

//--- Global variables
CTrade         trade;
CPositionInfo  position;
COrderInfo     order;

//--- AI-adapted parameters
double         aiSpikeThreshold;
int            aiCooldownPeriod;
double         aiStopLoss;
double         aiTakeProfit;
double         aiRiskScore;
datetime       lastAICheck = 0;

//--- Standard variables
datetime       lastTradeTime = 0;
double         dailyProfit = 0.0;
datetime       currentDay = 0;
int            rsiHandle = INVALID_HANDLE;
int            emaHandle = INVALID_HANDLE;
double         rsiBuffer[];
double         emaBuffer[];

//--- AI Performance tracking
struct AIPerformance
{
   int    totalTrades;
   int    aiTrades;
   double aiProfitSum;
   double standardProfitSum;
   double aiWinRate;
   double standardWinRate;
};

AIPerformance aiStats;

//--- Spike detection variables
struct SpikeInfo
{
   bool     detected;
   bool     isCrash;
   double   spikeSize;
   datetime spikeTime;
   double   entryPrice;
   double   aiConfidence;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set magic number
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   //--- Initialize indicators
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   emaHandle = iMA(_Symbol, PERIOD_CURRENT, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(rsiHandle == INVALID_HANDLE || emaHandle == INVALID_HANDLE)
   {
      Print("Error creating indicators");
      return INIT_FAILED;
   }
   
   //--- Set array as series
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(emaBuffer, true);
   
   //--- Initialize AI parameters with defaults
   aiSpikeThreshold = InpSpikeThreshold;
   aiCooldownPeriod = InpCooldownPeriod;
   aiStopLoss = InpStopLoss;
   aiTakeProfit = InpTakeProfit;
   aiRiskScore = 5.0; // Neutral risk score
   
   //--- Initialize daily tracking
   currentDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   dailyProfit = CalculateDailyProfit();
   
   //--- Initialize AI stats
   aiStats.totalTrades = 0;
   aiStats.aiTrades = 0;
   aiStats.aiProfitSum = 0.0;
   aiStats.standardProfitSum = 0.0;
   aiStats.aiWinRate = 0.0;
   aiStats.standardWinRate = 0.0;
   
   //--- Check for initial AI recommendations
   if(InpUseAIRecommendations)
   {
      CheckForAIUpdates();
   }
   
   Print("AI-Enhanced CrashBoomScalper EA initialized successfully");
   Print("Symbol: ", _Symbol);
   Print("AI Integration: ", InpUseAIRecommendations ? "Enabled" : "Disabled");
   Print("Current AI Spike Threshold: ", aiSpikeThreshold);
   
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
   
   //--- Display final AI performance statistics
   DisplayAIPerformance();
   
   Print("AI-Enhanced CrashBoomScalper EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if new bar
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBar == lastBar)
      return;
      
   lastBar = currentBar;
   
   //--- Check for AI updates periodically
   if(InpUseAIRecommendations && ShouldCheckAI())
   {
      CheckForAIUpdates();
   }
   
   //--- Update daily profit tracking
   UpdateDailyProfit();
   
   //--- Check daily limits
   if(CheckDailyLimits())
      return;
   
   //--- Check spread
   if(CheckSpread())
      return;
   
   //--- Check time filter
   if(!CheckTimeFilter())
      return;
   
   //--- Update trailing stops
   if(InpUseTrailingStop)
      UpdateTrailingStops();
   
   //--- Check for spike and trade
   SpikeInfo spike = DetectSpike();
   if(spike.detected)
   {
      if(CanOpenNewTrade())
      {
         ExecuteSpikeTrade(spike);
      }
   }
}

//+------------------------------------------------------------------+
//| Check if should check for AI updates                            |
//+------------------------------------------------------------------+
bool ShouldCheckAI()
{
   return (TimeCurrent() - lastAICheck) >= (InpAIUpdateCheckMinutes * 60);
}

//+------------------------------------------------------------------+
//| Check for AI recommendation updates                              |
//+------------------------------------------------------------------+
void CheckForAIUpdates()
{
   lastAICheck = TimeCurrent();
   
   //--- Check if AI analyzer has updated recommendations
   if(GlobalVariableCheck("AI_LastUpdate"))
   {
      datetime aiLastUpdate = (datetime)GlobalVariableGet("AI_LastUpdate");
      
      //--- If AI has new recommendations, apply them
      if(aiLastUpdate > lastAICheck - (InpAIUpdateCheckMinutes * 60))
      {
         ApplyAIRecommendations();
      }
   }
}

//+------------------------------------------------------------------+
//| Apply AI recommendations with adaptation rate                    |
//+------------------------------------------------------------------+
void ApplyAIRecommendations()
{
   if(!GlobalVariableCheck("AI_SpikeThreshold"))
      return;
   
   //--- Get AI recommendations
   double newSpikeThreshold = GlobalVariableGet("AI_SpikeThreshold");
   int newCooldownPeriod = (int)GlobalVariableGet("AI_CooldownPeriod");
   double newStopLoss = GlobalVariableGet("AI_StopLoss");
   double newTakeProfit = GlobalVariableGet("AI_TakeProfit");
   double newRiskScore = GlobalVariableGet("AI_RiskScore");
   
   //--- Apply with adaptation rate (blend old and new values)
   double rate = MathMax(0.1, MathMin(1.0, InpAIAdaptationRate));
   
   aiSpikeThreshold = aiSpikeThreshold * (1.0 - rate) + newSpikeThreshold * rate;
   aiCooldownPeriod = (int)(aiCooldownPeriod * (1.0 - rate) + newCooldownPeriod * rate);
   aiStopLoss = aiStopLoss * (1.0 - rate) + newStopLoss * rate;
   aiTakeProfit = aiTakeProfit * (1.0 - rate) + newTakeProfit * rate;
   aiRiskScore = aiRiskScore * (1.0 - rate) + newRiskScore * rate;
   
   Print("AI Parameters Updated:");
   Print("Spike Threshold: ", DoubleToString(aiSpikeThreshold, 2), " (was ", DoubleToString(InpSpikeThreshold, 2), ")");
   Print("Cooldown Period: ", IntegerToString(aiCooldownPeriod), "s (was ", IntegerToString(InpCooldownPeriod), "s)");
   Print("Stop Loss: ", DoubleToString(aiStopLoss, 1), " pips (was ", DoubleToString(InpStopLoss, 1), " pips)");
   Print("Take Profit: ", DoubleToString(aiTakeProfit, 1), " pips (was ", DoubleToString(InpTakeProfit, 1), " pips)");
   Print("AI Risk Score: ", DoubleToString(aiRiskScore, 1), "/10");
}

//+------------------------------------------------------------------+
//| Detect spike using AI-adapted parameters                        |
//+------------------------------------------------------------------+
SpikeInfo DetectSpike()
{
   SpikeInfo spike;
   spike.detected = false;
   spike.isCrash = false;
   spike.spikeSize = 0.0;
   spike.spikeTime = 0;
   spike.entryPrice = 0.0;
   spike.aiConfidence = 0.0;
   
   //--- Use AI-adapted spike threshold
   double thresholdToUse = InpUseAIRecommendations ? aiSpikeThreshold : InpSpikeThreshold;
   
   //--- Get current price data
   double high[], low[], close[], open[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, InpSpikeCandles + 1, high) <= 0 ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, InpSpikeCandles + 1, low) <= 0 ||
      CopyClose(_Symbol, PERIOD_CURRENT, 0, InpSpikeCandles + 1, close) <= 0 ||
      CopyOpen(_Symbol, PERIOD_CURRENT, 0, InpSpikeCandles + 1, open) <= 0)
   {
      return spike;
   }
   
   //--- Check for crash spike (sudden drop)
   double maxHigh = high[ArrayMaximum(high, 1, InpSpikeCandles)];
   double currentLow = low[0];
   double crashSize = (maxHigh - currentLow) / _Point;
   double crashPercent = ((maxHigh - currentLow) / maxHigh) * 100.0;
   
   //--- Check for boom spike (sudden rise)
   double minLow = low[ArrayMinimum(low, 1, InpSpikeCandles)];
   double currentHigh = high[0];
   double boomSize = (currentHigh - minLow) / _Point;
   double boomPercent = ((currentHigh - minLow) / minLow) * 100.0;
   
   //--- Calculate AI confidence based on risk score and threshold
   double confidence = CalculateAIConfidence(aiRiskScore, thresholdToUse);
   
   //--- Determine if we have a significant spike
   if(crashSize >= InpMinSpikePips && crashPercent >= thresholdToUse)
   {
      spike.detected = true;
      spike.isCrash = true;
      spike.spikeSize = crashSize;
      spike.spikeTime = TimeCurrent();
      spike.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      spike.aiConfidence = confidence;
      
      Print("CRASH SPIKE DETECTED! Size: ", DoubleToString(crashSize, 1), " pips (", 
            DoubleToString(crashPercent, 2), "%) AI Confidence: ", DoubleToString(confidence, 1), "%");
   }
   else if(boomSize >= InpMinSpikePips && boomPercent >= thresholdToUse)
   {
      spike.detected = true;
      spike.isCrash = false;
      spike.spikeSize = boomSize;
      spike.spikeTime = TimeCurrent();
      spike.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      spike.aiConfidence = confidence;
      
      Print("BOOM SPIKE DETECTED! Size: ", DoubleToString(boomSize, 1), " pips (", 
            DoubleToString(boomPercent, 2), "%) AI Confidence: ", DoubleToString(confidence, 1), "%");
   }
   
   return spike;
}

//+------------------------------------------------------------------+
//| Calculate AI confidence level                                    |
//+------------------------------------------------------------------+
double CalculateAIConfidence(double riskScore, double threshold)
{
   //--- Base confidence from risk score (inverted - lower risk = higher confidence)
   double baseConfidence = (10.0 - riskScore) * 10.0; // 0-100%
   
   //--- Adjust based on how close threshold is to standard
   double thresholdFactor = 1.0;
   if(InpSpikeThreshold > 0)
   {
      thresholdFactor = InpSpikeThreshold / threshold;
      thresholdFactor = MathMax(0.5, MathMin(2.0, thresholdFactor));
   }
   
   //--- Final confidence calculation
   double confidence = baseConfidence * thresholdFactor;
   return MathMax(0.0, MathMin(100.0, confidence));
}

//+------------------------------------------------------------------+
//| Execute spike trade with AI parameters                          |
//+------------------------------------------------------------------+
void ExecuteSpikeTrade(SpikeInfo &spike)
{
   //--- Use AI-adapted cooldown period
   int cooldownToUse = InpUseAIRecommendations ? aiCooldownPeriod : InpCooldownPeriod;
   
   //--- Check cooldown period
   if(TimeCurrent() - lastTradeTime < cooldownToUse)
   {
      Print("Cooldown period active. Skipping trade.");
      return;
   }
   
   //--- Additional filters
   if(InpUseRSIFilter && !CheckRSIFilter(spike.isCrash))
      return;
   
   if(InpUseTrendFilter && !CheckTrendFilter(spike.isCrash))
      return;
   
   //--- Use AI-adapted risk parameters
   double stopLossToUse = InpUseAIRecommendations ? aiStopLoss : InpStopLoss;
   double takeProfitToUse = InpUseAIRecommendations ? aiTakeProfit : InpTakeProfit;
   
   //--- Calculate trade parameters
   double entryPrice, stopLoss, takeProfit;
   ENUM_ORDER_TYPE orderType;
   
   if(spike.isCrash)
   {
      //--- After crash spike, expect bounce up (BUY)
      orderType = ORDER_TYPE_BUY;
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      stopLoss = entryPrice - (stopLossToUse * _Point);
      takeProfit = entryPrice + (takeProfitToUse * _Point);
   }
   else
   {
      //--- After boom spike, expect pullback down (SELL)
      orderType = ORDER_TYPE_SELL;
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      stopLoss = entryPrice + (stopLossToUse * _Point);
      takeProfit = entryPrice - (takeProfitToUse * _Point);
   }
   
   //--- Normalize prices
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   //--- Execute trade
   string aiFlag = InpUseAIRecommendations ? "AI" : "STD";
   string comment = StringFormat("SpikeScalp_%s_%s_%.1fpips_C%.0f", 
                                 spike.isCrash ? "Crash" : "Boom",
                                 aiFlag,
                                 spike.spikeSize,
                                 spike.aiConfidence);
   
   if(trade.PositionOpen(_Symbol, orderType, InpLotSize, entryPrice, stopLoss, takeProfit, comment))
   {
      Print("Spike trade executed: ", EnumToString(orderType), 
            " at ", entryPrice, " SL:", stopLoss, " TP:", takeProfit);
      Print("AI Confidence: ", DoubleToString(spike.aiConfidence, 1), "%");
      
      lastTradeTime = TimeCurrent();
      
      //--- Track AI vs standard performance
      aiStats.totalTrades++;
      if(InpUseAIRecommendations)
      {
         aiStats.aiTrades++;
      }
   }
   else
   {
      Print("Failed to execute spike trade. Error: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Check RSI filter                                                 |
//+------------------------------------------------------------------+
bool CheckRSIFilter(bool isCrashSpike)
{
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
            double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            profit += dealProfit;
            
            //--- Track AI performance
            string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
            if(StringFind(comment, "AI") >= 0)
            {
               aiStats.aiProfitSum += dealProfit;
            }
            else
            {
               aiStats.standardProfitSum += dealProfit;
            }
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
//| Display AI performance statistics                                |
//+------------------------------------------------------------------+
void DisplayAIPerformance()
{
   if(aiStats.totalTrades == 0)
      return;
   
   Print("=== AI PERFORMANCE SUMMARY ===");
   Print("Total Trades: ", IntegerToString(aiStats.totalTrades));
   Print("AI Trades: ", IntegerToString(aiStats.aiTrades), " (", DoubleToString((double)aiStats.aiTrades/(double)aiStats.totalTrades*100.0, 1), "%)");
   Print("Standard Trades: ", IntegerToString(aiStats.totalTrades - aiStats.aiTrades));
   
   if(aiStats.aiTrades > 0)
   {
      Print("AI Average Profit: $", DoubleToString(aiStats.aiProfitSum/aiStats.aiTrades, 2));
   }
   
   if(aiStats.totalTrades - aiStats.aiTrades > 0)
   {
      Print("Standard Average Profit: $", DoubleToString(aiStats.standardProfitSum/(double)(aiStats.totalTrades - aiStats.aiTrades), 2));
   }
   
   Print("AI Total P&L: $", DoubleToString(aiStats.aiProfitSum, 2));
   Print("Standard Total P&L: $", DoubleToString(aiStats.standardProfitSum, 2));
}

//+------------------------------------------------------------------+
//| Display information on chart                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   string info = StringFormat("AI CrashBoom Scalper | Daily P&L: $%.2f | AI Risk: %.1f/10 | Spread: %d", 
                              dailyProfit, 
                              aiRiskScore,
                              SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
   
   if(InpUseAIRecommendations)
   {
      info += StringFormat("\nAI Params: Thresh=%.2f%% CD=%ds SL=%.1f TP=%.1f", 
                           aiSpikeThreshold, aiCooldownPeriod, aiStopLoss, aiTakeProfit);
   }
   
   Comment(info);
}

//+------------------------------------------------------------------+ 