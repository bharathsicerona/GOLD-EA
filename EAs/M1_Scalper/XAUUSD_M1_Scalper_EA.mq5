#property strict
#property version   "2.70"
#property description "M1 High-Risk Scalper EA v2.7 - Bi-directional Trading Upgrade"

#include <Trade/Trade.mqh>
#include <Generic/HashMap.mqh>

string EA_TYPE = "M1_SCALPER";

void Log(string message)
{
   Print("[" + EA_TYPE + "][GoldEA] " + message);
}

void LogTyped(string type, string message)
{
   Print("[" + EA_TYPE + "][GoldEA][" + type + "] " + message);
}

// --- Internal logging counters ---
int totalSignals = 0;
int totalTrades = 0;
int totalSkipped = 0;
int totalWins = 0;
int totalLosses = 0;
int rejectLowScore = 0;
int rejectSpread = 0;
int rejectSession = 0;
int rejectCooldown = 0;
int rejectMaxTrades = 0;
int rejectMargin = 0;
int rejectOther = 0;
const int STATS_PRINT_INTERVAL = 10;

string NormalizeRejectReason(const string rawReason)
{
   string u = rawReason;
   StringToUpper(u);
   if(StringFind(u, "LOW_ATR_DYNAMIC") >= 0) return "LOW_ATR_DYNAMIC";
   if(StringFind(u, "WEAK_TREND") >= 0) return "WEAK_TREND";
   if(StringFind(u, "CHOP_MARKET_DYNAMIC") >= 0) return "CHOP_MARKET_DYNAMIC";
   if(StringFind(u, "WEAK_CANDLE_DYNAMIC") >= 0) return "WEAK_CANDLE_DYNAMIC";
   if(StringFind(u, "WEAK_BREAKOUT_DYNAMIC") >= 0) return "WEAK_BREAKOUT_DYNAMIC";
   if(StringFind(u, "NY_WEAK_CONDITION") >= 0) return "NY_WEAK_CONDITION";
   if(StringFind(u, "WEAK_BREAKOUT_REJECTED") >= 0) return "WEAK_BREAKOUT_REJECTED";
   if(StringFind(u, "CORE_CONDITION_FAIL") >= 0) return "CORE_CONDITION_FAIL";
   if(StringFind(u, "TREND_WEAK") >= 0) return "TREND_WEAK";
   if(StringFind(u, "MOMENTUM_WEAK") >= 0) return "MOMENTUM_WEAK";
   if(StringFind(u, "SCORE_TOO_LOW") >= 0) return "SCORE_TOO_LOW";
   if(StringFind(u, "DIRECTION_CONFLICT") >= 0) return "DIRECTION_CONFLICT";
   if(StringFind(u, "NO_BREAKOUT") >= 0) return "NO_BREAKOUT";
   if(StringFind(u, "EARLY_NOISE") >= 0) return "EARLY_NOISE";
   if(StringFind(u, "M5_TREND_BLOCK") >= 0) return "M5_TREND_BLOCK";
   if(StringFind(u, "SELL_DISABLED_DEBUG") >= 0) return "SELL_DISABLED_DEBUG";
   if(StringFind(u, "LOW_ATR") >= 0) return "LOW_ATR";
   if(StringFind(u, "LOSS_CLUSTER_COOLDOWN") >= 0) return "LOSS_CLUSTER_COOLDOWN";
   if(StringFind(u, "EMA_FLAT") >= 0) return "EMA_FLAT";
   if(StringFind(u, "ORDER_FAILED") >= 0) return "ORDER_FAILED";
   if(StringFind(u, "INVALID_TICKVALUE") >= 0) return "INVALID_TICKVALUE";
   if(StringFind(u, "RISK_ENGINE_BLOCK") >= 0) return "RISK_ENGINE_BLOCK";
   if(StringFind(u, "SPREAD") >= 0) return "HIGH_SPREAD";
   if(StringFind(u, "ASIAN") >= 0 || StringFind(u, "SESSION") >= 0) return "SESSION_BLOCK";
   if(StringFind(u, "5CANDLE") >= 0) return "COOLDOWN_5CANDLE";
   if(StringFind(u, "3CANDLE") >= 0) return "COOLDOWN_3CANDLE";
   if(StringFind(u, "2CANDLE") >= 0) return "COOLDOWN_2CANDLE";
   if(StringFind(u, "COOLDOWN") >= 0) return "COOLDOWN_ACTIVE";
   if(StringFind(u, "MAX") >= 0 || StringFind(u, "TRADE FREQUENCY") >= 0 || StringFind(u, "DUPLICATE") >= 0) return "MAX_TRADES_REACHED";
   if(StringFind(u, "MARGIN") >= 0) return "INSUFFICIENT_MARGIN";
   if(StringFind(u, "VALID") >= 0 || StringFind(u, "SIGNAL") >= 0) return "VALID";
   return "OTHER";
}

