/*
================================================================================
# Gold EA - Unified Risk Engine (v2.0)
Fixed monetary stop-loss model used by both M1 and M5 EAs:
- 0.01 lot => $4 risk
- 0.02 lot => $8 risk
- 0.03 lot and above => 1% of account balance
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
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double volumeMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(volumeStep <= 0.0)
      return MathMax(lot, volumeMin);
   double normalizedLot = MathFloor(lot / volumeStep) * volumeStep;
   return MathMax(normalizedLot, volumeMin);
}

//+------------------------------------------------------------------+
//| M1 lot safety adjustment for small accounts.                     |
//+------------------------------------------------------------------+
double AdjustLotForM1(const double lot, const double balance)
{
   if(balance <= 200.0)
      return 0.01;
   return lot;
}

//+------------------------------------------------------------------+
//| Aligns SL/TP price to tick grid and broker minimum stop level.   |
//+------------------------------------------------------------------+
double NormalizeStop(const double price, const double openPrice, const ENUM_ORDER_TYPE orderType)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = _Point;

   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = stopsLevel * _Point;

   double normalizedPrice = MathFloor(price / tickSize) * tickSize;

   if(orderType == ORDER_TYPE_BUY)
     {
      double minSlPrice = openPrice - minStopDist;
      if(normalizedPrice > minSlPrice)
         normalizedPrice = minSlPrice;
     }
   else
     {
      double minSlPrice = openPrice + minStopDist;
      if(normalizedPrice < minSlPrice)
         normalizedPrice = minSlPrice;
     }

   return normalizedPrice;
}

//+------------------------------------------------------------------+
//| Computes SL distance in price terms from fixed monetary risk.     |
//+------------------------------------------------------------------+
double CalculateFixedSLDistance(const double lotSize, const double balance)
{
   if(lotSize <= 0.0 || balance <= 0.0)
      return 0.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0)
      return 0.0;

   double riskUSD = balance * 0.01;
   const double eps = 0.00001;
   if(MathAbs(lotSize - 0.01) <= eps)
      riskUSD = 4.0;
   else if(MathAbs(lotSize - 0.02) <= eps)
      riskUSD = 8.0;

   // risk = (distance / tickSize) * tickValue * lot
   // distance = risk * tickSize / (tickValue * lot)
   double slDistance = (riskUSD * tickSize) / (tickValue * lotSize);
   if(slDistance <= 0.0)
      return 0.0;

   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = stopsLevel * _Point;
   if(minStopDistance > 0.0 && slDistance < minStopDistance)
      slDistance = minStopDistance;

   return slDistance;
}

//+------------------------------------------------------------------+
//| Computes DYNAMIC SL distance for M1 Scalper ($3-$5 base range)    |
//+------------------------------------------------------------------+
double CalculateM1DynamicRisk(const double lotSize, const double atrDistance)
{
   if(lotSize <= 0.0 || atrDistance <= 0.0)
      return 0.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0)
      return 0.0;

   // 1. Calculate raw monetary risk based on ATR distance
   // Risk = (Distance / TickSize) * TickValue * LotSize
   double rawRiskUSD = (atrDistance / tickSize) * tickValue * lotSize;

   // 2. Define Clamped Range based on Lot Scaling (Base $3-$5 for 0.01 lot)
   double scaleFactor = lotSize / 0.01;
   double minRisk = 3.0 * scaleFactor;
   double maxRisk = 5.0 * scaleFactor;

   // 3. Apply Clamping
   double finalRiskUSD = MathMax(minRisk, MathMin(maxRisk, rawRiskUSD));

   // 4. Convert back to price distance
   // Distance = Risk * TickSize / (TickValue * Lot)
   double slDistance = (finalRiskUSD * tickSize) / (tickValue * lotSize);

   // 5. Final StopsLevel Check
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = stopsLevel * _Point;
   if(minStopDistance > 0.0 && slDistance < minStopDistance)
      slDistance = minStopDistance;

   return slDistance;
}

//+------------------------------------------------------------------+
//| Applies fixed-SL model to current trade parameters.              |
//| Keeps lot size selection unchanged; only SL is derived from lot. |
//+------------------------------------------------------------------+
bool CalculateTradeRisk(
   const ENUM_ORDER_TYPE orderType,
   const double openPrice,
   double &lotSize,
   double &stopLoss,
   const double atrDistance = -1.0) // If > 0, use M1 Dynamic Risk
{
   lotSize = NormalizeLot(lotSize);
   if(lotSize <= 0.0)
     {
      Print("RISK ENGINE: Invalid lot size. Trade aborted.");
      return false;
     }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double slDistance = 0.0;
   
   if (atrDistance > 0)
      slDistance = CalculateM1DynamicRisk(lotSize, atrDistance);
   else
      slDistance = CalculateFixedSLDistance(lotSize, balance);
      
   if(slDistance <= 0.0)
     {
      Print("RISK ENGINE: Failed to compute SL distance. Trade aborted.");
      return false;
     }

   stopLoss = (orderType == ORDER_TYPE_BUY) ? (openPrice - slDistance) : (openPrice + slDistance);
   stopLoss = NormalizeStop(stopLoss, openPrice, orderType);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double finalRisk = 0.0;
   if(tickValue > 0.0 && tickSize > 0.0)
      finalRisk = (MathAbs(openPrice - stopLoss) / tickSize) * tickValue * lotSize;

   PrintFormat("RISK LOG: Dynamic monetary SL applied. Lot=%.2f ATR_Dist=%.2f SL=%.2f Risk=$%.2f",
               lotSize, atrDistance, stopLoss, finalRisk);
   return true;
}

#endif // GOLD_EA_UNIFIED_RISK_MQH
