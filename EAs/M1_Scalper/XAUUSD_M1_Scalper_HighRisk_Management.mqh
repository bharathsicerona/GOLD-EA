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
//| CalculateTighterSL - Stronger reversal -> tighter SL             |
//+------------------------------------------------------------------+
double CalculateTighterSL(ENUM_POSITION_TYPE type, double currentSL, double entry, double strength)
{
    double atrValue = 0;
    if (!GetIndicatorValue(g_atrHandle, 1, atrValue)) return currentSL;
    
    double shift = strength * 0.2 * atrValue;
    double newSL = currentSL;
    
    if (type == POSITION_TYPE_BUY)
    {
        newSL = currentSL + shift;
        // Cap it at entry for now if it's too aggressive, or just allow it
    }
    else
    {
        newSL = currentSL - shift;
    }
    return NormalizeDouble(newSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| ExtendTakeProfitPrice - Extend TP based on reversal strength     |
//+------------------------------------------------------------------+
double ExtendTakeProfitPrice(ENUM_POSITION_TYPE type, double currentTP, double strength)
{
    double atrValue = 0;
    if (!GetIndicatorValue(g_atrHandle, 1, atrValue)) return currentTP;

    double shift = strength * 0.5 * atrValue;
    double newTP = currentTP;

    if (type == POSITION_TYPE_BUY)
    {
        newTP = currentTP + shift;
    }
    else
    {
        newTP = currentTP - shift;
    }
    return NormalizeDouble(newTP, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| StrategyFeedbackManager - In-trade Signal Management             |
//+------------------------------------------------------------------+
void StrategyFeedbackManager(StrategySignal &signals[])
{
    if (!PositionSelect(_Symbol)) return;

    long positionType = PositionGetInteger(POSITION_TYPE);
    double positionProfit = PositionGetDouble(POSITION_PROFIT);
    ulong ticket = PositionGetInteger(POSITION_TICKET);
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    
    // --- 1. HANDLE REVERSAL SIGNAL (INTELLIGENCE LAYER) ---
    ENUM_POSITION_TYPE revDir;
    double revStrength;
    if (DetectReversalSignal(revDir, revStrength))
    {
        // CASE 1: REVERSAL AGAINST TRADE (RISK CONTROL)
        if (revDir != (ENUM_POSITION_TYPE)positionType)
        {
            double initialRisk = 0;
            g_initialRiskMap.TryGetValue(ticket, initialRisk);
            double currentProfitR = (initialRisk > 0) ? (positionProfit / initialRisk) : 0;

            // Early exit condition: profit >= 0.5R and strength > 2.0 (STRONG)
            if (currentProfitR >= 0.5 && revStrength > 2.0)
            {
                double finalProfit = positionProfit;
                trade.PositionClose(ticket);
                LogTyped("RESULT", StringFormat("EARLY_EXIT_REVERSAL tradeId=%I64u profit=%.2f strength=%.2f profitR=%.2f", ticket, finalProfit, revStrength, currentProfitR));
                return;
            }
            else
            {
                double newSL = CalculateTighterSL((ENUM_POSITION_TYPE)positionType, currentSL, entryPrice, revStrength);
                // Ensure we only move SL in favor of the trade
                bool canModify = (positionType == POSITION_TYPE_BUY) ? (newSL > currentSL) : (newSL < currentSL);
                if (canModify && trade.PositionModify(ticket, newSL, currentTP))
                {
                    LogTyped("MGMT", StringFormat("SL_TIGHTENED_REVERSAL tradeId=%I64u newSL=%.2f strength=%.2f", ticket, newSL, revStrength));
                }
            }
        }
        // CASE 2: REVERSAL SUPPORTS TRADE (BOOST MODE)
        else if (revDir == (ENUM_POSITION_TYPE)positionType)
        {
            double newTP = ExtendTakeProfitPrice((ENUM_POSITION_TYPE)positionType, currentTP, revStrength);
            if (trade.PositionModify(ticket, currentSL, newTP))
            {
                LogTyped("MGMT", StringFormat("TP_EXTENDED_REVERSAL tradeId=%I64u newTP=%.2f strength=%.2f", ticket, newTP, revStrength));
            }
        }
    }

    // --- 2. HANDLE OTHER SIGNALS (LEGACY FEEDBACK) ---
    bool hasNewSameDirectionSignal = false;
    bool hasNewOppositeDirectionSignal = false;
    bool hasOppositeLiquiditySweep = false;

    for (int i = 0; i < ArraySize(signals); i++)
    {
        if (signals[i].valid)
        {
            if (signals[i].direction == positionType)
            {
                hasNewSameDirectionSignal = true;
            }
            else
            {
                hasNewOppositeDirectionSignal = true;
                if (signals[i].name == "M1_LIQUIDITY_SWEEP")
                {
                    hasOppositeLiquiditySweep = true;
                }
            }
        }
    }

    // CRITICAL RULE — SWEEP AGAINST TRADE
    if (hasOppositeLiquiditySweep)
    {
        LogTyped("SWEEP_OVERRIDE_EXIT", "Immediate exit due to opposite liquidity sweep. Ticket: " + (string)ticket);
        trade.PositionClose(ticket);
        return;
    }

    // SAME DIRECTION SIGNAL
    if (hasNewSameDirectionSignal)
    {
        double initialRisk = 0;
        g_initialRiskMap.TryGetValue(ticket, initialRisk);
        if(initialRisk > 0)
        {
            // LogTyped("TP_EXTENDED", "TP extended due to new same-direction signal. Ticket: " + (string)ticket);
            // This is handled by ExtendTakeProfit legacy call in main loop if needed, 
            // but we've already done reversal-based extension.
        }
    }
    // OPPOSITE SIGNAL
    else if (hasNewOppositeDirectionSignal)
    {
        if (positionProfit > 0)
        {
            LogTyped("EARLY_EXIT_CONFLICT", "Early exit with profit due to new opposite signal. Ticket: " + (string)ticket);
            trade.PositionClose(ticket);
        }
        else
        {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double newSL = openPrice; // Breakeven
            
            if(positionType == POSITION_TYPE_BUY && currentSL < newSL)
            {
                LogTyped("SL_TIGHTENED", "SL tightened to breakeven due to new opposite signal. Ticket: " + (string)ticket);
                trade.PositionModify(ticket, newSL, currentTP);
            }
            else if (positionType == POSITION_TYPE_SELL && currentSL > newSL)
            {
                LogTyped("SL_TIGHTENED", "SL tightened to breakeven due to new opposite signal. Ticket: " + (string)ticket);
                trade.PositionModify(ticket, newSL, currentTP);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| --- Main High-Risk Management Function ---                       |
//+------------------------------------------------------------------+
// This function orchestrates the new aggressive trade management logic.
// It should be called on every tick from the main EA file.
void ManageHighRiskPosition()
{
    if (!PositionSelect(_Symbol) || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return;

    ulong ticket = PositionGetInteger(POSITION_TICKET);
    double profit = PositionGetDouble(POSITION_PROFIT);
    double initialRisk = 0;
    g_initialRiskMap.TryGetValue(ticket, initialRisk);

    // --- Execute Management Logic ---
    ManageTrailingStop(ticket, profit);
    
    // Process intra-trade signals
    StrategySignal signals[];
    ValidateEntry(signals);
    StrategyFeedbackManager(signals);

    if(initialRisk > 0) {
        UpdateDynamicTP(ticket, profit, initialRisk);
        // Note: Legacy ExtendTakeProfit from main file might conflict, so we'll handle it carefully
    }
}

#endif // XAUUSD_M1_SCALPER_HIGHRISK_MANAGEMENT_MQH
