#property strict
#property version   "2.00"
#property description "Adaptive multi-factor Expert Advisor for XAUUSDm on MT5 with CSV logging and dashboard"

#include <Trade/Trade.mqh>

enum ENUM_SESSION
  {
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NEWYORK,
   SESSION_NONE
  };

enum ENUM_STRATEGY
  {
   STRATEGY_RANGE,
   STRATEGY_BREAKOUT,
   STRATEGY_TREND,
   STRATEGY_NONE
  };

enum ENUM_SCORE_MODE
  {
   SCORE_DISABLED = 0,
   SCORE_ENABLED  = 1
  };

input string           InpTradeSymbol            = "XAUUSDm";
input ENUM_TIMEFRAMES  InpTimeframe              = PERIOD_M5;
input ulong            InpMagicNumber            = 26032026;

input int              InpFastEmaPeriod          = 21;
input int              InpSlowEmaPeriod          = 100;
input int              InpRsiPeriod              = 14;
input int              InpAtrPeriod              = 14;

input double           InpVolAtrThreshold        = 150.0;
input int              InpBandsPeriod            = 20;
input double           InpBandsDeviation         = 2.0;

input double           InpRsiBuyMin              = 52.0;
input double           InpRsiBuyMax              = 68.0;
input double           InpRsiSellMin             = 32.0;
input double           InpRsiSellMax             = 48.0;

input double           InpRiskPercent            = 1.0;
input bool             InpAllowCounterTrend      = true;       // Allow Counter-Trend
input double           InpCounterTrendRisk       = 0.50;       // Counter-Trend Risk %
input int              InpCounterTrendMinScore   = 85;         // Counter-Trend Min Score
input double           InpStopAtrMultiplier      = 1.3;
input double           InpTakeProfitMultiplier   = 1.8;
input double           InpTrailAtrMultiplier     = 0.8;
input double           InpMinAtrPoints           = 120.0;
input double           InpPullbackAtrFactor      = 0.20;

input bool             InpAllowBuyTrades         = true;
input bool             InpAllowSellTrades        = true;

input int              InpMaxSpreadPoints        = 500;
input int              InpAsianStartHour         = 0;
input int              InpAsianEndHour           = 8;
input int              InpLondonStartHour        = 8;
input int              InpLondonEndHour          = 13;
input int              InpNewYorkStartHour       = 13;
input int              InpNewYorkEndHour         = 22;

input ENUM_SCORE_MODE  InpUseScoring             = SCORE_ENABLED;
input int              InpMinimumScore           = 80;
input int              InpWeightTrend            = 30;
input int              InpWeightEmaAlignment     = 25;
input int              InpWeightRsi              = 20;
input int              InpWeightRangeBB          = 50;
input int              InpWeightBreakout         = 50;
input int              InpWeightPullback         = 25;

input bool             InpEnableDebugPrints      = true;
input bool             InpEnableCSVLogging       = true;
input bool             InpEnableDashboard        = true;
input bool             InpLogEveryTick           = false;
input int              InpLogRetentionDays       = 7;
input bool             InpEnablePushAlerts       = false;
input bool             InpEnableEmailAlerts      = false;

CTrade trade;

string   g_dashboardPrefix  = "GoldEA_Dash_";
int      g_fastEmaHandle    = INVALID_HANDLE;
int      g_slowEmaHandle    = INVALID_HANDLE;
int      g_rsiHandle        = INVALID_HANDLE;
int      g_bbHandle         = INVALID_HANDLE;
int      g_atrHandle        = INVALID_HANDLE;
int      g_symbolDigits     = 2;
datetime g_lastBarTime      = 0;
datetime g_lastBuyBar       = 0;
datetime g_lastSellBar      = 0;
int      g_lastAsianDay     = -1;

double   g_asianHigh        = 0.0;
double   g_asianLow         = 0.0;

struct IndicatorSnapshot
  {
   bool   valid;
   int    shift;
   double price;
   double closePrice;
   double openPrice;
   double highPrice;
   double lowPrice;
   double prevHigh;
   double prevLow;
   double fastEma;
   double slowEma;
   double rsi;
   double prevRsi;
   double atr;
   double bbUpper;
   double bbLower;
   double bbBase;
   long   spread;
   bool   spreadOk;
   bool   isHighVol;
   ENUM_SESSION session;
   bool   volatilityOk;
   bool   priceAboveSlow;
   bool   priceBelowSlow;
   bool   emaBullish;
   bool   emaBearish;
   bool   rsiBuyOk;
   bool   rsiSellOk;
   bool   pullbackBuyOk;
   bool   pullbackSellOk;
  };

struct DecisionContext
  {
   bool               valid;
   ENUM_POSITION_TYPE type;
   string             sessionName;
   string             strategyName;
   string             action;
   string             phase;
   string             decision;
   string             reason;
   string             status;
   double             price;
   double             rsi;
   double             ema50;
   double             ema200;
   double             atr;
   long               spread;
   int                score;
   bool               isCounterTrend;
   double             riskPercent;
  };

string PositionTypeText(const ENUM_POSITION_TYPE type)
  {
   if(type == POSITION_TYPE_BUY)
      return "BUY";
   if(type == POSITION_TYPE_SELL)
      return "SELL";
   return "NONE";
  }

string SessionToString(const ENUM_SESSION s)
  {
   if(s == SESSION_ASIAN) return "ASIAN";
   if(s == SESSION_LONDON) return "LONDON";
   if(s == SESSION_NEWYORK) return "NEWYORK";
   return "NONE";
  }

string StrategyToString(const ENUM_STRATEGY s)
  {
   if(s == STRATEGY_RANGE) return "RANGE";
   if(s == STRATEGY_BREAKOUT) return "BREAKOUT";
   if(s == STRATEGY_TREND) return "TREND";
   return "NONE";
  }

