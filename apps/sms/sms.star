"""
Applet: SMS
Summary: Send messages to Tidbyts
Description: Send messages to Tidbyts
Author: esmday
"""

load("encoding/json.star", "json")
load("http.star", "http")
load("math.star", "math")
load("render.star", "render")
load("schema.star", "schema")

QUERY_URL = "https://tidbyt.860458.xyz/apps/sms/get.php?slug=doug"
USER_AGENT = "SMS"
DEFAULT_COLOR = "#ffffff"

def fetch_resp():
    resp = http.get(
        QUERY_URL,
        headers = {
            "User-Agent": USER_AGENT,
        },
        ttl_seconds = 60,
    )
    if resp.status_code != 200:
        print("Message retrieval failed with status ", resp.status_code)
        return str(resp.status_code)
    return resp.body()

ENTITIES = [
    ("&nbsp;", " "),
    ("&#160;", " "),
    ("&#xa0;", " "),
    ("&#xA0;", " "),
    ("&lt;", "<"),
    ("&gt;", ">"),
    ("&quot;", "\""),
    ("&apos;", "'"),
    ("&#39;", "'"),
    ("&amp;", "&"),
]

def decode_entities(s):
    for ent, ch in ENTITIES:
        s = s.replace(ent, ch)
    return s

def split_lines(s):
    for br in ["<br/>", "<br />", "<BR>", "<BR/>", "<BR />", "<Br>"]:
        s = s.replace(br, "<br>")
    s = s.replace("\r\n", "<br>").replace("\n", "<br>")
    return s.split("<br>")

def parse_segments(line):
    segments = []
    pos = 0
    for _ in range(200):
        if pos >= len(line):
            break
        open_idx = line.find("<font", pos)
        if open_idx == -1:
            text = line[pos:]
            if text:
                segments.append((text, DEFAULT_COLOR))
            break
        if open_idx > pos:
            segments.append((line[pos:open_idx], DEFAULT_COLOR))
        close_open = line.find(">", open_idx)
        if close_open == -1:
            segments.append((line[open_idx:], DEFAULT_COLOR))
            break
        attr_part = line[open_idx:close_open]
        color = DEFAULT_COLOR
        ci = attr_part.find("color=")
        if ci != -1:
            q1 = attr_part.find('"', ci)
            q2 = -1
            if q1 != -1:
                q2 = attr_part.find('"', q1 + 1)
            if q1 == -1 or q2 == -1:
                q1 = attr_part.find("'", ci)
                q2 = -1
                if q1 != -1:
                    q2 = attr_part.find("'", q1 + 1)
            if q1 != -1 and q2 != -1:
                color = attr_part[q1 + 1:q2]
        close_idx = line.find("</font>", close_open)
        if close_idx == -1:
            inner = line[close_open + 1:]
            if inner:
                segments.append((inner, color))
            break
        inner = line[close_open + 1:close_idx]
        if inner:
            segments.append((inner, color))
        pos = close_idx + len("</font>")
    return segments

DISPLAY_WIDTH = 64

# Advance widths (px) of the default tb-8 font for ASCII 32 (space) .. 126 (~),
# taken from the DWIDTH entries in pixlet's fonts/tb-8.bdf. Pixlet has no text
# measuring API, so wrapping is computed from these.
TB8_WIDTHS = [
    3, 2, 4, 5, 5, 5, 5, 2, 3, 3, 5, 4, 3, 4, 2, 5,  # space ! " # $ % & ' ( ) * + , - . /
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 2, 3, 4, 4, 4, 4,  # 0-9 : ; < = > ?
    6, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 5, 5, 6, 5, 5,  # @ A-O
    5, 5, 5, 5, 4, 5, 6, 6, 5, 6, 5, 5, 5, 5, 4, 5,  # P-Z [ \ ] ^ _
    3, 5, 5, 4, 5, 5, 5, 5, 5, 4, 4, 5, 4, 6, 5, 5,  # ` a-o
    5, 5, 5, 4, 5, 5, 4, 6, 5, 5, 5, 5, 2, 5, 5,  # p-z { | } ~
]
FALLBACK_CHAR_WIDTH = 5
SPACE_WIDTH = TB8_WIDTHS[0]

