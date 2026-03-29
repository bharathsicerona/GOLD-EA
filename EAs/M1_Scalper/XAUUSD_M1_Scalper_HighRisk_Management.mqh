#ifndef XAUUSD_M1_SCALPER_HIGHRISK_MANAGEMENT_MQH
#define XAUUSD_M1_SCALPER_HIGHRISK_MANAGEMENT_MQH

//+------------------------------------------------------------------+
//| --- Helper Functions ---                                         |
//+------------------------------------------------------------------+

// Converts a profit amount in account currency to a price offset
double ProfitToPrice(const double profitInCurrency, const string symbol, const double volume, const ENUM_POSITION_TYPE positionType)
{
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

    if (tickValue <= 0 || volume <= 0) return 0.0;

    double points = (profitInCurrency / (tickValue * volume)) * tickSize;
    return points;
}

//+------------------------------------------------------------------+
//| 1. R-based trailing stop                                          |
//+------------------------------------------------------------------+
// [NEW SYSTEM] Runner logic:
// - >1R  : move SL to breakeven
// - >1.5R: lock +0.5R
// - >2R  : trail by 1R from current price
void ManageTrailingStop(const ulong ticket, const double profit)
{
    if (ticket == 0)
        return;
    if (!PositionSelectByTicket(ticket))
        return;

    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    double initialRisk = 0.0;
    if (!g_initialRiskMap.TryGetValue(ticket, initialRisk) || initialRisk <= 0.0)
        return;
    double rMultiple = profit / initialRisk;
    if (rMultiple <= 1.0)
        return;

    double volume = PositionGetDouble(POSITION_VOLUME);
    double lockPriceDistance = ProfitToPrice(initialRisk, _Symbol, volume, type);
    double riskPriceDistance = lockPriceDistance;
    if (riskPriceDistance <= 0.0)
        return;

    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double lockSL = currentSL;
    int desiredLevel = 0;
    if (rMultiple > 2.0)
    {
        desiredLevel = 3;
        lockSL = (type == POSITION_TYPE_BUY) ? (currentPrice - riskPriceDistance) : (currentPrice + riskPriceDistance);
    }
    else if (rMultiple > 1.5)
    {
        desiredLevel = 2;
        lockSL = (type == POSITION_TYPE_BUY) ? (openPrice + riskPriceDistance * 0.5) : (openPrice - riskPriceDistance * 0.5);
    }
    else
    {
        desiredLevel = 1;
        lockSL = openPrice;
    }

    string trailLevelKey = BuildStateKey("m1traillevel", ticket);
    int lastAppliedLevel = 0;
    if (GlobalVariableCheck(trailLevelKey))
        lastAppliedLevel = (int)GlobalVariableGet(trailLevelKey);
    if (desiredLevel < lastAppliedLevel)
        return;

    bool needsLock = false;
    if (type == POSITION_TYPE_BUY)
        needsLock = (currentSL <= 0.0 || currentSL < lockSL);
    else
        needsLock = (currentSL <= 0.0 || currentSL > lockSL);

    if (!needsLock)
        return;

    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    lockSL = NormalizeDouble(lockSL, digits);
    if (trade.PositionModify(ticket, lockSL, currentTP))
    {
        GlobalVariableSet(trailLevelKey, (double)desiredLevel);
        Log(StringFormat("PROFIT_LOCK_APPLIED: ticket=%I64u r=%.2f level=%d sl=%.2f", ticket, rMultiple, desiredLevel, lockSL));
    }
}


//+------------------------------------------------------------------+
//| 2. Dynamic Take Profit Expansion                                 |
//+------------------------------------------------------------------+
// This function extends the Take Profit target as the trade achieves
// multiples of its initial risk (R).
void UpdateDynamicTP(const ulong ticket, const double profit, const double initialRiskInCurrency)
{
    // [NEW SYSTEM] Keep structured fixed TP from entry; skip dynamic TP rewrite.
    if (PositionSelectByTicket(ticket) && PositionGetDouble(POSITION_TP) > 0.0)
        return;
    if (initialRiskInCurrency <= 0) return;

    // Calculate current profit in R-multiples
    double rMultiple = profit / initialRiskInCurrency;

    // --- Determine New TP Target ---
    double newTpRR = 0.0;
    if (rMultiple >= 2.0)
    {
        newTpRR = 6.0; // At 2R profit, extend TP to 6R
    }
    else if (rMultiple >= 1.0)
    {
        newTpRR = 4.0; // At 1R profit, extend TP to 4R
    }

    if (newTpRR <= 0.0) return; // No update needed yet

    // --- Calculate and Apply New Take Profit ---
    if (!PositionSelectByTicket(ticket)) return;

    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    
    double initialRiskInPoints = PositionGetDouble(POSITION_SL) > 0 ? fabs(openPrice - PositionGetDouble(POSITION_SL)) : 0;
    double newTpPrice = 0.0;

    if (initialRiskInPoints <= 0) return;

    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    if(type == POSITION_TYPE_BUY)
    {
       newTpPrice = NormalizeDouble(openPrice + (initialRiskInPoints * newTpRR), SYMBOL_POINT);
    }
    else // SELL
    {
       newTpPrice = NormalizeDouble(openPrice - (initialRiskInPoints * newTpRR), SYMBOL_POINT);
    }
    
    // Check if TP needs updating
    if (fabs(newTpPrice - currentTP) < SYMBOL_POINT) return;

    // --- Modify Position and Log ---
    if (trade.PositionModify(ticket, currentSL, newTpPrice))
    {
        Log(StringFormat("DYNAMIC TP: Ticket #%I64u TP extended. Profit reached %.1fR, new TP at %.1fR.", ticket, rMultiple, newTpRR));
    }
}


//+------------------------------------------------------------------+
//| --- Main High-Risk Management Function ---                       |
//+------------------------------------------------------------------+
// This function orchestrates the new aggressive trade management logic.
// It should be called on every tick from the main EA file.
void ManageHighRiskPosition()
{
    if (PositionsTotal() != 1) return; // Function designed for a single open position

    ulong ticket = PositionGetTicket(0);
    if (!PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return;

    double profit = PositionGetDouble(POSITION_PROFIT);
    double initialRisk = 0; // This needs to be calculated and stored when the position is opened.

    // --- Execute Management Logic ---
    // Note: The order is important. Update SL first to lock profits.
    ManageTrailingStop(ticket, profit);
    
    // For Dynamic TP, we need the initial risk amount. This should be calculated
    // and stored when the trade is first opened, perhaps in a global map or by
    // embedding it in the trade comment. For now, this is a placeholder.
    // UpdateDynamicTP(ticket, profit, initialRisk);
}

#endif // XAUUSD_M1_SCALPER_HIGHRISK_MANAGEMENT_MQH
