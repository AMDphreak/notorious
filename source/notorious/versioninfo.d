module notorious.versioninfo;

import std.string : strip;

enum string appName = "Notorious";
enum string appVersion = {
    return import("VERSION").strip;
}();

string appVersionLine() @safe
{
    import std.format : format;
    return format("%s %s (dui/dew notes)", appName, appVersion);
}

string buildId() @safe
{
    // Overridden in CI via -version=NotoriousBuildId / string import later.
    return appVersion ~ "+local";
}
