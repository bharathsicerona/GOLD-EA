#ifndef XAUUSD_M1_QUICKHANDS_ENTRY_MQH
#define XAUUSD_M1_QUICKHANDS_ENTRY_MQH

#include "XAUUSD_M1_QuickHands_Inputs.mqh"
#include "XAUUSD_M1_QuickHands_Logging.mqh"
#include "../Include/GoldEA_Common_Core.mqh"

//+------------------------------------------------------------------+
//| Strategy Signal Struct                                           |
//+------------------------------------------------------------------+
struct StrategySignal
{
    ENUM_POSITION_TYPE type;
    string pattern;
    string mode;
    double atr;
    double rsi;
    double rsiPrev;
    double emaFast;
    double emaFastPrev;
    double emaSlow;
    double emaBias;
    double trendStrength;
    double spreadRatio;
    double distance;
    long spread;
    string reason;
    bool isValid;
    double structureSL; // Price level
    double slStruct;    // Distance
    double slATR;       // Distance
    double slFinal;     // Distance
    double c1BodyRatio;
    double c2BodyRatio;
    double c3BodyRatio;
    double c3Ratio;
    double c1Body;
    double c2Body;
    double c3Body;
    bool sweep;
    bool rejection;
    bool confirmation;
};

//+------------------------------------------------------------------+
//| Helper: Get Candle Pattern String (OLD -> NEW = c3 c2 c1)        |
//+------------------------------------------------------------------+
string GetCandlePattern()
{
    int c1 = 1, c2 = 2, c3 = 3;

    double o1 = iOpen(_Symbol, PERIOD_M1, c1);
    double c1p = iClose(_Symbol, PERIOD_M1, c1);

    double o2 = iOpen(_Symbol, PERIOD_M1, c2);
    double c2p = iClose(_Symbol, PERIOD_M1, c2);

    double o3 = iOpen(_Symbol, PERIOD_M1, c3);
    double c3p = iClose(_Symbol, PERIOD_M1, c3);

    string p1 = (c1p > o1) ? "G" : (c1p < o1 ? "R" : "D");
    string p2 = (c2p > o2) ? "G" : (c2p < o2 ? "R" : "D");
    string p3 = (c3p > o3) ? "G" : (c3p < o3 ? "R" : "D");

    return p3 + p2 + p1;
}

void LogQuickHandsCheck(const string side,
                        const bool sweep,
                        const bool rejection,
                        const bool confirmation,
                        const double atr,
                        const long spread,
                        const string reason)
{
    LogTyped("CHECK",
             StringFormat("[M1_LSMC] %s check: sweep=%s rejection=%s confirm=%s atr=%.2f spread=%d reason=%s strategy=M1_LSMC",
                          side,
                          (sweep ? "true" : "false"),
                          (rejection ? "true" : "false"),
                          (confirmation ? "true" : "false"),
                          atr,
                          (int)spread,
                          reason));
}

