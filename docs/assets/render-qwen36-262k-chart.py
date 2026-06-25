import csv
import html
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CSV_PATH = ROOT / "qwen36-262k-tok-s.csv"
SVG_PATH = ROOT / "qwen36-262k-tok-s.svg"

FONT = "Inter, Segoe UI, Arial, sans-serif"
BG = "#fbfcfd"
CARD = "#ffffff"
BORDER = "#e5ebf0"
TEXT = "#17202a"
MUTED = "#5e6b78"
GRID = "#d8e0e8"
STRIPE = "#f7f9fb"
EVAL = "#2468c9"
WALL = "#c76b22"


def esc(value):
    return html.escape(str(value), quote=True)


def short_label(label):
    if label.startswith("Ornith 1.0 35B Q4_K_M 174.6K prompt"):
        return "Ornith Q4_K_M - 174.6K prompt"
    if label.startswith("Ornith 1.0 35B Q5_K_M 174.6K prompt"):
        return "Ornith Q5_K_M - 174.6K prompt"

    replacements = {
        "UD-Q4_K_XL draft-mtp ": "UD-Q4_K_XL - ",
        "UD-Q4_K_XL Studio-like baseline": "UD-Q4_K_XL - Studio-like baseline",
        "MXFP4_MOE draft-mtp ": "MXFP4_MOE - ",
        "MXFP4_MOE no MTP, ": "MXFP4_MOE - no MTP ",
        "Ornith 1.0 35B Q4_K_M no MTP, ": "Ornith Q4_K_M - no MTP ",
        "Ornith 1.0 35B Q5_K_M no MTP, ": "Ornith Q5_K_M - no MTP ",
        ", ": " ",
    }
    out = label
    for old, new in replacements.items():
        out = out.replace(old, new)
    return out


def read_rows():
    with CSV_PATH.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    for row in rows:
        row["completion_tokens"] = int(row["completion_tokens"])
        row["eval_tps"] = float(row["eval_tps"])
        row["wall_tps"] = float(row["wall_tps"])
    return rows


def render():
    rows = read_rows()
    width = 1180
    row_h = 66
    top = 136
    plot_left = 390
    plot_right = 1060
    axis_bottom = top + row_h * len(rows) + 15
    height = axis_bottom + 120
    card_h = height - 40
    max_tick = int(math.ceil(max(max(r["eval_tps"], r["wall_tps"]) for r in rows) / 10.0) * 10)
    max_tick = max(60, max_tick)
    scale = (plot_right - plot_left) / max_tick

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">',
        '<title id="title">Ryzen AI Max+ 395 262K throughput comparison</title>',
        '<desc id="desc">Horizontal grouped bar chart comparing model generation speed and full request speed for selected local GGUF benchmark profiles on Ryzen AI Max+ 395 at 262K context.</desc>',
        f'<rect width="{width}" height="{height}" fill="{BG}"/>',
        f'<rect x="20" y="20" width="{width - 40}" height="{card_h}" rx="8" fill="{CARD}" stroke="{BORDER}"/>',
        f'<text x="42" y="62" font-family="{FONT}" font-size="30" font-weight="700" fill="{TEXT}">Ryzen AI Max+ 395 262K tok/s comparison</text>',
        f'<text x="42" y="91" font-family="{FONT}" font-size="15" fill="{MUTED}">Radeon 8060S, Windows HIP/ROCm, single-slot llama.cpp runs</text>',
        f'<text x="42" y="116" font-family="{FONT}" font-size="13" fill="{MUTED}">Curated from source-of-truth profile rows. Completion and prompt lengths vary, so treat this as a profile ranking rather than a fully controlled sweep.</text>',
        f'<rect x="855" y="53" width="14" height="14" rx="2" fill="{EVAL}"/>',
        f'<text x="877" y="65" font-family="{FONT}" font-size="14" fill="{TEXT}">generation only (eval)</text>',
        f'<rect x="855" y="78" width="14" height="14" rx="2" fill="{WALL}"/>',
        f'<text x="877" y="90" font-family="{FONT}" font-size="14" fill="{TEXT}">full request (wall)</text>',
    ]

    for tick in range(0, max_tick + 1, 10):
        x = plot_left + tick * scale
        parts.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{axis_bottom}" stroke="{GRID}" stroke-width="1"/>')
        parts.append(f'<text x="{x:.1f}" y="{axis_bottom + 22}" text-anchor="middle" font-family="{FONT}" font-size="12" fill="{MUTED}">{tick}</text>')

    parts.append(f'<text x="{(plot_left + plot_right) / 2:.1f}" y="{axis_bottom + 48}" text-anchor="middle" font-family="{FONT}" font-size="13" fill="{MUTED}">tokens per second</text>')

    for i, row in enumerate(rows):
        y = top + i * row_h
        if i % 2 == 0:
            parts.append(f'<rect x="35" y="{y - 8}" width="1092" height="58" rx="6" fill="{STRIPE}"/>')

        label = short_label(row["label"])
        sub = f'{row["completion_tokens"]} generated tokens - {row["case"]}'
        parts.append(f'<text x="42" y="{y + 26}" font-family="{FONT}" font-size="15" font-weight="650" fill="{TEXT}">{esc(label)}</text>')
        parts.append(f'<text x="42" y="{y + 47}" font-family="{FONT}" font-size="12" fill="{MUTED}">{esc(sub)}</text>')

        if "recommended" in row["note"].lower():
            parts.append('<rect x="266" y="{0}" width="95" height="20" rx="4" fill="#e6f5ef" stroke="#a9d8ca"/>'.format(y + 8))
            parts.append(f'<text x="313.5" y="{y + 22}" text-anchor="middle" font-family="{FONT}" font-size="11" font-weight="650" fill="#12715b">recommended</text>')

        eval_w = row["eval_tps"] * scale
        wall_w = row["wall_tps"] * scale
        parts.append(f'<rect x="{plot_left}" y="{y + 9}" width="{eval_w:.1f}" height="14" rx="3" fill="{EVAL}"/>')
        parts.append(f'<rect x="{plot_left}" y="{y + 29}" width="{wall_w:.1f}" height="14" rx="3" fill="{WALL}"/>')
        parts.append(f'<text x="{plot_left + eval_w + 8:.1f}" y="{y + 20}" font-family="{FONT}" font-size="12" font-weight="650" fill="{TEXT}">{row["eval_tps"]:.2f}</text>')
        parts.append(f'<text x="{plot_left + wall_w + 8:.1f}" y="{y + 40}" font-family="{FONT}" font-size="12" font-weight="650" fill="{TEXT}">{row["wall_tps"]:.2f}</text>')

    footer_y = height - 54
    parts.append(f'<text x="42" y="{footer_y}" font-family="{FONT}" font-size="12" fill="{MUTED}">Source: raw benchmark CSVs under results/ and model summaries under docs/models/.</text>')
    parts.append(f'<text x="42" y="{footer_y + 20}" font-family="{FONT}" font-size="12" fill="{MUTED}">Eval is model token generation only; wall is the full request time and is closer to what users feel.</text>')
    parts.append("</svg>")

    SVG_PATH.write_text("\n".join(parts) + "\n", encoding="utf-8")


if __name__ == "__main__":
    render()
