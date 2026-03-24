#ifndef XAUUSD_M1_SCALPER_RISK_MQH
#define XAUUSD_M1_SCALPER_RISK_MQH

double GetMinimumStopDistance()
  {
   int stopsLevelPoints = (int)SymbolInfoInteger(InpTradeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   double bufferPoints = 20.0;
   double minDistance = (stopsLevelPoints + bufferPoints) * _Point;
   if(minDistance <= 0.0)
      minDistance = 50.0 * _Point;
   return minDistance;
  }

double NormalizeStopDistance(const double requestedDistance)
  {
   return MathMax(requestedDistance, GetMinimumStopDistance());
  }

double CalculateDynamicLotSize(const double stopDistance)
  {
   double normalizedStop = NormalizeStopDistance(stopDistance);
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskPct   = InpMaxRiskPercent;

   if(g_consecutiveLosses >= 2)
      riskPct *= 0.50;
   else if(g_consecutiveLosses == 1)
      riskPct *= 0.75;

   double riskAmount = equity * (riskPct / 100.0);
   double tickSize   = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0 || normalizedStop <= 0.0 || riskAmount <= 0.0)
      return 0.0;

   double moneyPerLot = (normalizedStop / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
      return 0.0;

   double rawLot = riskAmount / moneyPerLot;
   double finalLot = NormalizeVolume(rawLot);
   double minLot = SymbolInfoDouble(InpTradeSymbol, SYMBOL_VOLUME_MIN);
   if(minLot <= 0.0) minLot = 0.01;

   if(finalLot < minLot)
      return 0.0;

   return finalLot;
  }

bool HasSufficientMargin(const ENUM_POSITION_TYPE type,const double volume,const double entryPrice)
  {
   if(volume <= 0.0)
      return false;

   ENUM_ORDER_TYPE orderType = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double marginRequired = 0.0;
   if(!OrderCalcMargin(orderType, InpTradeSymbol, volume, entryPrice, marginRequired))
     {
      DebugPrint(StringFormat("OrderCalcMargin failed. Error=%d", GetLastError()));
      return false;
     }

   double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
   return (freeMargin >= marginRequired * 1.5);
  }

void ResetTradeMinuteCounterIfNeeded()
  {
   datetime now = TimeTradeServer();
   datetime currentMinute = now - (now % 60);
   if(currentMinute != g_tradeMinuteStamp)
     {
      g_tradeMinuteStamp = currentMinute;
      g_tradesThisMinute = 0;
     }
  }

bool IsCooldownActive()
  {
   datetime now = TimeTradeServer();

   if(InpCooldownSeconds > 0 && (now - g_lastTradeTime) < InpCooldownSeconds)
      return true;

   if(InpLossCooldownSeconds > 0 && g_lastLossTime > 0 && (now - g_lastLossTime) < InpLossCooldownSeconds)
      return true;

   return false;
  }

bool CanPlaceTrade(const DecisionContext &context,string &reason,double &entryPrice,double &stopDistance,double &lotSize)
  {
   reason = "";
   entryPrice = (context.type == POSITION_TYPE_BUY) ? SymbolInfoDouble(InpTradeSymbol, SYMBOL_ASK)
                                                    : SymbolInfoDouble(InpTradeSymbol, SYMBOL_BID);

   if(!context.valid)
     {
      reason = context.reason;
      return false;
     }

   if(HasOpenPosition())
     {
      reason = "MAX_GLOBAL_TRADES_REACHED";
      return false;
     }

   ResetTradeMinuteCounterIfNeeded();
   if(g_tradesThisMinute >= InpMaxTradesPerMinute)
     {
      reason = "MAX_TRADES_PER_MINUTE";
      return false;
     }

   if(InpMaxConsecutiveLosses > 0 && g_consecutiveLosses >= InpMaxConsecutiveLosses)
     {
      reason = "MAX_CONSECUTIVE_LOSSES";
      return false;
     }

   if(IsCooldownActive())
     {
      reason = "COOLDOWN_ACTIVE";
      return false;
     }

   stopDistance = NormalizeStopDistance(context.atr * InpStopAtrMultiplier);
   lotSize = CalculateDynamicLotSize(stopDistance);
   if(lotSize <= 0.0)
     {
      reason = "LOT_SIZE_ZERO";
      return false;
     }

   if(!HasSufficientMargin(context.type, lotSize, entryPrice))
     {
      reason = "INSUFFICIENT_MARGIN";
      return false;
     }

   return true;
  }

#endif // XAUUSD_M1_SCALPER_RISK_MQH
