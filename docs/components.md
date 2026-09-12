<!-- markdownlint-disable MD013 -->
# Component Registry — {{PROJECT_NAME}} (Stage 3)

> Atomic UI components tracked BEFORE full page assembly. Tokens first:
> every component below references `tokens.json`/`tokens.css` values only —
> no raw hex colors, no ad-hoc spacing, no un-tokenized motion.
> Presence is checked by `scripts/verify.sh` on UI projects.

## Registry

| Component | Variants | Props | Token deps | Status |
| --- | --- | --- | --- | --- |
| Button | primary, secondary, ghost | label, onPress, disabled | color.brand, spacing.md, motion.fast | planned |
| TextInput | default, error | value, onChange, label | spacing.sm, color.brand | planned |
| Card | default | title, body | spacing.md, spacing.lg | planned |
| Modal | default | open, onClose | motion.normal, motion.emphasized | planned |

## Rules

- Add a row before building a new atomic component; `planned` -> `built` ->
  `gated` (polish gate passed on its slice).
- Status `gated` requires the slice 3-frame strip + `development_polish_gate`.
- Shared-element transitions declare `layoutId` / `view-transition-name` in
  `.ui-artifacts/interaction-schema.json` first (schema-lock before code).
