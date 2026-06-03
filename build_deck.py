#!/usr/bin/env python3
# Edits the v15 deck into v17: rebuild budget slide, add AI-search slide and paid-support slide.
import copy, os
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR

SRC='sources/Paid_Media_Forward_Strategy_Deck_v15.pptx'
OUT='FINAL_v_current/Paid_Media_Forward_Strategy_Deck_v18.pptx'

PURPLE=RGBColor(0x2F,0x1E,0x4A)
PINK=RGBColor(0xC2,0x30,0x58)
GREY=RGBColor(0x6A,0x64,0x78)
BODY=RGBColor(0x3C,0x35,0x50)
WHITE=RGBColor(0xFF,0xFF,0xFF)

prs=Presentation(SRC)

def shape_by_name(slide,name):
    for sh in slide.shapes:
        if sh.name==name: return sh
    return None

def set_line(shape, text):
    """Replace text of a single-line shape, keeping the first run's formatting."""
    tf=shape.text_frame
    p=tf.paragraphs[0]
    for r in list(p.runs)[1:]:
        r._r.getparent().remove(r._r)
    if p.runs:
        p.runs[0].text=text
    else:
        p.add_run().text=text
    for extra in list(tf.paragraphs)[1:]:
        extra._p.getparent().remove(extra._p)

def style_run(run, size, bold, color, name='Calibri'):
    run.font.size=Pt(size); run.font.bold=bold; run.font.name=name
    run.font.color.rgb=color

def fill_cell(cell, fill=None):
    if fill is not None:
        cell.fill.solid(); cell.fill.fore_color.rgb=fill
    else:
        cell.fill.background()
    cell.margin_left=Inches(0.08); cell.margin_right=Inches(0.08)
    cell.margin_top=Inches(0.03); cell.margin_bottom=Inches(0.03)
    cell.vertical_anchor=MSO_ANCHOR.MIDDLE

def cell_text(cell, text, size, bold, color):
    tf=cell.text_frame; tf.word_wrap=True
    tf.clear()
    p=tf.paragraphs[0]
    r=p.add_run(); r.text=text
    style_run(r, size, bold, color)

# =====================================================================
# 1) BUDGET SLIDE (index 17)
# =====================================================================
bs=prs.slides[17]
set_line(shape_by_name(bs,'Text 1'),
         'Concentrated spend, funded by cutting waste and scaled as it proves out.')
set_line(shape_by_name(bs,'Text 2'),
         'Iberia social now sits ahead of UK social for the period. Top-ups beyond the firm 110,000 euro floor are staged and deployed only on confirmation.')

old=shape_by_name(bs,'Table 0')
L,T,W,H=old.left,old.top,old.width,old.height
old._element.getparent().remove(old._element)

summary=[
    ('Market','Paid search','Paid social','Total Jun-Dec','Full-year (approx)'),
    ('France','32,000','11,000','43,000','~96,500'),
    ('UK','27,000','8,000','35,000','~83,300'),
    ('Iberia','20,000','9,500','29,500','~67,200'),
    ('LATAM (MX)','1,500','1,000','2,500','~7,600'),
    ('All','80,500','29,500','110,000','~254,600'),
]
gf=bs.shapes.add_table(6,5,L,T,W,Inches(2.0))
tbl=gf.table
tbl.first_row=False; tbl.horz_banding=False
colw=[Inches(2.5),Inches(2.0),Inches(2.0),Inches(2.43),Inches(3.0)]
for i,w in enumerate(colw): tbl.columns[i].width=w
for ri,row in enumerate(summary):
    tbl.rows[ri].height=Inches(0.33)
    for ci,val in enumerate(row):
        c=tbl.cell(ri,ci)
        if ri==0:
            fill_cell(c, PURPLE); cell_text(c,val,10,True,WHITE)
        elif ri==5:
            fill_cell(c, RGBColor(0xEC,0xE9,0xF2)); cell_text(c,val,10.5,True,PURPLE)
        else:
            fill_cell(c, None)
            cell_text(c,val,10.5, ci==0, PURPLE if ci==0 else BODY)
        if ci>=1: c.text_frame.paragraphs[0].alignment=PP_ALIGN.RIGHT

# speaker notes
notes=("Budget. The June to December floor is firm at 110,000 euros, confirmed by leadership. Full-year paid is about 254,600 "
"(search about 199,000, social about 55,800). Envelope: paid scope was about 242,600 for the year before this plan, of which "
"roughly 144,600 was committed January to May; the 14,800 trade-media line is SEO and PR owned and out of paid scope. We hold "
"search market totals, trim Mexico to a token, and shift that budget plus the floor headroom into Iberia LinkedIn, so Iberia "
"social now sits ahead of UK social. Top-ups beyond the floor are staged and held off-slide: an extra 30,000 to 40,000 likely "
"soon, about 20,000 possible for Q4 from unused budget, and 55,000 from a cancelled event earmarked for UK ideas; deployed only "
"on confirmation, social growth-support and UK brand and comparison search first. The 45,000 non-recurrent LATAM line is closed "
"and redistributed. AI-search stat to land: AI Overviews now answer many broad queries in place, so those clicks fall and the "
"cost per click on high-intent terms rises, which is exactly why we concentrate on brand and comparison search.")
bs.notes_slide.notes_text_frame.text=notes

