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
#include "../Include/GoldEA_Limit_Execution.mqh"

//+------------------------------------------------------------------+
//| --- Global Variables ---                                         |
//+------------------------------------------------------------------+
int      g_hFast, g_hSlow, g_hAtr;
// --- ELITE UPGRADE START ---
int      g_hBias, g_hRsi;
// --- ELITE UPGRADE END ---
CTrade   g_trade;
datetime g_lastBarCheck = 0;
datetime g_lastTradeBar = 0;
ulong    g_activeTicket = 0;

double CalculateSLDistanceFromUSD(const double riskUsd, const double lotSize)
{
    if(riskUsd <= 0.0 || lotSize <= 0.0)
        return 0.0;

    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    if(tickSize <= 0.0 || tickValue <= 0.0)
        return 0.0;

    return (riskUsd * tickSize) / (tickValue * lotSize);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    g_hFast = iMA(_Symbol, PERIOD_M1, InpEmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_hSlow = iMA(_Symbol, PERIOD_M1, InpEmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    // --- ELITE UPGRADE START ---
    g_hBias = iMA(_Symbol, PERIOD_M1, InpEmaBiasPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_hRsi  = iRSI(_Symbol, PERIOD_M1, InpRsiPeriod, PRICE_CLOSE);
    // --- ELITE UPGRADE END ---
    g_hAtr  = iATR(_Symbol, PERIOD_M1, InpAtrPeriod);

    if(g_hFast == INVALID_HANDLE || g_hSlow == INVALID_HANDLE || g_hBias == INVALID_HANDLE || g_hRsi == INVALID_HANDLE || g_hAtr == INVALID_HANDLE)
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
    // --- ELITE UPGRADE START ---
    if(g_hFast != INVALID_HANDLE) IndicatorRelease(g_hFast);
    if(g_hSlow != INVALID_HANDLE) IndicatorRelease(g_hSlow);
    if(g_hBias != INVALID_HANDLE) IndicatorRelease(g_hBias);
    if(g_hRsi  != INVALID_HANDLE) IndicatorRelease(g_hRsi);
    if(g_hAtr  != INVALID_HANDLE) IndicatorRelease(g_hAtr);
    // --- ELITE UPGRADE END ---
    CleanupDashboard();
}

//+------------------------------------------------------------------+
//| Helper: Detect New Bar                                           |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
    if(currentBarTime != g_lastBarCheck)
    {
        g_lastBarCheck = currentBarTime;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    int currentBarCount = Bars(_Symbol, PERIOD_M1);
    ManagePendingExpiry(currentBarCount);

    // 1. Manage Active Position (Trailing) - Keep Tick-Based
    CheckActivePosition();
    if(g_activeTicket != 0)
    {
        ManageQuickHandsTrailing(g_activeTicket);
    }

    // 2. ENTRY PIPELINE ONLY ON NEW CANDLE
    if(!IsNewBar())
        return;

    Print("[NEW BAR] Running entry logic");

    // Skip check if already in position or pending order exists
    if(g_activeTicket != 0 || HasPendingOrder() || HasAnyPendingOrders())
    {
        UpdateDashboardStats();
        return;
    }

    // Prevent multiple trades on same candle
    datetime currentBar = iTime(_Symbol, PERIOD_M1, 0);
    if(g_lastTradeBar == currentBar)
    {
        UpdateDashboardStats();
        return;
    }

    StrategySignal sig;
    if(EvaluateQuickHands(g_hFast, g_hSlow, g_hAtr, sig))
    {
        if(ExecuteQuickHandsTrade(sig))
        {
            g_lastTradeBar = currentBar;
        }
    }
    // 3. Update Dashboard - Now once per min
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
        if(HistoryDealSelect(trans.deal))
        {
            if((ulong)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == (ulong)InpMagicNumber)
            {
                ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
                ulong posTicket = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

                if(dealEntry == DEAL_ENTRY_IN)
                {
                    ulong fillOrder = (ulong)HistoryDealGetInteger(trans.deal, DEAL_ORDER);
                    double dealPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
                    HandleOrderFilled(fillOrder);

                    if(posTicket > 0)
                    {
                        GlobalVariableSet(BuildStateKey("qh_initrisk", posTicket), CalculateSLDistanceFromUSD(InpQuickHandsSLUSD, InpLotSize));
                        GlobalVariableSet(BuildStateKey("qh_traillevel", posTicket), 0);
                    }

                    LogTyped("EXECUTION", StringFormat("[M1_LSMC] %s executed: tradeId=%I64u entry=%.2f sl=%.2f lot=%.2f strategy=M1_LSMC",
                             (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY ? "BUY" : "SELL"),
                             posTicket, dealPrice, PositionSelectByTicket(posTicket) ? PositionGetDouble(POSITION_SL) : 0.0, InpLotSize));
                }
                else if(dealEntry == DEAL_ENTRY_OUT)
                {
                    double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
                    string resultType = (profit > 0.0) ? "LOCKED_PROFIT" : (profit < 0.0 ? "STOP_LOSS_HIT" : "BREAKEVEN");
                    LogTyped("RESULT", StringFormat("[%s] %s tradeId=%I64u profit=%.2f", EA_TYPE, resultType, posTicket, profit));
                    GlobalVariableDel(BuildStateKey("qh_initrisk", posTicket));
                    GlobalVariableDel(BuildStateKey("qh_traillevel", posTicket));
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
bool ExecuteQuickHandsTrade(StrategySignal &sig)
{
    double lot = InpLotSize;
    MqlRates signalBar[];
    ArraySetAsSeries(signalBar, true);
    if(CopyRates(_Symbol, PERIOD_M1, 1, 1, signalBar) != 1)
        return false;

    double openPrice = (sig.type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double R = CalculateSLDistanceFromUSD(InpQuickHandsSLUSD, lot);
    if(R <= 0.0)
    {
        LogTyped("REJECTION", StringFormat("[M1_LSMC] %s rejected: reason=INVALID_SL atr=%.2f spread=%d",
                 (sig.type == POSITION_TYPE_BUY ? "BUY" : "SELL"), sig.atr, (int)sig.spread));
        return false;
    }
    double sl = (sig.type == POSITION_TYPE_BUY) ? (openPrice - R) : (openPrice + R);
    sl = NormalizeDouble(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    if(sl <= 0.0)
    {
        LogTyped("REJECTION", StringFormat("[M1_LSMC] %s rejected: reason=INVALID_SL atr=%.2f spread=%d",
                 (sig.type == POSITION_TYPE_BUY ? "BUY" : "SELL"), sig.atr, (int)sig.spread));
        return false;
    }
    double tp = 0.0;

    string sideStr = (sig.type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
    datetime barTime = iTime(_Symbol, PERIOD_M1, 1);
    int currentBarCount = Bars(_Symbol, PERIOD_M1);
    
    // --- ELITE UPGRADE START ---
    double marginRequired = 0.0;
    if(!OrderCalcMargin((sig.type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), _Symbol, lot, openPrice, marginRequired) ||
       AccountInfoDouble(ACCOUNT_MARGIN_FREE) < marginRequired * 1.5)
    {
        LogTyped("REJECTION", StringFormat("[M1_LSMC] %s rejected: reason=INSUFFICIENT_MARGIN atr=%.2f spread=%d", 
            sideStr, sig.atr, (int)sig.spread));
        return false;
    }
    // --- ELITE UPGRADE END ---

    if(PositionsTotal() > 0 || HasPendingOrder() || HasAnyPendingOrders())
        return false;

    double rawEntry = CalculateLimitPrice((sig.type == POSITION_TYPE_BUY), signalBar[0].close, signalBar[0].high, signalBar[0].low);
    double limitEntry = NormalizeEntryPrice(rawEntry, (sig.type == POSITION_TYPE_BUY));
    double slDistance = MathAbs(openPrice - sl);
    sl = RecalculateSL((sig.type == POSITION_TYPE_BUY), limitEntry, slDistance);
    if(limitEntry <= 0.0 || !MathIsValidNumber(limitEntry))
    {
        PrintFormat("[GoldEA][REJECTION] INVALID_ENTRY price=%.5f", limitEntry);
        return false;
    }

    ulong orderTicket = PlaceLimitOrder("M1_LSMC",
                                        (sig.type == POSITION_TYPE_BUY),
                                        limitEntry,
                                        sl,
                                        0.0,
                                        lot,
                                        currentBarCount,
                                        0,
                                        "QuickHands M1",
                                        R,
                                        0);
    if(orderTicket > 0)
    {
        LogTyped("ORDER", StringFormat("[M1_LSMC] %s LIMIT_PLACED tradeId=%I64u barTime=%s entry=%.2f sl=%.2f lot=%.2f strategy=M1_LSMC",
                 sideStr, orderTicket, TimeToString(barTime), limitEntry, sl, lot));
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Dashboard Update                                                 |
//+------------------------------------------------------------------+
void UpdateDashboardStats()
{
    if(!InpEnableDashboard) return;

    DashboardState s;
    s.mode = "M1_LSMC"; 
    s.session = CurrentSessionText();
    s.spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    
    double atr = 0;
    GetIndicatorValue(g_hAtr, 1, atr);
    s.atr = atr;

    // Trend & Pattern State
    StrategySignal sig;
    EvaluateQuickHands(g_hFast, g_hSlow, g_hAtr, sig);
    
    double ema50_1 = 0.0;
    double close1 = iClose(_Symbol, PERIOD_M1, 1);
    GetIndicatorValue(g_hSlow, 1, ema50_1);
    s.trendStrength = 0.0;
    s.spreadRatio = 0.0;
    s.status = (sig.isValid ? "READY" : (sig.reason == "NO_PATTERN" ? "WAIT" : "BLOCKED"));
    s.phase = "NO LOCK";
    s.rMultiple = 0.0;
    bool buyBias = (close1 > ema50_1);
    bool sellBias = (close1 < ema50_1);
    s.trend = buyBias ? "BUY_BIAS" : (sellBias ? "SELL_BIAS" : "NEUTRAL");
    
    s.pattern = sig.isValid ? sig.pattern : "NONE";
    
    // Candle colors from Pattern String
    string currentPattern = GetCandlePattern();
    if(StringLen(currentPattern) == 3)
    {
        s.c3 = StringSubstr(currentPattern, 0, 1);
        s.c2 = StringSubstr(currentPattern, 1, 1);
        s.c1 = StringSubstr(currentPattern, 2, 1);
    }

    s.slStruct = sig.slStruct;
    s.slATR = sig.slATR;
    s.slFinal = sig.slFinal;
    s.sweepState = sig.sweep ? "YES" : "NO";
    s.rejectionState = sig.rejection ? "YES" : "NO";
    s.confirmationState = sig.confirmation ? "YES" : "NO";
    s.lockLevel = "NONE";
    s.slUsd = InpQuickHandsSLUSD;

    s.atrPass = "INFO";
    s.trendPass = ((sig.pattern == "RRG" && buyBias) || (sig.pattern == "GGR" && sellBias) || sig.reason == "NO_PATTERN") ? "PASS" : "FAIL";
    s.spreadPass = "INFO";
    s.qualityPass = (sig.reason != "WEAK_C1_BODY" && sig.reason != "WEAK_CONTEXT_BODY") ? "PASS" : "FAIL";
    s.c3Overextended = sig.reason;

    if(g_activeTicket != 0 && PositionSelectByTicket(g_activeTicket))
    {
        s.tradeStatus = "OPEN";
        s.profit = PositionGetDouble(POSITION_PROFIT);
        s.id = g_activeTicket;
        s.entry = PositionGetDouble(POSITION_PRICE_OPEN);
        s.sl = PositionGetDouble(POSITION_SL);
        s.tp = PositionGetDouble(POSITION_TP);
        
        // --- ELITE UPGRADE START ---
        double initR = GlobalVariableCheck(BuildStateKey("qh_initrisk", g_activeTicket)) ? GlobalVariableGet(BuildStateKey("qh_initrisk", g_activeTicket)) : MathAbs(s.entry - s.sl);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double priceMove = (posType == POSITION_TYPE_BUY) ? (currentPrice - s.entry) : (s.entry - currentPrice);
        s.rMultiple = (initR > 0.0) ? (priceMove / initR) : 0.0;
        double lockedDistance = (posType == POSITION_TYPE_BUY) ? (s.sl - s.entry) : (s.entry - s.sl);
        double volume = PositionGetDouble(POSITION_VOLUME);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        s.locked = 0.0;
        if(lockedDistance > 0.0 && volume > 0.0 && tickSize > 0.0 && tickValue > 0.0)
            s.locked = (lockedDistance / tickSize) * tickValue * volume;

        if(s.profit >= 2.0)
        {
            s.phase = "DYNAMIC";
            s.lockLevel = StringFormat("%.2f", MathMax(s.profit - 1.0, 0.0));
        }
        else if(s.profit >= 1.0)
        {
            s.phase = "LOCK 0.5";
            s.lockLevel = "0.5";
        }
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
        SetDashboardLabelLine(EA_TYPE, "R_VAL", StringFormat("RefR: %.2f | TP: %.2f | Lock: %s", R_val, MathAbs(s.entry - s.tp), lockStatus), lockColor, 16);
    }
}
