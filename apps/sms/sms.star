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

# Get message
def fetch_resp():
    resp = http.get(
        QUERY_URL,
#         params = {
#             "slug": 'doug'
#         },
        headers = {
            "User-Agent": USER_AGENT,
        },
        ttl_seconds = 60,
    )
    if resp.status_code != 200:
        print("Message retrieval failed with status ", resp.status_code)
        return str(resp.status_code)
    r = resp.body()
    return r

def main(config):

    resp = fetch_resp()

    blocks = []
    lines = resp.splitlines()

    for l in lines:
        blocks.append(
            render.WrappedText(
                content=l.strip(),
                width=64,
                align="center",
            )
        )

    if len(blocks) == 0:
        return []

    return render.Root(
        child = render.Marquee(
            width = 64,
            height = 32,
            scroll_direction = "vertical",
            child = render.Column(
                cross_align="center", # Horizontal center
                children = blocks,
            ),
        ),
        max_age = 60,
    )