void CountRejection(const string reasonCode)
{
   if(reasonCode == "HIGH_SPREAD") rejectSpread++;
   else if(reasonCode == "SESSION_BLOCK") rejectSession++;
   else if(reasonCode == "COOLDOWN_ACTIVE" || reasonCode == "COOLDOWN_2CANDLE" || reasonCode == "COOLDOWN_3CANDLE" || reasonCode == "COOLDOWN_5CANDLE") rejectCooldown++;
   else if(reasonCode == "MAX_TRADES_REACHED") rejectMaxTrades++;
   else if(reasonCode == "INSUFFICIENT_MARGIN") rejectMargin++;
   else rejectOther++;
}

// LogRejection handled below

void LogStatsIfDue()
{
   if(totalTrades <= 0 || (totalTrades % STATS_PRINT_INTERVAL) != 0)
      return;
   LogTyped("STATS", StringFormat("signals=%d trades=%d skipped=%d win=%d loss=%d",
                                  totalSignals, totalTrades, totalSkipped, totalWins, totalLosses));
   LogTyped("STATS", StringFormat("lowScore=%d spread=%d margin=%d session=%d cooldown=%d maxTrades=%d other=%d",
                                  rejectLowScore, rejectSpread, rejectMargin, rejectSession, rejectCooldown, rejectMaxTrades, rejectOther));
}

// --- Global Variables & Objects ---
CTrade trade;
int    g_symbolDigits = 2;
datetime g_lastLossTime = 0;
datetime g_lastCloseTime = 0;
datetime g_lastTradeBarTime = 0;
int g_lastBuyScore = 0;
int g_lastSellScore = 0;
int g_consecutiveLosses = 0;
int g_skipSignalsRemaining = 0;

// Indicator Handles
int g_ema20Handle = INVALID_HANDLE;
int g_ema50Handle = INVALID_HANDLE;
int g_rsiHandle   = INVALID_HANDLE;
int g_atrHandle   = INVALID_HANDLE;

// Include all modular components
#include "XAUUSD_M1_Scalper_Inputs.mqh"
#include "../Include/GoldEA_Common_Core.mqh"
#include "XAUUSD_M1_Scalper_Indicators.mqh"
#include "XAUUSD_M1_Scalper_Entry.mqh"
#include "../Include/GoldEA_Unified_Risk.mqh" // <-- NEW UNIFIED RISK ENGINE
#include "XAUUSD_M1_Scalper_Logging.mqh"
#include "XAUUSD_M1_Scalper_HighRisk_Management.mqh"

// Custom hash map to store initial risk per ticket
CHashMap<ulong, double> g_initialRiskMap;

// --- Forward Declarations for Indicator Functions ---
bool InitializeIndicators();
void ReleaseIndicators();

//+------------------------------------------------------------------+
//| Open Position Check                                              |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            return true;
        }
    }
    return false;
}

// --- Margin and Cooldown Checks (Moved from XAUUSD_M1_Scalper_Risk.mqh to fix dependency) ---
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

