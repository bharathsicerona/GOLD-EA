#ifndef XAUUSD_M1_QUICKHANDS_MANAGEMENT_MQH
#define XAUUSD_M1_QUICKHANDS_MANAGEMENT_MQH

#include "XAUUSD_M1_QuickHands_Inputs.mqh"
#include "XAUUSD_M1_QuickHands_Logging.mqh"
#include "../Include/GoldEA_Common_Core.mqh"

//+------------------------------------------------------------------+
//| Aggressive QuickHands Trailing Logic                             |
//+------------------------------------------------------------------+
void ManageQuickHandsTrailing(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double curSL = PositionGetDouble(POSITION_SL);
    double currentProfit = PositionGetDouble(POSITION_PROFIT);
    // --- ELITE UPGRADE START ---
    double initRisk = 0.0;
    string riskKey = BuildStateKey("qh_initrisk", ticket);
    if(GlobalVariableCheck(riskKey))
        initRisk = GlobalVariableGet(riskKey);
    if(initRisk <= 0.0)
        initRisk = MathAbs(entry - curSL);
    if(initRisk <= 0.0) return;
    // --- ELITE UPGRADE END ---
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    // R is the initial risk distance (Entry to SL)
    // If it has already moved to +1R, MathAbs(entry - curSL) still represents R but we shouldn't move it again.
    double R = initRisk;
    if(R <= 0) return;

    double currentPrice = (type == POSITION_TYPE_BUY)
                          ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                          : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double volume = PositionGetDouble(POSITION_VOLUME);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    if(volume <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0) return;

    int desiredLevel = 0;
    double lockUsd = -1.0;
    string mgmtTag = "";
    if(currentProfit >= 2.0)
    {
        desiredLevel = (int)MathFloor(currentProfit * 10.0);
        lockUsd = currentProfit - 1.0;
        mgmtTag = "LOCK_DYNAMIC";
    }
    else if(currentProfit >= 1.0)
    {
        desiredLevel = 1;
        lockUsd = 0.5;
        mgmtTag = "LOCK_0.5";
    }
    if(lockUsd < 0.0)
        return;

    string levelKey = BuildStateKey("qh_traillevel", ticket);
    int currentLevel = GlobalVariableCheck(levelKey) ? (int)GlobalVariableGet(levelKey) : 0;
    if(desiredLevel <= currentLevel)
        return;

    double tp = PositionGetDouble(POSITION_TP);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minStop = stopsLevel * point;
    double lockDistance = (lockUsd / (volume * tickValue)) * tickSize;
    if(lockDistance <= 0.0)
        return;

    double newSL = (type == POSITION_TYPE_BUY) ? (entry + lockDistance) : (entry - lockDistance);
    newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

    if(curSL > 0.0 && MathAbs(newSL - curSL) < (point * 2.0))
       return;

    if(type == POSITION_TYPE_BUY)
      {
       if((currentPrice - newSL) < minStop)
          return;
       if(curSL > 0.0 && newSL <= curSL)
          return;
      }
    else
      {
       if((newSL - currentPrice) < minStop)
          return;
       if(curSL > 0.0 && newSL >= curSL)
          return;
      }

    CTrade trade;
    if(trade.PositionModify(ticket, newSL, tp))
      {
       GlobalVariableSet(levelKey, desiredLevel);
       LogTyped("MGMT", StringFormat("[M1_LSMC] %s tradeId=%I64u profit=%.2f lock=%.2f newSL=%.2f",
           mgmtTag, ticket, currentProfit, lockUsd, newSL));
      }
}

#endif // XAUUSD_M1_QUICKHANDS_MANAGEMENT_MQH
