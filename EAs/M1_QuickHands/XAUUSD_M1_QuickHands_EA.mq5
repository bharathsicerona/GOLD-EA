//+------------------------------------------------------------------+
//|                                     XAUUSD_M1_QuickHands_EA.mq5 |
//|                                  Copyright 2026, GoldEA project |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, GoldEA project"
#property link        "https://github.com/GoldEA"
#property version     "1.00"
#property strict

#define EA_TYPE "M1_QUICKHANDS"

#include "XAUUSD_M1_QuickHands_Inputs.mqh"
#include "XAUUSD_M1_QuickHands_Logging.mqh"
#include "XAUUSD_M1_QuickHands_Entry.mqh"
#include "XAUUSD_M1_QuickHands_Management.mqh"
#include "../Include/GoldEA_Common_Core.mqh"
#include "../Include/GoldEA_Unified_Risk.mqh"

//+------------------------------------------------------------------+
//| --- Global Variables ---                                         |
//+------------------------------------------------------------------+
int      g_hFast, g_hSlow, g_hAtr;
CTrade   g_trade;
datetime g_lastBarCheck = 0;
ulong    g_activeTicket = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    g_hFast = iMA(_Symbol, PERIOD_M1, InpEmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_hSlow = iMA(_Symbol, PERIOD_M1, InpEmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_hAtr  = iATR(_Symbol, PERIOD_M1, InpAtrPeriod);

    if(g_hFast == INVALID_HANDLE || g_hSlow == INVALID_HANDLE || g_hAtr == INVALID_HANDLE)
    {
        Print("FAILED: Indicator Initialization");
        return INIT_FAILED;
    }

    g_trade.SetExpertMagicNumber(InpMagicNumber);
    PrintFormat("[%s][GoldEA] Initialized. Magic=%d", EA_TYPE, InpMagicNumber);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CleanupDashboard();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 1. Manage Active Position (Trailing)
    CheckActivePosition();
    if(g_activeTicket != 0)
    {
        ManageQuickHandsTrailing(g_activeTicket);
    }

    // 2. Bar Close Logic (Entry Only)
    // 🔥 GLOBAL RULE: ONLY ENTER AFTER CANDLE CLOSE
    datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
    if(currentBarTime != g_lastBarCheck)
    {
        g_lastBarCheck = currentBarTime;
        
        // Skip check if already in position
        if(g_activeTicket != 0) return;

        StrategySignal sig;
        if(EvaluateQuickHands(g_hFast, g_hSlow, g_hAtr, sig))
        {
            ExecuteQuickHandsTrade(sig);
        }
        else if(sig.reason != "NO_PATTERN")
        {
            // Log rejection if filter failed on a potential bar
            string sideStr = (sig.type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            datetime barTime = iTime(_Symbol, PERIOD_M1, 1);
            
            if(sig.reason == "WEAK_CANDLE_BODY")
            {
                LogTyped("REJECTION", StringFormat("[%s] %s rejected: barTime=%s reason=WEAK_CANDLE_BODY c1=%.2f c2=%.2f c3=%.2f", 
                    EA_TYPE, sideStr, TimeToString(barTime), sig.c1BodyRatio, sig.c2BodyRatio, sig.c3BodyRatio));
            }
            else if(sig.reason == "C3_OVEREXTENDED")
            {
                LogTyped("REJECTION", StringFormat("[%s] %s rejected: barTime=%s reason=C3_OVEREXTENDED ratio=%.2f c3=%.2f c2=%.2f c1=%.2f", 
                    EA_TYPE, sideStr, TimeToString(barTime), sig.c3Ratio, sig.c3Body, sig.c2Body, sig.c1Body));
            }
            else
            {
                LogTyped("REJECTION", StringFormat("[%s] %s skip: barTime=%s atr=%.2f spread=%d reason=%s pattern=%s", 
                    EA_TYPE, sideStr, TimeToString(barTime), sig.atr, sig.spread, sig.reason, sig.pattern));
            }
        }
    }

    // 3. Update Dashboard
    UpdateDashboardStats();
}

//+------------------------------------------------------------------+
//| Expert trade transaction callback                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, 
                        const MqlTradeRequest& req, 
                        const MqlTradeResult& res)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        ulong ticket = trans.position;
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                // Position CLOSED
                if(PositionGetInteger(POSITION_REASON) != POSITION_REASON_EXPERT) 
                {
                    // Fallback closed detection logic
                }
            }
        }
    }
    
    // Quick sync of active ticket
    CheckActivePosition();
}

