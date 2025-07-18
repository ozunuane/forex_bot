//+------------------------------------------------------------------+
//|                                                   AIAnalyzer.mq5 |
//|                         AI-Powered Spike Analysis for MT5        |
//|                                   Copyright 2025, Ozimede       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, YourName"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "AI-Powered Historical Spike Analysis and Parameter Optimization"

#include <Trade\Trade.mqh>
#include <Files\File.mqh>
#include <Arrays\ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Custom StringReplace function                                    |
//+------------------------------------------------------------------+
string CustomStringReplace(string str, string search, string replace)
{
   string result = str;
   int pos = StringFind(result, search);
   while(pos != -1)
   {
      result = StringSubstr(result, 0, pos) + replace + StringSubstr(result, pos + StringLen(search));
      pos = StringFind(result, search, pos + StringLen(replace));
   }
   return result;
}

//--- Input parameters
input group "=== AI INTEGRATION ==="
input string   InpOpenAIKey = "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";                    // OpenAI API Key
input string   InpOpenAIModel = "gpt-4";             // AI Model (gpt-4, gpt-3.5-turbo)
input bool     InpEnableAIAnalysis = true;           // Enable AI Analysis
input int      InpAnalysisPeriodDays = 30;           // Historical data period (days)
input int      InpUpdateIntervalHours = 24;          // Analysis update interval (hours)

input group "=== ANALYSIS SETTINGS ==="
input int      InpMinSpikeSize = 50;                 // Minimum spike size for analysis (pips)
input double   InpSpikeThresholdPercent = 1.0;       // Spike threshold percentage
input int      InpMaxSpikesToAnalyze = 1000;         // Maximum spikes to analyze
input bool     InpSaveAnalysisToFile = true;         // Save analysis results to file

input group "=== ADAPTATION SETTINGS ==="
input bool     InpAutoAdaptParameters = true;        // Auto-adapt EA parameters
input double   InpAdaptationSensitivity = 0.5;       // Adaptation sensitivity (0.1-1.0)
input bool     InpNotifyAdaptations = true;          // Notify when parameters change

//--- Global variables
struct SpikeData
{
   datetime timestamp;
   double   spikeSize;
   double   spikePercent;
   bool     isCrash;
   double   preBounceHigh;
   double   preBouceLow;
   double   postBounceHigh;
   double   postBounceLow;
   int      recoveryTime;
   double   maxRetracement;
   string   marketCondition;
};

struct AIRecommendation
{
   double   optimalSpikeThreshold;
   int      recommendedCooldown;
   double   suggestedStopLoss;
   double   suggestedTakeProfit;
   double   riskScore;
   string   marketTrend;
   double   confidenceLevel;
   string   reasoning;
};

