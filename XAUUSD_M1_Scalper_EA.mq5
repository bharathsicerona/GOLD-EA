#property strict
#property version   "1.00"
#property description "M1 Scalper EA v1 for XAUUSD with Dynamic SL Shrinking and 1:3 RR"

#include <Trade/Trade.mqh>

input string           InpTradeSymbol            = "XAUUSDm";
input ENUM_TIMEFRAMES  InpTimeframe              = PERIOD_M1;
input ulong            InpMagicNumber            = 999111;

enum ENUM_SESSION
  {
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NEWYORK,
   SESSION_NONE
  };

// --- Risk Management ---
input double           InpMaxRiskPercent         = 10.0;    // Maximum Risk per Trade (%)
input double           InpStopAtrMultiplier      = 2.0;     // Initial SL ATR Multiplier
input double           InpRewardRiskRatio        = 3.0;     // Target Reward-to-Risk Ratio (1:3)

// --- Indicators ---
input int              InpFastEmaPeriod          = 20;      // Fast EMA (Momentum)
input int              InpSlowEmaPeriod          = 50;      // Slow EMA (Trend)
input int              InpRsiPeriod              = 14;      // RSI Period
input int              InpAtrPeriod              = 14;      // ATR Period

// --- Entry Filters ---
input double           InpRsiBuyMin              = 50.0;
input double           InpRsiBuyMax              = 70.0;
input double           InpRsiSellMin             = 30.0;
input double           InpRsiSellMax             = 50.0;
input double           InpMinAtrPoints           = 150.0;   // Min ATR points to trade (Noise Filter)
input double           InpMinEmaGapPoints        = 20.0;    // Min gap between EMA20 and EMA50
input double           InpPullbackAtrFactor      = 0.50;    // Max distance from EMA20 for pullback

// --- Trade & Profit Management ---
input int              InpMaxSpreadPoints        = 800;     // Max Spread Cap (Points)
input double           InpMaxSpreadAtrFactor     = 0.5;     // Max Spread vs ATR Factor
input int              InpCooldownSeconds        = 60;      // Cooldown after trade (Seconds)
input double           InpProfitLockTriggerPct   = 5.0;     // Profit % to trigger lock
input double           InpProfitLockTargetPct    = 1.0;     // Profit % to lock
input double           InpTrailAtrMultiplier     = 1.5;     // Trailing Stop ATR Multiplier
input double           InpTrailStepAtr           = 0.2;     // Min Step for Trailing (ATR factor)

// --- Session & Logging Settings (Visuals Only) ---
input int              InpAsianStartHour         = 0;
input int              InpAsianEndHour           = 8;
input int              InpLondonStartHour        = 8;
input int              InpLondonEndHour          = 13;
input int              InpNewYorkStartHour       = 13;
input int              InpNewYorkEndHour         = 22;

input int              InpMinimumScore           = 100;     // Minimum Score (Visual)
input bool             InpEnableDebugPrints      = true;
input bool             InpEnableCSVLogging       = true;
input bool             InpEnableDashboard        = true;
input bool             InpLogEveryTick           = false;
input int              InpLogRetentionDays       = 7;
input bool             InpEnablePushAlerts       = false;
input bool             InpEnableEmailAlerts      = false;

CTrade trade;

string   g_dashboardPrefix = "M1_Dash_";
int      g_ema20Handle   = INVALID_HANDLE;
int      g_ema50Handle   = INVALID_HANDLE;
int      g_rsiHandle     = INVALID_HANDLE;
int      g_atrHandle     = INVALID_HANDLE;
int      g_symbolDigits  = 2;
datetime g_lastBarTime   = 0;
datetime g_lastTradeTime = 0;

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
   if(type == POSITION_TYPE_BUY) return "BUY";
   if(type == POSITION_TYPE_SELL) return "SELL";
   return "NONE";
  }