string BuildStateKey(const string label,const ulong ticket)
  {
   return StringFormat("EA_%I64u_%s_%I64u",InpMagicNumber,label,ticket);
  }

string BuildGlobalKey(const string label)
  {
   return StringFormat("EA_%I64u_%s",InpMagicNumber,label);
  }

void DebugPrint(const string message)
  {
   if(InpEnableDebugPrints)
      Print("[GoldEA] ",message);
  }

string CurrentTimeText()
  {
   return TimeToString(TimeTradeServer(),TIME_DATE | TIME_SECONDS);
  }

double NormalizeVolume(const double volume)
  {
   double minLot  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_STEP);

   if(minLot <= 0.0)  minLot = 0.01;
   if(maxLot <= 0.0)  maxLot = 100.0;
   if(lotStep <= 0.0) lotStep = 0.01;

   double normalized = MathFloor(volume / lotStep) * lotStep;
   
   if(normalized < minLot)
     {
      DebugPrint(StringFormat("Warning: Calculated lot (%.4f) < Min Lot (%.2f). Forcing Min Lot.", volume, minLot));
      normalized = minLot;
     }
   else if(normalized > maxLot)
     {
      DebugPrint(StringFormat("Warning: Calculated lot (%.2f) > Max Lot (%.2f). Capping to Max Lot.", normalized, maxLot));
      normalized = maxLot;
     }
     
   int digits = 2;
   if(lotStep == 0.001) digits = 3;
   if(lotStep == 0.1) digits = 1;
   if(lotStep == 1.0) digits = 0;
   
   return NormalizeDouble(normalized, digits);
  }

bool GetIndicatorValue(const int handle,const int shift,double &value, const int bufferIndex = 0)
  {
   double buffer[];
   ArraySetAsSeries(buffer,true);
   if(CopyBuffer(handle,bufferIndex,shift,1,buffer) != 1)
      return false;

   value = buffer[0];
   return true;
  }

bool GetRates(MqlRates &rates[],const int count)
  {
   ArraySetAsSeries(rates,true);
   return (CopyRates(InpTradeSymbol,InpTimeframe,0,count,rates) == count);
  }

bool IsNewBar()
  {
   datetime times[];
   ArraySetAsSeries(times,true);
   if(CopyTime(InpTradeSymbol,InpTimeframe,0,1,times) != 1)
      return false;

   if(times[0] == g_lastBarTime)
      return false;

   g_lastBarTime = times[0];
   return true;
  }

ENUM_SESSION GetCurrentSession()
  {
   MqlDateTime serverTime;
   TimeToStruct(TimeTradeServer(),serverTime);
   int hour = serverTime.hour;
   if(hour >= InpAsianStartHour && hour < InpAsianEndHour) return SESSION_ASIAN;
   if(hour >= InpLondonStartHour && hour < InpLondonEndHour) return SESSION_LONDON;
   if(hour >= InpNewYorkStartHour && hour < InpNewYorkEndHour) return SESSION_NEWYORK;
   return SESSION_NONE;
  }

bool DetectVolatility(const double currentAtr)
  {
   return (currentAtr / _Point >= InpVolAtrThreshold);
  }

bool SpreadIsAcceptable()
  {
   long spread = SymbolInfoInteger(InpTradeSymbol,SYMBOL_SPREAD);
   return (spread <= InpMaxSpreadPoints);
  }

void UpdateAsianRange()
  {
   MqlDateTime time;
   TimeToStruct(TimeTradeServer(),time);
   if(time.hour >= InpAsianStartHour && time.hour < InpAsianEndHour)
     {
      if(time.day_of_year != g_lastAsianDay)
        {
         g_asianHigh = 0.0;
         g_asianLow = 999999.0;
         g_lastAsianDay = time.day_of_year;
        }
      double high[], low[];
      if(CopyHigh(InpTradeSymbol,InpTimeframe,0,1,high) == 1 && high[0] > g_asianHigh)
         g_asianHigh = high[0];
      if(CopyLow(InpTradeSymbol,InpTimeframe,0,1,low) == 1 && low[0] < g_asianLow && low[0] > 0.0)
         g_asianLow = low[0];
     }
  }

bool PositionExists(const ENUM_POSITION_TYPE positionType)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != InpTradeSymbol)
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == positionType)
         return true;
     }
   return false;
  }

ulong FindPositionTicket(const ENUM_POSITION_TYPE positionType)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != InpTradeSymbol)
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == positionType)
         return ticket;
     }
   return 0;
  }

double CalculateLotSize(const double stopDistance, const double riskPercent)
  {
   if(stopDistance <= 0.0)
     {
      DebugPrint("Error: Invalid Stop Loss distance. Distance is 0.");
      return SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) > 0 ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) : 0.01;
     }

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPercent / 100.0);
   double tickSize   = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
     {
      DebugPrint(StringFormat("Error: Invalid parameters. TickValue: %f, TickSize: %f", tickValue, tickSize));
      return SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) > 0 ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) : 0.01;
     }

   double moneyPerLot = (stopDistance / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
     {
      DebugPrint("Error: Calculated loss per lot is zero or negative.");
      return SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) > 0 ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) : 0.01;
     }

   double rawLot = riskAmount / moneyPerLot;
   double finalLot = NormalizeVolume(rawLot);
   
   DebugPrint(StringFormat("Lot Calc: Balance=%.2f, Risk=%.2f, StopDist=%.1f, LossPerLot=%.2f, RawLot=%.5f, FinalLot=%.2f",
                           balance, riskAmount, stopDistance, moneyPerLot, rawLot, finalLot));
                           
   return finalLot;
  }

ulong NextTradeId()
  {
   string key = BuildGlobalKey("TradeCounter");
   double current = 0.0;
   if(GlobalVariableCheck(key))
      current = GlobalVariableGet(key);

   current += 1.0;
   GlobalVariableSet(key,current);
   return (ulong)current;
  }

