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
        ttl_seconds = 180,
    )
    if resp.status_code != 200:
        print("Message retrieval failed with status ", resp.status_code)
        return str(resp.status_code)
    r = resp.body()
    return r

def main(config):

    resp = fetch_resp()

    lines = resp.splitlines()

    return render.Root(
        max_age = 120,
        delay = 25,
        child = render.Marquee(
            width = 64,
            align = "center",
            child = render.Text(
                content = lines[0]
            ),
        )
    )
