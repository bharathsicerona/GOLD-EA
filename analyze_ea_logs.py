#!/usr/bin/env python3
"""
Analyze MetaTrader 5 Expert Advisor logs and produce a trading summary.

Supported inputs:
- .log files from MT5 Strategy Tester / Experts logs
- .txt files with copied log output

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
from datetime import datetime
from pathlib import Path
from typing import Iterable


TIMESTAMP_RE = re.compile(r"(?P<ts>\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})")
CHECK_RE = re.compile(
    r"""
    \[GoldEA\]\s+
    \[(?P<strategy>[^\]]+)\]\s+
    (?P<side>BUY|SELL)\s+check:
    (?P<body>.*)
    """,
    re.IGNORECASE | re.VERBOSE,
)
EXEC_RE = re.compile(
    r"""
    \[GoldEA\]\s+
    (?P<side>BUY|SELL)\s+executed:
    (?P<body>.*)
    """,
    re.IGNORECASE | re.VERBOSE,
)
RESULT_RE = re.compile(
    r"""
    \[GoldEA\]\s+
    (?:
        (?P<stop>STOP\s+LOSS\s+HIT)|
        (?P<tp>TAKE\s+PROFIT\s+HIT)|
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
VALID_REASONS = {"VALID", "READY", "ENTRY_READY", "SETUP_VALID", "SETUP_VALID_OVERRIDE", "EXECUTED"}
M1_HINTS = ("M1_Scalper", "timeframe=1", "[SCALPER_TREND]")
M5_HINTS = ("Adaptive_MultiFactor", "timeframe=5", "[TREND]", "[RANGE]")


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
    reason: str
    result: str
    trade_id: str
    raw: str


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
    reason: str = "",
    result: str = "",
    trade_id: str = "",
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
        reason=clean_reason(reason),
        result=result,
        trade_id=trade_id,
        raw=raw.strip(),
    )


def classify_ea_line(line: str, source_file: Path, current_ea: str = "") -> str:
    upper_line = line.upper()
    source_upper = source_file.name.upper()

    if any(hint.upper() in upper_line for hint in M1_HINTS):
        return "M1"
    if any(hint.upper() in upper_line for hint in M5_HINTS):
        return "M5"
    if "M1_SCALPER" in source_upper:
        return "M1"
    if "ADAPTIVE_MULTIFACTOR" in source_upper or "ADAPTIVE_MULTI_FACTOR" in source_upper:
        return "M5"
    return current_ea or "UNKNOWN"


def parse_check_line(line: str, source_file: Path, ea_type: str) -> Event | None:
    match = CHECK_RE.search(line)
    if not match:
        return None

    body = match.group("body")
    kv = parse_kv_pairs(body)
    timestamp = extract_timestamp(line)
    symbol = extract_symbol(line)
    reason = kv.get("reason", "UNKNOWN")
    score = parse_float(kv.get("score"))
    atr = parse_float(kv.get("atr"))
    price = parse_float(kv.get("price"))

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
        reason=reason,
        result=result,
        raw=line,
    )


def parse_execution_line(line: str, source_file: Path, ea_type: str) -> Event | None:
    match = EXEC_RE.search(line)
    if not match:
        return None

    body = match.group("body")
    kv = parse_kv_pairs(body)
    timestamp = extract_timestamp(line)
    symbol = extract_symbol(line)
    trade_id_match = TRADE_ID_RE.search(body)

    return build_event(
        ea_type=ea_type,
        timestamp=timestamp,
        symbol=symbol,
        source_file=source_file,
        action="TRADE_EXECUTED",
        trade_type=match.group("side"),
        strategy="",
        score=parse_float(kv.get("score")),
        atr=parse_float(kv.get("atr")),
        price=parse_float(kv.get("entry") or kv.get("price")),
        reason=kv.get("reason", "EXECUTED"),
        result="EXECUTED",
        trade_id=trade_id_match.group(1) if trade_id_match else "",
        raw=line,
    )


