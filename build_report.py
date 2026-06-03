#!/usr/bin/env python3
# Builds Report v22 HTML (rendered to PDF by wkhtmltopdf).
import os

CSS = open('doc_style.css').read()

# ---- locked budget data ----
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

def fmt(n): return f'{n:,}' if n else '0'

def summary_table():
    h = ['Market','Paid search','Paid social','Total Jun-Dec','Full-year (approx)']
    out = ['<table class="money"><thead><tr>'+''.join(f'<th>{c}</th>' for c in h)+'</tr></thead><tbody>']
    for r in summary_rows:
        out.append('<tr>'+''.join(f'<td>{c}</td>' for c in r)+'</tr>')
    out.append('<tr class="total">'+''.join(f'<td>{c}</td>' for c in summary_total)+'</tr>')
    out.append('</tbody></table>')
    return ''.join(out)

def month_table(rows, total):
    h = ['Market']+MONTHS+['Jun-Dec','Full-year (approx)']
    out = ['<table class="months"><thead><tr>'+''.join(f'<th>{c}</th>' for c in h)+'</tr></thead><tbody>']
    for name, vals, jd, fy in rows:
        cells = [name]+[fmt(v) for v in vals]+[jd, fy]
        out.append('<tr>'+''.join(f'<td>{c}</td>' for c in cells)+'</tr>')
    name, vals, jd, fy = total
    cells = [name]+[fmt(v) for v in vals]+[jd, fy]
    out.append('<tr class="total">'+''.join(f'<td>{c}</td>' for c in cells)+'</tr>')
    out.append('</tbody></table>')
    return ''.join(out)

