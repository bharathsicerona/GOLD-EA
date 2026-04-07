/*
================================================================================
# Single Strategy Entry System (v4.2) - M1_TREND_RSI_CONTINUATION (ADVANCED SPREAD)
Mode: FAST TREND MODE (EMA20 vs EMA50 + Slope)
HTF Directional Bias: EMA100
Candle-close execution only.
================================================================================
*/
#ifndef XAUUSD_M1_SCALPER_ENTRY_MQH
#define XAUUSD_M1_SCALPER_ENTRY_MQH

// --- Structs and Enums ---
struct StrategySignal {
    string name;
    int direction; // BUY or SELL
    bool valid;
    // --- ELITE UPGRADE START ---
    double trendStrength;
    double spreadRatio;
    string mode;
    string reason;
    // --- ELITE UPGRADE END ---
};

enum ENUM_SESSION
{
    SESSION_NONE,
    SESSION_ASIAN,
    SESSION_LONDON,
    SESSION_NEWYORK
};

// --- Helper Functions ---
ENUM_SESSION GetCurrentSession()
{
    MqlDateTime serverTime;
    TimeToStruct(TimeTradeServer(), serverTime);
    int hour = serverTime.hour;
    if (hour >= InpAsianStartHour && hour < InpAsianEndHour) return SESSION_ASIAN;
    if (hour >= InpLondonStartHour && hour < InpLondonEndHour) return SESSION_LONDON;
    if (hour >= InpNewYorkStartHour && hour < InpNewYorkEndHour) return SESSION_NEWYORK;
    return SESSION_NONE;
}

