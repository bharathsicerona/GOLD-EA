#ifndef XAUUSD_ADAPTIVE_MANAGEMENT_MQH
#define XAUUSD_ADAPTIVE_MANAGEMENT_MQH

//=============================================================================
// CHANGELOG
// Version 2.1 (EA Log Tagging)
// * Added EA_TYPE input to uniquely identify M1 vs M5 EA instances.
// * Implemented Log() wrapper function for unified console output.
// * Replaced all Print(), PrintFormat(), and DebugPrint() calls with Log().
// * Structured TRADE_RESULT logs to include ticket and profit= values for parsing.
//=============================================================================

// Note: EA_TYPE must now be defined in the main .mq5 files before #include

void Log(string message)
{
   Print("[" + EA_TYPE + "][GoldEA] " + message);
}

void LogTyped(string type, string message)
{
   Print("[" + EA_TYPE + "][GoldEA][" + type + "] " + message);
}

int totalSignals = 0;
int totalTrades = 0;
int totalSkipped = 0;
int totalWins = 0;
int totalLosses = 0;
int rejectLowScore = 0;
int rejectSpread = 0;
int rejectMargin = 0;
int rejectSession = 0;
int rejectCooldown = 0;
int rejectMaxTrades = 0;
int rejectOther = 0;
const int STATS_PRINT_INTERVAL = 10;

string NormalizeRejectReason(const string rawReason)
{
   string u = rawReason;
   StringToUpper(u);
   if(StringFind(u, "SPREAD") >= 0) return "HIGH_SPREAD";
   if(StringFind(u, "SCORE") >= 0) return "LOW_SCORE";
   if(StringFind(u, "SESSION") >= 0 || StringFind(u, "ASIAN") >= 0) return "SESSION_BLOCK";
   if(StringFind(u, "COOLDOWN") >= 0) return "COOLDOWN_ACTIVE";
   if(StringFind(u, "MAX") >= 0 || StringFind(u, "DUPLICATE") >= 0) return "MAX_TRADES_REACHED";
   if(StringFind(u, "MARGIN") >= 0 || StringFind(u, "LOT_SIZE_ZERO") >= 0) return "INSUFFICIENT_MARGIN";
   if(StringFind(u, "VALID") >= 0 || StringFind(u, "READY") >= 0 || StringFind(u, "EXECUTED") >= 0) return "VALID";
   return "OTHER";
}

void CountRejection(const string reasonCode)
{
   if(reasonCode == "LOW_SCORE") rejectLowScore++;
   else if(reasonCode == "HIGH_SPREAD") rejectSpread++;
   else if(reasonCode == "INSUFFICIENT_MARGIN") rejectMargin++;
   else if(reasonCode == "SESSION_BLOCK") rejectSession++;
   else if(reasonCode == "COOLDOWN_ACTIVE") rejectCooldown++;
   else if(reasonCode == "MAX_TRADES_REACHED") rejectMaxTrades++;
   else rejectOther++;
}

void LogRejection(const string side, const string reasonCode, const double lot, const double balance)
{
   totalSkipped++;
   CountRejection(reasonCode);
   LogTyped("REJECTION", StringFormat("%s rejected: reason=%s lot=%.2f balance=%.2f", side, reasonCode, lot, balance));
}

void LogStatsIfDue()
{
   if(totalTrades <= 0 || (totalTrades % STATS_PRINT_INTERVAL) != 0)
      return;
   LogTyped("STATS", StringFormat("signals=%d trades=%d skipped=%d win=%d loss=%d",
                                  totalSignals, totalTrades, totalSkipped, totalWins, totalLosses));
   LogTyped("STATS", StringFormat("lowScore=%d spread=%d margin=%d session=%d cooldown=%d maxTrades=%d other=%d",
                                  rejectLowScore, rejectSpread, rejectMargin, rejectSession, rejectCooldown, rejectMaxTrades, rejectOther));
}