def char_width(ch):
    code = ord(ch)
    if code >= 32 and code < 32 + len(TB8_WIDTHS):
        return TB8_WIDTHS[code - 32]
    return FALLBACK_CHAR_WIDTH

def text_width(s):
    w = 0
    for ch in s.codepoints():
        w += char_width(ch)
    return w

def add_piece(pieces, text, color):
    # Append text to a list of [text, color] pieces, merging with the last
    # piece when the color matches so each row needs as few Text widgets as possible.
    if len(pieces) > 0 and pieces[-1][1] == color:
        pieces[-1][0] += text
    else:
        pieces.append([text, color])

def line_words(segments):
    # Split colored segments into words. A word can span several colors
    # (e.g. <font color="red">He</font>llo), so each word is a list of pieces.
    words = []
    current = []
    for text, color in segments:
        for ch in text.codepoints():
            if ch.isspace():
                if len(current) > 0:
                    words.append(current)
                    current = []
            else:
                add_piece(current, ch, color)
    if len(current) > 0:
        words.append(current)
    return words

def pieces_width(pieces):
    w = 0
    for text, _ in pieces:
        w += text_width(text)
    return w

def split_long_word(word):
    # Break a word wider than the display into display-width chunks.
    chunks = []
    current = []
    width = 0
    for text, color in word:
        for ch in text.codepoints():
            cw = char_width(ch)
            if width + cw > DISPLAY_WIDTH and len(current) > 0:
                chunks.append(current)
                current = []
                width = 0
            add_piece(current, ch, color)
            width += cw
    if len(current) > 0:
        chunks.append(current)
    return chunks

def wrap_words(words):
    # Greedy word wrap into rows that fit the display width.
    rows = []
    row = []
    width = 0
    for word in words:
        word_width = pieces_width(word)
        if word_width > DISPLAY_WIDTH:
            if len(row) > 0:
                rows.append(row)
            chunks = split_long_word(word)
            rows.extend(chunks[:-1])
            row = chunks[-1]
            width = pieces_width(row)
            continue
        if len(row) > 0 and width + SPACE_WIDTH + word_width > DISPLAY_WIDTH:
            rows.append(row)
            row = []
            width = 0
        if len(row) > 0:
            # The space between words takes the color of the preceding text.
            add_piece(row, " ", row[-1][1])
            width += SPACE_WIDTH
        for text, color in word:
            add_piece(row, text, color)
        width += word_width
    if len(row) > 0:
        rows.append(row)
    return rows

LINE_HEIGHT = 8  # tb-8 ascent (7) + descent (1); the height pixlet gives each Text

def row_block(row):
    # A full-width box so each row is centered on the display, rather than
    # within the widest row.
    return render.Box(
        width = DISPLAY_WIDTH,
        height = LINE_HEIGHT,
        child = render.Row(
            children = [render.Text(content = text, color = color) for text, color in row],
        ),
    )

def trim_blank_lines(line_rows):
    # Drop empty lines at the start and end (e.g. from a trailing <br>) so they
    # don't add height and make the message scroll. Blank lines in between stay.
    start = 0
    for rows in line_rows:
        if len(rows) > 0:
            break
        start += 1
    end = len(line_rows)
    for rows in reversed(line_rows):
        if len(rows) > 0:
            break
        end -= 1
    return line_rows[start:end]

def main(config):
    resp = fetch_resp()
    resp = decode_entities(resp)

    line_rows = [
        wrap_words(line_words(parse_segments(l.strip())))
        for l in split_lines(resp)
    ]

    blocks = []
    for rows in trim_blank_lines(line_rows):
        if len(rows) == 0:
            blocks.append(render.Box(width = DISPLAY_WIDTH, height = LINE_HEIGHT))
        for row in rows:
            blocks.append(row_block(row))

    if len(blocks) == 0:
        return []

    return render.Root(
        child = render.Marquee(
            width = 64,
            height = 32,
            scroll_direction = "vertical",
            child = render.Column(
                cross_align = "center",
                children = blocks,
            ),
        ),
        max_age = 60,
    )
