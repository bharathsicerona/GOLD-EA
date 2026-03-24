#property strict
#property version   "1.00"
#property description "M1 Scalper EA v1 for XAUUSD with Dynamic SL Shrinking and 1:3 RR"

#include <Trade/Trade.mqh>

CTrade trade;
int g_symbolDigits  = 2;
datetime g_lastBarTime   = 0;
datetime g_lastTradeTime = 0;
datetime g_lastLossTime = 0;
datetime g_tradeMinuteStamp = 0;
int      g_tradesThisMinute = 0;
int      g_consecutiveLosses = 0;

#include "XAUUSD_M1_Scalper_Inputs.mqh"
#include "GoldEA_Common_Core.mqh"
#include "XAUUSD_M1_Scalper_Indicators.mqh"
#include "XAUUSD_M1_Scalper_Entry.mqh"
#include "XAUUSD_M1_Scalper_Risk.mqh"
#include "XAUUSD_M1_Scalper_Logging.mqh"
#include "XAUUSD_M1_Scalper_Management.mqh"
  
bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == InpTradeSymbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         return true;
     }
   return false;
  }

DecisionContext PickBestDecision(const DecisionContext &buyContext,const DecisionContext &sellContext)
  {
   DecisionContext result;
   result.valid    = false;
   result.type     = POSITION_TYPE_BUY;
   result.action   = "TICK_EVAL";
   result.phase    = "LIVE_PREVIEW";
   result.decision = "SKIPPED";
   result.reason   = "NO_SETUP";
   result.status   = buyContext.status;
   result.sessionName = buyContext.sessionName;
   result.strategyName = "EVAL_PENDING";
   result.price    = buyContext.price;
   result.rsi      = buyContext.rsi;
   result.ema50    = buyContext.ema50;
   result.ema20    = buyContext.ema20;
   result.atr      = buyContext.atr;
   result.spread   = buyContext.spread;
   result.score    = MathMax(buyContext.score,sellContext.score);
   result.isCounterTrend = false;
   result.riskPercent = InpMaxRiskPercent;

   if(buyContext.valid && (!sellContext.valid || buyContext.score >= sellContext.score))
      return buyContext;
   if(sellContext.valid)
      return sellContext;

   if(buyContext.reason == "SESSION_BLOCKED") result.reason = "SESSION_BLOCKED";
   else if(buyContext.reason == "SPREAD_TOO_HIGH") result.reason = "SPREAD_TOO_HIGH";
   else if(buyContext.score >= sellContext.score)
     {
      result.strategyName = buyContext.strategyName;
      result.reason = buyContext.reason;
     }
   else
     {
      result.strategyName = sellContext.strategyName;
      result.reason = sellContext.reason;
     }
   return result;
  }

