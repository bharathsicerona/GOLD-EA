#ifndef XAUUSD_M1_SCALPER_RISK_MQH
#define XAUUSD_M1_SCALPER_RISK_MQH

// --- Helper Functions ---
double GetMinimumStopDistance()
{
    int stopsLevelPoints = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    return (stopsLevelPoints + 20) * _Point; // 2-pip buffer
}

double NormalizeStopDistance(const double requestedDistance)
{
    return MathMax(requestedDistance, GetMinimumStopDistance());
}

//+------------------------------------------------------------------+
//| CalculateHighRiskLotSize - New Lot Sizing Logic                  |
//+------------------------------------------------------------------+
double CalculateHighRiskLotSize(const double stopDistanceInPrice)
{
    // --- 1. Determine Risk Percentage ---
    double riskPercent = InpEnableHighRiskMode ? InpHighRiskPercent : 2.0; // Default to 2% if high-risk mode is off

    // --- 2. Calculate Risk Amount ---
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = equity * (riskPercent / 100.0);

    // --- 3. Calculate Lot Size ---
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

    if (tickValue <= 0 || stopDistanceInPrice <= 0) return 0.0;

    double costPerLot = (stopDistanceInPrice / tickSize) * tickValue;
    if (costPerLot <= 0.0) return 0.0;

    double rawLot = riskAmount / costPerLot;

    // --- 4. Handle Broker Volume Limits & User Preference ---
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    // Normalize the raw lot size according to the lot step
    double normalizedLot = lotStep * floor(rawLot / lotStep);

    if (normalizedLot < minLot)
    {
        if (InpMinLotAction == MIN_LOT_FORCE)
        {
            // Use broker's minimum lot, but only if it doesn't exceed max lot
            return (minLot > maxLot) ? 0.0 : minLot;
        }
        else // MIN_LOT_SKIP
        {
            DebugPrint(StringFormat("Lot size (%.2f) is below minimum (%.2f). Skipping trade.", normalizedLot, minLot));
            return 0.0;
        }
    }

    // Clamp to max lot size
    if (normalizedLot > maxLot)
    {
        normalizedLot = maxLot;
    }

    return normalizedLot;
}


// --- Margin and Cooldown Checks (Largely unchanged) ---
bool HasSufficientMargin(const ENUM_POSITION_TYPE type, const double volume, const double entryPrice)
{
    if (volume <= 0.0) return false;
    double marginRequired = 0.0;
    if (!OrderCalcMargin((type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, volume, entryPrice, marginRequired))
    {
        return false;
    }
    return (AccountInfoDouble(ACCOUNT_MARGIN_FREE) >= marginRequired * 1.5);
}

bool IsCooldownActive()
{
    datetime now = TimeTradeServer();
    if (g_lastLossTime > 0 && InpCooldownAfterLoss > 0 && (now - g_lastLossTime) < InpCooldownAfterLoss)
    {
        return true;
    }
    return false;
}

#endif // XAUUSD_M1_SCALPER_RISK_MQH
