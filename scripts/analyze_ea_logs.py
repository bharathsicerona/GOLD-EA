#!/usr/bin/env python3
"""
Analyze MetaTrader 5 Expert Advisor logs and produce a trading summary.

Supported inputs:
- .log files from MT5 Strategy Tester / Experts logs
- .txt files with copied log output

CHANGELOG:
Version 2.0 (Advanced Log Analytics)
* Added profit, risk, and R-multiple tracking with inference from SL/TP and results.
* Implemented BUY vs SELL performance analysis (counts and win rates).
* Added session-wise performance metrics (win rates per session).
* Introduced automatic output folder (log analysis) for standard exports.
* Added trade frequency analysis and trade clustering detection.
* Improved console summary reporting.

The parser is tolerant of partial fields and focuses on GoldEA-style lines such as:
    [GoldEA] [TREND] BUY check: price=..., atr=..., score=..., reason=...
    [GoldEA] BUY executed: tradeId=1 lot=0.01 entry=...
    [GoldEA] Trade skipped
    [GoldEA] STOP LOSS HIT
    [GoldEA] TAKE PROFIT HIT
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable


TIMESTAMP_RE = re.compile(r"(?P<ts>\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})")
EA_PREFIX_RE = re.compile(
    r"\[(?P<ea_type>M1|M1_SCALPER|M5)\]\[GoldEA\](?:\[(?P<log_type>[A-Z_]+)\])?\s*"
)
GENERIC_DEAL_RE = re.compile(
    r"""
    \bdeal\s+\#(?P<trade_id>\d+)\s+
    (?P<side>buy|sell)\s+
    (?P<lot>[\d.]+)\s+
    (?P<symbol>[A-Z]{3,10}[a-z]?)\s+
    at\s+(?P<price>[\d.]+)\s+done
    """,
    re.IGNORECASE | re.VERBOSE,
)
GENERIC_CLOSE_RE = re.compile(
    r"""
    \bmarket\s+(?P<side>buy|sell)\s+[\d.]+\s+
    (?P<symbol>[A-Z]{3,10}[a-z]?),\s+close\s+\#(?P<trade_id>\d+)
    """,
    re.IGNORECASE | re.VERBOSE,
)
CHECK_RE = re.compile(
    r"""
    \[(?P<strategy>[^\]]+)\]\s+
    (?P<side>BUY|SELL)\s+check:
    (?P<body>.*)
    """,
    re.IGNORECASE | re.VERBOSE,
)
EXEC_RE = re.compile(
    r"""
    (?P<side>BUY|SELL)\s+executed:
    (?P<body>.*)
    """,
    re.IGNORECASE | re.VERBOSE,
)
RESULT_RE = re.compile(
    r"""
    (?:
        (?P<stop>STOP(?:\s+|_)LOSS(?:\s+|_)HIT)|
        (?P<tp>TAKE(?:\s+|_)PROFIT(?:\s+|_)HIT)|
        (?P<be>BREAKEVEN(?:\s+HIT)?)|
        (?P<partial>PARTIAL\s+CLOSE(?:D)?)|
        (?P<skip>Trade\s+skipped)|
        (?P<trail>Trailing\s+stop\s+updated)|
        (?P<other>.*)
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)
KV_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)=([^,\s]+)")
TRADE_ID_RE = re.compile(r"tradeId=(\d+)", re.IGNORECASE)
TICKET_RE = re.compile(r"ticket=(\d+)", re.IGNORECASE)
BUY_SELL_RE = re.compile(r"\b(BUY|SELL)\b", re.IGNORECASE)
LEGACY_VALID_RE = re.compile(r"\b(?:VALID\s+)?(?P<side>BUY|SELL)\s+SIGNAL\b", re.IGNORECASE)
LEGACY_REJECT_RE = re.compile(r"\b(?P<side>BUY|SELL)\s+REJECTED\b", re.IGNORECASE)
SCORE_INLINE_RE = re.compile(r"(?:score\s*=\s*|score\s*:\s*)([-\d.]+)", re.IGNORECASE)
ATR_INLINE_RE = re.compile(r"(?:atr\s*=\s*|atr\s*:\s*)([-\d.]+)", re.IGNORECASE)
VALID_REASONS = {"VALID", "READY", "ENTRY_READY", "SETUP_VALID", "SETUP_VALID_OVERRIDE", "EXECUTED"}
LOG_TYPES = {"CHECK", "EXECUTION", "REJECTION", "RESULT", "STATS"}


@dataclass
class Event:
    ea_type: str
    timestamp: str
    session: str
    symbol: str
    source_file: str
    action: str
    trade_type: str
    strategy: str
    score: float | None
    atr: float | None
    price: float | None
    sl: float | None
    tp: float | None
    reason: str
    result: str
    trade_id: str
    profit: float | None
    risk: float | None
    r_multiple: float | None
    raw: str


@dataclass
class TradeLifecycle:
    ea_type: str
    trade_id: str
    trade_type: str
    entry_price: float | None
    entry_time: str
    lot: float | None
    initial_sl: float | None
    exit_price: float | None
    exit_time: str
    profit: float | None
    result: str
    risk: float | None
    r_multiple: float | None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze GoldEA MetaTrader 5 logs and generate a summary report."
    )
    parser.add_argument(
        "paths",
        nargs="+",
        help="One or more .log/.txt files or directories containing logs.",
    )
    parser.add_argument(
        "--export-summary-csv",
        dest="summary_csv",
        help="Optional CSV file path for summary metrics.",
    )
    parser.add_argument(
        "--export-events-csv",
        dest="events_csv",
        help="Optional CSV file path for parsed structured events.",
    )
    parser.add_argument(
        "--export-json",
        dest="json_path",
        help="Optional JSON file path for full structured output.",
    )
    return parser.parse_args()


