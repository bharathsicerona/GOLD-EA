# XAUUSDm EA Optimization Checklist

Use this checklist when optimizing the EA for MT5 Strategy Tester.

## 1. Before You Start

- Confirm the EA compiles without errors in MetaEditor
- Confirm the symbol name matches your broker exactly
- Confirm chart timeframe matches your test plan
- Use the same account settings you expect in real trading
- Start on demo assumptions, not aggressive risk

## 2. Base Test Setup

- Symbol: `XAUUSDm`
- Timeframe: start with `M15`
- Model: `Every tick based on real ticks`
- Test period: at least `6 months`
- Initial deposit: close to your intended account size
- Risk per trade: keep at `1%` during optimization

## 3. Optimize in This Order

### Phase 1: Market Structure and Trend

- `InpFastEmaPeriod`
- `InpSlowEmaPeriod`
- `InpPullbackAtrFactor`
- `InpVolAtrThreshold`
- Session hours (Asian/London/New York)

Goal:
- Get cleaner trend-following entries
- Reduce entries against the main move

### Phase 2: Momentum Filters

- `InpRsiBuyMin`
- `InpRsiBuyMax`
- `InpRsiSellMin`
- `InpRsiSellMax`

Goal:
- Avoid weak or late momentum signals

### Phase 3: Volatility and Risk

- `InpStopAtrMultiplier`
- `InpTakeProfitMultiplier`
- `InpTrailAtrMultiplier`
- `InpMinAtrPoints`

Goal:
- Match gold volatility better
- Improve drawdown and trade survival

### Phase 4: Execution Filters

- `InpMaxSpreadPoints`
- Score threshold
- `InpWeightRangeBB`
- `InpWeightBreakout`
- `InpWeightTrend`

Goal:
- Remove low-quality trades caused by spread or poor timing

## 4. What Good Results Usually Look Like

Look for:

- Stable equity curve
- Reasonable drawdown
- Profit factor above `1.2`
- Enough trades to trust the sample size
- Similar results across different months

Do not optimize only for:

- Highest total profit
- Highest win rate
- One perfect historical period

## 5. Walk-Forward Habit

Use this simple method:

1. Optimize on Period A
2. Test the best settings on Period B
3. Compare if the strategy still behaves similarly
4. Reject settings that collapse outside the optimization window

Example:

- Optimize on January to June
- Validate on July to September

## 6. Gold-Specific Testing Notes

- Gold often needs wider ATR stops than forex majors
- News events can distort backtests and live results
- A lower trade count with cleaner setups is often better for XAUUSDm
- Broker spread and symbol specification matter a lot

## 7. Quick Adjustment Guide

If drawdown is too high:

- Raise `InpMinimumScore`
- Raise `InpMinAtrPoints`
- Increase `InpStopAtrMultiplier`
- Restrict trading hours more tightly

If there are too many trades:

- Tighten RSI ranges
- Adjust Volatility ATR threshold
- Increase score threshold

If there are too few trades:

- Lower score threshold
- Slightly relax ATR filter
- Lower Volatility ATR threshold

If trades exit too early:

- Raise `InpTakeProfitMultiplier`
- Relax trailing stop

If trades hold too long and give back profit:

- Tighten trailing stop
- Lower take-profit multiplier

## 8. Final Pre-Live Checklist

- Run at least one full backtest
- Run at least one forward demo test
- Check real spread behavior during London and New York
- Confirm lot sizing with your account balance
- Confirm stop-loss and take-profit placement on a live demo chart
- Save your final tested inputs as a broker-specific preset
