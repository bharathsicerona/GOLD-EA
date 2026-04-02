#ifndef XAUUSD_HLTEM_LOGGING_MQH
#define XAUUSD_HLTEM_LOGGING_MQH

#include "XAUUSD_HLTEM_Inputs.mqh"
#include "../Include/GoldEA_Common_Core.mqh"

// Define EA Type for logging
#define EA_TYPE "HLTEM"

void LogTyped(string type, string msg)
{
    // Following user requirement for [M5][GoldEA] prefix
    PrintFormat("[%s][GoldEA][%s] %s", "M5", type, msg);
}

#endif // XAUUSD_HLTEM_LOGGING_MQH
