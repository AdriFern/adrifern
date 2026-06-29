# Monday Marketing Deck — Paid media and campaigns

A single 11-slide deck for the Monday 10:30 marketing meeting. Two parts in one file:

- **Part A (slides 2 to 5):** PPC status and KPIs. Slides 3 and 4 carry placeholders that get
  filled with live numbers on the morning of the meeting. Slide 5 is the light contribution view.
- **Part B (slides 7 to 11):** How we build campaigns together. Copy is final.

## Files

| File | What it is |
|------|-----------|
| `monday-marketing-deck.pptx` | The deck. Editable, open in PowerPoint. This is what you present and fill. |
| `monday-marketing-deck-preview.pdf` | A read-only render of the current state, for quick viewing without PowerPoint. |
| `deck.js` | The source that generates both the `.pptx` and the QA render. |
| `qa.html` | The HTML mirror used for visual QA (see below). |

## Monday morning fill

Open `monday-marketing-deck.pptx` and replace every bracketed placeholder (shown in amber).
Pull current-period numbers (last 7 days or month to date — pick one and state it in `[ PERIOD ]`).

Slides 3 and 4 are **per-campaign tables grouped by region** (Iberia, UK, France). Each region has
three scaffolded campaign rows; add or delete rows in PowerPoint to match the live campaign count.
Region codes in the placeholders: `IB` = Iberia, `UK` = UK, `FR` = France; `i` = campaign number 1 to 3.

- **Slide 3, Paid search** (Google Ads — UK 511-997-3456, Iberia/Spain 306-126-9544, France 908-324-1950):
  per campaign row, fill `[<REGION>_CAMP_i]` (campaign name), `[<REGION>_SPEND_i]`,
  `[<REGION>_LEADS_i]`, `[<REGION>_CPL_i]`, `[<REGION>_THEME_i]` (top keyword or theme).
  Example for the first Iberia row: `[IB_CAMP_1]`, `[IB_SPEND_1]`, `[IB_LEADS_1]`, `[IB_CPL_1]`, `[IB_THEME_1]`.
- **Slide 4, Paid social** (LinkedIn — UK/EN 503519691, Iberia/Spain 508038339, France 509320582):
  per campaign row, fill `[<REGION>_SOC_CAMP_i]`, `[<REGION>_SOC_SPEND_i]`, `[<REGION>_SOC_RES_i]`
  (results), `[<REGION>_SOC_CPR_i]` (cost per result), `[<REGION>_SOC_AUD_i]` (audience).
- **Slide 5 (optional):** `[ COST_PER_LEAD ]`, `[ COST_PER_OPP ]`, `[ COST_PER_WON ]`.
  Keep these high level, or leave them off and let the monthly report carry the detail.

Notes:
- "Iberia" is the display label over the existing Spain Google Ads / LinkedIn accounts. If Portugal
  spend is in play, fold it into the same region rows.
- Want per-region subtotal rows (spend / leads totals under each region)? They are not in the deck
  yet — say the word and they can be added.

Format numbers consistently (currency, no decimals) and cross-check leads and cost-to-acquire in
HubSpot if the platform figures look off.

## Rebuilding

```bash
npm install pptxgenjs react-icons react react-dom sharp
node deck.js both                 # writes monday-marketing-deck.pptx and qa.html
python3 /mnt/skills/public/pptx/scripts/rezip.py monday-marketing-deck.pptx
```

## How it was QA'd

LibreOffice is unavailable for rendering in the build environment, so the deck is generated from a
single shared slide spec in `deck.js` that emits **both** the `.pptx` and a pixel-matched HTML mirror
(`qa.html`) using identical inch-based coordinates. The HTML is rendered with Chromium and inspected
slide by slide for overflow, overlap, misalignment, and contrast. The QA render uses Liberation Sans
(Arial metrics, wider than Calibri), so text that fits in QA also fits in PowerPoint's Calibri.
