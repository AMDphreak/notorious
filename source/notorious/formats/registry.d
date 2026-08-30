/// Format adapter contract + process-local registry.
module notorious.formats.registry;

import notorious.model;

/// How the format prefers to land on the clipboard.
enum ClipboardKind : ubyte
{
    plainText, /// UTF-8 / Unicode text
    html, /// HTML fragment (+ plain fallback)
    rtf, /// Rich Text (plain fallback until RTF writer matures)
}

/**
 * One export/import surface for a document serialization.
 * Keep adapters pure/stringly — no AST walks of the UI tree, no JS.
 */
struct FormatAdapter
{
    string id; /// Stable id: "markdown", "asciidoc", …
    string label; /// UI label
    string extension; /// Default file suffix without dot
    ClipboardKind clipboard = ClipboardKind.plainText;
    bool supportsPreview; /// Show “open preview” affordance when editing as code
    bool isCodeVariety; /// Treat as source for navigator compare / codebox preview

    string function(const ref NoteDoc doc) @safe exportText;
    /// Optional: parse source back into a text-mode note. Null = export-only for now.
    NoteDoc function(string source) @safe importText;
}

private FormatAdapter[] gFormats;

/// Register a format (call from builtins at startup / first use).
void registerFormat(FormatAdapter f) @safe
{
    foreach (ref existing; gFormats)
        if (existing.id == f.id)
        {
            existing = f;
            return;
        }
    gFormats ~= f;
}

const(FormatAdapter)[] allFormats() @safe
{
    ensureBuiltins();
    return gFormats;
}

bool tryFindFormat(string id, out FormatAdapter found) @safe
{
    ensureBuiltins();
    foreach (f; gFormats)
        if (f.id == id)
        {
            found = f;
            return true;
        }
    return false;
}

FormatAdapter* findFormat(string id) @trusted
{
    ensureBuiltins();
    foreach (ref f; gFormats)
        if (f.id == id)
            return &f;
    return null;
}

private bool gBuiltinsReady;

private void ensureBuiltins() @safe
{
    if (gBuiltinsReady)
        return;
    gBuiltinsReady = true;
    import notorious.formats.builtins : registerBuiltinFormats;
    registerBuiltinFormats();
}

unittest
{
    auto all = allFormats();
    assert(all.length >= 7);
    assert(findFormat("markdown") !is null);
    assert(findFormat("centrmark") !is null);
}
