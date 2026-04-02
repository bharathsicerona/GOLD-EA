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
   double             sl;
   double             tp;
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

//+------------------------------------------------------------------+
//| DetectMarketMode - Enforces clean market categorization           |
//+------------------------------------------------------------------+
MarketMode DetectMarketMode(const IndicatorSnapshot &snapshot)
{
    double ema20 = snapshot.fastEma;
    double ema50 = snapshot.slowEma;
    double adx = snapshot.adx;
    double atr = snapshot.atr;
    double atrAvg = snapshot.atrAvg;

    // RULE: Use explicit thresholds for mode detection
    bool isTrend = (MathAbs(ema20 - ema50) > InpMarketTrendThreshold * _Point) && adx > InpMarketTrendAdx;
    bool isBreakout = (atr > atrAvg * InpMarketBreakoutAtrMultiplier) && adx > InpMarketBreakoutAdx;

    if(isBreakout) return MODE_BREAKOUT;
    if(isTrend) return MODE_TREND;

    return MODE_NONE;
}

//+------------------------------------------------------------------+
//| EvaluateStrategiesForDirection - Enforces strategy isolation     |
//+------------------------------------------------------------------+
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
   ctx.score = 0;
   ctx.isCounterTrend = false;
   ctx.riskPercent = InpRiskPercent;
   
   if(!snapshot.spreadOk)
     {
      ctx.reason = "HIGH_SPREAD";
      return ctx;
     }

   // --- 1. CORE QUALITY FILTERS (KILL WEAK TRADES) ---
   if(snapshot.adx < 20.0)
     {
      ctx.reason = "WEAK_TREND";
      return ctx;
     }

   if(snapshot.atr < snapshot.atrAvg * 0.8)
     {
      ctx.reason = "LOW_VOLATILITY";
      return ctx;
     }

   // --- 2. CANDLE STRENGTH FILTER ---
   double body = MathAbs(snapshot.closePrice - snapshot.openPrice);
   double candleRange = snapshot.highPrice - snapshot.lowPrice;
   if(candleRange > 0 && body < candleRange * 0.6)
     {
      ctx.reason = "WEAK_CANDLE";
      return ctx;
     }

   // --- 3. MARKET MODE DETECTION ---
   MarketMode mode = DetectMarketMode(snapshot);
   bool bullishCandle = (snapshot.closePrice > snapshot.openPrice);
   bool bearishCandle = (snapshot.closePrice < snapshot.openPrice);

   // --- 4. STRATEGY ISOLATION (ONLY ONE ACTIVE PER MODE) ---
   if(mode == MODE_BREAKOUT)
     {
      ctx.strategyName = "M5_ATR_BREAKOUT";
      // Breakout logic: Session alignment + expansion check
      bool atrBreakoutCondition = (snapshot.session == SESSION_LONDON || snapshot.session == SESSION_NEWYORK);
      if(!atrBreakoutCondition)
      {
          ctx.reason = "SESSION_MISMATCH";
          return ctx;
      }

      if(direction == POSITION_TYPE_BUY)
        {
         if((snapshot.closePrice > snapshot.fastEma) && bullishCandle)
           { ctx.valid = true; ctx.reason = "VALID"; return ctx; }
        }
      else
        {
         if((snapshot.closePrice < snapshot.fastEma) && bearishCandle)
           { ctx.valid = true; ctx.reason = "VALID"; return ctx; }
        }
     }
   else if(mode == MODE_TREND)
     {
      ctx.strategyName = "M5_TREND_PULLBACK";
      // Trend logic: Persistent trend + Pullback signal
      if(direction == POSITION_TYPE_BUY)
        {
         bool buyTrend = (snapshot.fastEma > snapshot.slowEma);
         if(buyTrend && snapshot.pullbackBuyOk && bullishCandle)
           { ctx.valid = true; ctx.reason = "VALID"; return ctx; }
        }
      else
        {
         bool sellTrend = (snapshot.fastEma < snapshot.slowEma);
         if(sellTrend && snapshot.pullbackSellOk && bearishCandle)
           { ctx.valid = true; ctx.reason = "VALID"; return ctx; }
        }
     }
   else
     {
      ctx.reason = "NO_MARKET_MODE";
      ctx.strategyName = "NONE";
      return ctx;
     }

   ctx.reason = "NO_SETUP";
   return ctx;
  }

