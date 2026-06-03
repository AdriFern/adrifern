#!/usr/bin/env python3
# Builds Plan v11 HTML (rendered to PDF by wkhtmltopdf).
import os
from budget_tables import summary_table, month_table, menu_table, search_rows, search_total, social_rows, social_total

CSS = open('doc_style.css').read()
DEFS = ('<div class="tag-defs">Paid Search = Google + Microsoft/Bing. Paid Social = LinkedIn + Meta. The shape follows the season: '
        'a summer floor with near-zero social in July and August, a September ramp (a September lead typically closes in October or '
        'November), an October and November peak, and a low December.</div>')

def boundaries():
    items = [
        'Paid does not support on search for growth-team activity. Search stays evergreen intent capture and is never spent to promote an event or asset.',
        'Every supported campaign needs a working conversion and a tracked form in place before it goes live.',
        'The growth-support budget is a ceiling, not a floor. Unused, it reverts to evergreen.',
        'We run campaigns in Campaign Manager, not the Boost button, so we can use a lead form and target properly.',
    ]
    return '<ul>'+''.join(f'<li>{i}</li>' for i in items)+'</ul>'

HTML = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>

<div class="byline">ADRIAN FERNANDEZ | MAPAL GROUP | PAID MEDIA &amp; LIFECYCLE</div>
<h1>PPC and Nurture: Executive Summary</h1>
<div class="byline">Version 11 | 3 June 2026</div>
<hr class="rule">

<h3>The one-page version</h3>
<p><strong>The problem.</strong> We inherited the paid accounts from three freelancers, across Google, LinkedIn, Microsoft and Meta, in the UK, Iberia and France. They are a sprawl: broken tracking, money going to the wrong products in the wrong markets, narrow audiences that never convert, and bid strategies left on autopilot. Nobody could run them well, and the reporting undercounts what paid actually brings in.</p>
<p><strong>The plan, in a line.</strong> Tear it down and rebuild lean. Roughly 33 focused campaigns instead of the sprawl, one flagship product per market, each funded properly, named so it reports cleanly, and pointed at a real conversion.</p>
<p><strong>Paid is only half of it.</strong> The other half is nurture, what happens to a lead after it comes in. Today most leads dead-end. We fix that, so every lead gets worked and the demand we pay for turns into pipeline. For a slow, considered B2B purchase like ours, that second half is where the deal is won.</p>
<p><strong>What it needs from the wider team.</strong> Most of the remediation is ours to execute, the four ad platforms and the tag container, with the website-migration lead, because the conversion outage is a site dataLayer break rather than an attribution one. A short set genuinely sits with RevOps (the cross-system attribution into Dynamics and the offline-conversion connection), and the lead-routing engine RevOps built is already live. Until the conversion signal is firing again, campaigns still launch and still report through naming and UTMs; they just cannot optimise toward conversions yet.</p>
<div class="callout">Paid captures the lead &rsaquo; Score and nurture &rsaquo; MQL &rsaquo; Sales accepts (SAL) &rsaquo; SQL and pipeline</div>

<h3>Budget</h3>
<p>The base rebuild and the reactivations are funded by redeploying what is wasted today, not by asking for more. On top of that, the second-half plan deploys a confirmed budget floor, a disciplined base that leadership is adding to as the rebuilt engine proves it can absorb spend for return. For June to December the floor is firm at 110,000 euros. Search market totals are held and reshaped within campaigns; the Mexico line is trimmed to a token, and that budget plus the floor headroom shifts into Iberia LinkedIn, which makes Iberia social larger than UK social for the period. Full-year paid lands at about 254,600 euros, search about 199,000 and social about 55,800.</p>
{summary_table()}
{DEFS}

