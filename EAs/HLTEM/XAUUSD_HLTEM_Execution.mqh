#ifndef XAUUSD_HLTEM_EXECUTION_MQH
#define XAUUSD_HLTEM_EXECUTION_MQH

#include <Trade/Trade.mqh>
#include "XAUUSD_HLTEM_HTF.mqh"
#include "XAUUSD_HLTEM_LTF.mqh"
#include "XAUUSD_HLTEM_Logging.mqh"
#include "../Include/GoldEA_Limit_Execution.mqh"

//+------------------------------------------------------------------+
//| ExecuteHLTEM - HLTEM Execution Handler                           |
//+------------------------------------------------------------------+
bool ExecuteHLTEM(HTFContext &htf, LTFContext &ltf)
{
    if(PositionsTotal() > 0 || HasPendingOrder() || HasAnyPendingOrders())
        return false;

    MqlRates signalBar[];
    ArraySetAsSeries(signalBar, true);
    if(CopyRates(_Symbol, PERIOD_M1, 1, 1, signalBar) != 1)
        return false;

    double entry = (htf.bias == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl, tp;
    double riskDistance;

    if(htf.bias == (int)ORDER_TYPE_BUY)
    {
       sl = ltf.fvgLow - 50 * _Point;
       riskDistance = entry - sl;
       tp = entry + (riskDistance * 2.5);
    }
    else
    {
       sl = ltf.fvgHigh + 50 * _Point;
       riskDistance = sl - entry;
       tp = entry - (riskDistance * 2.5);
    }

    ulong tradeId = NextTradeId();
    string comment = StringFormat("HLTEM#%I64u", tradeId);
    bool isBuy = (htf.bias == (int)ORDER_TYPE_BUY);
    double rawEntry = CalculateLimitPrice(isBuy, signalBar[0].close, signalBar[0].high, signalBar[0].low);
    double limitEntry = NormalizeEntryPrice(rawEntry, isBuy);
    double slDistance = MathAbs(entry - sl);
    double tpDistance = MathAbs(tp - entry);
    double limitSl = RecalculateSL(isBuy, limitEntry, slDistance);
    double limitTp = isBuy ? (limitEntry + tpDistance) : (limitEntry - tpDistance);
    limitSl = NormalizeDouble(limitSl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    limitTp = NormalizeDouble(limitTp, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    if(limitEntry <= 0.0 || !MathIsValidNumber(limitEntry))
    {
       PrintFormat("[GoldEA][REJECTION] INVALID_ENTRY price=%.5f", limitEntry);
       return false;
    }

    ulong orderTicket = PlaceLimitOrder("HLTEM",
                                        isBuy,
                                        limitEntry,
                                        limitSl,
                                        limitTp,
                                        0.01,
                                        Bars(_Symbol, PERIOD_M1),
                                        tradeId,
                                        comment,
                                        slDistance,
                                        0);

    if(orderTicket > 0)
    {
       datetime barTime = iTime(_Symbol, PERIOD_M1, 1);
       LogTyped("ORDER", StringFormat("[HLTEM] LIMIT_PLACED tradeId=%I64u barTime=%s side=%s entry=%.2f sl=%.2f tp=%.2f",
                tradeId, TimeToString(barTime), (isBuy ? "BUY" : "SELL"), limitEntry, limitSl, limitTp));
       return true;
    }
    else
    {
       LogTyped("REJECTION", StringFormat("[HLTEM] ORDER_FAILED"));
    }

    return false;
}

#endif // XAUUSD_HLTEM_EXECUTION_MQH