//+------------------------------------------------------------------+
//| Helper: Sync active ticket                                      |
//+------------------------------------------------------------------+
void CheckActivePosition()
{
    g_activeTicket = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong t = PositionGetTicket(i);
        if(PositionSelectByTicket(t))
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                g_activeTicket = t;
                return;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Helper: Execute Trade Logic                                      |
//+------------------------------------------------------------------+
void ExecuteQuickHandsTrade(StrategySignal &sig)
{
    double lot = InpLotSize;
    double openPrice = (sig.type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double R = sig.slFinal; // R is the initial SL distance
    double sl = (sig.type == POSITION_TYPE_BUY) ? (openPrice - R) : (openPrice + R);
    sl = NormalizeDouble(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

    // TP = 3:1 RR based on R
    double tp = (sig.type == POSITION_TYPE_BUY) ? (openPrice + (R * 3.0)) : (openPrice - (R * 3.0));
    tp = NormalizeDouble(tp, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

    string sideStr = (sig.type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
    datetime barTime = iTime(_Symbol, PERIOD_M1, 1);
    
    LogTyped("CHECK", StringFormat("[%s] %s check: barTime=%s structureSL=%.2f atr=%.2f reason=VALID pattern=%s", 
        EA_TYPE, sideStr, TimeToString(barTime), sig.structureSL, sig.atr, sig.pattern));

    ENUM_ORDER_TYPE orderType = (sig.type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    if(g_trade.PositionOpen(_Symbol, orderType, lot, openPrice, sl, tp, "QuickHands M1"))
    {
        ulong ticket = g_trade.ResultOrder();
        if(ticket == 0) ticket = g_trade.ResultDeal();
        
        LogTyped("EXECUTION", StringFormat("[%s] %s executed: tradeId=%I64u barTime=%s entry=%.2f sl=%.2f tp=%.2f R=%.2f RR=3", 
            EA_TYPE, sideStr, ticket, TimeToString(barTime), openPrice, sl, tp, R));

        TradeContext *ctx = new TradeContext;
        ctx.strategy = EA_TYPE;
        ctx.eaType = EA_TYPE;
        ctx.side = sideStr;
        g_tradeContextMap.Add(ticket, ctx);
        
        g_activeTicket = ticket;
    }
}

//+------------------------------------------------------------------+
//| Dashboard Update                                                 |
//+------------------------------------------------------------------+
void UpdateDashboardStats()
{
    if(!InpEnableDashboard) return;

    DashboardState s;
    s.mode = "ACTIVE"; 
    s.session = CurrentSessionText();
    s.spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    
    double atr = 0;
    GetIndicatorValue(g_hAtr, 1, atr);
    s.atr = atr;

    // Trend & Pattern State
    StrategySignal sig;
    EvaluateQuickHands(g_hFast, g_hSlow, g_hAtr, sig);
    
    double fast, slow;
    GetIndicatorValue(g_hFast, 1, fast);
    GetIndicatorValue(g_hSlow, 1, slow);
    s.trend = (fast > slow) ? "UP" : (fast < slow) ? "DOWN" : "NONE";
    
    s.pattern = sig.isValid ? sig.pattern : "NONE";
    
    // Candle colors (simplified fetch)
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M1, 1, 3, rates) == 3)
    {
        s.c1 = (rates[0].close > rates[0].open) ? "G" : "R";
        s.c2 = (rates[1].close > rates[1].open) ? "G" : "R";
        s.c3 = (rates[2].close > rates[2].open) ? "G" : "R";
    }

    s.slStruct = sig.slStruct;
    s.slATR = sig.slATR;
    s.slFinal = sig.slFinal;

    s.atrPass = (atr >= InpMinAtrPoints * _Point) ? "PASS" : "FAIL";
    s.trendPass = (s.trend != "NONE") ? "PASS" : "FAIL";
    s.spreadPass = (s.spread <= InpMaxSpreadPoints) ? "PASS" : "FAIL";
    s.qualityPass = (sig.reason != "WEAK_CANDLE_BODY") ? "PASS" : "FAIL";
    s.c3Overextended = (sig.reason != "C3_OVEREXTENDED") ? "PASS" : "FAIL";

    if(g_activeTicket != 0 && PositionSelectByTicket(g_activeTicket))
    {
        s.tradeStatus = "OPEN";
        s.profit = PositionGetDouble(POSITION_PROFIT);
        s.id = g_activeTicket;
        s.entry = PositionGetDouble(POSITION_PRICE_OPEN);
        s.sl = PositionGetDouble(POSITION_SL);
        s.tp = PositionGetDouble(POSITION_TP);
        
        double R = MathAbs(s.entry - s.sl);
        // Note: Initial SL distance is R. If we moved it to BE+R, distance is still R.
        // Let's use a simpler way to detect "Locked"
        bool isLocked = false;
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && s.sl > s.entry) isLocked = true;
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && s.sl < s.entry) isLocked = true;
        
        s.locked = isLocked ? R : 0;
    }
    else
    {
        s.tradeStatus = "SCANNING";
        s.profit = 0; s.locked = 0; s.id = 0;
        s.entry = 0; s.sl = 0; s.tp = 0;
    }

    UpdateDashboard(s);
    
    // R and Lock Stats
    if(g_activeTicket != 0)
    {
        double R_val = MathAbs(s.entry - s.sl);
        string lockStatus = (s.locked > 0) ? "ACTIVE" : "SCANNING";
        color lockColor = (s.locked > 0) ? clrLime : clrYellow;
        SetDashboardLabelLine(EA_TYPE, "R_VAL", StringFormat("R: %.2f | TP: %.2f | SL Lock: %s", R_val, MathAbs(s.entry - s.tp), lockStatus), lockColor, 16);
    }
}
