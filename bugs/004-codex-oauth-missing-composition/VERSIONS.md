# Versions - bug 004

- First seen broken: `@deepseek-ai/dsh` 0.1.1-rc.2, installed bundle on
  2026-09-12.
- Pristine patch base: `@deepseek-ai/dsh-base` 0.1.1-rc.2 from the npm
  registry (`npm pack @deepseek-ai/dsh-base@0.1.1-rc.2`).
- Verified fixed-locally: installed bundle after applying the stored patch on
  2026-09-12; DSH web profile booted and the composed config includes the
  authorization service.