void CleanupOldLogs()
  {
   if(InpLogRetentionDays <= 0)
      return;

   string fileName;
   long searchHandle = FileFindFirst("GoldEA_Log_*.csv", fileName);
   if(searchHandle != INVALID_HANDLE)
     {
      datetime threshold = TimeTradeServer() - (InpLogRetentionDays * 86400);
      do
        {
         if(StringLen(fileName) < 20)
            continue;

         string dateToken = StringSubstr(fileName,11,8);
         string formattedDate = StringFormat("%s.%s.%s",StringSubstr(dateToken,0,4),StringSubstr(dateToken,4,2),StringSubstr(dateToken,6,2));
         datetime fileDate = StringToTime(formattedDate);
         if(fileDate > 0 && fileDate < threshold)
           {
            FileDelete(fileName);
            DebugPrint(StringFormat("Deleted old log file: %s", fileName));
           }
        }
      while(FileFindNext(searchHandle, fileName));
      FileFindClose(searchHandle);
     }
  }

void LogToCSV(const string action,
              const string sessionStr,
              const string strategyStr,
              const double price,
              const double rsi,
              const double ema50,
              const double ema200,
              const double atr,
              const long spread,
              const int score,
              const string decision,
              const string reason)
  {
   if(!InpEnableCSVLogging)
      return;

   string dateStr = TimeToString(TimeTradeServer(), TIME_DATE);
   StringReplace(dateStr, ".", "");
   string currentLogName = StringFormat("GoldEA_Log_%s.csv", dateStr);

   int handle = FileOpen(currentLogName,FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE,',');
   if(handle == INVALID_HANDLE)
     {
      DebugPrint(StringFormat("CSV open failed. error=%d",GetLastError()));
      return;
     }

   if(FileSize(handle) == 0)
      FileWrite(handle,"Time","Symbol","Action","Session","Strategy","Price","RSI","EMA50","EMA200","ATR","Spread","Score","Decision","Reason");

   FileSeek(handle,0,SEEK_END);
   FileWrite(handle,
             CurrentTimeText(),
             InpTradeSymbol,
             action,
             sessionStr,
             strategyStr,
             DoubleToString(price,g_symbolDigits),
             DoubleToString(rsi,2),
             DoubleToString(ema50,g_symbolDigits),
             DoubleToString(ema200,g_symbolDigits),
             DoubleToString(atr,g_symbolDigits),
             (string)spread,
             (string)score,
             decision,
             reason);
   FileFlush(handle);
   FileClose(handle);
  }

bool CalculateIndicators(IndicatorSnapshot &snapshot,const int shift)
  {
   snapshot.valid = false;
   snapshot.shift = shift;

   MqlRates rates[];
   if(!GetRates(rates,shift + 4))
      return false;

   if(!GetIndicatorValue(g_fastEmaHandle,shift,snapshot.fastEma) ||
      !GetIndicatorValue(g_slowEmaHandle,shift,snapshot.slowEma) ||
      !GetIndicatorValue(g_rsiHandle,shift,snapshot.rsi) ||
      !GetIndicatorValue(g_rsiHandle,shift+1,snapshot.prevRsi) ||
      !GetIndicatorValue(g_bbHandle,shift,snapshot.bbBase,0) ||
      !GetIndicatorValue(g_bbHandle,shift,snapshot.bbUpper,1) ||
      !GetIndicatorValue(g_bbHandle,shift,snapshot.bbLower,2) ||
      !GetIndicatorValue(g_atrHandle,shift,snapshot.atr))
      return false;

   int nextIndex = shift + 1;
   snapshot.price      = (SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID) + SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK)) * 0.5;
   snapshot.closePrice = rates[shift].close;
   snapshot.openPrice  = rates[shift].open;
   snapshot.highPrice  = rates[shift].high;
   snapshot.lowPrice   = rates[shift].low;
   snapshot.prevHigh   = rates[nextIndex].high;
   snapshot.prevLow    = rates[nextIndex].low;
   snapshot.spread     = SymbolInfoInteger(InpTradeSymbol,SYMBOL_SPREAD);
   snapshot.spreadOk   = SpreadIsAcceptable();
   snapshot.session    = GetCurrentSession();
   snapshot.isHighVol  = DetectVolatility(snapshot.atr);
   snapshot.volatilityOk   = (snapshot.atr / _Point >= InpMinAtrPoints);
   snapshot.priceAboveSlow = (snapshot.closePrice > snapshot.slowEma);
   snapshot.priceBelowSlow = (snapshot.closePrice < snapshot.slowEma);
   snapshot.emaBullish     = (snapshot.fastEma > snapshot.slowEma);
   snapshot.emaBearish     = (snapshot.fastEma < snapshot.slowEma);
   snapshot.rsiBuyOk       = (snapshot.rsi >= InpRsiBuyMin && snapshot.rsi <= InpRsiBuyMax);
   snapshot.rsiSellOk      = (snapshot.rsi >= InpRsiSellMin && snapshot.rsi <= InpRsiSellMax);
   snapshot.pullbackBuyOk  = (MathAbs(snapshot.lowPrice - snapshot.fastEma) <= snapshot.atr * InpPullbackAtrFactor);
   snapshot.pullbackSellOk = (MathAbs(snapshot.highPrice - snapshot.fastEma) <= snapshot.atr * InpPullbackAtrFactor);
   snapshot.valid = true;
   return true;
  }

