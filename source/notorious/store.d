/// Filesystem catalog of notes (JSON-ish simple format per note).
module notorious.store;

import std.algorithm : filter, map, sort;
import std.array : array, appender;
import std.datetime : Clock, UTC;
import std.file;
import std.json;
import std.path;
import std.string : strip;
import notorious.model;
import dew : ColorRgba;

struct NoteStore
{
    string rootDir;

    static NoteStore openDefault() @safe
    {
        NoteStore s;
        s.rootDir = defaultNotesDir();
        if (!exists(s.rootDir))
            mkdirRecurse(s.rootDir);
        return s;
    }

    void ensureSeed() @safe
    {
        if (listMeta().length)
            return;
        auto n = newNote("Welcome to Notorious");
        n.bodyText =
            "Notorious mixes Notepad and sticky notes.\n\n" ~
            "• Catalog: list / grid / search\n" ~
            "• Per-note background color\n" ~
            "• Text ↔ Canvas mode (Undo to reverse)\n" ~
            "• Ctrl+C copies HTML without the sticky background\n" ~
            "• Ctrl+Shift+C copies Markdown\n";
        save(n);
    }

    string pathFor(string id) const @safe
    {
        return buildPath(rootDir, id ~ ".json");
    }

    NoteDoc[] listAll() @trusted
    {
        NoteDoc[] out_;
        if (!exists(rootDir))
            return out_;
        foreach (DirEntry e; dirEntries(rootDir, "*.json", SpanMode.shallow))
        {
            try
                out_ ~= loadFile(e.name);
            catch (Exception)
            {
            }
        }
        out_.sort!((a, b) => a.updatedIso > b.updatedIso);
        return out_;
    }

    struct NoteMeta
    {
        string id;
        string title;
        string updatedIso;
        ColorRgba background;
        NoteMode mode;
    }

    NoteMeta[] listMeta() @safe
    {
        return listAll().map!(n => NoteMeta(n.id, n.title, n.updatedIso, n.background, n.mode)).array;
    }

    NoteDoc load(string id) @safe
    {
        return loadFile(pathFor(id));
    }

    void save(ref NoteDoc doc) @safe
    {
        import std.format : format;
        auto now = Clock.currTime(UTC());
        doc.updatedIso = format("%04d-%02d-%02dT%02d:%02d:%02dZ",
            now.year, now.month, now.day, now.hour, now.minute, now.second);
        auto text = docToJson(doc).toPrettyString;
        std.file.write(pathFor(doc.id), text);
    }

    void remove(string id) @safe
    {
        auto p = pathFor(id);
        if (exists(p))
            std.file.remove(p);
    }

    NoteDoc[] search(string query) @safe
    {
        import std.string : toLower;
        auto q = query.strip.toLower;
        if (!q.length)
            return listAll();
        return listAll().filter!(n =>
            n.title.toLower.canFind(q) || n.bodyText.toLower.canFind(q)
            || n.canvasTexts.map!(c => c.text.toLower).joiner(" ").canFind(q)).array;
    }
}

string defaultNotesDir() @safe
{
    version (Windows)
    {
        import std.process : environment;
        auto appdata = environment.get("APPDATA", expandTilde("~"));
        return buildPath(appdata, "Notorious", "notes");
    }
    else
    {
        return expandTilde("~/.local/share/notorious/notes");
    }
}

private:

import std.algorithm : canFind, joiner;

NoteDoc loadFile(string path) @trusted
{
    auto bytes = cast(char[]) read(path);
    auto j = parseJSON(bytes.idup);
    return jsonToDoc(j);
}

