#ifndef XAUUSD_ADAPTIVE_MANAGEMENT_MQH
#define XAUUSD_ADAPTIVE_MANAGEMENT_MQH

void Log(string message)
{
   Print("[" + EA_TYPE + "][GoldEA] " + message);
}

void LogTyped(string type, string message)
{
   Print("[" + EA_TYPE + "][GoldEA][" + type + "] " + message);
}

//--- Session Trade Tracking
ENUM_SESSION g_currentSession = SESSION_NONE;
int g_sessionTradeCountTrend = 0;
int g_sessionTradeCountBreakout = 0;

int totalSignals = 0;
int totalTrades = 0;
int totalSkipped = 0;
int totalWins = 0;
int totalLosses = 0;
int rejectLowAtr = 0;
int rejectSpread = 0;
int rejectMargin = 0;
int rejectSession = 0;
int rejectCooldown = 0;
int rejectMaxTrades = 0;
int rejectOther = 0;
const int STATS_PRINT_INTERVAL = 10;

string NormalizeRejectReason(const string rawReason)
{
   if(rawReason == "" || rawReason == "UNKNOWN" || rawReason == "NO_SETUP")
      return "UNCLASSIFIED_REJECTION";

   string u = rawReason;
   StringToUpper(u);
   if(StringFind(u, "SPREAD") >= 0) return "HIGH_SPREAD";
   if(StringFind(u, "ATR") >= 0 || StringFind(u, "VOLATILITY") >= 0) return "LOW_ATR";
   if(StringFind(u, "SESSION") >= 0) return "SESSION_BLOCK";
   if(StringFind(u, "COOLDOWN") >= 0) return "COOLDOWN_ACTIVE";
   if(StringFind(u, "MAX") >= 0 || StringFind(u, "DUPLICATE") >= 0) return "MAX_TRADES_REACHED";
   if(StringFind(u, "MARGIN") >= 0 || StringFind(u, "LOT_SIZE_ZERO") >= 0) return "INSUFFICIENT_MARGIN";
   if(StringFind(u, "MODE") >= 0) return "NO_MARKET_MODE";
   if(StringFind(u, "WEAK_TREND") >= 0) return "WEAK_TREND";
   if(StringFind(u, "WEAK_CANDLE") >= 0) return "WEAK_CANDLE";
   if(StringFind(u, "VALID") >= 0 || StringFind(u, "READY") >= 0 || StringFind(u, "EXECUTED") >= 0) return "VALID";
   
   return rawReason;
}

