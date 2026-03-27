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

DecisionContext RunTrendPullbackStrategy(const ENUM_POSITION_TYPE direction,const IndicatorSnapshot &snapshot,const bool isBarClose)
  {
   DecisionContext ctx;
   ctx.valid = false;
   ctx.type = direction;
   ctx.action = "SIGNAL_CHECK";
   ctx.phase = "UNSPECIFIED";
   ctx.decision = PositionTypeText(direction);
   ctx.sessionName = SessionToString(snapshot.session);
   ctx.strategyName = "TREND_PULLBACK";
   ctx.status = snapshot.spreadOk ? "ACTIVE" : "BLOCKED";
   ctx.price = snapshot.price;
   ctx.rsi = snapshot.rsi;
   ctx.ema50 = snapshot.fastEma;
   ctx.ema200 = snapshot.slowEma;
   ctx.atr = snapshot.atr;
   ctx.spread = snapshot.spread;
   ctx.score = 0;
   ctx.isCounterTrend = false;
   ctx.riskPercent = InpRiskPercent;

   if(snapshot.session != SESSION_ASIAN)
     {
      ctx.reason = "SESSION_BLOCK";
      return ctx;
     }
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

   bool buyTrend = (snapshot.fastEma > snapshot.slowEma);
   bool sellTrend = (snapshot.fastEma < snapshot.slowEma);
   bool buyPullback = snapshot.pullbackBuyOk;
   bool sellPullback = snapshot.pullbackSellOk;

   bool strongTrend = snapshot.emaGapOk && snapshot.adxIncreasing && snapshot.adx > InpAdxThreshold;

   if(direction == POSITION_TYPE_BUY)
     {
      if(!buyTrend)
        {
         ctx.reason = "TREND_MISMATCH";
         return ctx;
        }
      if(!buyPullback)
        {
         ctx.reason = "NO_PULLBACK";
         return ctx;
        }
      if(!bullishCandle)
        {
         ctx.reason = "NO_CANDLE_CONFIRMATION";
         return ctx;
        }
      ctx.valid = true;
      ctx.score = strongTrend ? 90 : 75;
      ctx.reason = strongTrend ? "VALID_3R" : "VALID_2R";
      if(ctx.score < InpMinimumScore)
        {
         ctx.valid = false;
         ctx.reason = "LOW_SCORE";
        }
      return ctx;
     }

   if(direction == POSITION_TYPE_SELL)
     {
      if(!sellTrend)
        {
         ctx.reason = "TREND_MISMATCH";
         return ctx;
        }
      if(!sellPullback)
        {
         ctx.reason = "NO_PULLBACK";
         return ctx;
        }
      if(!bearishCandle)
        {
         ctx.reason = "NO_CANDLE_CONFIRMATION";
         return ctx;
        }
      ctx.valid = true;
      ctx.score = strongTrend ? 90 : 75;
      ctx.reason = strongTrend ? "VALID_3R" : "VALID_2R";
      if(ctx.score < InpMinimumScore)
        {
         ctx.valid = false;
         ctx.reason = "LOW_SCORE";
        }
      return ctx;
     }

   ctx.reason = "UNSUPPORTED_DIRECTION";
   return ctx;
  }

DecisionContext SelectAndRunStrategy(const ENUM_POSITION_TYPE direction,const IndicatorSnapshot &snapshot,const bool isBarClose = false)
  {
   DecisionContext ctx = RunTrendPullbackStrategy(direction, snapshot, isBarClose);
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
   result.strategyName = "TREND_PULLBACK";
   result.price    = snapshot.price;
   result.rsi      = snapshot.rsi;
   result.ema50    = snapshot.fastEma;
   result.ema200   = snapshot.slowEma;
   result.atr      = snapshot.atr;
   result.spread   = snapshot.spread;
   result.score    = MathMax(buyContext.score,sellContext.score);
   result.isCounterTrend = false;
   result.riskPercent = InpRiskPercent;

   if(buyContext.valid && (!sellContext.valid || buyContext.score >= sellContext.score))
      return buyContext;
   if(sellContext.valid)
      return sellContext;

   if(!sessionOk) result.reason = "SESSION_BLOCKED";
   else if(!snapshot.spreadOk) result.reason = "SPREAD_TOO_HIGH";
   else if(buyContext.score >= sellContext.score)
      result.reason = buyContext.reason;
   else
      result.reason = sellContext.reason;

   return result;
  }

#endif // XAUUSD_ADAPTIVE_ENTRY_MQH
