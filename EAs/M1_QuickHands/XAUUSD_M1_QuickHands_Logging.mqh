#ifndef XAUUSD_M1_QUICKHANDS_LOGGING_MQH
#define XAUUSD_M1_QUICKHANDS_LOGGING_MQH

#include "XAUUSD_M1_QuickHands_Inputs.mqh"
#include "../Include/GoldEA_Common_Core.mqh"

//+------------------------------------------------------------------+
//| GoldEA Standardized Logging Wrapper                              |
//+------------------------------------------------------------------+
void LogTyped(string type, string msg)
{
    PrintFormat("[%s][GoldEA][%s] %s", EA_TYPE, type, msg);
}

//+------------------------------------------------------------------+
//| Dashboard State Struct                                           |
//+------------------------------------------------------------------+
struct DashboardState
{
    string mode; // ACTIVE/BLOCKED
    string trend;
    double trendStrength;
    double spreadRatio;
    string status;
    string phase;
    double rMultiple;
    double atr;
    long spread;
    string session;
    string pattern;
    string c3, c2, c1;
    double slStruct, slATR, slFinal;
    double entry, sl, tp;
    string atrPass, trendPass, spreadPass, qualityPass;
    string c3Overextended;
    string tradeStatus;
    double profit, locked;
    ulong id;
    string sweepState;
    string rejectionState;
    string confirmationState;
    string lockLevel;
    double slUsd;
};

//+------------------------------------------------------------------+
//| Dashboard Update Helper                                          |
//+------------------------------------------------------------------+
void UpdateQuickHandsDashboard(string label, string text, color clr, int row)
{
    if(!InpEnableDashboard) return;
    SetDashboardLabelLine(InpDashboardPrefix, label, text, clr, row);
}

void UpdateDashboard(const DashboardState &s)
{
    if(!InpEnableDashboard) return;
    
    UpdateQuickHandsDashboard("HEADER", "=== M1 QUICKHANDS LSMC ===", clrCyan, 0);
    UpdateQuickHandsDashboard("MODE", "Logic: " + s.mode, clrGreen, 1);
    UpdateQuickHandsDashboard("ENTRY_MODE", "Entry Mode: CLOSED CANDLE", clrCyan, 2);
    
    UpdateQuickHandsDashboard("SEP1", "---------------------------", clrGray, 3);

    UpdateQuickHandsDashboard("SIGNAL1", StringFormat("Sweep: %s | Rejection: %s", s.sweepState, s.rejectionState), clrWhite, 4);
    UpdateQuickHandsDashboard("SIGNAL2", StringFormat("Confirmation: %s | Pattern: %s", s.confirmationState, s.pattern), clrWhite, 5);
    UpdateQuickHandsDashboard("MARKET", StringFormat("ATR: %.2f | Spread: %d | Bias: %s", s.atr, s.spread, s.trend), clrWhite, 6);
    UpdateQuickHandsDashboard("STATUS", "Status: " + s.status, (StringFind(s.status, "READY") == 0 ? clrLime : (StringFind(s.status, "BLOCKED") == 0 ? clrRed : clrYellow)), 7);
    UpdateQuickHandsDashboard("REASON", "Reason: " + s.c3Overextended, (s.c3Overextended == "VALID" ? clrLime : clrOrange), 8);
    UpdateQuickHandsDashboard("SESSION", "Session: " + s.session, clrWhite, 9);
    
    UpdateQuickHandsDashboard("SEP2", "---------------------------", clrGray, 11);
    
    UpdateQuickHandsDashboard("TRADE_SETUP", StringFormat("Entry: %.2f | SL: %.2f | TP: %.2f", s.entry, s.sl, s.tp), clrWhite, 12);
    UpdateQuickHandsDashboard("FILTERS", StringFormat("Bodies: %s | EMA50: %s", s.qualityPass, s.trendPass), clrWhite, 13);
    
    UpdateQuickHandsDashboard("SEP3", "---------------------------", clrGray, 19);
    
    UpdateQuickHandsDashboard("TRADE_STATE", "Trade: " + s.tradeStatus, (s.tradeStatus == "OPEN" ? clrGreen : clrYellow), 20);
    if(s.tradeStatus == "OPEN")
    {
        UpdateQuickHandsDashboard("TRADE_DATA", StringFormat("Profit: $%.2f | Lock Level: %s | SL($): %.2f", s.profit, s.lockLevel, s.slUsd), (s.profit >= 0 ? clrGreen : clrRed), 21);
    }
}

//+------------------------------------------------------------------+
//| Clean up dashboard on exit                                       |
//+------------------------------------------------------------------+
void CleanupDashboard()
{
    ObjectsDeleteAll(0, InpDashboardPrefix);
}

#endif // XAUUSD_M1_QUICKHANDS_LOGGING_MQH