//+------------------------------------------------------------------+
//| Evaluates LSMC continuation patterns on closed candles           |
//+------------------------------------------------------------------+
bool EvaluateQuickHands(int hFast, int hSlow, int hAtr, StrategySignal &sig)
{
    // --- QUICKHANDS FINAL PATCH START ---
    sig.isValid = false;
    sig.reason = "NO_PATTERN";
    sig.mode = "M1_LSMC";
    sig.atr = 0.0;
    sig.rsi = 0.0;
    sig.rsiPrev = 0.0;
    sig.emaFast = 0.0;
    sig.emaFastPrev = 0.0;
    sig.emaSlow = 0.0;
    sig.emaBias = 0.0;
    sig.trendStrength = 0.0;
    sig.spreadRatio = 0.0;
    sig.distance = 0.0;
    sig.spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    sig.pattern = GetCandlePattern();
    sig.structureSL = 0.0;
    sig.slStruct = 0.0;
    sig.slATR = 0.0;
    sig.slFinal = 0.0;
    sig.c1BodyRatio = 0.0;
    sig.c2BodyRatio = 0.0;
    sig.c3BodyRatio = 0.0;
    sig.c1Body = 0.0;
    sig.c2Body = 0.0;
    sig.c3Body = 0.0;
    sig.sweep = false;
    sig.rejection = false;
    sig.confirmation = false;

    double atr = 0.0;
    if(!GetIndicatorValue(hAtr, 1, atr))
        return false;
    sig.atr = atr;

    if(sig.spread > InpMaxSpreadPoints)
    {
        sig.reason = "HIGH_SPREAD";
        LogQuickHandsCheck("SETUP", false, false, false, atr, sig.spread, sig.reason);
        return false;
    }

    double atrSeries[];
    ArraySetAsSeries(atrSeries, true);
    if(CopyBuffer(hAtr, 0, 1, 20, atrSeries) == 20)
    {
        double atrAvg = 0.0;
        for(int i = 0; i < 20; i++)
            atrAvg += atrSeries[i];
        atrAvg /= 20.0;

        if(atr < atrAvg * 0.8)
        {
            sig.reason = "LOW_ATR";
            LogQuickHandsCheck("SETUP", false, false, false, atr, sig.spread, sig.reason);
            return false;
        }
    }

    double ema20c1 = 0.0, ema20c2 = 0.0, ema50c1 = 0.0;
    if(!GetIndicatorValue(hFast, 1, ema20c1)) return false;
    if(!GetIndicatorValue(hFast, 2, ema20c2)) return false;
    if(!GetIndicatorValue(hSlow, 1, ema50c1)) return false;
    sig.emaFast = ema20c1;
    sig.emaFastPrev = ema20c2;
    sig.emaSlow = ema50c1;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M1, 1, 3, rates) < 3)
        return false;

    MqlRates c1 = rates[0];
    MqlRates c2 = rates[1];
    MqlRates c3 = rates[2];

    double c1_body = MathAbs(c1.close - c1.open);
    double c1_range = c1.high - c1.low;
    double c2_body = MathAbs(c2.close - c2.open);
    double c2_range = c2.high - c2.low;
    double c3_body = MathAbs(c3.close - c3.open);
    double c3_range = c3.high - c3.low;

    sig.c1Body = c1_body;
    sig.c2Body = c2_body;
    sig.c3Body = c3_body;
    sig.c1BodyRatio = (c1_range > 0.0) ? (c1_body / c1_range) : 0.0;
    sig.c2BodyRatio = (c2_range > 0.0) ? (c2_body / c2_range) : 0.0;
    sig.c3BodyRatio = (c3_range > 0.0) ? (c3_body / c3_range) : 0.0;

    bool c1Bull = (c1.close > c1.open);
    bool c1Bear = (c1.close < c1.open);
    bool c2Bull = (c2.close > c2.open);
    bool c2Bear = (c2.close < c2.open);
    bool c3Bull = (c3.close > c3.open);
    bool c3Bear = (c3.close < c3.open);

    bool buyPattern = (c3Bear && c2Bear && c1Bull);
    bool sellPattern = (c3Bull && c2Bull && c1Bear);

    if(!buyPattern && !sellPattern)
    {
        sig.reason = "PATTERN_FAIL";
        LogQuickHandsCheck("SETUP", false, false, false, atr, sig.spread, sig.reason);
        return false;
    }

    if(buyPattern)
    {
        sig.type = POSITION_TYPE_BUY;
        sig.pattern = "RRG";
        sig.sweep = (c2.low < c3.low);
        sig.rejection = (c2_range > 0.0) && ((MathMin(c2.open, c2.close) - c2.low) > (0.5 * c2_range));
        sig.confirmation = c1Bull && (c1_range > 0.0) && (c1_body >= 0.6 * c1_range);

        if(c1_range <= 0.0 || sig.c1BodyRatio < 0.5)
        {
            sig.reason = "WEAK_C1_BODY";
            LogQuickHandsCheck("BUY", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
            return false;
        }

        if(c2_range <= 0.0 || c3_range <= 0.0 || (sig.c2BodyRatio < 0.4 && sig.c3BodyRatio < 0.4))
        {
            sig.reason = "WEAK_CONTEXT_BODY";
            LogQuickHandsCheck("BUY", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
            return false;
        }

        if(c1.close <= ema50c1)
        {
            sig.reason = "EMA_BIAS_FAIL";
            LogQuickHandsCheck("BUY", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
            return false;
        }

        if(!sig.sweep)
        {
            sig.reason = "NO_LIQUIDITY_SWEEP";
            LogQuickHandsCheck("BUY", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
            return false;
        }

        if(!sig.rejection)
        {
            sig.reason = "WEAK_REJECTION";
            LogQuickHandsCheck("BUY", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
            return false;
        }

        if(!sig.confirmation)
        {
            sig.reason = "WEAK_CONFIRMATION";
            LogQuickHandsCheck("BUY", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
            return false;
        }

        if(c1.high <= c2.high)
        {
            sig.reason = "NO_STRUCTURE_BREAK";
            LogQuickHandsCheck("BUY", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
            return false;
        }

        if(InpUseMicroTrendFilter && c1.low <= c2.low)
        {
            sig.reason = "MICRO_TREND_FAIL";
            LogQuickHandsCheck("BUY", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
            return false;
        }

        sig.isValid = true;
        sig.reason = "VALID";
        LogQuickHandsCheck("BUY", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
        LogTyped("SIGNAL", "[M1_LSMC] BUY confirmed");

        double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sig.structureSL = MathMin(c1.low, c2.low);
        sig.slStruct = entry - sig.structureSL;
        sig.slATR = atr;
        sig.slFinal = sig.slStruct;
        return true;
    }

    sig.type = POSITION_TYPE_SELL;
    sig.pattern = "GGR";
    sig.sweep = (c2.high > c3.high);
    sig.rejection = (c2_range > 0.0) && ((c2.high - MathMax(c2.open, c2.close)) > (0.5 * c2_range));
    sig.confirmation = c1Bear && (c1_range > 0.0) && (c1_body >= 0.6 * c1_range);

    if(c1_range <= 0.0 || sig.c1BodyRatio < 0.5)
    {
        sig.reason = "WEAK_C1_BODY";
        LogQuickHandsCheck("SELL", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
        return false;
    }

    if(c2_range <= 0.0 || c3_range <= 0.0 || (sig.c2BodyRatio < 0.4 && sig.c3BodyRatio < 0.4))
    {
        sig.reason = "WEAK_CONTEXT_BODY";
        LogQuickHandsCheck("SELL", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
        return false;
    }

    if(c1.close >= ema50c1)
    {
        sig.reason = "EMA_BIAS_FAIL";
        LogQuickHandsCheck("SELL", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
        return false;
    }

    if(!sig.sweep)
    {
        sig.reason = "NO_LIQUIDITY_SWEEP";
        LogQuickHandsCheck("SELL", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
        return false;
    }

    if(!sig.rejection)
    {
        sig.reason = "WEAK_REJECTION";
        LogQuickHandsCheck("SELL", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
        return false;
    }

    if(!sig.confirmation)
    {
        sig.reason = "WEAK_CONFIRMATION";
        LogQuickHandsCheck("SELL", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
        return false;
    }

    if(c1.low >= c2.low)
    {
        sig.reason = "NO_STRUCTURE_BREAK";
        LogQuickHandsCheck("SELL", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
        return false;
    }

    if(InpUseMicroTrendFilter && c1.high >= c2.high)
    {
        sig.reason = "MICRO_TREND_FAIL";
        LogQuickHandsCheck("SELL", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
        return false;
    }

    sig.isValid = true;
    sig.reason = "VALID";
    LogQuickHandsCheck("SELL", sig.sweep, sig.rejection, sig.confirmation, atr, sig.spread, sig.reason);
    LogTyped("SIGNAL", "[M1_LSMC] SELL confirmed");

    double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    sig.structureSL = MathMax(c1.high, c2.high);
    sig.slStruct = sig.structureSL - entry;
    sig.slATR = atr;
    sig.slFinal = sig.slStruct;
    return true;
    // --- QUICKHANDS FINAL PATCH END ---
}

#endif // XAUUSD_M1_QUICKHANDS_ENTRY_MQH
