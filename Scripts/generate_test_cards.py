#!/usr/bin/env python3
"""Generate the synthetic business-card benchmark corpus.

Why this exists
---------------
The assignment expects a teacher-provided set of 30-50 business cards with a
Ground Truth file.  None was provided, so this repo ships its own corpus with
two hard requirements:

  1. 100% synthetic and non-identifying (reserved domains `.example`, phone
     numbers in the 0000xxxx range, invented companies/people).
  2. Deterministic: same script + same seed => byte-identical images, so the
     OCR benchmark numbers in `docs/reports/ocr-accuracy.md` are reproducible.

Output
------
  TestData/cards/*.png              50 clean renders + 12 "photo" variants
  TestData/ground-truth/ground_truth.json
  TestData/ground-truth/manifest.csv

Usage
-----
  python3 Scripts/generate_test_cards.py            # full corpus
  python3 Scripts/generate_test_cards.py --clean    # wipes output first
  python3 Scripts/generate_test_cards.py --preview  # 4 sample cards only
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import random
import shutil
from dataclasses import dataclass, field, asdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CARDS_DIR = ROOT / "TestData" / "cards"
GT_DIR = ROOT / "TestData" / "ground-truth"

# CR80 business card at 300 dpi => 85.6 x 53.98 mm
CARD_W, CARD_H = 1012, 638
VERT_W, VERT_H = 638, 1012

FONT_CANDIDATES = [
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
]
FONT_SANS = ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]
FONT_SERIF = [
    "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
    "/System/Library/Fonts/Supplemental/Georgia.ttf",
]
FONT_MONO = ["/System/Library/Fonts/Supplemental/Courier New.ttf"]

THEMES = {
    # name: (paper, ink, muted, accent)
    "ivory": ("#FBF8F1", "#1C1C1E", "#5C5C66", "#0B5FFF"),
    "white": ("#FFFFFF", "#111111", "#6B6B6B", "#C0392B"),
    "navy": ("#0E1B2C", "#F5F7FA", "#A9B4C2", "#4DA3FF"),
    "charcoal": ("#1F1F22", "#F2F2F2", "#9A9A9A", "#E8B23A"),
    "mint": ("#F2F7F2", "#16321E", "#4B6B52", "#2E7D32"),
    "blueprint": ("#EAF2FB", "#0A2540", "#4A6785", "#1E88E5"),
}

LATIN_NAME_SETS = [
    # (name, company, title, dept)
    ("David Chen", "ABC Technologies", "Technical Director", "Platform Engineering"),
    ("Emily Zhang", "Northwind Analytics", "Senior Data Scientist", "AI Lab"),
    ("Michael O'Brian", "Bright Harbor Logistics", "VP Sales", "Global Accounts"),
    ("Sarah Kim", "Lumen Health Systems", "Product Manager", "Clinical Products"),
    ("Robert Fischer", "Kestrel Robotics GmbH", "Chief Engineer", "Motion Control"),
    ("Laura Mendosa", "Sierra Legal Partners", "Partner", "Intellectual Property"),
    ("Thomas Weber", "Rhine Valley Chemicals", "Head of Procurement", "Supply Chain"),
    ("Grace Lin", "Atlas Capital Group", "Investment Analyst", "Growth Equity"),
    ("James Okafor", "Vertex Construction Ltd.", "Site Manager", "Project Delivery"),
    ("Anna Petrova", "Aurora Design Studio", "Creative Lead", "Brand Design"),
    ("Kevin Wu", "Pacific Freight Co.", "Operations Manager", "Ocean Freight"),
    ("Rachel Adler", "Meridian Education Group", "Academic Director", "Curriculum"),
    ("Daniel Ito", "Skyline Semiconductors", "Staff Engineer", "Analog Design"),
    ("Olivia Brown", "Cedar & Finch", "Founder", ""),
    ("Hassan Al-Rashid", "Gulf Horizon Energy", "Business Development", "Middle East"),
]

CN_NAME_SETS = [
    ("朱宏明", "同济大学", "教授", "计算机科学与技术学院"),
    ("李静", "华远科技股份有限公司", "技术总监", "研发中心"),
    ("王建国", "东方物流集团", "副总经理", "运营管理部"),
    ("陈雨欣", "明德咨询有限公司", "高级顾问", "战略咨询"),
    ("张伟", "长安精密制造有限公司", "总经理", ""),
    ("刘晓峰", "海通律师事务所", "合伙人", "知识产权"),
    ("赵敏", "康宁医疗器械有限公司", "市场经理", "市场部"),
    ("孙立", "北方电力设计院", "主任工程师", "输电线路室"),
    ("周婷", "青禾文化传媒", "创意总监", ""),
    ("吴强", "南山置业发展有限公司", "项目经理", "工程部"),
    ("郑丽华", "星河银行", "客户经理", "对公业务部"),
    ("何俊", "云图数据科技有限公司", "算法工程师", "数据平台"),
    ("马晓东", "远航国际贸易有限公司", "外贸经理", "进出口部"),
    ("林芳", "华夏中医药研究院", "研究员", "药理研究室"),
    ("高鹏", "蓝天航空服务有限公司", "运营总监", ""),
]

BILINGUAL_SETS = [
    ("朱宏明 Zhu Hongming", "同济大学 Tongji University", "教授 Professor", "计算机学院 School of CS"),
    ("李静 Li Jing", "华远科技 Huayuan Tech", "技术总监 CTO", "研发中心 R&D Center"),
    ("David Chen 陈大卫", "ABC Technologies 艾博西科技", "Director 总监", "Platform 平台部"),
    ("王建国 Wang Jianguo", "东方物流 Orient Logistics", "副总经理 VP", "Operations 运营"),
    ("Emily Zhang 张艾米", "Northwind Analytics 北风数据", "Data Scientist 数据科学家", ""),
    ("陈雨欣 Chen Yuxin", "Mingde Consulting 明德咨询", "Senior Consultant 高级顾问", ""),
    ("Thomas Weber 托马斯", "Rhine Valley 莱茵化工", "Head of Procurement 采购总监", ""),
    ("赵敏 Zhao Min", "Conning Medical 康宁医疗", "Marketing Manager 市场经理", ""),
    ("Grace Lin 林格蕾", "Atlas Capital 阿特拉斯资本", "Analyst 分析师", ""),
    ("孙立 Sun Li", "北方电力 North Power Design", "主任工程师 Chief Engineer", ""),
]

DOMAINS = ["example.com", "example.org", "example.net", "mail.example.com"]


@dataclass
class Phone:
    kind: str  # mobile | office | fax
    number: str


@dataclass
class CardSpec:
    cid: str
    lang: str
    layout: str
    theme: str
    fields: dict
    logo: str = "none"  # none | block | circle | monogram
    photo_variant: bool = False
    labels: bool = True
    occlusion: bool = False
    notes: str = ""

    @property
    def filename(self) -> str:
        return f"{self.cid}.png"


def resolve_font(spec: CardSpec) -> str:
    """Choose a real family deterministically; this is not a fallback list."""
    latin = [FONT_SANS[0], FONT_SERIF[0], FONT_MONO[0]]
    cjk = [FONT_CANDIDATES[0], FONT_CANDIDATES[1], "/System/Library/Fonts/Supplemental/Songti.ttc"]
    families = latin if spec.lang == "en" else cjk
    index = (int(spec.cid.split("-")[-1]) - 1) % len(families)
    selected = families[index]
    if not Path(selected).is_file():
        raise FileNotFoundError(f"Corpus font is required for reproducibility: {selected}")
    return selected


def pick_font(paths: list[str], size: int) -> ImageFont.FreeTypeFont:
    for p in paths:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                continue
    return ImageFont.load_default(size)


def hex2rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def make_contact_lines(spec: CardSpec) -> list[tuple[str, str]]:
    """Return [(label, text)] for the contact block, in canonical order.

    `text` already carries the label when the card is a labelled one; the
    unlabelled variant exists to keep the corpus realistic and to stop the
    parser from relying on labels alone.
    """
    f = spec.fields
    out: list[tuple[str, str]] = []
    for p in f.get("phones", []):
        label = {"mobile": "Mobile", "office": "Tel", "fax": "Fax"}[p["kind"]]
        if spec.lang == "zh":
            label = {"mobile": "手机", "office": "电话", "fax": "传真"}[p["kind"]]
        elif spec.lang == "bilingual":
            label = {"mobile": "Mobile", "office": "Tel", "fax": "Fax"}[p["kind"]]
        out.append((label, p["number"]))
    for e in f.get("emails", []):
        out.append(("Email", e))
    if f.get("website"):
        out.append(("Web", f["website"]))
    if f.get("address"):
        out.append(("Add", f["address"]))
    if not spec.labels:
        return [(label, text) for label, text in out]
    return [(label, f"{label}: {text}") for label, text in out]


def draw_logo(draw: ImageDraw.ImageDraw, style: str, box: tuple[int, int, int, int], accent: str) -> None:
    x0, y0, x1, y1 = box
    if style == "block":
        draw.rounded_rectangle(box, radius=8, fill=accent)
        inner = (x0 + 12, y0 + 12, x1 - 12, y1 - 12)
        draw.rounded_rectangle(inner, radius=4, fill="#FFFFFF")
    elif style == "circle":
        draw.ellipse(box, fill=accent)
        r = (x1 - x0) // 4
        draw.ellipse((x0 + r, y0 + r, x1 - r, y1 - r), fill="#FFFFFF")
    elif style == "monogram":
        draw.rounded_rectangle(box, radius=6, outline=accent, width=4)
        draw.line((x0, y0, x1, y1), fill=accent, width=4)
        draw.line((x1, y0, x0, y1), fill=accent, width=6)


def render_card(spec: CardSpec, rng: random.Random) -> Image.Image:
    """Backwards-compatible wrapper: callers that do not need the text box."""
    image, _ = render_card_with_meta(spec, rng)
    return image


def render_card_with_meta(spec: CardSpec, rng: random.Random) -> tuple[Image.Image, tuple[int, int, int, int] | None]:
    paper, ink, muted, accent = (hex2rgb(c) for c in THEMES[spec.theme])
    vertical = spec.layout == "vertical"
    W, H = (VERT_W, VERT_H) if vertical else (CARD_W, CARD_H)
    img = Image.new("RGB", (W, H), paper)
    draw = ImageDraw.Draw(img)

    # paper texture: very light noise, keeps OCR honest but not hostile
    arr = np.array(img).astype(np.int16)
    # `hash()` is salted per process, which silently made every regeneration
    # differ. A digest keeps the paper grain identical across runs and machines.
    grain_seed = int(hashlib.sha256(spec.cid.encode()).hexdigest()[:8], 16)
    noise = np.random.default_rng(grain_seed).integers(-3, 4, arr.shape[:2])[:, :, None]
    arr = np.clip(arr + noise, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    f = spec.fields
    m = 56 if not vertical else 48
    y = 58 if not vertical else 64

    f_name = pick_font([resolve_font(spec)], 46 if not vertical else 40)
    f_title = pick_font([resolve_font(spec)], 24)
    f_company = pick_font([resolve_font(spec)], 28 if not vertical else 24)
    f_body = pick_font([resolve_font(spec)], 19)
    f_small = pick_font([resolve_font(spec)], 16)

    align_center = spec.layout == "centered"
    cx = W // 2

    def put(text: str, font, fill, xy, anchor=None):
        draw.text(xy, text, font=font, fill=fill, anchor=anchor)

    # accent bar -- drawn on the paper, not on the text layer, so it does not
    # distort the vertical-centring bounding box
    if spec.layout in ("classic", "vertical"):
        ImageDraw.Draw(img).rectangle((0, 0, 10, H), fill=accent)

    logo_w = 0
    if spec.logo != "none":
        size = 96 if not vertical else 88
        if align_center:
            lx = cx - size // 2
            ly = y
            draw_logo(draw, spec.logo, (lx, ly, lx + size, ly + size), accent)
            y = ly + size + 24
        else:
            lx = W - m - size
            ly = y - 10
            draw_logo(draw, spec.logo, (lx, ly, lx + size, ly + size), accent)
            logo_w = size + 24

    if align_center:
        put(f["name"], f_name, ink, (cx, y), "ma")
        y += 58
        if f.get("jobTitle"):
            put(f["jobTitle"], f_title, muted, (cx, y), "ma")
            y += 34
        if f.get("company"):
            put(f["company"], f_company, accent if spec.theme in ("white", "ivory", "mint", "blueprint") else ink, (cx, y), "ma")
            y += 38
        if f.get("department"):
            put(f["department"], f_small, muted, (cx, y), "ma")
            y += 26
        y += 14
        draw.line((m + 40, y, W - m - 40, y), fill=muted, width=1)
        y += 22
        for _, text in make_contact_lines(spec):
            put(text, f_body, ink, (cx, y), "ma")
            y += 28
    else:
        put(f["name"], f_name, ink, (m, y))
        y += 56
        if f.get("jobTitle"):
            put(f["jobTitle"], f_title, muted, (m, y))
            y += 32
        if f.get("company"):
            put(f["company"], f_company, ink, (m, y))
            y += 34
        if f.get("department"):
            put(f["department"], f_small, muted, (m, y))
            y += 24
        y += 8
        draw.line((m, y, W - m, y), fill=muted, width=1)
        y += 18
        for label, text in make_contact_lines(spec):
            if spec.layout == "two-column" and y < H - 120:
                put(f"{label}:", f_small, muted, (m, y))
                put(text, f_body, ink, (m + 74, y - 2))
            else:
                put(text, f_body, ink, (m, y))
            y += 27

    # footer chip / page number-ish detail for realism
    if spec.layout == "two-column":
        deco = ImageDraw.Draw(img)
        deco.rectangle((W - m - 150, H - m - 26, W - m, H - m), outline=accent, width=2)
        deco.text((W - m - 75, H - m - 13), spec.lang.upper(), font=f_small, fill=accent, anchor="mm")

    # vertical centring: shift the whole text block so cards do not look top-heavy
    bbox = layer.getbbox()
    if bbox:
        content_h = bbox[3] - bbox[1]
        target_top = max(m, (H - content_h) // 2)
        dy = target_top - bbox[1]
        if dy:
            shifted = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            shifted.paste(layer, (0, dy))
            layer = shifted
    img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    return img, (bbox if bbox else None)


# ---------------------------------------------------------------- occlusion


SKIN = (232, 190, 160)
SKIN_SHADOW = (198, 152, 122)
NAIL = (242, 214, 196)


def make_finger(width: int, height: int, rng: random.Random) -> Image.Image:
    """A finger-like capsule with a soft edge and a nail highlight."""
    w, h = max(width, 24), max(height, 24)
    finger = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(finger)
    radius = min(w, h) // 2
    draw.rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=SKIN + (255,))
    # shading along one edge so it reads as a 3D object, not a sticker
    draw.rounded_rectangle((0, 0, w - 1, h // 3), radius=radius, fill=SKIN_SHADOW + (70,))
    nail_w, nail_h = int(w * 0.44), int(h * 0.34)
    nx = (w - nail_w) // 2
    ny = int(h * 0.16)
    draw.ellipse((nx, ny, nx + nail_w, ny + nail_h), fill=NAIL + (220,))
    return finger.filter(ImageFilter.GaussianBlur(1.6))


def overlaps(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> bool:
    return not (a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1])


def apply_occlusion(
    card: Image.Image,
    text_bbox: tuple[int, int, int, int] | None,
    rng: random.Random,
) -> tuple[Image.Image, dict] | None:
    """Cover one corner with a finger hanging over the card edge.

    The occluder is only allowed over the card's margin: covering printed text
    would make the Ground Truth wrong, and "the text is hidden" is a different
    test than "the card outline is interrupted".
    """
    W, H = card.size
    if text_bbox is None:
        return None
    out = card.convert("RGBA")
    corners = ["top-right", "bottom-right", "bottom-left", "top-left"]
    rng.shuffle(corners)

    for corner in corners:
        for scale in (1.0, 0.8, 0.62):
            fw = int(W * 0.30 * scale)
            fh = int(H * 0.26 * scale)
            # most of the finger sits outside the card, like a thumb holding it
            if corner.endswith("right"):
                x0 = W - int(fw * 0.55)
            else:
                x0 = -int(fw * 0.45)
            if corner.startswith("bottom"):
                y0 = H - int(fh * 0.60)
            else:
                y0 = -int(fh * 0.40)

            rect = (x0, y0, x0 + fw, y0 + fh)
            if overlaps(rect, text_bbox):
                continue

            finger = make_finger(fw, fh, rng)
            if corner.startswith("top"):
                finger = finger.transpose(Image.FLIP_TOP_BOTTOM)

            shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            ImageDraw.Draw(shadow).rounded_rectangle(
                (x0 + 10, y0 + 16, x0 + fw + 10, y0 + fh + 16),
                radius=min(fw, fh) // 2,
                fill=(0, 0, 0, 90),
            )
            out = Image.alpha_composite(out, shadow.filter(ImageFilter.GaussianBlur(12)))
            out.alpha_composite(finger, dest=(x0, y0))

            visible = (
                max(0, min(rect[2], W) - max(rect[0], 0))
                * max(0, min(rect[3], H) - max(rect[1], 0))
            )
            coverage = visible / float(W * H)
            return out.convert("RGB"), {
                "corner": corner,
                "scale": round(scale, 2),
                "coverage": round(coverage, 3),
            }
    return None


# ---------------------------------------------------------------- photo variant


def find_coeffs(pa, pb):
    """Perspective coefficients mapping output quad pa -> input quad pb."""
    matrix = []
    for p1, p2 in zip(pa, pb):
        matrix.append([p1[0], p1[1], 1, 0, 0, 0, -p2[0] * p1[0], -p2[0] * p1[1]])
        matrix.append([0, 0, 0, p1[0], p1[1], 1, -p2[1] * p1[0], -p2[1] * p1[1]])
    A = np.matrix(matrix, dtype=float)
    B = np.array(pb).reshape(8)
    res = np.dot(np.linalg.inv(A.T * A) * A.T, B)
    return np.array(res).reshape(8)


def make_background(w: int, h: int, rng: random.Random, kind: str) -> Image.Image:
    styles = {
        "desk": ("#6B4F3A", "#8A6A4C", "#5A4030"),
        "table": ("#3A3A3C", "#4A4A4E", "#2C2C2E"),
        "dark": ("#121212", "#1E1E20", "#0A0A0A"),
        "paper": ("#D8D2C4", "#E4DED2", "#C8C2B4"),
        "blue": ("#1B2A41", "#243B5A", "#16233A"),
    }
    c1, c2, c3 = (hex2rgb(c) for c in styles[kind])
    base = Image.new("RGB", (w, h), c1)
    d = ImageDraw.Draw(base)
    for i in range(0, h, 4):
        t = i / h
        col = tuple(int(c1[k] + (c2[k] - c1[k]) * t) for k in range(3))
        d.line((0, i, w, i), fill=col)
    # wood-ish streaks or clutter
    for _ in range(rng.randint(18, 40)):
        x0 = rng.randint(-w // 4, w)
        y0 = rng.randint(-h // 4, h)
        d.line(
            (x0, y0, x0 + rng.randint(80, w), y0 + rng.randint(-40, 40)),
            fill=c3,
            width=rng.randint(1, 6),
        )
    base = base.filter(ImageFilter.GaussianBlur(2))
    return base


def render_photo(
    spec: CardSpec, card: Image.Image, rng: random.Random
) -> tuple[Image.Image, list[tuple[float, float]]]:
    """Simulate a handheld phone shot: perspective, shadow, clutter, exposure."""
    pw, ph = 2000, 1500
    # upscale the flat render so the card stays legible after the warp
    card = card.resize((card.width * 2, card.height * 2), Image.LANCZOS)
    bg_kind = rng.choice(["desk", "table", "dark", "paper", "blue"])
    bg = make_background(pw, ph, rng, bg_kind)

    cw, ch = card.size
    scale = rng.uniform(0.52, 0.60)
    tw, th = int(cw * scale), int(ch * scale)

    margin = 90
    jitter = lambda v: rng.uniform(-v, v)
    # destination quad inside the photo
    left = rng.randint(margin, pw // 2 - tw // 2)
    top = rng.randint(margin, ph // 2 - th // 2)
    quad = [
        (left + jitter(22), top + jitter(22)),
        (left + tw + jitter(22), top + jitter(22)),
        (left + tw + jitter(22), top + th + jitter(22)),
        (left + jitter(22), top + th + jitter(22)),
    ]
    # mild rotation
    deg = rng.uniform(-6, 6)
    if abs(deg) > 0.5:
        cx0 = left + tw / 2
        cy0 = top + th / 2
        r = math.radians(deg)
        rot = []
        for x, y in quad:
            dx, dy = x - cx0, y - cy0
            rot.append((cx0 + dx * math.cos(r) - dy * math.sin(r), cy0 + dx * math.sin(r) + dy * math.cos(r)))
        quad = rot

    # shadow
    shadow = Image.new("L", (pw, ph), 0)
    sd = ImageDraw.Draw(shadow)
    off = 16
    sd.polygon([(x + off, y + off + 22) for x, y in quad], fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    bg = Image.composite(Image.new("RGB", (pw, ph), (18, 18, 20)), bg, shadow)

    src = [(0, 0), (cw, 0), (cw, ch), (0, ch)]
    coeffs = find_coeffs(quad, src)
    warped = card.convert("RGB").transform(
        (pw, ph), Image.PERSPECTIVE, coeffs, resample=Image.BICUBIC
    )
    mask = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(mask).polygon(quad, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.2))  # soften the cut-out edge
    out = Image.composite(warped, bg, mask)

    # exposure / white balance / noise / focus
    out = Image.eval(out, lambda v: min(255, max(0, int(v * rng.uniform(0.88, 1.06) + rng.uniform(-6, 8)))))
    if rng.random() < 0.35:
        out = out.filter(ImageFilter.GaussianBlur(rng.uniform(0.3, 0.9)))
    arr = np.array(out).astype(np.int16)
    arr = np.clip(arr + np.random.default_rng(rng.randint(0, 9999)).normal(0, 3.2, arr.shape), 0, 255).astype(np.uint8)
    out = Image.fromarray(arr)
    return out, quad


def apply_photo_occlusion(
    photo: Image.Image,
    quad: list[tuple[float, float]],
    rng: random.Random,
) -> tuple[Image.Image, dict]:
    """A finger pressing on one corner of the card, in photo space.

    This is the case that actually stresses `VisionCardDetector`: the card's
    outline is interrupted, so the rectangle has one corner missing.
    """
    W, H = photo.size
    corner_index = rng.choice([1, 2])  # top-right or bottom-right of the card
    corner = quad[corner_index]
    # size the finger relative to the card, not to the photo
    card_width = max(abs(quad[1][0] - quad[0][0]), abs(quad[2][0] - quad[3][0]), 1)
    fw = int(card_width * 0.22)
    fh = int(fw * 1.35)

    finger = make_finger(fw, fh, rng)
    angle = rng.uniform(-35, 35)
    finger = finger.rotate(angle, expand=True, resample=Image.BICUBIC)
    # anchor so roughly 30% of the finger overlaps the card's corner
    x0 = int(corner[0] - fw * 0.55)
    y0 = int(corner[1] - fh * 0.35)

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x0 + 14, y0 + 18, x0 + finger.width + 14, y0 + finger.height + 18),
        radius=min(finger.width, finger.height) // 2,
        fill=(0, 0, 0, 110),
    )
    out = Image.alpha_composite(photo.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(18)))
    out.alpha_composite(finger, dest=(x0, y0))
    return out.convert("RGB"), {
        "corner": "top-right" if corner_index == 1 else "bottom-right",
        "angle": round(angle, 1),
        "space": "photo",
    }


# ---------------------------------------------------------------- corpus


def phone(kind: str, number: str) -> dict:
    return {"kind": kind, "number": number}


CN_MOBILES = [
    "+86 138 0000 1234", "+86 139 0000 5678", "+86 137 0000 9012", "+86 150 0000 3344",
    "+86 186 0000 7788", "+86 188 0000 2211", "+86 133 0000 4455", "+86 159 0000 6677",
]
CN_OFFICES = [
    "021-6000 1234", "010-8000 5678", "0755-2000 9012", "0571-3000 3456",
    "028-4000 7890", "025-5000 2345",
]
CN_FAXES = ["021-6000 1235", "010-8000 5679", "0755-2000 9013"]
INTL_MOBILES = [
    "+1 415 000 1234", "+1 212 000 5678", "+44 20 0000 9012", "+49 30 0000 3456",
    "+81 3 0000 7890", "+65 0000 2345",
]
INTL_OFFICES = ["+1 415 000 8000", "+44 20 0000 7000", "+49 30 0000 6000", "+65 0000 5000"]
INTL_FAXES = ["+1 415 000 8001", "+44 20 0000 7001", "+49 30 0000 6001"]

ADDRESSES_CN = [
    "上海市杨浦区四平路1239号 200092",
    "北京市海淀区中关村大街1号 100080",
    "深圳市南山区科技园南路18号 518057",
    "杭州市西湖区文三路90号 310012",
    "成都市高新区天府大道中段1号 610041",
]
ADDRESSES_EN = [
    "500 Market Street, Suite 900, San Francisco, CA 94105",
    "12 King William Street, London EC4N 7BJ",
    "Friedrichstrasse 88, 10117 Berlin, Germany",
    "1 Raffles Place, #20-01, Singapore 048616",
]


def build_corpus() -> list[CardSpec]:
    rng = random.Random(20261027)
    specs: list[CardSpec] = []

    OCCLUDED = {"zh-01", "zh-05", "zh-09", "zh-12", "en-02", "en-06", "en-11", "bi-03", "bi-08", "bi-14"}

    def add(cid, lang, layout, theme, fields, logo="none", photo=False, notes="", labels=True):
        specs.append(CardSpec(
            cid=cid, lang=lang, layout=layout, theme=theme, fields=fields,
            logo=logo, photo_variant=photo, labels=labels, notes=notes,
            occlusion=cid in OCCLUDED,
        ))

    # ---- Chinese cards (15)
    for i, (name, company, title, dept) in enumerate(CN_NAME_SETS):
        layout = ["classic", "centered", "two-column", "vertical", "minimal"][i % 5]
        phones = [phone("mobile", CN_MOBILES[i % len(CN_MOBILES)])]
        if i % 3 == 0:
            phones.append(phone("office", CN_OFFICES[i % len(CN_OFFICES)]))
        if i % 5 == 0:
            phones.append(phone("fax", CN_FAXES[i % len(CN_FAXES)]))
        f = {
            "name": name,
            "company": company,
            "jobTitle": title,
            "department": dept,
            "phones": phones,
            "emails": [f"contact{i + 1:02d}@example.com"],
            "website": f"www.example{i + 1:02d}.com" if i % 4 != 3 else None,
            "address": ADDRESSES_CN[i % len(ADDRESSES_CN)] if i % 3 != 2 else None,
        }
        add(f"zh-{i + 1:02d}", "zh", layout, list(THEMES)[i % len(THEMES)], f,
            logo=["none", "block", "circle", "monogram"][i % 4],
            labels=(i % 3 != 2),
            photo=(i % 4 == 0),
            notes="中文名片" + ("，双电话" if len(phones) > 1 else "") + ("，缺网站" if not f["website"] else ""))

    # ---- English cards (15)
    for i, (name, company, title, dept) in enumerate(LATIN_NAME_SETS):
        layout = ["classic", "centered", "two-column", "minimal", "classic"][i % 5]
        phones = [phone("mobile", INTL_MOBILES[i % len(INTL_MOBILES)])]
        if i % 2 == 0:
            phones.append(phone("office", INTL_OFFICES[i % len(INTL_OFFICES)]))
        if i % 4 == 1:
            phones.append(phone("fax", INTL_FAXES[i % len(INTL_FAXES)]))
        emails = [f"{name.split()[0].lower()}.{name.split()[-1].lower().replace(chr(39), '')}@example.org"]
        if i % 6 == 0:
            emails.append(f"info@example.org")
        f = {
            "name": name,
            "company": company,
            "jobTitle": title,
            "department": dept,
            "phones": phones,
            "emails": emails,
            "website": f"www.{company.split()[0].lower().replace('&', 'and')}.example" if i % 3 != 1 else None,
            "address": ADDRESSES_EN[i % len(ADDRESSES_EN)] if i % 4 != 3 else None,
        }
        add(f"en-{i + 1:02d}", "en", layout, list(THEMES)[(i + 2) % len(THEMES)], f,
            logo=["none", "circle", "block", "none"][i % 4],
            labels=(i % 4 != 1),
            photo=(i % 5 == 2),
            notes="英文名片" + ("，多 Email" if len(emails) > 1 else ""))

    # ---- Bilingual cards (20)
    for i in range(20):
        src = BILINGUAL_SETS[i % len(BILINGUAL_SETS)]
        name, company, title, dept = src
        layout = ["classic", "centered", "two-column", "vertical"][i % 4]
        phones = [phone("mobile", CN_MOBILES[i % len(CN_MOBILES)])]
        if i % 2 == 0:
            phones.append(phone("office", CN_OFFICES[(i + 2) % len(CN_OFFICES)]))
        if i % 5 == 1:
            phones.append(phone("fax", CN_FAXES[i % len(CN_FAXES)]))
        emails = [f"biz{i + 1:02d}@example.com"]
        if i % 7 == 3:
            emails.append(f"sales{i + 1:02d}@example.net")
        f = {
            "name": name,
            "company": company,
            "jobTitle": title,
            "department": dept,
            "phones": phones,
            "emails": emails,
            "website": f"www.example{i + 1:02d}.com" if i % 3 != 0 else None,
            "address": ADDRESSES_CN[i % len(ADDRESSES_CN)] if i % 4 != 2 else None,
        }
        add(f"bi-{i + 1:02d}", "bilingual", layout, list(THEMES)[(i + 4) % len(THEMES)], f,
            logo=["block", "monogram", "circle", "none"][i % 4],
            labels=(i % 5 != 4),
            photo=(i % 4 == 1),
            notes="中英双语名片")

    return specs


def ground_truth_entry(
    spec: CardSpec,
    file: str,
    kind: str,
    occlusion: dict | None = None,
) -> dict:
    f = spec.fields
    present = [f["name"]]
    for key in ("company", "jobTitle", "department"):
        if f.get(key):
            present.append(f[key])
    for p in f.get("phones", []):
        present.append(p["number"])
    present.extend(f.get("emails", []))
    if f.get("website"):
        present.append(f["website"])
    if f.get("address"):
        present.append(f["address"])

    absent = [k for k in ("company", "jobTitle", "department", "website", "address") if not f.get(k)]
    if not f.get("emails"):
        absent.append("emails")

    return {
        "id": spec.cid,
        "file": file,
        "kind": kind,
        "lang": spec.lang,
        "layout": spec.layout,
        "theme": spec.theme,
        "logo": spec.logo,
        "labels": spec.labels,
        "font_file": resolve_font(spec),
        "occlusion": occlusion,
        "notes": spec.notes,
        "fields": {
            "name": f["name"],
            "company": f.get("company"),
            "jobTitle": f.get("jobTitle"),
            "department": f.get("department"),
            "phones": f.get("phones", []),
            "emails": f.get("emails", []),
            "website": f.get("website"),
            "address": f.get("address"),
        },
        "expected_absent": absent,
        "present_text": present,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--clean", action="store_true")
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()

    if args.clean:
        for d in (CARDS_DIR, GT_DIR):
            if d.exists():
                shutil.rmtree(d)
    CARDS_DIR.mkdir(parents=True, exist_ok=True)
    GT_DIR.mkdir(parents=True, exist_ok=True)

    specs = build_corpus()
    if args.preview:
        specs = [s for s in specs if s.cid in ("zh-01", "en-03", "bi-06", "zh-04")]

    entries = []
    for spec in specs:
        rng = random.Random(int(hashlib.sha256(spec.cid.encode()).hexdigest()[:8], 16))
        card, text_bbox = render_card_with_meta(spec, rng)
        card.save(CARDS_DIR / spec.filename, optimize=True)
        entries.append(ground_truth_entry(spec, spec.filename, "flat"))

        if spec.occlusion:
            occluded = apply_occlusion(card, text_bbox, rng)
            if occluded is not None:
                occluded_image, occlusion_meta = occluded
                ofile = f"{spec.cid}-occluded.png"
                occluded_image.save(CARDS_DIR / ofile, optimize=True)
                entries.append(ground_truth_entry(spec, ofile, "occluded", occlusion_meta))

        if spec.photo_variant:
            photo, photo_quad = render_photo(spec, card, rng)
            pfile = f"{spec.cid}-photo.jpg"
            photo.save(CARDS_DIR / pfile, quality=92, optimize=True, progressive=True)
            entries.append(ground_truth_entry(spec, pfile, "photo"))

            if spec.occlusion:
                occluded_photo, photo_meta = apply_photo_occlusion(photo, photo_quad, rng)
                ofile = f"{spec.cid}-photo-occluded.jpg"
                occluded_photo.save(CARDS_DIR / ofile, quality=92, optimize=True, progressive=True)
                entries.append(ground_truth_entry(spec, ofile, "occluded-photo", photo_meta))

    # Keep the small app fixture bundle in sync with this exact corpus version.
    if not args.preview:
        fixture_names = ["bi-06", "en-02", "en-02-occluded", "en-03-photo", "zh-01",
                         "zh-01-photo", "zh-01-occluded", "zh-04", "bi-14-photo-occluded"]
        directory = ROOT / "Resources" / "Fixtures"
        directory.mkdir(parents=True, exist_ok=True)
        for name in fixture_names:
            photo_source = CARDS_DIR / (name + ".jpg")
            target = directory / (name + ".jpg")
            if photo_source.exists():
                shutil.copyfile(photo_source, target)
            else:
                with Image.open(CARDS_DIR / (name + ".png")) as source:
                    source.convert("RGB").save(target, quality=92, optimize=True)

    gt = {
        "version": 2,
        "generated_at": "2026-10-28T00:00:00+00:00",
        "generator": "Scripts/generate_test_cards.py",
        "seed": 20261027,
        "canvas": {"flat": [CARD_W, CARD_H], "vertical": [VERT_W, VERT_H]},
        "card_count": len({e["id"] for e in entries}),
        "image_count": len(entries),
        "cards": entries,
    }
    (GT_DIR / "ground_truth.json").write_text(
        json.dumps(gt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    with (GT_DIR / "manifest.csv").open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["id", "file", "kind", "lang", "layout", "theme", "logo", "font_file", "name", "company", "missing"])
        for e in entries:
            w.writerow([
                e["id"], e["file"], e["kind"], e["lang"], e["layout"], e["theme"], e["logo"], e["font_file"],
                e["fields"]["name"], e["fields"]["company"] or "", ",".join(e["expected_absent"]),
            ])

    print(f"cards: {len({e['id'] for e in entries})}  images: {len(entries)}")
    print(f"output: {CARDS_DIR}")
    print(f"ground truth: {GT_DIR / 'ground_truth.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
