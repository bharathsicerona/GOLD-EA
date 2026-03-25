/*
================================================================================
# Gold EA - Unified Risk Engine (v1.0)
This module provides a centralized, scalable risk management system for all
GoldEA trading strategies. It enforces strict capital protection rules
while allowing strategies to define their own entry/exit logic.

## Core Logic
1.  **Fixed Risk for Minimum Lot (0.01):**
    - Any trade with the minimum lot size (0.01) is capped at a maximum
      risk of $10.
    - If the initial Stop Loss implies a risk greater than $10, the SL
      distance is automatically reduced to meet the cap.
    - If the adjusted SL is too close to the entry price (violating broker
      minimums), the trade is aborted.

2.  **Dynamic Percentage Risk (Lots > 0.01):**
    - For any lot size greater than the minimum, the system calculates a lot
      size corresponding to a fixed percentage of the account balance (e.g., 1%).
    - This ensures risk scales with the account, protecting capital during
      drawdowns and compounding returns during growth.

This unified approach ensures consistent risk behavior across all EAs.
================================================================================
*/
#ifndef GOLD_EA_UNIFIED_RISK_MQH
#define GOLD_EA_UNIFIED_RISK_MQH

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Normalizes a lot size to conform to symbol's volume rules.       |
//+------------------------------------------------------------------+
double NormalizeLot(const double lot)
{
    double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double normalized_lot = floor(lot / volume_step) * volume_step;
    return(MathMax(normalized_lot, volume_min));
}

//+------------------------------------------------------------------+
//| Aligns SL/TP price to the correct tick size and broker distance. |
//+------------------------------------------------------------------+
double NormalizeStop(const double price, const double open_price, const ENUM_ORDER_TYPE order_type)
{
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double min_stop_dist = stops_level * _Point;

    // First, align the price to the tick grid
    double normalized_price = floor(price / tick_size) * tick_size;

    // Then, ensure it respects the minimum stop distance from the open price
    if (order_type == ORDER_TYPE_BUY)
    {
        double min_sl_price = open_price - min_stop_dist;
        if (normalized_price > min_sl_price)
        {
            normalized_price = min_sl_price;
        }
    }
    else // ORDER_TYPE_SELL
    {
        double min_sl_price = open_price + min_stop_dist;
        if (normalized_price < min_sl_price)
        {
            normalized_price = min_sl_price;
        }
    }

    return normalized_price;
}

//+------------------------------------------------------------------+
//| The core risk calculation and trade parameter adjustment engine. |
//| Modifies lotSize and stopLoss by reference based on risk rules.  |
//| Returns 'false' if the trade should be aborted.                  |
//+------------------------------------------------------------------+
bool CalculateTradeRisk(
    const ENUM_ORDER_TYPE orderType,
    const double openPrice,
    double &lotSize,
    double &stopLoss)
{
    // --- Get Symbol & Account Information ---
    const double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    const double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    const double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    const double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    const long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    const double minStopDistancePoints = stopsLevel * _Point;

    // Ensure initial stopLoss is not zero or invalid
    if (stopLoss <= 0)
    {
        Print("RISK ENGINE: Invalid initial Stop Loss provided. Trade aborted.");
        return false;
    }

    // --- RULE 1: Fixed Risk for Minimum Lot Size ---
    if (lotSize == minLot)
    {
        const double maxRiskDollars = 10.0;
        double slDistancePrice = MathAbs(openPrice - stopLoss);
        double riskInMoney = (slDistancePrice / tickSize) * tickValue * lotSize;

        if (riskInMoney > maxRiskDollars)
        {
            // SL implies too much risk. We must reduce the SL distance.
            double newSlDistancePrice = (maxRiskDollars * tickSize) / (tickValue * lotSize);

            // Check if this new SL is valid (not too close)
            if (newSlDistancePrice < minStopDistancePoints)
            {
                PrintFormat("RISK ENGINE: Fixed $10 cap cannot be applied. Required SL distance %.5f is less than broker minimum %.5f. Trade aborted.", newSlDistancePrice, minStopDistancePoints);
                return false;
            }

            // Adjust the Stop Loss to meet the $10 cap
            double oldStopLoss = stopLoss;
            stopLoss = (orderType == ORDER_TYPE_BUY) ? openPrice - newSlDistancePrice : openPrice + newSlDistancePrice;
            stopLoss = NormalizeStop(stopLoss, openPrice, orderType);
            riskInMoney = (MathAbs(openPrice - stopLoss) / tickSize) * tickValue * lotSize; // Recalculate with new SL

            PrintFormat("RISK LOG: Rule 'Fixed $10 cap' applied. SL adjusted from %.2f to %.2f. Lot: %.2f, Risk: $%.2f", oldStopLoss, stopLoss, lotSize, riskInMoney);
        }
        else
        {
            // Risk is already under the cap, no adjustment needed.
            PrintFormat("RISK LOG: Rule 'Fixed $10 cap' checked. Within limit. Lot: %.2f, SL: %.2f, Risk: $%.2f", lotSize, stopLoss, riskInMoney);
        }
        return true;
    }

    // --- RULE 2: Dynamic Risk for Lot Sizes > MinLot ---
    // The lot size itself will be recalculated based on 1% risk.
    const double riskPercent = 0.01; // 1%
    const double riskAmount = accountBalance * riskPercent;
    
    double slDistancePrice = MathAbs(openPrice - stopLoss);
    if (slDistancePrice <= 0)
    {
        Print("RISK ENGINE: Stop Loss distance is zero. Cannot calculate dynamic lot size. Trade aborted.");
        return false;
    }

    // Calculate the required lot size for 1% risk
    double riskPerLot = (slDistancePrice / tickSize) * tickValue;
    double calculatedLot = riskAmount / riskPerLot;

    // Normalize the lot and update the reference
    lotSize = NormalizeLot(calculatedLot);

    // If calculated lot is less than min lot, use min lot and re-run logic.
    if (lotSize < minLot)
    {
       lotSize = minLot;
       // We call the function again to apply the fixed $10 rule correctly
       return CalculateTradeRisk(orderType, openPrice, lotSize, stopLoss);
    }

    double finalRiskInMoney = (slDistancePrice / tickSize) * tickValue * lotSize;
    PrintFormat("RISK LOG: Rule '1%% dynamic risk' applied. Account Balance: $%.2f, Risk Target: $%.2f. Calculated Lot: %.2f, SL: %.2f, Final Risk: $%.2f", 
                accountBalance, riskAmount, lotSize, stopLoss, finalRiskInMoney);

    return true;
}

#endif // GOLD_EA_UNIFIED_RISK_MQH
