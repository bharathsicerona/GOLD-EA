#ifndef XAUUSD_HLTEM_LTF_MQH
#define XAUUSD_HLTEM_LTF_MQH

#include "XAUUSD_HLTEM_HTF.mqh"
#include "XAUUSD_HLTEM_Logging.mqh"

// LTF Context (M1)
struct LTFContext
{
   bool mss;
   bool impulse;
   bool fvg;
   double fvgHigh;
   double fvgLow;
   double recentHigh;
   double recentLow;
};

// --- Swing-based MSS Helpers ---
double GetRecentHigh(int bars)
{
   return iHigh(_Symbol, PERIOD_M1, iHighest(_Symbol, PERIOD_M1, MODE_HIGH, bars, 2));
}

double GetRecentLow(int bars)
{
   return iLow(_Symbol, PERIOD_M1, iLowest(_Symbol, PERIOD_M1, MODE_LOW, bars, 2));
}

//+------------------------------------------------------------------+
//| EvaluateLTF - Execution validation (M1)                          |
//+------------------------------------------------------------------+
bool EvaluateLTF(LTFContext &ltf, HTFContext &htf)
{
    if(!htf.valid) return false;

    // 1. OB Zone Check
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(price < htf.obLow || price > htf.obHigh)
    {
       // Not in zone, but keep monitoring HTF
       return false;
    }

    // 2. MSS (Market Structure Shift) M1 - SWING BASED
    ltf.recentHigh = GetRecentHigh(5);
    ltf.recentLow  = GetRecentLow(5);
    double close1  = iClose(_Symbol, PERIOD_M1, 1);

    ltf.mss = false;

    if(htf.bias == (int)ORDER_TYPE_BUY  && close1 > ltf.recentHigh)
    {
       ltf.mss = true;
       LogTyped("DEBUG", StringFormat("[HLTEM] MSS_BULLISH break=%.2f close=%.2f", ltf.recentHigh, close1));
    }
    else if(htf.bias == (int)ORDER_TYPE_SELL && close1 < ltf.recentLow)
    {
       ltf.mss = true;
       LogTyped("DEBUG", StringFormat("[HLTEM] MSS_BEARISH break=%.2f close=%.2f", ltf.recentLow, close1));
    }

    if(!ltf.mss)
    {
       LogTyped("REJECTION", "[HLTEM] NO_MSS");
       return false;
    }

    // 3. Impulse (Strong Candle)
    double open1 = iOpen(_Symbol, PERIOD_M1, 1);
    double body  = MathAbs(close1 - open1);
    
    // Fetch ATR(14) on M1, Candle[1]
    double atrArr[];
    ArraySetAsSeries(atrArr, true);
    int atrHandle = iATR(_Symbol, PERIOD_M1, 14);
    if(CopyBuffer(atrHandle, 0, 1, 1, atrArr) != 1) return false;
    double atr = atrArr[0];
    IndicatorRelease(atrHandle);

    ltf.impulse = body > atr * 1.2;

    if(!ltf.impulse)
    {
       LogTyped("REJECTION", "[HLTEM] NO_IMPULSE");
       return false;
    }

    // 4. FVG (Fair Value Gap) 3-Candle M1
    double c1_high = iHigh(_Symbol, PERIOD_M1, 3);
    double c1_low  = iLow(_Symbol, PERIOD_M1, 3);
    double c3_high = iHigh(_Symbol, PERIOD_M1, 1);
    double c3_low  = iLow(_Symbol, PERIOD_M1, 1);

    bool bullishFVG = (c3_low > c1_high);
    bool bearishFVG = (c3_high < c1_low);

    if(!(bullishFVG || bearishFVG))
    {
       LogTyped("REJECTION", "[HLTEM] NO_FVG");
       return false;
    }

    ltf.fvg = true;
    if(bullishFVG)
    {
       ltf.fvgHigh = c3_low;
       ltf.fvgLow  = c1_high;
    }
    else
    {
       ltf.fvgHigh = c1_low;
       ltf.fvgLow  = c3_high;
    }

    // 5. RELAXED FVG TOUCH RULE (For Testing)
    double low   = iLow(_Symbol, PERIOD_M1, 1);
    double high  = iHigh(_Symbol, PERIOD_M1, 1);
    double close = iClose(_Symbol, PERIOD_M1, 1);

    bool touch = (low <= ltf.fvgHigh && high >= ltf.fvgLow);
    bool closeInside = (close >= ltf.fvgLow && close <= ltf.fvgHigh);

    if(!(touch || closeInside))
    {
       LogTyped("REJECTION", "[HLTEM] NO_FVG_TOUCH");
       return false;
    }

    return true;
}

#endif // XAUUSD_HLTEM_LTF_MQH
