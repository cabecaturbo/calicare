"""Builds the "A day with Cali Care" landing page (owner's copy, exactly) as
static HTML in the site's existing look (tokens.css), desktop and phone."""
import sys

BETA = 'mailto:msmccartin@gmail.com?subject=Cali%20Care%20beta'
CONTACT = 'mailto:msmccartin@gmail.com?subject=Cali%20Care'


def verify(name, html, fallback=None):
    out = f'<!-- VERIFY: {name} -->{html}<!-- /VERIFY -->'
    if fallback:
        out += f'<!-- FALLBACK ({name}): {fallback} -->'
    return out


# ---------- drawn pictures (night palette, from tokens.css) ----------

def tonight_card(scale=1.0):
    s = scale
    return f'''<div role="img" aria-label="The Tonight card on the Lock Screen: 2 wake-ups, last at 1:52 AM, with a Log button" style="box-sizing:border-box;width:{int(358*s)}px;padding:{int(16*s)}px;border-radius:{int(24*s)}px;background:#1E2129;border:1px solid #2C303A;color:#EAE3D6;display:flex;align-items:center;gap:{int(16*s)}px;font-family:var(--sans)">
<div style="flex-grow:1;display:flex;flex-direction:column;gap:{int(4*s)}px">
<span style="font-family:var(--serif);font-weight:500;font-size:{int(24*s)}px;line-height:1.2">Tonight</span>
<span style="font-size:{int(16*s)}px;line-height:1.35;color:#A8A093">2 wake-ups · last at 1:52 AM</span>
</div>
<span style="display:flex;align-items:center;gap:{int(8*s)}px;height:{int(56*s)}px;padding:0 {int(22*s)}px;border-radius:999px;background:#9FB0D0;color:#14161C;font-weight:600;font-size:{int(19*s)}px"><svg width="{int(20*s)}" height="{int(20*s)}" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M18 11V6a2 2 0 0 0-4 0v5h-.5V4a2 2 0 0 0-4 0v7H9V6a2 2 0 0 0-4 0v8a8 8 0 0 0 16 0v-2a2 2 0 0 0-4 0v-1z"/></svg>Log</span>
</div>'''


def lock_phone(scale=1.0):
    """A drawn iPhone Lock Screen at night with the Tonight card."""
    s = scale
    w, h = int(414 * s), int(868 * s)
    return f'''<div aria-hidden="false" style="width:{w}px;height:{h}px;box-sizing:border-box;padding:{int(12*s)}px;border-radius:{int(58*s)}px;background:var(--mock-frame)">
<div style="position:relative;width:100%;height:100%;border-radius:{int(46*s)}px;overflow:hidden;background:linear-gradient(180deg,#232833 0%,#2C3240 55%,#1B1F28 100%);color:#EAE3D6;font-family:var(--sans)">
<div style="position:absolute;top:{int(14*s)}px;left:50%;transform:translateX(-50%);width:{int(124*s)}px;height:{int(36*s)}px;border-radius:999px;background:#000"></div>
<div style="position:absolute;top:{int(84*s)}px;left:0;right:0;text-align:center">
<div style="font-size:{int(20*s)}px;font-weight:500">Tuesday, October 6</div>
<div style="font-size:{int(92*s)}px;line-height:1.05;font-weight:600;letter-spacing:-2px">1:58</div>
</div>
<div style="position:absolute;left:{int(16*s)}px;right:{int(16*s)}px;bottom:{int(120*s)}px;display:flex;justify-content:center">{tonight_card(s)}</div>
<div style="position:absolute;bottom:{int(10*s)}px;left:50%;transform:translateX(-50%);width:{int(134*s)}px;height:{int(5*s)}px;border-radius:999px;background:#EAE3D6;opacity:.8"></div>
</div>
</div>'''


NIGHTS = [  # (weekday, dot positions 0-1 along 7 PM to 7 AM)
    ('Wed', [0.42]), ('Thu', [0.30, 0.55, 0.78]), ('Fri', []), ('Sat', [0.48, 0.70]),
    ('Sun', [0.62]), ('Mon', [0.36, 0.58]), ('Tue', [0.45, 0.66]),
]


