#ifndef XAUUSD_ADAPTIVE_INDICATORS_MQH
#define XAUUSD_ADAPTIVE_INDICATORS_MQH

int      g_fastEmaHandle    = INVALID_HANDLE;
int      g_slowEmaHandle    = INVALID_HANDLE;
int      g_rsiHandle        = INVALID_HANDLE;
int      g_bbHandle         = INVALID_HANDLE;
int      g_atrHandle        = INVALID_HANDLE;
int      g_adxHandle        = INVALID_HANDLE;
int      g_lastAsianDay     = -1;

double   g_asianHigh        = 0.0;
double   g_asianLow         = 0.0;

struct IndicatorSnapshot
  {
   bool   valid;
   int    shift;
   double price;
   double closePrice;
   double openPrice;
   double highPrice;
   double lowPrice;
   double prevHigh;
   double prevLow;
   double fastEma;
   double slowEma;
   double rsi;
   double prevRsi;
   double atr;
   double bbUpper;
   double bbLower;
   double bbBase;
   double adx;
   double prevAdx;
   bool   adxIncreasing;
   bool   emaGapOk;
   bool   trendPersistentBuy;
   bool   trendPersistentSell;
   long   spread;
   bool   spreadOk;
   bool   isHighVol;
   ENUM_SESSION session;
   bool   volatilityOk;
   bool   priceAboveSlow;
   bool   priceBelowSlow;
   bool   emaBullish;
   bool   emaBearish;
   bool   rsiBuyOk;
   bool   rsiSellOk;
   bool   pullbackBuyOk;
   bool   pullbackSellOk;
  };

bool GetIndicatorValue(const int handle,const int shift,double &value,const int bufferIndex = 0)
  {
   double buffer[];
   ArraySetAsSeries(buffer,true);
   if(CopyBuffer(handle,bufferIndex,shift,1,buffer) != 1)
      return false;

   value = buffer[0];
   return true;
  }

bool GetRates(MqlRates &rates[],const int count)
  {
   ArraySetAsSeries(rates,true);
   return (CopyRates(InpTradeSymbol,InpTimeframe,0,count,rates) == count);
  }

ENUM_SESSION GetCurrentSession()
  {
   MqlDateTime serverTime;
   TimeToStruct(TimeTradeServer(),serverTime);
   int hour = serverTime.hour;
   if(hour >= InpAsianStartHour && hour < InpAsianEndHour) return SESSION_ASIAN;
   if(hour >= InpLondonStartHour && hour < InpLondonEndHour) return SESSION_LONDON;
   if(hour >= InpNewYorkStartHour && hour < InpNewYorkEndHour) return SESSION_NEWYORK;
   return SESSION_NONE;
  }

bool DetectVolatility(const double currentAtr)
  {
   return (currentAtr / _Point >= InpVolAtrThreshold);
  }

bool SpreadIsAcceptable()
  {
   long spread = SymbolInfoInteger(InpTradeSymbol,SYMBOL_SPREAD);
   return (spread <= InpMaxSpreadPoints);
  }

void UpdateAsianRange()
  {
   MqlDateTime time;
   TimeToStruct(TimeTradeServer(),time);
   if(time.hour >= InpAsianStartHour && time.hour < InpAsianEndHour)
     {
      if(time.day_of_year != g_lastAsianDay)
        {
         g_asianHigh = 0.0;
         g_asianLow = 999999.0;
         g_lastAsianDay = time.day_of_year;
        }

      double high[], low[];
      if(CopyHigh(InpTradeSymbol,InpTimeframe,0,1,high) == 1 && high[0] > g_asianHigh)
         g_asianHigh = high[0];
      if(CopyLow(InpTradeSymbol,InpTimeframe,0,1,low) == 1 && low[0] < g_asianLow && low[0] > 0.0)
         g_asianLow = low[0];
     }
  }

bool RebuildAsianRangeFromHistory()
  {
   datetime now = TimeTradeServer();
   MqlDateTime serverTime;
   TimeToStruct(now,serverTime);

   serverTime.hour = 0;
   serverTime.min = 0;
   serverTime.sec = 0;
   datetime dayStart = StructToTime(serverTime);
   datetime asianStart = dayStart + (InpAsianStartHour * 3600);
   datetime asianEnd   = dayStart + (InpAsianEndHour * 3600);

   datetime rangeEnd = now;
   if(now >= asianEnd)
      rangeEnd = asianEnd;
   else if(now <= asianStart)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int copied = CopyRates(InpTradeSymbol,InpTimeframe,asianStart,rangeEnd,rates);
   if(copied <= 0)
      return false;

   double high = 0.0;
   double low  = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].high > high)
         high = rates[i].high;

      if((low == 0.0 || rates[i].low < low) && rates[i].low > 0.0)
         low = rates[i].low;
     }

   if(high <= 0.0 || low <= 0.0)
      return false;

   g_asianHigh = high;
   g_asianLow = low;
   g_lastAsianDay = serverTime.day_of_year;
   DebugPrint(StringFormat("Asian range rebuilt from history: high=%.2f low=%.2f bars=%d",g_asianHigh,g_asianLow,copied));
   return true;
  }

