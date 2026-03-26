#property strict
#property version   "1.00"
#property description "Beginner-friendly XAUUSDm trend pullback EA for MT5"

#include <Trade/Trade.mqh>

string EA_TYPE = "BEGINNER";

void Log(string message)
{
    Print("[" + EA_TYPE + "][GoldEA] " + message);
}


input string           InpTradeSymbol          = "XAUUSDm";
input ENUM_TIMEFRAMES  InpTimeframe            = PERIOD_M5;
input ulong            InpMagicNumber          = 26032027;

input int              InpFastEmaPeriod        = 20;
input int              InpSlowEmaPeriod        = 100;
input int              InpRsiPeriod            = 14;
input int              InpAtrPeriod            = 14;

input double           InpRsiBuyMin            = 52.0;
input double           InpRsiBuyMax            = 68.0;
input double           InpRsiSellMin           = 32.0;
input double           InpRsiSellMax           = 48.0;

input double           InpRiskPercent          = 1.0;
input double           InpStopAtrMultiplier    = 1.3;
input double           InpTakeProfitMultiplier = 1.8;
input double           InpMinAtrPoints         = 120.0;
input double           InpPullbackAtrFactor    = 0.20;
input int              InpMaxSpreadPoints      = 90;

input int              InpLondonStartHour      = 8;
input int              InpLondonEndHour        = 17;
input int              InpNewYorkStartHour     = 13;
input int              InpNewYorkEndHour       = 22;

CTrade trade;

int      g_fastEmaHandle = INVALID_HANDLE;
int      g_slowEmaHandle = INVALID_HANDLE;
int      g_rsiHandle     = INVALID_HANDLE;
int      g_atrHandle     = INVALID_HANDLE;
int      g_symbolDigits  = 2;
datetime g_lastBarTime   = 0;
datetime g_lastBuyBar    = 0;
datetime g_lastSellBar   = 0;

struct SimpleSignal
  {
   bool   valid;
   double atr;
   string reason;
  };

bool GetIndicatorValue(const int handle,const int shift,double &value)
  {
   double buffer[];
   ArraySetAsSeries(buffer,true);
   if(CopyBuffer(handle,0,shift,1,buffer) != 1)
      return false;

   value = buffer[0];
   return true;
  }

bool GetRates(MqlRates &rates[],const int count)
  {
   ArraySetAsSeries(rates,true);
   return CopyRates(InpTradeSymbol,InpTimeframe,0,count,rates) == count;
  }

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

bool IsTradingSession()
  {
   MqlDateTime serverTime;
   TimeToStruct(TimeTradeServer(),serverTime);
   int hour = serverTime.hour;

   bool london  = (hour >= InpLondonStartHour && hour < InpLondonEndHour);
   bool newYork = (hour >= InpNewYorkStartHour && hour < InpNewYorkEndHour);
   return (london || newYork);
  }

bool SpreadIsAcceptable()
  {
   return (SymbolInfoInteger(InpTradeSymbol,SYMBOL_SPREAD) <= InpMaxSpreadPoints);
  }

bool PositionExists(const ENUM_POSITION_TYPE type)
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

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
         return true;
     }

   return false;
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
      Log(StringFormat("Warning: Calculated lot (%.4f) < Min Lot (%.2f). Forcing Min Lot.", volume, minLot));
      normalized = minLot;
     }
   else if(normalized > maxLot)
     {
      Log(StringFormat("Warning: Calculated lot (%.2f) > Max Lot (%.2f). Capping to Max Lot.", normalized, maxLot));
      normalized = maxLot;
     }
     
   int digits = 2;
   if(lotStep == 0.001) digits = 3;
   if(lotStep == 0.1) digits = 1;
   if(lotStep == 1.0) digits = 0;
   
   return NormalizeDouble(normalized, digits);
  }

double CalculateLotSize(const double stopDistance)
  {
   if(stopDistance <= 0.0)
     {
      Log("Error: Invalid Stop Loss distance. Distance is 0.");
      return SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) > 0 ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) : 0.01;
     }

   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
   double tickSize   = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
     {
      Log(StringFormat("Error: Invalid parameters. TickValue: %f, TickSize: %f", tickValue, tickSize));
      return SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) > 0 ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) : 0.01;
     }

   double moneyPerLot = (stopDistance / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
     {
      Log("Error: Calculated loss per lot is zero or negative.");
      return SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) > 0 ? SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN) : 0.01;
     }

   double rawLot = riskAmount / moneyPerLot;
   double finalLot = NormalizeVolume(rawLot);
   
   Log(StringFormat("Lot Calc: Bal=%.2f, Risk=%.2f, StopDist=%.1f, LossPerLot=%.2f, RawLot=%.5f, FinalLot=%.2f",
               AccountInfoDouble(ACCOUNT_BALANCE), riskAmount, stopDistance, moneyPerLot, rawLot, finalLot));
               
   return finalLot;
  }

