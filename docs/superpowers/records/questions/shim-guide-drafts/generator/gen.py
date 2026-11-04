import html, os, re, sys

SRC = "/mnt/MediaVolume/Media/src/github.com/spaceghost/writ/hosts/genode/shim/writ_mem.cc"
OUT = sys.argv[1]
LINES = open(SRC).read().split("\n")

CSS = """:root{--bg:#f7f6f2;--fg:#1d2230;--muted:#5b6474;--line:#d9dbe0;--accent:#15655c;--soft:#e2efec;--mono:"JetBrains Mono","SF Mono",Menlo,monospace}
@media (prefers-color-scheme:dark){:root{--bg:#15181f;--fg:#e6e4dc;--muted:#a4a9b4;--line:#333945;--accent:#5fc2b2;--soft:#1d3330}}
body{margin:0;padding:1rem 1.2rem 2rem;background:var(--bg);color:var(--fg);font:15px/1.5 "Source Sans 3","Segoe UI",system-ui,sans-serif;max-width:60rem}
h1{font-size:1.3rem;margin:0 0 .4rem}p{margin:.4rem 0;max-width:68ch}
fieldset{border:1px solid var(--line);border-radius:8px;padding:.6rem 1rem;margin:.9rem 0}legend{font-weight:600;padding:0 .3rem}
label{display:block;margin:.3rem 0;cursor:pointer}label input{margin-right:.5rem}
textarea{width:100%;box-sizing:border-box;min-height:5rem;font:inherit;padding:.5rem;border:1px solid var(--line);border-radius:6px;background:var(--bg);color:var(--fg)}
button{font:inherit;font-weight:600;background:var(--accent);color:#fff;border:0;border-radius:6px;padding:.5rem 1rem;cursor:pointer;margin-top:.5rem}
code{font-family:var(--mono);font-size:.9em;background:var(--soft);padding:.05em .3em;border-radius:4px}
table{border-collapse:collapse;font-size:.92rem;margin:.5rem 0}th,td{text-align:left;padding:.3rem .6rem;border-bottom:1px solid var(--line);vertical-align:top}
.note{color:var(--muted);font-size:.9rem}"""

# one extra rule so a long excerpt scrolls inside its box instead of widening the page
PRE = "pre{background:var(--soft);border-radius:6px;padding:.6rem .8rem;overflow-x:auto;font-size:.85rem;line-height:1.35}pre code{background:none;padding:0}"


def excerpt(a, b):
    assert b - a + 1 <= 35, (a, b)
    body = "\n".join(LINES[a - 1:b])
    return html.escape(body.replace("\t", "    "), quote=False)


def page(n, slug, title, orient, ranges, ex, why, claims, verdict=None):
    rng = ", ".join("<code>writ_mem.cc:%d-%d</code>" % r for r in ranges)
    out = ['<!doctype html>',
           '<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
           '<title>%s</title>' % html.escape(title),
           '<meta name="writ-topic" content="genode">',
           '<meta name="writ-status" content="open">',
           '<style>', CSS, PRE, '</style>', '</head><body>',
           '<h1>%s</h1>' % html.escape(title)]
    out.append('<p>%s</p>' % orient)
    if verdict is None:
        out.append('<p><strong>Open:</strong> %s</p>' % rng)
        a, b = ex
        out.append('<p class="note">Excerpt, <code>writ_mem.cc:%d-%d</code> (tabs shown as four spaces):</p>' % (a, b))
        out.append('<pre><code>%s</code></pre>' % excerpt(a, b))
        if why:
            out.append('<p class="note"><strong>Limit or policy?</strong> %s</p>' % why)
        out.append('<p><strong>Confirm by reading:</strong></p>')
        out.append('<ol>')
        for c in claims:
            out.append('<li>%s</li>' % c)
        out.append('</ol>')
        out.append('<form method="post" action="/questions/__ID__/answer">')
        for i in range(1, len(claims) + 1):
            out.append('<fieldset><legend>Claim %d</legend>' % i)
            for v, l in (("confirmed", "Confirmed: the code does this"),
                         ("disagree", "Disagree: the code does something else"),
                         ("unsure", "Unsure: I could not tell from the code")):
                out.append('<label><input type="radio" name="c%d" value="%s">%s</label>' % (i, v, l))
            out.append('</fieldset>')
    else:
        out.extend(verdict)
        out.append('<form method="post" action="/questions/__ID__/answer">')
        out.append('<fieldset><legend>GB-006 verdict on writ_mem.cc</legend>')
        for v, l in (("no-policy-confirmed", "No policy found: the shim only translates native facts and performs admitted effects; task 2.2 may name me as reviewer"),
                     ("policy-found", "Policy found: at least one place decides something GB-006 reserves for Bend (say where below)"),
                     ("need-more-time", "Need more time, or an explanation first (say what below)")):
            out.append('<label><input type="radio" name="verdict" value="%s">%s</label>' % (v, l))
        out.append('</fieldset>')
    out.append('<label>Notes, doubts, or what you\'d like explained<br><textarea name="text" placeholder="optional"></textarea></label>')
    out.append('<button type="submit">Send answer</button>')
    out.append('</form>')
    out.append('</body></html>')
    path = os.path.join(OUT, "%02d-%s.html" % (n, slug))
    open(path, "w").write("\n".join(out) + "\n")
    return path


exec(open(os.path.join(os.path.dirname(__file__), "content.py")).read())
