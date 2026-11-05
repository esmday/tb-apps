"""
Applet: PWFD
Summary: Port Washington FD calls
Description: Shows the time and call type of the most recent Port Washington Fire Department call, refreshed every two minutes.
Author: smd
"""

load("http.star", "http")
load("images/flame.png", FLAME_ASSET = "file")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

# The real-time call page at https://www.pwfd.com/real-time-call-system/ is a
# thin wrapper around this iframe, which holds the actual call table.
CALLS_URL = "https://calls.pwfd.com/website_full.asp"
USER_AGENT = "Tidbyt PWFD"
POLL_SECONDS = 120

TIMEZONE = "America/New_York"  # Port Washington, NY; "today" is always NY time

FLAME = FLAME_ASSET.readall()

WHITE = "#ffffff"
ORANGE = "#ff9d3c"
FONT = "tom-thumb"

TEXT_WIDTH = 50  # 64 minus the flame and its padding

# Short enough to already read as an acronym, so leave them alone when
# converting the site's SHOUTING call types to title case.
ACRONYMS = ["EMS", "MVA", "CO", "AFA", "PD", "FD", "LZ"]

def fetch_calls():
    resp = http.get(
        CALLS_URL,
        headers = {
            "User-Agent": USER_AGENT,
        },
        ttl_seconds = POLL_SECONDS,
    )
    if resp.status_code != 200:
        print("PWFD call request failed with status ", resp.status_code)
        return None
    return resp.body()

# Rows look like:
# <tr><td>08/19/2026</td><td>15:50</td><td>PORT WASHINGTON</td><td>SIGNAL 9</td></tr>
def row_cells(row):
    cells = []
    pos = 0
    for _ in range(10):
        open_idx = row.find("<td", pos)
        if open_idx == -1:
            break
        close_open = row.find(">", open_idx)
        if close_open == -1:
            break
        close_idx = row.find("</td>", close_open)
        if close_idx == -1:
            break
        cells.append(row[close_open + 1:close_idx].strip())
        pos = close_idx + len("</td>")
    return cells

# The site zero pads, but don't depend on it when comparing against today.
def normalize_date(date):
    parts = date.split("/")
    if len(parts) != 3:
        return date
    return "/".join([p.lstrip("0") for p in parts])

def parse_calls(body):
    calls = []
    for row in body.split("<tr>"):
        cells = row_cells(row)
        if len(cells) < 4:
            continue
        date = cells[0]
        clock = cells[1]
        call_type = cells[3]
        if not date or not clock or not call_type:
            continue
        if len(date.split("/")) != 3 or len(clock.split(":")) != 2:
            continue
        calls.append({
            "date": normalize_date(date),
            "time": clock,
            "type": call_type,
        })
    return calls

# Calls arrive newest first, but sort so we don't depend on that either.
def latest_call_today(calls, now):
    today = normalize_date(now.format("01/02/2006"))
    todays_calls = [c for c in calls if c["date"] == today]
    if len(todays_calls) == 0:
        return None
    return sorted(todays_calls, key = lambda c: c["time"], reverse = True)[0]

def format_time(clock, use_24_hour):
    if use_24_hour:
        return clock

    parts = clock.split(":")
    hour = int(parts[0])
    minute = parts[1]

    suffix = "AM" if hour < 12 else "PM"
    hour = hour % 12
    if hour == 0:
        hour = 12

    return "%d:%s %s" % (hour, minute, suffix)

# "AUTOMATIC ALARM" is a lot of shouting for a 64 pixel screen.
def format_call_type(call_type):
    if call_type != call_type.upper():
        return call_type

    words = []
    for word in call_type.split(" "):
        if word in ACRONYMS or len(word) < 2:
            words.append(word)
        else:
            words.append(word[0] + word[1:].lower())
    return " ".join(words)

def screen(children):
    return render.Root(
        max_age = POLL_SECONDS,
        # A Row sizes itself to its content, so wrap it in a Box to centre the
        # flame and the call vertically on the 32 pixel screen.
        child = render.Box(
            child = render.Row(
                expanded = True,
                cross_align = "center",
                children = [
                    render.Padding(
                        pad = (2, 0, 3, 0),
                        child = render.Image(src = FLAME),
                    ),
                    render.Column(children = children),
                ],
            ),
        ),
    )

def message(text):
    return screen([
        render.WrappedText(
            content = text,
            width = TEXT_WIDTH,
            font = FONT,
            color = ORANGE,
        ),
    ])

def main(config):
    body = fetch_calls()
    if not body:
        return message("Call data unavailable")

    call = latest_call_today(parse_calls(body), time.now().in_location(TIMEZONE))
    if not call:
        return message("No calls today")

    return screen([
        render.Text(
            content = format_time(call["time"], config.bool("clock_24_hour", False)),
            color = WHITE,
        ),
        render.Marquee(
            width = TEXT_WIDTH,
            child = render.Text(
                content = format_call_type(call["type"]),
                font = FONT,
                color = ORANGE,
            ),
        ),
    ])

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Toggle(
                id = "clock_24_hour",
                name = "24 hour clock",
                desc = "Show call times as 24 hour instead of AM/PM.",
                icon = "clock",
                default = False,
            ),
        ],
    )
