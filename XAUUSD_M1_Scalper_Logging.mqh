#ifndef XAUUSD_M1_SCALPER_LOGGING_MQH
#define XAUUSD_M1_SCALPER_LOGGING_MQH

string g_dashboardPrefix = "M1_Dash_";
string g_m1LogPattern = "GoldEA_M1_Log_*.csv";

void DebugPrint(const string message)
  {
   if(InpEnableDebugPrints)
      Print("[GoldEA] ",message);
  }

string CurrentTimeText()
  {
   return TimeToString(TimeTradeServer(),TIME_DATE | TIME_SECONDS);
  }

void CleanupOldLogs()
  {
   if(InpLogRetentionDays <= 0) return;
   string fileName;
   long searchHandle = FileFindFirst(g_m1LogPattern, fileName);
   if(searchHandle != INVALID_HANDLE)
     {
      datetime threshold = TimeTradeServer() - (InpLogRetentionDays * 86400);
      do
        {
         if(StringLen(fileName) < 23) continue;
         string dateToken = StringSubstr(fileName,14,8);
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
  }

void LogToCSV(const string action,
              const string sessionStr,
              const string strategyStr,
              const double price,
              const double rsi,
              const double ema50,
              const double ema20,
              const double atr,
              const long spread,
              const int score,
              const string decision,
              const string reason)
  {
   if(!InpEnableCSVLogging) return;

   string dateStr = TimeToString(TimeTradeServer(), TIME_DATE);
   StringReplace(dateStr, ".", "");
   string currentLogName = StringFormat("GoldEA_M1_Log_%s.csv", dateStr);

   int handle = FileOpen(currentLogName,FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE,',');
   if(handle == INVALID_HANDLE) return;

   if(FileSize(handle) == 0)
      FileWrite(handle,"Time","Symbol","Action","Session","Strategy","Price","RSI","EMA50","EMA20","ATR","Spread","Score","Decision","Reason");

   FileSeek(handle,0,SEEK_END);
   FileWrite(handle,
             CurrentTimeText(),
             InpTradeSymbol,
             action,
             sessionStr,
             strategyStr,
             DoubleToString(price,g_symbolDigits),
             DoubleToString(rsi,2),
             DoubleToString(ema50,g_symbolDigits),
             DoubleToString(ema20,g_symbolDigits),
             DoubleToString(atr,g_symbolDigits),
             (string)spread,
             (string)score,
             decision,
             reason);
   FileFlush(handle);
   FileClose(handle);
  }

void SetDashboardLine(const string name,const string text,const color textColor,const int row)
  {
   string objectName = g_dashboardPrefix + name;
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

void UpdateDashboard(const DecisionContext &context)
  {
   if(!InpEnableDashboard) return;
   color statusColor   = (context.status == "ACTIVE") ? clrLimeGreen : clrTomato;
   color scoreColor    = (context.score >= InpMinimumScore) ? clrLimeGreen : clrTomato;
   color decisionColor = clrGold;
   if(context.decision == "BUY") decisionColor = clrLimeGreen;
   else if(context.decision == "SELL") decisionColor = clrTomato;

   SetDashboardLine("Title","Gold EA Dashboard",clrWhite,0);
   SetDashboardLine("Session",StringFormat("Session        : %s [%s]",context.sessionName,context.status),statusColor,1);
   SetDashboardLine("Strategy",StringFormat("Strategy       : %s (Risk: %.1f%%)",context.strategyName,context.riskPercent),clrPlum,2);
   SetDashboardLine("ATR",StringFormat("ATR            : %.2f",context.atr),clrKhaki,3);
   SetDashboardLine("Score",StringFormat("Current Score  : %d",context.score),scoreColor,4);
   SetDashboardLine("Decision",StringFormat("Trade Decision : %s (%s)",context.decision,context.phase),decisionColor,5);
   SetDashboardLine("Reason",StringFormat("Reason         : %s",context.reason),clrYellow,6);
  }

#endif // XAUUSD_M1_SCALPER_LOGGING_MQH