//+------------------------------------------------------------------+
//| ExecuteHighRiskTrade - New Trade Execution Logic                 |
//+------------------------------------------------------------------+
void ExecuteHighRiskTrade(const ENUM_POSITION_TYPE direction, const string strategyName)
{
    if(strategyName == "" || strategyName == "NONE" || strategyName == "UNKNOWN")
    {
        LogTyped("REJECTION", "INVALID_STRATEGY");
        return;
    }

    // --- 1. Get Entry Price ---
    double entryPrice = (direction == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // --- 2. Define Initial Trade Parameters ---
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lotSize = 0.01;
    
    // [NEW SYSTEM] ATR-based SL/TP model
    double atrValue = 0.0;
    if (!GetIndicatorValue(g_atrHandle, 0, atrValue) || atrValue <= 0.0)
    {
        LogRejection((direction == POSITION_TYPE_BUY) ? "BUY" : "SELL", "LOW_ATR", lotSize);
        return;
    }
    
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    if (tickSize <= 0.0 || tickValue <= 0.0 || lotSize <= 0.0)
    {
        LogRejection((direction == POSITION_TYPE_BUY) ? "BUY" : "SELL", "INVALID_TICKVALUE", lotSize);
        return;
    }

    double slDistance = atrValue * 0.8; 
    if (slDistance < 2.0) slDistance = 2.0; 
    if (slDistance > 5.0) slDistance = 5.0; 
    double tpDistance = slDistance * 1.5; 
    
    double minStopDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    if (minStopDist > 0.0)
    {
        slDistance = MathMax(slDistance, minStopDist);
        tpDistance = MathMax(tpDistance, minStopDist);
    }

    double slPrice = (direction == POSITION_TYPE_BUY) ? (entryPrice - slDistance) : (entryPrice + slDistance);
    double tpPrice = (direction == POSITION_TYPE_BUY) ? (entryPrice + tpDistance) : (entryPrice - tpDistance);
    double finalSlDistance = MathAbs(entryPrice - slPrice);

    // Final normalization
    slPrice = NormalizeDouble(slPrice, g_symbolDigits);
    tpPrice = NormalizeDouble(tpPrice, g_symbolDigits);

    // --- 5. Margin Check ---
    if (!HasSufficientMargin(direction, lotSize, entryPrice)) 
    {
        LogRejection((direction == POSITION_TYPE_BUY) ? "BUY" : "SELL", "INSUFFICIENT_MARGIN", lotSize);
        return;
    }

    // --- 6. Calculate Final Initial Risk for Management Modules ---
    double initialRiskInCurrency = (finalSlDistance / tickSize) * tickValue * lotSize;

    // --- 7. Execute Trade ---
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(20);
    
    ENUM_ORDER_TYPE orderType = (direction == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    
    if (trade.PositionOpen(_Symbol, orderType, lotSize, entryPrice, slPrice, tpPrice)) 
    {
        ulong dealId = trade.ResultDeal();
        ulong ticket = dealId;
        if (ticket == 0) ticket = trade.ResultOrder();
        totalTrades++;

        string side = (direction == POSITION_TYPE_BUY ? "BUY" : "SELL");
        
        g_lastTradeBarTime = iTime(_Symbol, PERIOD_M1, 0);
        datetime barTime = iTime(_Symbol, PERIOD_M1, 1);

        LogTyped("EXECUTION", StringFormat("[%s] %s executed: tradeId=%I64u barTime=%s lot=%.2f entry=%.2f sl=%.2f tp=%.2f strategy=%s",
                 strategyName, side, ticket, TimeToString(barTime), lotSize, entryPrice, slPrice, tpPrice, strategyName));

        // --- 8. Store Initial Risk ---
        if (ticket > 0) 
        {
            if (!g_initialRiskMap.ContainsKey(ticket)) 
            {
                g_initialRiskMap.Add(ticket, initialRiskInCurrency);
                LogTyped("EXECUTION", StringFormat("risk_mapped tradeId=%I64u risk=%.2f", ticket, initialRiskInCurrency));
            }
        }

        ResetPullbackState();
    } 
    else 
    {
        LogRejection((direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), "ORDER_FAILED", lotSize);
        LogTyped("REJECTION", StringFormat("order failed: retcode=%d comment=%s", trade.ResultRetcode(), trade.ResultComment()));
    }
}

//+------------------------------------------------------------------+
//| ExtendTakeProfit - Dynamically Pushes TP for Runners             |
//+------------------------------------------------------------------+
void ExtendTakeProfit(ulong ticket, double initialRisk)
{
    if (initialRisk <= 0) return;
    double profit = PositionGetDouble(POSITION_PROFIT);
    
    // If profit is more than 2x initial risk (strong runner), extend TP to avoid premature exit
    if (profit > (initialRisk * 2.0)) {
        double currentTP = PositionGetDouble(POSITION_TP);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        long type = PositionGetInteger(POSITION_TYPE);
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        
        double newTP = 0;
        double minTpDistance = 100 * point; // If price gets within 100 points of TP, push it away
        double pushDistance  = 300 * point; // Push TP 300 points further
        
        if (type == POSITION_TYPE_BUY && currentTP != 0 && (currentTP - currentPrice) < minTpDistance) {
            newTP = currentPrice + pushDistance;
        } else if (type == POSITION_TYPE_SELL && currentTP != 0 && (currentPrice - currentTP) < minTpDistance) {
            newTP = currentPrice - pushDistance;
        }
        
        if (newTP != 0) {
            trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), newTP);
            Log("Runner detected: TP dynamically extended to prevent premature exit.");
        }
    }
}

