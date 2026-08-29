/// HTML clipboard export without document / sticky background color.
module notorious.html_export;

import std.array : appender, replace;
import std.format : format;
import notorious.model;

/**
 * HTML fragment suitable for Ctrl+C.
 * Omits body/background styles so paste targets keep their own chrome.
 */
string toHtmlFragment(const ref NoteDoc doc) @safe
{
    auto ap = appender!string();
    if (doc.title.length)
        ap.put(format("<h1>%s</h1>", escape(doc.title)));

    if (doc.mode == NoteMode.canvas)
    {
        foreach (ct; doc.canvasTexts)
        {
            string style = format("font-size:%.0fpx;font-family:%s;",
                ct.fontSize, escape(ct.fontFamily));
            if (ct.bold)
                style ~= "font-weight:bold;";
            ap.put(format("<p style=\"%s\">%s</p>", style, escape(ct.text).replace("\n", "<br>")));
        }
    }
    else
    {
        ap.put("<p>");
        ap.put(escapeWithSpans(doc.bodyText, doc.spans));
        ap.put("</p>");
    }
    return ap.data;
}

private string escape(string s) @safe pure
{
    return s
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("\"", "&quot;");
}

private string escapeWithSpans(string body, const TextSpan[] spans) @safe
{
    if (!spans.length)
        return escape(body).replace("\n", "<br>");
    import std.algorithm : sort;
    auto sorted = spans.dup;
    sorted.sort!((a, b) => a.start < b.start);
    auto ap = appender!string();
    size_t cursor;
    foreach (s; sorted)
    {
        if (s.start > body.length || s.end > body.length || s.start >= s.end)
            continue;
        if (cursor < s.start)
            ap.put(escape(body[cursor .. s.start]).replace("\n", "<br>"));
        string open = "<span style=\"";
        if (s.bold)
            open ~= "font-weight:bold;";
        open ~= format("font-size:%.0fpx;font-family:%s;\">", s.fontSize, escape(s.fontFamily));
        ap.put(open);
        ap.put(escape(body[s.start .. s.end]).replace("\n", "<br>"));
        ap.put("</span>");
        cursor = s.end;
    }
    if (cursor < body.length)
        ap.put(escape(body[cursor .. $]).replace("\n", "<br>"));
    return ap.data;
}

unittest
{
    NoteDoc d;
    d.title = "T";
    d.bodyText = "x";
    d.background = ColorRgba.rgb(255, 0, 0);
    auto html = toHtmlFragment(d);
    assert(html.canFind("<h1>T</h1>"));
    assert(!html.canFind("background"));
    assert(!html.canFind("rgb(255, 0, 0)"));
}

import dew : ColorRgba;
import std.algorithm : canFind;