SimpleSignal BuildBuySignal()
  {
   SimpleSignal signal;
   signal.valid  = false;
   signal.atr    = 0.0;
   signal.reason = "";

   MqlRates rates[];
   if(!GetRates(rates,4))
     {
      signal.reason = "Not enough candle data";
      return signal;
     }

   double fastEma = 0.0;
   double slowEma = 0.0;
   double rsi     = 0.0;
   if(!GetIndicatorValue(g_fastEmaHandle,1,fastEma) ||
      !GetIndicatorValue(g_slowEmaHandle,1,slowEma) ||
      !GetIndicatorValue(g_rsiHandle,1,rsi) ||
      !GetIndicatorValue(g_atrHandle,1,signal.atr))
     {
      signal.reason = "Indicator data unavailable";
      return signal;
     }

   bool trendOk      = (rates[1].close > slowEma && fastEma > slowEma);
   bool rsiOk        = (rsi >= InpRsiBuyMin && rsi <= InpRsiBuyMax);
   bool pullbackOk   = (MathAbs(rates[1].low - fastEma) <= signal.atr * InpPullbackAtrFactor);
   bool candleOk     = (rates[1].close > rates[1].open);
   bool volatilityOk = (signal.atr / _Point >= InpMinAtrPoints);

   signal.valid = trendOk && rsiOk && pullbackOk && candleOk && volatilityOk;

   if(!volatilityOk)
      signal.reason = "ATR below minimum";
   else if(!trendOk)
      signal.reason = "Trend filter failed";
   else if(!rsiOk)
      signal.reason = "RSI buy zone failed";
   else if(!pullbackOk)
      signal.reason = "No pullback near fast EMA";
   else if(!candleOk)
      signal.reason = "Bullish candle missing";
   else
      signal.reason = "Buy setup valid";

   return signal;
  }

SimpleSignal BuildSellSignal()
  {
   SimpleSignal signal;
   signal.valid  = false;
   signal.atr    = 0.0;
   signal.reason = "";

   MqlRates rates[];
   if(!GetRates(rates,4))
     {
      signal.reason = "Not enough candle data";
      return signal;
     }

   double fastEma = 0.0;
   double slowEma = 0.0;
   double rsi     = 0.0;
   if(!GetIndicatorValue(g_fastEmaHandle,1,fastEma) ||
      !GetIndicatorValue(g_slowEmaHandle,1,slowEma) ||
      !GetIndicatorValue(g_rsiHandle,1,rsi) ||
      !GetIndicatorValue(g_atrHandle,1,signal.atr))
     {
      signal.reason = "Indicator data unavailable";
      return signal;
     }

   bool trendOk      = (rates[1].close < slowEma && fastEma < slowEma);
   bool rsiOk        = (rsi >= InpRsiSellMin && rsi <= InpRsiSellMax);
   bool pullbackOk   = (MathAbs(rates[1].high - fastEma) <= signal.atr * InpPullbackAtrFactor);
   bool candleOk     = (rates[1].close < rates[1].open);
   bool volatilityOk = (signal.atr / _Point >= InpMinAtrPoints);

   signal.valid = trendOk && rsiOk && pullbackOk && candleOk && volatilityOk;

   if(!volatilityOk)
      signal.reason = "ATR below minimum";
   else if(!trendOk)
      signal.reason = "Trend filter failed";
   else if(!rsiOk)
      signal.reason = "RSI sell zone failed";
   else if(!pullbackOk)
      signal.reason = "No pullback near fast EMA";
   else if(!candleOk)
      signal.reason = "Bearish candle missing";
   else
      signal.reason = "Sell setup valid";

   return signal;
  }

bool OpenBuyTrade(const SimpleSignal &signal)
  {
   double ask          = SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK);
   double stopDistance = signal.atr * InpStopAtrMultiplier;
   double sl           = NormalizeDouble(ask - stopDistance,g_symbolDigits);
   double tp           = NormalizeDouble(ask + stopDistance * InpTakeProfitMultiplier,g_symbolDigits);
   double lot          = CalculateLotSize(stopDistance);

   if(lot <= 0.0)
      return false;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   if(!trade.Buy(lot,InpTradeSymbol,0.0,sl,tp,"Beginner XAUUSDm Buy"))
      return false;

   g_lastBuyBar = g_lastBarTime;
   return true;
  }

bool OpenSellTrade(const SimpleSignal &signal)
  {
   double bid          = SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
   double stopDistance = signal.atr * InpStopAtrMultiplier;
   double sl           = NormalizeDouble(bid + stopDistance,g_symbolDigits);
   double tp           = NormalizeDouble(bid - stopDistance * InpTakeProfitMultiplier,g_symbolDigits);
   double lot          = CalculateLotSize(stopDistance);

   if(lot <= 0.0)
      return false;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   if(!trade.Sell(lot,InpTradeSymbol,0.0,sl,tp,"Beginner XAUUSDm Sell"))
      return false;

   g_lastSellBar = g_lastBarTime;
   return true;
  }

void EvaluateEntries()
  {
   if(!SpreadIsAcceptable() || !IsTradingSession())
      return;

   if(!PositionExists(POSITION_TYPE_BUY) && g_lastBuyBar != g_lastBarTime)
     {
      SimpleSignal buySignal = BuildBuySignal();
      if(buySignal.valid)
         OpenBuyTrade(buySignal);
     }

   if(!PositionExists(POSITION_TYPE_SELL) && g_lastSellBar != g_lastBarTime)
     {
      SimpleSignal sellSignal = BuildSellSignal();
      if(sellSignal.valid)
         OpenSellTrade(sellSignal);
     }
  }

int OnInit()
  {
   g_symbolDigits  = (int)SymbolInfoInteger(InpTradeSymbol,SYMBOL_DIGITS);
   g_fastEmaHandle = iMA(InpTradeSymbol,InpTimeframe,InpFastEmaPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_slowEmaHandle = iMA(InpTradeSymbol,InpTimeframe,InpSlowEmaPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_rsiHandle     = iRSI(InpTradeSymbol,InpTimeframe,InpRsiPeriod,PRICE_CLOSE);
   g_atrHandle     = iATR(InpTradeSymbol,InpTimeframe,InpAtrPeriod);

   if(g_fastEmaHandle == INVALID_HANDLE ||
      g_slowEmaHandle == INVALID_HANDLE ||
      g_rsiHandle == INVALID_HANDLE ||
      g_atrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(InpTradeSymbol);
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
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
  }

void OnTick()
  {
   if(!IsNewBar())
      return;

   EvaluateEntries();
  }
