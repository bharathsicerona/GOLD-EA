#ifndef XAUUSD_M1_SCALPER_HIGHRISK_MANAGEMENT_MQH
#define XAUUSD_M1_SCALPER_HIGHRISK_MANAGEMENT_MQH

//+------------------------------------------------------------------+
//| ManageTrendRSIContinuation - R-Based Phased Management          |
//| R = abs(TP - OpenPrice) / 3.0 (Since TP is fixed at 3R)          |
//| PHASE 1: Reach 1.0R Profit -> Lock 0.2R                          |
//| PHASE 2: Reach 2.0R Profit -> Lock 1.0R                          |
//| PHASE 3: Reach 3.0R Target -> Auto-exit                          |
//+------------------------------------------------------------------+
void ManageTrendRSIContinuation(const ulong ticket, const double profit)
{
    if (!PositionSelectByTicket(ticket)) return;

    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    string posSymbol = PositionGetString(POSITION_SYMBOL);

    if (currentTP <= 0) return; // Need TP to calculate R

    // Calculate Initial Risk (R) based on fixed 3R TP
    double R = MathAbs(currentTP - openPrice) / 3.0;
    if (R <= 0) return;

    // --- FIX START ---
    double currentPrice = (type == POSITION_TYPE_BUY)
                          ? SymbolInfoDouble(posSymbol, SYMBOL_BID)
                          : SymbolInfoDouble(posSymbol, SYMBOL_ASK);
    double move = (type == POSITION_TYPE_BUY)
                  ? (currentPrice - openPrice)
                  : (openPrice - currentPrice);
    double rMultiple = (R > 0.0) ? (move / R) : 0.0;
    int desiredLevel = 0;
    double lockPoints = -1.0;
    double lockedR = 0.0;

    if(rMultiple >= 3.0)
      {
       if(trade.PositionClose(ticket))
          LogTyped("RESULT", StringFormat("[%s] TAKE_PROFIT_HIT tradeId=%I64u R_multiple=%.2f", "M1_TREND_RSI_CONTINUATION", ticket, rMultiple));
       return;
      }
    else if(rMultiple >= 2.0)
      {
       desiredLevel = 2;
       lockedR = 1.0;
       lockPoints = 1.0 * R;
      }
    else if(rMultiple >= 1.0)
      {
       desiredLevel = 1;
       lockedR = 0.2;
       lockPoints = 0.2 * R;
      }
    // --- FIX END ---

    if (lockPoints < 0) return;

    // --- FIX START ---
    double newSL = (type == POSITION_TYPE_BUY) ? (openPrice + lockPoints) : (openPrice - lockPoints);
    double point = SymbolInfoDouble(posSymbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(posSymbol, SYMBOL_DIGITS);
    newSL = NormalizeDouble(newSL, digits);

    long stopsLevel = SymbolInfoInteger(posSymbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minStop = stopsLevel * point;

    string levelKey = BuildStateKey("m1trail", ticket);
    int currentLevel = GlobalVariableCheck(levelKey) ? (int)GlobalVariableGet(levelKey) : 0;
    if(desiredLevel <= currentLevel)
       return;

    if(currentSL > 0.0 && MathAbs(newSL - currentSL) < (point * 2.0))
       return;

    if(type == POSITION_TYPE_BUY)
      {
       if((currentPrice - newSL) < minStop)
          return;
       if(currentSL > 0.0 && newSL <= currentSL)
          return;
      }
    else
      {
       if((newSL - currentPrice) < minStop)
          return;
       if(currentSL > 0.0 && newSL >= currentSL)
          return;
      }

    if(trade.PositionModify(ticket, newSL, currentTP))
      {
       GlobalVariableSet(levelKey, desiredLevel);
       LogTyped("MGMT", StringFormat("[%s] LOCK_PROFIT tradeId=%I64u R_multiple=%.2f lockedR=%.2f SL=%.2f", "M1_TREND_RSI_CONTINUATION", ticket, rMultiple, lockedR, newSL));
      }
    else
      {
       LogTyped("MGMT_ERROR", StringFormat("[%s] MOD_FAILED ticket=%I64u err=%d targetSL=%.2f", "M1_TREND_RSI_CONTINUATION", ticket, GetLastError(), newSL));
      }
    // --- FIX END ---
}

//+------------------------------------------------------------------+
//| --- Main High-Risk Management Function ---                       |
//+------------------------------------------------------------------+
void ManageHighRiskPosition()
{
    if (!PositionSelect(_Symbol) || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return;

    ulong ticket = PositionGetInteger(POSITION_TICKET);
    double profit = PositionGetDouble(POSITION_PROFIT);
    
    ManageTrendRSIContinuation(ticket, profit);
}

#endif // XAUUSD_M1_SCALPER_HIGHRISK_MANAGEMENT_MQH