bool CalculateIndicators(IndicatorSnapshot &snapshot,const int shift)
  {
   snapshot.valid = false;
   snapshot.shift = shift;

   MqlRates rates[];
   if(!GetRates(rates,shift + 5))
      return false;

   double fEma1, fEma2, sEma1, sEma2;
   if(!GetIndicatorValue(g_fastEmaHandle,shift,snapshot.fastEma) ||
      !GetIndicatorValue(g_fastEmaHandle,shift+1,fEma1) ||
      !GetIndicatorValue(g_fastEmaHandle,shift+2,fEma2) ||
      !GetIndicatorValue(g_slowEmaHandle,shift,snapshot.slowEma) ||
      !GetIndicatorValue(g_slowEmaHandle,shift+1,sEma1) ||
      !GetIndicatorValue(g_slowEmaHandle,shift+2,sEma2) ||
      !GetIndicatorValue(g_rsiHandle,shift,snapshot.rsi) ||
      !GetIndicatorValue(g_rsiHandle,shift+1,snapshot.prevRsi) ||
      !GetIndicatorValue(g_bbHandle,shift,snapshot.bbBase,0) ||
      !GetIndicatorValue(g_bbHandle,shift,snapshot.bbUpper,1) ||
      !GetIndicatorValue(g_bbHandle,shift,snapshot.bbLower,2) ||
      !GetIndicatorValue(g_atrHandle,shift,snapshot.atr) ||
      !GetIndicatorValue(g_adxHandle,shift,snapshot.adx,0) ||
      !GetIndicatorValue(g_adxHandle,shift+1,snapshot.prevAdx,0))
      return false;

   int nextIndex = shift + 1;
   snapshot.price      = (SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID) + SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK)) * 0.5;
   snapshot.closePrice = rates[shift].close;
   snapshot.openPrice  = rates[shift].open;
   snapshot.highPrice  = rates[shift].high;
   snapshot.lowPrice   = rates[shift].low;
   snapshot.prevHigh   = rates[nextIndex].high;
   snapshot.prevLow    = rates[nextIndex].low;
   snapshot.spread     = SymbolInfoInteger(InpTradeSymbol,SYMBOL_SPREAD);
   snapshot.spreadOk   = SpreadIsAcceptable();
   snapshot.session    = GetCurrentSession();
   snapshot.isHighVol  = DetectVolatility(snapshot.atr);
   snapshot.volatilityOk   = (snapshot.atr / _Point >= InpMinAtrPoints);
   snapshot.priceAboveSlow = (snapshot.closePrice > snapshot.slowEma);
   snapshot.priceBelowSlow = (snapshot.closePrice < snapshot.slowEma);
   snapshot.emaBullish     = (snapshot.fastEma > snapshot.slowEma);
   snapshot.emaBearish     = (snapshot.fastEma < snapshot.slowEma);
   snapshot.rsiBuyOk       = (snapshot.rsi >= InpRsiBuyMin && snapshot.rsi <= InpRsiBuyMax);
   snapshot.rsiSellOk      = (snapshot.rsi >= InpRsiSellMin && snapshot.rsi <= InpRsiSellMax);
   snapshot.pullbackBuyOk  = (MathAbs(snapshot.lowPrice - snapshot.fastEma) <= snapshot.atr * InpPullbackAtrFactor);
   snapshot.pullbackSellOk = (MathAbs(snapshot.highPrice - snapshot.fastEma) <= snapshot.atr * InpPullbackAtrFactor);

   snapshot.emaGapOk = (MathAbs(snapshot.fastEma - snapshot.slowEma) >= snapshot.atr * InpEmaGapAtrFactor);
   snapshot.adxIncreasing = (snapshot.adx > snapshot.prevAdx);

   snapshot.trendPersistentBuy = (snapshot.closePrice > snapshot.slowEma && snapshot.fastEma > snapshot.slowEma) &&
                                 (rates[shift+1].close > sEma1 && fEma1 > sEma1) &&
                                 (rates[shift+2].close > sEma2 && fEma2 > sEma2);
   snapshot.trendPersistentSell = (snapshot.closePrice < snapshot.slowEma && snapshot.fastEma < snapshot.slowEma) &&
                                  (rates[shift+1].close < sEma1 && fEma1 < sEma1) &&
                                  (rates[shift+2].close < sEma2 && fEma2 < sEma2);

   snapshot.valid = true;
   return true;
  }

#endif // XAUUSD_ADAPTIVE_INDICATORS_MQH