<h3>How we measure success</h3>
<p>Judged on pipeline, not platform-reported clicks. HubSpot pipeline, closed-loop through the offline conversion upload, is the scoreboard.</p>
<table><thead><tr><th>Metric</th><th>Role</th></tr></thead><tbody>
<tr><td>Cost per lead, by channel and market</td><td>Launch-phase efficiency gate (native social forms ran 26 to 55 euros; ceilings 60 to 90 euros social, 120 to 150 euros search)</td></tr>
<tr><td>MQL-to-SQL rate</td><td>Lead quality, matters more than volume</td></tr>
<tr><td>Cost per SQL</td><td>True acquisition efficiency, replaces cost-per-click as the headline</td></tr>
<tr><td>Pipeline and win rate</td><td>Revenue contribution (paid's trailing-12-month win rate is 15.8%, the baseline to hold or beat)</td></tr>
<tr><td>SAL-to-booking (nurture)</td><td>From sub-15% toward 20% by end of 2026</td></tr>
</tbody></table>
<p><strong>Value over volume.</strong> Optimise for lead value, not count, by pushing values back from HubSpot (MQL 500 euros, SQL 2,000 euros, Opportunity 10,000 euros, Closed Won 25,000 euros). <strong>Measure lift, not last-click.</strong> A brand-defence geo holdout at launch (hold brand out in matched regions over a fixed window, then compare), because cheap last-click spend can hide demand that would convert anyway. <strong>Reallocate, do not use-it-or-lose-it.</strong> Budget moves monthly toward the best cost per SQL; read year-on-year because hospitality demand is seasonal; plan a conservative and an optimistic case, not one forecast.</p>
<p>Full build detail, per-platform specs and the tracking and routing remediation are in the plan that follows.</p>

<div class="byline">ADRIAN FERNANDEZ | MAPAL GROUP</div>
<h1>PPC and Nurture: The Plan</h1>
<div class="byline">Version 11 | 3 June 2026 | Companion: the per-platform execution document</div>
<hr class="rule">

<div class="changebox"><span class="tag">WHAT CHANGED IN V11</span>
<p>Locked the budget to the firm 110,000 euro June to December floor. Search market totals are held, with reshaping inside campaigns rather than growth. The Mexico line is trimmed to a token and shifted into Iberia LinkedIn, so Iberia social now sits ahead of UK social for the period. Full-year paid is about 254,600 euros, social about 55,800. The "no new budget" headline is dropped in favour of a disciplined base funded by cutting waste that leadership is adding to as the engine proves out; top-ups beyond the floor are staged and deployed only on confirmation. The 45,000 non-recurrent LATAM line is closed and redistributed. The envelope is clarified: the 14,800 trade-media line is SEO and PR owned and out of paid scope. A new section sets out what paid can support for the growth team and the proven play for each.</p></div>

<div class="changebox"><span class="tag">WHAT CHANGED IN V10</span>
<p>Added the AI-search layer to the plan: a competitor and comparison-term layer in section 5 (Google Ads), and an answer-engine visibility flag in section 15 (SEO, content and PR owned, paid amplifies, not a paid workstream). The budget specifics from this version are superseded; see the V11 note above for the current numbers.</p></div>

<div class="changebox"><span class="tag">WHAT CHANGED IN V9</span>
<p>Re-cut the tracking work by real ownership and folded in the live routing engine. The conversion outage is framed as a site dataLayer break owned by us and the website-migration lead, not a RevOps fix; section 14 is reorganised around who owns each item, with a short genuine RevOps list (the cross-system attribution into Dynamics and the offline-conversion connection). Non-demo lead routing is live (RevOps), so the routing gap is reframed to the residual, a working signal on non-demo leads. Automatic lead scoring is RevOps Phase 2. Paid suppression and the fit gate use the under-20-employee company-size floor, matching the inbound qualification gate.</p></div>

<h3>The one-page version</h3>
<p>As above. Sections 1 to 8 are the paid build. Section 9 is the nurture engine. Section 10 is the expansion engine, cross-sell and up-sell into the customer base. Sections 11 and 12 cover creative and how we measure success. Sections 13 to 15 are budget, the tracking and routing remediation (who owns what), and the launch order. Skip to whatever is yours.</p>

<h3>Contents</h3>
<ul>
<li>1. How to use this with the execution doc</li>
<li>2. The rules every campaign follows</li>
<li>3. The product-market map (the filter on everything)</li>
<li>4. The teardown: what we pause and archive</li>
<li>5. Google Ads, by market</li>
<li>6. LinkedIn Ads, by market</li>
<li>7. Microsoft Ads, by market</li>
<li>8. Meta Ads, by market</li>
<li>9. The nurture engine paid feeds into</li>
<li>10. The expansion engine: cross-sell and up-sell</li>
<li>11. Creative and testing</li>
<li>12. How we measure success</li>
<li>13. Budget and campaign count</li>
<li>What paid can support, and the proven play for each</li>
<li>14. Tracking and routing remediation (who owns each)</li>
<li>15. The launch order</li>
<li>Appendix A. ABM build detail</li>
</ul>

<h2>1. How to use this with the execution doc</h2>
<p><em>Short version: read this for the why, build from the execution doc.</em></p>
<p>This document is the thinking: what we run, why it exists, who it targets, and the settings behind it. The execution doc is the doing: step-by-step blocks per platform and market. Build from that, adapting each block to what you see on screen rather than running it all blind. If the two ever disagree, this document wins. For every account the order is the same: export the current state, pause everything, archive it under a dated label, then build fresh. We do not edit old campaigns into new ones; section 4 explains why.</p>

<h2>2. The rules every campaign follows</h2>
<p><em>Short version: a few rules every campaign obeys, so nothing launches half-built and everything reports cleanly.</em></p>
<p><strong>Naming.</strong> The platform campaign name and the utm_campaign value are the same string, so the data lines up in both Dynamics and HubSpot. The prefix matches the Dynamics campaign theme; the suffix adds the PPC detail.</p>
<table><thead><tr><th>Level</th><th>Pattern</th></tr></thead><tbody>
<tr><td>Campaign</td><td>{{REGION}}-{{ICP}}-{{PRODUCT}}-{{OBJECTIVE}}-{{THEME}}-{{QYY}}</td></tr>
<tr><td>Ad set / ad group</td><td>{{Audience}}-{{Geo}}-{{Lang}}-{{FunnelStage}}</td></tr>
<tr><td>Ad / creative</td><td>{{Format}}-{{Angle}}-V##</td></tr>
</tbody></table>
<p>Hyphens only, no spaces, 80 characters max. Nobody types these by hand; they come from the builder sheet, so the name and the UTM always match. Example: UK-HOTEL-Flow-Search-Always-On-Q226. LinkedIn Lead Gen Forms and Meta Instant Forms do not pass UTMs, so on those campaigns the campaign name is the only thing HubSpot receives; a wrong name means an unattributable lead.</p>
<p><strong>UTMs.</strong> utm_source (google / linkedin / bing / meta) and utm_medium (cpc / paid-social / display / video) land as latest traffic source; utm_campaign is the full campaign name; utm_content is adset-name then ad-name; utm_term is the keyword on search.</p>
<p><strong>Conversions.</strong> Every campaign points at the right conversion from day one, even where that conversion is not firing cleanly yet, so the moment the signal is firing again the campaign already has the right goal. Three conversions, in funnel order: Lead MQL (the one we optimise to), Lead SQL, and Demo Form Submission. The HubSpot attribution setup itself is sound; the conversion break is upstream of it, in the site dataLayer and the tag container.</p>
<p><strong>Tracking prerequisite (ours, with the website lead).</strong> The conversion signal is down because the website migration changed the dataLayer contract these conversions depend on: form conversions were moved onto a HubSpot form event and the form-id keys were then renamed, so the triggers stopped matching. The Google Ads conversions themselves are live and correctly configured; they are simply not being triggered, and ES and UK Lead MQL conversions do not exist yet and are part of the build. Realigning that contract sits with us (the tag container) and the website-migration lead, not RevOps. A main Meta pixel is also dead, ours to restore.</p>
<p><strong>Bidding: start honest, then switch.</strong> Every campaign launches on an interim bid strategy honest about the data we have, then switches to conversion-based bidding about seven days after the conversion signal is confirmed firing.</p>
<table><thead><tr><th>Campaign type</th><th>At launch</th><th>After the tag fix</th></tr></thead><tbody>
<tr><td>Brand defence</td><td>Manual CPC or impression share</td><td>Stays manual. Never Maximize Clicks.</td></tr>
<tr><td>Flagship search</td><td>Maximize Clicks with a firm CPC cap</td><td>Maximize Conversions, then Target CPA at 30+ conversions/month</td></tr>
<tr><td>Lead form (social)</td><td>Maximize leads / lowest cost</td><td>Cost cap once we have a cost-per-lead baseline</td></tr>
<tr><td>Remarketing</td><td>Manual or cost cap, small budget</td><td>Conversion-based once audiences are populated</td></tr>
</tbody></table>
<p><strong>Interim guardrails (set at launch).</strong> Max CPC brand UK 2 to 3 pounds, ES and FR 2 to 3 euros; max CPC flagship search 6 to 9 euros by market; cost-per-lead ceiling 120 to 150 euros search, 60 to 90 euros social (native forms ran 26 to 55 in the audit); switch to conversion bidding at 30+ Lead MQLs per campaign per 30 days.</p>
<p><strong>Value-based bidding.</strong> Ours is a considered, low-volume purchase, so we optimise for lead value, pushing a value back to the platform as each lead moves through the funnel: MQL 500 euros, SQL 2,000 euros, Opportunity 10,000 euros, Closed Won 25,000 euros. It works even when a campaign cannot hit 30 conversions a month. Prerequisites (all in section 14): offline conversion upload on, MQL set automatically, and the LinkedIn click ID plus UTMs captured on every form.</p>
<p><strong>Attribution windows.</strong> Senior hospitality buyers do not convert in one session, so we set a 30-day click-through window across platforms, with view-through handled conservatively.</p>
<p><strong>Audiences: broad but correct.</strong> No always-on social audience runs below 50,000, the platform's delivery threshold. Narrow hand-built lists starve the algorithm, which the audit proved on LinkedIn (a 3,400 list produced zero leads against a 22,000 audience that worked). Narrow, named-account targeting moves to sales sequencing, not paid. Every campaign suppresses existing MQLs and above, the titles Student, Intern and Assistant, companies under 20 employees, current customers and open opportunities, and clearly wrong verticals.</p>

<h2>3. The product-market map (the filter on everything)</h2>
<p><em>Short version: one product leads in each market. Anything off this map is waste, full stop.</em></p>
<table><thead><tr><th>Market</th><th>Flagship</th><th>Secondary</th><th>Out of scope</th></tr></thead><tbody>
<tr><td>UK</td><td>Flow (hotels first, QSR/FSR second)</td><td>Compliance (enterprise hotels, low-volume high-value)</td><td>Workforce, Easilys, Inpulse</td></tr>
<tr><td>Iberia (ES + LATAM)</td><td>Workforce (enterprise + QSR, strongest local play)</td><td>Flow ES, Compliance pilot</td><td>Easilys</td></tr>
<tr><td>France</td><td>Easilys (contract catering, public sector, healthcare)</td><td>Flow (retargeting-led brand build)</td><td>Workforce</td></tr>
<tr><td>Nordics</td><td>None (no 2026 budget)</td><td>Piggyback UK Flow by geo only</td><td>Everything else</td></tr>
</tbody></table>
<p>The competitive picture sharpens the message per market. France is a point-of-sale fight (Lightspeed dominant, Skello present), so Easilys competes there. Iberia competes against HR and payroll tools, so Workforce runs on the HR angle. The UK competes against training and LMS tools, so Flow leads with training-to-execution. Brand defence matters most where rivals bid on our terms, which we have confirmed in France on Bing.</p>

<h2>4. The teardown: what we pause and archive</h2>
<p><em>Short version: export everything for the record, then pause and archive the lot, so we build clean.</em></p>
<p>Before any new campaign goes up, every existing campaign on every account is exported, paused, and archived under a dated label. The history is kept, but nothing old keeps spending or polluting the new structure. Brand defence is the one exception: we reactivate it rather than rebuild it (its history is the baseline we are protecting), then rename it to the convention. Archive everything under one searchable label, ARCHIVED-2026-06-PreRebuild, so the old structure can be found if ever needed and stays clearly separate from the new build.</p>
<p><strong>Before building (leadership, not RevOps).</strong> Departed-contractor access still exists across the stack (Super Admin on both Microsoft accounts via a personal Gmail, and stale personal-Gmail editor access on the Google accounts). These revocations are leadership actions and should be closed before the rebuild, so the clean account cannot be edited by former contractors. Listed in section 14.</p>

<h2>5. Google Ads, by market</h2>
<p><em>Short version: four campaigns per market (brand, flagship search, generic, remarketing), with search doing the heavy lifting.</em></p>
<p>Account settings get fixed first: correct time zone and currency, auto-apply recommendations off, and Search Partners and Display unticked on search campaigns. Within Google, search dominates (65 to 70 percent, the engine), Performance Max is kept but capped (10 to 15 percent, FR only at launch), Display retargeting is remarketing only (5 to 10 percent, no cold display), and branded search is defensive and capped (5 to 10 percent).</p>
<p><strong>The comparison-term layer.</strong> As AI answers resolve more broad and informational queries in place, those clicks fall and the cost per click on what remains rises, so the value concentrates on high-intent, brand and comparison terms. We add a deliberate comparison-term layer inside search: terms where a buyer is weighing us against a named rival, run where a click is genuinely incremental and defended where a competitor bids on our brand (confirmed on French Bing). Bidding on competitor brand terms, if we do it at all, goes in a separate, clearly-labelled quarantine campaign with its own small budget and kill criteria, opt-in per market and only where a competitor is bidding on us first.</p>
<p>Settings for all three Google accounts: time zone London (UK), Madrid (ES), Paris (FR); currency GBP (UK), EUR (ES, FR); auto-apply recommendations off everywhere; import Lead MQL and Lead SQL from HubSpot and set Lead MQL as the single primary, removing every legacy conversion still flagged primary before launch.</p>
<h4>Google UK (Flow flagship, Compliance secondary)</h4>
<table><thead><tr><th>Campaign</th><th>Type / bid</th><th>What it does</th><th>Conversion</th></tr></thead><tbody>
<tr><td>UK-HOTEL-Brand-Brand-AlwaysOn-Q226</td><td>Search. Manual / impression share (~90%+ on exact brand)</td><td>Brand and brand+product terms. Reactivated then renamed. Our cheapest converter historically (13.64 euro CPA).</td><td>Demo Form Submission</td></tr>
<tr><td>UK-HOTEL-Flow-Search-AlwaysOn-Q226</td><td>Search. Maximize Clicks + CPC cap, then Maximize Conversions</td><td>Flagship. Ad groups by theme (rota, labour cost, hotel ops), Flow hotel messaging. Fresh negative-keyword list (UK had none).</td><td>Lead MQL</td></tr>
<tr><td>UK-QSRFSR-Flow-Search-Generic-Q226</td><td>Search. Maximize Clicks + cap</td><td>Generic high-intent category terms for QSR/FSR. Tighter budget than flagship.</td><td>Lead MQL</td></tr>
<tr><td>UK-HOTEL-Flow-Retarget-AlwaysOn-Q226</td><td>Display / Demand Gen remarketing. Small budget</td><td>Remarketing to Flow visitors and engaged audiences. The 69,000 unused curated exclusions get attached.</td><td>Lead MQL / Demo</td></tr>
</tbody></table>
<h4>Google ES (Workforce flagship, Flow ES secondary)</h4>
<table><thead><tr><th>Campaign</th><th>Type / bid</th><th>What it does</th><th>Conversion</th></tr></thead><tbody>
<tr><td>ES-QSR-Brand-Brand-AlwaysOn-Q226</td><td>Search. Manual / impression share</td><td>Brand terms. New build (ES brand was never isolated before).</td><td>Demo Form Submission</td></tr>
<tr><td>ES-QSR-Workforce-Search-AlwaysOn-Q226</td><td>Search. Maximize Clicks + cap, then Maximize Conversions</td><td>Flagship. Workforce management, labour cost, scheduling. HR-angle messaging. Desktop-weighted (mobile burned 6,593 euros for zero). 4 negative lists reattached.</td><td>Lead MQL</td></tr>
<tr><td>ES-QSRFSR-Flow-Search-Generic-Q226</td><td>Search. Maximize Clicks + cap</td><td>Flow ES secondary, lighter feature claims than UK. Smaller budget.</td><td>Lead MQL</td></tr>
<tr><td>ES-QSR-Workforce-Retarget-AlwaysOn-Q226</td><td>Display remarketing. Small budget</td><td>Remarketing to Workforce visitors. Exclusion list attached.</td><td>Lead MQL</td></tr>
</tbody></table>
<p>LATAM has no separate Google account; run it as its own Workforce search campaign (LATAM-QSR-Workforce-Search-Always-On-Q226) with its own geo-targeting and a small token budget, not buried inside ES campaigns like before.</p>
<h4>Google FR (Easilys flagship, Flow secondary)</h4>
<table><thead><tr><th>Campaign</th><th>Type / bid</th><th>What it does</th><th>Conversion</th></tr></thead><tbody>
<tr><td>FR-CC-Brand-Brand-AlwaysOn-Q226</td><td>Search. Manual / impression share</td><td>Brand and Easilys-brand terms. Genuinely incremental here: rivals bid on our brand on Bing.</td><td>Demo Form Submission</td></tr>
<tr><td>FR-CC-Easilys-Search-AlwaysOn-Q226</td><td>Search. Maximize Clicks + cap, then Maximize Conversions</td><td>Flagship, consolidated from 12 variants into one. Geos as ad groups. 542-keyword negative list reattached.</td><td>Lead MQL</td></tr>
<tr><td>FR-CC-Easilys-Demand-AlwaysOn-Q226</td><td>Performance Max (single, clean)</td><td>One PMax on a single clean conversion. PMax converted whenever the signal reached it. Launch paused until conversion cleanup is done.</td><td>Lead MQL</td></tr>
<tr><td>FR-CC-Easilys-Retarget-AlwaysOn-Q226</td><td>Display remarketing. Small budget</td><td>Remarketing plus the Flow retargeting-led brand build. FR exclusion lists attached.</td><td>Lead MQL</td></tr>
</tbody></table>
<div class="callout"><strong>Tracking prerequisite, FR conversions (ours).</strong> The FR conversion layer needs a cleanup in the Google Ads UI (29 actions, 18 removed, 4 still flagged primary). This is ours to do and must finish before FR switches to conversion bidding. Until then, FR runs on Maximize Clicks with caps.</div>

<h2>6. LinkedIn Ads, by market</h2>
<p><em>Short version: three campaigns per market, broad audiences, native lead forms. Broad wins; narrow lists do not.</em></p>
<p>Account-based work is rebuilt as three tiers instead of narrow lists, with every always-on tier above the 50,000 floor. Lead Gen Forms are the default capture format. One correction from the live rebuild: the Insight Tags fire on all three accounts, but LinkedIn is not actually connected to HubSpot yet, so part of the work here is the connection, not just the campaign structure (section 14, items 5, 10, 12). The format mix sits inside the existing 70/30 evergreen/growth split: Sponsored Content with Lead Gen Forms (40 to 45 percent, primary capture), Conversation Ads (30 to 35 percent), Document Ads (15 to 20 percent), and ABM (10 percent max, justified on pipeline or cut).</p>
<table><thead><tr><th>Campaign</th><th>Format / bid</th><th>Audience</th><th>Conversion</th></tr></thead><tbody>
<tr><td>{{REGION}}-{{ICP}}-{{PRODUCT}}-LeadGen-AlwaysOn-Q226</td><td>Sponsored Content, native form. Maximize leads, cost cap later</td><td>Broad ICP, above 50K, by title + industry + size. The workhorse.</td><td>Lead MQL</td></tr>
<tr><td>{{REGION}}-{{ICP}}-{{PRODUCT}}-Demand-Sponsored-Q226</td><td>Sponsored Content (image / document). Lowest cost</td><td>Mid-funnel, broad ICP. Builds the retargeting pool. Content-led.</td><td>Lead MQL / engagement</td></tr>
<tr><td>{{REGION}}-{{ICP}}-{{PRODUCT}}-Retarget-AlwaysOn-Q226</td><td>Sponsored Content retargeting. Cost cap</td><td>Engaged audiences and site visitors. Stays present between nurture emails.</td><td>Lead MQL / Demo</td></tr>
</tbody></table>
<p>ABM is rebuilt in three tiers inside that structure: Tier 1 named accounts (10 to 30 sales-chosen logos, one-to-one, measured on meetings booked), Tier 2 best-fit (50K+ by title, industry, size, the workhorse, measured on cost per lead through to pipeline), Tier 3 broad ICP plus lookalikes (lowest cost, feeds the funnel). Full detail in Appendix A.</p>
<div class="callout"><strong>Tracking prerequisite, LinkedIn (mostly ours).</strong> Attaching Lead MQL/SQL at ad-set level, reactivating the FR event, and clearing the dead events are ours, in Campaign Manager. The one genuine RevOps piece is connecting and confirming the HubSpot to LinkedIn integration. Section 14.</div>

<h2>7. Microsoft Ads, by market</h2>
<p><em>Short version: treat Microsoft as a new channel, not a fix. Two campaigns per market: brand and generic.</em></p>
<p>The UK account is rebuilt from corrected settings (never un-paused as-is: wrong target CPA, Helsinki time zone, currency), France is rebuilt around Easilys and brand after the 42 auto-imported campaigns are archived and the orphaned 250-keyword Easilys negative list is attached, and Spain gets a new account in Q3.</p>
<table><thead><tr><th>Campaign</th><th>Type / bid</th><th>What it does</th><th>Conversion</th></tr></thead><tbody>
<tr><td>UK-HOTEL-Brand-Brand-AlwaysOn-Q226</td><td>Search. Manual / impression share</td><td>Brand defence, reactivating the paused UK presence. Catches the 5 to 10 percent of branded search Google misses.</td><td>Demo Form Submission</td></tr>
<tr><td>UK-HOTEL-Flow-Search-Generic-Q226</td><td>Search. Maximize Clicks + cap</td><td>Generic high-intent, Microsoft-specific keywords (not the generic terms that burned 1,570 euros for zero). Flow flagship.</td><td>Lead MQL</td></tr>
<tr><td>FR-CC-Brand-Brand-AlwaysOn-Q226</td><td>Search. Manual / impression share</td><td>Brand defence. Skello, Sage and Eurecia bid on our brand on Bing (impression share to 56 percent). Add negatives for Workforce-mention queries.</td><td>Demo Form Submission</td></tr>
<tr><td>FR-CC-Easilys-Search-Generic-Q226</td><td>Search. Maximize Clicks + cap</td><td>High-intent Easilys. The FR Easilys brand term already converts at about 143 euros. 250-keyword negative list attached. No Audience Network.</td><td>Lead MQL</td></tr>
</tbody></table>
<p>Spain Microsoft (Q3): no ES account exists today and there is uncovered ES demand on Bing. Open one in Q3, funded by reallocating ES Workforce Google waste, mirroring the two-campaign structure. On the roadmap, not the launch build.</p>

<h2>8. Meta Ads, by market</h2>
<p><em>Short version: three campaigns per active market, all native lead forms, all pointed at leads, never traffic.</em></p>
<p>Native forms were three times cheaper than landing pages in the audit. Everything points at leads, never traffic or awareness (which was 73 percent of the wasted spend). France is the live base; UK and ES are rebuilt as they come online. The pixel gets fixed and the four zombie pixels deleted before any scaling, and Audience Network is excluded everywhere.</p>
<table><thead><tr><th>Campaign</th><th>Objective / bid</th><th>Audience</th><th>Conversion</th></tr></thead><tbody>
<tr><td>{{REGION}}-{{ICP}}-{{PRODUCT}}-LeadGen-Native-Q226</td><td>Leads, native Instant Form. Lowest cost, cost cap later</td><td>Broad ICP. The 26 vs 84 euro winner. Audience Network excluded. Form name is the attribution.</td><td>Lead (then Lead MQL once traced)</td></tr>
<tr><td>{{REGION}}-{{ICP}}-{{PRODUCT}}-Retarget-Conversion-Q226</td><td>Conversion remarketing. Cost cap</td><td>Site and engagement audiences. Needs the working pixel.</td><td>Lead / Demo</td></tr>
<tr><td>{{REGION}}-{{ICP}}-{{PRODUCT}}-Demand-Video-Q226</td><td>Demand Gen / video, inside the lead-form structure</td><td>The growth-team video runs here, where it converts, not as standalone awareness.</td><td>Lead</td></tr>
</tbody></table>
<div class="callout"><strong>Tracking prerequisite, Meta pixel (ours).</strong> The main pixel was dead about 27 days and four others are inactive. Restoring the main pixel, deleting the four zombie pixels, and confirming Lead and Lead_SQL fire are ours, in Events Manager, before remarketing or conversion bidding. Section 14.</div>

<h2>9. The nurture engine paid feeds into</h2>
<p><em>Short version: paid brings the lead in, nurture turns it into a deal. Today most leads go cold. This fixes that.</em></p>
<p>For a slow, considered purchase like ours, this is where the deal is won or lost, and right now it is the weak point: most non-demo leads dead-end. The shared lifecycle stages are defined the same way for marketing and sales, so "MQL" means the same thing to both teams.</p>
<table><thead><tr><th>Stage</th><th>What it means</th><th>Owner</th><th>What moves it forward</th></tr></thead><tbody>
<tr><td>Lead</td><td>Known contact, not yet qualified</td><td>Marketing</td><td>Fit + behaviour scoring</td></tr>
<tr><td>MQL</td><td>Hits the score; ready for a human</td><td>Marketing</td><td>Score crosses the threshold (never set by hand)</td></tr>
<tr><td>SAL</td><td>Sales has accepted it as worth working</td><td>SDR</td><td>SDR accept; a reject sends it back to nurture with a reason</td></tr>
<tr><td>SQL</td><td>A real opportunity (need, fit, timing)</td><td>SDR / Sales</td><td>Discovery confirms it</td></tr>
<tr><td>Opportunity</td><td>Open deal in the pipeline</td><td>Sales</td><td>Stage progression</td></tr>
<tr><td>Customer</td><td>Closed won</td><td>Sales</td><td>Signed</td></tr>
</tbody></table>
<p><strong>How a lead becomes an MQL.</strong> A lead qualifies on two scores together: fit (title, company size 20+, industry on the map, region, hard-gated so juniors and wrong-vertical leads cannot reach MQL on behaviour alone) and behaviour (pricing-page visit, 2+ downloads, demo interaction, email engagement, where high-intent actions count far more than a single open). The threshold is set with sales and SDR input and tuned against the actual MQL-to-SQL rate. MQL is set by scoring, never flipped by hand, because manual delay misses the platform match window value-based bidding depends on.</p>
<p><strong>Routing and the handoff.</strong> Every paid lead is tagged on entry with its campaign and a paid-lead marker. A central routing workflow creates, qualifies and routes the non-demo leads to an owner, splits current customers to Customer Success, dedups against open leads, and blocks the clear non-fits. The residual gap is that only demo requests alert an SDR today, so non-demo leads can sit; closing that, a queue view or daily digest, sits with RevOps and the SDR side. Once automatic scoring is live (RevOps Phase 2), a sales-ready lead creates a high-priority, paid-labelled task in the SDR queue. Since SDRs are at about 63 percent of target, it stays a priority and a soft target, not a punitive timer. The SDR accepts (it becomes SAL) or rejects with a reason; rejected leads return to nurture, which is also the cleanest lead-quality signal back to paid.</p>
<p><strong>Three layers of personalisation.</strong> Product, market (UK, Iberia, France, LATAM, with language and local proof) and ICP. So someone who downloaded a Workforce guide in Spain gets Workforce nurture, in Spanish, with a Spanish customer story.</p>
<p><strong>The sequence.</strong> Inside each track (Flow/Compliance for HR and Operations; Workforce for Operations Director and Finance; Easilys for Finance and public-sector and contract-catering leads), a four-week sequence: week 1 a relevant customer story (no pitch), week 2 content for the business case, week 3 proof from a similar business in their market and language, week 4 a low-friction demo offer. Non-converters drop to a monthly long-term nurture. Behaviour triggers an accelerated response: a pricing-page visit triggers an immediate case-study email with a demo offer plus an ROI retargeting ad; 2+ downloads trigger an SDR alert and a case-study ad within 48 hours; a demo no-show gets a Conversation Ad within 7 days; 45 days quiet triggers a re-engagement sequence.</p>
<p>We suppress a contact from active nurture when they are an open opportunity, a current customer, unsubscribed, or already in a live SDR conversation. We judge nurture on pipeline, not activity: SAL-to-booking rate (from sub-15% toward 20% by end of 2026), MQL-to-SQL nurtured versus not (the core proof), time-to-SQL, pipeline influenced, and engagement with unsubscribe under 0.3% per send. We do not report sends or opens on their own.</p>
<p><strong>How we build it.</strong> Q3 quick wins: audit and fix current workflows, fix UTM and source attribution, build the scoring model with sales and SDR input, ship the 2 to 3 highest-value sequences. Q4: full track-based architecture, product/market/ICP personalisation, dashboard reporting. 2027: progressive profiling, predictive scoring, multi-touch orchestration, account-level nurture for ABM.</p>

<h2>10. The expansion engine: cross-sell and up-sell</h2>
<p><em>Short version: acquisition wins a logo, expansion grows it. The cheapest pipeline we have is the customers we already own.</em></p>
<p>The third loop is what happens after the first sale. A customer who adds a second module and rolls out across their estate is worth several times their first contract, converts far better than a cold prospect, and costs a fraction to reach. Cross-sell is a customer on one module taking an adjacent one; up-sell is growing what they already have (more sites, seats, a higher tier, a longer term). Both are measured as expansion revenue and net revenue retention. The expansion sale is owned by Customer Success and account management; paid and lifecycle own the demand layer and hand a qualified expansion signal to the account owner.</p>
<table><thead><tr><th>Current product (entry)</th><th>Natural next module</th><th>The angle</th></tr></thead><tbody>
<tr><td>Flow (UK hotels, the largest base)</td><td>Compliance, then Engage</td><td>Close the compliance and audit gap on teams already trained. Flow and Compliance are often bought together.</td></tr>
<tr><td>Workforce (Iberia)</td><td>Compliance + Engage</td><td>The compliance and engagement layer on the same teams whose scheduling and labour cost are already solved.</td></tr>
<tr><td>Easilys (France, contract catering)</td><td>Flow</td><td>Bring training and onboarding into a kitchen operation that already runs on Easilys.</td></tr>
<tr><td>Multi-module / Key Accounts</td><td>MapalOS consolidation</td><td>More modules on one operating system, one login, one data layer. The largest-account expansion play.</td></tr>
</tbody></table>
<p><strong>The trigger logic.</strong> Expansion fires on a combination of account health, product usage and timing, never on tenure alone. The one hard rule: only green-health accounts enter cross-sell or up-sell; amber and red go to adoption or save motions, never an ask for more money. Low adoption of an owned module means adoption nurture first, not cross-sell. Nearing a seat or site limit triggers an up-sell sequence with an account-owner alert. The renewal window (90/60/30) surfaces the expansion opportunity alongside the renewal. The paid layer points database activation at customers instead of prospects, suppressing the owned module plus amber/red accounts. When a green-health account crosses the threshold it creates a high-priority, paid-labelled task for the account owner, never a raw demo form. A cross-sell holdout matters even more here than on cold acquisition, because these customers might expand anyway.</p>
<div class="callout"><strong>Data prerequisites (beyond the acquisition fix-list).</strong> Product-usage data flowing into the CRM (owner: RevOps, target Q3) and the customer-health score exposed to marketing (owner: Customer Success, target Q3). Neither blocks the acquisition rebuild.</div>

<h2>11. Creative and testing</h2>
<p><em>Short version: a few strong, tested angles per product beats a pile of one-off ads.</em></p>
<p>Ads lead with the reader's problem, then how we solve it, then proof. Flow (UK, hotels) leads on training that turns into consistent on-shift behaviour and the cost of staff turnover, with the training-gap creative and hotel stories. Workforce (Iberia) leads on labour cost and scheduling on the HR angle, with the proven ES forms and same-size local proof. Easilys (France) leads on food-cost control and kitchen and procurement efficiency, with the document/whitepaper pattern and public-sector references. Compliance (UK secondary) leads on compliance-gap closure and audit-readiness for enterprise hotels. We test one thing at a time (the V## in the name tracks the version), judge on the funnel not the click, refresh on fatigue, and source creative through the intake form.</p>

<h2>12. How we measure success</h2>
<p><em>Short version: we judge spend on pipeline, not platform-reported clicks. HubSpot pipeline is the truth.</em></p>
<p>The real scoreboard is HubSpot pipeline, closed-loop through the offline conversion upload. Every campaign carries cost per lead by channel and market (the launch-phase gate), MQL volume, MQL-to-SQL rate, cost per SQL (replaces cost-per-click as the headline), and pipeline and win rate (paid's trailing-12-month win rate is 15.8%, the baseline to hold or beat). We optimise for lead value, not count (MQL 500, SQL 2,000, Opportunity 10,000, Closed Won 25,000 euros).</p>
<table><thead><tr><th>Test</th><th>When</th><th>What it answers</th></tr></thead><tbody>
<tr><td>Brand-defence geo holdout</td><td>At launch</td><td>Is brand-defence spend incremental, or just harvesting demand that would convert anyway? Hold brand out in matched regions over a fixed window and compare.</td></tr>
<tr><td>Meta value holdout</td><td>Q3, after leads are traced to pipeline</td><td>Does Meta lead spend drive incremental pipeline, measured on value not lead count?</td></tr>
</tbody></table>
<p>We reallocate rather than use-it-or-lose-it (budget moves monthly toward the best cost per SQL, and the social growth shares are ceilings that revert to evergreen if unused), read year-on-year because hospitality demand is seasonal, and plan a conservative and an optimistic case rather than one forecast.</p>

<h2>13. Budget and campaign count</h2>
<p><em>Short version: a disciplined base funded by cutting waste, into about 33 campaigns one person can actually run.</em></p>
<p>The base rebuild and the reactivations are funded by redeploying what is wasted today, not by asking for more. On top of that, the second-half plan deploys a confirmed budget floor, firm at 110,000 euros for June to December, which leadership is adding to as the rebuilt engine proves it can absorb spend for return. Search market totals are held and reshaped inside campaigns; the Mexico line is trimmed to a token, and that budget plus the floor headroom shifts into Iberia LinkedIn, so Iberia social now sits ahead of UK social for the period. Full-year paid lands at about 254,600 euros (search about 199,000, social about 55,800). For scope: paid was about 242,600 euros for the year before this plan, of which roughly 144,600 was committed January to May; the separate 14,800 trade-media line is SEO and PR owned and out of paid scope. The 45,000 non-recurrent LATAM line is closed and redistributed. Beyond the floor, top-ups are staged and deployed only on confirmation, social growth-support and UK brand and comparison search first. Search stays fully evergreen; the social platforms split evergreen and a ring-fenced growth share that is a ceiling, not a floor: unused, it reverts to evergreen. In-housing three external retainers banks about 17,760 euros a year, kept as a line.</p>
<h4>Market summary, Jun to Dec (euros)</h4>
{summary_table()}
<h4>Paid search by month (euros)</h4>
{month_table(search_rows, search_total)}
<h4>Paid social by month (euros)</h4>
{month_table(social_rows, social_total)}
{DEFS}
<h4>Campaign count</h4>
<table><thead><tr><th>Platform</th><th>Per market</th><th>Markets</th><th>Approx total</th></tr></thead><tbody>
<tr><td>Google</td><td>4 (brand, flagship, generic, remarketing)</td><td>UK, ES, FR (+ LATAM search)</td><td>~13</td></tr>
<tr><td>LinkedIn</td><td>3 (lead-gen, demand, retarget)</td><td>UK, ES, FR</td><td>~9</td></tr>
<tr><td>Microsoft</td><td>2 (brand, generic)</td><td>UK, FR (ES in Q3)</td><td>~4</td></tr>
<tr><td>Meta</td><td>3 (lead-gen, retarget, video)</td><td>FR live, UK + ES as they come online</td><td>~7</td></tr>
<tr class="total"><td>Total</td><td></td><td></td><td>~33</td></tr>
</tbody></table>
<p>One person can run weekly hygiene across 33 focused campaigns. The current sprawl cannot be run well by anyone, which is the practical argument for consolidating.</p>

<h2>What paid can support, and the proven play for each</h2>
<p>Paid supports the growth team's activity through a defined set of plays, each with a proven setup and one metric it is judged on, so supported activity generates pipeline rather than spend. This is a service menu, not a gate: here is what paid can do for you, and the proven play for each.</p>
{menu_table()}
<h4>How to work with paid</h4>
{boundaries()}

<h2>14. Tracking and routing remediation, and who owns each</h2>
<p><em>Short version: most of this is ours to execute (the platforms and the tag container); a short set genuinely needs RevOps; the lead-routing engine is already live.</em></p>
<p>The conversion outage is a website dataLayer break, not an attribution fault, so the bulk of the work sits with us and the website-migration lead rather than RevOps. The HubSpot attribution design is sound. Each row names what is wrong, what is needed, and who owns it.</p>
<table><thead><tr><th>#</th><th>Item</th><th>What is needed</th><th>Owner</th></tr></thead><tbody>
<tr><td>1</td><td>Conversion signal / site dataLayer (the critical path)</td><td>Verify the migrated site pushes the form event with the current keys (a live dataLayer test), then realign the triggers in the tag container. The Google Ads conversions are live but untriggered.</td><td>Us + website lead</td></tr>
<tr><td>2</td><td>FR Google conversions cleanup</td><td>Unmark removed actions as primary, remove from account goals, leave only live Lead MQL and Demo (29 actions, 18 removed, 4 still flagged primary).</td><td>Us</td></tr>
<tr><td>3</td><td>ES Google "Compra"</td><td>Removed, yet still primary and in account goals; unmark and remove so bidding does not chase a dead event.</td><td>Us</td></tr>
<tr><td>4</td><td>UK Google "Demo Form Submission"</td><td>In "needs attention" but recording 20 conversions; check the tag, confirm it fires, clear the state so the count can be trusted.</td><td>Us</td></tr>
<tr><td>5</td><td>LinkedIn conversions + HubSpot connection</td><td>Attach Lead MQL/SQL at ad-set level, reactivate FR, clear dead events (ours). Connect and confirm the HubSpot to LinkedIn integration (RevOps).</td><td>Us + RevOps</td></tr>
<tr><td>6</td><td>Microsoft events</td><td>UET and config are ours; confirming events flow from HubSpot into Microsoft is RevOps (same dataLayer root cause as item 1).</td><td>Us + RevOps</td></tr>
<tr><td>7</td><td>Meta pixel + zombies</td><td>Restore the main pixel, confirm Lead and Lead_SQL fire, delete the four zombie pixels.</td><td>Us</td></tr>
<tr><td>8</td><td>Non-demo lead routing</td><td>Routing shipped (created, qualified, routed; customers split to CS; duplicates and non-fits filtered). Add a working signal on non-demo leads (a queue view or daily digest) and a clean paid-source label on entry.</td><td>RevOps (shipped) + SDR side</td></tr>
<tr><td>9</td><td>Cross-channel UTM and deal attribution</td><td>Confirm UTMs reach deal records and campaign writes back, and stop Dynamics overwriting source, so the naming rolls up as designed.</td><td>RevOps</td></tr>
<tr><td>10</td><td>Offline conversion upload (LinkedIn + Google)</td><td>Enable the upload on the platforms (ours); confirm the HubSpot connection that feeds deal-stage values back (RevOps).</td><td>Shared, RevOps-gated</td></tr>
<tr><td>11</td><td>Automatic MQL / lead scoring</td><td>Make MQL scored or workflow-driven so it fires automatically. Sales signs off the threshold.</td><td>RevOps, Phase 2</td></tr>
<tr><td>12</td><td>li_fat_id + UTM hidden fields</td><td>Add li_fat_id and utm_source/medium/campaign as hidden fields on every form. No form ships without it.</td><td>Us</td></tr>
<tr><td>13</td><td>Attribution windows</td><td>Set a 30-day click-through window in each platform (ours); align the HubSpot model window with conservative view-through (RevOps).</td><td>Us + RevOps</td></tr>
<tr><td>14</td><td>Product-usage data synced into the CRM</td><td>Sync product-usage data into the CRM. Gates cross-sell, not the acquisition rebuild. Target: Q3.</td><td>RevOps / data</td></tr>
<tr><td>15</td><td>Customer-health score exposed to marketing</td><td>Expose the customer-health score to marketing so the green-health gate and suppression can be enforced. Gates cross-sell. Target: Q3.</td><td>Customer Success</td></tr>
</tbody></table>
<p>Items 1 to 7 are the conversion-tracking work, ours and the website lead's. Items 8 and 11 are the routing engine and its Phase 2 scoring (8 is live). Items 9, 10 and 13 are the cross-system and optimisation layer. Items 14 and 15 gate cross-sell only.</p>
<p><strong>Governance (leadership and marketing-admin, not RevOps).</strong> Close the departed-contractor access across the stack as handover completes (personal-Gmail admin rights on the tag container, a Super Admin on both Microsoft accounts, stale editor access on the three Google accounts), and turn on "require sign-in with work account" where supported, before the rebuild.</p>

<h2>15. The launch order</h2>
<p><em>Short version: governance and teardown first, clean settings second, capture-ready campaigns third, the conversion-bidding switch only once the signal is real.</em></p>
<p>Lead capture is never blocked: native forms work from day one. Only conversion-based bidding and the remarketing sync wait on the tracking fix.</p>
<table><thead><tr><th>Stage</th><th>What happens</th><th>Waits on</th></tr></thead><tbody>
<tr><td>0. Governance + export</td><td>Close the access revocations. Export every account to the dated audit folder.</td><td>Leadership for revocations; nothing for export.</td></tr>
<tr><td>1. Teardown</td><td>Pause and archive everything under the dated label. Keep the named audiences, negative lists and proven creative.</td><td>Export done.</td></tr>
<tr><td>2. Settings</td><td>Fix time zones, currencies, target CPAs; auto-apply off; import and set the primary conversion; attach negative-keyword and exclusion lists.</td><td>Teardown done.</td></tr>
<tr><td>3. Brand + flagship</td><td>Reactivate and rename brand defence; build the flagship search per market on interim bidding; build the LinkedIn lead-gen and Meta native-form campaigns.</td><td>Settings done.</td></tr>
<tr><td>4. Generic + remarketing</td><td>Build the generic and remarketing campaigns. Remarketing launches small.</td><td>Flagship live.</td></tr>
<tr><td>5. Switch bidding (T+7d)</td><td>Once we and the website lead confirm the signal is firing and the in-platform conversions are clean, verify events fire for 7 days, then switch flagship and generic to Maximize Conversions, set realistic target CPAs, enable FR Performance Max.</td><td>Tracking items 1-7 verified.</td></tr>
<tr><td>6. Sync + scale</td><td>Sync HubSpot segments to platform audiences, build revenue lookalikes, scale the native-form model to UK and ES once leads are traced to pipeline.</td><td>Tracking healthy; leads traced.</td></tr>
</tbody></table>
<p><strong>Q3 roadmap (depends on other teams, not part of the launch).</strong></p>
<ul>
<li><strong>Paid amplifies SEO.</strong> Once SEO is producing ranking problem-aware content, paid social amplifies the best pieces (paid serves SEO, not the reverse). Depends on the SEO content pipeline.</li>
<li><strong>Video as a view-through asset.</strong> The growth-team video runs as a view-through demand asset feeding retargeting into Search and LinkedIn. Depends on the video pipeline.</li>
<li><strong>A second incrementality holdout.</strong> After native-form leads are traced to pipeline, run a Meta value holdout (the brand-defence geo holdout comes first, at launch).</li>
<li><strong>Answer-engine visibility.</strong> As buyers get more of their answers inside AI assistants and AI overviews, how Mapal shows up in those answers becomes a real surface. This is SEO, content and PR owned, with paid amplifying; it is flagged here for the wider team, not absorbed into paid as a workstream.</li>
</ul>

<h2>Appendix A. ABM build detail</h2>
<p><em>Short version: account-based done the way it actually works. Broad-but-precise audiences, native capture, nurture behind the click.</em></p>
<p>The old ABM was not a bad idea executed unluckily. It broke three rules at once: narrow hand-picked Top-100 lists below LinkedIn's delivery threshold, pushed through InMail, with no nurture layer behind the click. The one broad, correctly-targeted campaign we ran did the opposite.</p>
<table class="money"><thead><tr><th>Same offer, same form, two audiences</th><th>Audience</th><th>Spend</th><th>Leads</th><th>Cost per click</th></tr></thead><tbody>
<tr><td>Narrow "Top 100" list (about half the wrong vertical)</td><td>3,400</td><td>&euro;441</td><td>0</td><td>&euro;184</td></tr>
<tr><td>Broad ICP audience</td><td>22,000</td><td>&euro;444</td><td>3 (21 lifetime)</td><td>&euro;8.28</td></tr>
</tbody></table>
<p>Near-identical spend; the only variable was the audience. Narrow targeting starved the platform and cost 22 times more per click for zero leads. Two more lessons sit underneath: native lead forms beat landing pages by a wide margin (26 euros against 84 on the same Meta offer), and none of it matters if the lead then hears nothing. The rebuild fixes all three: broad-but-precise audiences, native capture, and a nurture layer that was not there before. We are not killing ABM, we are fixing the mechanics that made it fail.</p>
<table><thead><tr><th>Tier</th><th>Who it targets</th><th>Audience</th><th>Targeting method</th><th>Format</th><th>Primary metric</th></tr></thead><tbody>
<tr><td>Tier 1: Named accounts</td><td>A small, hand-chosen set of priority logos</td><td>10-30 logos</td><td>Company-list, one-to-one</td><td>Conversation ads, native forms, sales-aligned</td><td>Meetings booked</td></tr>
<tr><td>Tier 2: Best-fit (the workhorse)</td><td>Verticals and sizes that match the product-market map</td><td>50K+</td><td>Title + industry + size, above the floor</td><td>Native lead forms</td><td>Cost per lead, then pipeline</td></tr>
<tr><td>Tier 3: Broad ICP + lookalikes</td><td>The wider ICP and lookalikes of converters</td><td>Largest</td><td>Broad ICP + lookalikes from Tier 2 and closed-won</td><td>Native forms, retargeting</td><td>Lowest cost, feeds the funnel</td></tr>
</tbody></table>
<p>The tiers are a funnel, not silos. Tier 3 finds and warms people cheaply, the best graduate into Tier 2, the genuinely strategic accounts get the Tier 1 one-to-one treatment. Closed-won data flows back to sharpen the Tier 3 lookalikes. Every ABM campaign must meet the build standards (50,000+ audience floor, native capture, conversion event wired before launch, conversion-based bidding never Maximize Clicks on an always-on campaign, suppression and exclusions from day one, dual-string naming, nurture behind the click, proven creative). The always-on ABM tiers sit in the evergreen budget rather than the growth-support share, because Tiers 2 and 3 run year-round capturing and feeding demand, which frees the growth-support share for the growth team's own campaigns. The unused 1.28-million-member French matched audience is the starting pool for Tiers 2 and 3.</p>

</body></html>"""

os.makedirs('build', exist_ok=True)
open('build/plan_v11.html','w').write(HTML)
print('plan HTML written', len(HTML), 'chars')
