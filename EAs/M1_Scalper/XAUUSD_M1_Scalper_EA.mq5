#property strict
#property version   "2.70"
#property description "M1 High-Risk Scalper EA v2.7 - Bi-directional Trading Upgrade"

#include <Trade/Trade.mqh>
#include <Generic/HashMap.mqh>

string EA_TYPE = "M1";

void Log(string message)
{
   Print("[" + EA_TYPE + "][GoldEA] " + message);
}

// --- Global Variables & Objects ---
CTrade trade;
int    g_symbolDigits = 2;
datetime g_lastLossTime = 0;
datetime g_lastCloseTime = 0;
datetime g_lastTradeBarTime = 0;

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
void ExecuteHighRiskTrade(const ENUM_POSITION_TYPE direction)
{
    // --- 1. Get Entry Price & ATR for Initial SL Placement ---
    double entryPrice = (direction == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double atrValue;
    if (!GetIndicatorValue(g_atrHandle, 1, atrValue)) {
        Log("Could not get ATR for trade execution.");
        return;
    }

    // --- 2. Define Initial Trade Parameters ---
    double lotSize = 0.02; // Start with a value > minLot to trigger dynamic % risk calculation.
                           // The risk engine will clamp to minLot and re-evaluate if needed.
    double slDistance = atrValue * InpStopAtrMultiplier;
    double slPrice = (direction == POSITION_TYPE_BUY) 
                   ? entryPrice - slDistance
                   : entryPrice + slDistance;

    // --- 3. APPLY UNIFIED RISK ENGINE ---
    // This function will adjust lotSize and slPrice by reference to meet risk rules.
    if (!CalculateTradeRisk((direction == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, entryPrice, lotSize, slPrice))
    {
        Log("Trade aborted by Unified Risk Engine. Check logs for details.");
        return; // Risk engine determined the trade is not viable.
    }
    
    // --- 4. Calculate Final TP and Normalize Stops ---
    double finalSlDistance = MathAbs(entryPrice - slPrice);
    double tpDistance = finalSlDistance * InpRewardRiskRatio;
    double tpPrice = (direction == POSITION_TYPE_BUY)
                   ? entryPrice + tpDistance
                   : entryPrice - tpDistance;

    // Final normalization after all calculations
    slPrice = NormalizeDouble(slPrice, g_symbolDigits);
    tpPrice = NormalizeDouble(tpPrice, g_symbolDigits);

    // --- 5. Margin Check ---
    if (!HasSufficientMargin(direction, lotSize, entryPrice)) {
        Log("Trade skipped due to insufficient margin for risk-adjusted lot.");
        return;
    }

    // --- 6. Calculate Final Initial Risk for Management Modules ---
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double initialRiskInCurrency = (finalSlDistance / tickSize) * tickValue * lotSize;

    // --- 7. Execute Trade ---
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(20);
    
    ENUM_ORDER_TYPE orderType = (direction == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    
    if (trade.PositionOpen(_Symbol, orderType, lotSize, entryPrice, slPrice, tpPrice)) {
        ulong ticket = trade.ResultDeal();
        Log(StringFormat("TRADE EXECUTED: %s %.2f lots @ %.2f, SL=%.2f, TP=%.f", 
            (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), lotSize, entryPrice, slPrice, tpPrice));

        // --- 8. Store Initial Risk ---
        if (ticket > 0) {
            if (!g_initialRiskMap.ContainsKey(ticket)) {
                g_initialRiskMap.Add(ticket, initialRiskInCurrency);
                Log(StringFormat("Initial risk for ticket #%I64u stored: $%.2f", ticket, initialRiskInCurrency));
            }
            // Record the bar time of the successful entry to prevent same-candle re-entries
            g_lastTradeBarTime = iTime(_Symbol, PERIOD_M1, 0);
        }
    } else {
        Log(StringFormat("Trade execution failed: %s", trade.ResultComment()));
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

    // This function is defined in the logging include
    UpdateDashboard(context);
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

    Log("High-Risk M1 EA v2.1 Initialized.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit: EA Deinitialization                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ReleaseIndicators();
    // g_initialRiskMap is destroyed automatically
    Log("High-Risk M1 EA Deinitialized.");

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
                        Log(StringFormat("Initial risk for closed ticket #%I64u removed.", position_id));
                    }
                    // Cooldown after loss
                    if(HistoryDealGetDouble(trans.deal, DEAL_PROFIT) < 0) {
                        g_lastLossTime = TimeCurrent();
                    }
                    // Cooldown after ANY trade
                    g_lastCloseTime = TimeCurrent();
                }
            }
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
        if (PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double initialRisk = 0;
            g_initialRiskMap.TryGetValue(ticket, initialRisk);

            // Call the new management functions
            ManageTrailingStop(ticket, profit);
            if(initialRisk > 0) {
                UpdateDynamicTP(ticket, profit, initialRisk);
                ExtendTakeProfit(ticket, initialRisk);
            }
        }
        return; // Do not look for new trades if one is open
    }

    // --- 2. Check for New Trade Opportunities ---
    
    // Cooldown after loss check
    if(IsCooldownActive()) {
        return;
    }

    // Unified 20-second cooldown after ANY trade closes to prevent extreme overtrading but maintain frequency
    if (TimeCurrent() - g_lastCloseTime < 20) {
        return;
    }

    // Smart Re-entry Filter: Ensure we are on a new M1 candle since the last trade
    if (iTime(_Symbol, PERIOD_M1, 0) == g_lastTradeBarTime) {
        return;
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
        return; // Prevent extreme overtrading bursts
    }
    
    // Check for BUY signal
    EntryContext buyContext = ValidateEntry(POSITION_TYPE_BUY);
    if (buyContext.isValid) {
        Log("VALID BUY SIGNAL: " + buyContext.reason);
        ExecuteHighRiskTrade(POSITION_TYPE_BUY);
        return;
    } else {
        static datetime lastBuyRejectTime = 0;
        datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
        if (lastBuyRejectTime != currentBarTime) {
            Log("BUY REJECTED: " + buyContext.reason);
            lastBuyRejectTime = currentBarTime;
        }
    }

    // Check for SELL signal
    EntryContext sellContext = ValidateEntry(POSITION_TYPE_SELL);
    if (sellContext.isValid) {
        Log("VALID SELL SIGNAL: " + sellContext.reason);
        ExecuteHighRiskTrade(POSITION_TYPE_SELL);
        return;
    } else {
        static datetime lastSellRejectTime = 0;
        datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
        if (lastSellRejectTime != currentBarTime) {
            Log("SELL REJECTED: " + sellContext.reason);
            lastSellRejectTime = currentBarTime;
        }
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
