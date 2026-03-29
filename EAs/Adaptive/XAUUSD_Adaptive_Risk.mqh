#ifndef XAUUSD_ADAPTIVE_RISK_MQH
#define XAUUSD_ADAPTIVE_RISK_MQH

#include "../Include/GoldEA_Unified_Risk.mqh"

double CalculateLotSize(const double stopDistance,const double riskPercent)
  {
   if(stopDistance <= 0.0)
     {
      DebugPrint("Error: Invalid Stop Loss distance. Distance is 0.");
      return 0.0;
     }

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPercent / 100.0);
   double tickSize   = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
     {
      DebugPrint(StringFormat("Error: Invalid parameters. TickValue: %f, TickSize: %f", tickValue, tickSize));
      return 0.0;
     }

   double moneyPerLot = (stopDistance / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
     {
      DebugPrint("Error: Calculated loss per lot is zero or negative.");
      return 0.0;
     }

   double rawLot = riskAmount / moneyPerLot;
   double finalLot = NormalizeVolume(rawLot);
   finalLot = MathMax(finalLot, 0.01);

   double expectedLoss = finalLot * moneyPerLot;
   double actualRiskPercent = (expectedLoss / balance) * 100.0;

   DebugPrint(StringFormat("Lot Calc: Balance=%.2f, TargetRisk=%.2f, StopDist=%.1f, LossPerLot=%.2f, RawLot=%.5f, FinalLot=%.2f, ActualRisk=%.2f%%",
                           balance, riskAmount, stopDistance, moneyPerLot, rawLot, finalLot, actualRiskPercent));
   return finalLot;
  }

#endif // XAUUSD_ADAPTIVE_RISK_MQH
