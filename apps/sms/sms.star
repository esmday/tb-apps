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

QUERY_URL = "https://860458.xyz/tidbyt/get.php?slug=doug"
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

def line_blocks(line):
    segments = parse_segments(line)
    if len(segments) == 0:
        return [render.Text(content = " ")]
    blocks = []
    for text, color in segments:
        stripped = text.strip()
        if stripped == "":
            continue
        blocks.append(render.WrappedText(
            content = stripped,
            width = 64,
            align = "center",
            color = color,
        ))
    if len(blocks) == 0:
        return [render.Text(content = " ")]
    return blocks

def main(config):
    resp = fetch_resp()
    resp = decode_entities(resp)

    lines = split_lines(resp)

    blocks = []
    for l in lines:
        l = l.strip()
        for b in line_blocks(l):
            blocks.append(b)

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
