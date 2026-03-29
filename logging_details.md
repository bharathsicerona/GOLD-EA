# GoldEA Logging System - Outstanding Issues

This document tracks the remaining known issues in the logging infrastructure. Issues that have been fixed have been removed from this list.

## 1. Rejection Codes
**Status: Functional but Muted on Ticks (Unchanged by Design)**

*   **Structure:** Both EAs utilize a `NormalizeRejectReason()` function to map raw MT5 errors to standardized, analyzer-friendly strings (`LOW_ATR`, `HIGH_SPREAD`, `INSUFFICIENT_MARGIN`, `COOLDOWN_ACTIVE`, `SESSION_BLOCK`).
*   **M1 Tick-Level Loophole:** The `M1_BREAKOUT` strategy was decoupled to allow for tick-by-tick evaluation. To prevent massive log file bloat, it intentionally does not log its rejections. This behavior is a known design choice and remains unchanged.

## 2. Logic Errors in Logging
**Status: FIXED**

*   **The Issue:** The Python log analyzer uses a regex string to extract the strategy name from a CHECK line. The M1 Scalper EA was hardcoding a strategy name, causing a mismatch.
*   **The Fix:** The M1 Scalper EA now dynamically includes the strategy name in the log, and the log format is aligned with the Python parser's expectations. This resolves the "Regex Mismatch" issue.

