#ifndef XAUUSD_M1_SCALPER_MANAGEMENT_MQH
#define XAUUSD_M1_SCALPER_MANAGEMENT_MQH

void ManageOpenPosition(const bool isNewBar)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != InpTradeSymbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSl   = PositionGetDouble(POSITION_SL);
      double currentTp   = PositionGetDouble(POSITION_TP);
      double volume      = PositionGetDouble(POSITION_VOLUME);
      double profitMoney = PositionGetDouble(POSITION_PROFIT);
      double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
      double currentPrice= (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(InpTradeSymbol, SYMBOL_BID) : SymbolInfoDouble(InpTradeSymbol, SYMBOL_ASK);
      
      double tickSize    = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue   = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_VALUE);
      
      if(tickSize <= 0.0 || tickValue <= 0.0 || volume <= 0.0) continue;

      double atrValue;
      if(!GetIndicatorValue(g_atrHandle, 0, atrValue)) continue;

      // --- 1. Evaluate Profit Lock (Lock 1% if >= 5%) ---
      double triggerTarget = balance * (InpProfitLockTriggerPct / 100.0);
      double lockTarget    = balance * (InpProfitLockTargetPct / 100.0);
      double lockPriceDiff = (lockTarget * tickSize) / (tickValue * volume);
      
      double lockSlPrice = 0.0;
      bool isLocked = false;

      if(type == POSITION_TYPE_BUY)
        {
         lockSlPrice = NormalizeDouble(openPrice + lockPriceDiff, g_symbolDigits);
         if(currentSl >= lockSlPrice) isLocked = true; // Already locked
        }
      else
        {
         lockSlPrice = NormalizeDouble(openPrice - lockPriceDiff, g_symbolDigits);
         if(currentSl <= lockSlPrice && currentSl != 0.0) isLocked = true; // Already locked
        }

      bool modified = false;
      if(!isLocked && profitMoney >= triggerTarget)
        {
         if(trade.PositionModify(ticket, lockSlPrice, currentTp))
           {
            DebugPrint(StringFormat("Account profit lock moved for ticket=%I64u", ticket));
            string reasonStr = StringFormat("PROFIT_$%.2f_SL_%.2f", profitMoney, lockSlPrice);
            LogToCSV("ACCOUNT_PROFIT_LOCK",SessionToString(GetCurrentSession()),"TRADE_MGMT",currentPrice,0,0,0,atrValue,0,0,PositionTypeText(type),reasonStr);
            modified = true;
            isLocked = true;
            currentSl = lockSlPrice;
           }
        }

      // --- 2. ATR Trailing Stop (Only active AFTER profit lock) ---
      if(isLocked && !modified && isNewBar)
        {
         double trailStep = atrValue * InpTrailStepAtr;
         double minUpdateDistance = atrValue * 0.2;
         double trailedSl = currentSl;
         bool validTrail = false;

         if(type == POSITION_TYPE_BUY)
           {
            double candidate = NormalizeDouble(currentPrice - (atrValue * InpTrailAtrMultiplier), g_symbolDigits);
            candidate = MathMax(candidate, lockSlPrice); // Never drop below profit lock
            if(candidate >= currentSl + trailStep && (candidate - currentSl) >= minUpdateDistance)
              {
               trailedSl = candidate;
               validTrail = true;
              }
           }
         else
           {
            double candidate = NormalizeDouble(currentPrice + (atrValue * InpTrailAtrMultiplier), g_symbolDigits);
            candidate = MathMin(candidate, lockSlPrice); // Never rise above profit lock
            if((candidate <= currentSl - trailStep && (currentSl - candidate) >= minUpdateDistance) || currentSl == 0.0)
              {
               trailedSl = candidate;
               validTrail = true;
              }
           }

         if(validTrail && trailedSl > 0.0)
           {
            if(trade.PositionModify(ticket, trailedSl, currentTp))
              {
               DebugPrint(StringFormat("Trailing stop updated for ticket=%I64u", ticket));
               LogToCSV("TRAILING_UPDATED",SessionToString(GetCurrentSession()),"TRADE_MGMT",currentPrice,0,0,0,atrValue,0,0,PositionTypeText(type),"TRAILING_STOP_MOVED");
              }
           }
        }
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal <= 0)
      return;

   if(!HistoryDealSelect(trans.deal))
      return;

   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != InpTradeSymbol)
      return;

   if((ulong)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagicNumber)
      return;

   ENUM_DEAL_ENTRY entryType = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entryType != DEAL_ENTRY_OUT)
      return;

   double netProfit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                    + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   if(netProfit < 0.0)
     {
      g_consecutiveLosses++;
      g_lastLossTime = TimeTradeServer();
      DebugPrint(StringFormat("Loss recorded. Consecutive losses=%d net=%.2f", g_consecutiveLosses, netProfit));
      Print(StringFormat("[GoldEA-M1] TRADE_RESULT: LOSS profit=%.2f", netProfit));
     }
   else if(netProfit > 0.0)
     {
      g_consecutiveLosses = 0;
      DebugPrint(StringFormat("Winning trade recorded. Consecutive losses reset. net=%.2f", netProfit));
      Print(StringFormat("[GoldEA-M1] TRADE_RESULT: WIN profit=%.2f", netProfit));
     }
   else
     {
      Print(StringFormat("[GoldEA-M1] TRADE_RESULT: BREAKEVEN profit=%.2f", netProfit));
     }
  }

#endif // XAUUSD_M1_SCALPER_MANAGEMENT_MQH
