/*
================================================================================
# Entry System Execution Logic (v3.0) - Scoring model
Hard filters: ATR minimum + dynamic spread only.
Scoring (per side): core trend +2, pullback +1, EMA separation +1, momentum +1.
Valid entry when directional score >= 3, core trend true for that side, and score beats the opposite side.
================================================================================
*/
#ifndef XAUUSD_M1_SCALPER_ENTRY_MQH
#define XAUUSD_M1_SCALPER_ENTRY_MQH

// --- Structs and Enums ---
struct StrategySignal {
    string name;
    int direction; // BUY or SELL
    bool valid;
    double strength;
    bool isStrong;
    bool isWeak;
};

struct EntryContext
{
    bool   isValid;
    string reason;
    string strategy;
    double atr;
    double atrAvg;
    long   spread;
    double rsi;
    double emaFast;
    double emaSlow;
    double slDistance;
    double tpDistance;
};

enum ENUM_SESSION
{
    SESSION_NONE,
    SESSION_ASIAN,
    SESSION_LONDON,
    SESSION_NEWYORK
};

// Pullback state placeholders (kept for interface compatibility)
bool g_buyPullbackDetected = false;
bool g_sellPullbackDetected = false;
datetime g_buyPullbackBarTime = 0;
datetime g_sellPullbackBarTime = 0;

void ResetPullbackState()
{
    g_buyPullbackDetected = false;
    g_sellPullbackDetected = false;
    g_buyPullbackBarTime = 0;
    g_sellPullbackBarTime = 0;
}


// --- Helper Functions ---
string SessionToString(const ENUM_SESSION s)
{
    if (s == SESSION_ASIAN) return "ASIAN";
    if (s == SESSION_LONDON) return "LONDON";
    if (s == SESSION_NEWYORK) return "NEWYORK";
    return "NONE";
}

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

struct StrategyContext
{
    string strategyName;
};

//+------------------------------------------------------------------+
//| AdaptiveFilterCheck - Pre-strategy market condition filter       |
//+------------------------------------------------------------------+
bool AdaptiveFilterCheck(string &reason, double atr, double emaFast, double emaSlow, bool isBreakout)
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

    // 2. TREND STRENGTH FILTER
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
    
    // 5. BREAKOUT QUALITY FILTER
    if(isBreakout)
    {
        if(bod < atr * 0.5)
        {
            reason = "WEAK_BREAKOUT_DYNAMIC";
            return false;
        }
    }
    
    // 6. SESSION ADAPTIVE FILTER
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
//| CheckLiquiditySweep - New strategy for M1 Scalper                |
//+------------------------------------------------------------------+
bool CheckLiquiditySweep(int direction, StrategyContext &ctx)
{
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, 2, rates) < 2)
        return false;

    ArraySetAsSeries(rates, true);

    double atrValue = 0.0;
    if(!GetIndicatorValue(g_atrHandle, 1, atrValue))
        return false;

    bool triggered = false;

    if(direction == POSITION_TYPE_BUY)
    {
        // Previous high is taken, candle leaves upper wick, and closes back below breakout level
        if(rates[0].high > rates[1].high && (rates[0].high - rates[0].close) > (atrValue * 0.2) && rates[0].close < rates[1].high)
        {
            ctx.strategyName = "M1_LIQUIDITY_SWEEP";
            triggered = true;
        }
    }
    else if(direction == POSITION_TYPE_SELL)
    {
        // Previous low is taken, candle leaves lower wick, and closes back above breakout level
        if(rates[0].low < rates[1].low && (rates[0].close - rates[0].low) > (atrValue * 0.2) && rates[0].close > rates[1].low)
        {
            ctx.strategyName = "M1_LIQUIDITY_SWEEP";
            triggered = true;
        }
    }

    return triggered;
}

