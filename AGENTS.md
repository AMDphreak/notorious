# Notorious

- D + dui/dew desktop notes app
- Path deps: `../../dlang-supplemental/{dui,dew}` for co-dev
- Configs: `application` (headless/SoftwareBackend), `windowed` (GLFW+Vello), `unittest`
- Notes live under `%APPDATA%/Notorious/notes` (Windows) or `~/.local/share/notorious/notes`
- Version truth: `VERSION` + `notorious.versioninfo`
- **Formats:** first-party D adapters under `source/notorious/formats/` (registry + builtins). No in-app store; no loading third-party binaries or JS into the process. New formats = PR / in-tree module (or pinned path-dep we own).
- **Copy as…:** Ctrl+Shift+C opens the format picker (clipboard or “Open as code” + navigator stubs).
