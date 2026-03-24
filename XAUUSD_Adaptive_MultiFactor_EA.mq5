#property strict
#property version   "4.00"
#property description "M5 Adaptive Multi-Factor EA v4 for XAUUSDm on MT5 with CSV logging and dashboard"

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
input double           InpMaxAbsoluteRiskPercent = 10.0;       // Max Allowed Risk % (Absolute Cap)
input bool             InpAllowCounterTrend      = true;       // Allow Counter-Trend
input double           InpCounterTrendRisk       = 0.50;       // Counter-Trend Risk %
input int              InpCounterTrendMinScore   = 85;         // Counter-Trend Min Score
input double           InpCounterTrendTpMultiplier = 1.2;      // Counter-Trend TP Multiplier
input int              InpMaxOpenPositionsTotal  = 1;          // Max Global Open Positions
input int              InpMaxConcurrentTrades    = 2;          // Max Concurrent Trades per Direction
input int              InpTradeCooldownSeconds   = 300;        // Trade Cooldown (Seconds)
input double           InpStopAtrMultiplier      = 1.8;
input double           InpTakeProfitMultiplier   = 3.0;
input double           InpBreakevenAtrMultiplier = 1.2;
input double           InpMinProfitLockAtr       = 0.30;
input double           InpAccountProfitLockTriggerPercent = 5.0;  // Account Profit Lock Trigger %
input double           InpAccountProfitLockTargetPercent = 1.0;   // Account Profit Lock Target %
input double           InpTrailActivationAtrMultiplier = 2.0;
input double           InpTrailAtrMultiplier     = 2.5;
input double           InpTrailStepAtrMultiplier = 0.50;
input double           InpProfitLockActivationAtr = 2.5;
input double           InpProfitLockAtr          = 1.0;
input double           InpMinAtrPoints           = 120.0;
input double           InpPullbackAtrFactor      = 0.50;

input int              InpAdxPeriod              = 14;
input double           InpAdxThreshold           = 20.0;
input double           InpEmaGapAtrFactor        = 0.5;

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
input int              InpMinimumScore           = 75;
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
int      g_adxHandle        = INVALID_HANDLE;
int      g_symbolDigits     = 2;
datetime g_lastBarTime      = 0;
datetime g_lastBuyBar       = 0;
datetime g_lastSellBar      = 0;
datetime g_lastTradeTime    = 0;
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
   double adx;
   double prevAdx;
   bool   adxIncreasing;
   bool   emaGapOk;
   bool   trendPersistentBuy;
   bool   trendPersistentSell;
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

bool RebuildAsianRangeFromHistory()
  {
   datetime now = TimeTradeServer();
   MqlDateTime serverTime;
   TimeToStruct(now,serverTime);

   serverTime.hour = 0;
   serverTime.min = 0;
   serverTime.sec = 0;
   datetime dayStart = StructToTime(serverTime);
   datetime asianStart = dayStart + (InpAsianStartHour * 3600);
   datetime asianEnd   = dayStart + (InpAsianEndHour * 3600);

   datetime rangeEnd = now;
   if(now >= asianEnd)
      rangeEnd = asianEnd;
   else if(now <= asianStart)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int copied = CopyRates(InpTradeSymbol,InpTimeframe,asianStart,rangeEnd,rates);
   if(copied <= 0)
      return false;

   double high = 0.0;
   double low  = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].high > high)
         high = rates[i].high;

      if((low == 0.0 || rates[i].low < low) && rates[i].low > 0.0)
         low = rates[i].low;
     }

   if(high <= 0.0 || low <= 0.0)
      return false;

   g_asianHigh = high;
   g_asianLow = low;
   g_lastAsianDay = serverTime.day_of_year;
   DebugPrint(StringFormat("Asian range rebuilt from history: high=%.2f low=%.2f bars=%d",g_asianHigh,g_asianLow,copied));
   return true;
  }

int CountPositions(const ENUM_POSITION_TYPE positionType)
  {
   int count = 0;
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
         count++;
     }
   return count;
  }

bool HasOpenPosition()
  {
   return (CountPositions(POSITION_TYPE_BUY) + CountPositions(POSITION_TYPE_SELL)) >= InpMaxOpenPositionsTotal;
  }

bool HasBuyPosition()
  {
   return CountPositions(POSITION_TYPE_BUY) >= InpMaxConcurrentTrades;
  }

