module notorious.about;

import dew;
import notorious.versioninfo;

Widget buildAbout() @safe
{
    return VStack(
        Text(appName).fontSize(24).bold(),
        Text(appVersionLine()).fontSize(14),
        Text("Build " ~ buildId()).fontSize(12),
        Text("Sticky notes + notepad on dui/dew. License: BSL-1.0").fontSize(12),
        Text("Shortcuts: Ctrl+C HTML (no bg) · Ctrl+Shift+C Markdown · Ctrl+Z Undo").fontSize(12),
    ).spacing(8).padding(24);
}
