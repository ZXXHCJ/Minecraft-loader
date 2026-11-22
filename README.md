# Minecraft Watchface Installer Lua Sources

This repository publishes the Lua installer sources used by the Minecraft watchface installer for Xiaomi Vela wearable devices.

It contains the public installer entry points and shared UI/progress/visibility-management modules:

- `lua/q66/installer.lua` — Xiaomi Band 11 / q66 installer entry point.
- `lua/o66/installer.lua` — Xiaomi Band 10 / o66 installer entry point.
- `lua/shared/` — shared UI, progress, and visibility-management modules.
- `PROTOCOL.md` — public device-interface and host-contract description.

The Lua files are preserved from the project release. This repository intentionally excludes Minecraft native ELF modules, theme assets, firmware addresses, private recovery code, signing material, and internal build configuration.

## Canopus reference and license

The installer flow was developed with reference to the public Canopus installer conventions. Canopus is an independent community project and this repository is not endorsed by it.

Canopus publishes its installer code under the **GNU Affero General Public License v3.0 only (AGPL-3.0-only)**. This repository uses the same license for the corresponding installer source. See `LICENSE`.

If you redistribute modified versions of these installer sources, retain the license and copyright notices and provide the corresponding source under AGPLv3.