//+------------------------------------------------------------------+
//| EvaluateTickAndDashboard - Update the dashboard on every tick    |
//+------------------------------------------------------------------+
void EvaluateTickAndDashboard()
{
    if (!InpEnableDashboard) return;

    DecisionContext context;
    context.sessionName = "AGGRO"; // M1 is always AGGRO
    context.status = IsCooldownActive() ? "COOLDOWN" : "ACTIVE";
    context.strategyName = "M1 Scalper";
    context.riskPercent = InpHighRiskPercent; // Using the high-risk input

    double atrValue;
    if (GetIndicatorValue(g_atrHandle, 1, atrValue)) {
        context.atr = atrValue;
    }

    context.score = 0; // M1 EA doesn't have a score model
    context.decision = "MONITORING";
    context.phase = "N/A";
    context.reason = "N/A";

    // Standardized Dashboard
    UpdateDashboard(context);
    
    // Entry Mode
    SetDashboardLabelLine(EA_TYPE, "ENTRY_MODE", "Entry Mode: CLOSED CANDLE", clrCyan, 2);
}

//+------------------------------------------------------------------+
//| OnInit: EA Initialization                                        |
//+------------------------------------------------------------------+
int OnInit()
{
    g_symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    // Init indicators
    if (!InitializeIndicators()) return INIT_FAILED;
    
    // Init trade engine
    trade.SetTypeFillingBySymbol(_Symbol);

    LogTyped("STATS", "init status=ACTIVE");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit: EA Deinitialization                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ReleaseIndicators();
    // g_initialRiskMap is destroyed automatically
    LogTyped("STATS", StringFormat("deinit reason=%d signals=%d trades=%d skipped=%d", reason, totalSignals, totalTrades, totalSkipped));

   if(InpEnableDashboard)
     {
      string labels[7] = {"Title","Session","Strategy","ATR","Score","Decision","Reason"};
      for(int i = 0; i < 7; ++i)
         ObjectDelete(0,g_dashboardPrefix + labels[i]);
     }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction: Handle Closed Trades                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
    if (trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        if (HistoryDealSelect(trans.deal)) {
            if (HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == InpMagicNumber) {
                // If a position is closed, remove its initial risk from the map
                if (HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                    ulong position_id = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
                    if (g_initialRiskMap.ContainsKey(position_id)) {
                        g_initialRiskMap.Remove(position_id);
                        LogTyped("RESULT", StringFormat("risk_unmapped tradeId=%I64u", position_id));
                    }
                    string trailLevelKey = BuildStateKey("m1traillevel", position_id);
                    if (GlobalVariableCheck(trailLevelKey))
                        GlobalVariableDel(trailLevelKey);
                    // Standardized Result Logic with Context
                    double dealProfit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
                    string resultType = "EXIT";
                    if(dealProfit < 0) {
                        g_lastLossTime = TimeCurrent();
                        totalLosses++;
                        g_consecutiveLosses++;
                        if(g_consecutiveLosses >= 2 && g_skipSignalsRemaining <= 0)
                           g_skipSignalsRemaining = 2;
                        resultType = "STOP_LOSS_HIT";
                    } else if(dealProfit > 0) {
                        totalWins++;
                        g_consecutiveLosses = 0;
                        resultType = "TAKE_PROFIT_HIT";
                    } else {
                        g_consecutiveLosses = 0;
                        resultType = "BREAKEVEN";
                    }

                    TradeContext *tCtx = NULL;
                    if(g_tradeContextMap.TryGetValue(position_id, tCtx) && tCtx != NULL)
                    {
                        LogTyped("RESULT", StringFormat("[%s] %s tradeId=%I64u profit=%.2f", 
                                                       tCtx.strategy, resultType, position_id, dealProfit));
                        delete tCtx;
                        g_tradeContextMap.Remove(position_id);
                    }

                    else
                    {
                        LogTyped("RESULT", StringFormat("[UNKNOWN] %s tradeId=%I64u profit=%.2f", 
                                                       resultType, position_id, dealProfit));
                    }

                    // Cooldown after ANY trade
                    g_lastCloseTime = TimeCurrent();
                    LogStatsIfDue();

                }
            }
        }
    }
}


