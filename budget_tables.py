# Shared locked-budget tables and the paid-support menu, used by report + plan builders.
summary_rows = [
    ('France', '32,000', '11,000', '43,000', '~96,500'),
    ('UK',     '27,000', '8,000',  '35,000', '~83,300'),
    ('Iberia', '20,000', '9,500',  '29,500', '~67,200'),
    ('LATAM (MX)', '1,500', '1,000', '2,500', '~7,600'),
]
summary_total = ('All', '80,500', '29,500', '110,000', '~254,600')
search_rows = [
    ('France', [5000,3000,3000,5000,6500,6500,3000], '32,000', '~75,400'),
    ('UK',     [4000,2000,2000,4000,7000,7000,1000], '27,000', '~65,100'),
    ('Iberia', [3000,1500,1500,3000,4000,4000,3000], '20,000', '~54,300'),
    ('LATAM',  [200,100,100,200,400,400,100],         '1,500',  '~4,000'),
]
search_total = ('All', [12200,6600,6600,12200,17900,17900,7100], '80,500', '~199,000')
social_rows = [
    ('France', [200,0,0,2200,4000,4000,600], '11,000', '~21,100'),
    ('UK',     [150,0,0,1600,2900,2900,450], '8,000',  '~18,200'),
    ('Iberia', [200,0,0,2000,3500,3500,300], '9,500',  '~12,900'),
    ('LATAM',  [0,0,0,200,400,400,0],         '1,000',  '~3,600'),
]
social_total = ('All', [550,0,0,6000,10800,10800,1350], '29,500', '~55,800')
MONTHS = ['Jun','Jul','Aug','Sep','Oct','Nov','Dec']

def _f(n): return f'{n:,}' if n else '0'

def summary_table():
    h = ['Market','Paid search','Paid social','Total Jun-Dec','Full-year (approx)']
    out = ['<table class="money"><thead><tr>'+''.join(f'<th>{c}</th>' for c in h)+'</tr></thead><tbody>']
    for r in summary_rows:
        out.append('<tr>'+''.join(f'<td>{c}</td>' for c in r)+'</tr>')
    out.append('<tr class="total">'+''.join(f'<td>{c}</td>' for c in summary_total)+'</tr></tbody></table>')
    return ''.join(out)

def month_table(rows, total):
    h = ['Market']+MONTHS+['Jun-Dec','Full-year (approx)']
    out = ['<table class="months"><thead><tr>'+''.join(f'<th>{c}</th>' for c in h)+'</tr></thead><tbody>']
    for name, vals, jd, fy in rows:
        out.append('<tr>'+''.join(f'<td>{c}</td>' for c in [name]+[_f(v) for v in vals]+[jd,fy])+'</tr>')
    name, vals, jd, fy = total
    out.append('<tr class="total">'+''.join(f'<td>{c}</td>' for c in [name]+[_f(v) for v in vals]+[jd,fy])+'</tr>')
    out.append('</tbody></table>')
    return ''.join(out)

menu_rows = [
    ('Webinar or event',
     'Single-image Sponsored Content with a native LinkedIn Lead Gen Form to a broad ICP, synced to HubSpot; a reminder sequence and a post-event sequence carry the pipeline.',
     'Registrations to attendees to SQLs'),
    ('Whitepaper, guide or report (gated content)',
     'Lead Gen Form ad to a broad ICP plus retargeting of engaged users, into nurture; native form, not a landing page (about 26 euros vs about 84 euros per lead on the same offer in our data).',
     'Cost per lead and MQL rate'),
    ('Named-account or strategic push (ABM)',
     'Tier 1 only when sales provides 10 to 30 named logos; company-targeted Sponsored Content plus retargeting, high-touch.',
     'Meetings booked, not cost per lead'),
    ('Product or feature awareness',
     'Video or single-image to a broad ICP as a view-through layer that feeds retargeting, not a direct-response ask.',
     'Assisted pipeline and influenced opps, not clicks'),
    ('Brand and competitor defence',
     'Always-on, owned by paid (not a growth-team request), named here so it is understood as protected.',
     'Incremental branded and comparison conversions, proven by holdout'),
]
def menu_table():
    out = ['<table><thead><tr><th>Request type</th><th>Proven play</th><th>Judged on</th></tr></thead><tbody>']
    for a,b,c in menu_rows:
        out.append(f'<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>')
    out.append('</tbody></table>')
    return ''.join(out)
