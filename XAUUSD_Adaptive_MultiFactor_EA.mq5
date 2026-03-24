#property strict
#property version   "4.00"
#property description "M5 Adaptive Multi-Factor EA v4 for XAUUSDm on MT5 with CSV logging and dashboard"

#include <Trade/Trade.mqh>

CTrade trade;
int      g_symbolDigits     = 2;
datetime g_lastBarTime      = 0;
datetime g_lastBuyBar       = 0;
datetime g_lastSellBar      = 0;
datetime g_lastTradeTime    = 0;

void DebugPrint(const string message);

#include "XAUUSD_Adaptive_Inputs.mqh"
#include "XAUUSD_Adaptive_Indicators.mqh"
#include "XAUUSD_Adaptive_Entry.mqh"
#include "XAUUSD_Adaptive_Risk.mqh"
#include "XAUUSD_Adaptive_Logging.mqh"
#include "XAUUSD_Adaptive_Management.mqh"

bool IsNewBar()
  {
   datetime times[];
   ArraySetAsSeries(times,true);
   if(CopyTime(InpTradeSymbol,InpTimeframe,0,1,times) != 1)
      return false;

   if(times[0] == g_lastBarTime)
      return false;

   g_lastBarTime = times[0];
   return true;
  }

int OnInit()
  {
   g_symbolDigits = (int)SymbolInfoInteger(InpTradeSymbol,SYMBOL_DIGITS);

   g_fastEmaHandle = iMA(InpTradeSymbol,InpTimeframe,InpFastEmaPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(g_fastEmaHandle == INVALID_HANDLE)
     {
      PrintFormat("Error creating Fast EMA indicator for symbol '%s'. Error code: %d", InpTradeSymbol, GetLastError());
      return INIT_FAILED;
     }

   g_slowEmaHandle = iMA(InpTradeSymbol,InpTimeframe,InpSlowEmaPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(g_slowEmaHandle == INVALID_HANDLE)
     {
      PrintFormat("Error creating Slow EMA indicator for symbol '%s'. Error code: %d", InpTradeSymbol, GetLastError());
      return INIT_FAILED;
     }

   g_rsiHandle = iRSI(InpTradeSymbol,InpTimeframe,InpRsiPeriod,PRICE_CLOSE);
   if(g_rsiHandle == INVALID_HANDLE)
     {
      PrintFormat("Error creating RSI indicator for symbol '%s'. Error code: %d", InpTradeSymbol, GetLastError());
      return INIT_FAILED;
     }

   g_bbHandle = iBands(InpTradeSymbol,InpTimeframe,InpBandsPeriod,0,InpBandsDeviation,PRICE_CLOSE);
   if(g_bbHandle == INVALID_HANDLE)
     {
      PrintFormat("Error creating Bollinger Bands indicator for symbol '%s'. Error code: %d", InpTradeSymbol, GetLastError());
      return INIT_FAILED;
     }

   g_atrHandle = iATR(InpTradeSymbol,InpTimeframe,InpAtrPeriod);
   if(g_atrHandle == INVALID_HANDLE)
     {
      PrintFormat("Error creating ATR indicator for symbol '%s'. Error code: %d", InpTradeSymbol, GetLastError());
      return INIT_FAILED;
     }

   g_adxHandle = iADX(InpTradeSymbol,InpTimeframe,InpAdxPeriod);
   if(g_adxHandle == INVALID_HANDLE)
     {
      PrintFormat("Error creating ADX indicator for symbol '%s'. Error code: %d", InpTradeSymbol, GetLastError());
      return INIT_FAILED;
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(InpTradeSymbol);

   RebuildAsianRangeFromHistory();
   CleanupOldLogs();

   DebugPrint(StringFormat("EA initialized on %s timeframe=%d",InpTradeSymbol,InpTimeframe));
   LogToCSV("INIT","NONE","NONE",0.0,0.0,0.0,0.0,0.0,0,0,"ACTIVE","EA_INITIALIZED");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_fastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(g_fastEmaHandle);
   if(g_slowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(g_slowEmaHandle);
   if(g_rsiHandle != INVALID_HANDLE)
      IndicatorRelease(g_rsiHandle);
   if(g_bbHandle != INVALID_HANDLE)
      IndicatorRelease(g_bbHandle);
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   if(g_adxHandle != INVALID_HANDLE)
      IndicatorRelease(g_adxHandle);

   ObjectsDeleteAll(0, "GoldEA_Arrow_");

   if(InpEnableDashboard)
     {
      string labels[7] = {"Title","Session","Strategy","ATR","Score","Decision","Reason"};
      for(int i = 0; i < 7; ++i)
         ObjectDelete(0,g_dashboardPrefix + labels[i]);
     }

   LogToCSV("DEINIT","NONE","NONE",0.0,0.0,0.0,0.0,0.0,0,0,"STOPPED",StringFormat("REASON_%d",reason));
  }

void OnTick()
  {
   UpdateAsianRange();
   EvaluateTickAndDashboard();

   bool newBar = IsNewBar();
   ManageOpenTrades(newBar);

   if(!newBar)
      return;

   CleanupStateGlobals();
   EvaluateEntries();
  }
