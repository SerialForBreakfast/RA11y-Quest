# Quest paint chrome — validation checklist

Use this list to iterate across **size classes**, **devices**, and **accessibility settings**. Check items when verified; note build, date, and device in your PR or memlog entry.

**Related implementation:** `RA11y-iOS/RA11y-iOS/Design/iOSQuestPaintChrome.swift` (`QuestPaintReadableText`, `QuestPaintContentMetrics`, `QuestPaintAmbientBackdrop`, `QuestPaintReadableScrim`).

**Gesture “spell” vocabulary & shared CTAs:** `memlog/requirements/Design/VoiceOver-GestureSpell-Vocabulary.md` — `QuestVoiceOverGestureSpellPlate`, `QuestGameResultActionStack`, `QuestStandardPrimaryButton`.

---

## 1. Typography & VoiceOver (`questPaintReadableText`)

| # | Check | Compact iPhone | Regular (iPad) | Notes |
|---|--------|----------------|----------------|--------|
| 1.1 | Dynamic Type: largest content sizes — no clipping, no overlapping nav | ☐ | ☐ | Scroll where needed; avoid fixed heights for multi-line copy. |
| 1.2 | Dynamic Type: smallest content — hierarchy still obvious | ☐ | ☐ | Serif hero vs body still distinguishable. |
| 1.3 | VoiceOver: each interactive control has a clear label + hint where spec’d | ☐ | ☐ | Styling does not replace labels. |
| 1.4 | VoiceOver: grouped cards (e.g. skill transfer) announce full content once | ☐ | ☐ | No duplicate or missing lines vs on-screen order. |
| 1.5 | Decorative icons next to titles are `accessibilityHidden` or merged into one element | ☐ | ☐ | Avoid redundant focus stops. |
| 1.6 | Gold / accent captions: meaning not color-only | ☐ | ☐ | Wording carries category (e.g. “Encounter”), not hue alone. |
| 1.7 | Reduce Motion: no reliance on animation for meaning | ☐ | ☐ | N/A for static text; note any motion on same screen. |
| 1.8 | Reduce Transparency: material cards + white text remain readable | ☐ | ☐ | Bump contrast if materials flatten. |
| 1.9 | Increase Contrast: body/meta text still legible on scrim + materials | ☐ | ☐ | Shadows are decorative; verify opacity/weight if needed. |

---

## 2. Layout & metrics (`QuestPaintContentMetrics`)

| # | Check | Compact | Regular | Notes |
|---|--------|---------|---------|--------|
| 2.1 | Result / VO gate: reading column centered; no horizontal clip | ☐ | ☐ | No “cut off” headings (e.g. “What You Learned”). |
| 2.2 | Flavor / body paragraphs wrap with comfortable margins | ☐ | ☐ | `frame(maxWidth: .infinity)` + leading alignment inside cards. |
| 2.3 | Primary/secondary CTAs span same width as content column | ☐ | ☐ | Full-width buttons on results. |
| 2.4 | Dungeon result: extra horizontal inset vs other games | ☐ | ☐ | `scrollHunt` ribbon in metrics. |
| 2.5 | iPad: line length capped (~620pt) with side margins | ☐ | ☐ | Not edge-to-edge paragraphs. |
| 2.6 | Safe area: no text under home indicator / notch | ☐ | ☐ | ScrollView + safe area respected. |

---

## 3. Surfaces & adoption (where chrome should apply)

| Surface | Backdrop + scrim | `questPaintReadableText` on copy | Layout metrics | Status |
|---------|------------------|-----------------------------------|----------------|--------|
| `iOSGameResultView` | ☑ | ☑ | ☑ | Migrated (prior pass). |
| `iOSVORequiredView` | ☑ | ☑ | ☑ | Migrated (prior pass). |
| Banishment prologue / intermission / trap card | ☑ | ☑ | ☑ | Migrated (prior pass; Banishment uses bespoke art stack). |
| Enchanter prologue & play (hub flow) | ☑ | ☑ | partial | Shelf bg + L3 dimmed paint; typography on prologue, prompt, HUD, relic rows. |
| Dungeon prologue & play | ☑ | ☑ | partial | Prologue: `dungeon_descent_bg` + scrim; play shaft + L3 dimmed paint; chrome copy styled. |
| Hub (`iOSHubView`) | ☑ | ☑ | ☑ | `iOSHubBackgroundView` uses ambient + scrim; `QuestPaintContentMetrics` for column; cards use material-type roles. |
| First run / Basics entry | ☑ | ☑ | ☑ | `simon_room_bg` + scrim; metrics + hero/body roles; `.clipped()` removed on scroll. |
| `iOSDungeonResonanceMockupView` | ☐ | ☐ | ☐ | *Prototype; lower priority.* |

---

## 4. Visual & assets (non-text)

| # | Check | Notes |
|---|--------|--------|
| 4.1 | No checkerboard fringes on composited sprites (goblin, skeleton, reticle, flare) | Re-run `utility/validate_banishment_assets.sh` / QA scripts. |
| 4.2 | Banishment tower trap: golden ward ring removed per product freeze | Code + art aligned. |
| 4.3 | Z gesture asset: RGBA, transparent exterior matte | `transparent_edge_dark_matte.py` if re-importing. |
| 4.4 | Enchanter “Lights Off” / timed beat: intentional bg (not accidental solid black) | ☑ Dimmed shelf under blackout; Dungeon L3 shaft uses same pattern. Re-verify in screenshots. |
| 4.5 | Fastlane screenshots regenerated after UI changes | `iPhone_large` / `iPhone_small` / `iPad` locales. |

---

## 5. Device / orientation matrix (smoke)

Run at least one **passing** build on each row; mark ☐ → ☑ when done.

| Context | iPhone (compact) | iPhone Pro Max | iPad portrait | iPad landscape |
|---------|------------------|----------------|---------------|----------------|
| Result (each game kind) | ☐ | ☐ | ☐ | ☐ |
| VO Required (each `GameKind`) | ☐ | ☐ | ☐ | ☐ |
| Banishment prologue + trap + tower | ☐ | ☐ | ☐ | ☐ |

---

## 6. Definition of done (release gate)

- [ ] All rows in §1–2 pass on **one** large phone + **one** iPad.
- [ ] §3 surfaces either migrated or explicitly deferred with ticket.
- [ ] §4 asset blockers either fixed or waived with written rationale.
- [ ] Screenshot set updated or ticket filed for Fastlane refresh.

---

## Is `QuestPaintReadableText` “enough” for VoiceOver?

**Mostly yes for visual styling**, with caveats:

- It is **not** a replacement for `accessibilityLabel`, `accessibilityHint`, `accessibilityIdentifier`, heading traits, or escape actions—those stay on containers and controls.
- **Grouping** must be designed explicitly: combined elements need one spoken string that matches reading order.
- **Dynamic Type** and **system accessibility settings** still require **per-screen layout** testing (scroll, truncation).
- **Color** (e.g. gold captions) must not be the only carrier of meaning.

Treat `questPaintReadableText` as the **visual** layer; pair it with the **a11y** layer your screens already define in product specs.