DecisionContext RunRangeStrategy(const ENUM_POSITION_TYPE direction,const IndicatorSnapshot &snapshot,const bool isBarClose)
  {
   DecisionContext ctx;
   ctx.type = direction;
   ctx.action = "SIGNAL_CHECK";
   ctx.phase = "UNSPECIFIED";
   ctx.decision = PositionTypeText(direction);
   ctx.sessionName = SessionToString(snapshot.session);
   ctx.strategyName = "RANGE";
   ctx.status = snapshot.spreadOk ? "ACTIVE" : "BLOCKED";
   ctx.price = snapshot.price;
   ctx.rsi = snapshot.rsi;
   ctx.ema50 = snapshot.fastEma;
   ctx.ema200 = snapshot.slowEma;
   ctx.atr = snapshot.atr;
   ctx.spread = snapshot.spread;
   
   int rawScore = 0;
   bool rsiOk = false;
   bool bbOk = false;
   
   if(direction == POSITION_TYPE_BUY)
     {
      rsiOk = (snapshot.rsi < InpRsiSellMin);
      bbOk = (snapshot.closePrice <= snapshot.bbLower + (snapshot.atr * 0.2));
      if(rsiOk) rawScore += InpWeightRsi;
      if(bbOk) rawScore += InpWeightRangeBB;
     }
   else
     {
      rsiOk = (snapshot.rsi > InpRsiBuyMax);
      bbOk = (snapshot.closePrice >= snapshot.bbUpper - (snapshot.atr * 0.2));
      if(rsiOk) rawScore += InpWeightRsi;
      if(bbOk) rawScore += InpWeightRangeBB;
     }

   int maxScore = InpWeightRsi + InpWeightRangeBB;
   ctx.score = maxScore > 0 ? (int)MathRound((double)rawScore * 100.0 / (double)maxScore) : 0;

   bool structureOk = rsiOk && bbOk;
   bool scoreOk = (InpUseScoring == SCORE_DISABLED || ctx.score >= InpMinimumScore);
   ctx.valid = snapshot.spreadOk && structureOk && scoreOk;

   if(!snapshot.spreadOk) ctx.reason = "SPREAD_TOO_HIGH";
   else if(!structureOk) ctx.reason = "RANGE_STRUCTURE_FAIL";
   else if(!scoreOk) ctx.reason = "SCORE_TOO_LOW";
   else ctx.reason = "SETUP_VALID";

   return ctx;
  }

DecisionContext RunBreakoutStrategy(const ENUM_POSITION_TYPE direction,const IndicatorSnapshot &snapshot,const bool isBarClose)
  {
   DecisionContext ctx;
   ctx.type = direction;
   ctx.action = "SIGNAL_CHECK";
   ctx.phase = "UNSPECIFIED";
   ctx.decision = PositionTypeText(direction);
   ctx.sessionName = SessionToString(snapshot.session);
   ctx.strategyName = "BREAKOUT";
   ctx.status = snapshot.spreadOk ? "ACTIVE" : "BLOCKED";
   ctx.price = snapshot.price;
   ctx.rsi = snapshot.rsi;
   ctx.ema50 = snapshot.fastEma;
   ctx.ema200 = snapshot.slowEma;
   ctx.atr = snapshot.atr;
   ctx.spread = snapshot.spread;

   int rawScore = 0;
   bool breakOk = false;

   if(direction == POSITION_TYPE_BUY)
     {
      breakOk = (g_asianHigh > 0 && snapshot.closePrice > g_asianHigh);
      if(breakOk) rawScore += InpWeightBreakout;
     }
   else
     {
      breakOk = (g_asianLow > 0 && snapshot.closePrice < g_asianLow);
      if(breakOk) rawScore += InpWeightBreakout;
     }

   int maxScore = InpWeightBreakout;
   ctx.score = maxScore > 0 ? (int)MathRound((double)rawScore * 100.0 / (double)maxScore) : 0;

   bool scoreOk = (InpUseScoring == SCORE_DISABLED || ctx.score >= InpMinimumScore);
   ctx.valid = snapshot.spreadOk && breakOk && scoreOk;

   if(!snapshot.spreadOk) ctx.reason = "SPREAD_TOO_HIGH";
   else if(!breakOk) ctx.reason = "NO_ASIAN_BREAKOUT";
   else if(!scoreOk) ctx.reason = "SCORE_TOO_LOW";
   else ctx.reason = "SETUP_VALID";

   return ctx;
  }

DecisionContext RunTrendStrategy(const ENUM_POSITION_TYPE direction,const IndicatorSnapshot &snapshot,const bool isBarClose)
  {
   DecisionContext ctx;
   ctx.type = direction;
   ctx.action = "SIGNAL_CHECK";
   ctx.phase = "UNSPECIFIED";
   ctx.decision = PositionTypeText(direction);
   ctx.sessionName = SessionToString(snapshot.session);
   ctx.strategyName = "TREND";
   ctx.status = snapshot.spreadOk ? "ACTIVE" : "BLOCKED";
   ctx.price = snapshot.price;
   ctx.rsi = snapshot.rsi;
   ctx.ema50 = snapshot.fastEma;
   ctx.ema200 = snapshot.slowEma;
   ctx.atr = snapshot.atr;
   ctx.spread = snapshot.spread;

   int rawScore = 0;
   bool trendOk = false;
   bool rsiOk = false;
   bool pullbackOk = false;

   if(direction == POSITION_TYPE_BUY)
     {
      trendOk = snapshot.priceAboveSlow && snapshot.emaBullish;
      rsiOk = snapshot.rsiBuyOk;
      pullbackOk = snapshot.pullbackBuyOk;
     }
   else
     {
      trendOk = snapshot.priceBelowSlow && snapshot.emaBearish;
      rsiOk = snapshot.rsiSellOk;
      pullbackOk = snapshot.pullbackSellOk;
     }

   if(trendOk) rawScore += InpWeightTrend + InpWeightEmaAlignment;
   if(rsiOk) rawScore += InpWeightRsi;
   if(pullbackOk) rawScore += InpWeightPullback;

   int maxScore = InpWeightTrend + InpWeightEmaAlignment + InpWeightRsi + InpWeightPullback;
   ctx.score = maxScore > 0 ? (int)MathRound((double)rawScore * 100.0 / (double)maxScore) : 0;

   bool structureOk = trendOk && rsiOk && pullbackOk;
   bool scoreOk = (InpUseScoring == SCORE_DISABLED || ctx.score >= InpMinimumScore);
   ctx.valid = snapshot.spreadOk && structureOk && scoreOk;

   if(!snapshot.spreadOk) ctx.reason = "SPREAD_TOO_HIGH";
   else if(!structureOk) ctx.reason = "TREND_STRUCTURE_FAIL";
   else if(!scoreOk) ctx.reason = "SCORE_TOO_LOW";
   else ctx.reason = "SETUP_VALID";

   return ctx;
  }

