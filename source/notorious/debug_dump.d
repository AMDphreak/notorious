module notorious.debug_dump;

import std.file;
import std.path;
import std.stdio;
import std.array : appender;
import std.format : format;
import notorious.versioninfo;
import notorious.store;

/// Write a redacted support dump next to the notes folder; returns path.
string writeDebugDump(ref NoteStore store) @safe
{
    auto dir = buildPath(dirName(store.rootDir), "dumps");
    if (!exists(dir))
        mkdirRecurse(dir);
    auto path = buildPath(dir, "notorious-dump.txt");
    auto ap = appender!string();
    ap.put(appVersionLine());
    ap.put("\nbuild=");
    ap.put(buildId());
    ap.put("\nnotesDir=");
    ap.put(store.rootDir);
    ap.put("\nnoteCount=");
    ap.put(format("%s", store.listMeta().length));
    ap.put("\n(no note bodies or clipboard contents included)\n");
    std.file.write(path, ap.data);
    return path;
}