//+------------------------------------------------------------------+
//| StrategyFeedbackManager - In-trade Signal Management             |
//+------------------------------------------------------------------+
// StrategyFeedbackManager moved to XAUUSD_M1_Scalper_HighRisk_Management.mqh

//+------------------------------------------------------------------+
//| ProcessStrategySignals - Signal Interaction Engine               |
//+------------------------------------------------------------------+
void ProcessStrategySignals(StrategySignal &signals[], int cntSignals, int &finalDirection, string &decisionType, double &confidenceLevel, string &primaryStrategyName)
{
    finalDirection = -1;
    decisionType = "REJECT";
    confidenceLevel = 0.0;
    primaryStrategyName = "NONE";

    StrategySignal sweepSignal;
    bool hasSweep = false;
    StrategySignal breakoutSignal;
    bool hasBreakout = false;
    StrategySignal pullbackSignal;
    bool hasPullback = false;

    int buySignalCount = 0;
    int sellSignalCount = 0;

    for (int i = 0; i < cntSignals; i++)
    {
        if (signals[i].valid)
        {
            if(signals[i].direction == POSITION_TYPE_BUY) buySignalCount++;
            if(signals[i].direction == POSITION_TYPE_SELL) sellSignalCount++;

            if (signals[i].name == "M1_LIQUIDITY_SWEEP")
            {
                hasSweep = true;
                sweepSignal = signals[i];
            }
            else if (signals[i].name == "M1_BREAKOUT")
            {
                hasBreakout = true;
                breakoutSignal = signals[i];
            }
            else if (signals[i].name == "M1_EMA_PULLBACK")
            {
                hasPullback = true;
                pullbackSignal = signals[i];
            }
        }
    }
    
    // PRIORITY 6: CONFLICT
    if (buySignalCount > 0 && sellSignalCount > 0)
    {
        decisionType = "DIRECTION_CONFLICT";
    }
    // PRIORITY 1: LIQUIDITY SWEEP
    else if (hasSweep)
    {
        finalDirection = sweepSignal.direction;
        decisionType = "SWEEP_OVERRIDE";
        confidenceLevel = 2.0;
        primaryStrategyName = sweepSignal.name;
        LogTyped("SIGNAL_SUMMARY", "SWEEP_OVERRIDE. Strategy: " + primaryStrategyName);
    }
    // PRIORITY 2: ALIGNMENT
    else if (hasBreakout && hasPullback && breakoutSignal.direction == pullbackSignal.direction)
    {
        finalDirection = breakoutSignal.direction;
        decisionType = "ALIGNMENT";
        confidenceLevel = 1.5;
        primaryStrategyName = "M1_BREAKOUT"; 
        LogTyped("SIGNAL_SUMMARY", "ALIGNMENT signal. Strategies: M1_BREAKOUT, M1_EMA_PULLBACK");
    }
    // PRIORITY 3: BREAKOUT ONLY
    else if (hasBreakout && !hasPullback)
    {
        if (breakoutSignal.isStrong)
        {
            finalDirection = breakoutSignal.direction;
            decisionType = "STRONG_BREAKOUT";
            confidenceLevel = 1.0;
            primaryStrategyName = "M1_BREAKOUT";
            LogTyped("SIGNAL_SUMMARY", "STRONG_BREAKOUT signal. Strategy: M1_BREAKOUT");
        }
        else
        {
            decisionType = "WEAK_BREAKOUT_REJECTED";
            LogTyped("SIGNAL_SUMMARY", "Weak breakout rejected.");
        }
    }
    // PRIORITY 4: PULLBACK ONLY
    else if (hasPullback && !hasBreakout)
    {
        finalDirection = pullbackSignal.direction;
        decisionType = "PULLBACK_ONLY";
        confidenceLevel = 1.0;
        primaryStrategyName = "M1_EMA_PULLBACK";
        LogTyped("SIGNAL_SUMMARY", "PULLBACK_ONLY signal. Strategy: M1_EMA_PULLBACK");
    }

    // --- FINAL SCORE FILTER ---
    if (finalDirection != -1 && confidenceLevel < 1.0)
    {
        finalDirection = -1;
        decisionType = "LOW_SCORE";
    }
}



