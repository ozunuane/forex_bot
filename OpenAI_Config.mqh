//+------------------------------------------------------------------+
//|                                             OpenAI_Config.mqh   |
//|                           OpenAI Integration Configuration      |
//|                                    Copyright 2025, YourName     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, YourName"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| OpenAI Configuration Constants                                   |
//+------------------------------------------------------------------+

// OpenAI API Configuration
#define OPENAI_API_URL "https://api.openai.com/v1/chat/completions"
#define OPENAI_MODELS_GPT4 "gpt-4"
#define OPENAI_MODELS_GPT35 "gpt-3.5-turbo"
#define OPENAI_MODELS_GPT4_TURBO "gpt-4-turbo"

// Request Configuration
#define OPENAI_MAX_TOKENS 1500
#define OPENAI_TEMPERATURE 0.3
#define OPENAI_REQUEST_TIMEOUT 30000  // 30 seconds

// Analysis Configuration
#define AI_MIN_SPIKES_FOR_ANALYSIS 10
#define AI_MAX_SPIKES_PER_REQUEST 100
#define AI_DEFAULT_ANALYSIS_PERIOD 30  // days
#define AI_UPDATE_INTERVAL_HOURS 6

// File Paths
#define AI_ANALYSIS_FOLDER "AIAnalysis"
#define AI_CONFIG_FILE "ai_config.txt"
#define AI_RESULTS_FILE "ai_results.json"
#define AI_PERFORMANCE_FILE "ai_performance.csv"

//+------------------------------------------------------------------+
//| OpenAI Request Structure                                         |
//+------------------------------------------------------------------+
struct OpenAIRequest
{
   string model;
   string prompt;
   int    maxTokens;
   double temperature;
   string apiKey;
};

//+------------------------------------------------------------------+
//| OpenAI Response Structure                                        |
//+------------------------------------------------------------------+
struct OpenAIResponse
{
   bool   success;
   string content;
   string error;
   int    tokensUsed;
   double confidence;
};

//+------------------------------------------------------------------+
//| AI Analysis Parameters                                           |
//+------------------------------------------------------------------+
struct AIAnalysisParams
{
   // Market Analysis
   string symbol;
   int    analysisPeriodDays;
   int    minSpikeSize;
   double spikeThreshold;
   int    maxSpikesToAnalyze;
   
   // Technical Indicators
   int    rsiPeriod;
   int    emaPeriod;
   bool   useVolumeAnalysis;
   bool   useVolatilityAnalysis;
   
   // Risk Management
   double maxDailyLoss;
   double maxDailyProfit;
   int    maxConcurrentTrades;
   bool   useTrailingStops;
   
   // Market Conditions
   datetime startTime;
   datetime endTime;
   string   marketSession;
   bool     excludeWeekends;
   bool     excludeHolidays;
};

//+------------------------------------------------------------------+
//| AI Recommendation Structure                                      |
//+------------------------------------------------------------------+
struct AIRecommendation
{
   // Spike Detection
   double optimalSpikeThreshold;
   int    recommendedCooldownPeriod;
   int    suggestedSpikeCandles;
   double minimumSpikeSize;
   
   // Risk Management
   double suggestedStopLoss;
   double suggestedTakeProfit;
   double recommendedLotSize;
   double trailingStopDistance;
   
   // Technical Analysis
   int    optimalRSIPeriod;
   double rsiOverboughtLevel;
   double rsiOversoldLevel;
   int    optimalEMAPeriod;
   bool   useTrendFilter;
   
   // Market Timing
   int    bestTradingHours[];
   string marketCondition;
   double volatilityScore;
   
   // Performance Metrics
   double expectedWinRate;
   double expectedProfitFactor;
   double riskScore;
   double confidenceLevel;
   
   // AI Analysis
   string reasoning;
   datetime analysisTime;
   int    spikesAnalyzed;
   double aiModelConfidence;
};

//+------------------------------------------------------------------+
//| Market Condition Enumeration                                     |
//+------------------------------------------------------------------+
enum ENUM_MARKET_CONDITION
{
   MARKET_TRENDING_UP,
   MARKET_TRENDING_DOWN,
   MARKET_RANGING,
   MARKET_HIGH_VOLATILITY,
   MARKET_LOW_VOLATILITY,
   MARKET_UNCERTAIN
};

//+------------------------------------------------------------------+
//| AI Analysis Status                                               |
//+------------------------------------------------------------------+
enum ENUM_AI_STATUS
{
   AI_STATUS_IDLE,
   AI_STATUS_COLLECTING_DATA,
   AI_STATUS_ANALYZING,
   AI_STATUS_READY,
   AI_STATUS_ERROR
};