def discover_files(paths: Iterable[str]) -> list[Path]:
    results: list[Path] = []
    seen: set[Path] = set()
    for raw_path in paths:
        path = Path(raw_path)
        if not path.exists():
            print(f"Warning: path not found: {path}", file=sys.stderr)
            continue
        if path.is_file() and path.suffix.lower() in {".log", ".txt"}:
            resolved = path.resolve()
            if resolved not in seen:
                seen.add(resolved)
                results.append(resolved)
            continue
        if path.is_dir():
            for file_path in sorted(path.rglob("*")):
                if file_path.is_file() and file_path.suffix.lower() in {".log", ".txt"}:
                    resolved = file_path.resolve()
                    if resolved not in seen:
                        seen.add(resolved)
                        results.append(resolved)
    return sorted(results)


def extract_timestamp(line: str) -> str:
    match = TIMESTAMP_RE.search(line)
    return match.group("ts") if match else ""


def extract_symbol(line: str) -> str:
    for token in re.findall(r"\b[A-Z]{3,10}[a-z]?\b", line):
        if token.startswith("XAUUSD"):
            return token
    return ""


def parse_kv_pairs(text: str) -> dict[str, str]:
    return {key.lower(): value.strip() for key, value in KV_RE.findall(text)}


def parse_float(value: str | None) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def infer_session(timestamp_text: str) -> str:
    if not timestamp_text:
        return "Unknown"
    try:
        dt = datetime.strptime(timestamp_text, "%Y.%m.%d %H:%M:%S")
    except ValueError:
        return "Unknown"
    hour = dt.hour
    if 0 <= hour < 8:
        return "Asian"
    if 8 <= hour < 13:
        return "London"
    if 13 <= hour < 22:
        return "New York"
    return "Off Session"


def clean_reason(reason: str | None) -> str:
    if not reason:
        return ""
    return reason.strip().strip(",").upper()


def normalize_ea_type(raw_ea_type: str) -> str:
    if raw_ea_type.upper() == "M1":
        return "M1_SCALPER"
    return raw_ea_type.upper()


def strip_log_type_tag(text: str) -> str:
    stripped = text.strip()
    match = re.match(r"^\[(?P<t>[A-Z_]+)\]\s*", stripped, re.IGNORECASE)
    if not match:
        return stripped
    log_type = match.group("t").upper()
    if log_type in LOG_TYPES:
        return stripped[match.end():].strip()
    return stripped


def extract_reason_from_text(text: str, default: str = "UNKNOWN") -> str:
    lowered = text.lower()
    if "core_condition_fail" in lowered or "core condition fail" in lowered:
        return "CORE_CONDITION_FAIL"
    if "ema_flat" in lowered or "ema flat" in lowered:
        return "EMA_FLAT"
    if "cooldown_3candle" in lowered or "3candle" in lowered or "3-candle" in lowered:
        return "COOLDOWN_3CANDLE"
    if "cooldown_2candle" in lowered or "2candle" in lowered or "2-candle" in lowered:
        return "COOLDOWN_2CANDLE"
    if "risk_engine_block" in lowered or "risk engine block" in lowered:
        return "RISK_ENGINE_BLOCK"
    if "invalid_tickvalue" in lowered or "invalid tick value" in lowered:
        return "INVALID_TICKVALUE"
    if "order_failed" in lowered or "order failed" in lowered:
        return "ORDER_FAILED"
    if "reason=" in lowered:
        kv = parse_kv_pairs(text)
        if kv.get("reason"):
            parsed = clean_reason(kv["reason"])
            if parsed in {"OTHER", "UNKNOWN", ""}:
                return "UNCLASSIFIED_REJECTION"
            return parsed
    if "margin" in lowered:
        return "INSUFFICIENT_MARGIN"
    if "score <" in lowered or "low_score" in lowered or "score" in lowered and "reject" in lowered:
        return "LOW_SCORE"
    if "spread" in lowered:
        return "HIGH_SPREAD"
    if "cooldown" in lowered:
        return "COOLDOWN_ACTIVE"
    if "session" in lowered or "asian" in lowered:
        return "SESSION_BLOCK"
    if "max" in lowered and "trade" in lowered:
        return "MAX_TRADES_REACHED"
    if "valid" in lowered or "signal" in lowered and "reject" not in lowered:
        return "VALID"
    cleaned_default = clean_reason(default or "UNKNOWN")
    if cleaned_default in {"OTHER", "UNKNOWN", ""}:
        return "UNCLASSIFIED_REJECTION"
    return cleaned_default


def parse_ts(timestamp_text: str) -> datetime | None:
    if not timestamp_text:
        return None
    try:
        return datetime.strptime(timestamp_text, "%Y.%m.%d %H:%M:%S")
    except ValueError:
        return None


def build_event(
    *,
    ea_type: str,
    timestamp: str,
    symbol: str,
    source_file: Path,
    action: str,
    trade_type: str = "",
    strategy: str = "",
    score: float | None = None,
    atr: float | None = None,
    price: float | None = None,
    sl: float | None = None,
    tp: float | None = None,
    reason: str = "",
    result: str = "",
    trade_id: str = "",
    profit: float | None = None,
    risk: float | None = None,
    r_multiple: float | None = None,
    raw: str = "",
) -> Event:
    return Event(
        ea_type=ea_type,
        timestamp=timestamp,
        session=infer_session(timestamp),
        symbol=symbol,
        source_file=source_file.name,
        action=action,
        trade_type=trade_type.upper(),
        strategy=strategy,
        score=score,
        atr=atr,
        price=price,
        sl=sl,
        tp=tp,
        reason=clean_reason(reason),
        result=result,
        trade_id=trade_id,
        profit=profit,
        risk=risk,
        r_multiple=r_multiple,
        raw=raw.strip(),
    )