int GetDynamicCooldownCandles(bool &chopDetected)
{
    int cooldownCandles = InpEntryCooldownCandles; // Default
    chopDetected = false;

    if(g_consecutiveLosses == 1)
    {
        cooldownCandles = 3;
    }
    else if(g_consecutiveLosses >= 2)
    {
        cooldownCandles = 5;
    }

    // Chop detection
    double atr;
    GetIndicatorValue(g_atrHandle, 1, atr);
    MqlRates rates[];
    if (CopyRates(_Symbol, _Period, 0, 5, rates) == 5)
    {
        double high5 = rates[0].high;
        double low5 = rates[0].low;
        for(int i = 1; i < 5; i++)
        {
            if(rates[i].high > high5) high5 = rates[i].high;
            if(rates[i].low < low5) low5 = rates[i].low;
        }
        double range5 = high5 - low5;
        if(range5 < atr * 1.2)
        {
            chopDetected = true;
            cooldownCandles = MathMax(cooldownCandles, 7); // increase cooldown in chop
        }
    }
    
    return cooldownCandles;
}

void LogRejection(const string side, const string reasonCode, const double lot, const double rsi = -1.0)
{
   totalSkipped++;
   CountRejection(reasonCode);
   datetime barTime = iTime(_Symbol, PERIOD_M1, 1);
   if(rsi >= 0.0)
      LogTyped("REJECTION", StringFormat("%s rejected: barTime=%s reason=%s rsi=%.2f lot=%.2f balance=%.2f", side, TimeToString(barTime), reasonCode, rsi, lot, AccountInfoDouble(ACCOUNT_BALANCE)));
   else
      LogTyped("REJECTION", StringFormat("%s rejected: barTime=%s reason=%s lot=%.2f balance=%.2f", side, TimeToString(barTime), reasonCode, lot, AccountInfoDouble(ACCOUNT_BALANCE)));
}

