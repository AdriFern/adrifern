# Monte Finder

Single-file web app for finding a home inside a dense Spanish forest.

- **Forests**: 24 forest areas with type, species, density (1–5), fire-risk index (0–100), area, rainfall, altitude, protection status, drive time from Madrid, villages to search, and one-click searches on Idealista, Fotocasa, Milanuncios, Cocampo and Aldeas Abandonadas.
- **Properties**: your shortlist of real ads. Price, land area, forest %, € per forested hectare, forest type, density, fire risk, building state, water/power/road/internet, notes, and a 0–100 fit score. Saved in the browser (localStorage) with JSON copy/paste backup.
- **Buying guide**: legal and safety checklist (suelo rústico, Catastro, Ley de Montes 30-year rule, defensible space) and official map tools (SIGPAC, Mapa Forestal, Iberpix, EFFIS).

## Run

Open `index.html` in a browser. No build, no server.

## Data caveats

- Forest figures are approximate. The fire-risk index is an editorial estimate, not an official statistic.
- The three rows marked **EXAMPLE** in Properties are illustrative, not real ads. Remove them from the "Back up or move your list" panel.
- Edit `FORESTS` in `index.html` to add or correct forests.