int CountPositions(const ENUM_POSITION_TYPE positionType)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != InpTradeSymbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == positionType)
         count++;
     }
   return count;
  }

bool HasOpenPosition()
  {
   return (CountPositions(POSITION_TYPE_BUY) + CountPositions(POSITION_TYPE_SELL)) >= InpMaxOpenPositionsTotal;
  }

bool HasBuyPosition()
  {
   return CountPositions(POSITION_TYPE_BUY) >= InpMaxConcurrentTrades;
  }

bool HasSellPosition()
  {
   return CountPositions(POSITION_TYPE_SELL) >= InpMaxConcurrentTrades;
  }

ulong FindPositionTicket(const ENUM_POSITION_TYPE positionType)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != InpTradeSymbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == positionType)
         return ticket;
     }
   return 0;
  }

ulong FindPositionTicketByComment(const string commentText)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != InpTradeSymbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_COMMENT) == commentText)
         return ticket;
     }
   return 0;
  }

bool ExecuteTrade(const DecisionContext &context)
  {
   if(!context.valid)
      return false;

   if(HasOpenPosition())
     {
      int totalCount = CountPositions(POSITION_TYPE_BUY) + CountPositions(POSITION_TYPE_SELL);
      LogRejection(context.decision, "MAX_TRADES_REACHED", 0.0, AccountInfoDouble(ACCOUNT_BALANCE));
      LogTyped("REJECTION", StringFormat("blocked existing position count=%d", totalCount));
      LogToCSV("TRADE_BLOCKED",context.sessionName,context.strategyName,context.price,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,"MAX_GLOBAL_POSITIONS");
      return false;
     }

   double entryPrice = (context.type == POSITION_TYPE_BUY) ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK) : SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
   double lotSizingDistance = context.atr * InpStopAtrMultiplier; // kept only for existing lot selection behavior

   double lot = CalculateLotSize(lotSizingDistance, context.riskPercent);
   if(lot <= 0.0)
     {
      LogRejection(context.decision, "INSUFFICIENT_MARGIN", lot, AccountInfoDouble(ACCOUNT_BALANCE));
      LogTyped("REJECTION", "Trade skipped because lot calculation returned 0.");
      LogToCSV("TRADE_SKIPPED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,"LOT_SIZE_ZERO");
      return false;
     }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickSize   = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
     {
      LogRejection(context.decision, "OTHER", lot, balance);
      LogTyped("REJECTION", "Trade skipped because tick size/value is invalid for fixed risk model.");
      LogToCSV("TRADE_SKIPPED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,"INVALID_TICK_VALUE");
      return false;
     }

   double riskDistance = CalculateFixedSLDistance(lot, balance);
   if(riskDistance <= 0.0)
     {
      LogRejection(context.decision, "OTHER", lot, balance);
      LogTyped("REJECTION", "Trade skipped because fixed monetary SL distance is invalid.");
      LogToCSV("TRADE_SKIPPED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,"FIXED_SL_INVALID");
      return false;
     }

   // M5 structured risk: for 0.01 lot, enforce $10 stop risk.
   if(lot <= 0.0100001)
     {
      double m5RiskUsd = 10.0;
      double customDistance = (m5RiskUsd * tickSize) / (tickValue * lot);
      if(customDistance <= 0.0)
        {
         LogRejection(context.decision, "OTHER", lot, balance);
         LogTyped("REJECTION", "Trade skipped because custom M5 risk distance is invalid.");
         LogToCSV("TRADE_SKIPPED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,"M5_CUSTOM_RISK_INVALID");
         return false;
        }
      riskDistance = customDistance;
     }

   double moneyPerLot = (riskDistance / tickSize) * tickValue;
   double expectedLoss = lot * moneyPerLot;

   double actualRiskPercent = (expectedLoss / balance) * 100.0;
   double tpMultiple = 3.0;
   double tpDistance = riskDistance * tpMultiple;
   double sl = 0.0;
   double tp = 0.0;

   if(context.type == POSITION_TYPE_BUY)
     {
      sl = NormalizeStop(entryPrice - riskDistance, entryPrice, ORDER_TYPE_BUY);
      tp = NormalizeDouble(entryPrice + tpDistance,g_symbolDigits);
     }
   else if(context.type == POSITION_TYPE_SELL)
     {
      sl = NormalizeStop(entryPrice + riskDistance, entryPrice, ORDER_TYPE_SELL);
      tp = NormalizeDouble(entryPrice - tpDistance,g_symbolDigits);
     }

   ulong tradeId = NextTradeId();
   string commentText = StringFormat("GoldEA#%I64u %s",tradeId,context.decision);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);

   bool success = false;
   if(context.type == POSITION_TYPE_BUY)
      success = trade.Buy(lot,InpTradeSymbol,0.0,sl,tp,commentText);
   else if(context.type == POSITION_TYPE_SELL)
      success = trade.Sell(lot,InpTradeSymbol,0.0,sl,tp,commentText);

   if(!success)
     {
      string failReason = StringFormat("ORDER_FAILED_%d_%s",trade.ResultRetcode(),trade.ResultRetcodeDescription());
      LogRejection(context.decision, "OTHER", lot, balance);
      LogTyped("REJECTION", StringFormat("%s order failed: %s",context.decision,failReason));
      LogToCSV(context.decision + "_FAILED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,failReason);
      return false;
     }

   ulong ticket = 0;
   ulong resultDeal = trade.ResultDeal();
   if(resultDeal > 0 && HistoryDealSelect(resultDeal))
      ticket = (ulong)HistoryDealGetInteger(resultDeal,DEAL_POSITION_ID);
   if(ticket == 0)
      ticket = FindPositionTicketByComment(commentText);
   if(ticket == 0)
      ticket = FindPositionTicket(context.type);

   if(ticket > 0)
     {
      GlobalVariableSet(BuildStateKey("initrisk",ticket),riskDistance);
      GlobalVariableSet(BuildStateKey("partial",ticket),0.0);
      GlobalVariableSet(BuildStateKey("minprofit",ticket),0.0);
      GlobalVariableSet(BuildStateKey("acclock",ticket),0.0);
      GlobalVariableSet(BuildStateKey("tradeid",ticket),(double)tradeId);
      GlobalVariableSet(BuildStateKey("M5TrailLevel", ticket), 0); // Initialize R-Multiple Trail Level
     }

   if(context.type == POSITION_TYPE_BUY)
      g_lastBuyBar = g_lastBarTime;
   else if(context.type == POSITION_TYPE_SELL)
      g_lastSellBar = g_lastBarTime;
   g_lastTradeTime = TimeTradeServer();

   DrawTradeArrow(tradeId, context.type, context.isCounterTrend, entryPrice);
   totalTrades++;
   LogTyped("EXECUTION", StringFormat("%s executed: tradeId=%I64u lot=%.2f entry=%.2f sl=%.2f tp=%.2f score=%d",
                                      context.decision, tradeId, lot, entryPrice, sl, tp, context.score));
   LogToCSV(context.decision + "_EXECUTED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema200,context.atr,context.spread,context.score,context.decision,StringFormat("TRADE_ID_%I64u",tradeId));

   if(InpEnablePushAlerts || InpEnableEmailAlerts)
     {
      string alertSubject = StringFormat("GoldEA %s %s Executed", context.strategyName, context.decision);
      string alertMsg = StringFormat("Action: %s %s\nType: %s\nActual Risk: %.2f%%\nLot: %.2f\nEntry: %.2f\nSL: %.2f\nTP Dist: %.2f points\nTP R: %.1f\nScore: %d",
                                     context.decision, InpTradeSymbol, context.strategyName, actualRiskPercent, lot, entryPrice, sl, tpDistance / _Point, tpMultiple, context.score);
      if(InpEnablePushAlerts) SendNotification(alertSubject + "\n" + alertMsg);
      if(InpEnableEmailAlerts) SendMail(alertSubject, alertMsg);
     }

   return true;
  }

void ManageTrade(const ulong ticket,const bool isNewBar)
  {
   if(!PositionSelectByTicket(ticket))
      return;
   if(PositionGetString(POSITION_SYMBOL) != InpTradeSymbol)
      return;
   if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return;

   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice        = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSl        = PositionGetDouble(POSITION_SL);
   double currentTp        = PositionGetDouble(POSITION_TP);
   double volume           = PositionGetDouble(POSITION_VOLUME);
   double profitMoney      = PositionGetDouble(POSITION_PROFIT);
   double balance          = AccountInfoDouble(ACCOUNT_BALANCE);

   IndicatorSnapshot snapshot;
   if(!CalculateIndicators(snapshot,0))
      return;

   double initialRisk = 0.0;
   string riskKey = BuildStateKey("initrisk",ticket);
   if(GlobalVariableCheck(riskKey))
      initialRisk = GlobalVariableGet(riskKey);
   if(initialRisk <= 0.0)
      initialRisk = MathAbs(openPrice - currentSl);
   if(initialRisk <= 0.0)
      return;

   double priceNow = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID)
                                                 : SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK);
   double profitDistance = (type == POSITION_TYPE_BUY) ? (priceNow - openPrice)
                                                       : (openPrice - priceNow);
   double rMultiple = profitDistance / initialRisk;
   const bool allowStopLossUpdates = false; // Keep legacy blocks disabled; custom M5 trailing below is active.

   // --- M5 R-Multiple Trailing Stop System ---
   string trailLevelKey = BuildStateKey("M5TrailLevel", ticket);
   if (GlobalVariableCheck(trailLevelKey))
   {
       int currentTrailLevel = (int)GlobalVariableGet(trailLevelKey);
       int desiredTrailLevel = currentTrailLevel;

       // Determine the highest trail level the trade currently qualifies for
       if (rMultiple >= 2.0) desiredTrailLevel = 2;
       else if (rMultiple >= 1.0) desiredTrailLevel = 1;

       // If the trade qualifies for a higher level than it's currently on
       if (desiredTrailLevel > currentTrailLevel)
       {
           double newSL_R = 0.0;
           // Get the target SL in R-terms based on the desired level
           if (desiredTrailLevel == 1) newSL_R = 0.2; // At 1.0R profit, move SL to +0.2R
           if (desiredTrailLevel == 2) newSL_R = 1.0; // At 2.0R profit, move SL to +1.0R

           double newSlPrice = 0.0;
           if (type == POSITION_TYPE_BUY)
               newSlPrice = NormalizeDouble(openPrice + (initialRisk * newSL_R), g_symbolDigits);
           else // SELL
               newSlPrice = NormalizeDouble(openPrice - (initialRisk * newSL_R), g_symbolDigits);

           // Check if the new SL is a valid improvement
           bool isImproved = (type == POSITION_TYPE_BUY && newSlPrice > currentSl) ||
                             (type == POSITION_TYPE_SELL && newSlPrice < currentSl);
           
           if (isImproved)
           {
               if (trade.PositionModify(ticket, newSlPrice, currentTp))
               {
                   GlobalVariableSet(trailLevelKey, desiredTrailLevel);
                   string logReason = StringFormat("PROFIT_%.2fR_SL_TO_+%.2fR", rMultiple, newSL_R);
                   Log(StringFormat("[MGMT][TRAIL] M5 R-Multiple Profit reached %.2fR. Moving SL to +%.2fR (New SL: %.2f, Level: %d)", rMultiple, newSL_R, newSlPrice, desiredTrailLevel));
                   LogToCSV("M5_R_TRAIL_UPDATE", SessionToString(snapshot.session), "TRADE_MGMT", priceNow, snapshot.rsi, snapshot.fastEma, snapshot.slowEma, snapshot.atr, snapshot.spread, desiredTrailLevel, PositionTypeText(type), logReason);
               }
           }
           else
           {
               // If the SL is not an improvement but the level is, update the level to prevent re-calculation.
               // This can happen if another trailing stop system has already moved the SL further.
               GlobalVariableSet(trailLevelKey, desiredTrailLevel);
           }
       }
   }
   // --- End of M5 R-Multiple Trailing Stop ---

   string accLockKey = BuildStateKey("acclock",ticket);
   bool isAccLockActive = (GlobalVariableCheck(accLockKey) && GlobalVariableGet(accLockKey) >= 1.0);
   if(allowStopLossUpdates && !isAccLockActive && InpAccountProfitLockTriggerPercent > 0.0)
     {
      double triggerMoney = balance * (InpAccountProfitLockTriggerPercent / 100.0);
      if(profitMoney >= triggerMoney)
        {
         double targetMoney = balance * (InpAccountProfitLockTargetPercent / 100.0);
         double tickSize   = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_SIZE);
         double tickValue  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_VALUE);
         if(tickSize > 0.0 && tickValue > 0.0 && volume > 0.0)
           {
            double priceDiff = (targetMoney * tickSize) / (tickValue * volume);
            double newSl = 0.0;
            bool needsBeModify = false;
            if(type == POSITION_TYPE_BUY)
              {
               newSl = NormalizeDouble(openPrice + priceDiff, g_symbolDigits);
               if(currentSl < newSl || currentSl == 0.0) needsBeModify = true;
              }
            else if(type == POSITION_TYPE_SELL)
              {
               newSl = NormalizeDouble(openPrice - priceDiff, g_symbolDigits);
               if(currentSl > newSl || currentSl == 0.0) needsBeModify = true;
              }

            if(needsBeModify)
              {
               if(trade.PositionModify(ticket,newSl,currentTp))
                 {
                  GlobalVariableSet(accLockKey,1.0);
                  Log(StringFormat("[MGMT][LOCK] Account profit lock moved for ticket=%I64u",ticket));
                  string reasonStr = StringFormat("PROFIT_$%.2f_SL_%.2f", profitMoney, newSl);
                  LogToCSV("ACCOUNT_PROFIT_LOCK",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),reasonStr);
                 }
              }
            else
              {
               GlobalVariableSet(accLockKey,1.0);
              }
           }
        }
     }

   string trailStartKey = BuildStateKey("trailstart",ticket);
   bool isTrailActive = (GlobalVariableCheck(trailStartKey) && GlobalVariableGet(trailStartKey) >= 1.0);

   string lockKey = BuildStateKey("minprofit",ticket);
   if(allowStopLossUpdates && !isTrailActive && profitDistance >= (snapshot.atr * InpBreakevenAtrMultiplier) && (!GlobalVariableCheck(lockKey) || GlobalVariableGet(lockKey) < 1.0))
     {
      bool needsBeModify = false;
      double newSl = 0.0;
      if(type == POSITION_TYPE_BUY)
        {
         newSl = NormalizeDouble(openPrice + snapshot.atr * InpMinProfitLockAtr, g_symbolDigits);
         if(currentSl < newSl || currentSl == 0.0) needsBeModify = true;
        }
      else if(type == POSITION_TYPE_SELL)
        {
         newSl = NormalizeDouble(openPrice - snapshot.atr * InpMinProfitLockAtr, g_symbolDigits);
         if(currentSl > newSl || currentSl == 0.0) needsBeModify = true;
        }

      if(needsBeModify)
        {
         if(trade.PositionModify(ticket,newSl,currentTp))
           {
            GlobalVariableSet(lockKey,1.0);
                  Log(StringFormat("[MGMT][LOCK] Minimal profit lock moved for ticket=%I64u",ticket));
            string reasonStr = StringFormat("PROFIT_%.2f_SL_%.2f", profitDistance, newSl);
            LogToCSV("MIN_PROFIT_LOCK_TRIGGERED",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),reasonStr);
           }
        }
      else
        {
         GlobalVariableSet(lockKey,1.0);
        }
     }



   if(allowStopLossUpdates && !isTrailActive && (profitDistance >= snapshot.atr * InpTrailActivationAtrMultiplier || (GlobalVariableCheck(accLockKey) && GlobalVariableGet(accLockKey) >= 1.0)))
     {
      isTrailActive = true;
      GlobalVariableSet(trailStartKey,1.0);
      LogToCSV("TRAILING_STARTED",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),"PROFIT_REACHED_ACTIVATION");
     }

   if(allowStopLossUpdates && isTrailActive && isNewBar)
     {
      double trailedSl = currentSl;
      double trailStep = snapshot.atr * InpTrailStepAtrMultiplier;
      bool validTrailStep = false;
      if(type == POSITION_TYPE_BUY)
        {
         double candidate = NormalizeDouble(priceNow - snapshot.atr * InpTrailAtrMultiplier,g_symbolDigits);
         if(profitDistance >= snapshot.atr * InpProfitLockActivationAtr)
           {
            double profitLockSl = NormalizeDouble(openPrice + snapshot.atr * InpProfitLockAtr, g_symbolDigits);
            candidate = MathMax(candidate, profitLockSl);
           }
         if(candidate > trailedSl && candidate > openPrice)
            trailedSl = candidate;
         if(trailedSl >= currentSl + trailStep)
            validTrailStep = true;
        }
      else if(type == POSITION_TYPE_SELL)
        {
         double candidate = NormalizeDouble(priceNow + snapshot.atr * InpTrailAtrMultiplier,g_symbolDigits);
         if(profitDistance >= snapshot.atr * InpProfitLockActivationAtr)
           {
            double profitLockSl = NormalizeDouble(openPrice - snapshot.atr * InpProfitLockAtr, g_symbolDigits);
            candidate = MathMin(candidate, profitLockSl);
           }
         if((trailedSl == 0.0 || candidate < trailedSl) && candidate < openPrice)
            trailedSl = candidate;
         if(trailedSl <= currentSl - trailStep || currentSl == 0.0)
            validTrailStep = true;
        }

      if(validTrailStep && trailedSl > 0.0)
        {
         if(trade.PositionModify(ticket,trailedSl,currentTp))
           {
               Log(StringFormat("Trailing stop updated ticket=%I64u",ticket));
            LogToCSV("TRAILING_UPDATED",SessionToString(snapshot.session),"TRADE_MGMT",priceNow,snapshot.rsi,snapshot.fastEma,snapshot.slowEma,snapshot.atr,snapshot.spread,0,PositionTypeText(type),"TRAILING_STOP_MOVED");
           }
        }
     }
  }

