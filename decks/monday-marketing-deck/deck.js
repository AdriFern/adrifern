// Monday Marketing Deck — Paid media and campaigns
// Single shared slide spec -> emits BOTH the .pptx (pptxgenjs) and an HTML mirror.
// The HTML mirror is rendered with Chromium for visual QA so the QA render matches
// the .pptx layout exactly (identical inch-based coordinates).
//
// Usage:
//   node deck.js pptx     -> writes monday-marketing-deck.pptx
//   node deck.js html     -> writes qa.html
//   node deck.js both     -> writes both (default)

const fs = require("fs");
const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");
const FA = require("react-icons/fa");

// ---------- Palette ----------
const NAVY = "16235C";
const WHITE = "FFFFFF";
const TEAL = "1F9E7F";
const AMBER = "D78A27";
const SLATE = "1F2733";
const MUTED = "5B6773";
const TINT_TEAL = "EAF6F2";
const TINT_AMBER = "FBF1E0";
const PANEL = "F4F7FA";
const HAIR = "DCE2E8";
const PH = AMBER; // placeholder colour — easy to find for the Monday fill
const LIGHT = "CFE6DC"; // light text on navy
const DIM = "AEB9CC"; // dim text on navy

const FONT = "Calibri";

// ---------- Geometry ----------
const PAGE_W = 13.333;
const PAGE_H = 7.5;
const MARGIN = 0.6;
const PX = 96; // inches -> px for HTML

// ---------- Icons ----------
async function renderIcon(IconComponent, hex, size = 256) {
  const svg = ReactDOMServer.renderToStaticMarkup(
    React.createElement(IconComponent, { color: "#" + hex, size: String(size) })
  );
  const png = await sharp(Buffer.from(svg)).png().toBuffer();
  return "image/png;base64," + png.toString("base64");
}

// ---------- Spec primitive builders ----------
// item types: bg, rect, text, image, table, chart, bullets, oval
function rect(x, y, w, h, o = {}) { return { t: "rect", x, y, w, h, ...o }; }
function oval(x, y, w, h, o = {}) { return { t: "oval", x, y, w, h, ...o }; }
function image(x, y, w, h, data) { return { t: "image", x, y, w, h, data }; }
function text(x, y, w, h, content, o = {}) { return { t: "text", x, y, w, h, content, ...o }; }
function table(x, y, colW, rowH, rows, o = {}) { return { t: "table", x, y, colW, rowH, rows, ...o }; }
function chart(x, y, w, h, labels, values, color) { return { t: "chart", x, y, w, h, labels, values, color }; }
function bullets(x, y, w, h, items, o = {}) { return { t: "bullets", x, y, w, h, items, ...o }; }

// icon chip = rounded coloured square + centred icon image
function iconChip(items, data, x, y, size, fill) {
  items.push(rect(x, y, size, size, { fill, radius: 0.08 }));
  const pad = size * 0.26;
  items.push(image(x + pad, y + pad, size - 2 * pad, size - 2 * pad, data));
}

const shadow = () => ({ type: "outer", color: "9AA7B4", blur: 9, offset: 3, angle: 90, opacity: 0.25 });