# =====================================================================
# clone helper
# =====================================================================
def clone_slide(src):
    layout=src.slide_layout
    ns=prs.slides.add_slide(layout)
    for shp in list(ns.shapes):
        shp._element.getparent().remove(shp._element)
    for shp in src.shapes:
        ns.shapes._spTree.append(copy.deepcopy(shp._element))
    return ns

def move_slide(slide, pos):
    sldIdLst=prs.slides._sldIdLst
    ids=list(sldIdLst)
    el=ids[-1]  # the just-added slide is last
    sldIdLst.remove(el)
    sldIdLst.insert(pos, el)

JUDGE_IDX=24

# =====================================================================
# 2) AI-SEARCH SLIDE (clone slide 24, after it)
# =====================================================================
ai=clone_slide(prs.slides[JUDGE_IDX])
set_line(shape_by_name(ai,'Text 0'),'HOW AI SEARCH CHANGES THE PLAN')
set_line(shape_by_name(ai,'Text 1'),'Buyers get answers without clicking, and shortlist inside assistants.')
for nm in ('Text 2','Table 0','Text 3'):
    sh=shape_by_name(ai,nm)
    if sh is not None: sh._element.getparent().remove(sh._element)

blocks=[
    ('What is happening',
     'AI answers resolve broad queries in place, so those clicks fall and the cost per click on the rest rises. Buyers shortlist inside assistants before they ever search.'),
    ('What we do in search',
     'Tilt to high-intent, brand and comparison terms where a click is genuinely incremental, and defend comparison terms.'),
    ('How we judge',
     'Incremental lift via holdout, not platform-reported conversions.'),
    ('Who owns AI-answer visibility',
     'SEO, content and PR own it; paid amplifies. Flagged for the wider team, not absorbed into paid.'),
]
gf=ai.shapes.add_table(2,2,Inches(0.7),Inches(2.1),Inches(11.93),Inches(4.0))
t=gf.table; t.first_row=False; t.horz_banding=False
t.columns[0].width=Inches(5.96); t.columns[1].width=Inches(5.97)
t.rows[0].height=Inches(2.0); t.rows[1].height=Inches(2.0)
for i,(head,body) in enumerate(blocks):
    c=t.cell(i//2, i%2)
    fill_cell(c, RGBColor(0xF4,0xF2,0xF8)); c.vertical_anchor=MSO_ANCHOR.TOP
    tf=c.text_frame; tf.word_wrap=True; tf.clear()
    p=tf.paragraphs[0]; r=p.add_run(); r.text=head; style_run(r,14,True,PURPLE)
    p2=tf.add_paragraph(); r2=p2.add_run(); r2.text=body; style_run(r2,11.5,False,GREY)
    p2.space_before=Pt(4)
move_slide(ai, JUDGE_IDX+1)  # -> index 25

# =====================================================================
# 3) PAID-SUPPORT SLIDE (clone slide 24, after AI-search)
# =====================================================================
ps=clone_slide(prs.slides[JUDGE_IDX])  # slide 24 unchanged, clone again
set_line(shape_by_name(ps,'Text 0'),'HOW PAID SUPPORTS THE GROWTH TEAM')
set_line(shape_by_name(ps,'Text 1'),'A menu of proven plays, each judged on pipeline.')
for nm in ('Text 2','Table 0','Text 3'):
    sh=shape_by_name(ps,nm)
    if sh is not None: sh._element.getparent().remove(sh._element)

menu=[
    ('Request type','Proven play','Judged on'),
    ('Webinar or event','Single-image Sponsored Content with a native Lead Gen Form to a broad ICP, synced to HubSpot, with reminder and post-event sequences.','Registrations to attendees to SQLs'),
    ('Whitepaper, guide or report (gated)','Lead Gen Form ad to a broad ICP plus retargeting, into nurture. Native form, not a landing page (about 26 vs 84 euros per lead in our data).','Cost per lead and MQL rate'),
    ('Named-account push (ABM)','Tier 1 only when sales provides 10 to 30 named logos: company-targeted Sponsored Content plus retargeting, high-touch.','Meetings booked, not cost per lead'),
    ('Product or feature awareness','Video or single image to a broad ICP as a view-through layer that feeds retargeting, not a direct-response ask.','Assisted pipeline and influenced opps'),
    ('Brand and competitor defence','Always-on, owned by paid (not a growth-team request), named here so it is understood as protected.','Incremental conversions, proven by holdout'),
]
gf=ps.shapes.add_table(6,3,Inches(0.7),Inches(2.0),Inches(11.93),Inches(4.1))
t=gf.table; t.first_row=False; t.horz_banding=False
t.columns[0].width=Inches(2.9); t.columns[1].width=Inches(6.43); t.columns[2].width=Inches(2.6)
for ri,row in enumerate(menu):
    t.rows[ri].height=Inches(0.68 if ri>0 else 0.34)
    for ci,val in enumerate(row):
        c=t.cell(ri,ci)
        if ri==0:
            fill_cell(c, PURPLE); cell_text(c,val,10,True,WHITE)
        else:
            fill_cell(c, RGBColor(0xF4,0xF2,0xF8) if ri%2==0 else None)
            cell_text(c,val,9.0, ci==0, PURPLE if ci==0 else BODY)
            c.vertical_anchor=MSO_ANCHOR.TOP
# footer line above the brand bar
tb=ps.shapes.add_textbox(Inches(0.7),Inches(6.4),Inches(11.93),Inches(0.4))
tf=tb.text_frame; tf.word_wrap=True
r=tf.paragraphs[0].add_run()
r.text='Search stays evergreen. Every play needs a working conversion and a tracked form before launch.'
style_run(r,11,True,PINK)
move_slide(ps, JUDGE_IDX+2)  # -> index 26
# messaging-discipline line in the support-menu speaker notes
ps.notes_slide.notes_text_frame.text=("Messaging is specific, substantiated and true to what the product does in each market: "
"claim only what is true and live per market, lead with substantiated proof, and cut generic claims for specific feature angles.")

# =====================================================================
# 4) MORE THAN ONE WAY IN (demo-alternative conversion paths), after support-menu
# =====================================================================
mw=clone_slide(prs.slides[JUDGE_IDX])
set_line(shape_by_name(mw,'Text 0'),'MORE THAN ONE WAY IN')
set_line(shape_by_name(mw,'Text 1'),'The demo stays primary. A step-down set of tracked paths captures the not-ready into nurture.')
for nm in ('Text 2','Table 0','Text 3'):
    sh=shape_by_name(mw,nm)
    if sh is not None: sh._element.getparent().remove(sh._element)
paths=[
    ('Path','Who it is for'),
    ('Book a demo (primary)','Buyers ready to talk to sales'),
    ('ROI or savings simulator','Buyers who want proof of value before a call'),
    ('Gated content (ebook, whitepaper, research)','Early-stage buyers researching the problem'),
    ('PDF brochure download','Buyers who want detail without a call'),
    ('Request a quote','Buyers price-checking, closer to a decision'),
]
gf=mw.shapes.add_table(6,2,Inches(0.7),Inches(2.0),Inches(11.93),Inches(3.6))
t=gf.table; t.first_row=False; t.horz_banding=False
t.columns[0].width=Inches(5.4); t.columns[1].width=Inches(6.53)
for ri,row in enumerate(paths):
    t.rows[ri].height=Inches(0.55 if ri>0 else 0.34)
    for ci,val in enumerate(row):
        c=t.cell(ri,ci)
        if ri==0:
            fill_cell(c, PURPLE); cell_text(c,val,10,True,WHITE)
        else:
            fill_cell(c, RGBColor(0xF4,0xF2,0xF8) if ri%2==0 else None)
            cell_text(c,val,11, ci==0, PURPLE if ci==0 else BODY)
            c.vertical_anchor=MSO_ANCHOR.MIDDLE
tb=mw.shapes.add_textbox(Inches(0.7),Inches(6.0),Inches(11.93),Inches(0.4))
r=tb.text_frame.paragraphs[0].add_run()
r.text='Demo stays primary. The alternatives feed nurture, scored lower, each tracked.'
style_run(r,11,True,PINK)
mw.notes_slide.notes_text_frame.text=("Demo stays the primary call to action. Each alternative is its own tracked conversion with a "
"value lower than a demo, so bidding never optimises to the cheapest, lowest-intent form-fill. Alternative-path leads feed nurture, "
"scored lower than a demo request, and are handed to sales only once nurture qualifies them, which protects the SDR team running "
"below target. A path goes live only where its tracked conversion and its nurture exit exist; until then it is planned, not live. "
"The assets (simulator, quote flow, brochure, gated content) are produced by web, content and RevOps; paid uses them as conversion "
"points and distributes them, it does not own asset production.")
move_slide(mw, JUDGE_IDX+3)  # -> index 27

os.makedirs('FINAL_v_current', exist_ok=True)
prs.save(OUT)
print('saved', OUT, 'total slides', len(prs.slides.__iter__.__self__._sldIdLst))
print('slide count', len(list(prs.slides)))