DecisionContext SelectAndRunStrategy(const ENUM_POSITION_TYPE direction,const IndicatorSnapshot &snapshot,const bool isBarClose = false)
  {
   DecisionContext ctx;
   if(snapshot.session == SESSION_NONE)
     {
      ctx.type = direction;
      ctx.action = "SIGNAL_CHECK";
      ctx.phase = "UNSPECIFIED";
      ctx.decision = PositionTypeText(direction);
      ctx.sessionName = "NONE";
      ctx.strategyName = "NO_SESSION";
      ctx.status = "BLOCKED";
      ctx.price = snapshot.price;
      ctx.rsi = snapshot.rsi;
      ctx.ema50 = snapshot.fastEma;
      ctx.ema200 = snapshot.slowEma;
      ctx.atr = snapshot.atr;
      ctx.spread = snapshot.spread;
      ctx.score = 0;
      ctx.isCounterTrend = false;
      ctx.riskPercent = 0.0;
      ctx.valid = false;
      ctx.reason = "SESSION_BLOCKED";
      return ctx;
     }

   if(!snapshot.isHighVol)
      ctx = RunRangeStrategy(direction, snapshot, isBarClose);
   else if(snapshot.session == SESSION_LONDON)
      ctx = RunBreakoutStrategy(direction, snapshot, isBarClose);
   else if(snapshot.session == SESSION_NEWYORK)
      ctx = RunTrendStrategy(direction, snapshot, isBarClose);
   else
      ctx = RunTrendStrategy(direction, snapshot, isBarClose);

   bool isCT = false;
   if(direction == POSITION_TYPE_BUY && snapshot.closePrice < snapshot.slowEma) isCT = true;
   if(direction == POSITION_TYPE_SELL && snapshot.closePrice > snapshot.slowEma) isCT = true;
   
   ctx.isCounterTrend = isCT;
   ctx.riskPercent = isCT ? InpCounterTrendRisk : InpRiskPercent;
   
   if(isCT)
     {
      ctx.strategyName = ctx.strategyName + "(CT)";
      if(ctx.valid)
        {
         if(!InpAllowCounterTrend) { ctx.valid = false; ctx.reason = "CT_DISABLED"; }
         else if(InpUseScoring == SCORE_ENABLED && ctx.score < InpCounterTrendMinScore) { ctx.valid = false; ctx.reason = "CT_SCORE_TOO_LOW"; }
         else
           {
            bool rsiConfirm = (direction == POSITION_TYPE_BUY) ? (snapshot.rsi > snapshot.prevRsi) : (snapshot.rsi < snapshot.prevRsi);
            if(!rsiConfirm) { ctx.valid = false; ctx.reason = "CT_RSI_NO_REVERSAL"; }
           }
        }
     }

   if(isBarClose)
      DebugPrint(StringFormat("[%s] %s check: price=%.2f atr=%.2f score=%d reason=%s",
                              ctx.strategyName, PositionTypeText(direction), ctx.price, ctx.atr, ctx.score, ctx.reason));
                              
   return ctx;
  }

DecisionContext PickBestDecision(const DecisionContext &buyContext,const DecisionContext &sellContext,const IndicatorSnapshot &snapshot)
  {
   DecisionContext result;
   result.valid    = false;
   result.type     = POSITION_TYPE_BUY;
   result.action   = "TICK_EVAL";
   result.phase    = "LIVE_PREVIEW";
   result.decision = "SKIPPED";
   result.reason   = "NO_SETUP";
   result.status   = snapshot.spreadOk ? "ACTIVE" : "BLOCKED";
   result.sessionName = SessionToString(snapshot.session);
   result.strategyName = "EVAL_PENDING";
   result.price    = snapshot.price;
   result.rsi      = snapshot.rsi;
   result.ema50    = snapshot.fastEma;
   result.ema200   = snapshot.slowEma;
   result.atr      = snapshot.atr;
   result.spread   = snapshot.spread;
   result.score    = MathMax(buyContext.score,sellContext.score);
   result.isCounterTrend = false;
   result.riskPercent = 0.0;

   if(buyContext.valid && (!sellContext.valid || buyContext.score >= sellContext.score))
      return buyContext;

   if(sellContext.valid)
      return sellContext;

   if(!snapshot.spreadOk)
      result.reason = "SPREAD_TOO_HIGH";
   else if(buyContext.score >= sellContext.score)
     {
      result.strategyName = buyContext.strategyName;
      result.reason = buyContext.reason;
      result.isCounterTrend = buyContext.isCounterTrend;
      result.riskPercent = buyContext.riskPercent;
     }
   else
     {
      result.strategyName = sellContext.strategyName;
      result.reason = sellContext.reason;
      result.isCounterTrend = sellContext.isCounterTrend;
      result.riskPercent = sellContext.riskPercent;
     }

   return result;
  }

void SetDashboardLine(const string name,const string text,const color textColor,const int row)
  {
   string objectName = g_dashboardPrefix + name;
   if(ObjectFind(0,objectName) < 0)
     {
      ObjectCreate(0,objectName,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,objectName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,objectName,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,objectName,OBJPROP_YDISTANCE,20 + row * 18);
      ObjectSetInteger(0,objectName,OBJPROP_FONTSIZE,10);
      ObjectSetString(0,objectName,OBJPROP_FONT,"Consolas");
     }

   ObjectSetString(0,objectName,OBJPROP_TEXT,text);
   ObjectSetInteger(0,objectName,OBJPROP_COLOR,textColor);
  }

