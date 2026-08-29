/// Markdown ↔ note body / clipboard.
module notorious.markdown;

import std.array : appender, replace;
import std.algorithm : startsWith;
import std.string : splitLines, strip;
import notorious.model;

/// Export note content as Markdown (no sticky background concepts).
string toMarkdown(const ref NoteDoc doc) @safe
{
    auto ap = appender!string();
    if (doc.title.length)
    {
        ap.put("# ");
        ap.put(doc.title);
        ap.put("\n\n");
    }
    if (doc.mode == NoteMode.canvas)
    {
        foreach (i, ct; doc.canvasTexts)
        {
            if (i)
                ap.put("\n\n");
            if (ct.bold)
            {
                ap.put("**");
                ap.put(ct.text);
                ap.put("**");
            }
            else
                ap.put(ct.text);
        }
    }
    else
    {
        // Apply bold spans roughly as **…** for overlapping runs (simple).
        ap.put(spansToMarkdown(doc.bodyText, doc.spans));
    }
    return ap.data;
}

string spansToMarkdown(string body, const TextSpan[] spans) @safe
{
    if (!spans.length)
        return body;
    // Minimal: wrap each bold span (assumes non-overlapping, sorted).
    char[] buf = body.dup;
    // Work from end so offsets stay valid.
    import std.algorithm : sort;
    auto sorted = spans.dup;
    sorted.sort!((a, b) => a.start > b.start);
    foreach (s; sorted)
    {
        if (!s.bold || s.end > buf.length || s.start >= s.end)
            continue;
        auto mid = buf[s.start .. s.end].idup;
        buf = buf[0 .. s.start] ~ ("**" ~ mid ~ "**") ~ buf[s.end .. $];
    }
    return buf.idup;
}

/// Parse a small Markdown subset into a text-mode note (title from first # heading).
NoteDoc fromMarkdown(string md) @safe
{
    auto n = newNote();
    auto lines = md.splitLines;
    size_t i;
    if (lines.length && lines[0].strip.startsWith("# "))
    {
        n.title = lines[0].strip[2 .. $].strip;
        i = 1;
        while (i < lines.length && !lines[i].strip.length)
            i++;
    }
    auto ap = appender!string();
    for (; i < lines.length; i++)
    {
        if (ap.data.length)
            ap.put("\n");
        auto line = lines[i];
        // strip simple **bold** markers into spans
        string plain;
        size_t pos;
        while (pos < line.length)
        {
            auto idx = indexOf(line[pos .. $], "**");
            if (idx < 0)
            {
                plain ~= line[pos .. $];
                break;
            }
            plain ~= line[pos .. pos + idx];
            pos += idx + 2;
            auto end = indexOf(line[pos .. $], "**");
            if (end < 0)
            {
                plain ~= line[pos .. $];
                break;
            }
            auto startOff = n.bodyText.length + plain.length; // approximate after join — fixed below
            auto boldText = line[pos .. pos + end];
            plain ~= boldText;
            // spans fixed after full body built
            pos += end + 2;
        }
        ap.put(stripBoldMarkers(line));
    }
    n.bodyText = ap.data;
    // Second pass for bold spans on full body
    n.spans = extractBoldSpans(n.bodyText);
    n.bodyText = stripAllBoldMarkers(n.bodyText);
    // Rebuild spans against stripped body: re-parse simply
    n.spans = extractBoldSpansFromSource(md, n.bodyText);
    return n;
}

private:

ptrdiff_t indexOf(string s, string needle) @safe pure
{
    import std.string : indexOf;
    return s.indexOf(needle);
}

string stripBoldMarkers(string s) @safe
{
    return s.replace("**", "");
}

string stripAllBoldMarkers(string s) @safe
{
    return s.replace("**", "");
}

TextSpan[] extractBoldSpans(string withMarkers) @safe
{
    TextSpan[] spans;
    // unused helper placeholder
    return spans;
}

TextSpan[] extractBoldSpansFromSource(string md, string plainBody) @safe
{
    // Best-effort: find **segments** in md body and map into plain offsets.
    TextSpan[] spans;
    import std.string : indexOf;
    auto src = md;
    // skip title line
    auto nl = src.indexOf("\n");
    if (nl >= 0 && src[0] == '#')
        src = src[nl + 1 .. $];
    size_t plainPos;
    size_t i;
    while (i + 1 < src.length)
    {
        if (src[i] == '*' && src[i + 1] == '*')
        {
            i += 2;
            auto end = src[i .. $].indexOf("**");
            if (end < 0)
                break;
            auto text = src[i .. i + end];
            TextSpan sp;
            sp.start = plainPos;
            sp.end = plainPos + text.length;
            sp.bold = true;
            spans ~= sp;
            plainPos += text.length;
            i += end + 2;
        }
        else
        {
            if (src[i] != '\r')
                plainPos++;
            i++;
        }
    }
    return spans;
}

unittest
{
    NoteDoc d;
    d.title = "Hi";
    d.bodyText = "hello";
    auto md = toMarkdown(d);
    assert(md.canFind("# Hi"));
    assert(md.canFind("hello"));
}

import std.algorithm : canFind;