string SessionToString(const ENUM_SESSION s)
  {
   if(s == SESSION_ASIAN) return "ASIAN";
   if(s == SESSION_LONDON) return "LONDON";
   if(s == SESSION_NEWYORK) return "NEWYORK";
   return "NONE";
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

void CleanupOldLogs()
  {
   if(InpLogRetentionDays <= 0) return;
   string fileName;
   long searchHandle = FileFindFirst("GoldEA_Log_*.csv", fileName);
   if(searchHandle != INVALID_HANDLE)
     {
      datetime threshold = TimeTradeServer() - (InpLogRetentionDays * 86400);
      do
        {
         if(StringLen(fileName) < 20) continue;
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
   if(!InpEnableCSVLogging) return;

   string dateStr = TimeToString(TimeTradeServer(), TIME_DATE);
   StringReplace(dateStr, ".", "");
   string currentLogName = StringFormat("GoldEA_Log_%s.csv", dateStr);

   int handle = FileOpen(currentLogName,FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE,',');
   if(handle == INVALID_HANDLE) return;

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

bool GetRates(MqlRates &rates[], const int count)
  {
   ArraySetAsSeries(rates, true);
   return (CopyRates(InpTradeSymbol, InpTimeframe, 0, count, rates) == count);
  }

bool GetIndicatorValue(const int handle, const int shift, double &value)
  {
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) != 1)
      return false;
   value = buffer[0];
   return true;
  }

double NormalizeVolume(const double volume)
  {
   double minLot  = SymbolInfoDouble(InpTradeSymbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(InpTradeSymbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(InpTradeSymbol, SYMBOL_VOLUME_STEP);

   if(minLot <= 0.0) minLot = 0.01;
   if(lotStep <= 0.0) lotStep = 0.01;

   double normalized = MathFloor(volume / lotStep) * lotStep;
   if(normalized < minLot) normalized = minLot;
   if(normalized > maxLot) normalized = maxLot;
   
   int digits = 2;
   if(lotStep == 0.001) digits = 3;
   if(lotStep == 0.1) digits = 1;
   if(lotStep == 1.0) digits = 0;
   
   return NormalizeDouble(normalized, digits);
  }

bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == InpTradeSymbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         return true;
     }
   return false;
  }

void AdjustStopLossToRisk(double &slDistance, double &lotSize)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxRiskUSD = balance * (InpMaxRiskPercent / 100.0);
   double tickSize = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0 || slDistance <= 0.0)
      return;

   // 1. Calculate theoretical lot
   double rawLot = maxRiskUSD / ((slDistance / tickSize) * tickValue);
   lotSize = NormalizeVolume(rawLot);

   // 2. Expected loss at assigned lot
   double expectedLoss = lotSize * (slDistance / tickSize) * tickValue;

   // 3. If Risk > Limit, adjust (shrink) the SL distance to match EXACTLY maxRiskUSD
   if(expectedLoss > maxRiskUSD && lotSize > 0.0)
     {
      double maxSLTicks = maxRiskUSD / (tickValue * lotSize);
      double adjustedSLDistance = maxSLTicks * tickSize;

      PrintFormat("[M1 Scalper] Risk Limit Exceeded: Expected Loss $%.2f > Max $%.2f. Shrinking SL %.2f -> %.2f", 
                  expectedLoss, maxRiskUSD, slDistance, adjustedSLDistance);
                  
      slDistance = adjustedSLDistance;
     }
  }

void CalculateLotSize(double &slDistance, double &lotSize)
  {
   // Calls the adjustment function which perfectly marries Lot Size and SL Distance
   AdjustStopLossToRisk(slDistance, lotSize);
  }

