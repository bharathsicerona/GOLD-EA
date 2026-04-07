#property strict
#property version   "3.00"
#property description "M1 Trend-RSI Continuation EA (Single Strategy)"

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
   if(StringFind(u, "WEAK_CANDLE_DYNAMIC") >= 0) return "WEAK_CANDLE_DYNAMIC";
   if(StringFind(u, "CHOP") >= 0) return "CHOP_MARKET_DYNAMIC";
   if(StringFind(u, "HTF_BIAS") >= 0) return "HTF_BIAS_BLOCK";
   if(StringFind(u, "TOO_FAR_FROM_EMA") >= 0) return "TOO_FAR_FROM_EMA";
   if(StringFind(u, "NO_MOMENTUM") >= 0) return "NO_MOMENTUM";
   if(StringFind(u, "WEAK_SAFE_CANDLE") >= 0) return "WEAK_SAFE_CANDLE";
   if(StringFind(u, "RSI_TOO_HIGH") >= 0) return "RSI_TOO_HIGH";
   if(StringFind(u, "RSI_TOO_LOW") >= 0) return "RSI_TOO_LOW";
   if(StringFind(u, "SPREAD") >= 0) return "HIGH_SPREAD";
   if(StringFind(u, "NY_WEAK") >= 0) return "NY_WEAK_CONDITION";
   if(StringFind(u, "SESSION") >= 0) return "SESSION_BLOCK";
   if(StringFind(u, "COOLDOWN") >= 0) return "COOLDOWN_ACTIVE";
   if(StringFind(u, "MAX") >= 0) return "MAX_TRADES_REACHED";
   if(StringFind(u, "MARGIN") >= 0) return "INSUFFICIENT_MARGIN";
    if(StringFind(u, "ORDER_FAILED") >= 0) return "ORDER_FAILED";
    if(StringFind(u, "RISK_ENGINE") >= 0) return "RISK_ENGINE_BLOCK";
   return "OTHER";
}

void CountRejection(const string reasonCode)
{
   if(reasonCode == "HIGH_SPREAD") rejectSpread++;
   else if(reasonCode == "SESSION_BLOCK") rejectSession++;
   else if(reasonCode == "COOLDOWN_ACTIVE") rejectCooldown++;
   else if(reasonCode == "MAX_TRADES_REACHED") rejectMaxTrades++;
   else if(reasonCode == "INSUFFICIENT_MARGIN") rejectMargin++;
   else rejectOther++;
}

void LogRejection(const string side, const string reasonCode, const double lot)
{
   totalSkipped++;
   CountRejection(reasonCode);
   datetime barTime = iTime(_Symbol, PERIOD_M1, 1);
   LogTyped("REJECTION", StringFormat("[M1_TREND_RSI_CONTINUATION] %s rejected: barTime=%s reason=%s lot=%.2f balance=%.2f", side, TimeToString(barTime), reasonCode, lot, AccountInfoDouble(ACCOUNT_BALANCE)));
}

