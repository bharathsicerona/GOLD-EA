#ifndef XAUUSD_HLTEM_HTF_MQH
#define XAUUSD_HLTEM_HTF_MQH

#include "XAUUSD_HLTEM_Logging.mqh"

// HTF Context (M15)
struct HTFContext
{
   bool valid;
   int bias; // ORDER_TYPE_BUY / SELL
   double obHigh;
   double obLow;
   datetime lastUpdate;
};

//+------------------------------------------------------------------+
//| UpdateHTFContext - HTF Liquidity Sweep & BOS (M15)               |
//+------------------------------------------------------------------+
bool UpdateHTFContext(HTFContext &ctx)
{
    ctx.valid = false;

    // 1. Liquidity Sweep (Lookback last 20 candles, skip Candle[0] and Candle[1])
    // Search last 20 candles starting from index 2
    int highIdx = iHighest(_Symbol, PERIOD_M15, MODE_HIGH, 20, 2);
    int lowIdx  = iLowest(_Symbol, PERIOD_M15, MODE_LOW, 20, 2);
    
    double prevHigh = iHigh(_Symbol, PERIOD_M15, highIdx);
    double prevLow  = iLow(_Symbol, PERIOD_M15, lowIdx);

    // Candle[1] (HTF Close)
    double high1  = iHigh(_Symbol, PERIOD_M15, 1);
    double low1   = iLow(_Symbol, PERIOD_M15, 1);
    double close1 = iClose(_Symbol, PERIOD_M15, 1);

    bool bullishSweep = (high1 > prevHigh) && (close1 < prevHigh);
    bool bearishSweep = (low1 < prevLow) && (close1 > prevLow);

    // 2. BOS (Break of Structure)
    // Check break of Candle[2] swing points
    double swingHigh = iHigh(_Symbol, PERIOD_M15, 2);
    double swingLow  = iLow(_Symbol, PERIOD_M15, 2);

    bool bullishBOS = (close1 > swingHigh);
    bool bearishBOS = (close1 < swingLow);

    // 3. Direction Mapping
    if(bearishSweep && bullishBOS)
    {
       ctx.bias = ORDER_TYPE_BUY;
    }
    else if(bullishSweep && bearishBOS)
    {
       ctx.bias = ORDER_TYPE_SELL;
    }
    else
    {
       return false;
    }

    // 4. Order Block (Last opposite candle in the move)
    for(int i = 3; i < 10; i++)
    {
        double open  = iOpen(_Symbol, PERIOD_M15, i);
        double close = iClose(_Symbol, PERIOD_M15, i);

        if(ctx.bias == ORDER_TYPE_BUY && close < open)
        {
            ctx.obHigh = iHigh(_Symbol, PERIOD_M15, i);
            ctx.obLow  = iLow(_Symbol, PERIOD_M15, i);
            break;
        }

        if(ctx.bias == ORDER_TYPE_SELL && close > open)
        {
            ctx.obHigh = iHigh(_Symbol, PERIOD_M15, i);
            ctx.obLow  = iLow(_Symbol, PERIOD_M15, i);
            break;
        }
    }

    ctx.valid = true;
    ctx.lastUpdate = iTime(_Symbol, PERIOD_M15, 1);
    
    LogTyped("CHECK", StringFormat("[HLTEM] HTF_VALID bias=%s OB_Zone=%.2f-%.2f", 
             (ctx.bias == ORDER_TYPE_BUY ? "BUY" : "SELL"), ctx.obLow, ctx.obHigh));
    
    return true;
}

#endif // XAUUSD_HLTEM_HTF_MQH