DecisionContext RunScalperStrategy(const ENUM_POSITION_TYPE direction, const bool isBarClose)
  {
   DecisionContext ctx;
   ctx.type = direction;
   ctx.action = "SIGNAL_CHECK";
   ctx.phase = "UNSPECIFIED";
   ctx.decision = PositionTypeText(direction);
   
   ENUM_SESSION currentSession = GetCurrentSession();
   ctx.sessionName = SessionToString(currentSession);
   ctx.strategyName = "SCALPER_TREND";
   
   ctx.price = (SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID) + SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK)) * 0.5;
   ctx.isCounterTrend = false;
   ctx.riskPercent = InpMaxRiskPercent;

   bool sessionOk = (currentSession == SESSION_LONDON || currentSession == SESSION_NEWYORK);
   if(!sessionOk)
     {
      ctx.status = "BLOCKED";
      ctx.spread = SymbolInfoInteger(InpTradeSymbol, SYMBOL_SPREAD);
      ctx.valid = false;
      ctx.reason = "SESSION_BLOCKED";
      if(isBarClose)
         DebugPrint(StringFormat("[%s] %s check: price=%.2f reason=%s", ctx.strategyName, PositionTypeText(direction), ctx.price, ctx.reason));
      return ctx;
     }

   int shift = isBarClose ? 1 : 0;
   MqlRates rates[];
   if(!GetRates(rates, shift + 1))
     {
      ctx.valid = false;
      ctx.reason = "NO_DATA";
      return ctx;
     }

   double ema20, ema50, rsi, atrValue;
   if(!GetIndicatorValue(g_ema20Handle, shift, ema20) ||
      !GetIndicatorValue(g_ema50Handle, shift, ema50) ||
      !GetIndicatorValue(g_rsiHandle, shift, rsi) ||
      !GetIndicatorValue(g_atrHandle, shift, atrValue))
     {
      ctx.valid = false;
      ctx.reason = "INDICATOR_ERROR";
      return ctx;
     }

   ctx.rsi = rsi;
   ctx.ema50 = ema20; // Visual mapping: Fast EMA
   ctx.ema200 = ema50; // Visual mapping: Slow EMA
   ctx.atr = atrValue;
   
   long spread = SymbolInfoInteger(InpTradeSymbol, SYMBOL_SPREAD);
   ctx.spread = spread;
   double maxDynamicSpread = (atrValue / _Point) * InpMaxSpreadAtrFactor;
   double maxAllowedSpread = MathMin((double)InpMaxSpreadPoints, maxDynamicSpread);
   bool spreadOk = (spread <= maxAllowedSpread);
   ctx.status = spreadOk ? "ACTIVE" : "BLOCKED";
   
   if(!spreadOk && isBarClose)
      DebugPrint(StringFormat("Spread check failed: Spread=%d MaxAllowed=%.1f", spread, maxAllowedSpread));

   double close = rates[shift].close;
   double high = rates[shift].high;
   double low = rates[shift].low;
   double open = rates[shift].open;

   bool trendOk = false, momOk = false, rsiOk = false, pullOk = false, candleOk = false;
   bool emaGapOk = (MathAbs(ema20 - ema50) / _Point >= InpMinEmaGapPoints);
   int rawScore = 0;

   if(direction == POSITION_TYPE_BUY)
     {
      trendOk = (close > ema50);
      momOk   = (ema20 > ema50);
      rsiOk   = (rsi >= InpRsiBuyMin && rsi <= InpRsiBuyMax);
      pullOk  = (MathAbs(low - ema20) <= atrValue * InpPullbackAtrFactor);
      candleOk = (close > open);
     }
   else
     {
      trendOk = (close < ema50);
      momOk   = (ema20 < ema50);
      rsiOk   = (rsi >= InpRsiSellMin && rsi <= InpRsiSellMax);
      pullOk  = (MathAbs(high - ema20) <= atrValue * InpPullbackAtrFactor);
      candleOk = (close < open);
     }

   // Map pseudo-score matching the M5 visual feel
   if(trendOk) rawScore += 20;
   if(momOk) rawScore += 20;
   if(rsiOk) rawScore += 20;
   if(pullOk) rawScore += 20;
   if(emaGapOk) rawScore += 10;
   if(candleOk) rawScore += 10;
   
   ctx.score = rawScore;
   bool volOk = (atrValue / _Point >= InpMinAtrPoints);
   bool structureOk = trendOk && momOk && rsiOk && pullOk && candleOk && emaGapOk;
   
   // Strict gate: Only allows execution if everything is physically flawless
   ctx.valid = spreadOk && volOk && structureOk;

   if(!spreadOk) ctx.reason = "SPREAD_TOO_HIGH";
   else if(!volOk) ctx.reason = "WEAK_VOLATILITY";
   else if(!emaGapOk) ctx.reason = "WEAK_TREND";
   else if(!trendOk || !momOk) ctx.reason = "UNSTABLE_TREND";
   else if(!candleOk) ctx.reason = "NO_CANDLE_CONFIRM";
   else if(!structureOk) ctx.reason = "TREND_STRUCTURE_FAIL";
   else ctx.reason = "SETUP_VALID";

   if(isBarClose)
      DebugPrint(StringFormat("[%s] %s check: price=%.2f atr=%.2f score=%d reason=%s",
                              ctx.strategyName, PositionTypeText(direction), ctx.price, ctx.atr, ctx.score, ctx.reason));
                              
   return ctx;
  }

