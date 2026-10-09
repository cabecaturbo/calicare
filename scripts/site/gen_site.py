"""Builds calicare.vercel.app: six short sections around the three features
the owner wants up front (care plan to-do list, Quick Log on the Lock Screen,
quick updates). Static HTML in the site's look (tokens.css), desktop and phone.

    python3 scripts/site/gen_site.py scripts/site/index.template.html web/index.html
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BETA = 'mailto:msmccartin@gmail.com?subject=Cali%20Care%20beta'
CONTACT = 'mailto:msmccartin@gmail.com?subject=Cali%20Care'

# Greige night colors, for the Lock Screen pictures (tokens.css .night).
N_BG, N_SURFACE, N_INK, N_MUTED, N_LINE = '#201712', '#2C2019', '#F2E5D6', '#BBA792', '#3B2C22'
N_BUTTON, N_ON_BUTTON = '#D3C8BC', '#201712'
PALM = ('<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">'
        '<path d="M18 11V6a2 2 0 0 0-4 0v5h-.5V4a2 2 0 0 0-4 0v7H9V6a2 2 0 0 0-4 0v8a8 8 0 0 0 16 0v-2a2 2 0 0 0-4 0v-1z"/></svg>')


def verify(name, html):
    return f'<!-- VERIFY: {name} -->{html}<!-- /VERIFY -->'


def picture(name, label, scale=None, w=417, h=876):
    """A drawn picture saved from the earlier page (scripts/site/*.html), inert."""
    inner = open(os.path.join(HERE, name + '.html')).read()
    if scale:
        inner = (f'<div style="width:{int(w*scale)}px;height:{int(h*scale)}px;overflow:hidden">'
                 f'<div style="width:{w}px;height:{h}px;transform:scale({scale});transform-origin:top left">{inner}</div></div>')
    return f'<div role="img" aria-label="{label}"><div inert aria-hidden="true">{inner}</div></div>'


def quick_log_card(s=1.0):
    return f'''<div role="img" aria-label="The Quick Log card on the Lock Screen: tonight, 2 wake-ups, last at 1:52 AM, with a Log button" style="box-sizing:border-box;width:{int(358*s)}px;padding:{int(16*s)}px;border-radius:{int(24*s)}px;background:{N_SURFACE};border:1px solid {N_LINE};color:{N_INK};display:flex;align-items:center;gap:{int(16*s)}px;font-family:var(--sans)">
<div style="flex-grow:1;display:flex;flex-direction:column;gap:{int(4*s)}px">
<span style="font-family:var(--serif);font-weight:500;font-size:{int(24*s)}px;line-height:1.2">Quick Log</span>
<span style="font-size:{int(15*s)}px;line-height:1.35;color:{N_MUTED}">Tonight: 2 wake-ups</span>
<span style="font-size:{int(13*s)}px;line-height:1.35;color:{N_MUTED}">Last at 1:52 AM</span>
</div>
<span style="display:flex;align-items:center;gap:{int(8*s)}px;height:{int(56*s)}px;padding:0 {int(20*s)}px;flex-shrink:0;border-radius:999px;background:{N_BUTTON};color:{N_ON_BUTTON};font-family:var(--serif);font-weight:500;font-size:{int(20*s)}px">{PALM.format(s=int(18*s))}Log</span>
</div>'''


def phone(screen, s=1.0):
    w, h = int(414 * s), int(868 * s)
    return f'''<div style="width:{w}px;height:{h}px;box-sizing:border-box;padding:{int(12*s)}px;border-radius:{int(58*s)}px;background:var(--mock-frame)">
<div style="position:relative;width:100%;height:100%;border-radius:{int(46*s)}px;overflow:hidden">{screen}
<div style="position:absolute;top:{int(14*s)}px;left:50%;transform:translateX(-50%);width:{int(124*s)}px;height:{int(36*s)}px;border-radius:999px;background:#000"></div>
</div></div>'''


def lock_phone(s=1.0):
    screen = f'''<div style="position:absolute;inset:0;background:linear-gradient(180deg,#3A3029 0%,#2A221C 60%,#1F1915 100%);color:{N_INK};font-family:var(--sans)">
<div style="position:absolute;top:{int(84*s)}px;left:0;right:0;text-align:center">
<div style="font-size:{int(20*s)}px;font-weight:500">Tuesday, October 6</div>
<div style="font-size:{int(92*s)}px;line-height:1.05;font-weight:600;letter-spacing:-2px">1:58</div>
</div>
<div style="position:absolute;left:{int(16*s)}px;right:{int(16*s)}px;bottom:{int(120*s)}px;display:flex;justify-content:center">{quick_log_card(s)}</div>
<div style="position:absolute;bottom:{int(10*s)}px;left:50%;transform:translateX(-50%);width:{int(134*s)}px;height:{int(5*s)}px;border-radius:999px;background:{N_INK};opacity:.8"></div>
</div>'''
    return phone(screen, s)


def update_phone(s=1.0):
    """A message to a partner and an email to the provider with the PDF report."""
    bubble = (f'<div style="align-self:flex-end;max-width:78%;padding:{int(10*s)}px {int(14*s)}px;border-radius:{int(20*s)}px;'
              f'background:var(--accent);color:var(--bg);font-size:{int(16*s)}px;line-height:1.35">'
              'Last night: 2 wake-ups, at 11:40 PM and 1:52 AM.</div>')
    email = f'''<div style="border-radius:{int(16*s)}px;background:var(--surface);border:1px solid var(--line);padding:{int(14*s)}px;display:flex;flex-direction:column;gap:{int(6*s)}px">
<span style="font-size:{int(12*s)}px;color:var(--muted)">To: Your provider</span>
<span style="font-size:{int(15*s)}px;font-weight:600">Cal’s report, Sep 29 – Oct 5</span>
<span style="font-size:{int(13*s)}px;color:var(--muted);line-height:1.35">Here’s how the last week went before Thursday’s visit.</span>
<span style="align-self:flex-start;display:flex;align-items:center;gap:{int(8*s)}px;margin-top:{int(4*s)}px;padding:{int(8*s)}px {int(12*s)}px;border-radius:{int(10*s)}px;background:var(--bg);border:1px solid var(--line);font-size:{int(13*s)}px">
<svg width="{int(16*s)}" height="{int(16*s)}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><path d="M6 2h9l5 5v15H6z"/><path d="M14 2v6h6"/></svg>Cali Care report.pdf</span>
</div>'''
    screen = f'''<div class="day" style="position:absolute;inset:0;background:var(--bg);color:var(--ink);font-family:var(--sans);padding:{int(70*s)}px {int(18*s)}px {int(24*s)}px;box-sizing:border-box;display:flex;flex-direction:column;gap:{int(14*s)}px">
<span style="font-size:{int(13*s)}px;color:var(--muted);text-align:center">Messages · to Dad</span>
{bubble}
<div style="align-self:flex-end;width:72%;border-radius:{int(18*s)}px;overflow:hidden;border:1px solid var(--line);background:var(--surface)">
<div style="padding:{int(12*s)}px {int(14*s)}px;display:flex;flex-direction:column;gap:{int(4*s)}px">
<span style="font-size:{int(11*s)}px;color:var(--muted)">Cal · Sep 29 – Oct 5</span>
<span style="font-family:var(--serif);font-weight:500;font-size:{int(18*s)}px;line-height:1.2">About the same as last week</span>
<span style="display:flex;gap:{int(4*s)}px;margin-top:{int(6*s)}px">{''.join(f'<i style="width:{int(14*s)}px;height:{int(14*s)}px;border-radius:3px;border:1px solid var(--muted);background:{c}"></i>' for c in ['#ECECD8','#CFD0A6','#ECECD8','#8F9156','#CFD0A6','#ECECD8','#CFD0A6'])}</span>
</div></div>
<span style="font-size:{int(12*s)}px;color:var(--muted);text-align:right">Delivered</span>
<span style="font-size:{int(13*s)}px;color:var(--muted);text-align:center;margin-top:{int(18*s)}px">Mail</span>
{verify('doctor-pdf', email)}
<span style="font-size:{int(13*s)}px;color:var(--muted);text-align:center;margin-top:{int(18*s)}px">Caregiver card · for Grandma</span>
<div style="border-radius:{int(16*s)}px;background:var(--bg);border:1px solid var(--line);padding:{int(14*s)}px;display:flex;flex-direction:column;gap:{int(6*s)}px;box-shadow:0 1px 2px rgba(0,0,0,.05)">
<span style="font-family:var(--serif);font-weight:500;font-size:{int(18*s)}px">Caring for Cal</span>
<span style="font-size:{int(13*s)}px;color:var(--muted);line-height:1.4">Bath at 7:00, then moisturizer.<br>Bedtime at 7:30. Call us anytime.</span>
</div>
</div>'''
    return f'<div role="img" aria-label="A text to Dad with last night\'s wake-ups, and an email to the provider with the Cali Care report attached">{phone(screen, s)}</div>'


def shot(src, alt, s=1.0):
    return f'''<div style="width:{int(414*s)}px;height:{int(868*s)}px;box-sizing:border-box;padding:{int(12*s)}px;border-radius:{int(58*s)}px;background:var(--mock-frame)">
<div style="width:100%;height:100%;border-radius:{int(46*s)}px;overflow:hidden"><img src="shots/{src}" alt="{alt}" style="width:100%;height:100%;display:block;object-fit:cover;object-position:top"></div>
</div>'''


STORY = ('I know what it’s like to go through life sleep deprived, just trying to make it through the day. '
         'Keeping track of flares and how my son reacts to different foods was one more thing on my plate. '
         'That’s why I built Cali Care: to make that part as easy as possible.')

FAQ = [
    ('Do I need an account?', 'No. Everything works on your phone without one. Sign in with Apple if you want to sync phones, share with a partner, or import a care plan.', None),
    ('Where is my child’s data stored?', 'On your phone. If you sign in, your logs also sync to our server so they’re on all your devices. Photos always stay on your phone, and you can export your data or delete your account at any time.', None),
    ('Does my doctor need the app?', 'No. You send them a PDF report by email or AirDrop.', 'doctor-pdf'),
]


def build(desk):
    m = '' if desk else '-m'
    pad = '120px' if desk else 'var(--gutter)'
    sec_pad = f'96px {pad}' if desk else f'56px {pad}'
    h1 = 'font-size:64px;line-height:70px' if desk else 'font-size:40px;line-height:46px'
    h2 = ('font-family:var(--serif);font-weight:500;font-size:44px;line-height:52px' if desk
          else 'font-family:var(--serif);font-weight:500;font-size:32px;line-height:38px')
    body = 'font-size:19px;line-height:30px' if desk else 'font-size:17px;line-height:26px'
    sc = 1.0 if desk else 0.8

    def P(text):
        return f'<p class="muted" style="margin:0;{body};max-width:520px">{text}</p>'

    def small(text):
        return f'<p class="t-caption muted" style="margin:0">{text}</p>'

    def feature(anchor, eyebrow, title, text_html, visual, flip=False, bg=''):
        text = (f'<div style="display:flex;flex-direction:column;gap:var(--s4)">'
                f'<span class="t-label" style="color:var(--accent)">{eyebrow}</span>'
                f'<h2 style="margin:0;{h2}">{title}</h2>{text_html}</div>')
        vis = f'<div style="display:flex;justify-content:center;align-items:center;gap:var(--s5);flex-wrap:wrap">{visual}</div>'
        bgs = f'background:{bg};' if bg else ''
        if desk:
            first, second = (vis, text) if flip else (text, vis)
            return (f'<section id="{anchor}" style="box-sizing:border-box;padding:{sec_pad};{bgs}display:grid;'
                    f'grid-template-columns:repeat(2, minmax(0, 1fr));gap:80px;align-items:center">{first}{second}</section>')
        return (f'<section id="{anchor}-m" style="box-sizing:border-box;padding:{sec_pad};{bgs}display:flex;'
                f'flex-direction:column;gap:var(--s5)">{text}{vis}</section>')

    out = []
    # Header
    if desk:
        out.append(f'''<header style="height:88px;box-sizing:border-box;padding:0 120px;display:flex;align-items:center;justify-content:space-between;border-bottom:var(--hairline) solid var(--line)">
<a href="#top" class="t-title" style="color:var(--ink);text-decoration:none">Cali Care</a>
<nav aria-label="Main" style="display:flex;align-items:center;gap:var(--s6)">
<a href="#plan" class="t-label" style="color:var(--ink);text-decoration:none">Care plan</a>
<a href="#updates" class="t-label" style="color:var(--ink);text-decoration:none">Updates</a>
<a href="{BETA}" class="t-label" style="height:44px;display:flex;align-items:center;padding:0 20px;border-radius:var(--r-btn);background:var(--ink);color:var(--bg);text-decoration:none">Join the beta</a>
</nav></header>''')
    else:
        out.append(f'''<header style="height:64px;box-sizing:border-box;padding:0 var(--gutter);display:flex;align-items:center;justify-content:space-between;border-bottom:var(--hairline) solid var(--line)">
<a href="#top-m" class="t-title" style="color:var(--ink);text-decoration:none">Cali Care</a>
<a href="{BETA}" class="t-label" style="height:44px;display:flex;align-items:center;padding:0 16px;border-radius:var(--r-btn);background:var(--ink);color:var(--bg);text-decoration:none">Join the beta</a>
</header>''')

    # 1. Hero
    hero_text = f'''<div style="display:flex;flex-direction:column;gap:var(--s5)">
<span class="t-label muted">For parents of kids with eczema</span>
<h1 style="margin:0;font-family:var(--serif);font-weight:500;{h1};letter-spacing:-0.5px">You focus on your child. Cali Care keeps track.</h1>
<p class="t-lede" style="margin:0;max-width:560px;{'' if desk else 'font-size:20px;line-height:28px'}">Turn your care plan into a daily checklist, log from your Lock Screen, and send a quick update to your doctor or sitter.</p>
<div style="display:flex;{'align-items:center' if desk else 'flex-direction:column;align-items:stretch'};gap:var(--s4);margin-top:var(--s2)">
<a href="{BETA}" class="t-label" style="height:56px;display:flex;align-items:center;justify-content:center;padding:0 28px;border-radius:var(--r-btn);background:var(--ink);color:var(--bg);text-decoration:none">Join the beta</a>
<a href="#plan{m}" class="t-label" style="min-height:44px;display:flex;align-items:center;justify-content:center;text-decoration:none">See how it works</a>
</div>
<span class="t-caption muted">Free on iPhone during the beta. No account needed.</span>
</div>'''
    hero_vis = f'<div style="display:flex;justify-content:center">{lock_phone(sc)}</div>'
    if desk:
        out.append(f'<section id="top" style="box-sizing:border-box;padding:96px 120px;display:grid;grid-template-columns:repeat(2, minmax(0, 1fr));gap:80px;align-items:center">{hero_text}{hero_vis}</section>')
    else:
        out.append(f'<section id="top-m" style="box-sizing:border-box;padding:48px var(--gutter) 56px;display:flex;flex-direction:column;gap:var(--s6)">{hero_text}{hero_vis}</section>')

    # 2. Care plan: bring it in (Plan)
    plan_text = (verify('plan-import', P('Take a photo of the care plan from your doctor or practitioner, or add it as a PDF. Cali Care turns it into a short list for the morning, afternoon, and bedtime, with your provider’s exact words a tap away.'))
                 + small('Importing a plan requires signing in.'))
    out.append(feature('plan', 'Care plan', 'Bring in your care plan.', plan_text,
                       shot('plan-day.jpg', 'Cali Care’s Plan screen: week 1 of 12, the next visit, and what’s coming up', sc),
                       flip=True, bg='var(--surface)'))

    # 3. To do
    todo_text = P('It counts skin-care rounds and shows which supplements to give when, so you don’t have to keep it all in your head.')
    out.append(feature('todo', 'To do', 'Your care plan, as a to-do list.', todo_text,
                       shot('todo-day.jpg', 'Cali Care’s To do screen: the care plan as a list for the morning, with the next step highlighted', sc)))

    # 4. Quick updates
    upd_text = (P('Keep your doctor and anyone who helps in the loop. Text last night’s wake-ups to your partner, or send a weekly summary card to family.')
                + verify('doctor-pdf', P('Before a visit, email your provider a PDF report with charts, a day-by-day view, and your notes. They don’t need the app.'))
                + P('A one-page card gives a babysitter or grandparent what they need to know.'))
    out.append(feature('updates', 'Updates', 'Send a quick update.', upd_text, update_phone(sc), flip=True, bg='var(--surface)'))

    # 5. Story
    out.append(f'''<section id="story{m}" style="box-sizing:border-box;padding:{sec_pad};display:flex;flex-direction:column;gap:var(--s5);{'align-items:center;text-align:center' if desk else ''}">
<h2 style="margin:0;{h2}">Why I built Cali Care</h2>
<p class="t-lede" style="margin:0;max-width:720px;{'' if desk else 'font-size:21px;line-height:30px'}">{STORY}</p>
<span class="t-body muted">— Matthew, dad and founder</span>
<!-- TODO: founder photo. Add <img src="shots/founder.jpg" alt="Matthew with his son"> here. -->
</section>''')

    # 6. Questions + Join the beta
    qs = ''
    for q, a, v in FAQ:
        d = (f'<details class="faq ledger-row" style="display:block;padding:var(--s4) 0"><summary class="{"t-title" if desk else "t-body"}" '
             f'style="min-height:44px;display:flex;align-items:center;justify-content:space-between;gap:var(--s4);{"" if desk else "font-weight:600"}">{q}'
             '<svg class="faq-chev" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true" style="flex-shrink:0;color:var(--muted)"><path d="m9 6 6 6-6 6"></path></svg></summary>'
             f'<p class="muted" style="margin:var(--s2) 0 0;font-size:17px;line-height:27px">{a}</p></details>')
        qs += verify(v, d) if v else d
    out.append(f'''<section id="faq{m}" style="box-sizing:border-box;padding:{sec_pad};background:var(--surface);display:flex;flex-direction:column;gap:var(--s6);align-items:center">
<div style="width:100%;max-width:760px;display:flex;flex-direction:column;gap:var(--s4)"><h2 style="margin:0;{h2}">Questions</h2><div class="ledger">{qs}</div></div>
<div style="display:flex;flex-direction:column;align-items:center;gap:var(--s3);text-align:center;margin-top:var(--s5)">
<h2 style="margin:0;{h2}">Try Cali Care free during the beta.</h2>
<p class="muted" style="margin:0;{body}">Available on iPhone, and it works offline.</p>
<a href="{BETA}" class="t-label" style="margin-top:var(--s3);height:56px;display:flex;align-items:center;padding:0 28px;border-radius:var(--r-btn);background:var(--ink);color:var(--bg);text-decoration:none">Join the beta</a>
</div>
</section>''')

    # Footer (unchanged)
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


if __name__ == '__main__':
    template = open(sys.argv[1]).read()
    html = template.replace('{DESK}', build(True)).replace('{MOB}', build(False))
    html = re.sub(r'<title>.*?</title>', '<title>Cali Care: eczema care plans, logging, and updates for parents</title>', html)
    html = re.sub(r'<meta name="description" content="[^"]*">', '<meta name="description" content="Turn your care plan into a daily checklist, log from your Lock Screen, and send a quick update to your doctor or sitter. Free on iPhone during the beta.">', html)
    html = re.sub(r'<!-- "A day with Cali Care".*?-->', '<!-- Built by scripts/site/gen_site.py in the site\'s look (tokens.css), with real app screenshots in shots/. -->', html, flags=re.S)
    open(sys.argv[2], 'w').write(html)