void UpdateDashboard(const DecisionContext &context)
  {
   if(!InpEnableDashboard)
      return;

   color statusColor   = (context.status == "ACTIVE") ? clrLimeGreen : clrTomato;
   color scoreColor    = (context.score >= InpMinimumScore) ? clrLimeGreen : clrTomato;
   color decisionColor = clrGold;
   if(context.decision == "BUY")
      decisionColor = clrLimeGreen;
   else if(context.decision == "SELL")
      decisionColor = clrTomato;

   SetDashboardLine("Title","Gold EA Dashboard",clrWhite,0);
   SetDashboardLine("Session",StringFormat("Session        : %s",context.sessionName),clrAqua,1);
   SetDashboardLine("Strategy",StringFormat("Strategy       : %s (Risk: %.1f%%)",context.strategyName,context.riskPercent),clrPlum,2);
   SetDashboardLine("ATR",StringFormat("ATR            : %.2f",context.atr),clrKhaki,3);
   SetDashboardLine("Score",StringFormat("Current Score  : %d",context.score),scoreColor,4);
   SetDashboardLine("Decision",StringFormat("Trade Decision : %s (%s)",context.decision,context.phase),decisionColor,5);
   SetDashboardLine("Reason",StringFormat("Reason         : %s",context.reason),clrYellow,6);
  }

void DrawTradeArrow(const ulong tradeId, const ENUM_POSITION_TYPE type, const bool isCounterTrend, const double price)
  {
   string objName = StringFormat("GoldEA_Arrow_%I64u", tradeId);
   datetime time = TimeTradeServer();

   if(ObjectFind(0, objName) >= 0) return;

   ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);

   color arrowColor = clrWhite;
   uchar arrowCode = 0;

   if(type == POSITION_TYPE_BUY)
     {
      arrowCode = 233; // Up arrow wingding
      arrowColor = isCounterTrend ? clrOrange : clrDodgerBlue;
     }
   else if(type == POSITION_TYPE_SELL)
     {
      arrowCode = 234; // Down arrow wingding
      arrowColor = isCounterTrend ? clrOrange : clrCrimson;
     }

   ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   ObjectSetString(0, objName, OBJPROP_TOOLTIP, isCounterTrend ? "Counter-Trend Setup" : "Trend Setup");
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
  }

