#ifndef XAUUSD_M1_QUICKHANDS_INPUTS_MQH
#define XAUUSD_M1_QUICKHANDS_INPUTS_MQH

//+------------------------------------------------------------------+
//| --- Input Parameters ---                                         |
//+------------------------------------------------------------------+
input string InpSectionMain = "--- Main Settings ---";
input int    InpMagicNumber = 12042026; // EA Magic Number
input bool   InpEnableAudioAlert = false;
input bool   InpEnablePushNotification = false;

input string InpSectionStrategy = "--- Strategy Settings ---";
input int    InpEmaFastPeriod = 20;    // EMA Fast Period
input int    InpEmaSlowPeriod = 50;    // EMA Slow Period
// --- ELITE UPGRADE START ---
input int    InpEmaBiasPeriod = 100;   // EMA bias period
input int    InpRsiPeriod     = 14;    // RSI period
// --- ELITE UPGRADE END ---
input int    InpAtrPeriod     = 14;    // ATR Period for filter

input string InpSectionRisk = "--- Risk Settings ---";
input double InpLotSize = 0.01;        // Fixed Lot Size
input double InpRiskUSD = 3.0;         // Fixed SL Risk (USD)
input double InpRewardUSD = 15.0;      // Fixed TP Reward (USD)
input double InpQuickHandsSLUSD = 5.0; // Fixed initial stop loss in USD for LSMC

input string InpSectionFilters = "--- Filter Settings ---";
input double InpMinAtrPoints = 50.0;   // Minimum ATR in points (5.0 pips)
input int    InpMaxSpreadPoints = 500; // Maximum spread in points (50.0 pips)
// --- ELITE UPGRADE START ---
input bool   InpUseExplosiveMode = false;
input double InpPullbackAtrLimit = 0.30;
input double InpNormalTrendThreshold = 0.10;
input double InpAggressiveTrendThreshold = 0.20;
input double InpSpreadRatioLimit = 0.25;
input double InpSpreadTrendFloor = 0.15;
// --- ELITE UPGRADE END ---
input bool   InpUseMicroTrendFilter = false;

input string InpSectionVisual = "--- Visual Settings ---";
input bool   InpEnableDashboard = true;
input string InpDashboardPrefix = "MH_QuickHands_";

#endif // XAUUSD_M1_QUICKHANDS_INPUTS_MQH
