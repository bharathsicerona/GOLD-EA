#ifndef XAUUSD_M1_SCALPER_INPUTS_MQH
#define XAUUSD_M1_SCALPER_INPUTS_MQH

input string           InpTradeSymbol            = "XAUUSDm";   // Default symbol, change if your broker uses a suffix (e.g., "XAUUSD.m")
input ENUM_TIMEFRAMES  InpTimeframe              = PERIOD_M1;
input ulong            InpMagicNumber            = 999111;

// --- Risk Management ---
input double           InpMaxRiskPercent         = 2.0;     // Maximum Risk per Trade (%)
input double           InpStopAtrMultiplier      = 2.5;     // Initial SL ATR Multiplier
input double           InpRewardRiskRatio        = 3.0;     // Target Reward-to-Risk Ratio (1:3)

// --- Indicators ---
input int              InpFastEmaPeriod          = 20;      // Fast EMA (Momentum)
input int              InpSlowEmaPeriod          = 50;      // Slow EMA (Trend)
input int              InpRsiPeriod              = 14;      // RSI Period
input int              InpAtrPeriod              = 14;      // ATR Period

// --- Entry Filters ---
input double           InpRsiBuyMin              = 50.0;
input double           InpRsiBuyMax              = 70.0;
input double           InpRsiSellMin             = 30.0;
input double           InpRsiSellMax             = 50.0;
input double           InpMinAtrPoints           = 250.0;   // Min ATR points to trade (Noise Filter)
input double           InpMinEmaGapPoints        = 20.0;    // Min gap between EMA20 and EMA50
input double           InpPullbackAtrFactor      = 0.50;    // Max distance from EMA20 for pullback

// --- Trade & Profit Management ---
input int              InpMaxSpreadPoints        = 800;     // Max Spread Cap (Points)
input double           InpMaxSpreadAtrFactor     = 0.5;     // Max Spread vs ATR Factor
input int              InpCooldownSeconds        = 60;      // Cooldown after trade (Seconds)
input int              InpLossCooldownSeconds    = 60;      // Extra cooldown after a loss
input int              InpMaxConsecutiveLosses   = 3;       // Stop trading after N consecutive losses
input int              InpMaxTradesPerMinute     = 1;       // Limit trade frequency
input double           InpProfitLockTriggerPct   = 5.0;     // Profit % to trigger lock
input double           InpProfitLockTargetPct    = 1.0;     // Profit % to lock
input double           InpTrailAtrMultiplier     = 2.0;     // Trailing Stop ATR Multiplier
input double           InpTrailStepAtr           = 0.5;     // Min Step for Trailing (ATR factor)

// --- Session & Logging Settings (Visuals Only) ---
input int              InpAsianStartHour         = 0;
input int              InpAsianEndHour           = 8;
input int              InpLondonStartHour        = 8;
input int              InpLondonEndHour          = 13;
input int              InpNewYorkStartHour       = 13;
input int              InpNewYorkEndHour         = 22;
input bool             InpEnableAsianSession     = false;

input int              InpMinimumScore           = 100;     // Minimum Score (Visual)
input bool             InpEnableDebugPrints      = true;
input bool             InpEnableCSVLogging       = true;
input bool             InpEnableDashboard        = true;
input bool             InpLogEveryTick           = false;
input int              InpLogRetentionDays       = 7;
input bool             InpEnablePushAlerts       = false;
input bool             InpEnableEmailAlerts      = false;

#endif // XAUUSD_M1_SCALPER_INPUTS_MQH
