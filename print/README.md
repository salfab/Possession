# Possession V1g — Print-and-Play kit (English)

Output of `tools/print/build.py`. Re-run that script any time the i18n
strings or the card list change.

## Files

- `possession_print_kit_en.pdf` — A4, duplex (long-edge binding), 9 cards
  per page, cut marks at every corner. Page 1 = fronts, Page 2 = backs
  (mirrored for proper duplex alignment), Page 3 = next set of fronts, etc.
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

## Print recipe

1. Open `possession_print_kit_en.pdf`.
2. Print at 100 % scale (no fit-to-page) on **200–250 g/m² cardstock**.
3. Pick **duplex with long-edge binding** in the printer dialog
   (sometimes called "flip on long edge" / "binding on the side"). Backs
   are pre-mirrored so this is the correct option.
4. Cut along the corner marks with a guillotine or a sharp knife and
   metal ruler. Final card size is 65 × 91 mm.
5. Sleeve in standard tarot-size sleeves (or skip — paper alone holds
   up fine for a hotseat prototype).

## Regenerating

From the repo root :

```bash
python tools/print/build.py
```

Requires Python 3.12+ with `Pillow` and `reportlab` installed
(`pip install Pillow reportlab`). Reads the card data straight from
`scripts/data/I18n.gd` so any text change there flows into the next
print kit on the next build.