void CountRejection(const string reasonCode)
{
   if(reasonCode == "LOW_ATR") rejectLowAtr++;
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
   LogTyped("STATS", StringFormat("lowAtr=%d spread=%d margin=%d session=%d cooldown=%d maxTrades=%d other=%d",
                                   rejectLowAtr, rejectSpread, rejectMargin, rejectSession, rejectCooldown, rejectMaxTrades, rejectOther));
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

//+------------------------------------------------------------------+
//| ExecuteTrade - Implements strict strategy-specific risk          |
//+------------------------------------------------------------------+
bool ExecuteTrade(const DecisionContext &context)
  {
   if(!context.valid || context.strategyName == "" || context.strategyName == "NONE" || context.strategyName == "UNKNOWN")
   {
       LogTyped("REJECTION", "INVALID_STRATEGY");
       return false;
   }

   // --- 1. TRADE FREQUENCY CONTROL ---
   if(context.strategyName == "M5_TREND_PULLBACK" && g_sessionTradeCountTrend >= 2)
   {
       LogRejection(context.decision, "MAX_TRADES_REACHED", 0.0, AccountInfoDouble(ACCOUNT_BALANCE));
       return false;
   }
   if(context.strategyName == "M5_ATR_BREAKOUT" && g_sessionTradeCountBreakout >= 1)
   {
       LogRejection(context.decision, "MAX_TRADES_REACHED", 0.0, AccountInfoDouble(ACCOUNT_BALANCE));
       return false;
   }

   if(HasOpenPosition())
     {
      LogRejection(context.decision, "MAX_TRADES_REACHED", 0.0, AccountInfoDouble(ACCOUNT_BALANCE));
      return false;
     }

   double entryPrice = (context.type == POSITION_TYPE_BUY) ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK) : SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot = 0.01; // Fixed 0.01 
   
   double riskDistance = context.atr * 1.0; 
   double tpDistance = riskDistance * 3.0; 
   
   // --- 2. CORE R-MULTIPLE CONFIGURATION ---
   if(context.strategyName == "M5_TREND_PULLBACK")
   {
       riskDistance = context.atr * 0.8;
       tpDistance = riskDistance * 2.5; // Target 2.5R
   }
   else if(context.strategyName == "M5_ATR_BREAKOUT")
   {
       riskDistance = context.atr * 1.2;
       tpDistance = riskDistance * 4.0; // Target 4R
   }

   double sl = 0.0;
   double tp = 0.0;

   if(context.sl > 0 && context.tp > 0)
     {
      sl = NormalizeDouble(context.sl, g_symbolDigits);
      tp = NormalizeDouble(context.tp, g_symbolDigits);
     }
   else if(context.type == POSITION_TYPE_BUY)
     {
      sl = NormalizeStop(entryPrice - riskDistance, entryPrice, ORDER_TYPE_BUY);
      tp = NormalizeDouble(entryPrice + tpDistance, g_symbolDigits);
     }
   else if(context.type == POSITION_TYPE_SELL)
     {
      sl = NormalizeStop(entryPrice + riskDistance, entryPrice, ORDER_TYPE_SELL);
      tp = NormalizeDouble(entryPrice - tpDistance, g_symbolDigits);
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
      LogRejection(context.decision, "ORDER_FAILED", lot, balance);
      return false;
     }

   ulong ticket = 0;
   ulong resultDeal = trade.ResultDeal();
   if(resultDeal > 0 && HistoryDealSelect(resultDeal))
      ticket = (ulong)HistoryDealGetInteger(resultDeal,DEAL_POSITION_ID);
   if(ticket == 0)
      ticket = FindPositionTicketByComment(commentText);

   if(ticket > 0)
     {
      GlobalVariableSet(BuildStateKey("initrisk",ticket),riskDistance);
      GlobalVariableSet(BuildStateKey("tradeid",ticket),(double)tradeId);
      double stratId = 0.0;
      if(context.strategyName == "M5_TREND_PULLBACK") stratId = 1.0;
      else if(context.strategyName == "M5_ATR_BREAKOUT") stratId = 2.0;
      else if(context.strategyName == "M5_SMART_REVERSAL_FVG") stratId = 3.0;
      GlobalVariableSet(BuildStateKey("strategy",ticket), stratId);
      GlobalVariableSet(BuildStateKey("M5TrailLevel", ticket), 0); 
     }

   if(context.strategyName == "M5_TREND_PULLBACK") g_sessionTradeCountTrend++;
   else if(context.strategyName == "M5_ATR_BREAKOUT") g_sessionTradeCountBreakout++;

   DrawTradeArrow(tradeId, context.type, false, entryPrice);
   totalTrades++;

   // Store Trade Context for lifecycle tracking
   TradeContext *tCtx = new TradeContext(context.strategyName, (context.type == POSITION_TYPE_BUY ? "BUY" : "SELL"), "M5");
   g_tradeContextMap.Add(tradeId, tCtx);

   datetime barTime = iTime(InpTradeSymbol, InpTimeframe, 1);
   LogTyped("EXECUTION", StringFormat("[%s] %s executed: tradeId=%I64u barTime=%s lot=%.2f entry=%.2f sl=%.2f tp=%.2f strategy=%s",
                                       context.strategyName, tCtx.side, tradeId, TimeToString(barTime), lot, entryPrice, sl, tp, context.strategyName));
   
   return true;
  }