//+------------------------------------------------------------------+
//| ValidateEntry - Evaluates all strategies and returns signals     |
//+------------------------------------------------------------------+
void ValidateEntry(StrategySignal &signals[])
{
    // Initialize signals
    ArrayResize(signals, 3);
    for(int i = 0; i < 3; i++)
    {
        signals[i].valid = false;
        signals[i].isStrong = false;
        signals[i].isWeak = false;
    }
    signals[0].name = "M1_EMA_PULLBACK";
    signals[1].name = "M1_BREAKOUT";
    signals[2].name = "M1_LIQUIDITY_SWEEP";


    MqlRates rates[];
    if (CopyRates(_Symbol, _Period, 0, InpBreakoutCandles + 1, rates) < InpBreakoutCandles + 1)
    {
        return;
    }
    ArraySetAsSeries(rates, true);

    double rsiValue = 0.0;
    double emaSlow = 0.0;
    double emaFast = 0.0;
    double atrValue = 0.0;
    if (!GetIndicatorValue(g_ema50Handle, 1, emaSlow) ||
        !GetIndicatorValue(g_ema20Handle, 1, emaFast) ||
        !GetIndicatorValue(g_atrHandle, 1, atrValue) ||
        !GetIndicatorValue(g_rsiHandle, 1, rsiValue))
    {
        return;
    }

    double atrAvgValue = atrValue;
    double atrArr[];
    if (CopyBuffer(g_atrHandle, 0, 1, 20, atrArr) == 20)
    {
        double sum = 0;
        for (int i = 0; i < 20; i++) sum += atrArr[i];
        atrAvgValue = sum / 20.0;
    }

    // --- ATR QUALITY FILTER ---
    double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if (pointSize <= 0.0) return;

    if (atrValue < InpMinAtrPoints * pointSize)
    {
        return;
    }

    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    long dynamicSpreadMax = (long)((atrValue * 0.25) / pointSize);
    long maxAllowedSpread = MathMax((long)InpMaxSpreadPoints, dynamicSpreadMax);
    maxAllowedSpread = MathMax(maxAllowedSpread, 500);

    if (spread > maxAllowedSpread)
    {
        return;
    }

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double mid = (bid + ask) * 0.5;

    // --- STRATEGY 1: EMA PULLBACK ---
    if ((emaFast > emaSlow) && (mid <= emaFast + (atrValue * 0.2)) && (mid >= emaSlow))
    {
        signals[0].valid = true;
        signals[0].direction = POSITION_TYPE_BUY;
        signals[0].strength = 1.0;
    }
    if ((emaFast < emaSlow) && (mid >= emaFast - (atrValue * 0.2)) && (mid <= emaSlow))
    {
        signals[0].valid = true;
        signals[0].direction = POSITION_TYPE_SELL;
        signals[0].strength = 1.0;
    }

    // --- STRATEGY 2: BREAKOUT (last X candle high/low) ---
    ENUM_SESSION currentSession = GetCurrentSession();
    if (currentSession == SESSION_LONDON || currentSession == SESSION_NEWYORK)
    {
        double highestHigh = 0;
        double lowestLow = 999999;
        for (int i = 1; i <= InpBreakoutCandles; i++)
        {
            if (rates[i].high > highestHigh) highestHigh = rates[i].high;
            if (rates[i].low < lowestLow) lowestLow = rates[i].low;
        }

        double candleBody = MathAbs(rates[0].close - rates[0].open);
        double candleRange = rates[0].high - rates[0].low;
        bool isStrongCandle = (candleRange > 0 && (candleBody / candleRange) > 0.6);

        bool isAtrExpanding = atrValue > atrAvgValue * 1.2;

        if ((mid > highestHigh) && (highestHigh > 0))
        {
            signals[1].valid = true;
            signals[1].direction = POSITION_TYPE_BUY;
            signals[1].strength = 1.0;
            if(isAtrExpanding && isStrongCandle)
            {
                signals[1].isStrong = true;
            } else {
                signals[1].isWeak = true;
            }
        }
        if ((mid < lowestLow) && (lowestLow < 999999))
        {
            signals[1].valid = true;
            signals[1].direction = POSITION_TYPE_SELL;
            signals[1].strength = 1.0;
            if(isAtrExpanding && isStrongCandle)
            {
                signals[1].isStrong = true;
            } else {
                signals[1].isWeak = true;
            }
        }
    }

    // --- STRATEGY 3: LIQUIDITY SWEEP ---
    StrategyContext liqCtx;
    if (CheckLiquiditySweep(POSITION_TYPE_BUY, liqCtx))
    {
        signals[2].valid = true;
        signals[2].direction = POSITION_TYPE_BUY;
        signals[2].strength = 2.0; // Higher strength for override
        signals[2].isStrong = true;
    }
    if (CheckLiquiditySweep(POSITION_TYPE_SELL, liqCtx))
    {
        signals[2].valid = true;
        signals[2].direction = POSITION_TYPE_SELL;
        signals[2].strength = 2.0; // Higher strength for override
        signals[2].isStrong = true;
    }
}

//+------------------------------------------------------------------+
//| DetectReversalSignal - RSI extreme + engulfing logic             |
//+------------------------------------------------------------------+
bool DetectReversalSignal(ENUM_POSITION_TYPE &direction, double &strengthScore)
{
    MqlRates rates[];
    if (CopyRates(_Symbol, _Period, 0, 3, rates) < 3) return false;
    ArraySetAsSeries(rates, true);

    double rsiValue = 0.0;
    if (!GetIndicatorValue(g_rsiHandle, 1, rsiValue)) return false;

    bool bullEngulfing = (rates[2].close < rates[2].open) && (rates[1].close > rates[1].open) && 
                         (rates[1].close >= rates[2].open) && (rates[1].open <= rates[2].close);
    bool bearEngulfing = (rates[2].close > rates[2].open) && (rates[1].close < rates[1].open) && 
                         (rates[1].close <= rates[2].open) && (rates[1].open >= rates[2].close);

    direction = (ENUM_POSITION_TYPE)-1;
    strengthScore = 0.0;

    if ((rsiValue < 30.0) && bullEngulfing)
    {
        direction = POSITION_TYPE_BUY;
    }
    else if ((rsiValue > 70.0) && bearEngulfing)
    {
        direction = POSITION_TYPE_SELL;
    }

    if(direction != -1)
    {
        // RSI extreme distance score
        double rsiScore = (direction == POSITION_TYPE_BUY) ? (30.0 - rsiValue) : (rsiValue - 70.0);
        rsiScore = MathMax(0, rsiScore) / 10.0; // 0 to 3 scale (e.g. 20 RSI is 10/10=1, 10 RSI is 20/10=2)

        // Candle body size score
        double bodySize = MathAbs(rates[1].close - rates[1].open);
        double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double bodyScore = (bodySize / (100 * pointSize)); // scale based on pips

        // Wick rejection score
        double lowerWick = MathMin(rates[1].open, rates[1].close) - rates[1].low;
        double upperWick = rates[1].high - MathMax(rates[1].open, rates[1].close);
        double wickScore = (direction == POSITION_TYPE_BUY) ? (lowerWick / (50 * pointSize)) : (upperWick / (50 * pointSize));

        strengthScore = 1.0 + rsiScore + bodyScore + wickScore;
        return true;
    }

    return false;
}

#endif // XAUUSD_M1_SCALPER_ENTRY_MQH
