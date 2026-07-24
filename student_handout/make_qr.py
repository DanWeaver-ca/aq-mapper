"""Generate standalone QR code images for the lab.

Run:  python3 make_qr.py
Writes one PNG per entry in TARGETS below (300 DPI, captioned) into this
folder. The app URL comes from /deploy.config.json so a fork's codes point at
its own deployment; other links are listed here. Add a target and re-run.
"""
import json
import os
import qrcode
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
_CONFIG = os.environ.get("AQ_CONFIG",
                         os.path.join(HERE, "..", "deploy.config.json"))
try:
    with open(_CONFIG, encoding="utf-8") as _fh:
        APP_URL = json.load(_fh)["APP_URL"]
except Exception:
    APP_URL = "https://danweaver-ca.github.io/aq-mapper/"

CAMPUS_MAP_URL = (
    "https://www.utsc.utoronto.ca/home/sites/utsc.utoronto.ca.home/files/"
    "images/page/Campus%20Map-072525_FINAL_8.5x11.pdf"
)

# Two colours on purpose, so the pair stays distinguishable at a glance on a
# handout — but both dark. Scanners binarize to light/dark, so contrast is
# scan reliability: navy is 8.7:1 against white and black 21:1, where the
# app's teal (#009688) was a marginal 3.67:1. Black goes to the campus-map
# code because it's the dense one (long URL, fine modules).
NAVY = "#1A4E7A"
BLACK = "#000000"

# (url, output filename, caption, subtitle shown under the caption, colour)
TARGETS = [
    # NB: deliberately NOT aq_mapper_qr.png — that one is make_handout.py's
    # bare, uncaptioned asset embedded in the docx; don't clobber it.
    (APP_URL, "aq_mapper_app_qr.png",
     "AQ Mapper", "Scan with your Camera app — not WeChat · 请用相机扫码，勿用微信",
     NAVY),
    (CAMPUS_MAP_URL, "utsc_campus_map_qr.png",
     "UTSC Campus Map", "Scan for the printable campus map", BLACK),
]


def _has_cjk(text):
    return any("一" <= ch <= "鿿" for ch in text)


def font(size, bold=True, cjk=False):
    # Arial/Helvetica have no CJK glyphs — captions with Chinese need a
    # CJK-capable face or they render as tofu boxes.
    names = (["PingFang.ttc", "Hiragino Sans GB.ttc", "STHeiti Light.ttc"]
             if cjk else
             (["Arial Bold.ttf", "Helvetica.ttc"] if bold
              else ["Arial.ttf", "Helvetica.ttc"]))
    for name in names:
        path = os.path.join("/System/Library/Fonts/Supplemental", name)
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
        path = os.path.join("/System/Library/Fonts", name)
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def make(url, filename, caption, subtitle, colour, box=30):
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M,
                       box_size=box, border=2)
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color=colour, back_color="white").convert("RGB")

    pad = img.width // 20
    meas = ImageDraw.Draw(img)

    def fitted(text, size, bold, ink):
        # Shrink until the line fits inside the image width (long bilingual
        # subtitles would otherwise clip at both edges).
        f = font(size, bold=bold, cjk=_has_cjk(text))
        while size > 12 and meas.textlength(text, font=f) > img.width * 0.96:
            size -= 2
            f = font(size, bold=bold, cjk=_has_cjk(text))
        return (text, f, ink)

    lines = [
        fitted(caption, max(30, img.width // 20), True, "#222222"),
        fitted(subtitle, max(20, img.width // 32), False, "#666666"),
    ]
    text_h = sum(f.getbbox("Ag")[3] + pad // 2 for _, f, _ in lines) + pad

    canvas = Image.new("RGB", (img.width, img.height + text_h), "white")
    canvas.paste(img, (0, 0))
    d = ImageDraw.Draw(canvas)
    y = img.height + pad // 2
    for text, f, ink in lines:
        w = d.textlength(text, font=f)
        d.text(((canvas.width - w) / 2, y), text, font=f, fill=ink)
        y += f.getbbox("Ag")[3] + pad // 2

    path = os.path.join(HERE, filename)
    canvas.save(path, dpi=(300, 300))
    print(f"wrote {path}  ({canvas.width}x{canvas.height}px)")


if __name__ == "__main__":
    for target in TARGETS:
        make(*target)
