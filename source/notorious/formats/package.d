/**
 * First-party note format adapters.
 *
 * Policy: formats ship as compiled D modules in-tree (or path-deps we pin).
 * No in-app store, no loading third-party binaries or interpreters into the
 * process. See AGENTS.md / docs note on "format modules".
 */
module notorious.formats;

public import notorious.formats.registry;
public import notorious.formats.builtins;