def parse_log_file(path: Path) -> list[Event]:
    """Parses a log file and returns a list of trading events."""
    events: list[Event] = []
    text = read_text_auto(path)
    for line in text.splitlines():
        prefix_match = EA_PREFIX_RE.search(line)
        if prefix_match:
            ea_type = normalize_ea_type(prefix_match.group("ea_type"))
            timestamp = extract_timestamp(line)
            content = strip_log_type_tag(line[prefix_match.end():])
            
            event = (
                parse_check_line(content, path, ea_type, timestamp)
                or parse_execution_line(content, path, ea_type, timestamp)
                or parse_result_line(content, path, ea_type, timestamp)
            )
            if event:
                event.raw = line.strip()
                events.append(event)
                continue

        # Fallback for raw MT5 tester logs (non-GoldEA format)
        generic_event = parse_generic_mt5_line(line, path)
        if generic_event:
            generic_event.raw = line.strip()
            events.append(generic_event)
    return events


def infer_ea_type_fallback(line: str, source_file: Path) -> str:
    upper_line = line.upper()
    name = source_file.name.upper()
    if ",M5" in upper_line or "TIMEFRAME=5" in upper_line or "ADAPTIVE" in upper_line or "M5" in name:
        return "M5"
    return "M1_SCALPER"


def parse_generic_mt5_line(line: str, source_file: Path) -> Event | None:
    timestamp = extract_timestamp(line)
    if not timestamp:
        return None

    deal_match = GENERIC_DEAL_RE.search(line)
    if deal_match:
        ea_type = infer_ea_type_fallback(line, source_file)
        return build_event(
            ea_type=ea_type,
            timestamp=timestamp,
            symbol=deal_match.group("symbol"),
            source_file=source_file,
            action="TRADE_EXECUTED",
            trade_type=deal_match.group("side"),
            strategy="GENERIC_MT5",
            price=parse_float(deal_match.group("price")),
            reason="GENERIC_MT5_DEAL",
            result="EXECUTED",
            trade_id=deal_match.group("trade_id"),
        )

    close_match = GENERIC_CLOSE_RE.search(line)
    if close_match:
        ea_type = infer_ea_type_fallback(line, source_file)
        return build_event(
            ea_type=ea_type,
            timestamp=timestamp,
            symbol=close_match.group("symbol"),
            source_file=source_file,
            action="TRADE_CLOSED",
            trade_type=close_match.group("side"),
            strategy="GENERIC_MT5",
            reason="GENERIC_MT5_CLOSE",
            result="CLOSED",
            trade_id=close_match.group("trade_id"),
        )

    return None


def parse_check_line(line: str, source_file: Path, ea_type: str, timestamp: str) -> Event | None:
    """Parses a 'check' log line (a potential trade signal)."""
    match = CHECK_RE.search(line)
    if not match:
        legacy_valid = LEGACY_VALID_RE.search(line)
        legacy_reject = LEGACY_REJECT_RE.search(line)
        if not legacy_valid and not legacy_reject:
            return None

        side = (legacy_valid or legacy_reject).group("side")
        kv = parse_kv_pairs(line)
        score_match = SCORE_INLINE_RE.search(line)
        atr_match = ATR_INLINE_RE.search(line)
        reason_default = "VALID" if legacy_valid else "UNKNOWN"
        reason = extract_reason_from_text(line, default=reason_default)
        result = "PENDING" if clean_reason(reason) in VALID_REASONS else "SKIPPED"
        return build_event(
            ea_type=ea_type,
            timestamp=timestamp,
            symbol=extract_symbol(line) or extract_symbol(source_file.name),
            source_file=source_file,
            action="SIGNAL_CHECK",
            trade_type=side,
            strategy=kv.get("strategy", "LEGACY"),
            score=parse_float(kv.get("score")) if kv.get("score") else parse_float(score_match.group(1) if score_match else None),
            atr=parse_float(kv.get("atr")) if kv.get("atr") else parse_float(atr_match.group(1) if atr_match else None),
            price=parse_float(kv.get("price")),
            sl=parse_float(kv.get("sl")),
            tp=parse_float(kv.get("tp")),
            reason=reason,
            result=result,
        )

    body = match.group("body")
    kv = parse_kv_pairs(body)
    symbol = extract_symbol(line) or extract_symbol(source_file.name)
    reason = extract_reason_from_text(body, default=kv.get("reason", "UNKNOWN"))
    score = parse_float(kv.get("score"))
    atr = parse_float(kv.get("atr"))
    price = parse_float(kv.get("price"))
    sl = parse_float(kv.get("sl"))
    tp = parse_float(kv.get("tp"))

    executed_hint = clean_reason(reason) in VALID_REASONS
    result = "PENDING" if executed_hint else "SKIPPED"

    return build_event(
        ea_type=ea_type,
        timestamp=timestamp,
        symbol=symbol,
        source_file=source_file,
        action="SIGNAL_CHECK",
        trade_type=match.group("side"),
        strategy=match.group("strategy").strip(),
        score=score,
        atr=atr,
        price=price,
        sl=sl,
        tp=tp,
        reason=reason,
        result=result,
    )


def parse_execution_line(line: str, source_file: Path, ea_type: str, timestamp: str) -> Event | None:
    """Parses a trade execution log line."""
    match = EXEC_RE.search(line)
    if not match:
        return None

    body = match.group("body")
    kv = parse_kv_pairs(body)
    symbol = extract_symbol(line) or extract_symbol(source_file.name)
    trade_id_match = TRADE_ID_RE.search(body)

    return build_event(
        ea_type=ea_type,
        timestamp=timestamp,
        symbol=symbol,
        source_file=source_file,
        action="TRADE_EXECUTED",
        trade_type=match.group("side"),
        strategy=kv.get("strategy", ""),
        score=parse_float(kv.get("score")),
        atr=parse_float(kv.get("atr")),
        price=parse_float(kv.get("entry") or kv.get("price")),
        sl=parse_float(kv.get("sl")),
        tp=parse_float(kv.get("tp")),
        reason=extract_reason_from_text(body, default=kv.get("reason", "EXECUTED")),
        result="EXECUTED",
        trade_id=trade_id_match.group(1) if trade_id_match else "",
    )


