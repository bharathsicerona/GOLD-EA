#ifndef XAUUSD_M1_SCALPER_INDICATORS_MQH
#define XAUUSD_M1_SCALPER_INDICATORS_MQH

int      g_ema20Handle   = INVALID_HANDLE;
int      g_ema50Handle   = INVALID_HANDLE;
int      g_rsiHandle     = INVALID_HANDLE;
int      g_atrHandle     = INVALID_HANDLE;

bool GetIndicatorValue(const int handle, const int shift, double &value)
  {
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) != 1)
      return false;
   value = buffer[0];
   return true;
  }

#endif // XAUUSD_M1_SCALPER_INDICATORS_MQH
