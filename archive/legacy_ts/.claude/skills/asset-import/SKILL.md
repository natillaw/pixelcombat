---
name: asset-import
description: Add or use a third-party art/audio asset in Tactical Summoners safely (license, registry, style test). Use when importing a pack, referencing a new file under assets/, or choosing VFX/tiles/enemies/UI art.
---
# Importing or using an asset

1. Never edit `assets/sprites/**` (Caz hero sprites, D-023). Improve heroes only with code animation, effects, separate layers or derived portraits.
2. Free assets only; read the pack's LICENSE first (D-024). Note forbidden uses (resale, standalone redistribution, AI training).
3. Register it in `docs/ASSET_REGISTRY.md` (and `assets/ASSET_REGISTRY.json` via `tools/Import-Asset.ps1` when on Windows).
4. Style test first (D-008): one sample next to a Caz hero at native scale (~16 px figure, 48 px cell). Use the CI screenshots job to see it.
5. Reference real paths: packs live at `assets/packs/<pack>/<pack>/...` (nested). `assets/source_packs/` is a duplicate copy (F-021) — do not reference it.
6. Missing files must degrade gracefully (the code already returns null and keeps placeholders) and be covered by a test.
