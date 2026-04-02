#ifndef XAUUSD_HLTEM_EXECUTION_MQH
#define XAUUSD_HLTEM_EXECUTION_MQH

#include <Trade/Trade.mqh>
#include "XAUUSD_HLTEM_HTF.mqh"
#include "XAUUSD_HLTEM_LTF.mqh"
#include "XAUUSD_HLTEM_Logging.mqh"

//+------------------------------------------------------------------+
//| ExecuteHLTEM - HLTEM Execution Handler                           |
//+------------------------------------------------------------------+
bool ExecuteHLTEM(HTFContext &htf, LTFContext &ltf)
{
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

    CTrade trade;
    trade.SetExpertMagicNumber(260320); // Unique for HLTEM
    
    ulong tradeId = NextTradeId();
    string comment = StringFormat("HLTEM#%I64u", tradeId);

    bool result = false;
    if(htf.bias == (int)ORDER_TYPE_BUY)
       result = trade.Buy(0.01, _Symbol, 0.0, sl, tp, comment);
    else
       result = trade.Sell(0.01, _Symbol, 0.0, sl, tp, comment);

    if(result)
    {
       datetime barTime = iTime(_Symbol, PERIOD_M1, 1);
       LogTyped("EXECUTION", StringFormat("[HLTEM] TRADE_PLACED tradeId=%I64u barTime=%s side=%s entry=%.2f sl=%.2f tp=%.2f",
                tradeId, TimeToString(barTime), (htf.bias == ORDER_TYPE_BUY ? "BUY" : "SELL"), entry, sl, tp));
       
       // Handle context mapping for analyze_ea_logs.py
       TradeContext *tCtx = new TradeContext("HLTEM", (htf.bias == ORDER_TYPE_BUY ? "BUY" : "SELL"), "M5"); // Using [M5] for analyzer parity
       g_tradeContextMap.Add(tradeId, tCtx);
    }
    else
    {
       LogTyped("REJECTION", StringFormat("[HLTEM] ORDER_FAILED code=%d", trade.ResultRetcode()));
    }

    return result;
}

#endif // XAUUSD_HLTEM_EXECUTION_MQH