DecisionContext PickBestDecision(const DecisionContext &buyContext,const DecisionContext &sellContext)
  {
   DecisionContext result;
   result.valid    = false;
   result.type     = POSITION_TYPE_BUY;
   result.action   = "TICK_EVAL";
   result.phase    = "LIVE_PREVIEW";
   result.decision = "SKIPPED";
   result.reason   = "NO_SETUP";
   result.status   = buyContext.status;
   result.sessionName = buyContext.sessionName;
   result.strategyName = "EVAL_PENDING";
   result.price    = buyContext.price;
   result.rsi      = buyContext.rsi;
   result.ema50    = buyContext.ema50;
   result.ema200   = buyContext.ema200;
   result.atr      = buyContext.atr;
   result.spread   = buyContext.spread;
   result.score    = MathMax(buyContext.score,sellContext.score);
   result.isCounterTrend = false;
   result.riskPercent = InpMaxRiskPercent;

   if(buyContext.valid && (!sellContext.valid || buyContext.score >= sellContext.score))
      return buyContext;
   if(sellContext.valid)
      return sellContext;

   if(buyContext.reason == "SESSION_BLOCKED") result.reason = "SESSION_BLOCKED";
   else if(buyContext.reason == "SPREAD_TOO_HIGH") result.reason = "SPREAD_TOO_HIGH";
   else if(buyContext.score >= sellContext.score)
     {
      result.strategyName = buyContext.strategyName;
      result.reason = buyContext.reason;
     }
   else
     {
      result.strategyName = sellContext.strategyName;
      result.reason = sellContext.reason;
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
   if(!InpEnableDashboard) return;
   color statusColor   = (context.status == "ACTIVE") ? clrLimeGreen : clrTomato;
   color scoreColor    = (context.score >= InpMinimumScore) ? clrLimeGreen : clrTomato;
   color decisionColor = clrGold;
   if(context.decision == "BUY") decisionColor = clrLimeGreen;
   else if(context.decision == "SELL") decisionColor = clrTomato;

   SetDashboardLine("Title","Gold EA Dashboard",clrWhite,0);
   SetDashboardLine("Session",StringFormat("Session        : %s [%s]",context.sessionName,context.status),statusColor,1);
   SetDashboardLine("Strategy",StringFormat("Strategy       : %s (Risk: %.1f%%)",context.strategyName,context.riskPercent),clrPlum,2);
   SetDashboardLine("ATR",StringFormat("ATR            : %.2f",context.atr),clrKhaki,3);
   SetDashboardLine("Score",StringFormat("Current Score  : %d",context.score),scoreColor,4);
   SetDashboardLine("Decision",StringFormat("Trade Decision : %s (%s)",context.decision,context.phase),decisionColor,5);
   SetDashboardLine("Reason",StringFormat("Reason         : %s",context.reason),clrYellow,6);
  }

void ExecuteTrade(const DecisionContext &context)
  {
   double entryPrice = (context.type == POSITION_TYPE_BUY) ? SymbolInfoDouble(InpTradeSymbol, SYMBOL_ASK) 
                                                           : SymbolInfoDouble(InpTradeSymbol, SYMBOL_BID);

   double originalSlDistance = context.atr * InpStopAtrMultiplier;
   double slDistance = originalSlDistance;
   double lotSize = 0.0;

   CalculateLotSize(slDistance, lotSize);

   if(lotSize <= 0.0 || slDistance <= 0.0)
     {
      DebugPrint("Trade skipped because lot calculation returned 0 (Invalid parameters).");
      LogToCSV("TRADE_SKIPPED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,"LOT_SIZE_ZERO");
      return;
     }

   // Enforce RR 1:3 
   double tpDistance = slDistance * InpRewardRiskRatio;
   
   double slPrice = 0.0;
   double tpPrice = 0.0;
   
   ulong tradeId = NextTradeId();
   string commentText = StringFormat("GoldEA#%I64u %s",tradeId,context.decision);

   if(context.type == POSITION_TYPE_BUY)
     {
      slPrice = NormalizeDouble(entryPrice - slDistance, g_symbolDigits);
      tpPrice = NormalizeDouble(entryPrice + tpDistance, g_symbolDigits);
     }
   else
     {
      slPrice = NormalizeDouble(entryPrice + slDistance, g_symbolDigits);
      tpPrice = NormalizeDouble(entryPrice - tpDistance, g_symbolDigits);
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);

   bool success = false;
   if(context.type == POSITION_TYPE_BUY)
      success = trade.Buy(lotSize, InpTradeSymbol, 0.0, slPrice, tpPrice, commentText);
   else
      success = trade.Sell(lotSize, InpTradeSymbol, 0.0, slPrice, tpPrice, commentText);

   if(success)
     {
      g_lastTradeTime = TimeTradeServer();
      double tickSize = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_VALUE);
      double actualRiskPct = ((lotSize * (slDistance / tickSize) * tickValue) / AccountInfoDouble(ACCOUNT_BALANCE)) * 100.0;
      
      if(slDistance < originalSlDistance)
         LogToCSV("SL_ADJUSTED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,StringFormat("OrigSL_%.2f_NewSL_%.2f", originalSlDistance, slDistance));

      DebugPrint(StringFormat("%s executed: tradeId=%I64u lot=%.2f entry=%.2f sl=%.2f tp=%.2f",context.decision,tradeId,lotSize,entryPrice,slPrice,tpPrice));
      LogToCSV(context.decision + "_EXECUTED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,StringFormat("TRADE_ID_%I64u",tradeId));

      if(InpEnablePushAlerts || InpEnableEmailAlerts)
        {
         string alertSubject = StringFormat("GoldEA %s %s Executed", context.strategyName, context.decision);
         string alertMsg = StringFormat("Action: %s %s\nType: %s\nActual Risk: %.2f%%\nLot: %.2f\nEntry: %.2f\nSL: %.2f\nTP Dist: %.2f points\nScore: %d",
                                        context.decision, InpTradeSymbol, context.strategyName, actualRiskPct, lotSize, entryPrice, slPrice, tpDistance / _Point, context.score);
         if(InpEnablePushAlerts) SendNotification(alertSubject + "\n" + alertMsg);
         if(InpEnableEmailAlerts) SendMail(alertSubject, alertMsg);
        }
     }
   else
     {
      string failReason = StringFormat("ORDER_FAILED_%d_%s",trade.ResultRetcode(),trade.ResultRetcodeDescription());
      DebugPrint(StringFormat("%s order failed: %s",context.decision,failReason));
      LogToCSV(context.decision + "_FAILED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,failReason);
     }
  }

void ManageOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != InpTradeSymbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSl   = PositionGetDouble(POSITION_SL);
      double currentTp   = PositionGetDouble(POSITION_TP);
      double volume      = PositionGetDouble(POSITION_VOLUME);
      double profitMoney = PositionGetDouble(POSITION_PROFIT);
      double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
      double currentPrice= (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(InpTradeSymbol, SYMBOL_BID) : SymbolInfoDouble(InpTradeSymbol, SYMBOL_ASK);
      
      double tickSize    = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue   = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_VALUE);
      
      if(tickSize <= 0.0 || tickValue <= 0.0 || volume <= 0.0) continue;

      double atrValue;
      if(!GetIndicatorValue(g_atrHandle, 0, atrValue)) continue;

      // --- 1. Evaluate Profit Lock (Lock 1% if >= 5%) ---
      double triggerTarget = balance * (InpProfitLockTriggerPct / 100.0);
      double lockTarget    = balance * (InpProfitLockTargetPct / 100.0);
      double lockPriceDiff = (lockTarget * tickSize) / (tickValue * volume);
      
      double lockSlPrice = 0.0;
      bool isLocked = false;

      if(type == POSITION_TYPE_BUY)
        {
         lockSlPrice = NormalizeDouble(openPrice + lockPriceDiff, g_symbolDigits);
         if(currentSl >= lockSlPrice) isLocked = true; // Already locked
        }
      else
        {
         lockSlPrice = NormalizeDouble(openPrice - lockPriceDiff, g_symbolDigits);
         if(currentSl <= lockSlPrice && currentSl != 0.0) isLocked = true; // Already locked
        }

      bool modified = false;
      if(!isLocked && profitMoney >= triggerTarget)
        {
         if(trade.PositionModify(ticket, lockSlPrice, currentTp))
           {
            DebugPrint(StringFormat("Account profit lock moved for ticket=%I64u", ticket));
            string reasonStr = StringFormat("PROFIT_$%.2f_SL_%.2f", profitMoney, lockSlPrice);
            LogToCSV("ACCOUNT_PROFIT_LOCK",SessionToString(GetCurrentSession()),"TRADE_MGMT",currentPrice,0,0,0,atrValue,0,0,PositionTypeText(type),reasonStr);
            modified = true;
            isLocked = true;
            currentSl = lockSlPrice;
           }
        }

      // --- 2. ATR Trailing Stop (Only active AFTER profit lock) ---
      if(isLocked && !modified)
        {
         double trailStep = atrValue * InpTrailStepAtr;
         double trailedSl = currentSl;
         bool validTrail = false;

         if(type == POSITION_TYPE_BUY)
           {
            double candidate = NormalizeDouble(currentPrice - (atrValue * InpTrailAtrMultiplier), g_symbolDigits);
            candidate = MathMax(candidate, lockSlPrice); // Never drop below profit lock
            if(candidate >= currentSl + trailStep)
              {
               trailedSl = candidate;
               validTrail = true;
              }
           }
         else
           {
            double candidate = NormalizeDouble(currentPrice + (atrValue * InpTrailAtrMultiplier), g_symbolDigits);
            candidate = MathMin(candidate, lockSlPrice); // Never rise above profit lock
            if(candidate <= currentSl - trailStep || currentSl == 0.0)
              {
               trailedSl = candidate;
               validTrail = true;
              }
           }

         if(validTrail && trailedSl > 0.0)
           {
            if(trade.PositionModify(ticket, trailedSl, currentTp))
              {
               DebugPrint(StringFormat("Trailing stop updated for ticket=%I64u", ticket));
               LogToCSV("TRAILING_UPDATED",SessionToString(GetCurrentSession()),"TRADE_MGMT",currentPrice,0,0,0,atrValue,0,0,PositionTypeText(type),"TRAILING_STOP_MOVED");
              }
           }
        }
     }
  }

int OnInit()
  {
   g_symbolDigits = (int)SymbolInfoInteger(InpTradeSymbol, SYMBOL_DIGITS);
   
   g_ema20Handle = iMA(InpTradeSymbol, InpTimeframe, InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ema50Handle = iMA(InpTradeSymbol, InpTimeframe, InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiHandle   = iRSI(InpTradeSymbol, InpTimeframe, InpRsiPeriod, PRICE_CLOSE);
   g_atrHandle   = iATR(InpTradeSymbol, InpTimeframe, InpAtrPeriod);

   if(g_ema20Handle == INVALID_HANDLE || g_ema50Handle == INVALID_HANDLE || 
      g_rsiHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE)
     {
      Print("Error creating indicators!");
      return INIT_FAILED;
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(InpTradeSymbol);
   
   CleanupOldLogs();
   DebugPrint(StringFormat("M1 EA initialized on %s timeframe=%d",InpTradeSymbol,InpTimeframe));
   LogToCSV("INIT","NONE","NONE",0.0,0.0,0.0,0.0,0.0,0,0,"ACTIVE","EA_INITIALIZED");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_ema20Handle != INVALID_HANDLE) IndicatorRelease(g_ema20Handle);
   if(g_ema50Handle != INVALID_HANDLE) IndicatorRelease(g_ema50Handle);
   if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);

   if(InpEnableDashboard)
     {
      string labels[7] = {"Title","Session","Strategy","ATR","Score","Decision","Reason"};
      for(int i = 0; i < 7; ++i)
         ObjectDelete(0,g_dashboardPrefix + labels[i]);
     }
   LogToCSV("DEINIT","NONE","NONE",0.0,0.0,0.0,0.0,0.0,0,0,"STOPPED",StringFormat("REASON_%d",reason));
  }

bool IsNewBar()
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(InpTradeSymbol, InpTimeframe, 0, 1, times) != 1) return false;
   if(times[0] == g_lastBarTime) return false;
   
   g_lastBarTime = times[0];
   return true;
  }

void EvaluateTickAndDashboard()
  {
   DecisionContext buyContext = RunScalperStrategy(POSITION_TYPE_BUY, false);
   DecisionContext sellContext = RunScalperStrategy(POSITION_TYPE_SELL, false);
   buyContext.phase  = "LIVE_PREVIEW";
   sellContext.phase = "LIVE_PREVIEW";

   if(HasOpenPosition())
     {
      buyContext.valid = false; buyContext.reason = "MAX_GLOBAL_TRADES_REACHED";
      sellContext.valid = false; sellContext.reason = "MAX_GLOBAL_TRADES_REACHED";
     }
   if(TimeTradeServer() - g_lastTradeTime < InpCooldownSeconds)
     {
      buyContext.valid = false; buyContext.reason = "COOLDOWN_ACTIVE";
      sellContext.valid = false; sellContext.reason = "COOLDOWN_ACTIVE";
     }

   DecisionContext current = PickBestDecision(buyContext, sellContext);
   UpdateDashboard(current);

   if(InpLogEveryTick)
      LogToCSV("LIVE_TICK_PREVIEW",current.sessionName,current.strategyName,current.price,current.rsi,current.ema50,current.ema200,current.atr,current.spread,current.score,current.decision,current.reason);
  }

void OnTick()
  {
   ManageOpenPosition();
   EvaluateTickAndDashboard();

   if(!IsNewBar()) return;

   DecisionContext buyContext = RunScalperStrategy(POSITION_TYPE_BUY, true);
   DecisionContext sellContext = RunScalperStrategy(POSITION_TYPE_SELL, true);
   buyContext.phase  = "BAR_CLOSE_SIGNAL";
   sellContext.phase = "BAR_CLOSE_SIGNAL";
   
   DecisionContext best = PickBestDecision(buyContext, sellContext);
   
   if(HasOpenPosition() || TimeTradeServer() - g_lastTradeTime < InpCooldownSeconds) return;
   
   if(best.valid)
     {
      LogToCSV("BAR_CLOSE_SIGNAL",best.sessionName,best.strategyName,best.price,best.rsi,best.ema50,best.ema200,best.atr,best.spread,best.score,best.decision,best.reason);
      ExecuteTrade(best);
     }
  }
