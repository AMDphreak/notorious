# Notorious

- D + dui/dew desktop notes app
- Path deps: `../../dlang-supplemental/{dui,dew}` for co-dev
- Configs: `application` (headless/SoftwareBackend), `windowed` (GLFW+Vello), `unittest`
- Notes live under `%APPDATA%/Notorious/notes` (Windows) or `~/.local/share/notorious/notes`
- Version truth: `VERSION` + `notorious.versioninfo`
- **Launch names:** product UI = Notorious; commands = `note` (primary), `noto` (if `note` conflicts), `notorious` (installer shims + App Paths + optional user PATH). Leave **Noter** free.

## Document kinds (mode strip)

Primary selector: **Plain | Doc | Canvas** (not buried only in Save As).

| Kind | On disk | Keyboard / chrome |
|------|---------|-------------------|
| **Plain** | UTF-8 text; user-visible encoding + EOL | Default for new stickies. Ctrl+B = markup-assist wrap *or* prompt to promote to Doc — never silent rewrite. |
| **Doc** | CentrMark (`.cmk`) source of truth | Semantic formatting; Copy as… / export adapters. |
| **Canvas** | **OCIF** edit + interchange; SVG/PNG export | Excalidraw-like board. Tools in mode **subbar** (and/or left rail when large). |

- First-party format adapters under `source/notorious/formats/` for Copy as… / import. No in-app extension store; no third-party binaries or JS in-process.
- In-memory editor model (`NoteDoc` / scene) for edit ops; **on-disk** truth is Plain / CentrMark / OCIF — not a private JSON forever-format. Legacy note JSON migrates toward these kinds.
- Endorse OCIF per Dev-Centr: https://docs.devcentr.org/general-knowledge/latest/explanation/architecture/open-canvas-interchange.html (hub deploy after GK push). Spec: https://canvasprotocol.org/
- D OCIF codec: first-party reimplementation (nothing useful on DUB); pin OCIF v0.7.0+. Prefer shared package over Notorious-only fork once it exists.

## Chrome

- **Mode-contextual subbars** (not a bottom status bar): Plain → encoding/EOL; Doc → export + format/syntax links; Canvas → tool palette + export OCIF/JSON/SVG.
- Authoritative syntax guides: Dev-Centr docs (online). Optional offline copies; online wins for updates.
- Canvas pen/stroke sampling: drive from **input/pointer polling** (or OS tablet events), not vsync/frame rate.

## Canvas feel

Aim for Excalidraw clarity (top/subbar tools + compact side settings when needed). Prefer responsive ink over web-app stroke lag.