async function buildSpec() {
  const ic = {
    power: await renderIcon(FA.FaPowerOff, WHITE),
    check: await renderIcon(FA.FaCheckCircle, WHITE),
    rocket: await renderIcon(FA.FaRocket, WHITE),
    coins: await renderIcon(FA.FaCoins, WHITE),
    trophy: await renderIcon(FA.FaTrophy, TEAL),
    infinity: await renderIcon(FA.FaInfinity, AMBER),
    bullseye: await renderIcon(FA.FaBullseye, WHITE),
    layers: await renderIcon(FA.FaLayerGroup, WHITE),
    bullhorn: await renderIcon(FA.FaBullhorn, WHITE),
    cogs: await renderIcon(FA.FaCogs, WHITE),
    search: await renderIcon(FA.FaSearch, WHITE),
    users: await renderIcon(FA.FaUsers, WHITE),
    form: await renderIcon(FA.FaWpforms, WHITE),
    link: await renderIcon(FA.FaLink, WHITE),
    send: await renderIcon(FA.FaPaperPlane, WHITE),
  };

  const slides = [];

  // shared content-title helper
  function titleBlock(items, t, sub) {
    items.push(text(MARGIN, 0.42, PAGE_W - 2 * MARGIN, 0.72, t,
      { font: FONT, size: 32, bold: true, color: NAVY, align: "center", valign: "middle" }));
    if (sub) items.push(text(MARGIN, 1.12, PAGE_W - 2 * MARGIN, 0.4, sub,
      { font: FONT, size: 14, color: MUTED, align: "center", valign: "middle" }));
  }

  const phc = (t) => ({ text: t, color: PH, bold: true });
  const hdrCell = (t) => ({ text: t, fill: NAVY, color: WHITE, bold: true, align: "center" });
  const mktCell = (t) => ({ text: t, bold: true, color: SLATE, align: "left" });
  const valCell = (t) => ({ text: t, color: PH, bold: true, align: "center" });

  // ============ SLIDE 1 — Title ============
  {
    const items = [];
    items.push(oval(10.6, 4.7, 3.4, 3.4, { fill: TEAL, transparency: 78 }));
    items.push(oval(12.0, 5.7, 2.6, 2.6, { fill: AMBER, transparency: 80 }));
    items.push(text(1.0, 2.5, 11.3, 1.2, "Paid media and campaigns",
      { font: FONT, size: 46, bold: true, color: WHITE, align: "left", valign: "middle" }));
    items.push(text(1.0, 3.72, 11.3, 0.6, "Status, results, and how we build together",
      { font: FONT, size: 20, color: LIGHT, align: "left", valign: "middle" }));
    items.push(text(1.0, 6.55, 11.3, 0.4,
      [{ text: "Marketing meeting, Monday 29 June 2026", color: DIM },
       { text: "      Mapal OS, internal", color: "7F8BA6" }],
      { font: FONT, size: 12.5, align: "left", valign: "middle" }));
    slides.push({ bg: NAVY, items });
  }

  // ============ SLIDE 2 — Where paid stands ============
  {
    const items = [];
    titleBlock(items, "Where paid stands");
    const rows = [
      { ic: ic.power, fill: TEAL, h: "Cleaned up the ad estate",
        d: "Switched off campaigns running with no tracking or no results across Microsoft, Meta, the Nordics and old LinkedIn France campaigns." },
      { ic: ic.check, fill: TEAL, h: "Fixed the demo form tracking",
        d: "It now records correctly in the UK, Spain and France." },
      { ic: ic.rocket, fill: AMBER, h: "Launched the new French Flow search campaigns",
        d: "Brand and non-brand, now live." },
      { ic: ic.coins, fill: AMBER, h: "Pointed wasted spend back at pipeline",
        d: "Recovered budget now sits behind what brings in leads." },
    ];
    const listX = MARGIN, listW = 7.6, rowH = 1.18, gap = 0.12;
    let ry = 1.55;
    rows.forEach((r) => {
      iconChip(items, r.ic, listX, ry + 0.07, 0.66, r.fill);
      items.push(text(listX + 0.92, ry, listW - 0.92, rowH,
        [{ text: r.h, bold: true, color: SLATE, size: 15, br: true }, { text: r.d, color: MUTED, size: 12.5 }],
        { font: FONT, valign: "middle", paraGap: 3 }));
      ry += rowH + gap;
    });
    const cx = 8.7, cw = 4.05;
    items.push(rect(cx, 1.7, cw, 4.0, { fill: TINT_TEAL, radius: 0.12, shadow: shadow() }));
    items.push(text(cx, 2.05, cw, 0.4, "WASTED SPEND CUT", { font: FONT, size: 13, bold: true, color: TEAL, align: "center", charSpacing: 2 }));
    items.push(text(cx, 2.5, cw, 1.5, "~5,800", { font: FONT, size: 80, bold: true, color: NAVY, align: "center", valign: "middle" }));
    items.push(text(cx, 4.2, cw, 1.2, "per month, reinvested into\nwhat brings in pipeline", { font: FONT, size: 16, color: SLATE, align: "center", valign: "top" }));
    slides.push({ bg: WHITE, items });
  }

  // ============ SLIDE 3 — Paid search ============
  {
    const items = [];
    titleBlock(items, "Paid search");
    items.push(text(MARGIN, 1.18, 6, 0.35, [{ text: "Period: ", color: MUTED }, phc("[ PERIOD ]")], { font: FONT, size: 12.5, align: "left" }));
    const rows = [
      [hdrCell("Market"), hdrCell("Spend"), hdrCell("Leads / MQLs"), hdrCell("Cost per lead"), hdrCell("Top campaign")],
      [mktCell("UK"), valCell("[SPEND_UK]"), valCell("[LEADS_UK]"), valCell("[CPL_UK]"), valCell("[TOPCAMP_UK]")],
      [mktCell("Spain"), valCell("[SPEND_ES]"), valCell("[LEADS_ES]"), valCell("[CPL_ES]"), valCell("[TOPCAMP_ES]")],
      [mktCell("France"), valCell("[SPEND_FR]"), valCell("[LEADS_FR]"), valCell("[CPL_FR]"), valCell("[TOPCAMP_FR]")],
    ];
    items.push(table(MARGIN, 1.6, [1.1, 1.45, 1.65, 1.55, 1.95], [0.5, 0.6, 0.6, 0.6], rows));
    items.push(text(MARGIN, 4.25, 7.7, 0.35, "Best keywords or themes", { font: FONT, size: 13, bold: true, color: SLATE }));
    const pills = ["[ KEYWORD_1 ]", "[ KEYWORD_2 ]", "[ KEYWORD_3 ]"];
    let px = MARGIN; const pw = 2.45, ph = 0.5;
    pills.forEach((p) => {
      items.push(rect(px, 4.65, pw, ph, { fill: TINT_TEAL, radius: 0.1 }));
      items.push(text(px, 4.65, pw, ph, p, { font: FONT, size: 12.5, bold: true, color: PH, align: "center", valign: "middle" }));
      px += pw + 0.18;
    });
    items.push(rect(MARGIN, 5.45, 7.7, 1.35, { fill: TINT_AMBER, radius: 0.1 }));
    items.push(text(MARGIN + 0.25, 5.58, 7.2, 0.3, "CAMPAIGN SPOTLIGHT", { font: FONT, size: 11, bold: true, color: AMBER, charSpacing: 2 }));
    items.push(text(MARGIN + 0.25, 5.9, 7.2, 0.8,
      [{ text: "[ SPOTLIGHT_DESC ]", color: PH, bold: true, br: true }, { text: "Audience: ", color: SLATE }, { text: "[ SPOTLIGHT_AUDIENCE ]", color: PH, bold: true }],
      { font: FONT, size: 13, valign: "top", paraGap: 4 }));
    const chX = 8.7, chW = 4.05;
    items.push(text(chX, 1.6, chW, 0.35, "Spend by market", { font: FONT, size: 13, bold: true, color: SLATE }));
    items.push(chart(chX - 0.1, 2.0, chW + 0.15, 3.6, ["UK", "Spain", "France"], [1200, 800, 1000], TEAL));
    items.push(text(chX, 5.62, chW, 0.3, "Placeholder values. Replace with Monday figures.", { font: FONT, size: 10.5, italic: true, color: MUTED }));
    slides.push({ bg: WHITE, items });
  }

  // ============ SLIDE 4 — Paid social ============
  {
    const items = [];
    titleBlock(items, "Paid social");
    items.push(text(MARGIN, 1.18, 6, 0.35, [{ text: "Period: ", color: MUTED }, phc("[ PERIOD ]"), { text: "      LinkedIn", color: MUTED }], { font: FONT, size: 12.5, align: "left" }));
    const rows = [
      [hdrCell("Market"), hdrCell("Spend"), hdrCell("Results"), hdrCell("Cost per result"), hdrCell("Audience")],
      [mktCell("UK / EN"), valCell("[SOC_SPEND_UK]"), valCell("[SOC_RES_UK]"), valCell("[SOC_CPR_UK]"), valCell("[SOC_AUD_UK]")],
      [mktCell("Spain"), valCell("[SOC_SPEND_ES]"), valCell("[SOC_RES_ES]"), valCell("[SOC_CPR_ES]"), valCell("[SOC_AUD_ES]")],
      [mktCell("France"), valCell("[SOC_SPEND_FR]"), valCell("[SOC_RES_FR]"), valCell("[SOC_CPR_FR]"), valCell("[SOC_AUD_FR]")],
    ];
    items.push(table(MARGIN, 1.6, [1.05, 1.7, 1.5, 1.7, 1.75], [0.5, 0.6, 0.6, 0.6], rows));
    items.push(text(MARGIN, 4.25, 7.7, 0.35, "Warm audiences in play", { font: FONT, size: 13, bold: true, color: SLATE }));
    items.push(rect(MARGIN, 4.65, 7.7, 0.6, { fill: TINT_AMBER, radius: 0.1 }));
    items.push(text(MARGIN + 0.2, 4.65, 7.3, 0.6, "[ WARM_AUDIENCES ]", { font: FONT, size: 13, bold: true, color: PH, align: "left", valign: "middle" }));
    items.push(rect(MARGIN, 5.55, 7.7, 1.0, { fill: TINT_TEAL, radius: 0.1 }));
    items.push(text(MARGIN + 0.25, 5.55, 7.2, 1.0, "Search drives the pipeline. Social is for warm retargeting and nurture.", { font: FONT, size: 14.5, bold: true, color: NAVY, align: "left", valign: "middle" }));
    const chX = 8.7, chW = 4.05;
    items.push(text(chX, 1.6, chW, 0.35, "Social spend by market", { font: FONT, size: 13, bold: true, color: SLATE }));
    items.push(chart(chX - 0.1, 2.0, chW + 0.15, 3.6, ["UK / EN", "Spain", "France"], [600, 450, 500], AMBER));
    items.push(text(chX, 5.62, chW, 0.3, "Placeholder values. Replace with Monday figures.", { font: FONT, size: 10.5, italic: true, color: MUTED }));
    slides.push({ bg: WHITE, items });
  }

  // ============ SLIDE 5 — What paid brings in ============
  {
    const items = [];
    titleBlock(items, "What paid brings in");
    const cw = 5.85, ch = 1.65, cy = 1.5;
    items.push(rect(MARGIN, cy, cw, ch, { fill: TINT_TEAL, radius: 0.12 }));
    iconChip(items, ic.trophy, MARGIN + 0.3, cy + 0.5, 0.66, WHITE);
    items.push(text(MARGIN + 1.2, cy, cw - 1.45, ch, "Paid is one of our top two channels by closed-won deals.", { font: FONT, size: 16.5, bold: true, color: NAVY, align: "left", valign: "middle" }));
    const cx2 = MARGIN + cw + 0.3;
    items.push(rect(cx2, cy, cw, ch, { fill: TINT_AMBER, radius: 0.12 }));
    iconChip(items, ic.infinity, cx2 + 0.3, cy + 0.5, 0.66, WHITE);
    items.push(text(cx2 + 1.2, cy, cw - 1.45, ch, "It pays back over the customer life.", { font: FONT, size: 16.5, bold: true, color: NAVY, align: "left", valign: "middle" }));
    items.push(text(MARGIN, 3.45, 12.1, 0.35, "Cost to acquire, high level", { font: FONT, size: 13, bold: true, color: SLATE, align: "left" }));
    const costs = [["[ COST_PER_LEAD ]", "per lead"], ["[ COST_PER_OPP ]", "per opportunity"], ["[ COST_PER_WON ]", "per customer"]];
    const ctW = 3.9, ctGap = 0.2; let ctx = MARGIN;
    costs.forEach(([p, l]) => {
      items.push(rect(ctx, 3.85, ctW, 1.3, { fill: PANEL, radius: 0.1 }));
      items.push(text(ctx, 4.0, ctW, 0.65, p, { font: FONT, size: 28, bold: true, color: PH, align: "center", valign: "middle" }));
      items.push(text(ctx, 4.62, ctW, 0.4, l, { font: FONT, size: 13, color: MUTED, align: "center" }));
      ctx += ctW + ctGap;
    });
    items.push(rect(MARGIN, 5.4, 12.1, 0.92, { fill: NAVY, radius: 0.1 }));
    items.push(text(MARGIN + 0.3, 5.4, 11.5, 0.92,
      [{ text: "About 3x.  ", bold: true, color: AMBER, size: 18 }, { text: "Paid search brings in pipeline at roughly three times the rate of paid social.", color: WHITE, size: 15 }],
      { font: FONT, align: "left", valign: "middle" }));
    items.push(text(MARGIN, 6.5, 12.1, 0.4, "The full monthly PPC KPI report lands Tuesday, so this is the lighter status view.", { font: FONT, size: 12, italic: true, color: MUTED, align: "left" }));
    slides.push({ bg: WHITE, items });
  }

  // ============ SLIDE 6 — Divider ============
  {
    const items = [];
    items.push(oval(-1.2, -1.2, 3.6, 3.6, { fill: TEAL, transparency: 80 }));
    items.push(oval(11.4, 5.2, 3.2, 3.2, { fill: AMBER, transparency: 82 }));
    items.push(text(1.0, 2.85, 11.3, 1.1, "How we build campaigns together", { font: FONT, size: 40, bold: true, color: WHITE, align: "left", valign: "middle" }));
    items.push(text(1.0, 3.95, 11.3, 0.5, "Ownership, the request path, and what every campaign needs.", { font: FONT, size: 18, color: LIGHT, align: "left", valign: "middle" }));
    slides.push({ bg: NAVY, items });
  }

  // ============ SLIDE 7 — One structure ============
  {
    const items = [];
    titleBlock(items, "Every campaign sits in one structure", "And maps to one approved theme, named [REGION]-[ICP]-[THEME].");
    const blocks = [
      { ic: ic.bullseye, fill: NAVY, h: "Business objective", d: "The big-rock priority it ladders up to." },
      { ic: ic.layers, fill: TEAL, h: "Campaign (theme)", d: "The ongoing initiative. [REGION]-[ICP]-[THEME]." },
      { ic: ic.bullhorn, fill: AMBER, h: "Channel or source", d: "Where we reach them: paid social, paid search, email, events." },
      { ic: ic.cogs, fill: NAVY, h: "HubSpot feature", d: "Forms, ads, scoring and workflows that capture and report it." },
    ];
    const gW = 5.95, gH = 1.55, gx0 = MARGIN, gy0 = 1.75, gx = 0.3, gy = 0.3;
    blocks.forEach((b, i) => {
      const col = i % 2, row = Math.floor(i / 2);
      const x = gx0 + col * (gW + gx), y = gy0 + row * (gH + gy);
      items.push(rect(x, y, gW, gH, { fill: PANEL, radius: 0.1, shadow: shadow() }));
      iconChip(items, b.ic, x + 0.3, y + 0.45, 0.66, b.fill);
      items.push(text(x + 1.2, y, gW - 1.45, gH, [{ text: b.h, bold: true, color: NAVY, size: 16, br: true }, { text: b.d, color: MUTED, size: 13 }], { font: FONT, valign: "middle", paraGap: 4 }));
    });
    items.push(rect(MARGIN, 6.15, 12.13, 0.95, { fill: TINT_TEAL, radius: 0.1 }));
    items.push(text(MARGIN + 0.3, 6.15, 11.53, 0.95,
      [{ text: "Why it matters.  ", bold: true, color: TEAL }, { text: "The theme name is the thread that ties spend, leads and pipeline together. If the theme is missing or wrong, the campaign will not show up in reporting.", color: SLATE }],
      { font: FONT, size: 13.5, align: "left", valign: "middle" }));
    slides.push({ bg: WHITE, items });
  }

  // ============ SLIDE 8 — Who owns what ============
  {
    const items = [];
    titleBlock(items, "Who owns what");
    const oW = 5.95, oH = 2.55, oy = 1.55;
    items.push(rect(MARGIN, oy, oW, oH, { fill: TINT_TEAL, radius: 0.12, shadow: shadow() }));
    iconChip(items, ic.search, MARGIN + 0.35, oy + 0.32, 0.7, TEAL);
    items.push(text(MARGIN + 1.25, oy + 0.34, oW - 1.5, 0.7, "Performance owns search", { font: FONT, size: 18, bold: true, color: NAVY, valign: "middle" }));
    items.push(text(MARGIN + 0.35, oy + 1.15, oW - 0.7, oH - 1.3, "Evergreen, always-on search sits with performance all year. Beyond that it is collaborative: you bring the keywords, we build and optimise. Requests fold into the shared evergreen campaigns so the data compounds.", { font: FONT, size: 13.5, color: SLATE, valign: "top", lineMult: 1.05 }));
    const o2x = MARGIN + oW + 0.3;
    items.push(rect(o2x, oy, oW, oH, { fill: TINT_AMBER, radius: 0.12, shadow: shadow() }));
    iconChip(items, ic.users, o2x + 0.35, oy + 0.32, 0.7, AMBER);
    items.push(text(o2x + 1.25, oy + 0.34, oW - 1.5, 0.7, "Growth teams commission paid social", { font: FONT, size: 18, bold: true, color: NAVY, valign: "middle" }));
    items.push(text(o2x + 0.35, oy + 1.15, oW - 0.7, oH - 1.3, "LinkedIn campaigns plus event and content bursts. You bring the brief and assets, performance builds it and wires up the tracking.", { font: FONT, size: 13.5, color: SLATE, valign: "top", lineMult: 1.05 }));
    items.push(rect(MARGIN, oy + oH + 0.25, 12.13, 0.85, { fill: PANEL, radius: 0.1 }));
    items.push(text(MARGIN + 0.3, oy + oH + 0.25, 11.53, 0.85,
      [{ text: "You own the HubSpot campaign.  ", bold: true, color: NAVY }, { text: "Create it for your initiative, named to the theme. Performance links the paid UTMs and leads, so it stays yours.", color: SLATE }],
      { font: FONT, size: 13.5, align: "left", valign: "middle" }));
    items.push(text(MARGIN, oy + oH + 1.2, 12.13, 0.45, "One request path for everything: the PPC Campaign Request form.", { font: FONT, size: 15, bold: true, color: TEAL, align: "center", valign: "middle" }));
    slides.push({ bg: WHITE, items });
  }

  // ============ SLIDE 9 — Three things ============
  {
    const items = [];
    titleBlock(items, "Three things every campaign needs before it goes live");
    const need = [
      { ic: ic.check, fill: TEAL, h: "A working conversion", d: "The action it drives is set up and firing. Verified before launch, not after." },
      { ic: ic.form, fill: AMBER, h: "A tracked form", d: "A live landing page with a HubSpot form that captures the UTM hidden fields. No 404s, no redirects." },
      { ic: ic.link, fill: NAVY, h: "A clean UTM link", d: "Built in the HubSpot URL Builder to the naming standard, not hand-typed or numeric." },
    ];
    const nW = 3.91, nH = 3.2, nGap = 0.2, ny = 1.55; let nx = MARGIN;
    need.forEach((b) => {
      items.push(rect(nx, ny, nW, nH, { fill: PANEL, radius: 0.12, shadow: shadow() }));
      iconChip(items, b.ic, nx + (nW - 0.85) / 2, ny + 0.45, 0.85, b.fill);
      items.push(text(nx + 0.25, ny + 1.5, nW - 0.5, 0.5, b.h, { font: FONT, size: 17, bold: true, color: NAVY, align: "center", valign: "middle" }));
      items.push(text(nx + 0.3, ny + 2.05, nW - 0.6, 1.0, b.d, { font: FONT, size: 13.5, color: MUTED, align: "center", valign: "top", lineMult: 1.05 }));
      nx += nW + nGap;
    });
    items.push(rect(MARGIN, 5.05, 12.13, 1.0, { fill: TINT_TEAL, radius: 0.1 }));
    items.push(text(MARGIN + 0.3, 5.05, 11.53, 1.0, "When these three are set, the campaign launches clean and reports properly. If one is missing, we sort it together before going live.", { font: FONT, size: 14.5, bold: true, color: NAVY, align: "center", valign: "middle" }));
    slides.push({ bg: WHITE, items });
  }

  // ============ SLIDE 10 — How to request ============
  {
    const items = [];
    titleBlock(items, "How to request a campaign");
    const lW = 4.6, lY = 1.7, lH = 4.6;
    items.push(rect(MARGIN, lY, lW, lH, { fill: NAVY, radius: 0.12 }));
    iconChip(items, ic.send, MARGIN + 0.4, lY + 0.45, 0.8, TEAL);
    items.push(text(MARGIN + 0.4, lY + 1.5, lW - 0.8, 1.2, "Submit via the PPC Campaign Request form.", { font: FONT, size: 20, bold: true, color: WHITE, align: "left", valign: "top" }));
    items.push(text(MARGIN + 0.4, lY + 3.2, lW - 0.8, 1.0,
      [{ text: "Build needs ", color: LIGHT }, { text: "3 to 5 working days", color: AMBER, bold: true }, { text: " before your deadline.", color: LIGHT }],
      { font: FONT, size: 16, align: "left", valign: "top" }));
    const rX = MARGIN + lW + 0.4, rW = 12.73 - rX;
    items.push(text(rX, lY, rW, 0.5, "What to provide", { font: FONT, size: 18, bold: true, color: NAVY, align: "left" }));
    const provide = [
      "Market, product and ICP",
      "The theme it maps to, from the approved list",
      "Goal and the conversion it should drive",
      "The live landing page URL, with a HubSpot form on it",
      "Lead routing: nurture, SDR, or both",
      "Assets and copy",
      "Deadline",
    ];
    items.push(bullets(rX, lY + 0.6, rW, lH - 0.6, provide, { font: FONT, size: 15, color: SLATE, gap: 9 }));
    slides.push({ bg: WHITE, items });
  }

  // ============ SLIDE 11 — Closing ============
  {
    const items = [];
    items.push(oval(10.8, -1.0, 3.4, 3.4, { fill: TEAL, transparency: 80 }));
    items.push(oval(-1.0, 5.0, 3.2, 3.2, { fill: AMBER, transparency: 82 }));
    items.push(text(1.0, 2.55, 11.3, 1.4, "One structure. Consistent setup. Better reporting.", { font: FONT, size: 36, bold: true, color: WHITE, align: "left", valign: "middle" }));
    items.push(text(1.0, 4.05, 10.8, 1.0, "Set it up right at the request and it shows up everywhere it should: the Monday snapshot, pipeline, and the campaigns that earn more budget.", { font: FONT, size: 17, color: LIGHT, align: "left", valign: "top", lineMult: 1.1 }));
    items.push(text(1.0, 6.6, 11.3, 0.4, "Mapal OS, internal.", { font: FONT, size: 12.5, color: "7F8BA6", align: "left", valign: "middle" }));
    slides.push({ bg: NAVY, items });
  }

  const notes = [
    "Opening slide for the Monday 10:30 marketing meeting. Two parts: where paid stands, then how we build campaigns together.",
    "Four cleanup and launch moves this week, plus the headline: roughly 5,800 a month of wasted spend cut and redirected to pipeline.",
    "Paid search drives the pipeline. Fill spend, leads, cost per lead and top campaign per market on Monday, plus three best keywords and the spotlight.",
    "Social is the warm layer, not the pipeline driver. Fill spend, results, cost per result and audience per market on Monday, plus the warm audiences in play.",
    "Keep this light for the room. Top two channels, never number one. Cost-to-acquire figures are optional and high level only; the deep numbers are in tomorrow's monthly report.",
    "Transition to Part B. Aimed at growth teams, everyone listens.",
    "Four layers, one thread. The theme name connects everything in reporting.",
    "Search is performance-owned and collaborative. Social is growth-commissioned, performance-built. You own the HubSpot campaign. One request path.",
    "Three pre-launch checks. Enabling framing: if something is missing, we sort it together.",
    "One form, 3 to 5 working days, and the seven inputs needed to build it clean.",
    "Close on the payoff: set it up right once and it shows up everywhere, including the campaigns that earn more budget.",
  ];

  return { slides, notes };
}

