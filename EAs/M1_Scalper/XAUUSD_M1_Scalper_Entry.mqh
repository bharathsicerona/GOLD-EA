/*
================================================================================
# Entry System Execution Logic (v2.93) - Performance Tuning
The entry engine uses a series of hard filters for high-frequency scalping.
It does not use a scoring system.

### 1. Core Entry Conditions
* **BUY:** Price > EMA(20) + Hybrid Pullback to EMA(20) + Bullish Candle
* **SELL:** Price < EMA(20) + Hybrid Pullback to EMA(20) + Bearish Candle

### 2. Mandatory Hard Filters
* **Session Trading:** Trades only in user-defined sessions.
* **Dynamic Spread:** Max spread is capped, based on a combination of a fixed value and a dynamic ATR-based value.
* **Minimum Volatility (ATR):** Rejects trades if ATR(14) is below a minimum threshold (e.g., 1.0), avoiding flat markets.
* **Trend Strength (EMA Gap):** Rejects trades if the gap between EMA(20) and EMA(50) is not wide enough, defined by an ATR-based threshold (`ATR * 0.6`).
* **Flat Market (EMA Slope):** Rejects trades if the EMA(20) is moving sideways.

### Changelog v2.93 - M1 Performance Tuning
- ENHANCEMENT: Replaced fixed-point EMA gap filter with a dynamic, ATR-based threshold (`ATR * 0.6`) for better market adaptivity.
- ENHANCEMENT: Replaced simple 'near EMA' pullback with a more robust hybrid logic, checking for price proximity (`ATR * 0.4`) or a candle body cross of the EMA.
- FEATURE: Added a minimum ATR filter to prevent entries in extremely low-volatility conditions.
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

    // --- 1. Get Indicator and Price Data ---
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
    
    // --- 2. Hard Filters (Pre-Trade Validation) ---
    
    // ATR Filter: Ensure minimum market volatility.
    const double MIN_ATR_VALUE = 1.0; // As per optimization request. Represents $1.0 price movement on XAUUSD.
    if (atrValue < MIN_ATR_VALUE)
    {
        ctx.reason = "REJECT: LOW_ATR";
        return ctx;
    }

    // Dynamic Spread Filter (ATR Based)
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

    // --- 3. Ultra-Simple EMA Pullback Model ---
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
    // NEW: Hybrid pullback logic, replacing old 'nearEma20'
    bool buyPullback = (MathAbs(closePrice - emaFast) <= atrValue * 0.4) || (rates[1].low <= emaFast && rates[1].close > emaFast);
    bool sellPullback = (MathAbs(closePrice - emaFast) <= atrValue * 0.4) || (rates[1].high >= emaFast && rates[1].close < emaFast);

    bool bullishCandle = (closePrice > openPrice);
    bool bearishCandle = (closePrice < openPrice);
    double candleBody = MathAbs(closePrice - openPrice);
    double prevCandleBody = MathAbs(prevClose - prevOpen);
    bool buyTrendAllowed = (closePrice > emaFast); // Core condition
    bool sellTrendAllowed = (closePrice < emaFast); // Core condition
    bool emaFlat = (MathAbs(emaFast - emaFastPrev) <= MathMax(pointSize * 8.0, atrValue * 0.01));
    ctx.emaFast = emaFast;
    ctx.emaSlow = emaSlow;
    ctx.atr = atrValue;

    // NEW: ATR-based dynamic EMA gap, replacing fixed points.
    double emaGap = MathAbs(emaFast - emaSlow);
    if (emaGap < (atrValue * 0.6))
    {
        ctx.reason = "TREND_WEAK";
        return ctx;
    }

    if (emaFlat)
    {
        ctx.reason = "EMA_FLAT";
        return ctx;
    }

    if (direction == POSITION_TYPE_BUY)
    {
        if (buyTrendAllowed && buyPullback && bullishCandle)
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
        if (sellTrendAllowed && sellPullback && bearishCandle)
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
