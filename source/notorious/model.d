/// Document model: text vs canvas modes, formatting spans, undo snapshots.
module notorious.model;

import std.algorithm : canFind, map, joiner;
import std.array : array, appender;
import std.conv : to;
import std.string : splitLines, strip, join;
import std.uuid : randomUUID;
import dew : ColorRgba;

enum NoteMode : string
{
    text = "text",
    canvas = "canvas",
}

enum LineEnding : string
{
    lf = "lf",
    crlf = "crlf",
    cr = "cr",
}

enum TextEncoding : string
{
    utf8 = "utf-8",
    utf8Bom = "utf-8-bom",
}

/// Inline formatting run inside the text body (offsets in UTF-8 code units).
struct TextSpan
{
    size_t start;
    size_t end;
    bool bold;
    float fontSize = 14;
    string fontFamily = "Segoe UI";
}

/// Canvas text object (converted from paragraphs; free placement later).
struct CanvasText
{
    string id;
    string text;
    float x = 24;
    float y = 24;
    float fontSize = 14;
    bool bold;
    string fontFamily = "Segoe UI";
}

/// Non-text diagram primitives — presence blocks reverse conversion to text mode.
struct CanvasShape
{
    string id;
    string kind; // rect, ellipse, line, arrow, …
    float x, y, w, h;
    string label;
}

struct NoteDoc
{
    string id;
    string title = "Untitled";
    NoteMode mode = NoteMode.text;
    /// Plain body used in text mode (and kept as recovery snapshot).
    string bodyText;
    TextSpan[] spans;
    CanvasText[] canvasTexts;
    CanvasShape[] shapes;
    ColorRgba background = ColorRgba.rgb(255, 249, 196); // sticky yellow
    LineEnding lineEnding = LineEnding.lf;
    TextEncoding encoding = TextEncoding.utf8;
    string updatedIso;
}

/// True when canvas still only has text blocks (safe to reverse to notepad).
bool canRevertToText(const ref NoteDoc doc) @safe pure nothrow
{
    return doc.shapes.length == 0;
}

NoteDoc newNote(string title = "Untitled") @safe
{
    NoteDoc n;
    n.id = randomUUID().toString;
    n.title = title;
    n.bodyText = "";
    n.background = ColorRgba.rgb(255, 249, 196);
    return n;
}

/// Split body into paragraphs (blank-line separated) for canvas conversion.
string[] paragraphs(string body) @safe
{
    auto lines = body.splitLines;
    string[] paras;
    auto cur = appender!string();
    void flush()
    {
        auto t = cur.data.strip;
        if (t.length)
            paras ~= t;
        cur = appender!string();
    }

    foreach (line; lines)
    {
        if (!line.strip.length)
            flush();
        else
        {
            if (cur.data.length)
                cur.put("\n");
            cur.put(line);
        }
    }
    flush();
    if (!paras.length && body.strip.length)
        paras ~= body.strip;
    return paras;
}

/**
 * Convert notepad body → canvas text objects (stacked).
 * Caller should push undo snapshot first.
 */
void convertTextToCanvas(ref NoteDoc doc) @safe
{
    doc.canvasTexts.length = 0;
    auto paras = paragraphs(doc.bodyText);
    float y = 32;
    foreach (i, p; paras)
    {
        CanvasText ct;
        ct.id = randomUUID().toString;
        ct.text = p;
        ct.x = 32;
        ct.y = y;
        ct.fontSize = 14;
        doc.canvasTexts ~= ct;
        y += 28 + cast(float)(p.splitLines.length) * 18;
    }
    if (!doc.canvasTexts.length)
    {
        CanvasText ct;
        ct.id = randomUUID().toString;
        ct.text = "";
        ct.x = 32;
        ct.y = 32;
        doc.canvasTexts ~= ct;
    }
    doc.mode = NoteMode.canvas;
}

/**
 * Reverse canvas text → notepad body when no shapes exist.
 * Returns false if locked by diagramming content.
 */
bool convertCanvasToText(ref NoteDoc doc) @safe
{
    if (!canRevertToText(doc))
        return false;
    auto ap = appender!string();
    foreach (i, ct; doc.canvasTexts)
    {
        if (i)
            ap.put("\n\n");
        ap.put(ct.text);
    }
    doc.bodyText = ap.data;
    doc.canvasTexts.length = 0;
    doc.mode = NoteMode.text;
    return true;
}

string applyLineEndings(string text, LineEnding le) @safe pure
{
    import std.array : replace;
    auto norm = text.replace("\r\n", "\n").replace("\r", "\n");
    final switch (le)
    {
    case LineEnding.lf:
        return norm;
    case LineEnding.crlf:
        return norm.replace("\n", "\r\n");
    case LineEnding.cr:
        return norm.replace("\n", "\r");
    }
}

unittest
{
    auto n = newNote("t");
    n.bodyText = "Hello\n\nWorld";
    convertTextToCanvas(n);
    assert(n.mode == NoteMode.canvas);
    assert(n.canvasTexts.length == 2);
    assert(canRevertToText(n));
    assert(convertCanvasToText(n));
    assert(n.mode == NoteMode.text);
    assert(n.bodyText.canFind("Hello"));
    n.shapes ~= CanvasShape("1", "rect", 0, 0, 10, 10, "");
    convertTextToCanvas(n);
    assert(!convertCanvasToText(n));
}
