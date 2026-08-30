/// Built-in first-party format adapters (compiled in — not plugins).
module notorious.formats.builtins;

import std.array : appender, replace;
import std.format : format;
import std.string : splitLines, strip;
import notorious.model;
import notorious.markdown;
import notorious.html_export;
import notorious.formats.registry;

void registerBuiltinFormats() @safe
{
    registerFormat(FormatAdapter(
        "plaintext", "Plain text", "txt",
        ClipboardKind.plainText, false, false,
        &exportPlain, &importPlain));
    registerFormat(FormatAdapter(
        "markdown", "Markdown", "md",
        ClipboardKind.plainText, true, true,
        &exportMarkdown, &importMarkdown));
    registerFormat(FormatAdapter(
        "centrmark", "CentrMark", "cmk",
        ClipboardKind.plainText, true, true,
        &exportCentrMark, null));
    registerFormat(FormatAdapter(
        "rst", "reStructuredText", "rst",
        ClipboardKind.plainText, true, true,
        &exportRst, null));
    registerFormat(FormatAdapter(
        "asciidoc", "AsciiDoc", "adoc",
        ClipboardKind.plainText, true, true,
        &exportAsciiDoc, null));
    registerFormat(FormatAdapter(
        "html", "HTML", "html",
        ClipboardKind.html, true, true,
        &exportHtml, null));
    registerFormat(FormatAdapter(
        "richtext", "Rich Text (RTF)", "rtf",
        ClipboardKind.rtf, false, false,
        &exportRtf, null));
}

private string bodyOrCanvas(const ref NoteDoc doc) @safe
{
    if (doc.mode == NoteMode.canvas)
    {
        auto ap = appender!string();
        foreach (i, ct; doc.canvasTexts)
        {
            if (i)
                ap.put("\n\n");
            ap.put(ct.text);
        }
        return ap.data;
    }
    return doc.bodyText;
}

string exportPlain(const ref NoteDoc doc) @safe
{
    auto ap = appender!string();
    if (doc.title.length)
    {
        ap.put(doc.title);
        ap.put("\n\n");
    }
    ap.put(bodyOrCanvas(doc));
    return ap.data;
}

NoteDoc importPlain(string source) @safe
{
    auto n = newNote();
    auto lines = source.splitLines;
    if (lines.length && lines[0].strip.length && lines.length > 1 && !lines[1].strip.length)
    {
        n.title = lines[0].strip;
        size_t i = 2;
        auto ap = appender!string();
        for (; i < lines.length; i++)
        {
            if (ap.data.length)
                ap.put("\n");
            ap.put(lines[i]);
        }
        n.bodyText = ap.data;
    }
    else
        n.bodyText = source;
    return n;
}

string exportMarkdown(const ref NoteDoc doc) @safe
{
    return toMarkdown(doc);
}

NoteDoc importMarkdown(string source) @safe
{
    return fromMarkdown(source);
}

/// Lightweight CentrMark-flavored export (title + body paragraphs).
/// Full `centrmark` D package can replace this later via path-dep — still first-party.
string exportCentrMark(const ref NoteDoc doc) @safe
{
    auto ap = appender!string();
    if (doc.title.length)
    {
        ap.put("= ");
        ap.put(doc.title);
        ap.put("\n\n");
    }
    foreach (para; paragraphs(bodyOrCanvas(doc)))
    {
        ap.put(para);
        ap.put("\n\n");
    }
    return ap.data;
}

string exportRst(const ref NoteDoc doc) @safe
{
    auto ap = appender!string();
    if (doc.title.length)
    {
        ap.put(doc.title);
        ap.put("\n");
        foreach (i; 0 .. doc.title.length)
            ap.put("=");
        ap.put("\n\n");
    }
    ap.put(bodyOrCanvas(doc));
    ap.put("\n");
    return ap.data;
}

string exportAsciiDoc(const ref NoteDoc doc) @safe
{
    auto ap = appender!string();
    if (doc.title.length)
    {
        ap.put("= ");
        ap.put(doc.title);
        ap.put("\n\n");
    }
    auto body = bodyOrCanvas(doc);
    // Promote markdown-ish **bold** leftovers into AsciiDoc *bold* lightly.
    ap.put(body.replace("**", "*"));
    ap.put("\n");
    return ap.data;
}

string exportHtml(const ref NoteDoc doc) @safe
{
    return toHtmlFragment(doc);
}

/// Minimal RTF wrapper (ANSI-ish escaped plain). Good enough for clipboard RTF Kind.
string exportRtf(const ref NoteDoc doc) @safe
{
    auto plain = exportPlain(doc);
    auto ap = appender!string();
    ap.put(`{\rtf1\ansi\deff0 {\fonttbl {\f0 Segoe UI;}}\f0\fs24 `);
    foreach (dchar ch; plain)
    {
        if (ch == '\\' || ch == '{' || ch == '}')
        {
            ap.put('\\');
            ap.put(ch);
        }
        else if (ch == '\n')
            ap.put(`\par `);
        else if (ch < 128)
            ap.put(cast(char) ch);
        else
            ap.put(format(`\u%04d?`, cast(int) ch));
    }
    ap.put(`}`);
    return ap.data;
}
