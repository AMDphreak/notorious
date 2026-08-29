/**
 * Notorious — sticky notes + notepad hybrid on dui/dew.
 *
 * Modes: Text (notepad) ↔ Canvas (diagram-ready text blocks).
 * Canvas conversion is reversible until non-text shapes exist; Undo restores prior snapshots.
 */
module app;

import std.stdio;
import std.getopt;
import notorious;

void main(string[] args)
{
    bool showVersion;
    bool headlessDemo;
    auto helpInfo = getopt(args,
        "version", "Print version and exit", &showVersion,
        "headless", "Run one SoftwareBackend frame (CI / smoke)", &headlessDemo);
    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter("Notorious — notes that stick.", helpInfo.options);
        return;
    }
    if (showVersion)
    {
        writeln(appVersionLine);
        return;
    }

    auto store = NoteStore.openDefault();
    store.ensureSeed();

    version (NotoriousWindowed)
    {
        if (headlessDemo)
            runHeadlessCatalog(store);
        else
            runWindowedApp(store);
    }
    else
    {
        runHeadlessCatalog(store);
    }
}
