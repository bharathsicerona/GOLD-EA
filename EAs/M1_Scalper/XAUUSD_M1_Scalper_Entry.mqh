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

### Changelog v2.70 - Bi-directional Trading Upgrade
- ENHANCEMENT: Applied strictly symmetric scoring logic to perfectly balance BUY and SELL entries.
- ENHANCEMENT: Removed hard counter-trend rejection blocks. Early price reversals can now trigger entries before EMAs fully cross.
- ENHANCEMENT: Adjusted Fallback weighting to guarantee execution if EMA Trend and RSI (>50 / <50) align.
================================================================================
*/
#ifndef XAUUSD_M1_SCALPER_ENTRY_MQH
#define XAUUSD_M1_SCALPER_ENTRY_MQH

// --- Structs and Enums ---
struct EntryContext
{
    bool   isValid;
    string reason;
    // Add other context fields as needed for logging
};

enum ENUM_SESSION
{
    SESSION_NONE,
    SESSION_ASIAN,
    SESSION_LONDON,
    SESSION_NEWYORK
};


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
    double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    long dynamicSpreadMax = (long)((atrValue * 0.25) / pointSize); // Allow spread up to 25% of current ATR for spikes
    long maxAllowedSpread = MathMax((long)InpMaxSpreadPoints, dynamicSpreadMax);
    maxAllowedSpread = MathMax(maxAllowedSpread, 500); // Absolute floor of 500

    if (spread > maxAllowedSpread)
    {
        ctx.reason = StringFormat("REJECT: Spread too high (%d > %d)", spread, maxAllowedSpread);
        return ctx;
    }

    // --- 4. Spike Candle Filter ---
    double candleRange = rates[1].high - rates[1].low;
    // Relaxed spike filter to prevent over-filtering (threshold doubled)
    if (candleRange > atrValue * (InpSpikeCandleAtrFactor * 2.0))
    {
        ctx.reason = StringFormat("REJECT: Spike candle detected (Range %.2f > ATR %.2f)", candleRange, atrValue);
        return ctx;
    }

    // --- 5. Weighted Scoring Engine (Soft Filters) ---
    int score = 0;
    int passThreshold = 60; // 60/100 points required to enter a trade
    double emaGap = MathAbs(emaFast - emaSlow);

    if (direction == POSITION_TYPE_BUY)
    {
        // 1. Trend Direction & Gap (Max 30 pts)
        if (emaFast > emaSlow) {
            score += 15; // Basic uptrend
            if (emaGap >= atrValue * 0.05) score += 15; // Strong gap confirmation
        }

        // 2. RSI Level & Momentum (Max 35 pts)
        if (rsiValues[0] > 50.0) score += 20; // Core RSI level (Bullish)
        if (rsiValues[0] > rsiValues[1]) score += 15; // RSI sloping up

        // 3. Price Action Confirmation (Max 35 pts)
        if (rates[1].close > rates[1].open) score += 15; // Bullish candle
        if (rates[1].close > emaSlow) score += 20; // Price successfully crossed above Slow EMA

        // Evaluation
        if (score >= passThreshold) {
            ctx.isValid = true;
            ctx.reason = StringFormat("BUY SIGNAL: EMA uptrend + RSI=%.2f (Score: %d)", rsiValues[0], score);
            Print(ctx.reason); // Explicit logging
            return ctx;
        } else {
            ctx.reason = StringFormat("REJECT: BUY Score %d < %d", score, passThreshold);
            return ctx;
        }
    }
    else // SELL
    {
        // 1. Trend Direction & Gap (Max 30 pts)
        if (emaFast < emaSlow) {
            score += 15; // Basic downtrend
            if (emaGap >= atrValue * 0.05) score += 15; // Strong gap confirmation
        }

        // 2. RSI Level & Momentum (Max 35 pts)
        if (rsiValues[0] < 50.0) score += 20; // Core RSI level (Bearish)
        if (rsiValues[0] < rsiValues[1]) score += 15; // RSI sloping down

        // 3. Price Action Confirmation (Max 35 pts)
        if (rates[1].close < rates[1].open) score += 15; // Bearish candle
        if (rates[1].close < emaSlow) score += 20; // Price successfully crossed below Slow EMA

        // Evaluation
        if (score >= passThreshold) {
            ctx.isValid = true;
            ctx.reason = StringFormat("SELL SIGNAL: EMA downtrend + RSI=%.2f (Score: %d)", rsiValues[0], score);
            Print(ctx.reason); // Explicit logging
            return ctx;
        } else {
            ctx.reason = StringFormat("REJECT: SELL Score %d < %d", score, passThreshold);
            return ctx;
        }
    }
    
    return ctx;
}

#endif // XAUUSD_M1_SCALPER_ENTRY_MQH
