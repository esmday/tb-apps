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

QUERY_URL = "https://860458.xyz/tidbyt/get.php"
USER_AGENT = "SMS"

# Get message
# def fetch():
#     resp = http.get(
#         QUERY_URL.format(slug='doug'),
#         params = {
#             "slug": 'doug'
#         },
#         headers = {
#             "User-Agent": USER_AGENT,
#         },
#         ttl_seconds = 180,
#     )
#     if resp.status_code != 200:
#         print("Message retrieval failed with status ", resp.status_code)
#         return None
#     return resp.json()

def main(config):

    return render.Root(
        max_age = 120,
        delay = 25,
        child = render.Marquee(
            width = 64,
            align = "center",
            child = render.Text(
                content = 'steve'
            ),
        )
    )