//--- Arrays and variables
SpikeData        historicalSpikes[];
AIRecommendation currentRecommendation;
datetime         lastAnalysisTime = 0;
string           analysisResults = "";
int              fileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate inputs
   if(StringLen(InpOpenAIKey) < 10)
   {
      Print("ERROR: Please provide a valid OpenAI API Key");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- Initialize arrays
   ArrayResize(historicalSpikes, 0);
   
   //--- Create analysis directory
   if(!FolderCreate("AIAnalysis", 0))
   {
      if(GetLastError() != 5019) // Folder already exists
      {
         Print("Warning: Could not create AIAnalysis folder");
      }
   }
   
   Print("AI Analyzer initialized successfully");
   Print("Model: ", InpOpenAIModel);
   Print("Analysis Period: ", IntegerToString(InpAnalysisPeriodDays), " days");
   
   //--- Start initial analysis
   if(InpEnableAIAnalysis)
   {
      StartHistoricalAnalysis();
   }
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Close file handle if open
   if(fileHandle != INVALID_HANDLE)
   {
      FileClose(fileHandle);
   }
   
   Print("AI Analyzer deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if it's time for AI analysis update
   if(InpEnableAIAnalysis && ShouldUpdateAnalysis())
   {
      StartHistoricalAnalysis();
   }
}

//+------------------------------------------------------------------+
//| Check if analysis should be updated                              |
//+------------------------------------------------------------------+
bool ShouldUpdateAnalysis()
{
   return (TimeCurrent() - lastAnalysisTime) >= (InpUpdateIntervalHours * 3600);
}

//+------------------------------------------------------------------+
//| Start historical spike analysis                                  |
//+------------------------------------------------------------------+
void StartHistoricalAnalysis()
{
   Print("Starting AI-powered historical spike analysis...");
   
   //--- Collect historical spike data
   if(!CollectHistoricalSpikes())
   {
      Print("ERROR: Failed to collect historical spike data");
      return;
   }
   
   //--- Prepare data for AI analysis
   string analysisPrompt = PrepareAIPrompt();
   
   //--- Send to OpenAI for analysis
   string aiResponse = SendToOpenAI(analysisPrompt);
   
   if(StringLen(aiResponse) > 0)
   {
      //--- Parse AI response
      if(ParseAIResponse(aiResponse))
      {
         //--- Apply recommendations if auto-adaptation is enabled
         if(InpAutoAdaptParameters)
         {
            ApplyAIRecommendations();
         }
         
         //--- Save analysis results
         if(InpSaveAnalysisToFile)
         {
            SaveAnalysisResults(aiResponse);
         }
         
         lastAnalysisTime = TimeCurrent();
         Print("AI analysis completed successfully");
      }
      else
      {
         Print("ERROR: Failed to parse AI response");
      }
   }
   else
   {
      Print("ERROR: No response from OpenAI");
   }
}

//+------------------------------------------------------------------+
//| Collect historical spike data                                    |
//+------------------------------------------------------------------+
bool CollectHistoricalSpikes()
{
   //--- Calculate start time
   datetime startTime = TimeCurrent() - (InpAnalysisPeriodDays * 24 * 3600);
   
   //--- Get historical data
   double high[], low[], close[], open[];
   datetime time[];
   
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(time, true);
   
   int bars = Bars(_Symbol, PERIOD_M5);
   int barsToAnalyze = MathMin(bars, InpAnalysisPeriodDays * 24 * 12); // M5 bars
   
   if(CopyHigh(_Symbol, PERIOD_M5, 0, barsToAnalyze, high) <= 0 ||
      CopyLow(_Symbol, PERIOD_M5, 0, barsToAnalyze, low) <= 0 ||
      CopyClose(_Symbol, PERIOD_M5, 0, barsToAnalyze, close) <= 0 ||
      CopyOpen(_Symbol, PERIOD_M5, 0, barsToAnalyze, open) <= 0 ||
      CopyTime(_Symbol, PERIOD_M5, 0, barsToAnalyze, time) <= 0)
   {
      return false;
   }
   
   //--- Clear previous data
   ArrayResize(historicalSpikes, 0);
   
   //--- Analyze each candle for spikes
   for(int i = 5; i < barsToAnalyze - 5; i++)
   {
      if(ArraySize(historicalSpikes) >= InpMaxSpikesToAnalyze)
         break;
         
      //--- Check for crash spike
      double maxHigh = high[ArrayMaximum(high, i+1, 5)];
      double currentLow = low[i];
      double crashSize = (maxHigh - currentLow) / _Point;
      double crashPercent = ((maxHigh - currentLow) / maxHigh) * 100.0;
      
      if(crashSize >= InpMinSpikeSize && crashPercent >= InpSpikeThresholdPercent)
      {
         SpikeData spike;
         spike.timestamp = time[i];
         spike.spikeSize = crashSize;
         spike.spikePercent = crashPercent;
         spike.isCrash = true;
         
         //--- Analyze recovery pattern
         AnalyzeSpikeRecovery(spike, i, high, low, close);
         
         //--- Add to array
         int newSize = ArraySize(historicalSpikes) + 1;
         ArrayResize(historicalSpikes, newSize);
         historicalSpikes[newSize-1] = spike;
      }
      
      //--- Check for boom spike
      double minLow = low[ArrayMinimum(low, i+1, 5)];
      double currentHigh = high[i];
      double boomSize = (currentHigh - minLow) / _Point;
      double boomPercent = ((currentHigh - minLow) / minLow) * 100.0;
      
      if(boomSize >= InpMinSpikeSize && boomPercent >= InpSpikeThresholdPercent)
      {
         SpikeData spike;
         spike.timestamp = time[i];
         spike.spikeSize = boomSize;
         spike.spikePercent = boomPercent;
         spike.isCrash = false;
         
         //--- Analyze recovery pattern
         AnalyzeSpikeRecovery(spike, i, high, low, close);
         
         //--- Add to array
         int newSize = ArraySize(historicalSpikes) + 1;
         ArrayResize(historicalSpikes, newSize);
         historicalSpikes[newSize-1] = spike;
      }
   }
   
   Print("Collected ", IntegerToString(ArraySize(historicalSpikes)), " historical spikes for analysis");
   return ArraySize(historicalSpikes) > 0;
}

//+------------------------------------------------------------------+
//| Analyze spike recovery pattern                                   |
//+------------------------------------------------------------------+
void AnalyzeSpikeRecovery(SpikeData &spike, int spikeIndex, double &high[], double &low[], double &close[])
{
   //--- Analyze 20 bars after spike for recovery pattern
   int recoveryBars = MathMin(20, spikeIndex);
   
   if(spike.isCrash)
   {
      //--- Find highest point after crash spike
      double maxRecovery = high[ArrayMaximum(high, spikeIndex-recoveryBars, recoveryBars)];
      spike.maxRetracement = (maxRecovery - low[spikeIndex]) / _Point;
      
      //--- Find recovery time (when price crosses back above 50% retracement)
      double fiftyPercent = low[spikeIndex] + (spike.spikeSize * _Point * 0.5);
      for(int j = spikeIndex-1; j >= spikeIndex-recoveryBars; j--)
      {
         if(close[j] > fiftyPercent)
         {
            spike.recoveryTime = spikeIndex - j;
            break;
         }
      }
   }
   else
   {
      //--- Find lowest point after boom spike
      double maxRetracement = low[ArrayMinimum(low, spikeIndex-recoveryBars, recoveryBars)];
      spike.maxRetracement = (high[spikeIndex] - maxRetracement) / _Point;
      
      //--- Find recovery time
      double fiftyPercent = high[spikeIndex] - (spike.spikeSize * _Point * 0.5);
      for(int j = spikeIndex-1; j >= spikeIndex-recoveryBars; j--)
      {
         if(close[j] < fiftyPercent)
         {
            spike.recoveryTime = spikeIndex - j;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Prepare AI analysis prompt                                       |
//+------------------------------------------------------------------+
string PrepareAIPrompt()
{
   string prompt = "You are an expert quantitative analyst specializing in Crash and Boom synthetic indices. ";
   prompt += "Analyze the following historical spike data and provide optimized trading parameters.\n\n";
   
   prompt += "MARKET: " + _Symbol + "\n";
   prompt += "ANALYSIS PERIOD: " + IntegerToString(InpAnalysisPeriodDays) + " days\n";
   prompt += "TOTAL SPIKES ANALYZED: " + IntegerToString(ArraySize(historicalSpikes)) + "\n\n";
   
   prompt += "HISTORICAL SPIKE DATA:\n";
   prompt += "Format: [Type|Size(pips)|Percent|RecoveryTime|MaxRetracement]\n\n";
   
   //--- Add spike data (limit to prevent token overflow)
   int maxSpikesToInclude = MathMin(50, ArraySize(historicalSpikes));
   
   for(int i = 0; i < maxSpikesToInclude; i++)
   {
      SpikeData spike = historicalSpikes[i];
      prompt += (spike.isCrash ? "CRASH|" : "BOOM|");
      prompt += DoubleToString(spike.spikeSize, 1) + "|";
      prompt += DoubleToString(spike.spikePercent, 2) + "%|";
      prompt += IntegerToString(spike.recoveryTime) + "bars|";
      prompt += DoubleToString(spike.maxRetracement, 1) + "pips\n";
   }
   
   //--- Add statistical summary
   prompt += "\nSTATISTICAL SUMMARY:\n";
   prompt += CalculateStatistics();
   
   //--- Add analysis request
   prompt += "\nPLEASE ANALYZE AND PROVIDE:\n";
   prompt += "1. Optimal spike threshold (percentage)\n";
   prompt += "2. Recommended cooldown period (seconds)\n";
   prompt += "3. Suggested stop loss (pips)\n";
   prompt += "4. Suggested take profit (pips)\n";
   prompt += "5. Risk score (1-10, where 10 is highest risk)\n";
   prompt += "6. Current market trend assessment\n";
   prompt += "7. Confidence level (0-100%)\n";
   prompt += "8. Brief reasoning for recommendations\n\n";
   
   prompt += "FORMAT RESPONSE AS JSON:\n";
   prompt += "{\n";
   prompt += "  \"spike_threshold\": 1.5,\n";
   prompt += "  \"cooldown_seconds\": 300,\n";
   prompt += "  \"stop_loss_pips\": 20,\n";
   prompt += "  \"take_profit_pips\": 15,\n";
   prompt += "  \"risk_score\": 7,\n";
   prompt += "  \"market_trend\": \"volatile_ranging\",\n";
   prompt += "  \"confidence\": 85,\n";
   prompt += "  \"reasoning\": \"Analysis shows...\"\n";
   prompt += "}";
   
   return prompt;
}

//+------------------------------------------------------------------+
//| Calculate statistical summary                                    |
//+------------------------------------------------------------------+
string CalculateStatistics()
{
   if(ArraySize(historicalSpikes) == 0)
      return "No data available\n";
   
   int crashCount = 0, boomCount = 0;
   double totalCrashSize = 0, totalBoomSize = 0;
   double avgRecoveryTime = 0, avgRetracement = 0;
   
   for(int i = 0; i < ArraySize(historicalSpikes); i++)
   {
      SpikeData spike = historicalSpikes[i];
      
      if(spike.isCrash)
      {
         crashCount++;
         totalCrashSize += spike.spikeSize;
      }
      else
      {
         boomCount++;
         totalBoomSize += spike.spikeSize;
      }
      
      avgRecoveryTime += spike.recoveryTime;
      avgRetracement += spike.maxRetracement;
   }
   
   int total = ArraySize(historicalSpikes);
   avgRecoveryTime /= total;
   avgRetracement /= total;
   
   string stats = "";
   stats += "Crash Spikes: " + IntegerToString(crashCount) + " (" + DoubleToString((double)crashCount/total*100, 1) + "%)\n";
   stats += "Boom Spikes: " + IntegerToString(boomCount) + " (" + DoubleToString((double)boomCount/total*100, 1) + "%)\n";
   stats += "Avg Crash Size: " + DoubleToString(crashCount > 0 ? totalCrashSize/crashCount : 0, 1) + " pips\n";
   stats += "Avg Boom Size: " + DoubleToString(boomCount > 0 ? totalBoomSize/boomCount : 0, 1) + " pips\n";
   stats += "Avg Recovery Time: " + DoubleToString(avgRecoveryTime, 1) + " bars\n";
   stats += "Avg Max Retracement: " + DoubleToString(avgRetracement, 1) + " pips\n";
   
   return stats;
}

//+------------------------------------------------------------------+
//| Send analysis request to OpenAI                                  |
//+------------------------------------------------------------------+
string SendToOpenAI(string prompt)
{
   string url = "https://api.openai.com/v1/chat/completions";
   string headers = "Content-Type: application/json\r\nAuthorization: Bearer " + InpOpenAIKey + "\r\n";
   
   //--- Prepare JSON payload
   string jsonPayload = "{\n";
   jsonPayload += "  \"model\": \"" + InpOpenAIModel + "\",\n";
   jsonPayload += "  \"messages\": [\n";
   jsonPayload += "    {\n";
   jsonPayload += "      \"role\": \"user\",\n";
   jsonPayload += "      \"content\": \"" + EscapeJsonString(prompt) + "\"\n";
   jsonPayload += "    }\n";
   jsonPayload += "  ],\n";
   jsonPayload += "  \"max_tokens\": 1000,\n";
   jsonPayload += "  \"temperature\": 0.3\n";
   jsonPayload += "}";
   
   //--- Send HTTP request
   char data[], result[];
   StringToCharArray(jsonPayload, data, 0, StringLen(jsonPayload));
   
   int timeout = 30000; // 30 seconds
   int res = WebRequest("POST", url, headers, timeout, data, result, headers);
   
   if(res == 200)
   {
      string response = CharArrayToString(result);
      return ExtractContentFromResponse(response);
   }
   else
   {
      Print("OpenAI API Error: HTTP ", IntegerToString(res));
      return "";
   }
}

//+------------------------------------------------------------------+
//| Escape JSON string                                               |
//+------------------------------------------------------------------+
string EscapeJsonString(string str)
{
   str = CustomStringReplace(str, "\\", "\\\\");
   str = CustomStringReplace(str, "\"", "\\\"");
   str = CustomStringReplace(str, "\n", "\\n");
   str = CustomStringReplace(str, "\r", "\\r");
   str = CustomStringReplace(str, "\t", "\\t");
   return str;
}

//+------------------------------------------------------------------+
//| Extract content from OpenAI response                             |
//+------------------------------------------------------------------+
string ExtractContentFromResponse(string response)
{
   //--- Find content field in JSON response
   int contentStart = StringFind(response, "\"content\":\"");
   if(contentStart == -1)
      return "";
   
   contentStart += 11; // Length of "content":"
   
   int contentEnd = StringFind(response, "\"", contentStart);
   if(contentEnd == -1)
      return "";
   
   string content = StringSubstr(response, contentStart, contentEnd - contentStart);
   
   //--- Unescape JSON
   content = CustomStringReplace(content, "\\n", "\n");
   content = CustomStringReplace(content, "\\\"", "\"");
   content = CustomStringReplace(content, "\\\\", "\\");
   
   return content;
}

//+------------------------------------------------------------------+
//| Parse AI response and extract recommendations                    |
//+------------------------------------------------------------------+
bool ParseAIResponse(string response)
{
   //--- Find JSON object in response
   int jsonStart = StringFind(response, "{");
   int jsonEnd = StringFind(response, "}", jsonStart);
   
   if(jsonStart == -1 || jsonEnd == -1)
      return false;
   
   string jsonStr = StringSubstr(response, jsonStart, jsonEnd - jsonStart + 1);
   
   //--- Parse JSON fields (simplified parsing)
   currentRecommendation.optimalSpikeThreshold = ExtractDoubleFromJson(jsonStr, "spike_threshold");
   currentRecommendation.recommendedCooldown = (int)ExtractDoubleFromJson(jsonStr, "cooldown_seconds");
   currentRecommendation.suggestedStopLoss = ExtractDoubleFromJson(jsonStr, "stop_loss_pips");
   currentRecommendation.suggestedTakeProfit = ExtractDoubleFromJson(jsonStr, "take_profit_pips");
   currentRecommendation.riskScore = ExtractDoubleFromJson(jsonStr, "risk_score");
   currentRecommendation.confidenceLevel = ExtractDoubleFromJson(jsonStr, "confidence");
   currentRecommendation.marketTrend = ExtractStringFromJson(jsonStr, "market_trend");
   currentRecommendation.reasoning = ExtractStringFromJson(jsonStr, "reasoning");
   
   Print("AI Recommendations parsed successfully");
   Print("Spike Threshold: ", currentRecommendation.optimalSpikeThreshold);
   Print("Cooldown: ", IntegerToString(currentRecommendation.recommendedCooldown), " seconds");
   Print("Stop Loss: ", currentRecommendation.suggestedStopLoss, " pips");
   Print("Take Profit: ", currentRecommendation.suggestedTakeProfit, " pips");
   Print("Risk Score: ", currentRecommendation.riskScore, "/10");
   Print("Confidence: ", currentRecommendation.confidenceLevel, "%");
   
   return true;
}

//+------------------------------------------------------------------+
//| Extract double value from JSON string                           |
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
//| Apply AI recommendations to EA parameters                        |
//+------------------------------------------------------------------+
void ApplyAIRecommendations()
{
   //--- Apply recommendations with sensitivity adjustment
   double sensitivity = MathMax(0.1, MathMin(1.0, InpAdaptationSensitivity));
   
   //--- Update global variables (these would be used by the main EA)
   GlobalVariableSet("AI_SpikeThreshold", currentRecommendation.optimalSpikeThreshold * sensitivity);
   GlobalVariableSet("AI_CooldownPeriod", currentRecommendation.recommendedCooldown * sensitivity);
   GlobalVariableSet("AI_StopLoss", currentRecommendation.suggestedStopLoss * sensitivity);
   GlobalVariableSet("AI_TakeProfit", currentRecommendation.suggestedTakeProfit * sensitivity);
   GlobalVariableSet("AI_RiskScore", currentRecommendation.riskScore);
   GlobalVariableSet("AI_LastUpdate", TimeCurrent());
   
   if(InpNotifyAdaptations)
   {
      string message = "AI Parameters Updated:\n";
      message += "Spike Threshold: " + DoubleToString(currentRecommendation.optimalSpikeThreshold, 2) + "\n";
      message += "Cooldown: " + IntegerToString(currentRecommendation.recommendedCooldown) + "s\n";
      message += "Stop Loss: " + DoubleToString(currentRecommendation.suggestedStopLoss, 1) + " pips\n";
      message += "Take Profit: " + DoubleToString(currentRecommendation.suggestedTakeProfit, 1) + " pips\n";
      message += "Risk Score: " + DoubleToString(currentRecommendation.riskScore, 1) + "/10\n";
      message += "Confidence: " + DoubleToString(currentRecommendation.confidenceLevel, 1) + "%";
      
      Print(message);
      Comment(message);
   }
}

//+------------------------------------------------------------------+
//| Save analysis results to file                                    |
//+------------------------------------------------------------------+
void SaveAnalysisResults(string aiResponse)
{
   string fileName = "AIAnalysis\\analysis_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ".txt";
   fileName = CustomStringReplace(fileName, ":", "_");
   fileName = CustomStringReplace(fileName, " ", "_");
   
   int file = FileOpen(fileName, FILE_WRITE|FILE_TXT);
   if(file != INVALID_HANDLE)
   {
      FileWrite(file, "=== AI SPIKE ANALYSIS REPORT ===");
      FileWrite(file, "Symbol: " + _Symbol);
      FileWrite(file, "Analysis Time: " + TimeToString(TimeCurrent()));
      FileWrite(file, "Period: " + IntegerToString(InpAnalysisPeriodDays) + " days");
      FileWrite(file, "Spikes Analyzed: " + IntegerToString(ArraySize(historicalSpikes)));
      FileWrite(file, "");
      FileWrite(file, "=== AI RESPONSE ===");
      FileWrite(file, aiResponse);
      FileWrite(file, "");
      FileWrite(file, "=== STATISTICAL SUMMARY ===");
      FileWrite(file, CalculateStatistics());
      
      FileClose(file);
      Print("Analysis results saved to: ", fileName);
   }
}

//+------------------------------------------------------------------+
//| Get current AI recommendations                                   |
//+------------------------------------------------------------------+
AIRecommendation GetCurrentRecommendations()
{
   return currentRecommendation;
}

//+------------------------------------------------------------------+ 