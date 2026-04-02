#ifndef XAUUSD_M1_QUICKHANDS_MANAGEMENT_MQH
#define XAUUSD_M1_QUICKHANDS_MANAGEMENT_MQH

#include "XAUUSD_M1_QuickHands_Inputs.mqh"
#include "XAUUSD_M1_QuickHands_Logging.mqh"
#include "../Include/GoldEA_Common_Core.mqh"

//+------------------------------------------------------------------+
//| R-Multiple Support Calculations                                  |
//+------------------------------------------------------------------+
double GetCurrentProfitR(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return 0.0;
    
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl    = PositionGetDouble(POSITION_SL);
    double cur   = PositionGetDouble(POSITION_PRICE_CURRENT);
    double profit = PositionGetDouble(POSITION_PROFIT);
    
    double riskPrice = MathAbs(entry - sl);
    if(riskPrice <= 0) return 0.0;
    
    return profit / InpRiskUSD; // Using fixed USD risk of 3.0
}

//+------------------------------------------------------------------+
//| Aggressive QuickHands Trailing Logic                             |
//+------------------------------------------------------------------+
void ManageQuickHandsTrailing(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double curSL = PositionGetDouble(POSITION_SL);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    // R is the initial risk distance (Entry to SL)
    // If it has already moved to +1R, MathAbs(entry - curSL) still represents R but we shouldn't move it again.
    double R = MathAbs(entry - curSL);
    if(R <= 0) return;

    double profitPoints = (type == POSITION_TYPE_BUY) ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) - entry) : (entry - SymbolInfoDouble(_Symbol, SYMBOL_ASK));
    
    // Move SL to 1R lock when price hits 2R
    if(profitPoints >= 2.0 * R)
    {
        double newSL = (type == POSITION_TYPE_BUY) ? (entry + R) : (entry - R);
        newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
        
        // Ensure we only move SL forward (to +1R profit)
        bool shouldUpdate = false;
        if(type == POSITION_TYPE_BUY && newSL > curSL + _Point) shouldUpdate = true;
        if(type == POSITION_TYPE_SELL && (curSL == 0 || newSL < curSL - _Point)) shouldUpdate = true;
        
        if(shouldUpdate)
        {
            CTrade trade;
            if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
            {
                LogTyped("MGMT", StringFormat("[%s] SL_MOVED_TO_1R tradeId=%I64u R=%.2f newSL=%.2f", 
                    "M1_QUICKHANDS", ticket, R, newSL));
            }
        }
    }
}

#endif // XAUUSD_M1_QUICKHANDS_MANAGEMENT_MQH