//+------------------------------------------------------------------+
//| RunSmartReversalFVG - Liquidity-based reversal strategy          |
//+------------------------------------------------------------------+
bool RunSmartReversalFVG(DecisionContext &ctx, const IndicatorSnapshot &snapshot)
{
    string prefix = "[M5_SMART_REVERSAL_FVG]";
    // Re-check base filters
    if(snapshot.adx < 20.0) { LogTyped("REJECTION", prefix + " WEAK_TREND"); return false; }
    if(snapshot.atr < snapshot.atrAvg * 0.8) { LogTyped("REJECTION", prefix + " LOW_VOLATILITY"); return false; }

    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(InpTradeSymbol, InpTimeframe, 0, 50, rates) < 50) return false;

    // --- 1. Structure Shift (ChoCH) Detection ---
    double lastSwingHigh = 0, lastSwingLow = 0;
    double prevSwingHigh = 0, prevSwingLow = 0;
    
    // Find last 2 fractal highs/lows (5-candle fractal)
    for(int i = 3; i < 40; i++)
    {
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high && 
           rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
        {
            if(lastSwingHigh == 0) lastSwingHigh = rates[i].high;
            else if(prevSwingHigh == 0) { prevSwingHigh = rates[i].high; break; }
        }
    }
    for(int i = 3; i < 40; i++)
    {
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low && 
           rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
        {
            if(lastSwingLow == 0) lastSwingLow = rates[i].low;
            else if(prevSwingLow == 0) { prevSwingLow = rates[i].low; break; }
        }
    }

    if(lastSwingHigh == 0 || lastSwingLow == 0 || prevSwingHigh == 0 || prevSwingLow == 0) 
    {
        LogTyped("REJECTION", prefix + " NO_STRUCTURE");
        return false;
    }

    bool bullishShift = (rates[1].close > lastSwingHigh);
    bool bearishShift = (rates[1].close < lastSwingLow);

    if(!bullishShift && !bearishShift) 
    {
        LogTyped("REJECTION", prefix + " NO_STRUCTURE");
        return false;
    }

    // --- 2. Impulse Detection ---
    double body2 = MathAbs(rates[2].close - rates[2].open);
    if(body2 < snapshot.atr * 1.2) 
    {
        LogTyped("REJECTION", prefix + " NO_IMPULSE");
        return false;
    }

    // --- 3. FVG Detection (3-Candle) ---
    // Candle[3] = rates[3], Candle[1] = rates[1]
    double c1_high = rates[3].high;
    double c1_low  = rates[3].low;
    double c3_high = rates[1].high;
    double c3_low  = rates[1].low;

    bool bullishFVG = (c3_low > c1_high);
    bool bearishFVG = (c3_high < c1_low);

    if(!bullishFVG && !bearishFVG) 
    {
        LogTyped("REJECTION", prefix + " NO_FVG");
        return false;
    }

    // 4. FVG Zone Definition
    double fvgHigh, fvgLow;
    if(bullishFVG) { fvgHigh = c3_low; fvgLow = c1_high; }
    else { fvgHigh = c1_low; fvgLow = c3_high; }

    // 5. Close-Based Entry Rules
    double close1 = rates[1].close;
    double low1   = rates[1].low;
    double high1  = rates[1].high;

    // Wick-only check
    if(low1 <= fvgHigh && close1 > fvgHigh) 
    {
        LogTyped("REJECTION", prefix + " FVG_WICK_ONLY");
        return false;
    }
    
    // Full cross check
    if(bullishFVG && close1 < fvgLow) 
    {
        LogTyped("REJECTION", prefix + " FVG_CROSS_INVALID");
        return false;
    }
    if(bearishFVG && close1 > fvgHigh) 
    {
        LogTyped("REJECTION", prefix + " FVG_CROSS_INVALID");
        return false;
    }

    // Must close inside FVG
    if(!(close1 >= fvgLow && close1 <= fvgHigh)) 
    {
        LogTyped("REJECTION", prefix + " NO_CLOSE_CONFIRMATION");
        return false;
    }

    // 6. Discount/Premium Filter
    double swingH = lastSwingHigh;
    double swingL = lastSwingLow;
    double range = swingH - swingL;
    double fib50 = swingL + range * 0.5;

    if(bullishFVG && close1 > fib50) 
    {
        LogTyped("REJECTION", prefix + " NOT_IN_DISCOUNT");
        return false;
    }
    if(bearishFVG && close1 < fib50) 
    {
        LogTyped("REJECTION", prefix + " NOT_IN_PREMIUM");
        return false;
    }

    // 7. Confirmation Candle
    double body1 = MathAbs(rates[1].close - rates[1].open);
    double range1 = rates[1].high - rates[1].low;
    if(body1 < range1 * 0.6) 
    {
        LogTyped("REJECTION", prefix + " WEAK_CANDLE");
        return false;
    }

    // 8. Final Setup
    ctx.strategyName = "M5_SMART_REVERSAL_FVG";
    ctx.valid = true;
    ctx.reason = "VALID";

    if(bullishFVG)
    {
        ctx.type = POSITION_TYPE_BUY;
        ctx.sl = fvgLow - snapshot.atr * 0.2;
    }
    else
    {
        ctx.type = POSITION_TYPE_SELL;
        ctx.sl = fvgHigh + snapshot.atr * 0.2;
    }
    ctx.tp = close1 + (close1 - ctx.sl) * 2.5;

    LogTyped("CHECK", StringFormat("[M5_SMART_REVERSAL_FVG] %s check: atr=%.2f fvg=VALID discount=YES reason=VALID",
                                   (bullishFVG ? "BUY" : "SELL"), snapshot.atr));

    return true;
}