//+------------------------------------------------------------------+
//| Global AI Configuration                                          |
//+------------------------------------------------------------------+
class CAIConfig
{
private:
   string            m_apiKey;
   string            m_model;
   AIAnalysisParams  m_params;
   ENUM_AI_STATUS    m_status;
   datetime          m_lastAnalysis;
   
public:
   // Constructor
   CAIConfig()
   {
      m_apiKey = "";
      m_model = OPENAI_MODELS_GPT4;
      m_status = AI_STATUS_IDLE;
      m_lastAnalysis = 0;
      InitializeDefaultParams();
   }
   
   // Setters
   void SetAPIKey(string key) { m_apiKey = key; }
   void SetModel(string model) { m_model = model; }
   void SetStatus(ENUM_AI_STATUS status) { m_status = status; }
   void SetLastAnalysis(datetime time) { m_lastAnalysis = time; }
   
   // Getters
   string GetAPIKey() const { return m_apiKey; }
   string GetModel() const { return m_model; }
   ENUM_AI_STATUS GetStatus() const { return m_status; }
   datetime GetLastAnalysis() const { return m_lastAnalysis; }
   AIAnalysisParams GetParams() const { return m_params; }
   
   // Parameter management
   void SetAnalysisPeriod(int days) { m_params.analysisPeriodDays = days; }
   void SetSpikeThreshold(double threshold) { m_params.spikeThreshold = threshold; }
   void SetMinSpikeSize(int size) { m_params.minSpikeSize = size; }
   
   // Validation
   bool IsConfigValid()
   {
      return (StringLen(m_apiKey) > 10 && 
              StringLen(m_model) > 0 && 
              m_params.analysisPeriodDays > 0);
   }
   
   // Save/Load configuration
   bool SaveConfig()
   {
      string fileName = AI_ANALYSIS_FOLDER + "\\" + AI_CONFIG_FILE;
      int file = FileOpen(fileName, FILE_WRITE|FILE_TXT);
      
      if(file != INVALID_HANDLE)
      {
         FileWrite(file, "API_KEY=" + m_apiKey);
         FileWrite(file, "MODEL=" + m_model);
         FileWrite(file, "ANALYSIS_PERIOD=" + IntegerToString(m_params.analysisPeriodDays));
         FileWrite(file, "SPIKE_THRESHOLD=" + DoubleToString(m_params.spikeThreshold, 2));
         FileWrite(file, "MIN_SPIKE_SIZE=" + IntegerToString(m_params.minSpikeSize));
         FileWrite(file, "RSI_PERIOD=" + IntegerToString(m_params.rsiPeriod));
         FileWrite(file, "EMA_PERIOD=" + IntegerToString(m_params.emaPeriod));
         
         FileClose(file);
         return true;
      }
      
      return false;
   }
   
   bool LoadConfig()
   {
      string fileName = AI_ANALYSIS_FOLDER + "\\" + AI_CONFIG_FILE;
      int file = FileOpen(fileName, FILE_READ|FILE_TXT);
      
      if(file != INVALID_HANDLE)
      {
         while(!FileIsEnding(file))
         {
            string line = FileReadString(file);
            ParseConfigLine(line);
         }
         
         FileClose(file);
         return true;
      }
      
      return false;
   }

private:
   void InitializeDefaultParams()
   {
      m_params.symbol = _Symbol;
      m_params.analysisPeriodDays = AI_DEFAULT_ANALYSIS_PERIOD;
      m_params.minSpikeSize = 50;
      m_params.spikeThreshold = 1.5;
      m_params.maxSpikesToAnalyze = AI_MAX_SPIKES_PER_REQUEST;
      m_params.rsiPeriod = 14;
      m_params.emaPeriod = 21;
      m_params.useVolumeAnalysis = false;
      m_params.useVolatilityAnalysis = true;
      m_params.maxDailyLoss = 100.0;
      m_params.maxDailyProfit = 200.0;
      m_params.maxConcurrentTrades = 5;
      m_params.useTrailingStops = true;
      m_params.marketSession = "London/New York";
      m_params.excludeWeekends = true;
      m_params.excludeHolidays = false;
   }
   
   void ParseConfigLine(string line)
   {
      int pos = StringFind(line, "=");
      if(pos > 0)
      {
         string key = StringSubstr(line, 0, pos);
         string value = StringSubstr(line, pos + 1);
         
         if(key == "API_KEY") m_apiKey = value;
         else if(key == "MODEL") m_model = value;
         else if(key == "ANALYSIS_PERIOD") m_params.analysisPeriodDays = StringToInteger(value);
         else if(key == "SPIKE_THRESHOLD") m_params.spikeThreshold = StringToDouble(value);
         else if(key == "MIN_SPIKE_SIZE") m_params.minSpikeSize = StringToInteger(value);
         else if(key == "RSI_PERIOD") m_params.rsiPeriod = StringToInteger(value);
         else if(key == "EMA_PERIOD") m_params.emaPeriod = StringToInteger(value);
      }
   }
};