def parse_result_line(line: str, source_file: Path, ea_type: str) -> Event | None:
    match = RESULT_RE.search(line)
    if not match or "[GoldEA]" not in line:
        return None

    timestamp = extract_timestamp(line)
    symbol = extract_symbol(line)
    raw_upper = line.upper()
    trade_match = TRADE_ID_RE.search(line)
    ticket_match = TICKET_RE.search(line)
    side_match = BUY_SELL_RE.search(line)

    if match.group("stop"):
        return build_event(
            ea_type=ea_type,
            timestamp=timestamp,
            symbol=symbol,
            source_file=source_file,
            action="STOP_LOSS_HIT",
            trade_type=side_match.group(1) if side_match else "",
            reason="STOP_LOSS_HIT",
            result="LOSS",
            trade_id=(trade_match.group(1) if trade_match else ticket_match.group(1) if ticket_match else ""),
            raw=line,
        )

    if match.group("tp"):
        return build_event(
            ea_type=ea_type,
            timestamp=timestamp,
            symbol=symbol,
            source_file=source_file,
            action="TAKE_PROFIT_HIT",
            trade_type=side_match.group(1) if side_match else "",
            reason="TAKE_PROFIT_HIT",
            result="WIN",
            trade_id=(trade_match.group(1) if trade_match else ticket_match.group(1) if ticket_match else ""),
            raw=line,
        )

    if match.group("be"):
        return build_event(
            ea_type=ea_type,
            timestamp=timestamp,
            symbol=symbol,
            source_file=source_file,
            action="BREAKEVEN",
            trade_type=side_match.group(1) if side_match else "",
            reason="BREAKEVEN",
            result="BREAKEVEN",
            trade_id=(trade_match.group(1) if trade_match else ticket_match.group(1) if ticket_match else ""),
            raw=line,
        )

    if match.group("partial"):
        return build_event(
            ea_type=ea_type,
            timestamp=timestamp,
            symbol=symbol,
            source_file=source_file,
            action="PARTIAL_CLOSE",
            trade_type=side_match.group(1) if side_match else "",
            reason="PARTIAL_CLOSE",
            result="PARTIAL",
            trade_id=(trade_match.group(1) if trade_match else ticket_match.group(1) if ticket_match else ""),
            raw=line,
        )

    if match.group("skip"):
        reason = "TRADE_SKIPPED"
        reason_match = re.search(r"reason=([A-Za-z0-9_]+)", line, re.IGNORECASE)
        if reason_match:
            reason = reason_match.group(1)
        return build_event(
            ea_type=ea_type,
            timestamp=timestamp,
            symbol=symbol,
            source_file=source_file,
            action="TRADE_SKIPPED",
            trade_type=side_match.group(1) if side_match else "",
            reason=reason,
            result="SKIPPED",
            raw=line,
        )

    if match.group("trail"):
        return build_event(
            ea_type=ea_type,
            timestamp=timestamp,
            symbol=symbol,
            source_file=source_file,
            action="TRAILING_UPDATE",
            trade_type=side_match.group(1) if side_match else "",
            reason="TRAILING_UPDATE",
            result="MANAGEMENT",
            trade_id=(trade_match.group(1) if trade_match else ticket_match.group(1) if ticket_match else ""),
            raw=line,
        )

    if "TRADE EXECUTED" in raw_upper or " EXECUTED:" in raw_upper:
        return None

    return None


def parse_log_file(path: Path) -> list[Event]:
    events: list[Event] = []
    text = read_text_auto(path)
    current_ea = classify_ea_line(path.name, path)
    for line in text.splitlines():
        line_ea = classify_ea_line(line, path, current_ea)
        if line_ea != "UNKNOWN":
            current_ea = line_ea
        if "[GoldEA]" not in line:
            continue
        event = (
            parse_check_line(line, path, current_ea)
            or parse_execution_line(line, path, current_ea)
            or parse_result_line(line, path, current_ea)
        )
        if event:
            events.append(event)
    return events


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