void ExecuteTrade(const DecisionContext &context)
  {
   double entryPrice = 0.0;
   double slDistance = 0.0;
   double lotSize = 0.0;
   string blockReason = "";

   if(!CanPlaceTrade(context, blockReason, entryPrice, slDistance, lotSize))
     {
      DebugPrint(StringFormat("Trade blocked: %s", blockReason));
      LogToCSV("TRADE_SKIPPED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema20,context.atr,context.spread,context.score,context.decision,blockReason);
      return;
     }

   double tpDistance = slDistance * InpRewardRiskRatio;
   
   double slPrice = 0.0;
   double tpPrice = 0.0;
   
   ulong tradeId = NextTradeId();
   string commentText = StringFormat("GoldEA#%I64u %s",tradeId,context.decision);

   if(context.type == POSITION_TYPE_BUY)
     {
      slPrice = NormalizeDouble(entryPrice - slDistance, g_symbolDigits);
      tpPrice = NormalizeDouble(entryPrice + tpDistance, g_symbolDigits);
     }
   else
     {
      slPrice = NormalizeDouble(entryPrice + slDistance, g_symbolDigits);
      tpPrice = NormalizeDouble(entryPrice - tpDistance, g_symbolDigits);
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);

   bool success = false;
   if(context.type == POSITION_TYPE_BUY)
      success = trade.Buy(lotSize, InpTradeSymbol, 0.0, slPrice, tpPrice, commentText);
   else
      success = trade.Sell(lotSize, InpTradeSymbol, 0.0, slPrice, tpPrice, commentText);

   if(success)
     {
      g_lastTradeTime = TimeTradeServer();
      ResetTradeMinuteCounterIfNeeded();
      g_tradesThisMinute++;
      double tickSize = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(InpTradeSymbol, SYMBOL_TRADE_TICK_VALUE);
      double actualRiskPct = ((lotSize * (slDistance / tickSize) * tickValue) / AccountInfoDouble(ACCOUNT_EQUITY)) * 100.0;

      DebugPrint(StringFormat("%s executed: tradeId=%I64u lot=%.2f entry=%.2f sl=%.2f tp=%.2f",context.decision,tradeId,lotSize,entryPrice,slPrice,tpPrice));
      LogToCSV(context.decision + "_EXECUTED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema20,context.atr,context.spread,context.score,context.decision,StringFormat("TRADE_ID_%I64u",tradeId));

      if(InpEnablePushAlerts || InpEnableEmailAlerts)
        {
         string alertSubject = StringFormat("GoldEA %s %s Executed", context.strategyName, context.decision);
         string alertMsg = StringFormat("Action: %s %s\nType: %s\nActual Risk: %.2f%%\nLot: %.2f\nEntry: %.2f\nSL: %.2f\nTP Dist: %.2f points\nScore: %d",
                                        context.decision, InpTradeSymbol, context.strategyName, actualRiskPct, lotSize, entryPrice, slPrice, tpDistance / _Point, context.score);
         if(InpEnablePushAlerts) SendNotification(alertSubject + "\n" + alertMsg);
         if(InpEnableEmailAlerts) SendMail(alertSubject, alertMsg);
        }
     }
   else
     {
      string failReason = StringFormat("ORDER_FAILED_%d_%s",trade.ResultRetcode(),trade.ResultRetcodeDescription());
      DebugPrint(StringFormat("%s order failed: %s",context.decision,failReason));
      LogToCSV(context.decision + "_FAILED",context.sessionName,context.strategyName,entryPrice,context.rsi,context.ema50,context.ema20,context.atr,context.spread,context.score,context.decision,failReason);
     }
  }

int OnInit()
  {
   g_symbolDigits = (int)SymbolInfoInteger(InpTradeSymbol, SYMBOL_DIGITS);
   
   // --- Load Indicators ---
   g_ema20Handle = iMA(InpTradeSymbol, InpTimeframe, InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_ema20Handle == INVALID_HANDLE)
     {
      PrintFormat("Error creating Fast EMA indicator for symbol '%s'. Error code: %d", InpTradeSymbol, GetLastError());
      return INIT_FAILED;
     }

   g_ema50Handle = iMA(InpTradeSymbol, InpTimeframe, InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_ema50Handle == INVALID_HANDLE)
     {
      PrintFormat("Error creating Slow EMA indicator for symbol '%s'. Error code: %d", InpTradeSymbol, GetLastError());
      return INIT_FAILED;
     }

   g_rsiHandle   = iRSI(InpTradeSymbol, InpTimeframe, InpRsiPeriod, PRICE_CLOSE);
   if(g_rsiHandle == INVALID_HANDLE)
     {
      PrintFormat("Error creating RSI indicator for symbol '%s'. Error code: %d", InpTradeSymbol, GetLastError());
      return INIT_FAILED;
     }
     
   g_atrHandle   = iATR(InpTradeSymbol, InpTimeframe, InpAtrPeriod);
   if(g_atrHandle == INVALID_HANDLE)
     {
      PrintFormat("Error creating ATR indicator for symbol '%s'. Error code: %d", InpTradeSymbol, GetLastError());
      return INIT_FAILED;
     }

   // --- Initialize Trade Engine ---
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(InpTradeSymbol);
   
   // --- Finalize ---
   CleanupOldLogs();
   DebugPrint(StringFormat("M1 EA initialized on %s timeframe=%d",InpTradeSymbol,InpTimeframe));
   LogToCSV("INIT","NONE","NONE",0.0,0.0,0.0,0.0,0.0,0,0,"ACTIVE","EA_INITIALIZED");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_ema20Handle != INVALID_HANDLE) IndicatorRelease(g_ema20Handle);
   if(g_ema50Handle != INVALID_HANDLE) IndicatorRelease(g_ema50Handle);
   if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);

   if(InpEnableDashboard)
     {
      string labels[7] = {"Title","Session","Strategy","ATR","Score","Decision","Reason"};
      for(int i = 0; i < 7; ++i)
         ObjectDelete(0,g_dashboardPrefix + labels[i]);
     }
   LogToCSV("DEINIT","NONE","NONE",0.0,0.0,0.0,0.0,0.0,0,0,"STOPPED",StringFormat("REASON_%d",reason));
  }