void LogStatsIfDue()
{
   if(totalTrades <= 0 || (totalTrades % STATS_PRINT_INTERVAL) != 0)
      return;
   LogTyped("STATS", StringFormat("signals=%d trades=%d skipped=%d win=%d loss=%d",
                                   totalSignals, totalTrades, totalSkipped, totalWins, totalLosses));
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
int g_ema100Handle = INVALID_HANDLE;
int g_rsiHandle   = INVALID_HANDLE;
int g_atrHandle   = INVALID_HANDLE;

// Include all modular components
#include "XAUUSD_M1_Scalper_Inputs.mqh"
#include "../Include/GoldEA_Common_Core.mqh"
#include "XAUUSD_M1_Scalper_Indicators.mqh"
#include "XAUUSD_M1_Scalper_Entry.mqh"
#include "../Include/GoldEA_Unified_Risk.mqh" 
#include "XAUUSD_M1_Scalper_HighRisk_Management.mqh"
#include "../Include/GoldEA_Limit_Execution.mqh"

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

bool HasSufficientMargin(const ENUM_POSITION_TYPE type, const double volume, const double entryPrice)
{
    if (volume <= 0.0) return false;
    double marginRequired = 0.0;
    if (!OrderCalcMargin((type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, volume, entryPrice, marginRequired))
        return false;
    return (AccountInfoDouble(ACCOUNT_MARGIN_FREE) >= marginRequired * 1.5);
}

bool IsCooldownActive()
{
    datetime now = TimeTradeServer();
    if (g_lastLossTime > 0 && InpCooldownAfterLoss > 0 && (now - g_lastLossTime) < (datetime)InpCooldownAfterLoss)
        return true;
    return false;
}

//+------------------------------------------------------------------+
//| ExecuteTrade - Simplified Signal Execution                       |
//+------------------------------------------------------------------+
void ExecuteTrade(const ENUM_POSITION_TYPE direction)
{
    string strategyName = "M1_TREND_RSI_CONTINUATION";
    double lotSize = 0.01; // Using fixed 0.01 lot for M1 scalper core
    
    double entryPrice = (direction == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double slPrice = 0;
    
    // Fetch ATR for dynamic risk
    double atrVal = 0;
    if (!GetIndicatorValue(g_atrHandle, 1, atrVal)) atrVal = 0.5; // Fallback to safe floor if error
    double atrDistance = atrVal * InpStopAtrMultiplier;

    if (!CalculateTradeRisk((direction == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), entryPrice, lotSize, slPrice, atrDistance))
    {
        LogRejection((direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), "RISK_ENGINE_BLOCK", lotSize);
        return;
    }

    double finalSlDistance = MathAbs(entryPrice - slPrice);
    double tpDistance = finalSlDistance * 3.0; // 3R TP as runner
    double tpPrice = (direction == POSITION_TYPE_BUY) ? (entryPrice + tpDistance) : (entryPrice - tpDistance);

    slPrice = NormalizeDouble(slPrice, g_symbolDigits);
    tpPrice = NormalizeDouble(tpPrice, g_symbolDigits);

    MqlRates signalBar[];
    ArraySetAsSeries(signalBar, true);
    if(CopyRates(_Symbol, PERIOD_M1, 1, 1, signalBar) != 1)
        return;

    double rawEntry = CalculateLimitPrice((direction == POSITION_TYPE_BUY), signalBar[0].close, signalBar[0].high, signalBar[0].low);
    double limitEntry = NormalizeEntryPrice(rawEntry, (direction == POSITION_TYPE_BUY));
    double limitSl = RecalculateSL((direction == POSITION_TYPE_BUY), limitEntry, finalSlDistance);
    double limitTp = (direction == POSITION_TYPE_BUY) ? (limitEntry + tpDistance) : (limitEntry - tpDistance);
    limitSl = NormalizeDouble(limitSl, g_symbolDigits);
    limitTp = NormalizeDouble(limitTp, g_symbolDigits);
    if(limitEntry <= 0.0 || !MathIsValidNumber(limitEntry))
    {
        PrintFormat("[GoldEA][REJECTION] INVALID_ENTRY price=%.5f", limitEntry);
        return;
    }

    if (!HasSufficientMargin(direction, lotSize, limitEntry)) 
    {
        LogRejection((direction == POSITION_TYPE_BUY) ? "BUY" : "SELL", "INSUFFICIENT_MARGIN", lotSize);
        return;
    }

    if (HasOpenPosition() || HasPendingOrder() || HasAnyPendingOrders())
        return;

    int currentBarCount = Bars(_Symbol, PERIOD_M1);
    ulong orderTicket = PlaceLimitOrder(strategyName,
                                        (direction == POSITION_TYPE_BUY),
                                        limitEntry,
                                        limitSl,
                                        limitTp,
                                        lotSize,
                                        currentBarCount,
                                        0,
                                        strategyName,
                                        finalSlDistance,
                                        0);
    if (orderTicket > 0)
    {
        g_lastTradeBarTime = iTime(_Symbol, PERIOD_M1, 0);
        datetime barTime = iTime(_Symbol, PERIOD_M1, 1);
        string side = (direction == POSITION_TYPE_BUY ? "BUY" : "SELL");

        LogTyped("ORDER", StringFormat("[%s] %s LIMIT_PLACED tradeId=%I64u barTime=%s lot=%.2f entry=%.2f sl=%.2f tp=%.2f",
                 strategyName, side, orderTicket, TimeToString(barTime), lotSize, limitEntry, limitSl, limitTp));
    } 
    else 
    {
        LogRejection((direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), "ORDER_FAILED", lotSize);
    }
}

//+------------------------------------------------------------------+
//| EA Events                                                        |
//+------------------------------------------------------------------+
int OnInit()
{
    g_symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    if (!InitializeIndicators()) return INIT_FAILED;
    trade.SetTypeFillingBySymbol(_Symbol);
    LogTyped("STATS", "init status=ACTIVE strategy=M1_TREND_RSI_CONTINUATION");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ReleaseIndicators();
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
    if (trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        if (HistoryDealSelect(trans.deal)) {
            if (HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == InpMagicNumber) {
                ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
                ulong position_id = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

                if (dealEntry == DEAL_ENTRY_IN) {
                    ulong orderId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_ORDER);
                    string side = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? "BUY" : "SELL";
                    double dealPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
                    double sl = g_pendingOrder.sl;
                    double tp = g_pendingOrder.tp;
                    HandleOrderFilled(orderId);
                    totalTrades++;

                    LogTyped("EXECUTION", StringFormat("[%s] %s executed: tradeId=%I64u barTime=%s lot=%.2f entry=%.2f sl=%.2f tp=%.2f",
                             "M1_TREND_RSI_CONTINUATION", side, position_id, TimeToString((datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME)), 0.01, dealPrice, sl, tp));

                    TradeContext *tCtx = new TradeContext("M1_TREND_RSI_CONTINUATION", side, EA_TYPE);
                    g_tradeContextMap.Add(position_id, tCtx);
                }
                else if (dealEntry == DEAL_ENTRY_OUT) {
                    double dealProfit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
                    
                    string resultType = (dealProfit < 0) ? "STOP_LOSS_HIT" : (dealProfit > 0 ? "TAKE_PROFIT_HIT" : "BREAKEVEN");
                    if (dealProfit < 0) { 
                        g_lastLossTime = TimeCurrent(); 
                        totalLosses++; 
                    } else if (dealProfit > 0) { 
                        totalWins++; 
                    }

                    TradeContext *tCtx = NULL;
                    if(g_tradeContextMap.TryGetValue(position_id, tCtx) && tCtx != NULL)
                    {
                        LogTyped("RESULT", StringFormat("[%s] %s tradeId=%I64u profit=%.2f", tCtx.strategy, resultType, position_id, dealProfit));
                        delete tCtx;
                        g_tradeContextMap.Remove(position_id);
                    }
                    else
                    {
                        LogTyped("RESULT", StringFormat("[%s] %s tradeId=%I64u profit=%.2f", "M1_TREND_RSI_CONTINUATION", resultType, position_id, dealProfit));
                    }
                    
                    g_lastCloseTime = TimeCurrent();
                    LogStatsIfDue();
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| UpdateM1ScalperDashboard - Real-time visual state                |
//+------------------------------------------------------------------+
void UpdateM1ScalperDashboard()
{
    string prefix = "M1_Dash_";
    
    // 0. TITLE
    SetDashboardLabelLine(prefix, "Title", "--- GOLD EA M1 SCALPER (M1_TREND_RSI_CONTINUATION) ---", clrWhite, 0);

    // Fetch indicator values
    double rsiVal=0, ema20=0, ema50=0, ema100=0, atr=0, rsiPrev=0, ema20Prev=0;
    if(!GetIndicatorValue(g_rsiHandle, 1, rsiVal) || !GetIndicatorValue(g_ema20Handle, 1, ema20) || 
       !GetIndicatorValue(g_ema50Handle, 1, ema50) || !GetIndicatorValue(g_ema100Handle, 1, ema100) ||
       !GetIndicatorValue(g_atrHandle, 1, atr) || !GetIndicatorValue(g_rsiHandle, 2, rsiPrev) ||
       !GetIndicatorValue(g_ema20Handle, 2, ema20Prev))
        return;

    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, 5, rates) != 5) return;
    ArraySetAsSeries(rates, true);

    // SECTION 1 — TREND STATE
    double trendStrengthVal = (atr > 0) ? (MathAbs(ema20 - ema50) / atr) : 0;
    // --- ELITE UPGRADE START ---
    string modeText = "SAFE";
    if(trendStrengthVal > InpAggressiveTrendThreshold) modeText = "AGGRESSIVE";
    else if(trendStrengthVal > InpNormalTrendThreshold) modeText = "NORMAL";
    double spreadRatio = (atr > 0) ? ((double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) / atr) : 0.0;
    // --- ELITE UPGRADE END ---
    string trendDir = (ema20 > ema50) ? "UP" : "DOWN";
    string strengthLabel = "WEAK";
    color trendColor = clrTomato;
    
    if(trendStrengthVal > 0.2) { strengthLabel = "STRONG"; trendColor = clrLimeGreen; }
    else if(trendStrengthVal >= 0.1) { strengthLabel = "MEDIUM"; trendColor = clrGold; }
    
    SetDashboardLabelLine(prefix, "Trend", StringFormat("TREND: %s (%s)", trendDir, strengthLabel), trendColor, 1);
    SetDashboardLabelLine(prefix, "Strength", StringFormat("STRENGTH: %.4f", trendStrengthVal), trendColor, 2);

    // SECTION 2 — CHOP DETECTION
    double high5 = rates[0].high, low5 = rates[0].low;
    for(int i=1; i<5; i++) { if(rates[i].high > high5) high5 = rates[i].high; if(rates[i].low < low5) low5 = rates[i].low; }
    bool isChop = (trendStrengthVal < 0.08) && ((high5 - low5) < atr * 1.2);
    SetDashboardLabelLine(prefix, "Chop", StringFormat("CHOP: %s", (isChop ? "YES [BLOCK]" : "NO [OK]")), (isChop ? clrTomato : clrLimeGreen), 3);

    // SECTION 3 — RSI STATE
    string rsiZone = "WEAK (NO TRADE)";
    color rsiColor = clrTomato;
    if(rsiVal > 60) { rsiZone = "LATE (SKIP)"; rsiColor = clrYellow; }
    else if(rsiVal >= 35) { rsiZone = "VALID"; rsiColor = clrLimeGreen; }

    SetDashboardLabelLine(prefix, "RSI", StringFormat("RSI: %.2f (%s)", rsiVal, rsiZone), rsiColor, 4);

    // SECTION 4 — MOMENTUM
    string momStr = "FLAT";
    color momColor = clrYellow;
    if(rsiVal > rsiPrev + 0.01) { momStr = "UP"; momColor = clrLimeGreen; }
    else if(rsiVal < rsiPrev - 0.01) { momStr = "DOWN"; momColor = clrTomato; }
    SetDashboardLabelLine(prefix, "Momentum", StringFormat("MOMENTUM: %s", momStr), momColor, 5);

    // SECTION 4b — CANDLE STRENGTH (PRO VERSION)
    double b1 = MathAbs(rates[1].close - rates[1].open);
    double b2 = MathAbs(rates[2].close - rates[2].open);
    bool isWeakCandle = (b1 < atr * 0.2 && b2 < atr * 0.2);
    SetDashboardLabelLine(prefix, "CandleStr", StringFormat("CANDLE STRENGTH: %s", (isWeakCandle ? "WEAK" : "STRONG")), (isWeakCandle ? clrTomato : clrLimeGreen), 6);

    // SECTION 5 — FILTER STATUS
    string bias = (rates[1].close > ema100) ? "BUY ONLY" : "SELL ONLY";
    SetDashboardLabelLine(prefix, "Bias", StringFormat("BIAS (EMA100): %s", bias), clrPlum, 7);

    double atrArr[]; double atrAvg = atr;
    if(CopyBuffer(g_atrHandle, 0, 1, 20, atrArr) == 20) {
        double sum=0; for(int i=0; i<20; i++) sum+=atrArr[i]; atrAvg = sum/20.0;
    }
    bool atrOk = (atr >= atrAvg * 0.8);
    SetDashboardLabelLine(prefix, "ATR", StringFormat("ATR: %s", (atrOk ? "OK" : "LOW")), (atrOk ? clrLimeGreen : clrTomato), 8);

    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    double sRatio = spreadRatio;
    
    // Spread Status Logic
    string sStatus = "HIGH";
    color sColor = clrYellow;
    if(spread > 500) { sStatus = "HARD REJECT"; sColor = clrTomato; }
    else if(sRatio > 0.25 && trendStrengthVal < 0.15) { sStatus = "REJECT (WEAK TREND)"; sColor = clrTomato; }
    else if(sRatio > 0.25) { sStatus = "HIGH BUT ALLOWED"; sColor = clrYellow; }
    else if(spread <= 250) { sStatus = "GOOD"; sColor = clrLimeGreen; }

    SetDashboardLabelLine(prefix, "Spread", StringFormat("SPREAD: %d (%s)", (int)spread, sStatus), sColor, 9);
    SetDashboardLabelLine(prefix, "Ratio", StringFormat("RATIO: %.2f", sRatio), sColor, 10);
    SetDashboardLabelLine(prefix, "SpreadTrend", StringFormat("TREND: %.4f", trendStrengthVal), clrWhite, 11);
    SetDashboardLabelLine(prefix, "Mode", StringFormat("MODE: %s", modeText), clrAqua, 12);
    
    // Move Cooldown to 12 or similar to keep layout clean for strategy decision
    bool cdReady = !IsCooldownActive() && ((iTime(_Symbol, PERIOD_M1, 0) - g_lastTradeBarTime) >= 180);
    SetDashboardLabelLine(prefix, "Cooldown", StringFormat("COOLDOWN: %s", (cdReady ? "READY" : "WAIT")), (cdReady ? clrLimeGreen : clrTomato), 13);

    // SECTION 6 — FINAL DECISION
    bool baseTrendBuy = (ema20 > ema50) && (ema20 > ema20Prev) && (rates[1].close > ema20) && (rsiVal > rsiPrev) && (rates[1].close > ema100);
    bool baseTrendSell = (ema20 < ema50) && (ema20 < ema20Prev) && (rates[1].close < ema20) && (rsiVal < rsiPrev) && (rates[1].close < ema100);
    bool pullbackOk = (MathAbs(rates[1].close - ema20) <= atr * InpPullbackAtrLimit);
    bool safeCandleOk = (MathAbs(rates[1].close - rates[1].open) > atr * 0.3);
    bool setupBuy = baseTrendBuy;
    bool setupSell = baseTrendSell;
    if(modeText == "SAFE")
    {
        setupBuy = baseTrendBuy && pullbackOk && safeCandleOk && rsiVal >= 40 && rsiVal <= 55;
        setupSell = baseTrendSell && pullbackOk && safeCandleOk && rsiVal >= 40 && rsiVal <= 55;
    }
    else if(modeText == "AGGRESSIVE")
    {
        setupBuy = baseTrendBuy && rsiVal >= 35 && rsiVal <= 65;
        setupSell = baseTrendSell && rsiVal >= 30 && rsiVal <= 65;
    }
    
    // RSI range additional check for Decision
    if(setupBuy && (rsiVal < 35 || rsiVal >= 60)) setupBuy = false;
    if(setupSell && (rsiVal < 30 || rsiVal >= 60)) setupSell = false;

    // Spread logic for Decision (Must match strategy block)
    bool spreadOk = true;
    if (spread > 500) spreadOk = false;
    else if (atr > 0 && sRatio > 0.25 && trendStrengthVal < 0.15) spreadOk = false;

    string statusStr = "WAIT [BLOCK]";
    color statusColor = clrYellow;
    if(!isChop && spreadOk && cdReady && atrOk)
    {
        if(setupBuy) { statusStr = "READY TO BUY [OK]"; statusColor = clrLimeGreen; }
        else if(setupSell) { statusStr = "READY TO SELL [OK]"; statusColor = clrLimeGreen; }
    }
    else if(isChop) { statusStr = "BLOCKED (CHOP)"; statusColor = clrTomato; }
    else if(!spreadOk) { statusStr = "BLOCKED (HIGH SPREAD)"; statusColor = clrTomato; }
    else if(!cdReady) { statusStr = "BLOCKED (COOLDOWN)"; statusColor = clrTomato; }

    SetDashboardLabelLine(prefix, "Status", StringFormat("STATUS: %s", statusStr), statusColor, 14);

    // SECTION 7 — TRADE STATUS
    if(PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
    {
        double p = PositionGetDouble(POSITION_PROFIT);
        double sl = PositionGetDouble(POSITION_SL);
        // --- FIX START ---
        double tp = PositionGetDouble(POSITION_TP);
        // --- FIX END ---
        double openP = PositionGetDouble(POSITION_PRICE_OPEN);
        double vol = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        double locked = 0;
        if(sl > 0)
        {
            double diff = (type == POSITION_TYPE_BUY) ? (sl - openP) : (openP - sl);
            if(diff > 0)
            {
               double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
               locked = (diff / tickSize) * tickValue * vol;
            }
        }
        
        // --- ELITE UPGRADE START ---
        double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        // --- FIX START ---
        double initialR = (tp > 0) ? (MathAbs(tp - openP) / 3.0) : MathAbs(openP - sl);
        // --- FIX END ---
        double priceMove = (type == POSITION_TYPE_BUY) ? (currentPrice - openP) : (openP - currentPrice);
        double rMultiple = (initialR > 0) ? (priceMove / initialR) : 0.0;
        string phase = "<1R";
        if(rMultiple >= 2.0) phase = "2R";
        else if(rMultiple >= 1.0) phase = "1R";

        SetDashboardLabelLine(prefix, "Trade", "TRADE: ACTIVE", clrLimeGreen, 15);
        SetDashboardLabelLine(prefix, "Profit", StringFormat("PROFIT: $%.2f", p), (p >= 0 ? clrLimeGreen : clrTomato), 16);
        double lockedDistance = (type == POSITION_TYPE_BUY) ? (sl - openP) : (openP - sl);
        double lockedR = (initialR > 0.0 && lockedDistance > 0.0) ? (lockedDistance / initialR) : 0.0;
        SetDashboardLabelLine(prefix, "Locked", StringFormat("LOCKED R: %.2f", lockedR), clrGold, 17);
        SetDashboardLabelLine(prefix, "Phase", StringFormat("PHASE: %s | R=%.2f", phase, rMultiple), clrPlum, 18);
        // --- ELITE UPGRADE END ---
        
        long stopLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
        SetDashboardLabelLine(prefix, "StopLvl", StringFormat("STOP LEVEL: %I64d", stopLvl), clrDarkGray, 19);
    }
    else
    {
        SetDashboardLabelLine(prefix, "Trade", "TRADE: NONE", clrWhite, 15);
        SetDashboardLabelLine(prefix, "Profit", "PROFIT: ---", clrDarkGray, 16);
        SetDashboardLabelLine(prefix, "Locked", "LOCKED R: ---", clrDarkGray, 17);
        SetDashboardLabelLine(prefix, "Phase", "PHASE: ---", clrDarkGray, 18);
        
        long stopLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
        SetDashboardLabelLine(prefix, "StopLvl", StringFormat("STOP LEVEL: %I64d", stopLvl), clrDarkGray, 19);
    }
}

void OnTick()
{
    UpdateM1ScalperDashboard();

    int currentBarCount = Bars(_Symbol, PERIOD_M1);
    ManagePendingExpiry(currentBarCount);

    if (HasOpenPosition())
    {
        ManageHighRiskPosition();
        return;
    }

    // --- Entry Bar Logic ---
    static datetime lastBar = 0;
    datetime currentBar = iTime(_Symbol, PERIOD_M1, 0);
    if (currentBar == lastBar) return;
    lastBar = currentBar;

    // --- Basic Cooldowns ---
    if (HasPendingOrder() || HasAnyPendingOrders()) {
        return;
    }

    if (IsCooldownActive()) {
        LogRejection("BOTH", "COOLDOWN_ACTIVE", 0.0);
        return;
    }

    if (g_lastTradeBarTime > 0 && (currentBar - g_lastTradeBarTime) < 180) { // 3 candles spread
        LogRejection("BOTH", "COOLDOWN_ACTIVE", 0.0);
        return;
    }

    // --- Data Gathering ---
    double atr, emaFast, emaSlow;
    if (!GetIndicatorValue(g_atrHandle, 1, atr) || !GetIndicatorValue(g_ema20Handle, 1, emaFast) || !GetIndicatorValue(g_ema50Handle, 1, emaSlow))
        return;

    // --- Adaptive Filters ---
    string filterReason = "";
    if (!AdaptiveFilterCheck(filterReason, atr, emaFast, emaSlow)) {
        LogRejection("BOTH", filterReason, 0.0);
        return;
    }

    // --- Spread Filter ---
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if (spread > InpMaxSpreadPoints) {
        LogRejection("BOTH", "HIGH_SPREAD", 0.0);
        return;
    }

    // --- Signal Evaluation ---
    totalSignals++;
    StrategySignal signal;
    if (ValidateEntry(signal) && signal.valid)
    {
        ExecuteTrade((ENUM_POSITION_TYPE)signal.direction);
    }
}

//+------------------------------------------------------------------+
//| Indicator Functions (Modified for single strategy)               |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    g_ema20Handle = iMA(_Symbol, _Period, InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_ema50Handle = iMA(_Symbol, _Period, InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_ema100Handle = iMA(_Symbol, _Period, InpTrendEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    g_rsiHandle = iRSI(_Symbol, _Period, InpRsiPeriod, PRICE_CLOSE);
    g_atrHandle = iATR(_Symbol, _Period, InpAtrPeriod);
    
    if(g_ema20Handle == INVALID_HANDLE || g_ema50Handle == INVALID_HANDLE || g_ema100Handle == INVALID_HANDLE || 
       g_rsiHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE)
    {
        Log("Indicator initialization failed.");
        return false;
    }
    return true;
}

void ReleaseIndicators()
{
    IndicatorRelease(g_ema20Handle);
    IndicatorRelease(g_ema50Handle);
    IndicatorRelease(g_ema100Handle);
    IndicatorRelease(g_rsiHandle);
    IndicatorRelease(g_atrHandle);
}
