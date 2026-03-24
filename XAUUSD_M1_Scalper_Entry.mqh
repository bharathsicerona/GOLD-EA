#ifndef XAUUSD_M1_SCALPER_ENTRY_MQH
#define XAUUSD_M1_SCALPER_ENTRY_MQH

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
   double             ema20;
   double             atr;
   long               spread;
   int                score;
   bool               isCounterTrend;
   double             riskPercent;
  };

enum ENUM_SESSION
  {
   SESSION_NONE,
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NEWYORK
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
  
bool GetRates(MqlRates &rates[], const int count)
  {
   ArraySetAsSeries(rates, true);
   return (CopyRates(InpTradeSymbol, InpTimeframe, 0, count, rates) == count);
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

   bool sessionOk = (currentSession == SESSION_LONDON || currentSession == SESSION_NEWYORK || (InpEnableAsianSession && currentSession == SESSION_ASIAN));
   if(!sessionOk)
     {
      ctx.status = "BLOCKED";
      ctx.spread = SymbolInfoInteger(InpTradeSymbol, SYMBOL_SPREAD);
      ctx.valid = false;
      ctx.reason = (currentSession == SESSION_ASIAN && !InpEnableAsianSession) ? "ASIAN_DISABLED" : "SESSION_BLOCKED";
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
   ctx.ema50 = ema50;
   ctx.ema20 = ema20; 
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

#endif // XAUUSD_M1_SCALPER_ENTRY_MQH
