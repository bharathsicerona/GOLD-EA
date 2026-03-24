#ifndef XAUUSD_ADAPTIVE_RISK_MQH
#define XAUUSD_ADAPTIVE_RISK_MQH

string BuildStateKey(const string label,const ulong ticket)
  {
   return StringFormat("EA_%I64u_%s_%I64u",InpMagicNumber,label,ticket);
  }

string BuildGlobalKey(const string label)
  {
   return StringFormat("EA_%I64u_%s",InpMagicNumber,label);
  }

double NormalizeVolume(const double volume)
  {
   double minLot  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_STEP);

   if(minLot <= 0.0)  minLot = 0.01;
   if(maxLot <= 0.0)  maxLot = 100.0;
   if(lotStep <= 0.0) lotStep = 0.01;

   double normalized = MathFloor(volume / lotStep) * lotStep;
   if(normalized < minLot)
     {
      DebugPrint(StringFormat("Warning: Calculated lot (%.4f) < Min Lot (%.2f). Forcing Min Lot.", volume, minLot));
      normalized = minLot;
     }
   else if(normalized > maxLot)
     {
      DebugPrint(StringFormat("Warning: Calculated lot (%.2f) > Max Lot (%.2f). Capping to Max Lot.", normalized, maxLot));
      normalized = maxLot;
     }

   int digits = 2;
   if(lotStep == 0.001) digits = 3;
   if(lotStep == 0.1) digits = 1;
   if(lotStep == 1.0) digits = 0;
   return NormalizeDouble(normalized, digits);
  }

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

   double expectedLoss = finalLot * moneyPerLot;
   double actualRiskPercent = (expectedLoss / balance) * 100.0;

   DebugPrint(StringFormat("Lot Calc: Balance=%.2f, TargetRisk=%.2f, StopDist=%.1f, LossPerLot=%.2f, RawLot=%.5f, FinalLot=%.2f, ActualRisk=%.2f%%",
                           balance, riskAmount, stopDistance, moneyPerLot, rawLot, finalLot, actualRiskPercent));
   return finalLot;
  }

ulong NextTradeId()
  {
   string key = BuildGlobalKey("TradeCounter");
   double current = 0.0;
   if(GlobalVariableCheck(key))
      current = GlobalVariableGet(key);

   current += 1.0;
   GlobalVariableSet(key,current);
   return (ulong)current;
  }

#endif // XAUUSD_ADAPTIVE_RISK_MQH