// ---------- runs -> pptx rich text ----------
function runsToPptx(content, base) {
  if (typeof content === "string") {
    const parts = content.split("\n");
    return parts.map((p, i) => ({ text: p, options: { breakLine: i < parts.length - 1, ...base } }));
  }
  return content.map((r) => ({
    text: r.text,
    options: { bold: r.bold, italic: r.italic, color: r.color || base.color, fontSize: r.size || base.fontSize, breakLine: !!r.br },
  }));
}

// ============ PPTX EMITTER ============
async function emitPptx(spec) {
  const pres = new pptxgen();
  pres.defineLayout({ name: "W", width: PAGE_W, height: PAGE_H });
  pres.layout = "W";
  pres.author = "Marketing";
  pres.title = "Paid media and campaigns";

  spec.slides.forEach((sl, idx) => {
    const s = pres.addSlide();
    s.background = { color: sl.bg };
    sl.items.forEach((it) => {
      if (it.t === "rect") {
        s.addShape(pres.shapes[it.radius ? "ROUNDED_RECTANGLE" : "RECTANGLE"], {
          x: it.x, y: it.y, w: it.w, h: it.h, fill: { color: it.fill },
          ...(it.radius ? { rectRadius: it.radius } : {}),
          line: { type: "none" }, ...(it.shadow ? { shadow: it.shadow } : {}),
        });
      } else if (it.t === "oval") {
        s.addShape(pres.shapes.OVAL, { x: it.x, y: it.y, w: it.w, h: it.h, fill: { color: it.fill, ...(it.transparency != null ? { transparency: it.transparency } : {}) }, line: { type: "none" } });
      } else if (it.t === "image") {
        s.addImage({ data: it.data, x: it.x, y: it.y, w: it.w, h: it.h });
      } else if (it.t === "text") {
        const base = { color: it.color || SLATE, fontSize: it.size || 14 };
        s.addText(runsToPptx(it.content, base), {
          x: it.x, y: it.y, w: it.w, h: it.h, fontFace: it.font || FONT,
          align: it.align || "left", valign: it.valign || "top", color: it.color || SLATE,
          fontSize: it.size || 14, bold: !!it.bold, italic: !!it.italic, margin: 0,
          ...(it.charSpacing ? { charSpacing: it.charSpacing } : {}),
          ...(it.lineMult ? { lineSpacingMultiple: it.lineMult } : {}),
          ...(it.paraGap ? { paraSpaceAfter: it.paraGap } : {}),
        });
      } else if (it.t === "table") {
        const rows = it.rows.map((r) => r.map((c) => ({
          text: c.text,
          options: { fill: c.fill ? { color: c.fill } : undefined, color: c.color, bold: c.bold, align: c.align || "center", valign: "middle", fontFace: FONT, fontSize: c.fill === NAVY ? 11.5 : 11.5 },
        })));
        s.addTable(rows, { x: it.x, y: it.y, colW: it.colW, rowH: it.rowH, border: { type: "solid", pt: 1, color: HAIR }, valign: "middle", margin: 4, fill: { color: WHITE } });
      } else if (it.t === "chart") {
        s.addChart(pres.charts.BAR, [{ name: "v", labels: it.labels, values: it.values }], {
          x: it.x, y: it.y, w: it.w, h: it.h, barDir: "col", chartColors: [it.color],
          chartArea: { fill: { color: WHITE } }, catAxisLabelColor: MUTED, valAxisLabelColor: MUTED,
          catAxisLabelFontSize: 11, valAxisLabelFontSize: 9, valGridLine: { color: "EAEEF2", size: 0.5 },
          catGridLine: { style: "none" }, showValue: false, showLegend: false, showTitle: false, barGapWidthPct: 60,
        });
      } else if (it.t === "bullets") {
        s.addText(it.items.map((t, i) => ({ text: t, options: { bullet: { code: "2022", indent: 18 }, breakLine: true, paraSpaceAfter: it.gap || 8 } })),
          { x: it.x, y: it.y, w: it.w, h: it.h, fontFace: it.font || FONT, fontSize: it.size || 14, color: it.color || SLATE, valign: "top", margin: 0 });
      }
    });
    if (spec.notes && spec.notes[idx]) s.addNotes(spec.notes[idx]);
  });

  await pres.writeFile({ fileName: "monday-marketing-deck.pptx" });
  console.log("wrote monday-marketing-deck.pptx");
}