//+------------------------------------------------------------------+
//| AdaptiveFilterCheck - Pre-strategy market condition filter       |
//+------------------------------------------------------------------+
bool AdaptiveFilterCheck(string &reason, double atr, double emaFast, double emaSlow)
{
    // 1. ATR DYNAMIC FILTER
    double atrArr[];
    if (CopyBuffer(g_atrHandle, 0, 1, 20, atrArr) != 20) return true; // Fail open if data is not ready
    double atrAvg = 0;
    for(int i = 0; i < 20; i++) atrAvg += atrArr[i];
    atrAvg /= 20.0;

    if(atr < atrAvg * 0.8)
    {
        reason = "LOW_ATR_DYNAMIC";
        return false;
    }

    // 2. TREND STRENGTH FILTER (RELAXED MODE)
    double emaGap = MathAbs(emaFast - emaSlow);
    if(atr > 0)
    {
        double trendStrength = emaGap / atr;
        if(trendStrength < 0.1)
        {
            reason = "WEAK_TREND";
            return false;
        }
    }

    // 3. CHOP DETECTION
    MqlRates rates[];
    if (CopyRates(_Symbol, _Period, 0, 5, rates) != 5) return true; // Fail open
    double high5 = rates[0].high;
    double low5 = rates[0].low;
    for(int i = 1; i < 5; i++)
    {
        if(rates[i].high > high5) high5 = rates[i].high;
        if(rates[i].low < low5) low5 = rates[i].low;
    }
    double range5 = high5 - low5;
    if(range5 < atr * 1.2)
    {
        reason = "CHOP_MARKET_DYNAMIC";
        return false;
    }
    
    // 4. CANDLE QUALITY FILTER
    double bod = MathAbs(rates[0].close - rates[0].open);
    double rng = rates[0].high - rates[0].low;
    if(rng > 0 && bod < rng * 0.6)
    {
        reason = "WEAK_CANDLE_DYNAMIC";
        return false;
    }
    
    // 5. SESSION ADAPTIVE FILTER
    ENUM_SESSION currentSession = GetCurrentSession();
    if (currentSession == SESSION_NEWYORK)
    {
        if(atr < atrAvg)
        {
            reason = "NY_WEAK_CONDITION";
            return false;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| ValidateEntry - Evaluates ADVANCED SPREAD + FAST TREND           |
//+------------------------------------------------------------------+
bool ValidateEntry(StrategySignal &signal)
{
    signal.valid = false;
    signal.name = "M1_TREND_RSI_CONTINUATION";
    signal.direction = -1;
    // --- ELITE UPGRADE START ---
    signal.trendStrength = 0.0;
    signal.spreadRatio = 0.0;
    signal.mode = "SAFE";
    signal.reason = "NO_SETUP";
    // --- ELITE UPGRADE END ---

    MqlRates rates[];
    if (CopyRates(_Symbol, _Period, 0, 3, rates) < 3) return false;
    ArraySetAsSeries(rates, true);

    double rsiVal = 0.0, rsiPrev = 0.0;
    double ema20_curr = 0.0, ema20_prev = 0.0;
    double ema50_curr = 0.0;
    double ema100_curr = 0.0;
    double atrVal = 0.0;

    if (!GetIndicatorValue(g_ema20Handle, 1, ema20_curr) ||
        !GetIndicatorValue(g_ema20Handle, 2, ema20_prev) ||
        !GetIndicatorValue(g_ema50Handle, 1, ema50_curr) ||
        !GetIndicatorValue(g_ema100Handle, 1, ema100_curr) ||
        !GetIndicatorValue(g_atrHandle, 1, atrVal) ||
        !GetIndicatorValue(g_rsiHandle, 1, rsiVal) ||
        !GetIndicatorValue(g_rsiHandle, 2, rsiPrev))
    {
        return false;
    }

    double trendStrength = (atrVal > 0) ? (MathAbs(ema20_curr - ema50_curr) / atrVal) : 0;
    string slopeStr = (ema20_curr > ema20_prev) ? "UP" : "DOWN";
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    double spreadRatio = (atrVal > 0) ? ((double)spread / atrVal) : 0;
    // --- ELITE UPGRADE START ---
    signal.trendStrength = trendStrength;
    signal.spreadRatio = spreadRatio;

    double buyRsiMin = 35.0;
    double buyRsiMax = 60.0;
    double sellRsiMin = 30.0;
    double sellRsiMax = 60.0;
    bool requirePullback = true;
    bool requireStrongCandle = false;
    if(trendStrength > InpAggressiveTrendThreshold)
      {
       signal.mode = "AGGRESSIVE";
       buyRsiMax = 65.0;
       sellRsiMax = 65.0;
       requirePullback = false;
      }
    else if(trendStrength > InpNormalTrendThreshold)
      {
       signal.mode = "NORMAL";
      }
    else
      {
       signal.mode = "SAFE";
       buyRsiMin = 40.0;
       buyRsiMax = 55.0;
       sellRsiMin = 40.0;
       sellRsiMax = 55.0;
       requireStrongCandle = true;
      }

    double distance = MathAbs(rates[1].close - ema20_curr);
    double body1 = MathAbs(rates[1].close - rates[1].open);
    double body2 = MathAbs(rates[2].close - rates[2].open);
    // --- ELITE UPGRADE END ---

    // --- Core Setup Identification ---
    bool setupBuy = (ema20_curr > ema50_curr) && (ema20_curr > ema20_prev) && (rates[1].close > ema20_curr) && (rsiVal > rsiPrev);
    bool setupSell = (ema20_curr < ema50_curr) && (ema20_curr < ema20_prev) && (rates[1].close < ema20_curr) && (rsiVal < rsiPrev);

    if (!setupBuy && !setupSell) return false;

    string reason = "VALID";
    string sideStr = setupBuy ? "BUY" : "SELL";

    // --- 1. HTF Directional Bias (EMA100) ---
    if (setupBuy && rates[1].close <= ema100_curr) reason = "HTF_BIAS_BLOCK";
    else if (setupSell && rates[1].close >= ema100_curr) reason = "HTF_BIAS_BLOCK";

    // --- 2. ATR Filter (LOW_ATR_DYNAMIC) ---
    double atrArr[];
    double atrAvgValue = atrVal;
    if (CopyBuffer(g_atrHandle, 0, 1, 20, atrArr) == 20)
    {
        double sum = 0;
        for (int i = 0; i < 20; i++) sum += atrArr[i];
        atrAvgValue = sum / 20.0;
    }
    if (reason == "VALID" && atrVal < atrAvgValue * 0.8) reason = "LOW_ATR_DYNAMIC";

    // --- 3. ADVANCED SPREAD FILTER (PRO VERSION) ---
    if (reason == "VALID")
    {
        bool spreadBlock = false;
        if (spread > 500) spreadBlock = true;
        else if (atrVal > 0 && spreadRatio > InpSpreadRatioLimit && trendStrength < InpSpreadTrendFloor) spreadBlock = true;

        if (spreadBlock)
        {
            signal.reason = "HIGH_SPREAD";
            LogTyped("REJECTION", StringFormat("[%s] %s rejected: reason=HIGH_SPREAD spread=%d atr=%.2f trendStrength=%.2f spreadRatio=%.2f",
                     signal.name, sideStr, (int)spread, atrVal, trendStrength, spreadRatio));
            return false;
        }
    }

    // --- 4. WEAK_CANDLE_DYNAMIC (PRO VERSION) ---
    if (reason == "VALID")
    {
        if (body1 < atrVal * 0.2 && body2 < atrVal * 0.2)
        {
            signal.reason = "WEAK_CANDLE_DYNAMIC";
            LogTyped("REJECTION", StringFormat("[%s] %s rejected: reason=WEAK_CANDLE_DYNAMIC atr=%.2f trendStrength=%.2f spreadRatio=%.2f",
                     signal.name, sideStr, atrVal, trendStrength, spreadRatio));
            return false;
        }
    }

    // --- ELITE UPGRADE START ---
    if(reason == "VALID" && requirePullback && distance > atrVal * InpPullbackAtrLimit)
      {
       reason = "TOO_FAR_FROM_EMA";
      }
    // --- FIX START ---
    else if(reason == "VALID" && distance > atrVal * 0.4)
      {
       reason = "LATE_ENTRY";
      }
    // --- FIX END ---

    if(reason == "VALID" && requireStrongCandle && body1 <= atrVal * 0.3)
      {
       reason = "WEAK_SAFE_CANDLE";
      }

    if(reason == "VALID" && InpUseExplosiveMode && body1 <= atrVal * 0.5)
      {
       reason = "NO_MOMENTUM";
      }
    // --- ELITE UPGRADE END ---

    // --- 5. RSI/Trend/Final Logic ---
    if (reason == "VALID")
    {
        if(setupBuy)
        {
            if(rsiVal >= buyRsiMax) reason = "RSI_TOO_HIGH";
            else if(rsiVal <= buyRsiMin) reason = "RSI_TOO_LOW";
        }
        else if(setupSell)
        {
            if(rsiVal <= sellRsiMin) reason = "RSI_TOO_LOW";
            else if(rsiVal >= sellRsiMax) reason = "RSI_TOO_HIGH";
        }
    }

    if(reason == "VALID")
    {
        signal.valid = true;
        signal.direction = setupBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        signal.reason = "VALID";
        
        // --- FIX START ---
        LogTyped("CHECK", StringFormat("[%s] %s check: rsi=%.2f ema20=%.2f ema50=%.2f slope=%s atr=%.2f trendStrength=%.2f spreadRatio=%.2f mode=%s reason=%s",
                                       signal.name, sideStr, rsiVal, ema20_curr, ema50_curr, slopeStr, atrVal, trendStrength, spreadRatio, signal.mode, signal.reason));
        // --- FIX END ---
        return true;
    }
    else
    {
        signal.reason = reason;
        LogTyped("REJECTION", StringFormat("[%s] %s rejected: reason=%s atr=%.2f trendStrength=%.2f spreadRatio=%.2f mode=%s",
                 signal.name, sideStr, reason, atrVal, trendStrength, spreadRatio, signal.mode));
        return false;
    }
}

#endif // XAUUSD_M1_SCALPER_ENTRY_MQH
