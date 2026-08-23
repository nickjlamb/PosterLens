"""Generate docs/assets/architecture-{light,dark}.svg for the README.

Hand-tuned layout; run from the repo root after editing:
    python docs/gen_diagram.py
"""

import os

FONT = "-apple-system,'Segoe UI',Helvetica,Arial,sans-serif"

THEMES = {
    "light": dict(
        text="#1f2328", muted="#59636e", border="#d0d7de", panel="#f6f8fa",
        node="#ffffff", accent="#8250df", accent_soft="#fbf0ff",
        red="#cf222e",
        green="#1a7f37", green_fill="#dafbe1", green_border="#aceebb",
        edge="#8c959f",
    ),
    "dark": dict(
        text="#e6edf3", muted="#9198a1", border="#3d444d", panel="#151b23",
        node="#212830", accent="#ab7df8", accent_soft="#2a2139",
        red="#f85149",
        green="#3fb950", green_fill="#122117", green_border="#2b5233",
        edge="#767d86",
    ),
}

W, H = 960, 520


def build(c: dict) -> str:
    s = []
    s.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
        f'font-family="{FONT}" role="img" '
        'aria-label="PosterLens architecture: capture and OCR run on device and only '
        'extracted text leaves the phone; reasoning produces a structured summary, '
        'categories, questions and chat; evidence retrieval runs over a PubMed corpus '
        'and every citation is validated against PubMed E-utilities — failures are '
        'dropped; results land in a per-scan store with PDF export.">'
    )
    s.append(
        '<defs>'
        f'<marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
        f'markerHeight="7" orient="auto-start-reverse">'
        f'<path d="M0,0 L10,5 L0,10 z" fill="{c["edge"]}"/></marker>'
        f'<marker id="arr-red" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
        f'markerHeight="7" orient="auto-start-reverse">'
        f'<path d="M0,0 L10,5 L0,10 z" fill="{c["red"]}"/></marker>'
        f'<marker id="arr-green" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
        f'markerHeight="7" orient="auto-start-reverse">'
        f'<path d="M0,0 L10,5 L0,10 z" fill="{c["green"]}"/></marker>'
        '</defs>'
    )

    def panel(x, y, w, h, title):
        s.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" '
            f'fill="{c["panel"]}" stroke="{c["border"]}"/>'
        )
        s.append(
            f'<text x="{x + 18}" y="{y + 26}" font-size="11" font-weight="600" '
            f'letter-spacing="1.5" fill="{c["muted"]}">{title}</text>'
        )

    def node(cx, y, w, h, title, sub=None, fill=None, stroke=None, tcol=None):
        fill = fill or c["node"]
        stroke = stroke or c["border"]
        tcol = tcol or c["text"]
        x = cx - w / 2
        s.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" '
            f'fill="{fill}" stroke="{stroke}"/>'
        )
        if sub:
            s.append(
                f'<text x="{cx}" y="{y + 22}" font-size="13" font-weight="600" '
                f'text-anchor="middle" fill="{tcol}">{title}</text>'
            )
            s.append(
                f'<text x="{cx}" y="{y + 40}" font-size="11" '
                f'text-anchor="middle" fill="{c["muted"]}">{sub}</text>'
            )
        else:
            s.append(
                f'<text x="{cx}" y="{y + h / 2 + 4.5}" font-size="13" font-weight="600" '
                f'text-anchor="middle" fill="{tcol}">{title}</text>'
            )

    def elbow(points, marker="arr", color=None):
        color = color or c["edge"]
        pts = " ".join(f"{x},{y}" for x, y in points)
        s.append(
            f'<polyline points="{pts}" fill="none" stroke="{color}" '
            f'stroke-width="1.5" marker-end="url(#{marker})"/>'
        )

    # ---------------- on device ----------------
    panel(16, 52, 200, 448, "ON DEVICE")
    s.append(
        '<text x="34" y="482" font-size="11" font-style="italic" '
        f'fill="{c["muted"]}">the photo never leaves the phone</text>'
    )
    dcx = 116
    node(dcx, 120, 170, 52, "Camera capture", "edge detection &#183; stable frame")
    elbow([(dcx, 172), (dcx, 228)])
    node(dcx, 230, 170, 52, "Vision OCR", "on-device &#183; notation repair")

    # trunk out of OCR: extracted text only
    elbow([(201, 248), (252, 248), (252, 118), (317, 118)])          # -> reasoning
    s.append(
        f'<polyline points="201,264 252,264 252,422" fill="none" '
        f'stroke="{c["edge"]}" stroke-width="1.5"/>'
    )
    elbow([(252, 342), (289, 342)])                                   # -> RAG
    elbow([(252, 422), (289, 422)])                                   # -> Perplexity
    s.append(
        f'<text x="234" y="330" font-size="11" fill="{c["muted"]}" text-anchor="middle" '
        f'transform="rotate(-90 234 330)">extracted text &#8212; never the photo</text>'
    )

    # ---------------- reasoning ----------------
    panel(276, 52, 436, 200, "REASONING &#183; EXTRACTED TEXT ONLY")
    rcx = 494
    node(rcx, 92, 350, 52, "Structured summary",
         "GPT &#183; six fields &#183; endpoints verbatim only",
         fill=c["accent_soft"], stroke=c["accent"], tcol=c["accent"])
    elbow([(rcx, 144), (rcx, 168)])
    node(rcx, 170, 350, 52, "Categories &#183; questions &#183; chat",
         "all grounded in the captured text")

    # ---------------- evidence ----------------
    panel(276, 282, 436, 218, "EVIDENCE &#183; RETRIEVE, THEN VERIFY")
    node(391, 316, 200, 52, "evidence_v2 &#183; RAG",
         "embed &#183; vector search &#183; re-rank")
    node(391, 396, 200, 52, "Perplexity Search",
         "legacy path &#183; domain-filtered")
    vcx = 606
    node(vcx, 352, 188, 56, "PubMed check", "every citation validated",
         fill=c["green_fill"], stroke=c["green_border"], tcol=c["green"])
    elbow([(491, 342), (503, 342), (503, 368), (512, 368)])
    elbow([(491, 422), (503, 422), (503, 392), (512, 392)])
    # dropped branch
    elbow([(vcx, 408), (vcx, 436)], marker="arr-red", color=c["red"])
    s.append(
        f'<text x="{vcx - 16}" y="454" font-size="11" font-weight="600" text-anchor="middle" '
        f'fill="{c["red"]}">&#10005; fails validation &#8212; dropped, never shown</text>'
    )

    # ---------------- output ----------------
    panel(742, 52, 202, 448, "OUTPUT")
    ocx = 843
    node(ocx, 196, 170, 52, "Per-scan store", "iCloud &#183; local fallback")
    elbow([(ocx, 248), (ocx, 326)])
    node(ocx, 330, 140, 44, "PDF export")

    # context -> store
    elbow([(669, 196), (728, 196), (728, 214), (756, 214)])
    s.append(
        f'<text x="718" y="188" font-size="11" fill="{c["muted"]}" '
        f'text-anchor="end">summary + context</text>'
    )
    # verified citations -> store
    elbow([(700, 372), (716, 372), (716, 232), (756, 232)],
          marker="arr-green", color=c["green"])
    s.append(
        f'<text x="702" y="302" font-size="11" font-weight="600" fill="{c["green"]}" '
        f'text-anchor="middle" transform="rotate(-90 702 302)">verified citations only</text>'
    )

    s.append("</svg>")
    return "\n".join(s)


os.makedirs("docs/assets", exist_ok=True)
for name, palette in THEMES.items():
    path = f"docs/assets/architecture-{name}.svg"
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(build(palette))
    print("wrote", path)