# ---- paid support menu (compact, report version) ----
menu_rows = [
    ('Webinar or event',
     'Single-image Sponsored Content with a native LinkedIn Lead Gen Form to a broad ICP, synced to HubSpot, with a reminder sequence and a post-event sequence carrying the pipeline.',
     'Registrations to attendees to SQLs'),
    ('Whitepaper, guide or report (gated)',
     'Lead Gen Form ad to a broad ICP plus retargeting of engaged users, into nurture. Native form, not a landing page (about 26 euros against about 84 euros per lead on the same offer in our data).',
     'Cost per lead and MQL rate'),
    ('Named-account or strategic push (ABM)',
     'Tier 1 only when sales provides 10 to 30 named logos: company-targeted Sponsored Content plus retargeting, high-touch.',
     'Meetings booked, not cost per lead'),
    ('Product or feature awareness',
     'Video or single image to a broad ICP as a view-through layer that feeds retargeting, not a direct-response ask.',
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

# ---- section 8 remediation table ----
remediation = [
    ('Conversion signal at the event layer',
     'Lead MQL and Lead SQL events firing into Google, LinkedIn and Microsoft so campaigns can bid to a conversion. The critical path.',
     'Us + website-migration lead'),
    ('Site dataLayer contract (tag container)',
     'The migration changed the dataLayer that triggers the live conversion tags; restore it in the container and on the site. This is the outage, not an attribution fault.',
     'Us + website lead'),
    ('LinkedIn form-confirmation signal',
     'A confirmation parameter on submit so LinkedIn registers the conversion. Needs a short script on the blog page.',
     'Us to spec, RevOps to deploy'),
    ('UTM standard and the numeric-source break',
     'One cross-channel UTM convention, and correcting a numeric source value that mis-buckets paid leads in HubSpot.',
     'Us + RevOps'),
    ('Iberia account-based conversions',
     'Reactivate the inactive ebook-landing conversion and correct its source tagging.',
     'Us'),
    ('Legacy source re-map and sync overwrite',
     'Recover historic paid attribution and stop the Dynamics sync overwriting source. Verify on sample deals first.',
     'RevOps'),
]
def remediation_table():
    out = ['<table><thead><tr><th>Fix</th><th>What it unblocks</th><th>Owner</th></tr></thead><tbody>']
    for a,b,c in remediation:
        out.append(f'<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>')
    out.append('</tbody></table>')
    return ''.join(out)

# ====================================================================
HTML = f"""<!DOCTYPE html><html><head><meta charset="utf-8">
<style>{CSS}</style></head><body>

<h1>Paid Media and Lifecycle: Audit, Findings, and Forward Strategy</h1>
<div class="byline">Adrian Fernandez | 30 May 2026, revised 3 June 2026 | Working document</div>
<hr class="rule">

<h2>Executive summary</h2>
<p class="lead">This report reviews the paid media operation we inherited across Google, LinkedIn, Microsoft and Meta in the UK, Iberia, France and LATAM, and sets out how paid media and lifecycle nurture become one engine rather than two separate efforts.</p>
<p>Two findings frame everything that follows. The first is that paid is a stronger source of business than the day-to-day reporting suggests. Over the last twelve months it produced 120 marketing-sourced opportunities and 19 closed-won deals, which places it second by closed-won deals, behind only the demo-request bucket and ahead of website, events and email. The second is that almost everything holding paid back is fixable, and most of it without new budget. The audit found spend set for clicks rather than customers, a conversion signal that was not firing into the platforms, brand defence switched off for five months, and no nurture layer to convert the leads that were not ready to buy yet.</p>
<p>On budget, the framing has changed. The base rebuild and the reactivations are funded by redeploying what is wasted today, not by asking for more; the second-half plan then deploys a confirmed budget floor on top, which leadership is adding to as the rebuilt engine proves it can absorb spend for return. The recovery from cutting the identified waste is roughly 35,000 to 55,000 euros a year, on top of about 9,000 already saved by stopping a failed campaign.</p>
<div class="callout">One principle governs how we judge paid from here: we measure it on incremental lift, proven by holdout, not on platform-reported conversions, and we move budget to where the lift is real.</div>
<p>The sections below cover where paid stands among our sources, the findings and their root causes, the platform-by-platform detail, the money, the forward plan, and the expansion motion that grows the customers we already have.</p>

<h2>How to read this, and where the numbers come from</h2>
<p>The windows differ by necessity. Google and Microsoft figures come from a 90-day audit window, annualised where stated. Meta figures come from a 17-month export, because that is the period over which the account ran. The opportunity, pipeline and won-deal figures come from the last twelve months in Dynamics, the system in which sales actually work deals, covering 875 marketing-sourced opportunities created between 28 May 2025 and 28 May 2026.</p>
<p>One note on the source figures, because it matters later. A separate filtered view of the same Dynamics data, shared earlier, shows smaller totals and ranks paid third by pipeline value. That view and the full trailing-twelve-month export do not reconcile on the number of opportunities they include, which points to a different window or filter behind it. This report uses the full export, which can be reproduced line by line. Confirming the basis of the filtered view is an open item, noted again at the end.</p>

<h2>1. Where paid stands among our sources</h2>
<p>Grouped by pipeline value, paid sits fourth among marketing sources over the last twelve months. That is the least flattering way to read it, and it is worth stating plainly before making the case that it understates paid. Request a Demo is a last-touch bucket, not an acquisition channel: it holds demand other channels created.</p>
<p>Two things make the value ranking misleading. The first is the bucket sitting on top of it. "Request a Demo" is not an acquisition channel, it is a last-touch destination: it records where an opportunity was sitting when it converted, not what created the demand. A large share of those 394 opportunities are paid, event and website visitors who finally filled in a demo form. Counting it as a source flatters it and starves the channels that actually fed it. The second is that pipeline value counts opportunities created, not business won, and on that measure the order changes sharply.</p>
<p>When you look at deals actually closed, paid is second only to the demo-request bucket, and it is comfortably ahead of website, events and email. The clearest way to see why is win rate, the share of each source's opportunities that convert to won business.</p>
<table class="money"><thead><tr><th>Source</th><th>Opportunities</th><th>Pipeline value</th><th>Won deals</th><th>Win rate</th></tr></thead><tbody>
<tr><td>Request a Demo (last-touch bucket)</td><td>394</td><td>&euro;6.04M</td><td>62</td><td>15.7%</td></tr>
<tr><td>Marketing Event</td><td>138</td><td>&euro;1.73M</td><td>7</td><td>5.1%</td></tr>
<tr><td>Marketing Email</td><td>120</td><td>&euro;1.37M</td><td>2</td><td>1.7%</td></tr>
<tr><td>Paid (search + social)</td><td>120</td><td>&euro;1.05M</td><td>19</td><td>15.8%</td></tr>
<tr><td>Website</td><td>81</td><td>&euro;0.66M</td><td>13</td><td>16.0%</td></tr>
</tbody></table>
<div class="caption">Marketing-sourced opportunities, Dynamics, trailing 12 months. Win rate is won deals divided by opportunities.</div>
<p>Paid converts at 15.8 percent, essentially the same as website (16.0) and the demo bucket (15.7), and far above events (5.1) and email (1.7). Marketing email is the sharpest contrast: it carries more pipeline value than paid, 1.37 million euros against 1.05 million, but it has produced only 2 won deals against paid's 19. So the channels ranked above paid on pipeline value are, with the exception of the last-touch demo bucket, weaker than paid at turning that pipeline into revenue. On the measure that pays the bills, paid is second by closed-won deals.</p>
<h3>Why paid still looks small in the day-to-day reports</h3>
<p>If paid is second by closed-won deals, why does it read as minor in HubSpot's standard source reports? Because of three breaks in the reporting layer, all of them upstream of the HubSpot attribution model, which is itself sound.</p>
<p>The first is legacy option IDs. Historic deals store their source under IDs from an earlier version of the source dropdown. The label still displays correctly when you open a record, so it looks fine, but reports that group by source match on the current IDs and read those older deals as blank. The second is that deal source is written by the Dynamics sync rather than by tracked web activity, so without consistent UTMs in place a genuine paid lead can arrive in HubSpot with no campaign attached. The third is last-touch attribution: a paid click that converts weeks later on a demo form is credited to the demo, not to paid, which is the same effect that inflates the demo-request bucket.</p>
<p>None of these is a flaw in how attribution was designed. They are a reorganised picklist and a sync behaviour sitting in front of a sound model. The fix is a one-time re-map that reads each deal's correct label and rewrites it to the current option ID, which would recover almost the entire history. This needs verifying on a sample of deals before it is relied on, by checking the property change history, and it sits with RevOps with marketing sponsoring it. Roughly 10,900 main-pipeline deals currently read blank for this reason, and about 25,000 across all pipelines, so the upside of fixing it is large.</p>
<p>There is a fourth effect, and it is operational rather than a reporting break. Today only the Request a Demo form auto-routes a lead to an SDR. Every other form a paid lead can fill, a whitepaper or guide download, an event registration, a product-page enquiry, creates an event in HubSpot and then nothing happens to it. So a real share of the demand paid pays to capture is never worked and never progresses, which means it never shows up as paid-sourced pipeline either. That gap is addressed in the forward plan, and it is part of why paid reads smaller than it is.</p>

<h2>2. The seven findings, and the three causes behind them</h2>
<p>The audit produced seven findings that matter. They are easier to act on grouped by the three root causes they trace back to, because fixing the causes stops the individual problems recurring.</p>
<p><strong>Money pointed at the wrong target.</strong> Bidding across the top-spending campaigns was set to Maximize Clicks, which buys the most clicks for the budget regardless of whether those clicks convert, and on Meta 73 percent of spend ran on Traffic and Awareness objectives rather than lead generation. Budget also went to products a market cannot sell: Workforce campaigns running in France, and a LATAM Workforce campaign nested inside the Spain account, both against the actual product-market map. This is findings two and four.</p>
<p><strong>Results were invisible.</strong> The lead conversion events were not firing reliably into the ad platforms, and a main Meta pixel sat dead for about four weeks. The root cause sits upstream of the platforms and of attribution: the website migration changed the dataLayer contract those conversions depend on, so the conversion actions are live but stopped being triggered. When the conversion signal is broken, good and bad spend look identical, the platforms cannot steer toward conversions even if asked to, and nobody can see which campaigns are working. Alongside this, source attribution was under-reporting paid for the reasons in the previous section. This is findings one and six.</p>
<p><strong>Demand was wasted after capture.</strong> Paid generated leads, but there was no nurture layer to work the ones that were not ready to buy on first contact. In B2B SaaS most buyers are not, so a lead that fills a form and then hears nothing goes cold. This is finding seven, and it is the one that matters most for the forward plan, because it is the difference between paid as a lead source and paid as a pipeline source.</p>
<p>Two further findings are execution misses that the rebuild corrects directly rather than root causes. Brand defence on Mapal's own branded search was paused on both Google and Microsoft in the UK for five months, leaving the cheapest converting campaign in the account, 13.64 euros per conversion across 162 conversions, switched off while competitors bid on the brand unopposed. And narrow, hand-built audiences consistently underperformed broad, correctly-targeted ones: on LinkedIn the same French offer through the same lead form produced zero leads from a narrow 3,400-person list that was half the wrong vertical, against three leads at 148 euros each from a broad 22,000-person audience, and native lead forms came in roughly three times cheaper than the same offer sent to a landing page.</p>

<h2>3. The platform audit</h2>
<p>The same pattern, click volume on a broken conversion signal, shows up across all four platforms, but the specifics and the fixes differ by platform and market.</p>
<h3>Google Ads</h3>
<p>Google is the largest spend and the clearest case. The year-on-year picture is the headline: across the three markets, cost rose sharply while conversions fell.</p>
<p>In Spain and LATAM, nine of the ten top-spending campaigns ran on Maximize Clicks. The Workforce-ES search campaign spent 7,305 euros for a single conversion, with 6,593 of that on mobile for none, while a defunct "Compra" conversion was still set as the primary goal so the bidder was partly aiming at an event that no longer exists. The fix is to move the flagship onto conversion bidding into a working Lead MQL event, cap the secondary products, and either fence or switch off Display, which was running with no placement exclusions. The negative-keyword hygiene was the one bright spot, four product-segmented lists in active use.</p>
<p>In France, the product focus was right, Easilys is the correct French flagship, but the execution diluted it across twelve overlapping "Scale" variants that split the budget and the conversion signal twelve ways. Roughly 9,160 euros, 44 percent of the French Google budget, ran across 52 keywords that were off the core play. The conversion layer itself was broken, with 18 of 29 actions in a Removed state and four removed actions still flagged as primary. The fix is to consolidate to one search campaign and one Performance Max, both feeding a single clean conversion. Performance Max already converts when the signal reaches it, which tells us the offer works.</p>
<p>In the UK, generic terms ran on Maximize Clicks at zero conversions, the Flow training campaign spent 3,445 euros for none, while brand defence, the cheapest converter in the account, sat paused since early December. There are no negative-keyword lists at all and roughly 69,000 placement exclusions attached to nothing. The single biggest lever here is simply turning brand defence back on.</p>
<h3>LinkedIn Ads</h3>
<p>LinkedIn ran narrow account lists below the platform's delivery threshold, and the controlled comparison described in the findings, narrow versus broad on the same offer, is the clearest evidence in the whole audit that broad, correctly-targeted audiences win. A ready 1.28-million-member French matched audience sat unused while the narrow wrong-vertical list ran. The infrastructure is healthy, the Insight Tags fire on all three accounts, and the UK training-to-execution creative is reusable. The fix is broad ICP audiences above the 50,000 floor with native lead forms, and leaving narrow account targeting to sales sequencing rather than paid.</p>
<h3>Microsoft Ads</h3>
<p>Microsoft is effectively a new channel rather than a fix. The UK account is entirely paused, roughly 393 euros a day of capacity sitting idle, and it was configured with a 6-euro target cost per acquisition on software that sells for 100 to 400 euros, a Helsinki time zone, and euros instead of pounds. The French side is 42 campaigns auto-imported from Google on Maximize Clicks, with the Audience Network alone taking 31 percent of French Microsoft spend for almost nothing, and the best curated negative-keyword list in the account, 250 keywords, attached to zero campaigns. The French Easilys brand term does convert at around 143 euros. The right framing is to decide what Microsoft should be, brand defence plus high-intent, and to open a Spain account, which does not exist today.</p>
<h3>Meta Ads</h3>
<p>Meta ran for 17 months and spent 14,958 euros for about 108 leads, with 73 percent of that, roughly 10,857 euros, on Traffic and Awareness objectives rather than leads. The Audience Network leaked 3,421 euros, the main pixel was dead for about 27 days, and four other pixels are inactive. The one thing that worked is the native lead form, which captured leads at roughly three times the efficiency of the landing-page route, 26 euros against 84. That efficiency has not yet been traced through to closed pipeline, and the form cost regressed from 26 euros in its first version to 55 in its second, so the next step is to trace those 108 leads to deals and diagnose the regression before scaling. France stays the live base.</p>

<h2>4. The waste, and what we get back</h2>
<p>The audit identified roughly 26,000 euros of waste over the 90-day window, which annualises to about 105,000 euros if the pattern continues. The largest items are concentrated in a handful of campaigns. Applying confidence haircuts, higher for clear-cut waste and lower for items that need confirmation, gives a realistic recovery of 67,410 euros a year. The number to use externally is more conservative still, to allow for execution risk and cost-per-click inflation. The reactivations and the rebuild are funded by redeploying what is currently wasted.</p>
<table class="money"><thead><tr><th>Item</th><th>Platform / market</th><th>90-day</th><th>12-mo run-rate</th><th>Recovery</th><th>Confidence</th></tr></thead><tbody>
<tr><td>Workforce-ES search, mobile</td><td>Google / Spain</td><td>&euro;6,593</td><td>&euro;26,755</td><td>&euro;22,742</td><td>High</td></tr>
<tr><td>France keyword spread (12 variants)</td><td>Google / France</td><td>&euro;9,160</td><td>&euro;37,160</td><td>&euro;20,438</td><td>Medium</td></tr>
<tr><td>Hospitality Jobs audience (mismatch)</td><td>Google / UK + FR</td><td>&euro;5,356</td><td>&euro;21,737</td><td>&euro;11,955</td><td>Medium</td></tr>
<tr><td>Spain Display (4 campaigns)</td><td>Google / Spain</td><td>&euro;3,156</td><td>&euro;12,806</td><td>&euro;7,043</td><td>Medium</td></tr>
<tr><td>Microsoft Audience Network</td><td>Microsoft / France</td><td>&euro;901</td><td>&euro;3,656</td><td>&euro;2,011</td><td>Medium</td></tr>
<tr><td>Microsoft Workforce (4, off-map)</td><td>Microsoft / France</td><td>&euro;785</td><td>&euro;3,185</td><td>&euro;2,707</td><td>High</td></tr>
<tr><td>Easilys without negative list</td><td>Microsoft / France</td><td>n/a</td><td>n/a</td><td>&euro;400</td><td>Medium</td></tr>
<tr><td>Competitor brand bids</td><td>Microsoft / UK</td><td>&euro;94</td><td>&euro;381</td><td>&euro;114</td><td>Low</td></tr>
<tr class="total"><td>Total realistic recovery</td><td></td><td>&euro;26,045</td><td>&euro;105,680</td><td>&euro;67,410</td><td></td></tr>
</tbody></table>
<p>Two honesty notes. Meta's Audience Network leak of 3,421 euros is a 17-month figure on a different clock, so it is kept out of the 90-day total rather than stacked on it. And the larger Meta number, the roughly 10,857 euros on the wrong objectives, is not counted as waste at all: it bought real clicks, it was simply pointed at the wrong goal, so it is budget to redeploy rather than money lost.</p>

<h2>5. The forward engine: paid and nurture as one loop</h2>
<p>The single most valuable change is not more spend, it is building the nurture and remarketing layer that did not exist before, because it works demand we have already paid to create.</p>
<p>The loop is straightforward. Paid search and lead forms capture the lead. HubSpot segments it by product and market and by what brought it in. A nurture sequence works the leads that are not yet ready, while paid remarketing keeps the brand present between emails so the lead does not go cold. When the lead shows real intent, pricing or demo-page activity, its score crosses a threshold and it is routed to sales as a warm hand-off rather than a cold one. The outcome, won or lost, feeds back into the audiences and the bidding so the system learns from actual revenue.</p>
<p>The behavioural segments and the nurture sequences can be built now, because they have no dependency on the tracking fix. Syncing those segments out to the ad platforms for remarketing, and building revenue-based lookalikes, comes once the conversion tracking is healthy. The stages and what triggers each one are below.</p>
<table><thead><tr><th>Stage</th><th>Trigger</th><th>What runs</th><th>Goal</th></tr></thead><tbody>
<tr><td>New paid lead</td><td>Form fill from a paid click, not a demo</td><td>Tag the source, send a welcome and relevant content by product and market</td><td>Establish relevance fast</td></tr>
<tr><td>Engaged, not ready</td><td>Content downloads, repeat visits</td><td>Sequenced nurture by segment, branched on what brought them in</td><td>Move toward sales-ready</td></tr>
<tr><td>Showing intent</td><td>Pricing or demo-page views, email clicks</td><td>Lead score crosses threshold, priority routing, sales alerted</td><td>Hand over warm, not cold</td></tr>
<tr><td>Active in nurture</td><td>In any segment</td><td>Paid remarketing stays present across Google, LinkedIn, Meta</td><td>Stop the lead going cold between emails</td></tr>
<tr><td>Closed or disqualified</td><td>Sales outcome recorded</td><td>Outcome feeds back to audiences and bidding</td><td>The loop learns from real revenue</td></tr>
</tbody></table>
<h3>The routing gap this loop had to close, now largely closed</h3>
<p>The loop only works if a captured lead actually moves, and until recently most non-demo leads did not: only the demo form auto-routed to an SDR, and every other form a paid lead fills created an event in HubSpot and then sat. That has now changed. A central routing workflow is live that creates, qualifies and routes the non-demo leads to an owner, splits current customers to Customer Success, suppresses duplicates against any open lead, and blocks the clear non-fits such as non-hospitality and very small companies. For paid that closes the worst dead-end: the leads we pay to capture are now created and routed rather than lost.</p>
<p>Two gaps remain, and both are small. SDRs are alerted by email only for demo requests, so a routed content or event lead can still sit if nobody is prompted to work it; the fix is a light working signal on the non-demo paid leads, a shared queue view or a daily digest rather than a per-lead alarm, raised with RevOps and the SDR side. And paid leads need a clean paid-source label on entry so they are visible and reportable through the routed flow, which is ours to set.</p>

<h3>What paid supports for the growth team</h3>
<p>Paid does not only find strangers; it turns the growth team's own activity into pipeline. The way it does that is a defined service menu, not a case-by-case scramble: each request type has a proven setup and one metric it is judged on, so supported activity generates pipeline rather than spend. The boundary is simple, search stays evergreen intent capture and is never spent to promote an event or asset, and every supported campaign needs a working conversion and a tracked form in place before it goes live. The compact menu is below; the full playbook, with the boundaries and the working-with-paid rules, is in the Plan.</p>
{menu_table()}

<h2>6. Growing the customers we already have</h2>
<p>The forward engine in section 5 turns strangers into customers. This section extends it to the customers we already have, the third loop the plan carves out and points to whenever the acquisition audiences suppress current customers. Acquisition wins the logo; expansion grows it. In a multi-module business the cheapest pipeline we have is the base we already serve, because the relationship and the data already exist and existing customers convert far better than cold prospects.</p>
<p>Two motions. Cross-sell is a customer on one module taking an adjacent one. Up-sell is growing what they already have: more sites across the estate, more seats, a higher tier, a longer term. Both are measured as expansion revenue and net revenue retention, not new-logo pipeline, and neither competes with acquisition for budget because the audiences are the customers we already hold.</p>
<table><thead><tr><th>Current product (entry)</th><th>Natural next module</th><th>The angle</th></tr></thead><tbody>
<tr><td>Flow (UK, hotels)</td><td>Compliance, then Engage</td><td>Close the compliance and audit gap on teams already trained. Flow and Compliance are often bought together.</td></tr>
<tr><td>Workforce (Iberia)</td><td>Compliance + Engage</td><td>The compliance and engagement layer on the same teams whose scheduling and labour cost are already solved.</td></tr>
<tr><td>Easilys (France)</td><td>Flow</td><td>Bring training and onboarding into a kitchen operation that already runs on Easilys.</td></tr>
<tr><td>Key Accounts</td><td>MapalOS consolidation</td><td>More modules on one operating system, one login, one data layer. The largest-account expansion play.</td></tr>
</tbody></table>
<p>Marketing owns the demand layer: a customer-only nurture stream, renewal sequences at 90, 60 and 30 days, and customer-match ads that surface the right module at the right moment. It then hands a qualified expansion signal to the account owner. Customer Success and account management own the sale. One hard rule sits above everything: only green-health accounts get an expansion ask, and an at-risk account is a save rather than a sell. This is a post-launch Q3 build, gated on two data feeds beyond the acquisition tracking work, both targeted Q3: product-usage into the CRM (owner: RevOps) and the account-health score exposed to marketing (owner: Customer Success). It is judged on incremental lift, proven against a held-out set of matched green-health accounts, the same discipline section 8 sets for acquisition spend.</p>

<h2>7. The rebuild, the budget, and the ABM tiers</h2>
<p>The rebuild concentrates the current sprawl into roughly 33 campaigns, about four on Google, three on LinkedIn, two on Microsoft and three on Meta per active market, each funded above the platform's learning threshold, each with one flagship product per market, and each measured on a working conversion. One person can run weekly hygiene across 33 focused campaigns. The current spread cannot be managed properly by anyone.</p>
<p>The base rebuild and the reactivations are funded by redeploying what is wasted today, not by asking for more. On top of that, the second-half plan deploys a confirmed budget floor, a disciplined base that leadership is adding to as the rebuilt engine proves it can absorb spend for return. For June to December the floor is firm at 110,000 euros. Search market totals are held and reshaped within campaigns rather than grown; the Mexico line is trimmed to a token, and that budget plus the floor headroom shifts into Iberia LinkedIn, which makes Iberia social larger than UK social for the period. Brand defence on the UK and French brand is a named, protected slice within search: it is the cheapest converter in the account and was switched off for five months. In-housing three external retainers banks about 17,760 euros a year, kept as a line.</p>
<p>For context on scope: paid (search plus social) was about 242,600 euros for the year before this second-half plan, of which roughly 144,600 was committed January to May; the separate 14,800 trade-media line is SEO and PR owned and sits outside paid scope. Full-year paid lands at about 254,600 euros, search about 199,000 and social about 55,800. The 45,000 non-recurrent LATAM line is closed and redistributed, so LATAM is a token line only.</p>
<p>Beyond the floor, further budget is staged and deployed only on confirmation, social growth-support and UK brand and comparison search first, so the plan can absorb more as the engine proves out without committing it before it is needed.</p>
<h4>Market summary, Jun to Dec (euros)</h4>
{summary_table()}
<h4>Paid search by month (euros)</h4>
{month_table(search_rows, search_total)}
<h4>Paid social by month (euros)</h4>
{month_table(social_rows, social_total)}
<div class="tag-defs">Paid Search = Google + Microsoft/Bing. Paid Social = LinkedIn + Meta. The shape follows the season: a summer floor with near-zero social in July and August, a September ramp (a September lead typically closes in October or November), an October and November peak, and a low December.</div>
<p>Within each platform, budget splits between always-on evergreen activity and a ring-fenced growth-support share for the growth team's events, webinars and content. Search stays entirely evergreen, because intent capture should never be sacrificed to promote an activity. All always-on demand generation lives in evergreen, including the account-based tiers below, which run year-round. The split is roughly 70/30 on LinkedIn and 75/25 on Meta, with Google and Microsoft fully evergreen, and the growth share is a ceiling, not a floor: if it is not used it reverts to evergreen.</p>
<p>Account-based marketing is rebuilt in three tiers rather than as the narrow lists that underperformed. The top tier is a small set of named accounts, 10 to 30 logos, run one-to-one and measured on meetings booked. The middle tier, the workhorse, is best-fit segments built into audiences above the 50,000 threshold and measured on cost per lead through to pipeline. The base tier is broad ICP plus lookalikes, feeding the top of the funnel at the lowest cost. The earlier account-based work underperformed on mechanics, tiny lists and no nurture, not on the idea, and this keeps the intent while fixing the mechanics. Because all three tiers run year-round, they sit in the evergreen budget rather than drawing on the growth-support share, and the unused 1.28-million-member French audience becomes the base.</p>

<h2>8. Competition, sequence, and how we measure it</h2>
<p>The competitive read changes where budget should point, because the set we actually compete against is not the one assumed in HQ thinking. In France, Lightspeed tops the auctions at around 52 percent, with Skello consistently present: it is a point-of-sale and Easilys fight, which is the argument for keeping Workforce out of the French paid mix. In Iberia, the live competitors are HR and payroll tools such as factorial and tramitapp rather than point-of-sale, so Workforce stays but the messaging competes on the HR axis. In the UK, the set skews to LMS and training tools such as Absorb, which puts Flow's training-to-execution angle on the right axis. The workforce-management names HQ assumes, such as Fourth and Deputy, barely appear in any auction, so we plan against the competition we can actually see, and brand defence matters most where rivals bid on our terms, which is confirmed on French Bing.</p>
<p>The work is not blocked. Native lead forms can capture leads now, and the dependencies govern measurement and smarter bidding rather than whether we can run at all. The 90-day sequence runs from stabilising in the first two weeks, to replatforming bid strategy as tracking lands, to replicating the lead-form model and standing up nurture, to building out the newer surfaces.</p>
<table><thead><tr><th>Phase</th><th>Days</th><th>What happens</th></tr></thead><tbody>
<tr><td>Stabilise</td><td>0-14</td><td>Brand defence back on, kill the clear waste, fix conversion goals, Audience Network exclusions</td></tr>
<tr><td>Replatform</td><td>15-30</td><td>Move from Maximize Clicks to conversion bidding as tracking lands, consolidate Easilys</td></tr>
<tr><td>Replicate</td><td>31-60</td><td>Lead-form model to UK and Spain, first nurture sequences live, audiences syncing</td></tr>
<tr><td>Build</td><td>61-90</td><td>Spain Microsoft account, France landing page, remarketing on populated audiences</td></tr>
</tbody></table>
<p>Four things have to happen, in order: the conversion-signal fix, which is the critical path the bidding switch waits on and which sits with us and the website-migration lead, because the campaign conversions are live but the site migration changed the dataLayer contract that triggers them, so the fix is in the tag container and on the site, not in attribution; the cross-channel UTM standard, in progress; the legacy source re-map and the Dynamics source-overwrite, which sit with RevOps and need verifying on sample deals first; and leadership sign-off on consolidating the campaign count, because cutting campaigns reads as doing less without the rationale behind it.</p>
<p>One operational constraint shapes how the nurture-to-SDR routing is enforced. The latest pipeline review shows SDR outbound running at about 63 percent of target, roughly 87,000 against 138,000 euros, on small weekly targets and real load. A rigid speed-to-lead rule on a team already behind would create noise and resentment and get ignored. So paid leads get queue priority and a daily monitoring report with soft escalation, not a punitive timer. It moves behaviour where it matters, protects the relationship with a stretched team, and can be tightened to a hard service level later if the soft version is not enough.</p>

<h3>How AI search changes where paid points</h3>
<p>AI Overviews now answer broad and informational queries in place, so those clicks fall and the cost per click on what remains rises. At the same time B2B buyers increasingly build their shortlist inside AI assistants such as ChatGPT and Perplexity before they ever run a search. Both effects push the same way: they reinforce consolidating spend onto high-intent, brand and comparison terms, where a click is genuinely incremental, and judging that spend on incremental lift rather than on raw volume. Being cited in AI answers matters, but it is SEO, content and PR owned, with paid amplifying rather than buying it. We flag it here for the wider team; it is not absorbed into paid.</p>

<h3>How we judge paid, and the brand-defence case</h3>
<p>One principle now governs how we judge paid going forward, and it sharpens the brand-defence case rather than weakening it. Platform-reported conversions over-count, because a paid click that would have happened anyway, for free, is not new business. So we reactivate brand defence, but we treat its value as a hypothesis to test rather than an article of faith. The strongest version of that hypothesis is where competitors bid on our terms, which is confirmed on French Bing: there, a branded click we would otherwise lose to a rival is genuinely incremental, and defending it is worth real money. We prove it with a geo holdout, brand defence switched on where rivals bid our brand and off in a comparable market where they do not, comparing branded conversions over four to six weeks. If the conversions hold steady with paid off, the spend was not incremental and the budget moves to where lift is real. The standard this sets applies to every channel: we judge paid on incremental lift, measured by holdout, not on platform-reported conversions. The discipline comes from large-scale holdout testing in the industry, most famously the Uber case, where a single set of experiments reallocated roughly 35 million dollars once it showed how much cheap last-click spend was buying conversions that would have arrived anyway. We would rather move budget to where the lift is real than spend because the budget exists.</p>

<h3>The tracking and attribution fixes, by owner</h3>
<p>The HubSpot attribution design itself is sound; every break here is upstream of it. The fixes below are provisional, written so the genuine cross-team items can be raised as their own tickets.</p>
{remediation_table()}

<h2>Open items</h2>
<p>Two things remain to confirm before this goes outside the team. The first is the basis of the filtered source view that shows paid third by value and smaller totals, so its window and filter can be reconciled with the full export this report uses. The second is tracing Meta's roughly 108 leads through to closed pipeline, which is what would turn the native-lead-form efficiency from a cost story into a revenue one. Neither changes the central finding: on closed business over the last twelve months, paid is second by closed-won deals, and it has been under-credited rather than underperforming.</p>
<p>One option worth holding, surfaced by the attribution work: because Dynamics holds clean source for every channel, not just paid, a full-funnel marketing-source view could be built straight from Dynamics without waiting on the HubSpot connector. It is not part of this plan, but it is the most useful thing the attribution review turned up.</p>

</body></html>"""

os.makedirs('build', exist_ok=True)
open('build/report_v22.html','w').write(HTML)
print('report HTML written', len(HTML), 'chars')
