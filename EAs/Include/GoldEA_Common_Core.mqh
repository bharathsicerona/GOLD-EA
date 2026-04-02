#ifndef GOLDEA_COMMON_CORE_MQH
#define GOLDEA_COMMON_CORE_MQH

#include <Generic/HashMap.mqh>

//+------------------------------------------------------------------+
//| Trade Context Class for Strategy Attribution                     |
//+------------------------------------------------------------------+
class TradeContext
{
public:
    string strategy;
    string side;
    string eaType; // M1_SCALPER or M5
    
    TradeContext() { strategy=""; side=""; eaType=""; }
    TradeContext(string s, string sd, string eat) { strategy=s; side=sd; eaType=eat; }
};

// Global map to persist strategy data between EXECUTION and RESULT
// We use a pointer map to ensure MQL5 compatibility with complex types (strings).
CHashMap<ulong, TradeContext*> g_tradeContextMap;

#include <Trade/Trade.mqh>

// --- Global Stats and Counters ---
// [REMOVED DUPLICATE INPUTS] Inputs like InpMagicNumber are managed by main EA input files.

void DebugPrint(const string message)
  {
   // Note: InpEnableDebugPrints must be defined in the main EA or its inputs
   Print("[GoldEA][DEBUG] ", message);
  }

string CurrentTimeText()
  {
   return TimeToString(TimeTradeServer(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
  }

string BuildGlobalKey(string prefix, ulong ticket)
  {
   return StringFormat("EA_%I64u_%s_%I64u", (ulong)InpMagicNumber, prefix, ticket);
  }

string BuildStateKey(string prefix, ulong ticket)
  {
   return StringFormat("EA_%I64u_%s_%I64u", (ulong)InpMagicNumber, prefix, ticket);
  }

string CurrentSessionText()
{
    MqlDateTime dt;
    TimeCurrent(dt);
    int hour = dt.hour;
    if(hour >= 0 && hour < 8) return "ASIAN";
    if(hour >= 8 && hour < 14) return "LONDON";
    if(hour >= 14 && hour < 22) return "NY";
    return "OFF";
}

ulong NextTradeId()
{
    long lastId = 0;
    if(GlobalVariableCheck("GoldEA_LastTradeId"))
        lastId = (long)GlobalVariableGet("GoldEA_LastTradeId");
    lastId++;
    GlobalVariableSet("GoldEA_LastTradeId", (double)lastId);
    return (ulong)lastId;
}

double NormalizeVolume(double volume)
{
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double v = MathFloor(volume / step) * step;
    if(v < minVol) v = minVol;
    if(v > maxVol) v = maxVol;
    return NormalizeDouble(v, 2);
}

// Fixed signature to match EA usages: handle, shift, value, buffer
bool GetIndicatorValue(int handle, int shift, double &value, int buffer=0)
{
    double arr[];
    ArraySetAsSeries(arr, true);
    if(CopyBuffer(handle, buffer, shift, 1, arr) == 1)
    {
        value = arr[0];
        return true;
    }
    return false;
}

// Unified Label Helper for Dashboard
void SetDashboardLabelLine(const string prefix, const string name, const string text, const color textColor, int row)
{
    string objName = prefix + name;
    int yDistance = 20 + (row * 18);
    
    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
        ObjectSetString(0, objName, OBJPROP_FONT, "Lucida Console");
    }
    
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yDistance);
}

// Log Cleanup Utility
void CleanupLogsByPattern(const string pattern, int keepDays, int dummy)
{
    string fileName;
    long searchHandle = FileFindFirst(pattern, fileName);
    if(searchHandle == INVALID_HANDLE) return;
    
    datetime now = TimeTradeServer();
    long secondsToKeep = keepDays * 24 * 3600;
    
    do {
        datetime lastMod = (datetime)FileGetInteger(fileName, FILE_MODIFY_DATE);
        if(now - lastMod > secondsToKeep)
        {
            FileDelete(fileName);
        }
    } while(FileFindNext(searchHandle, fileName));
    
    FileFindClose(searchHandle);
}

// [REMOVED] DrawTradeArrow deleted to avoid conflict with EA-specific logging modules.

#endif
