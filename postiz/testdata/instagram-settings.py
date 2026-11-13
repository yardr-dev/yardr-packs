# Hands the stand-in a draft and a schedule on an Instagram channel, each
# without post_type and with it, and checks that it answers as the service
# does: 400 without the setting, 200 with it. build-post sends the setting
# now, so no case of testdata/calls ever reaches the refusal. This is the one
# place a post without it is made, straight at the stand-in, so the cases can
# be trusted to pass only with the setting.
#
#   python3 -I instagram-settings.py <the stand-in's address> <an Instagram channel's id>
#
# It says what differs, and exits 1 if anything does.
import json
import sys
import urllib.error
import urllib.request

site, channel = sys.argv[1:3]
picture = [{"id": "e639003b-f727-4a1e-87bd-74a2c48ae41e", "path": "https://uploads.postiz.com/6fba0ef5febb4400ae8778a5b854224d.png"}]
# The type, the settings of the one entry, and the status the service answers.
rows = [
    ("draft", {"__type": "instagram-standalone"}, 400),
    ("schedule", {"__type": "instagram-standalone"}, 400),
    ("draft", {"__type": "instagram-standalone", "post_type": "post"}, 200),
    ("schedule", {"__type": "instagram-standalone", "post_type": "post"}, 200),
]
failed = 0
for kind, settings, want in rows:
    body = {
        "type": kind,
        "date": "2030-11-20T09:00:00.000Z",
        "shortLink": False,
        "tags": [],
        "posts": [{"integration": {"id": channel}, "value": [{"content": "Hello.", "image": picture}], "settings": settings}],
    }
    request = urllib.request.Request(site + "/public/v1/posts", json.dumps(body).encode(), {"Content-Type": "application/json"})
    try:
        got = urllib.request.urlopen(request).status
    except urllib.error.HTTPError as err:
        got = err.code
    if got != want:
        failed += 1
        print("%s with settings %s: the stand-in answered %d, the service answers %d" % (kind, sorted(settings), got, want))
sys.exit(1 if failed else 0)