def parse_result_line(line: str, source_file: Path, ea_type: str, timestamp: str) -> Event | None:
    """Parses a trade result log line (e.g., SL/TP hit, closed)."""
    match = RESULT_RE.search(line)
    if not match:
        return None

    symbol = extract_symbol(line) or extract_symbol(source_file.name)
    trade_match = TRADE_ID_RE.search(line)
    ticket_match = TICKET_RE.search(line)
    side_match = BUY_SELL_RE.search(line)
    
    profit_match = re.search(r"profit=([-\d.]+)", line, re.IGNORECASE)
    profit = parse_float(profit_match.group(1)) if profit_match else None
    trade_id = (trade_match.group(1) if trade_match else ticket_match.group(1) if ticket_match else "")

    action, result = "UNKNOWN", "UNKNOWN"
    reason = extract_reason_from_text(line, default="")
    if match.group("stop"):
        action = "STOP_LOSS_HIT"
        if profit is not None and profit > 0:
            result = "WIN"
        else:
            result = "LOSS"
    elif match.group("tp"):
        action = "TAKE_PROFIT_HIT"
        if profit is not None and profit < 0:
            result = "LOSS"
        else:
            result = "WIN"
    elif match.group("be"):
        action, result = "BREAKEVEN", "BREAKEVEN"
    elif match.group("partial"):
        action, result = "PARTIAL_CLOSE", "PARTIAL"
    elif match.group("skip"):
        action, result = "TRADE_SKIPPED", "SKIPPED"
    elif match.group("trail"):
        action, result = "TRAILING_UPDATE", "MANAGEMENT"
    
    # Do not parse execution lines here, they are handled by parse_execution_line
    if "EXECUTED" in line.upper():
        return None
    if action == "UNKNOWN":
        return None

    return build_event(
        ea_type=ea_type,
        timestamp=timestamp,
        symbol=symbol,
        source_file=source_file,
        action=action,
        trade_type=side_match.group(1) if side_match else "",
        reason=reason or action,
        result=result,
        trade_id=trade_id,
        profit=profit,
    )