JSONValue docToJson(const ref NoteDoc doc) @safe
{
    JSONValue o;
    o["id"] = doc.id;
    o["title"] = doc.title;
    o["mode"] = cast(string) doc.mode;
    o["bodyText"] = doc.bodyText;
    o["lineEnding"] = cast(string) doc.lineEnding;
    o["encoding"] = cast(string) doc.encoding;
    o["updatedIso"] = doc.updatedIso;
    o["background"] = [
        "r": JSONValue(doc.background.r),
        "g": JSONValue(doc.background.g),
        "b": JSONValue(doc.background.b),
        "a": JSONValue(doc.background.a),
    ];
    JSONValue[] spans;
    foreach (s; doc.spans)
    {
        JSONValue sj;
        sj["start"] = s.start;
        sj["end"] = s.end;
        sj["bold"] = s.bold;
        sj["fontSize"] = s.fontSize;
        sj["fontFamily"] = s.fontFamily;
        spans ~= sj;
    }
    o["spans"] = spans;
    JSONValue[] cts;
    foreach (c; doc.canvasTexts)
    {
        JSONValue cj;
        cj["id"] = c.id;
        cj["text"] = c.text;
        cj["x"] = c.x;
        cj["y"] = c.y;
        cj["fontSize"] = c.fontSize;
        cj["bold"] = c.bold;
        cj["fontFamily"] = c.fontFamily;
        cts ~= cj;
    }
    o["canvasTexts"] = cts;
    JSONValue[] sh;
    foreach (s; doc.shapes)
    {
        JSONValue sj;
        sj["id"] = s.id;
        sj["kind"] = s.kind;
        sj["x"] = s.x;
        sj["y"] = s.y;
        sj["w"] = s.w;
        sj["h"] = s.h;
        sj["label"] = s.label;
        sh ~= sj;
    }
    o["shapes"] = sh;
    return o;
}

private float jsonFloat(JSONValue v) @trusted
{
    if (v.type == JSONType.float_)
        return cast(float) v.floating;
    if (v.type == JSONType.integer)
        return cast(float) v.integer;
    return 0;
}

NoteDoc jsonToDoc(JSONValue j) @trusted
{
    NoteDoc d;
    d.id = j["id"].str;
    d.title = j["title"].str;
    d.mode = j["mode"].str == "canvas" ? NoteMode.canvas : NoteMode.text;
    d.bodyText = j["bodyText"].str;
    if ("lineEnding" in j)
        d.lineEnding = cast(LineEnding) j["lineEnding"].str;
    if ("encoding" in j)
        d.encoding = cast(TextEncoding) j["encoding"].str;
    if ("updatedIso" in j)
        d.updatedIso = j["updatedIso"].str;
    if ("background" in j)
    {
        auto b = j["background"];
        d.background = ColorRgba(
            cast(ubyte) b["r"].integer,
            cast(ubyte) b["g"].integer,
            cast(ubyte) b["b"].integer,
            cast(ubyte) b["a"].integer);
    }
    if ("spans" in j)
        foreach (s; j["spans"].array)
        {
            TextSpan sp;
            sp.start = cast(size_t) s["start"].integer;
            sp.end = cast(size_t) s["end"].integer;
            sp.bold = s["bold"].boolean;
            sp.fontSize = jsonFloat(s["fontSize"]);
            if ("fontFamily" in s)
                sp.fontFamily = s["fontFamily"].str;
            d.spans ~= sp;
        }
    if ("canvasTexts" in j)
        foreach (c; j["canvasTexts"].array)
        {
            CanvasText ct;
            ct.id = c["id"].str;
            ct.text = c["text"].str;
            ct.x = jsonFloat(c["x"]);
            ct.y = jsonFloat(c["y"]);
            ct.fontSize = jsonFloat(c["fontSize"]);
            ct.bold = c["bold"].boolean;
            if ("fontFamily" in c)
                ct.fontFamily = c["fontFamily"].str;
            d.canvasTexts ~= ct;
        }
    if ("shapes" in j)
        foreach (s; j["shapes"].array)
        {
            CanvasShape sh;
            sh.id = s["id"].str;
            sh.kind = s["kind"].str;
            sh.x = jsonFloat(s["x"]);
            sh.y = jsonFloat(s["y"]);
            sh.w = jsonFloat(s["w"]);
            sh.h = jsonFloat(s["h"]);
            if ("label" in s)
                sh.label = s["label"].str;
            d.shapes ~= sh;
        }
    return d;
}
