import csv
import html
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CSV_PATH = ROOT / "qwopus-q5-262k-bookcontext.csv"
SVG_PATH = ROOT / "qwopus-q5-262k-bookcontext.svg"

FONT = "Inter, Segoe UI, Arial, sans-serif"
BG = "#fbfcfd"
CARD = "#ffffff"
BORDER = "#e5ebf0"
TEXT = "#17202a"
MUTED = "#5e6b78"
GRID = "#d8e0e8"
STRIPE = "#f7f9fb"
PREFILL = "#2468c9"
GEN = "#0f8a73"
OVERHEAD = "#c76b22"


def esc(value):
    return html.escape(str(value), quote=True)


def read_rows():
    with CSV_PATH.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    for row in rows:
        row["prompt_tokens"] = int(row["prompt_tokens"])
        row["completion_tokens"] = int(row["completion_tokens"])
        row["prompt_tps"] = float(row["prompt_tps"])
        row["eval_tps"] = float(row["eval_tps"])
        row["wall_seconds"] = float(row["wall_seconds"])
        row["wall_tps"] = float(row["wall_tps"])
        row["prefill_seconds"] = row["prompt_tokens"] / row["prompt_tps"]
        row["decode_seconds"] = row["completion_tokens"] / row["eval_tps"]
        row["other_seconds"] = max(0.0, row["wall_seconds"] - row["prefill_seconds"] - row["decode_seconds"])
    return rows


def draw_axis(parts, left, right, top, bottom, max_tick, step, suffix=""):
    scale = (right - left) / max_tick
    for tick in range(0, max_tick + 1, step):
        x = left + tick * scale
        parts.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{bottom}" stroke="{GRID}" stroke-width="1"/>')
        parts.append(f'<text x="{x:.1f}" y="{bottom + 20}" text-anchor="middle" font-family="{FONT}" font-size="11" fill="{MUTED}">{tick}{suffix}</text>')
    return scale


def fixture_label(row):
    return row["fixture"].replace("book-context-", "").upper().replace("K", "K prompt")


