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

string StrategyToString(const ENUM_STRATEGY s)
  {
   if(s == STRATEGY_RANGE) return "RANGE";
   if(s == STRATEGY_BREAKOUT) return "BREAKOUT";
   if(s == STRATEGY_TREND) return "TREND";
   return "NONE";
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

   int penalty = 0;
   if(!rsiOk) penalty += 15;
   if(!bbOk) penalty += 15;

   ctx.score -= penalty;
   if(ctx.score > 100) ctx.score = 100;
   if(ctx.score < 0) ctx.score = 0;

   ctx.valid = snapshot.spreadOk && (InpUseScoring == SCORE_DISABLED || ctx.score >= InpMinimumScore);

   if(!snapshot.spreadOk) ctx.reason = "SPREAD_TOO_HIGH";
   else if(!ctx.valid) ctx.reason = (penalty >= 15) ? "RANGE_PENALTY_REJECTION" : "SCORE_TOO_LOW";
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
   bool rangeDetected = (g_asianHigh > 0.0 && g_asianLow > 0.0 && g_asianHigh > g_asianLow);

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

   if(rangeDetected && breakOk)
      ctx.score += 20;
   else if(rangeDetected && !breakOk)
      ctx.score -= 10;
      
   if((snapshot.session == SESSION_LONDON || snapshot.session == SESSION_NEWYORK) && snapshot.adx > 25.0)
      ctx.score += 15;

   bool adxOk = (snapshot.adx > InpAdxThreshold);
   bool emaGapOk = snapshot.emaGapOk;
   bool persistenceOk = (direction == POSITION_TYPE_BUY) ? snapshot.trendPersistentBuy : snapshot.trendPersistentSell;
   bool structureOk = trendOk && rsiOk && pullbackOk;

   int penalty = 0;
   if(!adxOk) penalty += 10;           // WEAK_TREND
   if(!emaGapOk) penalty += 15;        // SIDEWAYS_MARKET
   if(!persistenceOk) penalty += 10;   // UNSTABLE_TREND
   if(!structureOk) penalty += 15;     // TREND_STRUCTURE_FAIL
   if(!breakOk && !rangeDetected) penalty += 10; // Extra penalty if no breakout and not in range

   ctx.score -= penalty;
   if(ctx.score > 100) ctx.score = 100;
   if(ctx.score < 0) ctx.score = 0;

   ctx.valid = snapshot.spreadOk && (InpUseScoring == SCORE_DISABLED || ctx.score >= InpMinimumScore);

   if(!snapshot.spreadOk) ctx.reason = "SPREAD_TOO_HIGH";
   else if(!ctx.valid) ctx.reason = (penalty >= 15) ? "HIGH_PENALTY_REJECTION" : "SCORE_TOO_LOW";
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

   if((snapshot.session == SESSION_LONDON || snapshot.session == SESSION_NEWYORK) && snapshot.adx > 25.0)
      ctx.score += 15;

   bool adxOk = (snapshot.adx > InpAdxThreshold);
   bool emaGapOk = snapshot.emaGapOk;
   bool persistenceOk = (direction == POSITION_TYPE_BUY) ? snapshot.trendPersistentBuy : snapshot.trendPersistentSell;
   bool structureOk = trendOk && rsiOk && pullbackOk;

   int penalty = 0;
   if(!adxOk) penalty += 10;
   if(!emaGapOk) penalty += 15;
   if(!persistenceOk) penalty += 10;
   if(!structureOk) penalty += 15;

   ctx.score -= penalty;
   if(ctx.score > 100) ctx.score = 100;
   if(ctx.score < 0) ctx.score = 0;

   ctx.valid = snapshot.spreadOk && (InpUseScoring == SCORE_DISABLED || ctx.score >= InpMinimumScore);

   if(!snapshot.spreadOk) ctx.reason = "SPREAD_TOO_HIGH";
   else if(!ctx.valid) ctx.reason = (penalty >= 15) ? "HIGH_PENALTY_REJECTION" : "SCORE_TOO_LOW";
   else ctx.reason = "SETUP_VALID";

   return ctx;
  }

DecisionContext SelectAndRunStrategy(const ENUM_POSITION_TYPE direction,const IndicatorSnapshot &snapshot,const bool isBarClose = false)
  {
   DecisionContext ctx;
   bool sessionOk = (snapshot.session == SESSION_ASIAN || snapshot.session == SESSION_LONDON || snapshot.session == SESSION_NEWYORK);

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

   if(!sessionOk)
     {
      ctx.score -= 20;
      if(ctx.score >= InpMinimumScore)
        {
         ctx.valid = snapshot.spreadOk;
         ctx.reason = "OUT_OF_SESSION_OVERRIDE";
        }
      else
        {
         ctx.valid = false;
         ctx.reason = "SESSION_BLOCKED_LOW_SCORE";
        }
     }

   if(ctx.valid)
     {
      double close0 = iClose(InpTradeSymbol, InpTimeframe, 0);
      double close1 = iClose(InpTradeSymbol, InpTimeframe, 1);
      double open1  = iOpen(InpTradeSymbol, InpTimeframe, 1);
      
      bool momentumOk = false;
      bool microTrendOk = false;
      
      if(direction == POSITION_TYPE_BUY)
        {
         momentumOk = (close1 > open1);
         microTrendOk = (close0 >= close1);
        }
      else if(direction == POSITION_TYPE_SELL)
        {
         momentumOk = (close1 < open1);
         microTrendOk = (close0 <= close1);
        }
        
      if(snapshot.atr < 8.0)
        {
         ctx.valid = false;
         ctx.reason = "MIN_ATR_REJECT";
        }
      else if(!momentumOk)
        {
         ctx.valid = false;
         ctx.reason = "MOMENTUM_REJECT";
        }
      else if(!microTrendOk)
        {
         ctx.valid = false;
         ctx.reason = "MICRO_TREND_REJECT";
        }
      else if(snapshot.session == SESSION_ASIAN && ctx.score < 95)
        {
         ctx.valid = false;
         ctx.reason = "ASIAN_STRICT_REJECT";
        }
     }

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

   if(!sessionOk) result.reason = "SESSION_BLOCKED";
   else if(!snapshot.spreadOk) result.reason = "SPREAD_TOO_HIGH";
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

#endif // XAUUSD_ADAPTIVE_ENTRY_MQH
