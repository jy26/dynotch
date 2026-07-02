# dyNotch — Branding

## The name

**dyNotch** — a **DY**namic **NOTCH**. It's a portmanteau of "dynamic" and
"notch"; the tagline spells it out so the pun lands.

## Three casings, three jobs

| Casing | Where it's used |
|---|---|
| **dyNotch** | The written display name — prose, docs, the menu bar, and any UI string. One internal capital, reads instantly, sits naturally next to the code slug. |
| **DYnoTCH** | The **logo / wordmark** treatment only (app icon, splash, banner). Not for running text. |
| `dynotch` | The lowercase slug — repo (`jy26/dynotch`), local folder, `Sources/dynotch/` path, SwiftPM product, and built executable. |

## The DYnoTCH wordmark idea

The casing isn't random — it makes the word *look* like a notch. The only two
x-height letters (`n`, `o`) are lowercase and sit in the middle, flanked by
full-height capitals, so the top edge dips in the middle while the baseline stays
flat — exactly a notch silhouette:

```
D Y     T C H      ← caps: full height
    n o            ← lowercase: dips down  = the notch
────────────────   ← flat baseline
```

Why it works — and the rule to preserve:

- The dip must come from **x-height letters with no descender** (`n`, `o`), so the
  bottom stays flat like a real notch.
- **`Y` is capitalized on purpose:** a lowercase `y` has a descender that would
  poke below the baseline and break the flat bottom.

### Directions to explore for the logo (Milestone 6)

- Kern/group the wordmark into three visual clusters: `DY · no · TCH`.
- Optionally cut a literal rectangular notch out of the top of the `no`.
- Keep the baseline flat — avoid any glyph with a descender in the dip.

This is a note for the icon/logo work in **Milestone 6 (Polish & distribution)**;
nothing here changes the code or the written name.
