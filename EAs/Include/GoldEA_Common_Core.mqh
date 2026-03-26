#ifndef GOLDEA_COMMON_CORE_MQH
#define GOLDEA_COMMON_CORE_MQH

void DebugPrint(const string message)
  {
   if(InpEnableDebugPrints)
      Print("[GoldEA] ",message);
  }

string CurrentTimeText()
  {
   return TimeToString(TimeTradeServer(),TIME_DATE | TIME_SECONDS);
  }

string BuildGlobalKey(const string label)
  {
   return StringFormat("EA_%I64u_%s",InpMagicNumber,label);
  }

string BuildStateKey(const string label,const ulong ticket)
  {
   return StringFormat("EA_%I64u_%s_%I64u",InpMagicNumber,label,ticket);
  }

ulong NextTradeId()
  {
   string key = BuildGlobalKey("TradeCounter");
   double current = 0.0;
   if(GlobalVariableCheck(key))
      current = GlobalVariableGet(key);

   current += 1.0;
   GlobalVariableSet(key,current);
   return (ulong)current;
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
      DebugPrint(StringFormat("Warning: Calculated lot (%.4f) < Min Lot (%.2f). Forcing Min Lot.", volume, minLot));
      normalized = minLot;
     }
   else if(normalized > maxLot)
     {
      DebugPrint(StringFormat("Warning: Calculated lot (%.2f) > Max Lot (%.2f). Capping to Max Lot.", normalized, maxLot));
      normalized = maxLot;
     }

   int digits = 2;
   if(lotStep == 0.001) digits = 3;
   if(lotStep == 0.1) digits = 1;
   if(lotStep == 1.0) digits = 0;

   return NormalizeDouble(normalized, digits);
  }

bool GetIndicatorValue(const int handle,const int shift,double &value,const int bufferIndex = 0)
  {
   double buffer[];
   ArraySetAsSeries(buffer,true);
   if(CopyBuffer(handle,bufferIndex,shift,1,buffer) != 1)
      return false;

   value = buffer[0];
   return true;
  }

void SetDashboardLabelLine(const string prefix,const string name,const string text,const color textColor,const int row)
  {
   string objectName = prefix + name;
   if(ObjectFind(0,objectName) < 0)
     {
      ObjectCreate(0,objectName,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,objectName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,objectName,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,objectName,OBJPROP_YDISTANCE,20 + row * 18);
      ObjectSetInteger(0,objectName,OBJPROP_FONTSIZE,10);
      ObjectSetString(0,objectName,OBJPROP_FONT,"Consolas");
     }
   ObjectSetString(0,objectName,OBJPROP_TEXT,text);
   ObjectSetInteger(0,objectName,OBJPROP_COLOR,textColor);
  }

void CleanupLogsByPattern(const string pattern,const int minNameLen,const int dateTokenStart)
  {
   /*
   if(InpLogRetentionDays <= 0)
      return;

   string fileName;
   long searchHandle = FileFindFirst(pattern, fileName);
   if(searchHandle != INVALID_HANDLE)
     {
      datetime threshold = TimeTradeServer() - (InpLogRetentionDays * 86400);
      do
        {
         if(StringLen(fileName) < minNameLen)
            continue;

         string dateToken = StringSubstr(fileName,dateTokenStart,8);
         string formattedDate = StringFormat("%s.%s.%s",StringSubstr(dateToken,0,4),StringSubstr(dateToken,4,2),StringSubstr(dateToken,6,2));
         datetime fileDate = StringToTime(formattedDate);
         if(fileDate > 0 && fileDate < threshold)
           {
            FileDelete(fileName);
            DebugPrint(StringFormat("Deleted old log file: %s", fileName));
           }
        }
      while(FileFindNext(searchHandle, fileName));
      FileFindClose(searchHandle);
     }
   */
  }

#endif // GOLDEA_COMMON_CORE_MQH