def draw_metric_rows(parts, rows, value_key, x, y, width, max_tick, step, title, unit, color):
    parts.append(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="17" font-weight="700" fill="{TEXT}">{esc(title)}</text>')
    parts.append(f'<text x="{x}" y="{y + 22}" font-family="{FONT}" font-size="12" fill="{MUTED}">{esc(unit)}</text>')
    chart_top = y + 42
    row_h = 54
    chart_bottom = chart_top + row_h * len(rows) + 6
    scale = draw_axis(parts, x + 150, x + width, chart_top - 8, chart_bottom, max_tick, step)

    for i, row in enumerate(rows):
        row_y = chart_top + i * row_h
        if i % 2 == 0:
            parts.append(f'<rect x="{x}" y="{row_y - 8}" width="{width}" height="46" rx="6" fill="{STRIPE}"/>')
        value = row[value_key]
        bar_w = value * scale
        parts.append(f'<text x="{x + 14}" y="{row_y + 16}" font-family="{FONT}" font-size="14" font-weight="650" fill="{TEXT}">{esc(fixture_label(row))}</text>')
        parts.append(f'<text x="{x + 14}" y="{row_y + 34}" font-family="{FONT}" font-size="11" fill="{MUTED}">{row["prompt_tokens"]:,} prompt tokens</text>')
        parts.append(f'<rect x="{x + 150}" y="{row_y + 5}" width="{bar_w:.1f}" height="18" rx="3" fill="{color}"/>')
        parts.append(f'<text x="{x + 150 + bar_w + 8:.1f}" y="{row_y + 19}" font-family="{FONT}" font-size="12" font-weight="650" fill="{TEXT}">{value:.1f}</text>')
    return chart_bottom + 38


def draw_wall_rows(parts, rows, x, y, width):
    parts.append(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="19" font-weight="700" fill="{TEXT}">Cold one-shot wall time breakdown</text>')
    parts.append(f'<text x="{x}" y="{y + 24}" font-family="{FONT}" font-size="13" fill="{MUTED}">The 200K run is dominated by prompt prefill. MTP helps decode, not the cold prefill pass.</text>')

    left = x + 210
    right = x + width
    chart_top = y + 56
    row_h = 66
    chart_bottom = chart_top + row_h * len(rows) + 8
    max_tick = int(math.ceil(max(row["wall_seconds"] for row in rows) / 100.0) * 100)
    scale = draw_axis(parts, left, right, chart_top - 8, chart_bottom, max_tick, 150, "s")

    for i, row in enumerate(rows):
        row_y = chart_top + i * row_h
        if i % 2 == 0:
            parts.append(f'<rect x="{x}" y="{row_y - 9}" width="{width}" height="58" rx="6" fill="{STRIPE}"/>')

        parts.append(f'<text x="{x + 14}" y="{row_y + 17}" font-family="{FONT}" font-size="15" font-weight="650" fill="{TEXT}">{esc(fixture_label(row))}</text>')
        parts.append(f'<text x="{x + 14}" y="{row_y + 38}" font-family="{FONT}" font-size="11" fill="{MUTED}">wall {row["wall_seconds"]:.2f}s, {row["wall_tps"]:.2f} wall tok/s</text>')

        cursor = left
        segments = [
            ("prefill", row["prefill_seconds"], PREFILL),
            ("decode", row["decode_seconds"], GEN),
            ("startup/other", row["other_seconds"], OVERHEAD),
        ]
        for label, seconds, color in segments:
            seg_w = seconds * scale
            parts.append(f'<rect x="{cursor:.1f}" y="{row_y + 8}" width="{seg_w:.1f}" height="20" rx="3" fill="{color}"/>')
            if seg_w > 48:
                parts.append(f'<text x="{cursor + seg_w / 2:.1f}" y="{row_y + 23}" text-anchor="middle" font-family="{FONT}" font-size="10" font-weight="650" fill="#ffffff">{seconds:.1f}s</text>')
            cursor += seg_w
        parts.append(f'<text x="{cursor + 8:.1f}" y="{row_y + 23}" font-family="{FONT}" font-size="12" font-weight="650" fill="{TEXT}">{row["wall_seconds"]:.1f}s total</text>')

    legend_y = chart_bottom + 34
    legend = [("prompt prefill", PREFILL), ("generated output", GEN), ("startup/other", OVERHEAD)]
    legend_x = x + 210
    for label, color in legend:
        parts.append(f'<rect x="{legend_x}" y="{legend_y - 12}" width="14" height="14" rx="2" fill="{color}"/>')
        parts.append(f'<text x="{legend_x + 22}" y="{legend_y}" font-family="{FONT}" font-size="12" fill="{TEXT}">{esc(label)}</text>')
        legend_x += 165
    return legend_y + 40


def render():
    rows = read_rows()
    width = 1180
    height = 820

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">',
        '<title id="title">Qwopus3.6 Coder MTP Q5_K_M 262K BookContext benchmark on Ryzen AI Max+ 395</title>',
        '<desc id="desc">Chart splitting Qwopus prompt prefill, generated output, and cold wall time for 10K and 200K BookContext fixtures on AMD Ryzen AI Max+ 395 chipset with Radeon 8060S.</desc>',
        f'<rect width="{width}" height="{height}" fill="{BG}"/>',
        f'<rect x="20" y="20" width="{width - 40}" height="{height - 40}" rx="8" fill="{CARD}" stroke="{BORDER}"/>',
        f'<text x="42" y="62" font-family="{FONT}" font-size="29" font-weight="700" fill="{TEXT}">Qwopus3.6 Coder MTP Q5_K_M 262K BookContext</text>',
        f'<text x="42" y="91" font-family="{FONT}" font-size="15" fill="{MUTED}">AMD Ryzen AI Max+ 395 chipset / Radeon 8060S, Windows HIP/ROCm, Unsloth llama.cpp, MTP n=2, f16 KV</text>',
        f'<text x="42" y="116" font-family="{FONT}" font-size="13" fill="{MUTED}">The 623.2 tok/s result is 10K prompt prefill, not generated-output speed. Decode was 40.5 tok/s at 10K and 23.9 tok/s at 200K.</text>',
    ]

    next_y = draw_metric_rows(
        parts,
        rows,
        "prompt_tps",
        42,
        158,
        520,
        650,
        130,
        "Prompt prefill",
        "prompt tokens per second",
        PREFILL,
    )
    draw_metric_rows(
        parts,
        rows,
        "eval_tps",
        610,
        158,
        520,
        45,
        15,
        "Generated output",
        "eval tokens per second",
        GEN,
    )

    wall_bottom = draw_wall_rows(parts, rows, 42, max(next_y + 42, 388), 1088)

    footer_y = wall_bottom + 12
    parts.append(f'<text x="42" y="{footer_y}" font-family="{FONT}" font-size="12" fill="{MUTED}">Source: docs/assets/qwopus-q5-262k-bookcontext.csv and raw CSV under results/qwopus36-35b-a3b-coder-mtp-gguf/.</text>')
    parts.append(f'<text x="42" y="{footer_y + 20}" font-family="{FONT}" font-size="12" fill="{MUTED}">Full wall tok/s is cold CLI one-shot throughput; steady Hermes/server decode can feel closer to eval tok/s after the prompt is processed.</text>')
    parts.append("</svg>")

    SVG_PATH.write_text("\n".join(parts) + "\n", encoding="utf-8")


if __name__ == "__main__":
    render()