void CleanupStateGlobals()
  {
   int total = GlobalVariablesTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      string gName = GlobalVariableName(i);
      string prefix = StringFormat("EA_%I64u_", InpMagicNumber);
      if(StringFind(gName, prefix) == 0)
        {
         if(StringFind(gName, "TradeCounter") > 0)
            continue;
         string parts[];
         if(StringSplit(gName, ushort('_'), parts) >= 4)
           {
            ulong ticket = StringToInteger(parts[3]);
            if(ticket > 0 && !PositionSelectByTicket(ticket))
               GlobalVariableDel(gName);
           }
        }
     }
  }

void ManageOpenTrades(const bool isNewBar)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      ManageTrade(ticket, isNewBar);
     }
  }

void EvaluateEntries()
  {
   IndicatorSnapshot entrySnapshot;
   if(!CalculateIndicators(entrySnapshot,1))
      return;

   DecisionContext buyContext = SelectAndRunStrategy(POSITION_TYPE_BUY,entrySnapshot,true);
   DecisionContext sellContext = SelectAndRunStrategy(POSITION_TYPE_SELL,entrySnapshot,true);
   buyContext.phase  = "BAR_CLOSE_SIGNAL";
   sellContext.phase = "BAR_CLOSE_SIGNAL";

   if(!InpAllowBuyTrades)
     {
      buyContext.valid = false;
      buyContext.reason = "BUY_DISABLED";
     }
   if(!InpAllowSellTrades)
     {
      sellContext.valid = false;
      sellContext.reason = "SELL_DISABLED";
     }
   if(HasOpenPosition())
     {
      buyContext.valid = false;
      buyContext.reason = "MAX_GLOBAL_TRADES_REACHED";
      sellContext.valid = false;
      sellContext.reason = "MAX_GLOBAL_TRADES_REACHED";
     }
   if(TimeTradeServer() - g_lastTradeTime < InpTradeCooldownSeconds)
     {
      buyContext.valid = false;
      buyContext.reason = "COOLDOWN_ACTIVE";
      sellContext.valid = false;
      sellContext.reason = "COOLDOWN_ACTIVE";
     }

   int buyCount = CountPositions(POSITION_TYPE_BUY);
   if(HasBuyPosition())
     {
      buyContext.valid = false;
      buyContext.reason = "MAX_BUY_TRADES_REACHED";
     }
   else if(buyCount > 0)
     {
      bool continuationOk = entrySnapshot.emaBullish && (entrySnapshot.adx > InpAdxThreshold) && entrySnapshot.adxIncreasing;
      if(!continuationOk) { buyContext.valid = false; buyContext.reason = "NO_CONTINUATION_TREND"; }
     }

   int sellCount = CountPositions(POSITION_TYPE_SELL);
   if(HasSellPosition())
     {
      sellContext.valid = false;
      sellContext.reason = "MAX_SELL_TRADES_REACHED";
     }
   else if(sellCount > 0)
     {
      bool continuationOk = entrySnapshot.emaBearish && (entrySnapshot.adx > InpAdxThreshold) && entrySnapshot.adxIncreasing;
      if(!continuationOk) { sellContext.valid = false; sellContext.reason = "NO_CONTINUATION_TREND"; }
     }

   if(g_lastBuyBar == g_lastBarTime)
     {
      buyContext.valid = false;
      buyContext.reason = "BUY_DUPLICATE_BLOCKED";
     }
   if(g_lastSellBar == g_lastBarTime)
     {
      sellContext.valid = false;
      sellContext.reason = "SELL_DUPLICATE_BLOCKED";
     }

   totalSignals++;
   totalSignals++;
   string buyReasonCode = buyContext.valid ? "VALID" : NormalizeRejectReason(buyContext.reason);
   string sellReasonCode = sellContext.valid ? "VALID" : NormalizeRejectReason(sellContext.reason);
   LogTyped("CHECK", StringFormat("[%s] BUY check: score=%d atr=%.5f spread=%d reason=%s",
                                  buyContext.strategyName, buyContext.score, entrySnapshot.atr, entrySnapshot.spread, buyReasonCode));
   LogTyped("CHECK", StringFormat("[%s] SELL check: score=%d atr=%.5f spread=%d reason=%s",
                                  sellContext.strategyName, sellContext.score, entrySnapshot.atr, entrySnapshot.spread, sellReasonCode));
   if(!buyContext.valid)
      LogRejection("BUY", buyReasonCode, 0.0, AccountInfoDouble(ACCOUNT_BALANCE));
   if(!sellContext.valid)
      LogRejection("SELL", sellReasonCode, 0.0, AccountInfoDouble(ACCOUNT_BALANCE));

   if(buyContext.valid && (!sellContext.valid || buyContext.score >= sellContext.score))
     {
      LogToCSV("BAR_CLOSE_SIGNAL",buyContext.sessionName,buyContext.strategyName,buyContext.price,buyContext.rsi,buyContext.ema50,buyContext.ema200,buyContext.atr,buyContext.spread,buyContext.score,buyContext.decision,buyContext.reason);
      ExecuteTrade(buyContext);
     }
   else if(sellContext.valid)
     {
      LogToCSV("BAR_CLOSE_SIGNAL",sellContext.sessionName,sellContext.strategyName,sellContext.price,sellContext.rsi,sellContext.ema50,sellContext.ema200,sellContext.atr,sellContext.spread,sellContext.score,sellContext.decision,sellContext.reason);
      ExecuteTrade(sellContext);
     }
  }

