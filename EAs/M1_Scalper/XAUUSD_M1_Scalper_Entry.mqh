/*
================================================================================
# Entry System Execution Logic (v2.7)
The entry engine utilizes a weighted scoring system, decoupling from strictly 
stacked binary filters to maximize trade frequency and momentum capture.

### 1. Global Pre-Filters
* **Session Trading:** Operates 24/5 unless "Safe Mode" specifically blocks the Asian session. Dead zones have been removed.
* **Spread Tolerance:** Spread limits dynamically expand. Even if user inputs limit the spread, the High-Risk override forces a minimum spread tolerance of 500 points (50 pips) to accommodate XAUUSD volatility.
* **Spike Immunity:** The system calculates extreme anomalies based on 200% of the ATR multiplier, ignoring normal M1 volatile behavior.

### 2. Simplified Entry Engine
Entry is intentionally minimalist for scalping frequency:
* BUY: above EMA20 + near EMA20 pullback + bullish candle
* SELL: below EMA20 + near EMA20 pullback + bearish candle
Additional gating is limited to spread and runtime cooldown controls.

### Changelog v2.92 - Capital Booster Simplification
- ENHANCEMENT: Entry reduced to EMA20 bias + pullback touch + current candle direction.
- REMOVED: Breakout confirmation gate for faster M1 capital-booster execution.
- ENHANCEMENT: Added EMA flat-market skip (`EMA_FLAT`) to avoid chop entries.
- ENHANCEMENT: Designed to maximize trade frequency for profit-lock exits.
================================================================================
*/
#ifndef XAUUSD_M1_SCALPER_ENTRY_MQH
#define XAUUSD_M1_SCALPER_ENTRY_MQH

// --- Structs and Enums ---
struct EntryContext
{
    bool   isValid;
    string reason;
    int    score;
    double atr;
    long   spread;
    double rsi;
    double emaFast;
    double emaSlow;
    // Add other context fields as needed for logging
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

//+------------------------------------------------------------------+
//| ValidateEntry - High-Risk Scalping Logic                         |
//+------------------------------------------------------------------+
// This function replaces the old scoring system with a series of hard filters
// designed for the high-risk, high-reward scalping model.
EntryContext ValidateEntry(const ENUM_POSITION_TYPE direction)
{
    EntryContext ctx;
    ctx.isValid = false; // Default to invalid
    ctx.score = 0;
    ctx.atr = 0.0;
    ctx.spread = 0;
    ctx.rsi = 0.0;
    ctx.emaFast = 0.0;
    ctx.emaSlow = 0.0;

    // --- 1. Session Filter ---
    ENUM_SESSION currentSession = GetCurrentSession();
    if (currentSession != SESSION_LONDON && currentSession != SESSION_NEWYORK)
    {
        ctx.reason = "SESSION_BLOCK";
        return ctx;
    }

    // --- 2. Get Indicator and Price Data ---
    MqlRates rates[];
    if (CopyRates(_Symbol, _Period, 0, 3, rates) < 3)
    {
        ctx.reason = "REJECT: Not enough bar data";
        return ctx;
    }
    ArraySetAsSeries(rates, true);

    ctx.rsi = 0.0; // RSI intentionally removed from M1 simplified entry model.
    double emaSlow, emaFast, atrValue;
    if (!GetIndicatorValue(g_ema50Handle, 1, emaSlow) ||
        !GetIndicatorValue(g_ema20Handle, 1, emaFast) ||
        !GetIndicatorValue(g_atrHandle, 1, atrValue))
    {
        ctx.reason = "REJECT: Could not get EMA/ATR values";
        return ctx;
    }
    if (atrValue < InpMinAtrValue)
    {
        ctx.reason = "LOW_ATR";
        return ctx;
    }
    
    // --- 3. Dynamic Spread Filter (ATR Based) ---
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    ctx.spread = spread;
    double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    long dynamicSpreadMax = (long)((atrValue * 0.25) / pointSize); // Allow spread up to 25% of current ATR for spikes
    long maxAllowedSpread = MathMax((long)InpMaxSpreadPoints, dynamicSpreadMax);
    maxAllowedSpread = MathMax(maxAllowedSpread, 500); // Absolute floor of 500

    if (spread > maxAllowedSpread)
    {
        ctx.reason = StringFormat("REJECT: Spread too high (%d > %d)", spread, maxAllowedSpread);
        return ctx;
    }

    // --- 4. Ultra-Simple EMA Pullback Model ---
    double closePrice = rates[1].close;
    double openPrice = rates[1].open;
    double prevClose = rates[2].close;
    double prevOpen = rates[2].open;
    double emaFastPrev;
    if(!GetIndicatorValue(g_ema20Handle, 2, emaFastPrev))
    {
        ctx.reason = "REJECT: Could not get EMA20 previous value";
        return ctx;
    }
    double emaNearThreshold = MathMax(atrValue * 0.15, pointSize * 60.0);
    bool nearEma20 = (MathAbs(closePrice - emaFast) <= emaNearThreshold || rates[1].low <= emaFast + emaNearThreshold && rates[1].high >= emaFast - emaNearThreshold);
    bool bullishCandle = (closePrice > openPrice);
    bool bearishCandle = (closePrice < openPrice);
    double candleBody = MathAbs(closePrice - openPrice);
    double prevCandleBody = MathAbs(prevClose - prevOpen);
    bool momentumBodyOk = (candleBody > prevCandleBody);
    bool buyTrendAllowed = (closePrice > emaFast); // Core condition
    bool sellTrendAllowed = (closePrice < emaFast); // Core condition
    bool emaFlat = (MathAbs(emaFast - emaFastPrev) <= MathMax(pointSize * 8.0, atrValue * 0.01));
    ctx.emaFast = emaFast;
    ctx.emaSlow = emaSlow;
    ctx.atr = atrValue;

    double emaGapPoints = MathAbs(emaFast - emaSlow) / pointSize;
    if (emaGapPoints < InpMinEmaGapPoints)
    {
        ctx.reason = "TREND_WEAK";
        return ctx;
    }

    if (emaFlat)
    {
        ctx.reason = "EMA_FLAT";
        return ctx;
    }
    if (!momentumBodyOk)
    {
        ctx.reason = "MOMENTUM_WEAK";
        return ctx;
    }

    if (direction == POSITION_TYPE_BUY)
    {
        if (buyTrendAllowed && nearEma20 && bullishCandle)
        {
            ctx.isValid = true;
            ctx.score = 0;
            ctx.reason = "VALID";
            return ctx;
        }
        ctx.reason = "CORE_CONDITION_FAIL";
        return ctx;
    }
    else // SELL
    {
        if (sellTrendAllowed && nearEma20 && bearishCandle)
        {
            ctx.isValid = true;
            ctx.score = 0;
            ctx.reason = "VALID";
            return ctx;
        }
        ctx.reason = "CORE_CONDITION_FAIL";
        return ctx;
    }
    
    return ctx;
}

#endif // XAUUSD_M1_SCALPER_ENTRY_MQH