//+------------------------------------------------------------------+
//| ManageTrade - Fixed R-Multiple Trailing (Removes aggressive BE)  |
//+------------------------------------------------------------------+
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

   string strategyKey = BuildStateKey("strategy",ticket);
   int strategy = GlobalVariableCheck(strategyKey) ? (int)GlobalVariableGet(strategyKey) : 0;
   
   string trailLevelKey = BuildStateKey("M5TrailLevel", ticket);
   int currentTrailLevel = GlobalVariableCheck(trailLevelKey) ? (int)GlobalVariableGet(trailLevelKey) : 0;

   double newSlPrice = 0.0;
   int desiredTrailLevel = currentTrailLevel;

   // 🔹 TREND_PULLBACK Management
   if(strategy == 1) // TREND_PULLBACK
   {
       if(rMultiple >= 1.0 && currentTrailLevel < 1)
       {
           desiredTrailLevel = 1; // Breakeven
           newSlPrice = (type == POSITION_TYPE_BUY) ? (openPrice + initialRisk * 0.05) : (openPrice - initialRisk * 0.05);
       }
       else if(rMultiple >= 2.0 && currentTrailLevel < 2)
       {
           desiredTrailLevel = 2; // Lock 1R
           newSlPrice = (type == POSITION_TYPE_BUY) ? (openPrice + initialRisk * 1.0) : (openPrice - initialRisk * 1.0);
       }
   }
   // 🔹 ATR_BREAKOUT Management
   else if(strategy == 2) // ATR_BREAKOUT
   {
       if(rMultiple >= 1.5 && currentTrailLevel < 1)
       {
           desiredTrailLevel = 1; // Lock 0.5R
           newSlPrice = (type == POSITION_TYPE_BUY) ? (openPrice + initialRisk * 0.5) : (openPrice - initialRisk * 0.5);
       }
       else if(rMultiple >= 3.0 && currentTrailLevel < 2)
       {
           desiredTrailLevel = 2; // Lock 2.0R
           newSlPrice = (type == POSITION_TYPE_BUY) ? (openPrice + initialRisk * 2.0) : (openPrice - initialRisk * 2.0);
       }
   }
   // 🔹 SMART_REVERSAL_FVG Management
   else if(strategy == 3) // SMART_REVERSAL_FVG
   {
       if(rMultiple >= 1.0 && currentTrailLevel < 1)
       {
           desiredTrailLevel = 1; // Breakeven
           newSlPrice = (type == POSITION_TYPE_BUY) ? (openPrice + initialRisk * 0.1) : (openPrice - initialRisk * 0.1);
       }
       else if(rMultiple >= 2.0 && currentTrailLevel < 2)
       {
           desiredTrailLevel = 2; // Lock 1.0R
           newSlPrice = (type == POSITION_TYPE_BUY) ? (openPrice + initialRisk * 1.0) : (openPrice - initialRisk * 1.0);
       }
   }

   if(desiredTrailLevel > currentTrailLevel && newSlPrice > 0)
   {
       newSlPrice = NormalizeDouble(newSlPrice, g_symbolDigits);
       bool isImproved = (type == POSITION_TYPE_BUY && newSlPrice > currentSl) ||
                         (type == POSITION_TYPE_SELL && (currentSl == 0.0 || newSlPrice < currentSl));
       
       if(isImproved)
       {
           if(trade.PositionModify(ticket, newSlPrice, currentTp))
           {
               GlobalVariableSet(trailLevelKey, (double)desiredTrailLevel);
               LogTyped("MGMT", StringFormat("[%s] Trail updated tradeId=%I64u to level=%d R=%.2f", 
                        (strategy==1?"M5_TREND_PULLBACK":"M5_ATR_BREAKOUT"), ticket, desiredTrailLevel, rMultiple));
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
      string prefix = StringFormat("EA_%I64u_", (ulong)InpMagicNumber);
      if(StringFind(gName, prefix) == 0)
        {
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

   // Session Reset
   if(entrySnapshot.session != g_currentSession)
   {
       g_currentSession = entrySnapshot.session;
       g_sessionTradeCountTrend = 0;
       g_sessionTradeCountBreakout = 0;
       LogTyped("SESSION", StringFormat("New session detected: %s. Trade counters reset.", SessionToString(g_currentSession)));
   }

   DecisionContext buyContext = SelectAndRunStrategy(POSITION_TYPE_BUY,entrySnapshot,true);
   DecisionContext sellContext = SelectAndRunStrategy(POSITION_TYPE_SELL,entrySnapshot,true);
   
   if(!InpAllowBuyTrades) { buyContext.valid = false; buyContext.reason = "BUY_DISABLED"; }
   if(!InpAllowSellTrades) { sellContext.valid = false; sellContext.reason = "SELL_DISABLED"; }
   
   if(TimeTradeServer() - g_lastTradeTime < InpTradeCooldownSeconds)
     {
      buyContext.valid = false; buyContext.reason = "COOLDOWN_ACTIVE";
      sellContext.valid = false; sellContext.reason = "COOLDOWN_ACTIVE";
     }

   totalSignals += 2;
   string buyReasonCode = buyContext.valid ? "VALID" : NormalizeRejectReason(buyContext.reason);
   string sellReasonCode = sellContext.valid ? "VALID" : NormalizeRejectReason(sellContext.reason);
   
   datetime barTime = iTime(InpTradeSymbol, InpTimeframe, 1);
   
   LogTyped("CHECK", StringFormat("[%s] BUY check: barTime=%s atr=%.2f spread=%d reason=%s strategy=%s",
                                   buyContext.strategyName, TimeToString(barTime), entrySnapshot.atr, (int)entrySnapshot.spread, buyReasonCode, buyContext.strategyName));
   LogTyped("CHECK", StringFormat("[%s] SELL check: barTime=%s atr=%.2f spread=%d reason=%s strategy=%s",
                                   sellContext.strategyName, TimeToString(barTime), entrySnapshot.atr, (int)entrySnapshot.spread, sellReasonCode, sellContext.strategyName));

   
   if(!buyContext.valid && buyReasonCode != "NO_SETUP" && buyReasonCode != "UNCLASSIFIED_REJECTION") 
       LogTyped("REJECTION", StringFormat("%s rejected: barTime=%s reason=%s lot=%.2f balance=%.2f", "BUY", TimeToString(barTime), buyReasonCode, 0.0, AccountInfoDouble(ACCOUNT_BALANCE)));
   if(!sellContext.valid && sellReasonCode != "NO_SETUP" && sellReasonCode != "UNCLASSIFIED_REJECTION") 
       LogTyped("REJECTION", StringFormat("%s rejected: barTime=%s reason=%s lot=%.2f balance=%.2f", "SELL", TimeToString(barTime), sellReasonCode, 0.0, AccountInfoDouble(ACCOUNT_BALANCE)));

   if(buyContext.valid)
     {
      ExecuteTrade(buyContext);
     }
   else if(sellContext.valid)
     {
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
   
   DecisionContext current = PickBestDecision(buyContext,sellContext,liveSnapshot);
   UpdateDashboard(current);
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
    
    if (entryType == DEAL_ENTRY_IN)
        return;

    if(entryType != DEAL_ENTRY_OUT)
        return;

    double netProfit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                     + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                     + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

    ulong posId = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
    ulong tradeId = 0;
    string tradeIdKey = BuildStateKey("tradeid", posId);
    if(GlobalVariableCheck(tradeIdKey))
        tradeId = (ulong)GlobalVariableGet(tradeIdKey);

    string resultType = "EXIT";
    if(netProfit < 0.0) { totalLosses++; resultType = "STOP_LOSS_HIT"; }
    else if(netProfit > 0.0) { totalWins++; resultType = "TAKE_PROFIT_HIT"; }
    else resultType = "BREAKEVEN";

    TradeContext *tCtx = NULL;
    ulong lookupKey = (tradeId > 0 ? tradeId : posId);
    if(g_tradeContextMap.TryGetValue(lookupKey, tCtx) && tCtx != NULL)
    {
        LogTyped("RESULT", StringFormat("[%s] %s tradeId=%I64u profit=%.2f", 
                                       tCtx.strategy, resultType, lookupKey, netProfit));
        delete tCtx;
        g_tradeContextMap.Remove(lookupKey);
    }
    else
    {
        LogTyped("RESULT", StringFormat("[UNKNOWN] %s tradeId=%I64u profit=%.2f", 
                                       resultType, lookupKey, netProfit));
    }

    LogStatsIfDue();
}

#endif // XAUUSD_ADAPTIVE_MANAGEMENT_MQH
