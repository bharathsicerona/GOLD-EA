#ifndef XAUUSD_ADAPTIVE_ENTRY_MQH
#define XAUUSD_ADAPTIVE_ENTRY_MQH

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

DecisionContext EvaluateStrategiesForDirection(const ENUM_POSITION_TYPE direction, const IndicatorSnapshot &snapshot, const bool isBarClose)
  {
   DecisionContext ctx;
   ctx.valid = false;
   ctx.type = direction;
   ctx.action = "SIGNAL_CHECK";
   ctx.phase = isBarClose ? "BAR_CLOSE_SIGNAL" : "LIVE_PREVIEW";
   ctx.decision = PositionTypeText(direction);
   ctx.sessionName = SessionToString(snapshot.session);
   ctx.strategyName = "NONE";
   ctx.status = snapshot.spreadOk ? "ACTIVE" : "BLOCKED";
   ctx.price = snapshot.price;
   ctx.rsi = snapshot.rsi;
   ctx.ema50 = snapshot.fastEma;
   ctx.ema200 = snapshot.slowEma;
   ctx.atr = snapshot.atr;
   ctx.spread = snapshot.spread;
   ctx.score = 0; // Removed scoring
   ctx.isCounterTrend = false;
   ctx.riskPercent = InpRiskPercent;
   
   if(!snapshot.spreadOk)
     {
      ctx.reason = "SPREAD_TOO_HIGH";
      return ctx;
     }
   if(!snapshot.volatilityOk)
     {
      ctx.reason = "MIN_ATR_REJECT";
      return ctx;
     }

   bool bullishCandle = (snapshot.closePrice > snapshot.openPrice);
   bool bearishCandle = (snapshot.closePrice < snapshot.openPrice);

   // --- Strategy 1: Trend Pullback ---
   bool buyTrend = (snapshot.fastEma > snapshot.slowEma);
   bool sellTrend = (snapshot.fastEma < snapshot.slowEma);
   bool buyPullback = buyTrend && snapshot.pullbackBuyOk && bullishCandle;
   bool sellPullback = sellTrend && snapshot.pullbackSellOk && bearishCandle;

   // --- Strategy 2: Range Bounce (Asian) ---
   bool isAsian = (snapshot.session == SESSION_ASIAN);
   bool buyRange = isAsian && (snapshot.rsi < 35.0) && bullishCandle;
   bool sellRange = isAsian && (snapshot.rsi > 65.0) && bearishCandle;

   // --- Strategy 3: Breakout (London) ---
   bool isLondon = (snapshot.session == SESSION_LONDON);
   bool buyBreakout = isLondon && (g_asianHigh > 0) && (snapshot.closePrice < g_asianHigh);
   bool sellBreakout = isLondon && (g_asianLow > 0) && (snapshot.closePrice > g_asianLow);

   // --- Strategy 4: ATR Breakout ---
   double atrAvg = snapshot.atr;
   double atrArr[];
   if(CopyBuffer(g_atrHandle, 0, snapshot.shift, 20, atrArr) == 20)
     {
      double sum = 0;
      for(int i = 0; i < 20; i++) sum += atrArr[i];
      atrAvg = sum / 20.0;
     }
   bool atrBreakoutSession = (snapshot.session == SESSION_LONDON || snapshot.session == SESSION_NEWYORK);
   bool atrBreakoutCondition = atrBreakoutSession && (snapshot.atr > atrAvg * 1.3) && (snapshot.adx > 28.0);
   bool buyAtrBreakout = atrBreakoutCondition && (snapshot.closePrice > snapshot.fastEma);
   bool sellAtrBreakout = atrBreakoutCondition && (snapshot.closePrice < snapshot.fastEma);

   if(direction == POSITION_TYPE_BUY)
     {
      if(buyPullback)    { ctx.valid = true; ctx.strategyName = "M5_TREND_PULLBACK"; ctx.reason = "VALID"; return ctx; }
      if(buyRange)       { ctx.valid = true; ctx.strategyName = "M5_RANGE"; ctx.reason = "VALID"; return ctx; }
      if(buyBreakout)    { ctx.valid = true; ctx.strategyName = "M5_BREAKOUT"; ctx.reason = "VALID"; return ctx; }
      if(buyAtrBreakout) { ctx.valid = true; ctx.strategyName = "M5_ATR_BREAKOUT"; ctx.reason = "VALID"; return ctx; }
     }
   else if(direction == POSITION_TYPE_SELL)
     {
      if(sellPullback)    { ctx.valid = true; ctx.strategyName = "M5_TREND_PULLBACK"; ctx.reason = "VALID"; return ctx; }
      if(sellRange)       { ctx.valid = true; ctx.strategyName = "M5_RANGE"; ctx.reason = "VALID"; return ctx; }
      if(sellBreakout)    { ctx.valid = true; ctx.strategyName = "M5_BREAKOUT"; ctx.reason = "VALID"; return ctx; }
      if(sellAtrBreakout) { ctx.valid = true; ctx.strategyName = "M5_ATR_BREAKOUT"; ctx.reason = "VALID"; return ctx; }
     }

   ctx.reason = "NO_SETUP";
   return ctx;
  }

DecisionContext SelectAndRunStrategy(const ENUM_POSITION_TYPE direction,const IndicatorSnapshot &snapshot,const bool isBarClose = false)
  {
   DecisionContext ctx = EvaluateStrategiesForDirection(direction, snapshot, isBarClose);

   if(isBarClose)
      DebugPrint(StringFormat("[%s] %s check: price=%.2f atr=%.2f reason=%s",
                              ctx.strategyName, PositionTypeText(direction), ctx.price, ctx.atr, ctx.reason));
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
   result.strategyName = "NONE";
   result.price    = snapshot.price;
   result.rsi      = snapshot.rsi;
   result.ema50    = snapshot.fastEma;
   result.ema200   = snapshot.slowEma;
   result.atr      = snapshot.atr;
   result.spread   = snapshot.spread;
   result.score    = 0;
   result.isCounterTrend = false;
   result.riskPercent = InpRiskPercent;

   if(buyContext.valid) return buyContext;
   if(sellContext.valid) return sellContext;

   if(!sessionOk) result.reason = "SESSION_BLOCKED";
   else if(!snapshot.spreadOk) result.reason = "SPREAD_TOO_HIGH";
   else result.reason = buyContext.reason;

   return result;
  }

#endif // XAUUSD_ADAPTIVE_ENTRY_MQH
