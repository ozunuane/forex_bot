//+------------------------------------------------------------------+
//|                                           CrashBoomScalper.mq5 |
//|                                    Copyright 2025, YourName    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, YourName"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Professional Crash & Boom Spike Scalping EA"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input parameters
input group "=== TRADING SETTINGS ==="
input double   InpLotSize = 0.01;                    // Lot Size
input int      InpMagicNumber = 123456;              // Magic Number
input int      InpMaxSpread = 50;                    // Maximum Spread (points)
input bool     InpTradeOnlyDuringSession = true;     // Trade Only During Active Session

input group "=== SPIKE DETECTION ==="
input int      InpSpikeCandles = 5;                  // Candles to analyze for spike
input double   InpSpikeThreshold = 1.5;              // Spike threshold (% price change)
input int      InpMinSpikePips = 100;                // Minimum spike size in pips
input int      InpCooldownPeriod = 300;              // Cooldown between trades (seconds)

input group "=== RISK MANAGEMENT ==="
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

input group "=== ADVANCED SETTINGS ==="
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

datetime       lastTradeTime = 0;
double         dailyProfit = 0.0;
datetime       currentDay = 0;
int            rsiHandle = INVALID_HANDLE;
int            emaHandle = INVALID_HANDLE;
double         rsiBuffer[];
double         emaBuffer[];

//--- Spike detection variables
struct SpikeInfo
{
   bool     detected;
   bool     isCrash;    // true for crash spike, false for boom spike
   double   spikeSize;
   datetime spikeTime;
   double   entryPrice;
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
   
   //--- Initialize daily tracking
   currentDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   dailyProfit = CalculateDailyProfit();
   
   Print("CrashBoomScalper EA initialized successfully");
   Print("Symbol: ", _Symbol);
   Print("Lot Size: ", InpLotSize);
   Print("Magic Number: ", InpMagicNumber);
   
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
   
   Print("CrashBoomScalper EA deinitialized. Reason: ", reason);
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
//| Detect spike in price action                                    |
//+------------------------------------------------------------------+
SpikeInfo DetectSpike()
{
   SpikeInfo spike;
   spike.detected = false;
   spike.isCrash = false;
   spike.spikeSize = 0.0;
   spike.spikeTime = 0;
   spike.entryPrice = 0.0;
   
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
   
   //--- Determine if we have a significant spike
   if(crashSize >= InpMinSpikePips && crashPercent >= InpSpikeThreshold)
   {
      spike.detected = true;
      spike.isCrash = true;
      spike.spikeSize = crashSize;
      spike.spikeTime = TimeCurrent();
      spike.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      Print("CRASH SPIKE DETECTED! Size: ", DoubleToString(crashSize, 1), " pips (", 
            DoubleToString(crashPercent, 2), "%)");
   }
   else if(boomSize >= InpMinSpikePips && boomPercent >= InpSpikeThreshold)
   {
      spike.detected = true;
      spike.isCrash = false;
      spike.spikeSize = boomSize;
      spike.spikeTime = TimeCurrent();
      spike.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      Print("BOOM SPIKE DETECTED! Size: ", DoubleToString(boomSize, 1), " pips (", 
            DoubleToString(boomPercent, 2), "%)");
   }
   
   return spike;
}

//+------------------------------------------------------------------+
//| Execute spike trade                                              |
//+------------------------------------------------------------------+
void ExecuteSpikeTrade(SpikeInfo &spike)
{
   //--- Check cooldown period
   if(TimeCurrent() - lastTradeTime < InpCooldownPeriod)
   {
      Print("Cooldown period active. Skipping trade.");
      return;
   }
   
   //--- Additional filters
   if(InpUseRSIFilter && !CheckRSIFilter(spike.isCrash))
      return;
   
   if(InpUseTrendFilter && !CheckTrendFilter(spike.isCrash))
      return;
   
   //--- Calculate trade parameters
   double entryPrice, stopLoss, takeProfit;
   ENUM_ORDER_TYPE orderType;
   
   if(spike.isCrash)
   {
      //--- After crash spike, expect bounce up (BUY)
      orderType = ORDER_TYPE_BUY;
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      stopLoss = entryPrice - (InpStopLoss * _Point);
      takeProfit = entryPrice + (InpTakeProfit * _Point);
   }
   else
   {
      //--- After boom spike, expect pullback down (SELL)
      orderType = ORDER_TYPE_SELL;
      entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      stopLoss = entryPrice + (InpStopLoss * _Point);
      takeProfit = entryPrice - (InpTakeProfit * _Point);
   }
   
   //--- Normalize prices
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   //--- Execute trade
   string comment = StringFormat("SpikeScalp_%s_%.1fpips", 
                                 spike.isCrash ? "Crash" : "Boom", 
                                 spike.spikeSize);
   
   if(trade.PositionOpen(_Symbol, orderType, InpLotSize, entryPrice, stopLoss, takeProfit, comment))
   {
      Print("Spike trade executed: ", EnumToString(orderType), 
            " at ", entryPrice, " SL:", stopLoss, " TP:", takeProfit);
      lastTradeTime = TimeCurrent();
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
      return true; // Skip filter if data not available
   
   double currentRSI = rsiBuffer[0];
   
   if(isCrashSpike)
   {
      //--- For crash spike (expecting bounce up), RSI should be oversold
      return currentRSI <= InpRSIOverSold;
   }
   else
   {
      //--- For boom spike (expecting pullback down), RSI should be overbought
      return currentRSI >= InpRSIOverBought;
   }
}

//+------------------------------------------------------------------+
//| Check trend filter                                               |
//+------------------------------------------------------------------+
bool CheckTrendFilter(bool isCrashSpike)
{
   if(CopyBuffer(emaHandle, 0, 0, 2, emaBuffer) <= 0)
      return true; // Skip filter if data not available
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ema = emaBuffer[0];
   
   if(isCrashSpike)
   {
      //--- For crash spike bounce, prefer when price is below EMA (oversold condition)
      return currentPrice < ema;
   }
   else
   {
      //--- For boom spike pullback, prefer when price is above EMA (overbought condition)
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
   if(spread > InpMaxSpread)
   {
      return true; // Don't trade if spread is too high
   }
   return false;
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
   
   // Check closed trades for today
   HistorySelect(today, TimeCurrent());
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
            HistoryDealGetInteger(ticket, DEAL_TYPE) <= 1) // Only buy/sell deals
         {
            profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         }
      }
   }
   
   // Add current open positions profit
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
   string info = StringFormat("CrashBoom Scalper | Daily P&L: $%.2f | Spread: %d", 
                              dailyProfit, 
                              SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
   
   Comment(info);
}

//+------------------------------------------------------------------+ 