bool HasSellPosition()
  {
   return CountPositions(POSITION_TYPE_SELL) >= InpMaxConcurrentTrades;
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

ulong FindPositionTicketByComment(const string commentText)
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

      if(PositionGetString(POSITION_COMMENT) == commentText)
         return ticket;
     }

   return 0;
  }

double CalculateLotSize(const double stopDistance, const double riskPercent)
  {
   if(stopDistance <= 0.0)
     {
      DebugPrint("Error: Invalid Stop Loss distance. Distance is 0.");
      return 0.0;
     }

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPercent / 100.0);
   double tickSize   = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
     {
      DebugPrint(StringFormat("Error: Invalid parameters. TickValue: %f, TickSize: %f", tickValue, tickSize));
      return 0.0;
     }

   double moneyPerLot = (stopDistance / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
     {
      DebugPrint("Error: Calculated loss per lot is zero or negative.");
      return 0.0;
     }

   double rawLot = riskAmount / moneyPerLot;
   double finalLot = NormalizeVolume(rawLot);
   
   double expectedLoss = finalLot * moneyPerLot;
   double actualRiskPercent = (expectedLoss / balance) * 100.0;
   
   DebugPrint(StringFormat("Lot Calc: Balance=%.2f, TargetRisk=%.2f, StopDist=%.1f, LossPerLot=%.2f, RawLot=%.5f, FinalLot=%.2f, ActualRisk=%.2f%%",
                           balance, riskAmount, stopDistance, moneyPerLot, rawLot, finalLot, actualRiskPercent));
                           
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
   if(!GetRates(rates,shift + 5))
      return false;

   double fEma1, fEma2, sEma1, sEma2;
   if(!GetIndicatorValue(g_fastEmaHandle,shift,snapshot.fastEma) ||
      !GetIndicatorValue(g_fastEmaHandle,shift+1,fEma1) ||
      !GetIndicatorValue(g_fastEmaHandle,shift+2,fEma2) ||
      !GetIndicatorValue(g_slowEmaHandle,shift,snapshot.slowEma) ||
      !GetIndicatorValue(g_slowEmaHandle,shift+1,sEma1) ||
      !GetIndicatorValue(g_slowEmaHandle,shift+2,sEma2) ||
      !GetIndicatorValue(g_rsiHandle,shift,snapshot.rsi) ||
      !GetIndicatorValue(g_rsiHandle,shift+1,snapshot.prevRsi) ||
      !GetIndicatorValue(g_bbHandle,shift,snapshot.bbBase,0) ||
      !GetIndicatorValue(g_bbHandle,shift,snapshot.bbUpper,1) ||
      !GetIndicatorValue(g_bbHandle,shift,snapshot.bbLower,2) ||
      !GetIndicatorValue(g_atrHandle,shift,snapshot.atr) ||
      !GetIndicatorValue(g_adxHandle,shift,snapshot.adx,0) ||
      !GetIndicatorValue(g_adxHandle,shift+1,snapshot.prevAdx,0))
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
   
   snapshot.emaGapOk = (MathAbs(snapshot.fastEma - snapshot.slowEma) >= snapshot.atr * InpEmaGapAtrFactor);
   snapshot.adxIncreasing = (snapshot.adx > snapshot.prevAdx);
   
   snapshot.trendPersistentBuy = (snapshot.closePrice > snapshot.slowEma && snapshot.fastEma > snapshot.slowEma) &&
                                 (rates[shift+1].close > sEma1 && fEma1 > sEma1) &&
                                 (rates[shift+2].close > sEma2 && fEma2 > sEma2);
   snapshot.trendPersistentSell = (snapshot.closePrice < snapshot.slowEma && snapshot.fastEma < snapshot.slowEma) &&
                                  (rates[shift+1].close < sEma1 && fEma1 < sEma1) &&
                                  (rates[shift+2].close < sEma2 && fEma2 < sEma2);
                                  
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
   bool trendOk = false;
   bool rsiOk = false;
   bool pullbackOk = false;

   if(direction == POSITION_TYPE_BUY)
     {
      breakOk = (g_asianHigh > 0 && snapshot.closePrice > g_asianHigh);
      trendOk = snapshot.priceAboveSlow && snapshot.emaBullish;
      rsiOk = snapshot.rsiBuyOk;
      pullbackOk = snapshot.pullbackBuyOk;
     }
   else
     {
      breakOk = (g_asianLow > 0 && snapshot.closePrice < g_asianLow);
      trendOk = snapshot.priceBelowSlow && snapshot.emaBearish;
      rsiOk = snapshot.rsiSellOk;
      pullbackOk = snapshot.pullbackSellOk;
     }

   if(trendOk) rawScore += InpWeightTrend + InpWeightEmaAlignment;
   if(rsiOk) rawScore += InpWeightRsi;
   if(pullbackOk) rawScore += InpWeightPullback;
   if(breakOk) rawScore += InpWeightBreakout;

   int maxScore = InpWeightTrend + InpWeightEmaAlignment + InpWeightRsi + InpWeightPullback + InpWeightBreakout;
   ctx.score = maxScore > 0 ? (int)MathRound((double)rawScore * 100.0 / (double)maxScore) : 0;

   if((snapshot.session == SESSION_LONDON || snapshot.session == SESSION_NEWYORK) && snapshot.adx > 25.0)
      ctx.score += 15;
      
   if(!breakOk)
      ctx.score -= 20;
      
   if(ctx.score > 100) ctx.score = 100;
   if(ctx.score < 0) ctx.score = 0;

   bool adxOk = (snapshot.adx > InpAdxThreshold);
   bool emaGapOk = snapshot.emaGapOk;
   bool persistenceOk = (direction == POSITION_TYPE_BUY) ? snapshot.trendPersistentBuy : snapshot.trendPersistentSell;

   bool structureOk = trendOk && rsiOk && pullbackOk;
   bool scoreOk = (InpUseScoring == SCORE_DISABLED || ctx.score >= InpMinimumScore);
   bool strongTrendOverride = (ctx.score >= 90);
   bool trendOverride = (!breakOk && trendOk && adxOk && ctx.score >= 80);
   
   ctx.valid = snapshot.spreadOk && adxOk && (emaGapOk || strongTrendOverride) && (persistenceOk || strongTrendOverride) && (structureOk || strongTrendOverride) && scoreOk && (breakOk || trendOverride);

   if(!snapshot.spreadOk) ctx.reason = "SPREAD_TOO_HIGH";
   else if(!adxOk) ctx.reason = "WEAK_TREND";
   else if(!emaGapOk && !strongTrendOverride) ctx.reason = "SIDEWAYS_MARKET";
   else if(!persistenceOk && !strongTrendOverride) ctx.reason = "UNSTABLE_TREND";
   else if(!structureOk && !strongTrendOverride) ctx.reason = "TREND_STRUCTURE_FAIL";
   else if(!breakOk && !trendOverride) ctx.reason = "WEAK_BREAKOUT";
   else if(!scoreOk) ctx.reason = "SCORE_TOO_LOW";
   else ctx.reason = strongTrendOverride ? "SETUP_VALID_OVERRIDE" : "SETUP_VALID";

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

   if((snapshot.session == SESSION_LONDON || snapshot.session == SESSION_NEWYORK) && snapshot.adx > 25.0)
      ctx.score += 15;
      
   if(ctx.score > 100) ctx.score = 100;
   if(ctx.score < 0) ctx.score = 0;

   bool adxOk = (snapshot.adx > InpAdxThreshold);
   bool emaGapOk = snapshot.emaGapOk;
   bool persistenceOk = (direction == POSITION_TYPE_BUY) ? snapshot.trendPersistentBuy : snapshot.trendPersistentSell;

   bool structureOk = trendOk && rsiOk && pullbackOk;
   bool scoreOk = (InpUseScoring == SCORE_DISABLED || ctx.score >= InpMinimumScore);
   bool strongTrendOverride = (ctx.score >= 90);
   
   ctx.valid = snapshot.spreadOk && adxOk && (emaGapOk || strongTrendOverride) && (persistenceOk || strongTrendOverride) && (structureOk || strongTrendOverride) && scoreOk;

   if(!snapshot.spreadOk) ctx.reason = "SPREAD_TOO_HIGH";
   else if(!adxOk) ctx.reason = "WEAK_TREND";
   else if(!emaGapOk && !strongTrendOverride) ctx.reason = "SIDEWAYS_MARKET";
   else if(!persistenceOk && !strongTrendOverride) ctx.reason = "UNSTABLE_TREND";
   else if(!structureOk && !strongTrendOverride) ctx.reason = "TREND_STRUCTURE_FAIL";
   else if(!scoreOk) ctx.reason = "SCORE_TOO_LOW";
   else ctx.reason = strongTrendOverride ? "SETUP_VALID_OVERRIDE" : "SETUP_VALID";

   return ctx;
  }

