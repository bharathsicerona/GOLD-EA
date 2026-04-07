#property copyright "GoldEA 2026"
#property link      "https://github.com/bharathsicerona"
#property version   "1.00"
#property strict

#include "XAUUSD_HLTEM_Inputs.mqh"
#include "XAUUSD_HLTEM_HTF.mqh"
#include "XAUUSD_HLTEM_LTF.mqh"
#include "XAUUSD_HLTEM_Execution.mqh"
#include "XAUUSD_HLTEM_Logging.mqh"
#include "XAUUSD_HLTEM_Debug.mqh"

// Global Contexts
HTFContext g_htf;
datetime   g_lastM1Bar = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    LogTyped("INIT", "HLTEM Model Initialized (M15 Context -> M1 Execution)");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CleanupDebugObjects();
    LogTyped("DEINIT", StringFormat("HLTEM Model Stopped: Reason_%d", reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    ManagePendingExpiry(Bars(_Symbol, PERIOD_M1));

    // 1. Process New Bar only for heavy checks
    datetime timeM1 = iTime(_Symbol, PERIOD_M1, 0);
    if(timeM1 == g_lastM1Bar) return;
    g_lastM1Bar = timeM1;

    // 2. Update HTF Context (M15)
    // Runs on M1 bar close to check if HTF bias is ready
    if(!UpdateHTFContext(g_htf))
    {
        // Don't log rejection here as it's a polling state
        return;
    }

    // 3. Evaluate LTF Entry (M1)
    LTFContext ltf;
    EvaluateLTF(ltf, g_htf);
    
    datetime barTime = iTime(_Symbol, PERIOD_M1, 1);
    LogTyped("CHECK", StringFormat("[HLTEM] Signal check: barTime=%s mss=%d impulse=%d fvg=%d", 
             TimeToString(barTime), ltf.mss, ltf.impulse, ltf.fvg));

    // 4. Debug Visualization (Always Draw for monitoring)
    DrawHTF_OB(g_htf.obLow, g_htf.obHigh);
    DrawMSS(ltf.recentHigh, ltf.recentLow);
    if(ltf.fvg) DrawFVG(ltf.fvgLow, ltf.fvgHigh);

    LogTyped("DEBUG", StringFormat("[HLTEM] barTime=%s OB=%.2f-%.2f MSS_H=%.2f MSS_L=%.2f",
             TimeToString(barTime), g_htf.obLow, g_htf.obHigh, ltf.recentHigh, ltf.recentLow));

    if(!ltf.mss || !ltf.impulse || !ltf.fvg) return;

    // 5. Execution Pipeline
    if(ExecuteHLTEM(g_htf, ltf))
    {
        // Reset HTF context after successful execution so we don't repeat the trade
        // until a new HTF setup occurs. 
        g_htf.valid = false;
    }
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal <= 0)
        return;

    if(!HistoryDealSelect(trans.deal))
        return;

    ENUM_DEAL_ENTRY entryType = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
    if(entryType != DEAL_ENTRY_IN)
        return;

    ulong orderId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_ORDER);
    double dealPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
    string side = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? "BUY" : "SELL";
    PendingOrderInfo fillInfo = g_pendingOrder;
    HandleOrderFilled(orderId);

    TradeContext *tCtx = new TradeContext("HLTEM", side, "M5");
    g_tradeContextMap.Add(fillInfo.logicalTradeId, tCtx);

    LogTyped("EXECUTION", StringFormat("[HLTEM] TRADE_FILLED tradeId=%I64u side=%s entry=%.2f sl=%.2f tp=%.2f",
             fillInfo.logicalTradeId, side, dealPrice, fillInfo.sl, fillInfo.tp));
}
