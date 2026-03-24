#ifndef XAUUSD_ADAPTIVE_INPUTS_MQH
#define XAUUSD_ADAPTIVE_INPUTS_MQH

enum ENUM_SESSION
  {
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NEWYORK,
   SESSION_NONE
  };

enum ENUM_STRATEGY
  {
   STRATEGY_RANGE,
   STRATEGY_BREAKOUT,
   STRATEGY_TREND,
   STRATEGY_NONE
  };

enum ENUM_SCORE_MODE
  {
   SCORE_DISABLED = 0,
   SCORE_ENABLED  = 1
  };

input string           InpTradeSymbol            = "XAUUSDm";
input ENUM_TIMEFRAMES  InpTimeframe              = PERIOD_M5;
input ulong            InpMagicNumber            = 26032026;

input int              InpFastEmaPeriod          = 21;
input int              InpSlowEmaPeriod          = 100;
input int              InpRsiPeriod              = 14;
input int              InpAtrPeriod              = 14;

input double           InpVolAtrThreshold        = 150.0;
input int              InpBandsPeriod            = 20;
input double           InpBandsDeviation         = 2.0;

input double           InpRsiBuyMin              = 52.0;
input double           InpRsiBuyMax              = 68.0;
input double           InpRsiSellMin             = 32.0;
input double           InpRsiSellMax             = 48.0;

input double           InpRiskPercent            = 1.0;
input double           InpMaxAbsoluteRiskPercent = 10.0;
input bool             InpAllowCounterTrend      = true;
input double           InpCounterTrendRisk       = 0.50;
input int              InpCounterTrendMinScore   = 85;
input double           InpCounterTrendTpMultiplier = 1.2;
input int              InpMaxOpenPositionsTotal  = 1;
input int              InpMaxConcurrentTrades    = 2;
input int              InpTradeCooldownSeconds   = 300;
input double           InpStopAtrMultiplier      = 1.8;
input double           InpTakeProfitMultiplier   = 3.0;
input double           InpBreakevenAtrMultiplier = 1.2;
input double           InpMinProfitLockAtr       = 0.30;
input double           InpAccountProfitLockTriggerPercent = 5.0;
input double           InpAccountProfitLockTargetPercent = 1.0;
input double           InpTrailActivationAtrMultiplier = 2.0;
input double           InpTrailAtrMultiplier     = 2.5;
input double           InpTrailStepAtrMultiplier = 0.50;
input double           InpProfitLockActivationAtr = 2.5;
input double           InpProfitLockAtr          = 1.0;
input double           InpMinAtrPoints           = 120.0;
input double           InpPullbackAtrFactor      = 0.50;

input int              InpAdxPeriod              = 14;
input double           InpAdxThreshold           = 20.0;
input double           InpEmaGapAtrFactor        = 0.5;

input bool             InpAllowBuyTrades         = true;
input bool             InpAllowSellTrades        = true;

input int              InpMaxSpreadPoints        = 500;
input int              InpAsianStartHour         = 0;
input int              InpAsianEndHour           = 8;
input int              InpLondonStartHour        = 8;
input int              InpLondonEndHour          = 13;
input int              InpNewYorkStartHour       = 13;
input int              InpNewYorkEndHour         = 22;

input ENUM_SCORE_MODE  InpUseScoring             = SCORE_ENABLED;
input int              InpMinimumScore           = 75;
input int              InpWeightTrend            = 30;
input int              InpWeightEmaAlignment     = 25;
input int              InpWeightRsi              = 20;
input int              InpWeightRangeBB          = 50;
input int              InpWeightBreakout         = 50;
input int              InpWeightPullback         = 25;

input bool             InpEnableDebugPrints      = true;
input bool             InpEnableCSVLogging       = true;
input bool             InpEnableDashboard        = true;
input bool             InpLogEveryTick           = false;
input int              InpLogRetentionDays       = 7;
input bool             InpEnablePushAlerts       = false;
input bool             InpEnableEmailAlerts      = false;

#endif // XAUUSD_ADAPTIVE_INPUTS_MQH