bool ExecuteTrade(const DecisionContext &context)
  {
   if(!context.valid)
      return false;

   double entryPrice = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   double riskDistance = context.atr * InpStopAtrMultiplier;

   if(context.type == POSITION_TYPE_BUY)
     {
      entryPrice = SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK);
      sl = NormalizeDouble(entryPrice - riskDistance,g_symbolDigits);
      tp = NormalizeDouble(entryPrice + riskDistance * InpTakeProfitMultiplier,g_symbolDigits);
      riskDistance = entryPrice - sl;
     }
   else if(context.type == POSITION_TYPE_SELL)
     {
      entryPrice = SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
      sl = NormalizeDouble(entryPrice + riskDistance,g_symbolDigits);
      tp = NormalizeDouble(entryPrice - riskDistance * InpTakeProfitMultiplier,g_symbolDigits);
      riskDistance = sl - entryPrice;
     }

   double lot = CalculateLotSize(riskDistance, context.riskPercent);
   if(lot <= 0.0)
     {
      DebugPrint("Trade skipped because lot calculation returned 0");
      LogToCSV("TRADE_SKIPPED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,"LOT_SIZE_ZERO");
      return false;
     }

   ulong tradeId = NextTradeId();
   string commentText = StringFormat("GoldEA#%I64u %s",tradeId,context.decision);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);

   bool success = false;
   if(context.type == POSITION_TYPE_BUY)
      success = trade.Buy(lot,InpTradeSymbol,0.0,sl,tp,commentText);
   else if(context.type == POSITION_TYPE_SELL)
      success = trade.Sell(lot,InpTradeSymbol,0.0,sl,tp,commentText);

   if(!success)
     {
      string failReason = StringFormat("ORDER_FAILED_%d_%s",trade.ResultRetcode(),trade.ResultRetcodeDescription());
      DebugPrint(StringFormat("%s order failed: %s",context.decision,failReason));
      LogToCSV(context.decision + "_FAILED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,failReason);
      return false;
     }

   ulong ticket = FindPositionTicket(context.type);
   if(ticket > 0)
     {
      GlobalVariableSet(BuildStateKey("initrisk",ticket),riskDistance);
      GlobalVariableSet(BuildStateKey("partial",ticket),0.0);
      GlobalVariableSet(BuildStateKey("breakeven",ticket),0.0);
      GlobalVariableSet(BuildStateKey("tradeid",ticket),(double)tradeId);
     }

   if(context.type == POSITION_TYPE_BUY)
      g_lastBuyBar = g_lastBarTime;
   else if(context.type == POSITION_TYPE_SELL)
      g_lastSellBar = g_lastBarTime;
      
   DrawTradeArrow(tradeId, context.type, context.isCounterTrend, entryPrice);

   DebugPrint(StringFormat("%s executed: tradeId=%I64u lot=%.2f entry=%.2f sl=%.2f tp=%.2f",context.decision,tradeId,lot,entryPrice,sl,tp));
   LogToCSV(context.decision + "_EXECUTED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,StringFormat("TRADE_ID_%I64u",tradeId));

   if(InpEnablePushAlerts || InpEnableEmailAlerts)
     {
      string alertSubject = StringFormat("GoldEA %s %s Executed", context.strategyName, context.decision);
      string alertMsg = StringFormat("Action: %s %s\nType: %s\nRisk: %.2f%%\nLot: %.2f\nEntry: %.2f\nSL: %.2f\nTP: %.2f\nScore: %d",
                                     context.decision, InpTradeSymbol, context.strategyName, context.riskPercent, lot, entryPrice, sl, tp, context.score);
      if(InpEnablePushAlerts) SendNotification(alertSubject + "\n" + alertMsg);
      if(InpEnableEmailAlerts) SendMail(alertSubject, alertMsg);
     }

   return true;
  }

void ManageTrade(const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return;

   if(PositionGetString(POSITION_SYMBOL) != InpTradeSymbol)
      return;

   if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return;

   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice        = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSl        = PositionGetDouble(POSITION_SL);
   double currentTp        = PositionGetDouble(POSITION_TP);
   double volume           = PositionGetDouble(POSITION_VOLUME);

   IndicatorSnapshot snapshot;
   if(!CalculateIndicators(snapshot,0))
      return;

   double initialRisk = 0.0;
   string riskKey = BuildStateKey("initrisk",ticket);
   if(GlobalVariableCheck(riskKey))
      initialRisk = GlobalVariableGet(riskKey);

   if(initialRisk <= 0.0)
      initialRisk = MathAbs(openPrice - currentSl);

   if(initialRisk <= 0.0)
      return;

   double priceNow = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID)
                                                 : SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK);
   double profitDistance = (type == POSITION_TYPE_BUY) ? (priceNow - openPrice)
                                                       : (openPrice - priceNow);
   double rMultiple = profitDistance / initialRisk;

   string beKey = BuildStateKey("breakeven",ticket);
   if(rMultiple >= 1.0 && (!GlobalVariableCheck(beKey) || GlobalVariableGet(beKey) < 1.0))
     {
      bool needsBeModify = false;
      if(type == POSITION_TYPE_BUY && (currentSl < openPrice || currentSl == 0.0)) needsBeModify = true;
      if(type == POSITION_TYPE_SELL && (currentSl > openPrice || currentSl == 0.0)) needsBeModify = true;

      if(needsBeModify)
        {
         double newSl = NormalizeDouble(openPrice,g_symbolDigits);
         if(trade.PositionModify(ticket,newSl,currentTp))
           {
            GlobalVariableSet(beKey,1.0);
            DebugPrint(StringFormat("Breakeven moved for ticket=%I64u",ticket));
            LogToCSV("BREAKEVEN",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),"BREAKEVEN_TRIGGERED");
           }
        }
      else
        {
         GlobalVariableSet(beKey,1.0);
        }
     }

   string partialKey = BuildStateKey("partial",ticket);
   if(rMultiple >= 1.5 && (!GlobalVariableCheck(partialKey) || GlobalVariableGet(partialKey) < 1.0))
     {
      double halfVolume = NormalizeVolume(volume * 0.5);
      double minLot     = SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN);
      if(halfVolume >= minLot && halfVolume < volume)
        {
         if(trade.PositionClosePartial(ticket,halfVolume))
           {
            GlobalVariableSet(partialKey,1.0);
            DebugPrint(StringFormat("Partial close completed for ticket=%I64u",ticket));
            LogToCSV("PARTIAL_CLOSE",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),"PARTIAL_50_AT_1_5R");
           }
        }
      else
         GlobalVariableSet(partialKey,1.0);
     }

   double trailedSl = currentSl;
   if(type == POSITION_TYPE_BUY)
     {
      double candidate = NormalizeDouble(priceNow - snapshot.atr * InpTrailAtrMultiplier,g_symbolDigits);
      if(candidate > trailedSl && candidate > openPrice)
         trailedSl = candidate;
     }
   else if(type == POSITION_TYPE_SELL)
     {
      double candidate = NormalizeDouble(priceNow + snapshot.atr * InpTrailAtrMultiplier,g_symbolDigits);
      if((trailedSl == 0.0 || candidate < trailedSl) && candidate < openPrice)
         trailedSl = candidate;
     }

   double trailStep = 10.0 * SymbolInfoDouble(InpTradeSymbol,SYMBOL_POINT);
   bool validTrailStep = false;
   if(type == POSITION_TYPE_BUY && trailedSl >= currentSl + trailStep) validTrailStep = true;
   if(type == POSITION_TYPE_SELL && (trailedSl <= currentSl - trailStep || currentSl == 0.0)) validTrailStep = true;

   if(validTrailStep && trailedSl > 0.0)
     {
      if(trade.PositionModify(ticket,trailedSl,currentTp))
        {
         DebugPrint(StringFormat("Trailing stop updated for ticket=%I64u",ticket));
         LogToCSV("TRAILING_STOP",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),"TRAILING_STOP_UPDATED");
        }
     }
  }

void CleanupStateGlobals()
  {
   int total = GlobalVariablesTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      string gName = GlobalVariableName(i);
      string prefix = StringFormat("EA_%I64u_", InpMagicNumber);
      if(StringFind(gName, prefix) == 0)
        {
         if(StringFind(gName, "TradeCounter") > 0)
            continue;
         string parts[];
         if(StringSplit(gName, ushort('_'), parts) >= 4)
           {
            ulong ticket = StringToInteger(parts[3]);
            if(ticket > 0 && !PositionSelectByTicket(ticket))
               GlobalVariableDel(gName);
           }
        }
     }
  }

void ManageOpenTrades()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      ManageTrade(ticket);
     }
  }

