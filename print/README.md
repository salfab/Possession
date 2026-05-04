# Possession V1g — Print-and-Play kit (English)

Output of `tools/print/build.py`. Re-run that script any time the i18n
strings or the card list change.

## Files

- `possession_print_kit_en.pdf` — A4, duplex (long-edge binding), 9 cards
  per page, cut marks at every corner. Page 1 = fronts, Page 2 = backs
  (mirrored for proper duplex alignment), Page 3 = next set of fronts, etc.
- `possession_board_a3.pdf` — A3 landscape, single page with the game
  board centred and full-bleed inside a 10 mm margin. Cut marks at the
  four corners of the board image.
- `possession_banners_a4.pdf` — A4 portrait, 4 pages, 3 banners per
  page. The 11 liturgy-banner variants in station order with both modes
  adjacent (in_integro then impedita), plus the single-sided Exorcism
  banner at the end. Cut and glue back-to-back to make 5 double-sided
  station banners + 1 single-sided Exorcism banner.
- `cards_individual/*.png` — every card face as a 900×1260 PNG, one
  `_A.png` (front face) and one `_B.png` (back face) per card. Useful for
  spot-checking before printing or for sharing single-card previews.

## Inventory (18 physical cards = 36 faces)

- **10 Transgressions** : Scandal face / Infamy face — illustration on
  both faces, Required Domain + effect text per face.
- **5 Liturgical Responses** (Stations I–V) : In Integro / Impedita —
  text-only, with the Targeting rule reproduced on each face.
- **1 Final Exorcism** (Station VI) : painted front + Endgame Rules back.
- **2 Player aids** :
  - *Station & Pulse* — how a Station unfolds, what an action is, key
    tie-breakers + Soul Rupture / Fiat Tenebris conditions.
  - *Demon Actions* — every action a demon can take, costed and described.

## Print recipes

### Cards (`possession_print_kit_en.pdf`)
1. Print at 100 % scale (no fit-to-page) on **200–250 g/m² cardstock**.
2. Pick **duplex with long-edge binding** in the printer dialog
   (sometimes called "flip on long edge" / "binding on the side"). Backs
   are pre-mirrored so this is the correct option.
3. Cut along the corner marks. Final card size **65 × 91 mm**.
4. Sleeve in standard tarot-size sleeves (or skip — paper alone holds
   up fine for a hotseat prototype).

### Board (`possession_board_a3.pdf`)
1. Send to a print shop with **A3 landscape** capability. Home printers
   that don't do A3 can scale to A4 (you'll lose readability of the
   small symbols on the corruption track).
2. Print at 100 % scale on **160–250 g/m² paper or thin card**.
3. Cut along the corner marks. Final size **400 × 277 mm**.
4. Optional : mount on a thin chipboard backer for rigidity.

### Banners (`possession_banners_a4.pdf`)
1. Print all 4 pages **single-sided** at 100 % scale on **160 g/m²
   paper** (regular cardstock is too thick for back-to-back gluing).
2. Cut along the corner marks. Each banner is **180 × 67.5 mm**.
3. Pair adjacent banners (in_integro on top of impedita for the same
   station) and glue back-to-back with a glue stick or repositionable
   adhesive — gives 5 double-sided station banners. The Exorcism
   banner at the end stays single-sided.

## Regenerating

From the repo root :

```bash
python tools/print/build.py
```

Requires Python 3.12+ with `Pillow` and `reportlab` installed
(`pip install Pillow reportlab`). Reads the card data straight from
`scripts/data/I18n.gd` so any text change there flows into the next
print kit on the next build.