DecisionContext SelectAndRunStrategy(const ENUM_POSITION_TYPE direction,const IndicatorSnapshot &snapshot,const bool isBarClose = false)
  {
   DecisionContext ctx;
   bool sessionOk = (snapshot.session == SESSION_ASIAN || snapshot.session == SESSION_LONDON || snapshot.session == SESSION_NEWYORK);
   
   if(!sessionOk)
     {
      ctx.type = direction;
      ctx.action = "SIGNAL_CHECK";
      ctx.phase = "UNSPECIFIED";
      ctx.decision = PositionTypeText(direction);
      ctx.sessionName = SessionToString(snapshot.session);
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
      
      if(isBarClose)
         DebugPrint(StringFormat("[%s] %s check: price=%.2f atr=%.2f score=%d reason=%s",
                                 ctx.strategyName, PositionTypeText(direction), ctx.price, ctx.atr, ctx.score, ctx.reason));
      return ctx;
     }

   if(snapshot.session == SESSION_ASIAN)
      ctx = RunRangeStrategy(direction, snapshot, isBarClose);
   else if(!snapshot.isHighVol)
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
   bool sessionOk  = (snapshot.session == SESSION_ASIAN || snapshot.session == SESSION_LONDON || snapshot.session == SESSION_NEWYORK);
   
   result.valid    = false;
   result.type     = POSITION_TYPE_BUY;
   result.action   = "TICK_EVAL";
   result.phase    = "LIVE_PREVIEW";
   result.decision = "SKIPPED";
   result.reason   = "NO_SETUP";
   result.status   = (snapshot.spreadOk && sessionOk) ? "ACTIVE" : "BLOCKED";
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

   if(!sessionOk)
      result.reason = "SESSION_BLOCKED";
   else if(!snapshot.spreadOk)
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
   SetDashboardLine("Session",StringFormat("Session        : %s [%s]",context.sessionName,context.status),statusColor,1);
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

   if(HasOpenPosition())
     {
      int totalCount = CountPositions(POSITION_TYPE_BUY) + CountPositions(POSITION_TYPE_SELL);
      DebugPrint(StringFormat("Trade blocked: existing position already open. Current count: %d", totalCount));
      LogToCSV("TRADE_BLOCKED",context.sessionName,context.strategyName,context.price,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,"MAX_GLOBAL_POSITIONS");
      return false;
     }

   double entryPrice = (context.type == POSITION_TYPE_BUY) ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK) : SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
   double originalSlDistance = context.atr * InpStopAtrMultiplier;
   double riskDistance = originalSlDistance;

   double lot = CalculateLotSize(riskDistance, context.riskPercent);
   if(lot <= 0.0)
     {
      DebugPrint("Trade skipped because lot calculation returned 0 (Invalid parameters).");
      LogToCSV("TRADE_SKIPPED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,"LOT_SIZE_ZERO");
      return false;
     }
     
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxRiskUSD = balance * (InpMaxAbsoluteRiskPercent / 100.0);
   double tickSize   = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_VALUE);
   
   double moneyPerLot = (riskDistance / tickSize) * tickValue;
   double expectedLoss = lot * moneyPerLot;
   
   if(expectedLoss > maxRiskUSD && tickValue > 0.0 && lot > 0.0)
     {
      double maxSLTicks = maxRiskUSD / (tickValue * lot);
      double adjustedSLDistance = maxSLTicks * tickSize;
      
      DebugPrint(StringFormat("SL adjusted to fit %g%% risk. Expected $%.2f > Max $%.2f. Shrinking SL %.2f -> %.2f points.", 
                              InpMaxAbsoluteRiskPercent, expectedLoss, maxRiskUSD, riskDistance / _Point, adjustedSLDistance / _Point));
      LogToCSV("SL_ADJUSTED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,StringFormat("OrigSL_%.2f_NewSL_%.2f", riskDistance, adjustedSLDistance));
      
      riskDistance = adjustedSLDistance;
      expectedLoss = maxRiskUSD;
     }
     
   double actualRiskPercent = (expectedLoss / balance) * 100.0;
   double tpDistance = riskDistance * 3.0; // Enforce strict 1:3 RR
   
   double sl = 0.0;
   double tp = 0.0;
   
   if(context.type == POSITION_TYPE_BUY)
     {
      sl = NormalizeDouble(entryPrice - riskDistance,g_symbolDigits);
      tp = NormalizeDouble(entryPrice + tpDistance,g_symbolDigits);
     }
   else if(context.type == POSITION_TYPE_SELL)
     {
      sl = NormalizeDouble(entryPrice + riskDistance,g_symbolDigits);
      tp = NormalizeDouble(entryPrice - tpDistance,g_symbolDigits);
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

   ulong ticket = 0;
   ulong resultDeal = trade.ResultDeal();
   if(resultDeal > 0 && HistoryDealSelect(resultDeal))
      ticket = (ulong)HistoryDealGetInteger(resultDeal,DEAL_POSITION_ID);

   if(ticket == 0)
      ticket = FindPositionTicketByComment(commentText);

   if(ticket == 0)
      ticket = FindPositionTicket(context.type);

   if(ticket > 0)
     {
      GlobalVariableSet(BuildStateKey("initrisk",ticket),riskDistance);
      GlobalVariableSet(BuildStateKey("partial",ticket),0.0);
      GlobalVariableSet(BuildStateKey("minprofit",ticket),0.0);
      GlobalVariableSet(BuildStateKey("acclock",ticket),0.0);
      GlobalVariableSet(BuildStateKey("tradeid",ticket),(double)tradeId);
     }

   if(context.type == POSITION_TYPE_BUY)
      g_lastBuyBar = g_lastBarTime;
   else if(context.type == POSITION_TYPE_SELL)
      g_lastSellBar = g_lastBarTime;
   g_lastTradeTime = TimeTradeServer();
      
   DrawTradeArrow(tradeId, context.type, context.isCounterTrend, entryPrice);

   DebugPrint(StringFormat("%s executed: tradeId=%I64u lot=%.2f entry=%.2f sl=%.2f tp=%.2f",context.decision,tradeId,lot,entryPrice,sl,tp));
   LogToCSV(context.decision + "_EXECUTED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,StringFormat("TRADE_ID_%I64u",tradeId));

   if(InpEnablePushAlerts || InpEnableEmailAlerts)
     {
      string alertSubject = StringFormat("GoldEA %s %s Executed", context.strategyName, context.decision);
      string alertMsg = StringFormat("Action: %s %s\nType: %s\nActual Risk: %.2f%%\nLot: %.2f\nEntry: %.2f\nSL: %.2f\nTP Dist: %.2f points\nScore: %d",
                                     context.decision, InpTradeSymbol, context.strategyName, actualRiskPercent, lot, entryPrice, sl, tpDistance / _Point, context.score);
      if(InpEnablePushAlerts) SendNotification(alertSubject + "\n" + alertMsg);
      if(InpEnableEmailAlerts) SendMail(alertSubject, alertMsg);
     }

   return true;
  }

void ManageTrade(const ulong ticket, const bool isNewBar)
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
   double profitMoney      = PositionGetDouble(POSITION_PROFIT);
   double balance          = AccountInfoDouble(ACCOUNT_BALANCE);

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

   string accLockKey = BuildStateKey("acclock",ticket);
   bool isAccLockActive = (GlobalVariableCheck(accLockKey) && GlobalVariableGet(accLockKey) >= 1.0);
   
   if(!isAccLockActive && InpAccountProfitLockTriggerPercent > 0.0)
     {
      double triggerMoney = balance * (InpAccountProfitLockTriggerPercent / 100.0);
      if(profitMoney >= triggerMoney)
        {
         double targetMoney = balance * (InpAccountProfitLockTargetPercent / 100.0);
         double tickSize   = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_SIZE);
         double tickValue  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_VALUE);
         
         if(tickSize > 0.0 && tickValue > 0.0 && volume > 0.0)
           {
            double priceDiff = (targetMoney * tickSize) / (tickValue * volume);
            double newSl = 0.0;
            bool needsBeModify = false;
            
            if(type == POSITION_TYPE_BUY)
              {
               newSl = NormalizeDouble(openPrice + priceDiff, g_symbolDigits);
               if(currentSl < newSl || currentSl == 0.0) needsBeModify = true;
              }
            else if(type == POSITION_TYPE_SELL)
              {
               newSl = NormalizeDouble(openPrice - priceDiff, g_symbolDigits);
               if(currentSl > newSl || currentSl == 0.0) needsBeModify = true;
              }

            if(needsBeModify)
              {
               if(trade.PositionModify(ticket,newSl,currentTp))
                 {
                  GlobalVariableSet(accLockKey,1.0);
                  DebugPrint(StringFormat("Account profit lock moved for ticket=%I64u",ticket));
                  string reasonStr = StringFormat("PROFIT_$%.2f_SL_%.2f", profitMoney, newSl);
                  LogToCSV("ACCOUNT_PROFIT_LOCK",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),reasonStr);
                 }
              }
            else
              {
               GlobalVariableSet(accLockKey,1.0);
              }
           }
        }
     }

   string trailStartKey = BuildStateKey("trailstart",ticket);
   bool isTrailActive = (GlobalVariableCheck(trailStartKey) && GlobalVariableGet(trailStartKey) >= 1.0);

   string lockKey = BuildStateKey("minprofit",ticket);
   if(!isTrailActive && profitDistance >= (snapshot.atr * InpBreakevenAtrMultiplier) && (!GlobalVariableCheck(lockKey) || GlobalVariableGet(lockKey) < 1.0))
     {
      bool needsBeModify = false;
      double newSl = 0.0;
      
      if(type == POSITION_TYPE_BUY)
        {
         newSl = NormalizeDouble(openPrice + snapshot.atr * InpMinProfitLockAtr, g_symbolDigits);
         if(currentSl < newSl || currentSl == 0.0) needsBeModify = true;
        }
      else if(type == POSITION_TYPE_SELL)
        {
         newSl = NormalizeDouble(openPrice - snapshot.atr * InpMinProfitLockAtr, g_symbolDigits);
         if(currentSl > newSl || currentSl == 0.0) needsBeModify = true;
        }

      if(needsBeModify)
        {
         if(trade.PositionModify(ticket,newSl,currentTp))
           {
            GlobalVariableSet(lockKey,1.0);
            DebugPrint(StringFormat("Minimal profit lock moved for ticket=%I64u",ticket));
            string reasonStr = StringFormat("PROFIT_%.2f_SL_%.2f", profitDistance, newSl);
            LogToCSV("MIN_PROFIT_LOCK_TRIGGERED",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),reasonStr);
           }
        }
      else
        {
         GlobalVariableSet(lockKey,1.0);
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

   if(!isTrailActive && (profitDistance >= snapshot.atr * InpTrailActivationAtrMultiplier || (GlobalVariableCheck(accLockKey) && GlobalVariableGet(accLockKey) >= 1.0)))
     {
      isTrailActive = true;
      GlobalVariableSet(trailStartKey,1.0);
      LogToCSV("TRAILING_STARTED",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),"PROFIT_REACHED_ACTIVATION");
     }

   if(isTrailActive && isNewBar)
     {
      double trailedSl = currentSl;
      double trailStep = snapshot.atr * InpTrailStepAtrMultiplier;
      bool validTrailStep = false;

      if(type == POSITION_TYPE_BUY)
        {
         double candidate = NormalizeDouble(priceNow - snapshot.atr * InpTrailAtrMultiplier,g_symbolDigits);
         
         if(profitDistance >= snapshot.atr * InpProfitLockActivationAtr)
           {
            double profitLockSl = NormalizeDouble(openPrice + snapshot.atr * InpProfitLockAtr, g_symbolDigits);
            candidate = MathMax(candidate, profitLockSl);
           }
           
         if(candidate > trailedSl && candidate > openPrice)
            trailedSl = candidate;
            
         if(trailedSl >= currentSl + trailStep) 
            validTrailStep = true;
        }
      else if(type == POSITION_TYPE_SELL)
        {
         double candidate = NormalizeDouble(priceNow + snapshot.atr * InpTrailAtrMultiplier,g_symbolDigits);
         
         if(profitDistance >= snapshot.atr * InpProfitLockActivationAtr)
           {
            double profitLockSl = NormalizeDouble(openPrice - snapshot.atr * InpProfitLockAtr, g_symbolDigits);
            candidate = MathMin(candidate, profitLockSl);
           }
           
         if((trailedSl == 0.0 || candidate < trailedSl) && candidate < openPrice)
            trailedSl = candidate;
            
         if(trailedSl <= currentSl - trailStep || currentSl == 0.0) 
            validTrailStep = true;
        }

      if(validTrailStep && trailedSl > 0.0)
        {
         if(trade.PositionModify(ticket,trailedSl,currentTp))
           {
            DebugPrint(StringFormat("Trailing stop updated for ticket=%I64u",ticket));
            LogToCSV("TRAILING_UPDATED",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),"TRAILING_STOP_MOVED");
           }
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

void ManageOpenTrades(const bool isNewBar)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      ManageTrade(ticket, isNewBar);
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
     
   if(HasOpenPosition())
     {
      buyContext.valid = false;
      buyContext.reason = "MAX_GLOBAL_TRADES_REACHED";
      sellContext.valid = false;
      sellContext.reason = "MAX_GLOBAL_TRADES_REACHED";
     }
     
   if(TimeTradeServer() - g_lastTradeTime < InpTradeCooldownSeconds)
     {
      buyContext.valid = false;
      buyContext.reason = "COOLDOWN_ACTIVE";
      sellContext.valid = false;
      sellContext.reason = "COOLDOWN_ACTIVE";
     }

   int buyCount = CountPositions(POSITION_TYPE_BUY);
   if(HasBuyPosition())
     {
      buyContext.valid = false;
      buyContext.reason = "MAX_BUY_TRADES_REACHED";
     }
   else if(buyCount > 0)
     {
      bool continuationOk = entrySnapshot.emaBullish && (entrySnapshot.adx > InpAdxThreshold) && entrySnapshot.adxIncreasing;
      if(!continuationOk) { buyContext.valid = false; buyContext.reason = "NO_CONTINUATION_TREND"; }
     }
     
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   if(HasSellPosition())
     {
      sellContext.valid = false;
      sellContext.reason = "MAX_SELL_TRADES_REACHED";
     }
   else if(sellCount > 0)
     {
      bool continuationOk = entrySnapshot.emaBearish && (entrySnapshot.adx > InpAdxThreshold) && entrySnapshot.adxIncreasing;
      if(!continuationOk) { sellContext.valid = false; sellContext.reason = "NO_CONTINUATION_TREND"; }
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
     
   if(HasOpenPosition())
     {
      buyContext.valid = false;
      buyContext.reason = "MAX_GLOBAL_TRADES_REACHED";
      sellContext.valid = false;
      sellContext.reason = "MAX_GLOBAL_TRADES_REACHED";
     }
     
   if(TimeTradeServer() - g_lastTradeTime < InpTradeCooldownSeconds)
     {
      buyContext.valid = false;
      buyContext.reason = "COOLDOWN_ACTIVE";
      sellContext.valid = false;
      sellContext.reason = "COOLDOWN_ACTIVE";
     }

   int buyCount = CountPositions(POSITION_TYPE_BUY);
   if(HasBuyPosition())
     {
      buyContext.valid = false;
      buyContext.reason = "MAX_BUY_TRADES_REACHED";
     }
   else if(buyCount > 0)
     {
      bool continuationOk = liveSnapshot.emaBullish && (liveSnapshot.adx > InpAdxThreshold) && liveSnapshot.adxIncreasing;
      if(!continuationOk) { buyContext.valid = false; buyContext.reason = "NO_CONTINUATION_TREND"; }
     }
     
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   if(HasSellPosition())
     {
      sellContext.valid = false;
      sellContext.reason = "MAX_SELL_TRADES_REACHED";
     }
   else if(sellCount > 0)
     {
      bool continuationOk = liveSnapshot.emaBearish && (liveSnapshot.adx > InpAdxThreshold) && liveSnapshot.adxIncreasing;
      if(!continuationOk) { sellContext.valid = false; sellContext.reason = "NO_CONTINUATION_TREND"; }
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
   g_adxHandle     = iADX(InpTradeSymbol,InpTimeframe,InpAdxPeriod);

   if(g_fastEmaHandle == INVALID_HANDLE ||
      g_slowEmaHandle == INVALID_HANDLE ||
      g_rsiHandle == INVALID_HANDLE ||
      g_bbHandle == INVALID_HANDLE ||
      g_atrHandle == INVALID_HANDLE ||
      g_adxHandle == INVALID_HANDLE)
     {
      DebugPrint("Indicator handle creation failed");
      return INIT_FAILED;
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(InpTradeSymbol);

   RebuildAsianRangeFromHistory();
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
   if(g_adxHandle != INVALID_HANDLE)
      IndicatorRelease(g_adxHandle);
      
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
   
   bool newBar = IsNewBar();
   ManageOpenTrades(newBar);

   if(!newBar)
      return;

   CleanupStateGlobals();
   EvaluateEntries();
  }
