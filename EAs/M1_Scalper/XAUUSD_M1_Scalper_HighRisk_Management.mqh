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
//| 1. Dynamic Step-Based Trailing Stop                              |
//+------------------------------------------------------------------+
// This function implements the aggressive profit-locking trailing stop.
// It moves the SL to predefined profit levels as the trade becomes more profitable.
void ManageTrailingStop(const ulong ticket, const double profit)
{
    // Fixed-SL mode: stop-loss is set at entry and must not be modified later.
    // Keep function as no-op to preserve execution flow without SL overrides.
    if(ticket == 0 && profit < 0.0)
        Log("ManageTrailingStop no-op.");
}


//+------------------------------------------------------------------+
//| 2. Dynamic Take Profit Expansion                                 |
//+------------------------------------------------------------------+
// This function extends the Take Profit target as the trade achieves
// multiples of its initial risk (R).
void UpdateDynamicTP(const ulong ticket, const double profit, const double initialRiskInCurrency)
{
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