void LogSignals(StrategySignal &signals[], double atr, int spread)
{
    datetime barTime = iTime(_Symbol, PERIOD_M1, 1);
    for(int i = 0; i < ArraySize(signals); i++)
    {
        if(signals[i].valid)
        {
            string side = (signals[i].direction == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            string strategyName = signals[i].name;
            LogTyped("CHECK", StringFormat("[%s] %s check: barTime=%s atr=%.2f spread=%d reason=VALID strategy=%s",
                                           strategyName, side, TimeToString(barTime), atr, spread, strategyName));
        }
    }
}


//+------------------------------------------------------------------+
//| OnTick: Main EA Logic                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    EvaluateTickAndDashboard();

    // --- 1. Manage Existing Position ---
    if (HasOpenPosition())
    {
        ManageHighRiskPosition();
        return;
    }

    // --- 2. Bar Close Logic (Entry Only) ---
    // 🔥 GLOBAL RULE: ONLY ENTER AFTER CANDLE CLOSE
    bool isNewBar = false;
    static datetime lastSignalEvalBar = 0;
    datetime currentSignalBar = iTime(_Symbol, PERIOD_M1, 0);
    if (currentSignalBar != lastSignalEvalBar)
    {
        isNewBar = true;
        lastSignalEvalBar = currentSignalBar;
    }

    if(!isNewBar) return;
    
    datetime barTime = iTime(_Symbol, PERIOD_M1, 1);

    // --- Prevent Trade Clusters ---
    if(g_lastTradeBarTime > 0 && (currentSignalBar - g_lastTradeBarTime) < 120) // 2 candles * 60 seconds
    {
        LogRejection("BOTH", "COOLDOWN_ACTIVE", 0.0);
        return;
    }

    // --- Dynamic Cooldown and Adaptive Filter ---
    bool chopDetected = false;
    int dynamicCooldown = GetDynamicCooldownCandles(chopDetected);

    string filterReason = "";
    double atr, emaFast, emaSlow;
    GetIndicatorValue(g_atrHandle, 1, atr);
    GetIndicatorValue(g_ema20Handle, 1, emaFast);
    GetIndicatorValue(g_ema50Handle, 1, emaSlow);

    if (chopDetected) {
        if (g_lastTradeBarTime > 0) {
            int barsSinceLastTrade = iBarShift(_Symbol, PERIOD_M1, g_lastTradeBarTime, false);
            if (barsSinceLastTrade >= 0 && barsSinceLastTrade < dynamicCooldown) {
                LogRejection("BOTH", "COOLDOWN_ACTIVE_CHOP", 0.0);
                return;
            }
        }
    }
    else if(!AdaptiveFilterCheck(filterReason, atr, emaFast, emaSlow, false))
    {
        LogRejection("BOTH", filterReason, 0.0);
        return;
    }
    
    // Evaluate signals on every tick
    StrategySignal signals[];
    ValidateEntry(signals);
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    LogSignals(signals, atr, (int)spread);



    if (g_skipSignalsRemaining > 0)
    {
        LogRejection("BOTH", "LOSS_CLUSTER_COOLDOWN", 0.0);
        g_skipSignalsRemaining--;
        return;
    }

    // Cooldown after loss check
    if(IsCooldownActive()) {
        LogRejection("BOTH", "COOLDOWN_ACTIVE", 0.0);
        return;
    }
    
    // Safety: bar-based cooldown after last executed trade
    if (g_lastTradeBarTime > 0) {
        int barsSinceLastTrade = iBarShift(_Symbol, PERIOD_M1, g_lastTradeBarTime, false);
        if (barsSinceLastTrade >= 0 && barsSinceLastTrade < dynamicCooldown) {
            LogRejection("BOTH", "COOLDOWN_ACTIVE", 0.0);
            return;
        }
    }

    // Trade Frequency Control (Max 3 trades per 5 minutes)
    int countTradesLast5Min = 0;
    datetime currentTime = TimeCurrent();
    if (HistorySelect(currentTime - 300, currentTime)) {
        int deals = HistoryDealsTotal();
        for(int i = 0; i < deals; i++) {
            ulong dealTicket = HistoryDealGetTicket(i);
            if (HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                if (HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber) {
                    countTradesLast5Min++;
                }
            }
        }
    }
    if (countTradesLast5Min >= 3) {
        LogRejection("BOTH", "MAX_TRADES_REACHED", 0.0);
        return; // Prevent extreme overtrading bursts
    }

    // Process signals
    int finalDirection = -1;
    double confidenceLevel = 0.0;
    string primaryStrategyName = "NONE";
    string decisionType = "REJECT";
    ProcessStrategySignals(signals, ArraySize(signals), finalDirection, decisionType, confidenceLevel, primaryStrategyName);

    if (finalDirection != -1)
    {
        totalSignals++;
        ExecuteHighRiskTrade((ENUM_POSITION_TYPE)finalDirection, primaryStrategyName);
    }
    else
    {
        LogRejection("BOTH", decisionType, 0.0);
    }
}

//+------------------------------------------------------------------+
//| Indicator Functions                                              |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    g_ema20Handle = iMA(_Symbol, _Period, InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(g_ema20Handle == INVALID_HANDLE) {
        Log("Error creating Fast EMA indicator.");
        return false;
    }
    g_ema50Handle = iMA(_Symbol, _Period, InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(g_ema50Handle == INVALID_HANDLE) {
        Log("Error creating Slow EMA indicator.");
        return false;
    }
    g_rsiHandle = iRSI(_Symbol, _Period, InpRsiPeriod, PRICE_CLOSE);
    if(g_rsiHandle == INVALID_HANDLE) {
        Log("Error creating RSI indicator.");
        return false;
    }
    g_atrHandle = iATR(_Symbol, _Period, InpAtrPeriod);
    if(g_atrHandle == INVALID_HANDLE) {
        Log("Error creating ATR indicator.");
        return false;
    }
    return true;
}

void ReleaseIndicators()
{
    if(g_ema20Handle != INVALID_HANDLE) IndicatorRelease(g_ema20Handle);
    if(g_ema50Handle != INVALID_HANDLE) IndicatorRelease(g_ema50Handle);
    if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
    if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
}