def night_strip(scale=1.0):
    s = scale
    rows = ''
    for day, dots in NIGHTS:
        dots_html = ''.join(
            f'<span style="position:absolute;left:calc({p*100:.0f}% - {int(5*s)}px);top:50%;transform:translateY(-50%);width:{int(10*s)}px;height:{int(10*s)}px;border-radius:999px;background:#9FB0D0"></span>'
            for p in dots)
        rows += f'''<div style="display:flex;align-items:center;gap:{int(10*s)}px;height:{int(16*s)}px">
<span style="width:{int(30*s)}px;font-size:{int(11*s)}px;color:#A8A093">{day}</span>
<span style="position:relative;flex-grow:1;height:{int(12*s)}px"><span style="position:absolute;left:0;right:0;top:50%;height:1px;background:#2C303A"></span>{dots_html}</span>
</div>'''
    return f'''<div role="img" aria-label="The Night strip widget: the last 7 nights as rows of dots, one dot per wake-up" style="box-sizing:border-box;width:{int(338*s)}px;height:{int(158*s)}px;padding:{int(14*s)}px {int(16*s)}px;border-radius:{int(22*s)}px;background:#14161C;font-family:var(--sans);display:flex;flex-direction:column;justify-content:space-between">
{rows}
<div style="display:flex;justify-content:space-between;padding-left:{int(40*s)}px;font-size:{int(10*s)}px;color:#A8A093"><span>7 PM</span><span>7 AM</span></div>
</div>'''


def shot(src, alt, scale=1.0):
    s = scale
    return f'''<div style="width:{int(414*s)}px;height:{int(868*s)}px;box-sizing:border-box;padding:{int(12*s)}px;border-radius:{int(58*s)}px;background:var(--mock-frame)">
<div style="width:100%;height:100%;border-radius:{int(46*s)}px;overflow:hidden"><img src="shots/{src}" alt="{alt}" style="width:100%;height:100%;display:block;object-fit:cover;object-position:top"></div>
</div>'''


SCALE = [('Calm', 'sw-calm'), ('A little itchy', 'sw-little-itchy'), ('Flaring', 'sw-flaring'), ('Very rough', 'sw-very-rough')]

FAQ = [
    ('Do I need an account?', 'No. Everything works on your phone without one. Sign in with Apple if you want to sync phones, share with a partner, or import a care plan.', None),
    ('Where is my child’s data stored?', 'On your phone. If you sign in, your logs also sync to our server so they’re on all your devices. Photos always stay on your phone, and you can export your data or delete your account at any time.', None),
    ('Does my doctor need the app?', 'No. You send them a PDF report by email or AirDrop.', 'doctor-pdf'),
    ('What happens when I import a care plan?', 'The plan’s text goes through our server to Claude, an AI model, which turns it into steps. Each step links back to your provider’s exact words, and nothing is added.', 'plan-import'),
]

WONT = [
    ('It won’t suggest treatments.', 'It helps you follow the plan from your provider.'),
    ('It won’t make you feel behind.', 'There are no streaks. If you miss a day, pick up where you left off.'),
    ('It won’t sell your data.', 'There are no ads and no tracking.'),
]

STORY = 'My son still struggles with severe eczema. I know what it’s like to go through life sleep deprived, just trying to make it through the day. Keeping track of flares and how he reacts to different foods was one more thing on my plate. That’s why I built Cali Care: to make that part as easy as possible.'

T214_BODY = 'When your child wakes up itching, tap Log right on your Lock Screen. You don’t have to unlock your phone or open the app. At night, the app switches to dark, warm colors so it won’t light up the room.'
T214_FALLBACK = 'When your child wakes up itching, tap Log on the Cali Care widget on your Home Screen. It saves right away, even offline, and Undo is right there if you tap by mistake. At night, the app switches to dark, warm colors so it won’t light up the room.'
T214_SMALL = 'Your Lock Screen only shows how many times they woke up, never your child’s name.'
T7_BODY = 'When you wake up, Cali Care shows how the night went: how many times your child woke up, and when. You can text it to your partner with one tap, so you don’t have to explain it over breakfast.'
T7_FALLBACK = 'In the morning, Cali Care shows how the night went: how many times your child woke up, and when. You can text it to your partner with one tap, so you don’t have to explain it over breakfast.'
WEEKS_BODY = 'The Night strip widget shows your last 7 nights right on your Home Screen. In the app, you can see how this week compares with last and how things have gone since your last visit.'
WEEKS_FALLBACK = 'In the app, you can see how this week compares with last and how things have gone since your last visit.'


