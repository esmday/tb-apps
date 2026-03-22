"""
Applet: DougSucks
Summary: Doug Sucks
Description: Doug Sucks
Author: esmday
"""

load("encoding/json.star", "json")
load("http.star", "http")
load("math.star", "math")
load("render.star", "render")
load("schema.star", "schema")

def main(config):

    return render.Root(
        max_age = 120,
        delay = 25,
        child = render.Marquee(
            width = 64,
            align = "center",
            child = render.Text(
                content = 'DOUG SUCKS'
            ),
        )
    )
