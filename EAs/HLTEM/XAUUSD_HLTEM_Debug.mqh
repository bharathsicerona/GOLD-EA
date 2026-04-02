#ifndef XAUUSD_HLTEM_DEBUG_MQH
#define XAUUSD_HLTEM_DEBUG_MQH

#include "XAUUSD_HLTEM_Logging.mqh"

//+------------------------------------------------------------------+
//| DrawHTF_OB - Visualizes HTF Order Block Zone                     |
//+------------------------------------------------------------------+
void DrawHTF_OB(double low, double high)
{
   string name = "HLTEM_OB";

   ObjectDelete(0, name);

   if(low <= 0 || high <= 0) return;

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, iTime(_Symbol, PERIOD_CURRENT, 50), high, iTime(_Symbol, PERIOD_CURRENT, 0), low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'30,30,80');
}

//+------------------------------------------------------------------+
//| DrawMSS - Visualizes LTF Market Structure Levels                 |
//+------------------------------------------------------------------+
void DrawMSS(double high, double low)
{
   if(ObjectFind(0, "HLTEM_MSS_HIGH") < 0)
   {
      ObjectCreate(0, "HLTEM_MSS_HIGH", OBJ_HLINE, 0, 0, high);
      ObjectSetInteger(0, "HLTEM_MSS_HIGH", OBJPROP_STYLE, STYLE_DOT);
   }
   ObjectSetDouble(0, "HLTEM_MSS_HIGH", OBJPROP_PRICE, high);
   ObjectSetInteger(0, "HLTEM_MSS_HIGH", OBJPROP_COLOR, clrLimeGreen);

   if(ObjectFind(0, "HLTEM_MSS_LOW") < 0)
   {
      ObjectCreate(0, "HLTEM_MSS_LOW", OBJ_HLINE, 0, 0, low);
      ObjectSetInteger(0, "HLTEM_MSS_LOW", OBJPROP_STYLE, STYLE_DOT);
   }
   ObjectSetDouble(0, "HLTEM_MSS_LOW", OBJPROP_PRICE, low);
   ObjectSetInteger(0, "HLTEM_MSS_LOW", OBJPROP_COLOR, clrCrimson);
}

//+------------------------------------------------------------------+
//| DrawFVG - Visualizes M1 Fair Value Gap Zone                      |
//+------------------------------------------------------------------+
void DrawFVG(double low, double high)
{
   string name = "HLTEM_FVG";

   ObjectDelete(0, name);
   
   if(low <= 0 || high <= 0) return;

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, iTime(_Symbol, PERIOD_CURRENT, 5), high, iTime(_Symbol, PERIOD_CURRENT, 0), low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'80,80,0');
}

//+------------------------------------------------------------------+
//| CleanupDebugObjects - Removes all HLTEM visual aids             |
//+------------------------------------------------------------------+
void CleanupDebugObjects()
{
   ObjectsDeleteAll(0, "HLTEM_");
}

#endif // XAUUSD_HLTEM_DEBUG_MQH