DecisionContext SelectAndRunStrategy(const ENUM_POSITION_TYPE direction,const IndicatorSnapshot &snapshot,const bool isBarClose = false)
  {
   DecisionContext ctx;
   // Reset Context
   ctx.valid = false;
   ctx.action = "SIGNAL_CHECK";
   ctx.phase = isBarClose ? "BAR_CLOSE_SIGNAL" : "LIVE_PREVIEW";
   ctx.type = direction;
   ctx.sessionName = SessionToString(snapshot.session);
   ctx.strategyName = "NONE";
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
   ctx.sl = 0;
   ctx.tp = 0;

   // 1. SMART REVERSAL FVG (Priority)
   if(InpEnableSmartReversalFVG && isBarClose)
   {
       if(RunSmartReversalFVG(ctx, snapshot))
       {
           if(ctx.type == direction)
               return ctx;
       }
   }

   // 2. Fallback to Mode-based strategies
   DecisionContext modeCtx = EvaluateStrategiesForDirection(direction, snapshot, isBarClose);

   if(isBarClose && modeCtx.valid)
      DebugPrint(StringFormat("[%s] %s valid signal: price=%.2f atr=%.2f reason=%s",
                               modeCtx.strategyName, PositionTypeText(direction), modeCtx.price, modeCtx.atr, modeCtx.reason));
   return modeCtx;
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

   if(!sessionOk) result.reason = "SESSION_BLOCK";
   else if(!snapshot.spreadOk) result.reason = "HIGH_SPREAD";
   else result.reason = (buyContext.reason != "NO_SETUP") ? buyContext.reason : sellContext.reason;

   return result;
  }

#endif // XAUUSD_ADAPTIVE_ENTRY_MQH