bool IsNewBar()
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(InpTradeSymbol, InpTimeframe, 0, 1, times) != 1) return false;
   if(times[0] == g_lastBarTime) return false;
   
   g_lastBarTime = times[0];
   return true;
  }

void EvaluateTickAndDashboard()
  {
   DecisionContext buyContext = RunScalperStrategy(POSITION_TYPE_BUY, false);
   DecisionContext sellContext = RunScalperStrategy(POSITION_TYPE_SELL, false);
   buyContext.phase  = "LIVE_PREVIEW";
   sellContext.phase = "LIVE_PREVIEW";

   ResetTradeMinuteCounterIfNeeded();
   if(HasOpenPosition())
     {
      buyContext.valid = false; buyContext.reason = "MAX_GLOBAL_TRADES_REACHED";
      sellContext.valid = false; sellContext.reason = "MAX_GLOBAL_TRADES_REACHED";
     }
   else if(g_tradesThisMinute >= InpMaxTradesPerMinute)
     {
      buyContext.valid = false; buyContext.reason = "MAX_TRADES_PER_MINUTE";
      sellContext.valid = false; sellContext.reason = "MAX_TRADES_PER_MINUTE";
     }
   else if(g_consecutiveLosses >= InpMaxConsecutiveLosses)
     {
      buyContext.valid = false; buyContext.reason = "MAX_CONSECUTIVE_LOSSES";
      sellContext.valid = false; sellContext.reason = "MAX_CONSECUTIVE_LOSSES";
     }
   else if(IsCooldownActive())
     {
      buyContext.valid = false; buyContext.reason = "COOLDOWN_ACTIVE";
      sellContext.valid = false; sellContext.reason = "COOLDOWN_ACTIVE";
     }

   DecisionContext current = PickBestDecision(buyContext, sellContext);
   UpdateDashboard(current);

   if(InpLogEveryTick)
      LogToCSV("LIVE_TICK_PREVIEW",current.sessionName,current.strategyName,current.price,current.rsi,current.ema50,current.ema20,current.atr,current.spread,current.score,current.decision,current.reason);
  }

void OnTick()
  {
   bool isNewBar = IsNewBar();
   ManageOpenPosition(isNewBar);
   EvaluateTickAndDashboard();

   if(!isNewBar) return;

   DecisionContext buyContext = RunScalperStrategy(POSITION_TYPE_BUY, true);
   DecisionContext sellContext = RunScalperStrategy(POSITION_TYPE_SELL, true);
   buyContext.phase  = "BAR_CLOSE_SIGNAL";
   sellContext.phase = "BAR_CLOSE_SIGNAL";
   
   DecisionContext best = PickBestDecision(buyContext, sellContext);
   
   if(best.valid)
     {
      LogToCSV("BAR_CLOSE_SIGNAL",best.sessionName,best.strategyName,best.price,best.rsi,best.ema50,best.ema20,best.atr,best.spread,best.score,best.decision,best.reason);
      ExecuteTrade(best);
     }
  }