def read_text_auto(path: Path) -> str:
    raw = path.read_bytes()
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    for encoding in ("utf-8", "utf-8-sig", "cp1252", "latin-1"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def attach_execution_scores(events: list[Event]) -> None:
    """
    Links metadata (score, atr, reason, strategy) from SIGNAL_CHECK events 
    to the corresponding TRADE_EXECUTED events.
    
    Args:
        events: The list of parsed log events.
    """
    latest_signal_by_side: dict[str, Event] = {}
    for event in events:
        if event.action == "SIGNAL_CHECK":
            latest_signal_by_side[event.trade_type] = event
            continue
        if event.action != "TRADE_EXECUTED":
            continue
        signal = latest_signal_by_side.get(event.trade_type)
        if not signal:
            continue
        if event.score is None:
            event.score = signal.score
        if event.atr is None:
            event.atr = signal.atr
        if event.reason in {"", "EXECUTED"}:
            event.reason = signal.reason or event.reason
        if not event.strategy:
            event.strategy = signal.strategy


def attach_skipped_context(events: list[Event]) -> None:
    """
    Adds context to generic TRADE_SKIPPED events using nearby signal/rejection lines.
    """
    last_signal_by_side: dict[str, Event] = {}
    last_rejection_by_side: dict[str, Event] = {}

    for event in events:
        if event.action == "SIGNAL_CHECK" and event.trade_type:
            last_signal_by_side[event.trade_type] = event
            if event.result == "SKIPPED":
                last_rejection_by_side[event.trade_type] = event
            continue

        if event.action != "TRADE_SKIPPED":
            continue

        side = event.trade_type
        if not side:
            side_candidates = [("BUY", last_rejection_by_side.get("BUY")), ("SELL", last_rejection_by_side.get("SELL"))]
            best_side = ""
            best_delta = None
            current_ts = parse_ts(event.timestamp)
            for candidate_side, candidate_event in side_candidates:
                if not candidate_event:
                    continue
                cand_ts = parse_ts(candidate_event.timestamp)
                if not current_ts or not cand_ts:
                    side = candidate_side
                    break
                delta = abs((current_ts - cand_ts).total_seconds())
                if best_delta is None or delta < best_delta:
                    best_delta = delta
                    best_side = candidate_side
            if not side:
                side = best_side
            event.trade_type = side

        context = last_rejection_by_side.get(side) or last_signal_by_side.get(side)
        if context:
            if (not event.reason or event.reason in {"", "TRADE_SKIPPED", "UNKNOWN"}) and context.reason:
                event.reason = context.reason
            if event.score is None:
                event.score = context.score
            if event.atr is None:
                event.atr = context.atr
            if not event.strategy:
                event.strategy = context.strategy


def calculate_trade_frequency(executed_events: list[Event]) -> tuple[float | None, int]:
    """
    Analyzes trade frequency and detects rapid consecutive trading (clustering).
    
    Args:
        executed_events: A list of TRADE_EXECUTED events.
        
    Returns:
        A tuple of (average_time_between_trades_in_minutes, number_of_clusters_detected)
    """
    if len(executed_events) < 2:
        return None, 0
        
    times = []
    for e in executed_events:
        try:
            times.append(datetime.strptime(e.timestamp, "%Y.%m.%d %H:%M:%S"))
        except ValueError:
            continue
            
    times.sort()
    diffs = [(times[i] - times[i-1]).total_seconds() for i in range(1, len(times))]
    
    if not diffs:
        return None, 0
        
    avg_minutes = (sum(diffs) / len(diffs)) / 60.0
    # A cluster is defined as a trade occurring less than 5 minutes after the previous one
    clusters = sum(1 for d in diffs if d < 300)
    
    return avg_minutes, clusters


def link_trade_outcomes(events: list[Event]) -> None:
    """
    Links result events (Wins/Losses) back to execution events using trade_id.
    Calculates Risk and inferred R-Multiple based on Stop Loss and Profit values.
    """
    executions_by_id: dict[str, Event] = {}
    executions: list[Event] = []
    consumed_exec_keys: set[tuple[str, str]] = set()

    def _execution_risk(exec_event: Event) -> None:
        if exec_event.price is not None and exec_event.sl is not None and exec_event.price != exec_event.sl:
            exec_event.risk = abs(exec_event.price - exec_event.sl)

    def _assign_r_metrics(result_event: Event, exec_event: Event) -> None:
        result_event.risk = exec_event.risk
        if result_event.profit is not None and result_event.risk and result_event.risk > 0:
            result_event.r_multiple = result_event.profit / result_event.risk
        elif result_event.risk and result_event.risk > 0:
            if result_event.result == "LOSS":
                result_event.r_multiple = -1.0
            elif result_event.result == "WIN" and exec_event.tp and exec_event.price:
                reward = abs(exec_event.tp - exec_event.price)
                result_event.r_multiple = reward / result_event.risk
            elif result_event.result == "BREAKEVEN":
                result_event.r_multiple = 0.0
            elif result_event.result == "WIN":
                result_event.r_multiple = 1.0

    for event in events:
        if event.action == "TRADE_EXECUTED":
            if event.trade_id:
                executions_by_id[event.trade_id] = event
            _execution_risk(event)
            executions.append(event)
            continue

        if event.result not in ("WIN", "LOSS", "BREAKEVEN", "PARTIAL"):
            continue

        exec_event = executions_by_id.get(event.trade_id) if event.trade_id else None
        if not exec_event:
            # Fallback: nearest execution by time and matching side within 3 minutes
            evt_ts = parse_ts(event.timestamp)
            best_exec: Event | None = None
            best_delta: float | None = None
            for candidate in executions:
                key = (candidate.timestamp, candidate.trade_type)
                if key in consumed_exec_keys:
                    continue
                if event.trade_type and candidate.trade_type and event.trade_type != candidate.trade_type:
                    continue
                cand_ts = parse_ts(candidate.timestamp)
                if evt_ts and cand_ts:
                    delta = abs((evt_ts - cand_ts).total_seconds())
                    if delta > 180:
                        continue
                else:
                    delta = 0.0
                if best_delta is None or delta < best_delta:
                    best_delta = delta
                    best_exec = candidate
            exec_event = best_exec

        if not exec_event:
            continue

        if not event.trade_id and exec_event.trade_id:
            event.trade_id = exec_event.trade_id
        if not event.trade_type and exec_event.trade_type:
            event.trade_type = exec_event.trade_type
        consumed_exec_keys.add((exec_event.timestamp, exec_event.trade_type))
        _assign_r_metrics(event, exec_event)


def build_trade_lifecycle(events: list[Event]) -> list[TradeLifecycle]:
    """
    Builds per-trade lifecycle records for reliable resolved-trade accounting.
    A trade is considered resolved only when an explicit exit/result event is linked.
    """
    executions: list[Event] = [e for e in events if e.action == "TRADE_EXECUTED"]
    result_events: list[Event] = [e for e in events if e.result in {"WIN", "LOSS", "BREAKEVEN", "PARTIAL", "CLOSED"}]

    by_id: dict[str, Event] = {e.trade_id: e for e in executions if e.trade_id}
    used_exec: set[tuple[str, str]] = set()
    trades: list[TradeLifecycle] = []

    def _nearest_execution(result_event: Event) -> Event | None:
        evt_ts = parse_ts(result_event.timestamp)
        best_exec: Event | None = None
        best_delta: float | None = None
        for candidate in executions:
            key = (candidate.timestamp, candidate.trade_type)
            if key in used_exec:
                continue
            if result_event.trade_type and candidate.trade_type and result_event.trade_type != candidate.trade_type:
                continue
            cand_ts = parse_ts(candidate.timestamp)
            if evt_ts and cand_ts:
                delta = abs((evt_ts - cand_ts).total_seconds())
                if delta > 3600:
                    continue
            else:
                delta = 0.0
            if best_delta is None or delta < best_delta:
                best_delta = delta
                best_exec = candidate
        return best_exec

    for result_event in result_events:
        exec_event = by_id.get(result_event.trade_id) if result_event.trade_id else None
        if not exec_event:
            exec_event = _nearest_execution(result_event)
        if not exec_event:
            continue

        used_exec.add((exec_event.timestamp, exec_event.trade_type))

        risk = None
        r_multiple = None
        if exec_event.price is not None and exec_event.sl is not None and exec_event.price != exec_event.sl:
            risk = abs(exec_event.price - exec_event.sl)
            if result_event.profit is not None and risk > 0:
                r_multiple = result_event.profit / risk

        trade_result = result_event.result
        if result_event.action == "STOP_LOSS_HIT" and result_event.profit is not None:
            trade_result = "WIN" if result_event.profit > 0 else "LOSS"

        trades.append(
            TradeLifecycle(
                ea_type=exec_event.ea_type,
                trade_id=(result_event.trade_id or exec_event.trade_id or ""),
                trade_type=(exec_event.trade_type or result_event.trade_type or ""),
                entry_price=exec_event.price,
                entry_time=exec_event.timestamp,
                lot=parse_float(parse_kv_pairs(exec_event.raw).get("lot")) if exec_event.raw else None,
                initial_sl=exec_event.sl,
                exit_price=result_event.price,
                exit_time=result_event.timestamp,
                profit=result_event.profit,
                result=trade_result,
                risk=risk,
                r_multiple=r_multiple,
            )
        )

    return trades


def summarize(events: list[Event]) -> dict[str, object]:
    """
    Compiles statistical metrics, win rates, session performance, and R-multiple
    analysis from the list of raw events.
    """
    attach_execution_scores(events)
    attach_skipped_context(events)
    link_trade_outcomes(events)
    trades = build_trade_lifecycle(events)

    signal_events = [e for e in events if e.action == "SIGNAL_CHECK"]
    executed_events = [e for e in events if e.action == "TRADE_EXECUTED"]
    skipped_events = [
        e for e in events if e.result == "SKIPPED" and clean_reason(e.reason) not in VALID_REASONS
    ]
    resolved_trades = [t for t in trades if t.exit_time]
    win_trades = [t for t in resolved_trades if t.result == "WIN"]
    loss_trades = [t for t in resolved_trades if t.result == "LOSS"]

    buy_events = [e for e in executed_events if e.trade_type == "BUY"]
    sell_events = [e for e in executed_events if e.trade_type == "SELL"]

    avg_score = safe_average([e.score for e in executed_events if e.score is not None])
    avg_atr = safe_average([e.atr for e in signal_events + executed_events if e.atr is not None])

    rejection_counter = Counter()
    for e in signal_events:
        if e.result != "SKIPPED":
            continue
        parsed_reason = ""
        if e.reason and clean_reason(e.reason) != "OTHER":
            parsed_reason = extract_reason_from_text(e.reason, default=e.reason)
        else:
            parsed_reason = extract_reason_from_text(e.raw or "", default=e.reason or "UNKNOWN")
        rejection_counter[clean_reason(parsed_reason or "UNKNOWN")] += 1
    session_counter = Counter(e.session for e in signal_events + executed_events)
    reason_counter = Counter(e.reason for e in signal_events + executed_events if e.reason)
    action_counter = Counter(e.action for e in events)

    total_resolved = len(resolved_trades)
    total_signals = len(signal_events)
    total_executed = len(executed_events)
    total_skipped = len(skipped_events)
    execution_rate = (total_executed / total_signals * 100.0) if total_signals else 0.0
    rejection_rate = (total_skipped / total_signals * 100.0) if total_signals else 0.0
    win_rate = (len(win_trades) / total_resolved * 100.0) if total_resolved else 0.0
    loss_rate = (len(loss_trades) / total_resolved * 100.0) if total_resolved else 0.0
    profit_values = [t.profit for t in resolved_trades if t.profit is not None]
    total_profit = sum(profit_values) if profit_values else 0.0
    avg_profit_per_trade = (total_profit / len(profit_values)) if profit_values else 0.0

    # Buy vs Sell Win Rates
    buy_resolved = [t for t in resolved_trades if t.trade_type == "BUY"]
    sell_resolved = [t for t in resolved_trades if t.trade_type == "SELL"]
    buy_win_rate = (len([t for t in buy_resolved if t.result == "WIN"]) / len(buy_resolved) * 100.0) if buy_resolved else 0.0
    sell_win_rate = (len([t for t in sell_resolved if t.result == "WIN"]) / len(sell_resolved) * 100.0) if sell_resolved else 0.0

    # Session Performance
    session_perf = {}
    for session in {"Asian", "London", "New York", "Off Session"}:
        s_resolved = []
        for t in resolved_trades:
            sess = infer_session(t.exit_time or t.entry_time)
            if sess == session:
                s_resolved.append(t)
        if s_resolved:
            s_wins = len([t for t in s_resolved if t.result == "WIN"])
            session_perf[session] = round(s_wins / len(s_resolved) * 100.0, 2)

    # R-Multiple Analysis
    r_values = [t.r_multiple for t in resolved_trades if t.r_multiple is not None]
    avg_r = safe_average(r_values)
    max_r = max(r_values) if r_values else None
    min_r = min(r_values) if r_values else None
    
    r_distribution = {
        "<= -1R": len([r for r in r_values if r <= -0.9]),
        "-1R to 0R": len([r for r in r_values if -0.9 < r < 0]),
        "0R to 1R": len([r for r in r_values if 0 <= r <= 1.0]),
        "1R to 2R": len([r for r in r_values if 1.0 < r <= 2.0]),
        "> 2R": len([r for r in r_values if r > 2.0]),
    } if r_values else {}

    # Trade Frequency
    avg_time_mins, trade_clusters = calculate_trade_frequency(executed_events)

    insights = build_insights(
        total_signals=total_signals,
        total_executed=total_executed,
        avg_score=avg_score,
        rejection_counter=rejection_counter,
        session_counter=session_counter,
    )
    if total_resolved and len(r_values) != total_resolved:
        insights.append(
            f"R coverage gap: {len(r_values)}/{total_resolved} resolved trades have computable R."
        )
    if total_resolved:
        priced_resolved = len([t for t in resolved_trades if t.profit is not None])
        if priced_resolved != total_resolved:
            insights.append(
                f"Profit coverage gap: {priced_resolved}/{total_resolved} resolved trades have explicit profit values."
            )

    total_rejections = sum(rejection_counter.values())
    rejection_reason_distribution = [
        (reason, round((count / total_rejections * 100.0), 2) if total_rejections else 0.0)
        for reason, count in rejection_counter.most_common(10)
    ]

    return {
        "ea_type": events[0].ea_type if events else "UNKNOWN",
        "total_files": len({e.source_file for e in events}),
        "total_events": len(events),
        "total_signals": total_signals,
        "trades_executed": total_executed,
        "trades_skipped": total_skipped,
        "execution_rate": round(execution_rate, 2),
        "rejection_rate": round(rejection_rate, 2),
        "wins": len(win_trades),
        "losses": len(loss_trades),
        "resolved_trades": total_resolved,
        "total_profit": round(total_profit, 2),
        "avg_profit_per_trade": round(avg_profit_per_trade, 2),
        "win_rate": round(win_rate, 2),
        "loss_rate": round(loss_rate, 2),
        "buy_trades_executed": len(buy_events),
        "sell_trades_executed": len(sell_events),
        "buy_win_rate": round(buy_win_rate, 2),
        "sell_win_rate": round(sell_win_rate, 2),
        "avg_r_multiple": round(avg_r, 2) if avg_r is not None else None,
        "max_r_multiple": round(max_r, 2) if max_r is not None else None,
        "min_r_multiple": round(min_r, 2) if min_r is not None else None,
        "r_distribution": r_distribution,
        "session_win_rates": session_perf,
        "avg_time_between_trades_minutes": round(avg_time_mins, 2) if avg_time_mins else None,
        "trade_clusters_detected": trade_clusters,
        "average_score_executed": round(avg_score, 2) if avg_score is not None else None,
        "average_atr": round(avg_atr, 2) if avg_atr is not None else None,
        "top_rejection_reasons": rejection_counter.most_common(10),
        "rejection_reason_distribution": rejection_reason_distribution,
        "reasons": reason_counter.most_common(),
        "sessions": session_counter.most_common(),
        "actions": action_counter.most_common(),
        "closed_trades_count": len(resolved_trades),
        "lifecycle_validation_ok": bool(total_resolved == len(r_values) or len(r_values) <= total_resolved),
        "insights": insights,
    }


def split_by_ea(events: list[Event]) -> dict[str, list[Event]]:
    """Splits a list of events into a dictionary keyed by EA type."""
    data = {
        "M1_SCALPER": [],
        "M5": [],
    }
    for event in events:
        if event.ea_type in data:
            data[event.ea_type].append(event)
    return data


def safe_average(values: list[float]) -> float | None:
    if not values:
        return None
    return sum(values) / len(values)


def build_insights(
    *,
    total_signals: int,
    total_executed: int,
    avg_score: float | None,
    rejection_counter: Counter[str],
    session_counter: Counter[str],
) -> list[str]:
    insights: list[str] = []

    if total_signals and total_executed / total_signals < 0.2:
        insights.append("Trade conversion is low; filters may be blocking most setups.")

    if rejection_counter:
        top_reason, top_count = rejection_counter.most_common(1)[0]
        share = (top_count / max(sum(rejection_counter.values()), 1)) * 100.0
        insights.append(f"Most signals were blocked by {top_reason} ({share:.1f}% of rejections).")

    if avg_score is not None:
        if avg_score < 60:
            insights.append("Executed trade quality looks weak based on average score.")
        elif avg_score >= 80:
            insights.append("Executed trades are generally high-conviction based on score.")

    if session_counter:
        top_session, top_count = session_counter.most_common(1)[0]
        insights.append(f"Most signal activity occurred during the {top_session} session ({top_count} events).")

    if not insights:
        insights.append("Not enough classified data was found to derive strong insights.")
    return insights


def print_summary(title: str, summary: dict[str, object]) -> None:
    print("=====================")
    print(f"{title} SUMMARY")
    print("==========")
    print()
    print(f"Total Files: {summary['total_files']}")
    print(f"Total Signals: {summary['total_signals']}")
    print(f"Trades Taken: {summary['trades_executed']}")
    print(f"Trades Skipped: {summary['trades_skipped']}")
    print(f"Resolved Trades: {summary['resolved_trades']}")
    print(f"Win Rate: {summary['win_rate']:.2f}%")
    print(f"Loss Rate: {summary['loss_rate']:.2f}%")
    print()
    print("--- Execution Quality ---")
    print(f"Execution Rate: {summary['execution_rate']:.2f}%")
    print(f"Rejection Rate: {summary['rejection_rate']:.2f}%")

    print()
    print("--- Directional Performance ---")
    print(f"BUY Trades Taken: {summary['buy_trades_executed']} (Win Rate: {summary['buy_win_rate']:.2f}%)")
    print(f"SELL Trades Taken: {summary['sell_trades_executed']} (Win Rate: {summary['sell_win_rate']:.2f}%)")

    print()
    print("--- R-Multiple & Profitability ---")
    avg_r = summary['avg_r_multiple']
    print(f"Average R-Multiple: {avg_r if avg_r is not None else 'N/A'}")
    print(f"Max R-Multiple (Best Trade): {summary['max_r_multiple'] if summary['max_r_multiple'] is not None else 'N/A'}")
    print(f"Min R-Multiple (Worst Trade): {summary['min_r_multiple'] if summary['min_r_multiple'] is not None else 'N/A'}")
    if summary['r_distribution']:
        print("R-Multiple Distribution:")
        for band, count in summary['r_distribution'].items():
            print(f"  {band}: {count} trades")
    print()
    print("--- Profitability ---")
    print(f"Total Profit: {summary['total_profit']}")
    print(f"Avg Profit per Trade: {summary['avg_profit_per_trade']}")
            
    print()
    print("--- Session & Frequency Insights ---")
    if summary['session_win_rates']:
        for session, rate in summary['session_win_rates'].items():
            print(f"Win Rate ({session}): {rate:.2f}%")
    avg_time = summary['avg_time_between_trades_minutes']
    print(f"Avg Time Between Trades: {f'{avg_time} mins' if avg_time else 'N/A'}")
    print(f"Rapid Consecutive Trades (Clusters): {summary['trade_clusters_detected']}")
    print()

    avg_score = summary["average_score_executed"]
    avg_atr = summary["average_atr"]
    print(f"Average Score (Trades): {avg_score if avg_score is not None else 'N/A'}")
    print(f"Average ATR: {avg_atr if avg_atr is not None else 'N/A'}")
    print()

    print("Top Rejection Reasons:")
    top_rejections = summary["top_rejection_reasons"]
    if top_rejections:
        total_rejections = sum(count for _, count in top_rejections)
        for reason, count in top_rejections:
            pct = (count / total_rejections * 100.0) if total_rejections else 0.0
            print(f"- {reason}: {count} ({pct:.1f}%)")
    else:
        print("- None detected")
    top_rejection_reason = format_top_reason(top_rejections)
    print()
    print("--- Top Issues ---")
    print(f"Top rejection reason: {top_rejection_reason}")
    print()

    print("Session Activity:")
    sessions = summary["sessions"]
    if sessions:
        for session_name, count in sessions:
            print(f"- {session_name}: {count}")
    else:
        print("- No session data")
    print()

    print("Insights:")
    for insight in summary["insights"]:
        print(f"- {insight}")
    print()


def print_comparison(m1_summary: dict[str, object] | None, m5_summary: dict[str, object] | None) -> None:
    print("COMPARISON:")
    print()

    if m1_summary and m5_summary:
        m1_trade_rate = (
            m1_summary["trades_executed"] / m1_summary["total_signals"] * 100.0
            if m1_summary["total_signals"]
            else 0.0
        )
        m5_trade_rate = (
            m5_summary["trades_executed"] / m5_summary["total_signals"] * 100.0
            if m5_summary["total_signals"]
            else 0.0
        )
        print(f"- M1 Trade Rate vs M5: {m1_trade_rate:.2f}% vs {m5_trade_rate:.2f}%")
        print(f"- M1 Win Rate vs M5: {m1_summary['win_rate']:.2f}% vs {m5_summary['win_rate']:.2f}%")
        print(
            "- Most common rejection reasons:"
            f" M1={format_top_reason(m1_summary['top_rejection_reasons'])},"
            f" M5={format_top_reason(m5_summary['top_rejection_reasons'])}"
        )

        if m1_summary["trades_executed"] == 0:
            print("- M1 has no executed trades in the analyzed data.")
        if m5_summary["trades_executed"] == 0:
            print("- M5 has no executed trades in the analyzed data.")
        if m1_trade_rate < 1.0:
            print("- M1 appears to be heavily filtered or under-triggering.")
        if m5_trade_rate < 1.0:
            print("- M5 appears to be heavily filtered or under-triggering.")
        if m1_trade_rate > m5_trade_rate * 2 and m5_trade_rate > 0:
            print("- M1 is materially more active than M5.")
        elif m5_trade_rate > m1_trade_rate * 2 and m1_trade_rate > 0:
            print("- M5 is materially more active than M1.")
    else:
        print("- Only one EA was detected, so cross-comparison is limited.")


def format_top_reason(reasons: list[tuple[str, int]]) -> str:
    if not reasons:
        return "None"
    reason, count = reasons[0]
    return f"{reason} ({count})"


def export_events_csv(path: Path, events: list[Event]) -> None:
    rows = [asdict(event) for event in events]
    fieldnames = [
        "ea_type",
        "timestamp",
        "session",
        "symbol",
        "source_file",
        "action",
        "trade_type",
        "strategy",
        "score",
        "atr",
        "price",
        "sl",
        "tp",
        "reason",
        "result",
        "trade_id",
        "profit",
        "risk",
        "r_multiple",
        "raw",
    ]
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def export_summary_csv(path: Path, summary: dict[str, object]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["metric", "value"])
        for key, value in summary.items():
            if isinstance(value, (list, dict)):
                writer.writerow([key, json.dumps(value)])
            else:
                writer.writerow([key, value])


def export_multi_summary_csv(path: Path, summaries: dict[str, dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["ea_type", "metric", "value"])
        for ea_type, summary in summaries.items():
            for key, value in summary.items():
                if isinstance(value, (list, dict)):
                    writer.writerow([ea_type, key, json.dumps(value)])
                else:
                    writer.writerow([ea_type, key, value])


def export_json(path: Path, payload: dict[str, object]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)


def main() -> int:
    args = parse_args()
    files = discover_files(args.paths)
    if not files:
        print("No .log or .txt files found.", file=sys.stderr)
        return 1

    all_events: list[Event] = []
    for path in files:
        all_events.extend(parse_log_file(path))

    if not all_events:
        print("No GoldEA events found in the provided files.", file=sys.stderr)
        return 1

    data = split_by_ea(all_events)
    summaries: dict[str, dict[str, object]] = {}

    for ea_type in ("M1_SCALPER", "M5"):
        ea_events = data.get(ea_type, [])
        if not ea_events:
            continue
        summaries[ea_type] = summarize(ea_events)
        print_summary(ea_type, summaries[ea_type])

    print_comparison(summaries.get("M1_SCALPER"), summaries.get("M5"))

    # --- Automatic Directory Export (log_analysis_output/) ---
    output_dir = Path(__file__).parent.parent / "log_analysis_output"
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Always save copies to the standard output folder
    export_events_csv(output_dir / "events.csv", all_events)
    if len(summaries) == 1:
        export_summary_csv(output_dir / "summary.csv", next(iter(summaries.values())))
    elif len(summaries) > 1:
        export_multi_summary_csv(output_dir / "summary.csv", summaries)
        
    export_json(output_dir / "data.json", {
        "summaries": summaries,
        "data": {ea_type: [asdict(event) for event in ea_events] for ea_type, ea_events in data.items() if ea_events},
        "events": [asdict(event) for event in all_events],
    })

    # --- Process Optional CLI Args if Provided ---
    if args.events_csv:
        export_events_csv(Path(args.events_csv), all_events)
    if args.summary_csv:
        if len(summaries) <= 1 and summaries:
            only_summary = next(iter(summaries.values()))
            export_summary_csv(Path(args.summary_csv), only_summary)
        elif summaries:
            export_multi_summary_csv(Path(args.summary_csv), summaries)
    if args.json_path:
        export_json(
            Path(args.json_path),
            {
                "summaries": summaries,
                "data": {ea_type: [asdict(event) for event in ea_events] for ea_type, ea_events in data.items() if ea_events},
                "events": [asdict(event) for event in all_events],
            },
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