def summarize(events: list[Event]) -> dict[str, object]:
    attach_execution_scores(events)

    signal_events = [e for e in events if e.action == "SIGNAL_CHECK"]
    executed_events = [e for e in events if e.action == "TRADE_EXECUTED"]
    skipped_events = [
        e for e in events if e.result == "SKIPPED" and clean_reason(e.reason) not in VALID_REASONS
    ]
    win_events = [e for e in events if e.result == "WIN"]
    loss_events = [e for e in events if e.result == "LOSS"]
    resolved_events = win_events + loss_events

    avg_score = safe_average([e.score for e in executed_events if e.score is not None])
    avg_atr = safe_average([e.atr for e in signal_events + executed_events if e.atr is not None])

    rejection_counter = Counter(
        e.reason for e in signal_events if e.result == "SKIPPED" and e.reason
    )
    session_counter = Counter(e.session for e in signal_events + executed_events)
    reason_counter = Counter(e.reason for e in signal_events + executed_events if e.reason)
    action_counter = Counter(e.action for e in events)

    total_resolved = len(resolved_events)
    total_signals = len(signal_events)
    total_executed = len(executed_events)
    total_skipped = len(skipped_events)
    win_rate = (len(win_events) / total_resolved * 100.0) if total_resolved else 0.0
    loss_rate = (len(loss_events) / total_resolved * 100.0) if total_resolved else 0.0

    insights = build_insights(
        total_signals=total_signals,
        total_executed=total_executed,
        avg_score=avg_score,
        rejection_counter=rejection_counter,
        session_counter=session_counter,
    )

    return {
        "ea_type": events[0].ea_type if events else "UNKNOWN",
        "total_files": len({e.source_file for e in events}),
        "total_events": len(events),
        "total_signals": total_signals,
        "trades_executed": total_executed,
        "trades_skipped": total_skipped,
        "wins": len(win_events),
        "losses": len(loss_events),
        "resolved_trades": total_resolved,
        "win_rate": round(win_rate, 2),
        "loss_rate": round(loss_rate, 2),
        "average_score_executed": round(avg_score, 2) if avg_score is not None else None,
        "average_atr": round(avg_atr, 2) if avg_atr is not None else None,
        "top_rejection_reasons": rejection_counter.most_common(10),
        "reasons": reason_counter.most_common(),
        "sessions": session_counter.most_common(),
        "actions": action_counter.most_common(),
        "insights": insights,
    }


def split_by_ea(events: list[Event]) -> dict[str, list[Event]]:
    data = {
        "M1": [],
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
        "reason",
        "result",
        "trade_id",
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
            if isinstance(value, list):
                writer.writerow([key, json.dumps(value)])
            else:
                writer.writerow([key, value])


def export_multi_summary_csv(path: Path, summaries: dict[str, dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["ea_type", "metric", "value"])
        for ea_type, summary in summaries.items():
            for key, value in summary.items():
                if isinstance(value, list):
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

    for ea_type in ("M1", "M5"):
        ea_events = data[ea_type]
        if not ea_events:
            continue
        summaries[ea_type] = summarize(ea_events)
        print_summary(ea_type, summaries[ea_type])

    print_comparison(summaries.get("M1"), summaries.get("M5"))

    if args.events_csv:
        export_events_csv(Path(args.events_csv), all_events)
    if args.summary_csv:
        if len(summaries) <= 1:
            only_summary = next(iter(summaries.values()))
            export_summary_csv(Path(args.summary_csv), only_summary)
        else:
            export_multi_summary_csv(Path(args.summary_csv), summaries)
    if args.json_path:
        export_json(
            Path(args.json_path),
            {
                "summaries": summaries,
                "data": {ea_type: [asdict(event) for event in ea_events] for ea_type, ea_events in data.items()},
                "events": [asdict(event) for event in all_events],
            },
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
