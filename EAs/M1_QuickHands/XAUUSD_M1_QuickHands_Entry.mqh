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
    double atr;
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
};

//+------------------------------------------------------------------+
//| Evaluates GG-R (BUY) or RR-G (SELL) Trend Patterns               |
//+------------------------------------------------------------------+
bool EvaluateQuickHands(int hFast, int hSlow, int hAtr, StrategySignal &sig)
{
    sig.isValid = false;
    sig.reason = "NO_PATTERN";
    sig.atr = 0;
    sig.spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

    // 1. Hard Filter: Spread
    if(sig.spread > InpMaxSpreadPoints)
    {
        sig.reason = "HIGH_SPREAD";
        return false;
    }

    // 2. Hard Filter: ATR (Dynamic Volatility)
    double atr;
    if(!GetIndicatorValue(hAtr, 1, atr)) return false;
    sig.atr = atr;
    if(atr < InpMinAtrPoints * _Point)
    {
        sig.reason = "LOW_ATR_DYNAMIC";
        return false;
    }

    // 3. Trend Check (EMA Fast vs Slow)
    double fast, slow;
    if(!GetIndicatorValue(hFast, 1, fast)) return false;
    if(!GetIndicatorValue(hSlow, 1, slow)) return false;

    bool isTrendUp = (fast > slow);
    bool isTrendDown = (fast < slow);

    if(!isTrendUp && !isTrendDown)
    {
        sig.reason = "WEAK_TREND";
        return false;
    }

    // 4. Candle Quality Filter (Body >= 50%)
    // Candle index: 0=Live(forming), 1=Red(last closed), 2=Green, 3=Green
    // Shift:         0            1                  2            3
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M1, 1, 3, rates) < 3) return false;

    // Calculate Ratios
    double ratios[3];
    bool weakCandle = false;
    for(int i = 0; i < 3; i++)
    {
        double body = MathAbs(rates[i].open - rates[i].close);
        double range = rates[i].high - rates[i].low;
        ratios[i] = (range > 0) ? (body / range) : 0;
        if(ratios[i] < 0.5) weakCandle = true;
    }

    sig.c1BodyRatio = ratios[0];
    sig.c2BodyRatio = ratios[1];
    sig.c3BodyRatio = ratios[2];

    if(weakCandle)
    {
        sig.reason = "WEAK_CANDLE_BODY";
        // We still check if a pattern *would* have existed for logging purposes if needed, 
        // but the prompt says return false here.
    }

    // 5. Pattern Recognition (GG-R / RR-G)
    // Candle types
    bool c1Green = (rates[0].close > rates[0].open);
    bool c1Red   = (rates[0].close < rates[0].open);
    bool c2Green = (rates[1].close > rates[1].open);
    bool c2Red   = (rates[1].close < rates[1].open);
    bool c3Green = (rates[2].close > rates[2].open);
    bool c3Red   = (rates[2].close < rates[2].open);

    // Handle Pattern Side Assignment for Rejection Logging
    if(c3Green && c2Green && c1Red) sig.type = POSITION_TYPE_BUY;
    else if(c3Red && c2Red && c1Green) sig.type = POSITION_TYPE_SELL;

    // 6. Overextension Filter
    sig.c1Body = MathAbs(rates[0].open - rates[0].close);
    sig.c2Body = MathAbs(rates[1].open - rates[1].close);
    sig.c3Body = MathAbs(rates[2].open - rates[2].close);
    double combinedBody = sig.c1Body + sig.c2Body;

    if (combinedBody == 0)
    {
        sig.reason = "C3_OVEREXTENDED";
        return false;
    }

    sig.c3Ratio = sig.c3Body / combinedBody;

    if (sig.c3Ratio > 0.6)
    {
        sig.reason = "C3_OVEREXTENDED";
        return false;
    }

    if(weakCandle) return false;

    // BUY: GG-R (Green, Green, Red) + Trend Up
    // rates[2]=C3, rates[1]=C2, rates[0]=C1
    if(isTrendUp && sig.type == POSITION_TYPE_BUY)
    {
        // 🔥 NEW EMA CONDITION: If origin C3 was below EMA, confirm C1 is above
        if(rates[2].close < fast && rates[0].close <= fast)
        {
            sig.reason = "EMA_CONF_FAIL";
            return false;
        }

        sig.pattern = "GG-R";
        sig.isValid = true;
        sig.reason = "VALID";

        double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        // Anti-stophunt: Min of Candle 2 and 3 lows
        sig.structureSL = MathMin(rates[1].low, rates[2].low);
        sig.slStruct = entry - sig.structureSL;
        
        sig.slATR = atr * 0.8;
        
        // Hybrid calculation
        sig.slFinal = MathMin(sig.slStruct, sig.slATR * 1.5);
        
        // Safety Clamps (ENTRY ONLY)
        sig.slFinal = MathMax(sig.slFinal, 4.0);
        sig.slFinal = MathMin(sig.slFinal, 6.0);
        
        return true;
    }

    // SELL: RR-G (Red, Red, Green) + Trend Down
    if(isTrendDown && sig.type == POSITION_TYPE_SELL)
    {
        // 🔥 NEW EMA CONDITION: If origin C3 was above EMA, confirm C1 is below
        if(rates[2].close > fast && rates[0].close >= fast)
        {
            sig.reason = "EMA_CONF_FAIL";
            return false;
        }

        sig.pattern = "RR-G";
        sig.isValid = true;
        sig.reason = "VALID";

        double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        // Anti-stophunt: Max of Candle 2 and 3 highs
        sig.structureSL = MathMax(rates[1].high, rates[2].high);
        sig.slStruct = sig.structureSL - entry;
        
        sig.slATR = atr * 0.8;

        // Hybrid calculation
        sig.slFinal = MathMin(sig.slStruct, sig.slATR * 1.5);

        // Safety Clamps (ENTRY ONLY)
        sig.slFinal = MathMax(sig.slFinal, 4.0);
        sig.slFinal = MathMin(sig.slFinal, 6.0);

        return true;
    }

    return false;
}

#endif // XAUUSD_M1_QUICKHANDS_ENTRY_MQH