def build(desk):
    pad = '120px' if desk else 'var(--gutter)'
    h1 = 'font-size:64px;line-height:70px' if desk else 'font-size:40px;line-height:46px'
    h2 = ('font-family:var(--serif);font-weight:500;font-size:44px;line-height:52px' if desk
          else 'font-family:var(--serif);font-weight:500;font-size:32px;line-height:38px')
    body = 'font-size:19px;line-height:30px' if desk else 'font-size:17px;line-height:26px'
    small = 'font-size:15px;line-height:22px'
    sec_pad = f'120px {pad}' if desk else f'56px {pad}'
    sc = 1.0 if desk else 0.8

    def P(text, style=body, extra=''):
        return f'<p class="muted" style="margin:0;{style};max-width:520px{extra}">{text}</p>'

    def label(text):
        return f'<span class="t-label" style="color:var(--accent)">{text}</span>'

    def moment(anchor, time, h, text_html, visual, bg='', night=False):
        cls = ' class="night"' if night else ''
        bgs = 'background:var(--bg);color:var(--ink);' if night else (f'background:{bg};' if bg else '')
        text = f'<div style="display:flex;flex-direction:column;gap:var(--s4)">{label(time)}<h2 style="margin:0;{h2}">{h}</h2>{text_html}</div>'
        vis = f'<div style="display:flex;justify-content:center">{visual}</div>'
        if desk:
            return f'<section id="{anchor}"{cls} style="box-sizing:border-box;padding:{sec_pad};{bgs}display:grid;grid-template-columns:repeat(2, minmax(0, 1fr));gap:80px;align-items:center">{text}{vis}</section>'
        return f'<section id="{anchor}-m"{cls} style="box-sizing:border-box;padding:{sec_pad};{bgs}display:flex;flex-direction:column;gap:var(--s5)">{text}{vis}</section>'

    m = '' if desk else '-m'
    out = []
    # header
    if desk:
        out.append(f'''<header style="height:88px;box-sizing:border-box;padding:0 120px;display:flex;align-items:center;justify-content:space-between;border-bottom:var(--hairline) solid var(--line)">
<a href="#top" class="t-title" style="color:var(--ink);text-decoration:none">Cali Care</a>
<nav aria-label="Main" style="display:flex;align-items:center;gap:var(--s6)">
<a href="#story" class="t-label" style="color:var(--ink);text-decoration:none">My story</a>
<a href="#day" class="t-label" style="color:var(--ink);text-decoration:none">A day with Cali Care</a>
<a href="#faq" class="t-label" style="color:var(--ink);text-decoration:none">FAQ</a>
<a href="{BETA}" class="t-label" style="height:44px;display:flex;align-items:center;padding:0 20px;border-radius:var(--r-btn);background:var(--ink);color:var(--bg);text-decoration:none">Join the beta</a>
</nav></header>''')
    else:
        out.append(f'''<header style="height:64px;box-sizing:border-box;padding:0 var(--gutter);display:flex;align-items:center;justify-content:space-between;border-bottom:var(--hairline) solid var(--line)">
<a href="#top-m" class="t-title" style="color:var(--ink);text-decoration:none">Cali Care</a>
<a href="{BETA}" class="t-label" style="height:44px;display:flex;align-items:center;padding:0 16px;border-radius:var(--r-btn);background:var(--ink);color:var(--bg);text-decoration:none">Join the beta</a>
</header>''')

    # 1. hero
    hero_text = f'''<div style="display:flex;flex-direction:column;gap:var(--s5)">
<span class="t-label muted">For parents of kids with eczema</span>
<h1 style="margin:0;font-family:var(--serif);font-weight:500;{h1};letter-spacing:-0.5px">You focus on your child. Cali Care keeps track.</h1>
<p class="t-lede" style="margin:0;max-width:560px;{'' if desk else 'font-size:20px;line-height:28px'}">Log hard nights with one tap, follow your care plan, and show your doctor exactly how it’s been.</p>
<div style="display:flex;{'align-items:center' if desk else 'flex-direction:column;align-items:stretch'};gap:var(--s4);margin-top:var(--s2)">
<a href="{BETA}" class="t-label" style="height:56px;display:flex;align-items:center;justify-content:center;padding:0 28px;border-radius:var(--r-btn);background:var(--ink);color:var(--bg);text-decoration:none">Join the beta</a>
<a href="#day{m}" class="t-label" style="min-height:44px;display:flex;align-items:center;justify-content:center;text-decoration:none">See how it works</a>
</div>
<span class="t-caption muted">Free on iPhone during the beta. No account needed.</span>
</div>'''
    hero_vis = verify('tonight', lock_phone(sc), 'swap in the Home Screen widget phone mockup (the previous hero picture, web/index.html before this change).')
    if desk:
        out.append(f'<section id="top" style="box-sizing:border-box;padding:96px 120px;display:grid;grid-template-columns:repeat(2, minmax(0, 1fr));gap:80px;align-items:center">{hero_text}<div style="display:flex;justify-content:center">{hero_vis}</div></section>')
    else:
        out.append(f'<section id="top-m" style="box-sizing:border-box;padding:48px var(--gutter) 56px;display:flex;flex-direction:column;gap:var(--s6)">{hero_text}<div style="display:flex;justify-content:center">{hero_vis}</div></section>')

    # 2. story
    photo = f'''<!-- TODO: founder photo. Replace this box with <img src="shots/founder.jpg" alt="Matthew with his son">. -->
<div aria-hidden="true" style="width:{'360px' if desk else '100%'};height:{'440px' if desk else '280px'};border-radius:var(--r-btn);background:var(--bg);border:1px solid var(--line);display:flex;align-items:center;justify-content:center"><span class="t-caption muted">Founder photo</span></div>'''
    story_text = f'''<div style="display:flex;flex-direction:column;gap:var(--s5);max-width:640px">
<h2 style="margin:0;{h2}">Why I built Cali Care</h2>
<p class="t-lede" style="margin:0;{'' if desk else 'font-size:21px;line-height:30px'}">{STORY}</p>
<span class="t-body muted">— Matthew, dad and founder</span>
</div>'''
    if desk:
        out.append(f'<section id="story" style="box-sizing:border-box;padding:120px;background:var(--surface);display:grid;grid-template-columns:minmax(0, 1fr) 360px;gap:80px;align-items:center">{story_text}{photo}</section>')
    else:
        out.append(f'<section id="story-m" style="box-sizing:border-box;padding:56px var(--gutter);background:var(--surface);display:flex;flex-direction:column;gap:var(--s5)">{story_text}{photo}</section>')

    # 3. a day heading
    out.append(f'<section id="day{m}" style="box-sizing:border-box;padding:{"96px 120px 0" if desk else "56px var(--gutter) 0"}"><h2 class="t-label muted" style="margin:0;font-size:15px;letter-spacing:0.08em;text-transform:uppercase">A day with Cali Care</h2></section>')

    # 4. 2:14 AM
    t214 = verify('tonight', P(T214_BODY), T214_FALLBACK) + verify('tonight', f'<p class="t-caption muted" style="margin:0;{small}">{T214_SMALL}</p>')
    out.append(moment('night', '2:14 AM', 'Tap once, and get back to your child.', t214,
                      verify('tonight', tonight_card(1.0 if desk else 0.9), 'swap in the Home Screen widget picture (WSmall loop) from the previous page.'),
                      night=True))

    # 5. 7:00 AM
    swatches = ''.join(f'<div style="display:flex;align-items:center;gap:var(--s2)"><span class="swatch {c}" style="width:20px;height:20px"></span><span class="t-caption">{n}</span></div>' for n, c in SCALE)
    t7 = (verify('tonight', P(T7_BODY), T7_FALLBACK)
          + P('It also asks one question: how is their skin today?')
          + f'<div style="display:{"flex" if desk else "grid"};{"" if desk else "grid-template-columns:repeat(2, minmax(0, 1fr));"}gap:var(--s3) var(--s5)">{swatches}</div>'
          + f'<span class="t-caption muted" style="max-width:480px">The scale never uses red, and it’s based on symptoms, not how the skin looks, so it works for every skin tone.</span>')
    out.append(moment('morning', '7:00 AM', 'Last night, already written down.', t7,
                      shot('today-day.jpg', 'Cali Care’s Today screen in the morning: how was their skin today, and a summary of last night', sc)))

    # 6. during the day
    tday = (verify('plan-import', P('Take a photo of your care plan, and Cali Care turns it into a short list for the morning, afternoon, and bedtime. It counts skin-care rounds for you, so you never have to wonder whether it was two or three.'))
            + f'<p class="t-caption muted" style="margin:0;{small}">Your provider’s exact words are always a tap away. Importing a plan requires signing in.</p>'
            + P('You can also log flares, foods, products, baths, and notes whenever you want. None of it is required.'))
    out.append(moment('during', 'During the day', 'Your provider’s plan, one step at a time.', tday,
                      shot('todo-day.jpg', 'Cali Care’s To do screen: the care plan as a list for the morning, with the next step highlighted', sc),
                      bg='var(--surface)'))

    # 7. over the weeks
    tweeks = verify('night-strip', P(WEEKS_BODY), WEEKS_FALLBACK)
    out.append(moment('weeks', 'Over the weeks', 'See the whole month, not just the worst night.', tweeks,
                      verify('night-strip', night_strip(1.0 if desk else 1.0), 'remove this picture.')))

    # 8. at the appointment
    tappt = verify('doctor-pdf', P('Share a short PDF report with charts, a day-by-day view, and your notes. Your doctor doesn’t need the app.'))
    out.append(moment('appointment', 'At the appointment', 'When the doctor asks how it’s been, you’ll know.', tappt,
                      shot('progress-week.jpg', 'Cali Care’s Progress screen: this week’s nights and skin, with Share with provider', sc),
                      bg='var(--surface)'))

    # 9. everyone who helps
    items = [
        ('Your partner', 'Invite them with a code, and you’ll both see every log.', 'family-sharing'),
        ('Babysitters and grandparents', 'Give them a one-page card with the routine.', None),
        ('Family', 'Text them a weekly summary card.', None),
    ]
    cells = ''
    for t, b, v in items:
        cell = f'<div style="display:flex;flex-direction:column;gap:var(--s3);padding-top:var(--s4);border-top:1px solid var(--ink)"><h3 class="t-title" style="margin:0">{t}</h3><p class="muted" style="margin:0;font-size:17px;line-height:27px">{b}</p></div>'
        cells += verify(v, cell) if v else cell
    grid = f'display:grid;grid-template-columns:repeat(3, minmax(0, 1fr));gap:56px' if desk else 'display:flex;flex-direction:column;gap:var(--s5)'
    out.append(f'<section id="helps{m}" style="box-sizing:border-box;padding:{sec_pad};display:flex;flex-direction:column;gap:{"56px" if desk else "var(--s5)"}"><h2 style="margin:0;{h2}">Everyone on the same page.</h2><div style="{grid}">{cells}</div></section>')

    # 10. won't do
    cells = ''.join(f'<div style="display:flex;flex-direction:column;gap:var(--s3);padding-top:var(--s4);border-top:1px solid var(--ink)"><h3 class="t-title" style="margin:0">{t}</h3><p class="muted" style="margin:0;font-size:17px;line-height:27px">{b}</p></div>' for t, b in WONT)
    out.append(f'<section id="wont{m}" style="box-sizing:border-box;padding:{sec_pad};border-top:var(--hairline) solid var(--line);display:flex;flex-direction:column;gap:{"56px" if desk else "var(--s5)"}"><h2 style="margin:0;{h2}">What Cali Care won’t do</h2><div style="{grid}">{cells}</div></section>')

    # 11. FAQ
    qs = ''
    for q, a, v in FAQ:
        d = f'''<details class="faq ledger-row" style="display:block;padding:var(--s4) 0"><summary class="{'t-title' if desk else 't-body'}" style="min-height:44px;display:flex;align-items:center;justify-content:space-between;gap:var(--s4);{'' if desk else 'font-weight:600'}">{q}<svg class="faq-chev" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true" style="flex-shrink:0;color:var(--muted)"><path d="m9 6 6 6-6 6"></path></svg></summary><p class="muted" style="margin:var(--s2) 0 0;font-size:17px;line-height:27px">{a}</p></details>'''
        qs += verify(v, d) if v else d
    out.append(f'<section id="faq{m}" style="box-sizing:border-box;padding:{sec_pad};background:var(--surface);display:flex;flex-direction:column;gap:var(--s5)"><h2 style="margin:0;{h2}">Questions</h2><div class="ledger" style="max-width:860px">{qs}</div></section>')

    # 12. CTA
    out.append(f'''<section id="get{m}" style="box-sizing:border-box;padding:{"120px" if desk else "72px var(--gutter)"};display:flex;flex-direction:column;align-items:center;gap:var(--s4);text-align:center">
<h2 style="margin:0;{h2}">Try Cali Care free during the beta.</h2>
<p class="muted" style="margin:0;{body}">Available on iPhone, and it works offline.</p>
<a href="{BETA}" class="t-label" style="margin-top:var(--s3);height:56px;display:flex;align-items:center;padding:0 28px;border-radius:var(--r-btn);background:var(--ink);color:var(--bg);text-decoration:none">Join the beta</a>
</section>''')

    # footer (unchanged)
    if desk:
        out.append(f'''<footer style="box-sizing:border-box;padding:var(--s6) 120px 64px;border-top:var(--hairline) solid var(--line);display:flex;justify-content:space-between;gap:80px">
<div style="display:flex;flex-direction:column;gap:var(--s2);max-width:560px"><span class="t-title">Cali Care</span><span class="t-caption muted">Not medical advice. Cali Care helps you organize and track the plan from your own provider. Talk to them about treatment.</span></div>
<div style="display:flex;gap:var(--s6);align-items:flex-start"><a href="/privacy" class="t-caption" style="min-height:44px;display:flex;align-items:center">Privacy policy</a><a href="{CONTACT}" class="t-caption" style="min-height:44px;display:flex;align-items:center">Contact</a><span class="t-caption muted" style="min-height:44px;display:flex;align-items:center">© 2026 CursorKittens LLC</span></div>
</footer>''')
    else:
        out.append(f'''<footer style="box-sizing:border-box;padding:var(--s5) var(--gutter) 48px;border-top:var(--hairline) solid var(--line);display:flex;flex-direction:column;gap:var(--s2)">
<span class="t-title">Cali Care</span><span class="t-caption muted">Not medical advice. Cali Care helps you organize and track the plan from your own provider.</span>
<div style="display:flex;gap:var(--s5)"><a href="/privacy" class="t-caption" style="min-height:44px;display:flex;align-items:center">Privacy policy</a><a href="{CONTACT}" class="t-caption" style="min-height:44px;display:flex;align-items:center">Contact</a></div>
<span class="t-caption muted">© 2026 CursorKittens LLC</span>
</footer>''')
    width = '1440px' if desk else '390px'
    return f'<div class="day" style="width:{width};display:flex;flex-direction:column;background:var(--bg);color:var(--ink);font-family:var(--sans)">' + '\n'.join(out) + '</div>'


template = open(sys.argv[1]).read()
html = template.replace('{DESK}', build(True)).replace('{MOB}', build(False))
import re
html = re.sub(r'<title>.*?</title>', '<title>Cali Care: eczema tracking for parents</title>', html)
html = re.sub(r'<meta name="description" content="[^"]*">', '<meta name="description" content="Log hard nights with one tap, follow your care plan, and show your child’s doctor exactly how it’s been. Free on iPhone during the beta.">', html)
html = html.replace('<!-- Built from the "Cali Care website" design canvas (Home · desktop and Home · phone),\n     with real app screenshots in shots/. -->', '<!-- "A day with Cali Care": built by gen_day.py in the site\'s look (tokens.css), with real app screenshots in shots/. -->')
open(sys.argv[2], 'w').write(html)
