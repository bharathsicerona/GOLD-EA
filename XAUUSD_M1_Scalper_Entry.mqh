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

   // --- FIX #1: HARD BLOCK ASIAN SESSION ---
   // Immediately reject any trade if Asian session is disabled via inputs.
   if(currentSession == SESSION_ASIAN && !InpEnableAsianSession)
     {
      ctx.status = "BLOCKED";
      ctx.valid = false;
      ctx.reason = "ASIAN_SESSION_DISABLED";
      if(isBarClose)
         DebugPrint(StringFormat("[%s] %s: Hard block for Asian session.", ctx.strategyName, PositionTypeText(direction)));
      return ctx;
     }

   ctx.price = (SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID) + SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK)) * 0.5;
   ctx.isCounterTrend = false;
   ctx.riskPercent = InpMaxRiskPercent;

   bool isAsianBlockedSession = (currentSession == SESSION_ASIAN && !InpEnableAsianSession);
   bool isCoreSession = (currentSession == SESSION_LONDON || currentSession == SESSION_NEWYORK || currentSession == SESSION_ASIAN);
   if(!isCoreSession)
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
   // FIX: Always get at least 2 bars for Momentum & Micro-Trend checks.
   if(!GetRates(rates, 2))
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
   // --- FIX #3 & #4: New mandatory filter conditions ---
   bool momentumCandleOk = false;
   bool microTrendOk = false;
   
   bool emaGapOk = (MathAbs(ema20 - ema50) / _Point >= InpMinEmaGapPoints);
   int rawScore = 0;

   if(direction == POSITION_TYPE_BUY)
     {
      trendOk = (close > ema50);
      momOk   = (ema20 > ema50);
      rsiOk   = (rsi >= InpRsiBuyMin && rsi <= InpRsiBuyMax);
      pullOk  = (MathAbs(low - ema20) <= atrValue * InpPullbackAtrFactor);
      candleOk = (close > open);
      // FIX #3: Momentum Confirmation: only if Close[1] > Open[1]
      momentumCandleOk = (rates[1].close > rates[1].open);
      // FIX #4: Micro Trend Filter: only if Close[0] >= Close[1]
      microTrendOk = (rates[0].close >= rates[1].close);
     }
   else
     {
      trendOk = (close < ema50);
      momOk   = (ema20 < ema50);
      rsiOk   = (rsi >= InpRsiSellMin && rsi <= InpRsiSellMax);
      pullOk  = (MathAbs(high - ema20) <= atrValue * InpPullbackAtrFactor);
      candleOk = (close < open);
      // FIX #3: Momentum Confirmation: only if Close[1] < Open[1]
      momentumCandleOk = (rates[1].close < rates[1].open);
      // FIX #4: Micro Trend Filter: only if Close[0] <= Close[1]
      microTrendOk = (rates[0].close <= rates[1].close);
     }

   // Map pseudo-score matching the M5 visual feel (DO NOT CHANGE)
   if(trendOk) rawScore += 20;
   if(momOk) rawScore += 20;
   if(rsiOk) rawScore += 20;
   if(pullOk) rawScore += 20;
   if(emaGapOk) rawScore += 10;
   if(candleOk) rawScore += 10;
   
   ctx.score = rawScore;
   // FIX #2: Minimum ATR Filter: Reject trades if atr < 8.0
   bool volOk = (atrValue / _Point >= 8.0);
   bool sessionOk = !isAsianBlockedSession;
   bool trendAdaptiveOk = ((trendOk && momOk) || ctx.score >= 80);
   // FIX: OLD `candleAdaptiveOk` is removed and new mandatory filters are added
   bool structureOk = trendAdaptiveOk && rsiOk && pullOk && candleOk && emaGapOk && momentumCandleOk && microTrendOk;
   
   ctx.valid = sessionOk && spreadOk && volOk && structureOk;

   // Update reason string for better debuggging
   if(!sessionOk) ctx.reason = "ASIAN_DISABLED";
   else if(!spreadOk) ctx.reason = "SPREAD_TOO_HIGH";
   else if(!volOk) ctx.reason = "WEAK_VOLATILITY (ATR < 8.0)";
   else if(!momentumCandleOk) ctx.reason = "NO_MOMENTUM_CANDLE";
   else if(!microTrendOk) ctx.reason = "MICRO_TREND_FAIL";
   else if(!emaGapOk) ctx.reason = "WEAK_TREND";
   else if(!(trendOk && momOk) && ctx.score < 80) ctx.reason = "UNSTABLE_TREND";
   else if(!candleOk && ctx.score < 80) ctx.reason = "NO_CANDLE_CONFIRM";
   else if(!structureOk) ctx.reason = "TREND_STRUCTURE_FAIL";
   else ctx.reason = "SETUP_VALID";

   if(isBarClose)
      DebugPrint(StringFormat("[%s] %s check: price=%.2f atr=%.2f score=%d reason=%s",
                              ctx.strategyName, PositionTypeText(direction), ctx.price, ctx.atr, ctx.score, ctx.reason));
                              
   return ctx;
  }

#endif // XAUUSD_M1_SCALPER_ENTRY_MQH