//+------------------------------------------------------------------+
//| AI Performance Tracking                                          |
//+------------------------------------------------------------------+
class CAIPerformance
{
private:
   struct TradeRecord
   {
      datetime openTime;
      datetime closeTime;
      double   profit;
      bool     wasAIRecommended;
      double   aiConfidence;
      string   symbol;
      string   comment;
   };
   
   TradeRecord trades[];
   int         totalTrades;
   int         aiTrades;
   double      totalProfit;
   double      aiProfit;
   
public:
   CAIPerformance()
   {
      totalTrades = 0;
      aiTrades = 0;
      totalProfit = 0.0;
      aiProfit = 0.0;
      ArrayResize(trades, 0);
   }
   
   void AddTrade(datetime openTime, datetime closeTime, double profit, 
                 bool wasAI, double confidence, string symbol, string comment)
   {
      int newSize = ArraySize(trades) + 1;
      ArrayResize(trades, newSize);
      
      trades[newSize-1].openTime = openTime;
      trades[newSize-1].closeTime = closeTime;
      trades[newSize-1].profit = profit;
      trades[newSize-1].wasAIRecommended = wasAI;
      trades[newSize-1].aiConfidence = confidence;
      trades[newSize-1].symbol = symbol;
      trades[newSize-1].comment = comment;
      
      totalTrades++;
      totalProfit += profit;
      
      if(wasAI)
      {
         aiTrades++;
         aiProfit += profit;
      }
   }
   
   double GetAIWinRate()
   {
      if(aiTrades == 0) return 0.0;
      
      int aiWins = 0;
      for(int i = 0; i < ArraySize(trades); i++)
      {
         if(trades[i].wasAIRecommended && trades[i].profit > 0)
            aiWins++;
      }
      
      return (double)aiWins / aiTrades * 100.0;
   }
   
   double GetStandardWinRate()
   {
      int standardTrades = totalTrades - aiTrades;
      if(standardTrades == 0) return 0.0;
      
      int standardWins = 0;
      for(int i = 0; i < ArraySize(trades); i++)
      {
         if(!trades[i].wasAIRecommended && trades[i].profit > 0)
            standardWins++;
      }
      
      return (double)standardWins / standardTrades * 100.0;
   }
   
   void SavePerformanceReport()
   {
      string fileName = AI_ANALYSIS_FOLDER + "\\" + AI_PERFORMANCE_FILE;
      int file = FileOpen(fileName, FILE_WRITE|FILE_CSV);
      
      if(file != INVALID_HANDLE)
      {
         // Write header
         FileWrite(file, "OpenTime,CloseTime,Profit,AIRecommended,Confidence,Symbol,Comment");
         
         // Write data
         for(int i = 0; i < ArraySize(trades); i++)
         {
            string line = TimeToString(trades[i].openTime) + "," +
                         TimeToString(trades[i].closeTime) + "," +
                         DoubleToString(trades[i].profit, 2) + "," +
                         (trades[i].wasAIRecommended ? "TRUE" : "FALSE") + "," +
                         DoubleToString(trades[i].aiConfidence, 1) + "," +
                         trades[i].symbol + "," +
                         trades[i].comment;
            
            FileWrite(file, line);
         }
         
         FileClose(file);
      }
   }
};

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
string EscapeJsonString(string str)
{
   StringReplace(str, "\\", "\\\\");
   StringReplace(str, "\"", "\\\"");
   StringReplace(str, "\n", "\\n");
   StringReplace(str, "\r", "\\r");
   StringReplace(str, "\t", "\\t");
   return str;
}

string CreateJSONRequest(string model, string prompt, string apiKey)
{
   string json = "{\n";
   json += "  \"model\": \"" + model + "\",\n";
   json += "  \"messages\": [\n";
   json += "    {\n";
   json += "      \"role\": \"user\",\n";
   json += "      \"content\": \"" + EscapeJsonString(prompt) + "\"\n";
   json += "    }\n";
   json += "  ],\n";
   json += "  \"max_tokens\": " + IntegerToString(OPENAI_MAX_TOKENS) + ",\n";
   json += "  \"temperature\": " + DoubleToString(OPENAI_TEMPERATURE, 1) + "\n";
   json += "}";
   
   return json;
}

bool IsValidAPIKey(string apiKey)
{
   return (StringLen(apiKey) >= 40 && StringFind(apiKey, "sk-") == 0);
}

//+------------------------------------------------------------------+ 