void EvaluateEntries()
  {
   IndicatorSnapshot entrySnapshot;
   if(!CalculateIndicators(entrySnapshot,1))
      return;

   DecisionContext buyContext = SelectAndRunStrategy(POSITION_TYPE_BUY,entrySnapshot,true);
   DecisionContext sellContext = SelectAndRunStrategy(POSITION_TYPE_SELL,entrySnapshot,true);
   buyContext.phase  = "BAR_CLOSE_SIGNAL";
   sellContext.phase = "BAR_CLOSE_SIGNAL";

   if(!InpAllowBuyTrades)
     {
      buyContext.valid = false;
      buyContext.reason = "BUY_DISABLED";
     }
   if(!InpAllowSellTrades)
     {
      sellContext.valid = false;
      sellContext.reason = "SELL_DISABLED";
     }
   if(PositionExists(POSITION_TYPE_BUY))
     {
      buyContext.valid = false;
      buyContext.reason = "BUY_POSITION_EXISTS";
     }
   if(PositionExists(POSITION_TYPE_SELL))
     {
      sellContext.valid = false;
      sellContext.reason = "SELL_POSITION_EXISTS";
     }
   if(g_lastBuyBar == g_lastBarTime)
     {
      buyContext.valid = false;
      buyContext.reason = "BUY_DUPLICATE_BLOCKED";
     }
   if(g_lastSellBar == g_lastBarTime)
     {
      sellContext.valid = false;
      sellContext.reason = "SELL_DUPLICATE_BLOCKED";
     }

   if(buyContext.valid && (!sellContext.valid || buyContext.score >= sellContext.score))
     {
      LogToCSV("BAR_CLOSE_SIGNAL",buyContext.sessionName,buyContext.strategyName,buyContext.price,buyContext.rsi,buyContext.ema50,buyContext.ema200,buyContext.atr,buyContext.spread,buyContext.score,buyContext.decision,buyContext.reason);
      ExecuteTrade(buyContext);
     }
   else if(sellContext.valid)
     {
      LogToCSV("BAR_CLOSE_SIGNAL",sellContext.sessionName,sellContext.strategyName,sellContext.price,sellContext.rsi,sellContext.ema50,sellContext.ema200,sellContext.atr,sellContext.spread,sellContext.score,sellContext.decision,sellContext.reason);
      ExecuteTrade(sellContext);
     }
  }

void EvaluateTickAndDashboard()
  {
   IndicatorSnapshot liveSnapshot;
   if(!CalculateIndicators(liveSnapshot,0))
      return;

   DecisionContext buyContext = SelectAndRunStrategy(POSITION_TYPE_BUY,liveSnapshot,false);
   DecisionContext sellContext = SelectAndRunStrategy(POSITION_TYPE_SELL,liveSnapshot,false);
   buyContext.phase  = "LIVE_PREVIEW";
   sellContext.phase = "LIVE_PREVIEW";

   if(!InpAllowBuyTrades)
     {
      buyContext.valid = false;
      buyContext.reason = "BUY_DISABLED";
     }
   if(!InpAllowSellTrades)
     {
      sellContext.valid = false;
      sellContext.reason = "SELL_DISABLED";
     }
   if(PositionExists(POSITION_TYPE_BUY))
     {
      buyContext.valid = false;
      buyContext.reason = "BUY_POSITION_EXISTS";
     }
   if(PositionExists(POSITION_TYPE_SELL))
     {
      sellContext.valid = false;
      sellContext.reason = "SELL_POSITION_EXISTS";
     }

   DecisionContext current = PickBestDecision(buyContext,sellContext,liveSnapshot);
   UpdateDashboard(current);

   if(InpLogEveryTick)
      LogToCSV("LIVE_TICK_PREVIEW",current.sessionName,current.strategyName,current.price,current.rsi,current.ema50,current.ema200,current.atr,current.spread,current.score,current.decision,current.reason);
  }

int OnInit()
  {
   g_symbolDigits = (int)SymbolInfoInteger(InpTradeSymbol,SYMBOL_DIGITS);

   g_fastEmaHandle = iMA(InpTradeSymbol,InpTimeframe,InpFastEmaPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_slowEmaHandle = iMA(InpTradeSymbol,InpTimeframe,InpSlowEmaPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_rsiHandle     = iRSI(InpTradeSymbol,InpTimeframe,InpRsiPeriod,PRICE_CLOSE);
   g_bbHandle      = iBands(InpTradeSymbol,InpTimeframe,InpBandsPeriod,0,InpBandsDeviation,PRICE_CLOSE);
   g_atrHandle     = iATR(InpTradeSymbol,InpTimeframe,InpAtrPeriod);

   if(g_fastEmaHandle == INVALID_HANDLE ||
      g_slowEmaHandle == INVALID_HANDLE ||
      g_rsiHandle == INVALID_HANDLE ||
      g_bbHandle == INVALID_HANDLE ||
      g_atrHandle == INVALID_HANDLE)
     {
      DebugPrint("Indicator handle creation failed");
      return INIT_FAILED;
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(InpTradeSymbol);

   CleanupOldLogs();

   DebugPrint(StringFormat("EA initialized on %s timeframe=%d",InpTradeSymbol,InpTimeframe));
   LogToCSV("INIT","NONE","NONE",0.0,0.0,0.0,0.0,0.0,0,0,"ACTIVE","EA_INITIALIZED");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_fastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(g_fastEmaHandle);
   if(g_slowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(g_slowEmaHandle);
   if(g_rsiHandle != INVALID_HANDLE)
      IndicatorRelease(g_rsiHandle);
   if(g_bbHandle != INVALID_HANDLE)
      IndicatorRelease(g_bbHandle);
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
      
   ObjectsDeleteAll(0, "GoldEA_Arrow_");

   if(InpEnableDashboard)
     {
      string labels[7] = {"Title","Session","Strategy","ATR","Score","Decision","Reason"};
      for(int i = 0; i < 7; ++i)
         ObjectDelete(0,g_dashboardPrefix + labels[i]);
     }

   LogToCSV("DEINIT","NONE","NONE",0.0,0.0,0.0,0.0,0.0,0,0,"STOPPED",StringFormat("REASON_%d",reason));
  }

void OnTick()
  {
   UpdateAsianRange();
   EvaluateTickAndDashboard();
   ManageOpenTrades();

   if(!IsNewBar())
      return;

   CleanupStateGlobals();
   EvaluateEntries();
  }
