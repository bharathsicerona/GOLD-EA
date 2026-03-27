/*
================================================================================
# Entry System Execution Logic (v2.7)
The entry engine utilizes a weighted scoring system, decoupling from strictly 
stacked binary filters to maximize trade frequency and momentum capture.

### 1. Global Pre-Filters
* **Session Trading:** Operates 24/5 unless "Safe Mode" specifically blocks the Asian session. Dead zones have been removed.
* **Spread Tolerance:** Spread limits dynamically expand. Even if user inputs limit the spread, the High-Risk override forces a minimum spread tolerance of 500 points (50 pips) to accommodate XAUUSD volatility.
* **Spike Immunity:** The system calculates extreme anomalies based on 200% of the ATR multiplier, ignoring normal M1 volatile behavior.

### 2. Weighted Scoring Engine
Instead of rigid boolean pathways, trades are scored out of 100 points. 
A score of 60+ executes a trade. This soft-filter approach captures trades 
that miss "perfect" alignment but maintain strong statistical momentum.

### Changelog v2.75 - Structure-Break Confirmation
- ENHANCEMENT: Pullback is tracked as setup state; no entry on EMA touch.
- ENHANCEMENT: Added minimum 1-candle delay after pullback detection.
- ENHANCEMENT: Entry requires micro structure-break confirmation (previous candle high/low break).
- ENHANCEMENT: Optional quality boosts retained (RSI alignment, wick rejection, strong candle, EMA strength, HL/LH).
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

// Pullback continuation state (M1)
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
    if (InpSessionMode == SESSION_MODE_SAFE && currentSession == SESSION_ASIAN)
    {
        ctx.reason = "REJECT: Asian session disabled in Safe Mode";
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

    double rsiValues[2];
    if (CopyBuffer(g_rsiHandle, 0, 1, 2, rsiValues) < 2)
    {
        ctx.reason = "REJECT: Could not get RSI values";
        return ctx;
    }
    ctx.rsi = rsiValues[0];
    double emaSlow, emaFast, atrValue;
    if (!GetIndicatorValue(g_ema50Handle, 1, emaSlow) ||
        !GetIndicatorValue(g_ema20Handle, 1, emaFast) ||
        !GetIndicatorValue(g_atrHandle, 1, atrValue))
    {
        ctx.reason = "REJECT: Could not get EMA/ATR values";
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

    // --- 4. Structure-Break Core + Score Model ---
    int score = 0;
    int passThreshold = 2; // 0..5 boost model
    double emaGap = MathAbs(emaFast - emaSlow);
    double closePrice = rates[1].close;
    double openPrice = rates[1].open;
    double highPrice = rates[1].high;
    double lowPrice = rates[1].low;
    double candleBody = MathAbs(closePrice - openPrice);
    double prevBody = MathAbs(rates[2].close - rates[2].open);
    double upperWick = MathMax(0.0, highPrice - MathMax(openPrice, closePrice));
    double lowerWick = MathMax(0.0, MathMin(openPrice, closePrice) - lowPrice);
    double emaNearThreshold = MathMax(atrValue * 0.15, pointSize * 60.0);
    bool nearEma20 = (MathAbs(closePrice - emaFast) <= emaNearThreshold);
    bool bullishCandle = (closePrice > openPrice);
    bool bearishCandle = (closePrice < openPrice);
    bool buyWickRejection = (lowerWick >= MathMax(candleBody * 0.25, pointSize * 10.0));
    bool sellWickRejection = (upperWick >= MathMax(candleBody * 0.25, pointSize * 10.0));
    bool buyTrendAligned = (emaFast > emaSlow);
    bool sellTrendAligned = (emaFast < emaSlow);
    bool buyTrendAllowed = (closePrice > emaFast); // Core condition
    bool sellTrendAllowed = (closePrice < emaFast); // Core condition
    bool buyStructureBreak = (rates[1].high > rates[2].high && rates[1].close > rates[2].high);
    bool sellStructureBreak = (rates[1].low < rates[2].low && rates[1].close < rates[2].low);
    bool higherLow = (rates[1].low > rates[2].low);
    bool lowerHigh = (rates[1].high < rates[2].high);
    double rsiNow = rsiValues[0];
    ctx.emaFast = emaFast;
    ctx.emaSlow = emaSlow;
    ctx.atr = atrValue;

    if (direction == POSITION_TYPE_BUY)
    {
        // Hard block: extreme RSI only
        if (rsiNow > 80.0)
        {
            ctx.reason = "RSI_OVERBOUGHT";
            return ctx;
        }

        // Core trend alignment
        if (!buyTrendAllowed)
        {
            ctx.reason = "CORE_CONDITION_FAIL";
            g_buyPullbackDetected = false;
            g_buyPullbackBarTime = 0;
            return ctx;
        }

        // Pullback setup tracking (no entry on touch candle)
        if (nearEma20)
        {
            g_buyPullbackDetected = true;
            g_buyPullbackBarTime = rates[1].time;
            ctx.reason = "WAIT_FOR_STRUCTURE_BREAK";
            return ctx;
        }

        if (!g_buyPullbackDetected)
        {
            ctx.reason = "CORE_CONDITION_FAIL";
            return ctx;
        }

        // Minimum 1 candle delay after pullback
        if (rates[1].time <= g_buyPullbackBarTime)
        {
            ctx.reason = "WAIT_PULLBACK_DELAY";
            return ctx;
        }

        // Structure-break confirmation after pullback
        if (!(bullishCandle && buyStructureBreak))
        {
            ctx.reason = "WAIT_FOR_STRUCTURE_BREAK";
            return ctx;
        }

        // Boost scoring (0..5)
        if (rsiNow > 50.0) score += 1;           // RSI aligned (secondary only)
        if (buyWickRejection) score += 1;        // Wick rejection
        if (candleBody > prevBody) score += 1;   // Strong candle
        if (buyTrendAligned && emaGap >= atrValue * 0.03) score += 1; // EMA alignment strength
        if (higherLow) score += 1;               // Optional structure quality

        ctx.score = score;
        if (score >= passThreshold)
        {
            ctx.isValid = true;
            ctx.reason = "VALID";
            g_buyPullbackDetected = false;
            g_buyPullbackBarTime = 0;
            return ctx;
        }
        ctx.reason = "LOW_SCORE";
        return ctx;
    }
    else // SELL
    {
        // Hard block: extreme RSI only
        if (rsiNow < 20.0)
        {
            ctx.reason = "RSI_OVERSOLD";
            return ctx;
        }

        // Core trend alignment
        if (!sellTrendAllowed)
        {
            ctx.reason = "CORE_CONDITION_FAIL";
            g_sellPullbackDetected = false;
            g_sellPullbackBarTime = 0;
            return ctx;
        }

        // Pullback setup tracking (no entry on touch candle)
        if (nearEma20)
        {
            g_sellPullbackDetected = true;
            g_sellPullbackBarTime = rates[1].time;
            ctx.reason = "WAIT_FOR_STRUCTURE_BREAK";
            return ctx;
        }

        if (!g_sellPullbackDetected)
        {
            ctx.reason = "CORE_CONDITION_FAIL";
            return ctx;
        }

        // Minimum 1 candle delay after pullback
        if (rates[1].time <= g_sellPullbackBarTime)
        {
            ctx.reason = "WAIT_PULLBACK_DELAY";
            return ctx;
        }

        // Structure-break confirmation after pullback
        if (!(bearishCandle && sellStructureBreak))
        {
            ctx.reason = "WAIT_FOR_STRUCTURE_BREAK";
            return ctx;
        }

        // Boost scoring (0..5)
        if (rsiNow < 50.0) score += 1;           // RSI aligned (secondary only)
        if (sellWickRejection) score += 1;       // Wick rejection
        if (candleBody > prevBody) score += 1;   // Strong candle
        if (sellTrendAligned && emaGap >= atrValue * 0.03) score += 1; // EMA alignment strength
        if (lowerHigh) score += 1;               // Optional structure quality

        ctx.score = score;
        if (score >= passThreshold)
        {
            ctx.isValid = true;
            ctx.reason = "VALID";
            g_sellPullbackDetected = false;
            g_sellPullbackBarTime = 0;
            return ctx;
        }
        ctx.reason = "LOW_SCORE";
        return ctx;
    }
    
    return ctx;
}

#endif // XAUUSD_M1_SCALPER_ENTRY_MQH
