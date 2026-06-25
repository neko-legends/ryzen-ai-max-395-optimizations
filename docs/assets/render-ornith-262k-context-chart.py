import csv
import html
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CSV_PATH = ROOT / "ornith-262k-context.csv"
SVG_PATH = ROOT / "ornith-262k-context.svg"

FONT = "Inter, Segoe UI, Arial, sans-serif"
BG = "#fbfcfd"
CARD = "#ffffff"
BORDER = "#e5ebf0"
TEXT = "#17202a"
MUTED = "#5e6b78"
GRID = "#d8e0e8"
STRIPE = "#f7f9fb"
Q4 = "#2468c9"
Q5 = "#0f8a73"
ACCENT = "#c76b22"


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
    return rows


def quant_color(row):
    return Q4 if row["quant"] == "Q4_K_M" else Q5


def draw_axis(parts, left, right, top, bottom, max_tick, step):
    scale = (right - left) / max_tick
    for tick in range(0, max_tick + 1, step):
        x = left + tick * scale
        parts.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{bottom}" stroke="{GRID}" stroke-width="1"/>')
        parts.append(f'<text x="{x:.1f}" y="{bottom + 22}" text-anchor="middle" font-family="{FONT}" font-size="12" fill="{MUTED}">{tick}</text>')
    return scale


def draw_bar_rows(parts, rows, value_key, left, right, top, row_h, max_tick, step, subtitle_key):
    axis_bottom = top + row_h * len(rows) + 10
    scale = draw_axis(parts, left, right, top - 10, axis_bottom, max_tick, step)

    for i, row in enumerate(rows):
        y = top + i * row_h
        if i % 2 == 0:
            parts.append(f'<rect x="42" y="{y - 8}" width="1086" height="50" rx="6" fill="{STRIPE}"/>')

        label = f'Ornith {row["quant"]} - {row["context_label"]}'
        subtitle = subtitle_key(row)
        value = row[value_key]
        bar_w = value * scale

        parts.append(f'<text x="60" y="{y + 18}" font-family="{FONT}" font-size="15" font-weight="650" fill="{TEXT}">{esc(label)}</text>')
        parts.append(f'<text x="60" y="{y + 38}" font-family="{FONT}" font-size="12" fill="{MUTED}">{esc(subtitle)}</text>')
        parts.append(f'<rect x="{left}" y="{y + 8}" width="{bar_w:.1f}" height="17" rx="3" fill="{quant_color(row)}"/>')
        parts.append(f'<text x="{left + bar_w + 8:.1f}" y="{y + 21}" font-family="{FONT}" font-size="12" font-weight="650" fill="{TEXT}">{value:.2f}</text>')

    return axis_bottom


def render():
    rows = read_rows()
    generation_rows = rows
    long_rows = [row for row in rows if row["prompt_tokens"] > 1000]

    width = 1180
    height = 840
    plot_left = 360
    plot_right = 1080
    row_h = 58

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">',
        '<title id="title">Ornith 1.0 35B context benchmark on Ryzen AI Max+ 395</title>',
        '<desc id="desc">Two-panel bar chart showing Ornith Q4 and Q5 generation throughput at short and 174K context, plus cold prefill speed for the 174K prompt fixture.</desc>',
        f'<rect width="{width}" height="{height}" fill="{BG}"/>',
        f'<rect x="20" y="20" width="{width - 40}" height="{height - 40}" rx="8" fill="{CARD}" stroke="{BORDER}"/>',
        f'<text x="42" y="62" font-family="{FONT}" font-size="30" font-weight="700" fill="{TEXT}">Ornith 1.0 35B 262K context findings</text>',
        f'<text x="42" y="91" font-family="{FONT}" font-size="15" fill="{MUTED}">Ryzen AI Max+ 395 / Radeon 8060S, Windows HIP/ROCm, llama.cpp, no MTP, f16 KV, t28 ub1024</text>',
        f'<text x="42" y="116" font-family="{FONT}" font-size="13" fill="{MUTED}">Cold 174K fixture results are split into prefill and generation. Full one-shot wall tok/s is intentionally not charted as steady throughput.</text>',
        f'<rect x="875" y="53" width="14" height="14" rx="2" fill="{Q4}"/>',
        f'<text x="897" y="65" font-family="{FONT}" font-size="14" fill="{TEXT}">Q4_K_M</text>',
        f'<rect x="875" y="78" width="14" height="14" rx="2" fill="{Q5}"/>',
        f'<text x="897" y="90" font-family="{FONT}" font-size="14" fill="{TEXT}">Q5_K_M</text>',
    ]

    parts.append(f'<text x="42" y="158" font-family="{FONT}" font-size="19" font-weight="700" fill="{TEXT}">Generation speed</text>')
    parts.append(f'<text x="42" y="180" font-family="{FONT}" font-size="13" fill="{MUTED}">Eval tok/s only. This is the output speed after prompt processing.</text>')
    gen_bottom = draw_bar_rows(
        parts,
        generation_rows,
        "eval_tps",
        plot_left,
        plot_right,
        206,
        row_h,
        40,
        10,
        lambda row: f'{row["completion_tokens"]} generated tokens, {row["prompt_tokens"]:,} prompt tokens',
    )
    parts.append(f'<text x="{(plot_left + plot_right) / 2:.1f}" y="{gen_bottom + 48}" text-anchor="middle" font-family="{FONT}" font-size="13" fill="{MUTED}">generation tokens per second</text>')

    prefill_top = gen_bottom + 98
    parts.append(f'<text x="42" y="{prefill_top - 30}" font-family="{FONT}" font-size="19" font-weight="700" fill="{TEXT}">Cold prefill speed for the BookContext fixture</text>')
    parts.append(f'<text x="42" y="{prefill_top - 8}" font-family="{FONT}" font-size="13" fill="{MUTED}">One request containing the full copied target-200K prompt, counted by Ornith as 174,588 prompt tokens.</text>')
    prefill_bottom = draw_bar_rows(
        parts,
        long_rows,
        "prompt_tps",
        plot_left,
        plot_right,
        prefill_top + 18,
        row_h,
        220,
        55,
        lambda row: f'cold prefill {row["wall_seconds"] - (row["completion_tokens"] / row["eval_tps"]):.1f}s, full one-shot {row["wall_seconds"]:.1f}s',
    )
    parts.append(f'<text x="{(plot_left + plot_right) / 2:.1f}" y="{prefill_bottom + 48}" text-anchor="middle" font-family="{FONT}" font-size="13" fill="{MUTED}">prompt tokens per second</text>')

    footer_y = prefill_bottom + 82
    parts.append(f'<text x="42" y="{footer_y}" font-family="{FONT}" font-size="12" fill="{MUTED}">Long-context generation: Q4_K_M 18.37 tok/s, Q5_K_M 18.03 tok/s. Cold prefill: Q4_K_M 197.44 tok/s, Q5_K_M 202.92 tok/s.</text>')
    parts.append(f'<text x="42" y="{footer_y + 20}" font-family="{FONT}" font-size="12" fill="{MUTED}">Source: raw Ornith benchmark CSVs under results/ornith-1.0-35b-gguf/.</text>')
    parts.append("</svg>")

    SVG_PATH.write_text("\n".join(parts) + "\n", encoding="utf-8")


if __name__ == "__main__":
    render()