// ============ HTML EMITTER (for Chromium QA) ============
function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
const pt2px = (pt) => pt * (PX / 72);

function runsToHtml(content, base) {
  if (typeof content === "string") return esc(content).replace(/\n/g, "<br>");
  return content.map((r) => {
    let st = "";
    if (r.bold) st += "font-weight:700;";
    if (r.italic) st += "font-style:italic;";
    if (r.color) st += `color:#${r.color};`;
    if (r.size) st += `font-size:${pt2px(r.size)}px;`;
    return `<span style="${st}">${esc(r.text)}</span>${r.br ? "<br>" : ""}`;
  }).join("");
}

function emitHtml(spec) {
  const FONT_STACK = "'Calibri','Carlito','Liberation Sans',Arial,sans-serif";
  let body = "";
  spec.slides.forEach((sl) => {
    let inner = "";
    sl.items.forEach((it) => {
      const L = `left:${it.x * PX}px;top:${it.y * PX}px;width:${it.w * PX}px;height:${it.h * PX}px;`;
      if (it.t === "rect") {
        let st = `position:absolute;${L}background:#${it.fill};`;
        if (it.radius) st += `border-radius:${it.radius * PX}px;`;
        if (it.shadow) st += `box-shadow:0 ${it.shadow.offset}px ${it.shadow.blur}px rgba(154,167,180,${it.shadow.opacity});`;
        inner += `<div style="${st}"></div>`;
      } else if (it.t === "oval") {
        const op = it.transparency != null ? (100 - it.transparency) / 100 : 1;
        inner += `<div style="position:absolute;${L}background:#${it.fill};border-radius:50%;opacity:${op};"></div>`;
      } else if (it.t === "image") {
        inner += `<img src="data:${it.data}" style="position:absolute;${L}object-fit:contain;">`;
      } else if (it.t === "text") {
        const align = it.align || "left";
        const valign = it.valign || "top";
        const just = valign === "middle" ? "center" : valign === "bottom" ? "flex-end" : "flex-start";
        let st = `position:absolute;${L}display:flex;flex-direction:column;justify-content:${just};`;
        st += `text-align:${align};color:#${it.color || SLATE};font-size:${pt2px(it.size || 14)}px;`;
        st += `font-weight:${it.bold ? 700 : 400};${it.italic ? "font-style:italic;" : ""}`;
        st += `line-height:${it.lineMult ? it.lineMult : 1.15};`;
        if (it.charSpacing) st += `letter-spacing:${pt2px(it.charSpacing) / 2}px;`;
        const align_self = align === "center" ? "text-align:center;" : "";
        inner += `<div style="${st}"><div style="width:100%;${align_self}">${runsToHtml(it.content, it)}</div></div>`;
      } else if (it.t === "table") {
        let x = it.x;
        // header + rows drawn as absolutely positioned cells
        let cy = it.y;
        it.rows.forEach((row, ri) => {
          let cx = it.x;
          const rh = it.rowH[ri];
          row.forEach((c, ci) => {
            const cwid = it.colW[ci];
            const cl = `left:${cx * PX}px;top:${cy * PX}px;width:${cwid * PX}px;height:${rh * PX}px;`;
            const fill = c.fill ? `#${c.fill}` : "#FFFFFF";
            const al = c.align || "center";
            const fs = 11.5;
            inner += `<div style="position:absolute;${cl}box-sizing:border-box;border:1px solid #${HAIR};background:${fill};display:flex;align-items:center;justify-content:${al === "left" ? "flex-start" : "center"};padding:0 6px;color:#${c.color || SLATE};font-weight:${c.bold ? 700 : 400};font-size:${pt2px(fs)}px;text-align:${al};">${esc(c.text)}</div>`;
            cx += cwid;
          });
          cy += rh;
        });
      } else if (it.t === "chart") {
        const max = Math.max(...it.values);
        const plotH = it.h - 0.4; // leave room for labels
        let bars = "";
        const n = it.values.length;
        const slot = it.w / n;
        const bw = slot * 0.5;
        it.values.forEach((v, i) => {
          const bh = (v / max) * (plotH - 0.2);
          const bx = it.x + i * slot + (slot - bw) / 2;
          const by = it.y + (plotH - bh);
          bars += `<div style="position:absolute;left:${bx * PX}px;top:${by * PX}px;width:${bw * PX}px;height:${bh * PX}px;background:#${it.color};"></div>`;
          bars += `<div style="position:absolute;left:${(it.x + i * slot) * PX}px;top:${(it.y + plotH + 0.05) * PX}px;width:${slot * PX}px;text-align:center;color:#${MUTED};font-size:${pt2px(11)}px;">${esc(it.labels[i])}</div>`;
        });
        // baseline
        bars += `<div style="position:absolute;left:${it.x * PX}px;top:${(it.y + plotH) * PX}px;width:${it.w * PX}px;height:1px;background:#${HAIR};"></div>`;
        inner += bars;
      } else if (it.t === "bullets") {
        let st = `position:absolute;${L}color:#${it.color || SLATE};font-size:${pt2px(it.size || 14)}px;`;
        let lis = it.items.map((t) => `<div style="display:flex;margin-bottom:${pt2px(it.gap || 8)}px;line-height:1.2;"><span style="color:#${TEAL};margin-right:8px;">&#8226;</span><span>${esc(t)}</span></div>`).join("");
        inner += `<div style="${st}">${lis}</div>`;
      }
    });
    body += `<div class="slide" style="background:#${sl.bg};">${inner}</div>`;
  });

  const html = `<!doctype html><html><head><meta charset="utf-8"><style>
  *{margin:0;padding:0;box-sizing:border-box;-webkit-print-color-adjust:exact;print-color-adjust:exact;}
  @page{size:${PAGE_W}in ${PAGE_H}in;margin:0;}
  body{font-family:${FONT_STACK};}
  .slide{position:relative;width:${PAGE_W * PX}px;height:${PAGE_H * PX}px;overflow:hidden;page-break-after:always;}
  </style></head><body>${body}</body></html>`;
  fs.writeFileSync("qa.html", html);
  console.log("wrote qa.html");
}

(async () => {
  const mode = process.argv[2] || "both";
  const spec = await buildSpec();
  if (mode === "pptx" || mode === "both") await emitPptx(spec);
  if (mode === "html" || mode === "both") emitHtml(spec);
})().catch((e) => { console.error(e); process.exit(1); });