void EvaluateTickAndDashboard()
  {
   IndicatorSnapshot liveSnapshot;
   if(!CalculateIndicators(liveSnapshot,0))
      return;

   DecisionContext buyContext = SelectAndRunStrategy(POSITION_TYPE_BUY,liveSnapshot,false);
   DecisionContext sellContext = SelectAndRunStrategy(POSITION_TYPE_SELL,liveSnapshot,false);
   buyContext.phase  = "LIVE_PREVIEW";
   sellContext.phase = "LIVE_PREVIEW";

   if(!InpAllowBuyTrades)
     {
      buyContext.valid = false;
      buyContext.reason = "BUY_DISABLED";
     }
   if(!InpAllowSellTrades)
     {
      sellContext.valid = false;
      sellContext.reason = "SELL_DISABLED";
     }
   if(HasOpenPosition())
     {
      buyContext.valid = false;
      buyContext.reason = "MAX_GLOBAL_TRADES_REACHED";
      sellContext.valid = false;
      sellContext.reason = "MAX_GLOBAL_TRADES_REACHED";
     }
   if(TimeTradeServer() - g_lastTradeTime < InpTradeCooldownSeconds)
     {
      buyContext.valid = false;
      buyContext.reason = "COOLDOWN_ACTIVE";
      sellContext.valid = false;
      sellContext.reason = "COOLDOWN_ACTIVE";
     }

   int buyCount = CountPositions(POSITION_TYPE_BUY);
   if(HasBuyPosition())
     {
      buyContext.valid = false;
      buyContext.reason = "MAX_BUY_TRADES_REACHED";
     }
   else if(buyCount > 0)
     {
      bool continuationOk = liveSnapshot.emaBullish && (liveSnapshot.adx > InpAdxThreshold) && liveSnapshot.adxIncreasing;
      if(!continuationOk) { buyContext.valid = false; buyContext.reason = "NO_CONTINUATION_TREND"; }
     }

   int sellCount = CountPositions(POSITION_TYPE_SELL);
   if(HasSellPosition())
     {
      sellContext.valid = false;
      sellContext.reason = "MAX_SELL_TRADES_REACHED";
     }
   else if(sellCount > 0)
     {
      bool continuationOk = liveSnapshot.emaBearish && (liveSnapshot.adx > InpAdxThreshold) && liveSnapshot.adxIncreasing;
      if(!continuationOk) { sellContext.valid = false; sellContext.reason = "NO_CONTINUATION_TREND"; }
     }

   DecisionContext current = PickBestDecision(buyContext,sellContext,liveSnapshot);
   UpdateDashboard(current);

   if(InpLogEveryTick)
      LogToCSV("LIVE_TICK_PREVIEW",current.sessionName,current.strategyName,current.price,current.rsi,current.ema50,current.ema200,current.atr,current.spread,current.score,current.decision,current.reason);
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

   ulong posId = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

   if(netProfit < 0.0)
     {
      totalLosses++;
      LogTyped("RESULT", StringFormat("STOP LOSS HIT tradeId=%I64u profit=%.2f", posId, netProfit));
     }
   else if(netProfit > 0.0)
     {
      totalWins++;
      LogTyped("RESULT", StringFormat("TAKE PROFIT HIT tradeId=%I64u profit=%.2f", posId, netProfit));
     }
   else
      LogTyped("RESULT", StringFormat("BREAKEVEN tradeId=%I64u profit=%.2f", posId, netProfit));

   LogStatsIfDue();
  }

#endif // XAUUSD_ADAPTIVE_MANAGEMENT_MQH
