#ifndef XAUUSD_M1_SCALPER_INPUTS_MQH
#define XAUUSD_M1_SCALPER_INPUTS_MQH

input string           InpTradeSymbol            = "XAUUSDm";   // Symbol to trade (e.g., XAUUSD.m)
input ENUM_TIMEFRAMES  InpTimeframe              = PERIOD_M1;
input ulong            InpMagicNumber            = 999111;

#property group "--- High-Risk Mode ---"
input bool             InpEnableHighRiskMode     = true;    // MASTER SWITCH for all aggressive features
input double           InpHighRiskPercent        = 3.0;     // Risk per trade in High-Risk mode (%)
enum E_MinLotAction
  {
   MIN_LOT_SKIP, // Skip trade if calculated lot is too small
   MIN_LOT_FORCE // Force trade by using broker's minimum lot size
  };
input E_MinLotAction   InpMinLotAction           = MIN_LOT_FORCE; // Action for lots below broker minimum

// --- Session Management ---
#property group "--- Session Management ---"
enum E_SessionMode
  {
   SESSION_MODE_SAFE,    // London + New York sessions only
   SESSION_MODE_AGGRO    // All sessions (Asian, London, New York)
  };
input E_SessionMode    InpSessionMode            = SESSION_MODE_AGGRO; // Trading session mode

// --- Core Risk & Position Sizing ---
#property group "--- Core Risk & Position Sizing ---"
input double           InpStopAtrMultiplier      = 2.5;     // Initial SL ATR Multiplier
input double           InpRewardRiskRatio        = 3.0;     // Initial Target Reward-to-Risk Ratio

// --- Indicator Settings ---
#property group "--- Indicator Settings ---"
input int              InpFastEmaPeriod          = 20;      // Fast EMA (Momentum)
input int              InpSlowEmaPeriod          = 50;      // Slow EMA (Trend)
input int              InpRsiPeriod              = 14;      // RSI Period
input int              InpAtrPeriod              = 14;      // ATR Period

// --- Entry Filters ---
#property group "--- Entry Filters ---"
input double           InpRsiBuyMin              = 50.0;
input double           InpRsiBuyMax              = 70.0;
input double           InpRsiSellMin             = 30.0;
input double           InpRsiSellMax             = 50.0;
input double           InpMinAtrPoints           = 250.0;   // Min ATR points to trade (Noise Filter)
input double           InpMinEmaGapPoints        = 20.0;    // Min gap between EMA20 and EMA50
input double           InpPullbackAtrFactor      = 0.50;    // Max distance from EMA20 for pullback
input double           InpSpikeCandleAtrFactor   = 3.0;     // ATR factor to detect and avoid spike candles

// --- Trade Execution & Management ---
#property group "--- Trade Execution & Management ---"
input int              InpMaxSpreadPoints        = 300;     // Max Spread Cap (Points) - Tightened
input int              InpCooldownAfterLoss      = 90;      // Cooldown after a losing trade (Seconds)
input int              InpMaxConsecutiveLosses   = 0;       // Stop after N losses (0=disabled)

// --- Visual & Logging ---
#property group "--- Visual & Logging ---"
input int              InpAsianStartHour         = 0;
input int              InpAsianEndHour           = 8;
input int              InpLondonStartHour        = 8;
input int              InpLondonEndHour          = 13;
input int              InpNewYorkStartHour       = 13;
input int              InpNewYorkEndHour         = 22;

input bool             InpEnableDebugPrints      = true;
input bool             InpEnableCSVLogging       = true;

#property group "" // Reset group


#endif // XAUUSD_M1_SCALPER_INPUTS_MQH
