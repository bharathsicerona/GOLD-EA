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
    
    UpdateQuickHandsDashboard("HEADER", "M1 QUICKHANDS EA", clrCyan, 0);
    UpdateQuickHandsDashboard("MODE", "Mode: " + s.mode, (s.mode == "ACTIVE" ? clrGreen : clrRed), 1);
    UpdateQuickHandsDashboard("ENTRY_MODE", "Entry Mode: CLOSED CANDLE", clrCyan, 2);
    
    UpdateQuickHandsDashboard("SEP1", "---------------------------", clrGray, 3);
    
    UpdateQuickHandsDashboard("MARKET", StringFormat("Trend: %s | ATR: %.2f | Spread: %d", s.trend, s.atr, s.spread), clrWhite, 4);
    UpdateQuickHandsDashboard("SESSION", "Session: " + s.session, clrWhite, 5);
    
    UpdateQuickHandsDashboard("PATTERN", "Pattern: " + s.pattern, (s.pattern != "NONE" ? clrGreen : clrYellow), 6);
    UpdateQuickHandsDashboard("CANDLES", StringFormat("C3: %s | C2: %s | C1: %s", s.c3, s.c2, s.c1), clrWhite, 7);
    
    UpdateQuickHandsDashboard("SEP2", "---------------------------", clrGray, 9);
    
    UpdateQuickHandsDashboard("SL_TYPE", "SL Type: HYBRID", clrWhite, 10);
    UpdateQuickHandsDashboard("SL_DIST", StringFormat("Struct: %.2f | ATR: %.2f | Final: %.2f", s.slStruct, s.slATR, s.slFinal), clrSkyBlue, 11);
    
    color qualityColor = (s.qualityPass == "PASS") ? clrLime : clrRed;
    UpdateQuickHandsDashboard("QUALITY", "Candle Quality: " + s.qualityPass, qualityColor, 12);
    
    color extColor = (s.c3Overextended == "PASS") ? clrLime : clrRed;
    UpdateQuickHandsDashboard("OVEREXTENSION", "Overextension: " + s.c3Overextended, extColor, 13);
    
    UpdateQuickHandsDashboard("TRADE_SETUP", StringFormat("Entry: %.2f | SL: %.2f | TP: %.2f", s.entry, s.sl, s.tp), clrWhite, 14);
    
    UpdateQuickHandsDashboard("FILTERS", StringFormat("Filters: ATR %s | Trend %s | Spread %s", s.atrPass, s.trendPass, s.spreadPass), clrWhite, 15);
    
    UpdateQuickHandsDashboard("SEP3", "---------------------------", clrGray, 17);
    
    UpdateQuickHandsDashboard("TRADE_STATE", "Trade: " + s.tradeStatus, (s.tradeStatus == "OPEN" ? clrGreen : clrYellow), 18);
    if(s.tradeStatus == "OPEN")
    {
        UpdateQuickHandsDashboard("TRADE_DATA", StringFormat("Profit: $%.2f | Locked: $%.2f | ID: %I64u", s.profit, s.locked, s.id), (s.profit >= 0 ? clrGreen : clrRed), 19);
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
