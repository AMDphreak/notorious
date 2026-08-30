/**
 * Copy-as selector + code/source view chrome (navigator / preview hooks).
 *
 * Ctrl+Shift+C opens the modal. Choosing a format copies via the registry.
 * "Open as code" switches the editor into a source pane with optional right
 * navigator (minimap) and compare/preview affordances — preview rendering is
 * stubbed until format HTML/preview backends land per adapter.
 */
module notorious.copy_as;

import std.format : format;
import dew;
import dui;
import notorious.model;
import notorious.formats;

enum SourceViewMode : ubyte
{
    none,
    code,
}

struct CopyAsState
{
    State!bool open = State!bool(false);
    State!string lastFormat = State!string("");
    State!string status = State!string("");
    State!string sourceFormatId = State!string("");
    State!string sourceText = State!string("");
    State!bool showNavigator = State!bool(true);
    State!bool showPreview = State!bool(false);
    State!bool compareMode = State!bool(false);
}

void openCopyAs(ref CopyAsState st) @safe
{
    st.open = true;
    st.status = "Copy as…";
}

void closeCopyAs(ref CopyAsState st) @safe
{
    st.open = false;
}

bool copyFormatId(ref NoteDoc doc, ref CopyAsState st, ref State!string editorStatus, string formatId) @safe
{
    auto f = findFormat(formatId);
    if (f is null || f.exportText is null)
    {
        st.status = "Unknown format";
        return false;
    }
    auto payload = f.exportText(doc);
    bool ok;
    final switch (f.clipboard)
    {
    case ClipboardKind.plainText:
        ok = copyText(payload);
        break;
    case ClipboardKind.html:
        {
            auto plainF = findFormat("plaintext");
            auto plain = (plainF !is null && plainF.exportText !is null)
                ? plainF.exportText(doc) : doc.bodyText;
            ok = copyHtml(payload, plain);
        }
        break;
    case ClipboardKind.rtf:
        ok = copyText(payload);
        break;
    }
    st.lastFormat = formatId;
    st.status = ok ? format("Copied as %s", f.label) : "Clipboard copy failed";
    editorStatus = st.status.value;
    closeCopyAs(st);
    return ok;
}

void openAsCode(ref NoteDoc doc, ref CopyAsState st, ref State!string editorStatus, string formatId) @safe
{
    auto f = findFormat(formatId);
    if (f is null || f.exportText is null)
    {
        st.status = "Unknown format";
        return;
    }
    st.sourceFormatId = formatId;
    st.sourceText = f.exportText(doc);
    st.showNavigator = true;
    st.showPreview = false;
    st.compareMode = false;
    closeCopyAs(st);
    editorStatus = format("Editing as %s — Preview / Compare in the side panel", f.label);
}

void closeSourceView(ref CopyAsState st, ref State!string editorStatus) @safe
{
    st.sourceFormatId = "";
    st.sourceText = "";
    st.showPreview = false;
    st.compareMode = false;
    editorStatus = "Back to note";
}

Widget buildCopyAsModal(ref NoteDoc doc, ref CopyAsState st, ref State!string editorStatus) @safe
{
    if (!st.open.value)
        return Spacer(0);

    Widget[] rows;
    rows ~= Text("Copy as").fontSize(18).bold();
    rows ~= Text("Clipboard export, or open the serialization as editable source.")
        .fontSize(12);

    foreach (f; allFormats())
    {
        auto id = f.id;
        auto label = f.label;
        rows ~= HStack(
            Button(label).touchFriendly().width(160).onClick(() {
                copyFormatId(doc, st, editorStatus, id);
            }),
            Button("Open as code").touchFriendly().onClick(() {
                openAsCode(doc, st, editorStatus, id);
            }),
        ).spacing(8);
    }

    rows ~= Button("Cancel").touchFriendly().onClick(() { closeCopyAs(st); });
    rows ~= Text(st.status.value).fontSize(11);

    return Container(
        VStack(rows).spacing(8).padding(16)
    )
        .background(ColorRgba.rgb(250, 250, 252))
        .padding(4)
        .width(420);
}

Widget buildNavigatorPanel(ref CopyAsState st) @safe
{
    if (!st.showNavigator.value || !st.sourceFormatId.value.length)
        return Spacer(0);

    auto f = findFormat(st.sourceFormatId.value);
    auto title = f !is null ? f.label : st.sourceFormatId.value;

    Widget[] kids;
    kids ~= HStack(
        Text(title ~ " navigator").fontSize(12).bold(),
        Spacer(),
        Button(st.compareMode.value ? "Compare: on" : "Compare").touchFriendly()
            .onClick(() { st.compareMode = !st.compareMode.value; }),
        Button(st.showPreview.value ? "Preview: on" : "Preview").touchFriendly()
            .onClick(() {
                if (f !is null && f.supportsPreview)
                    st.showPreview = !st.showPreview.value;
            }),
    ).spacing(6).width(Length.percent(100));

    auto zoomed = st.sourceText.value;
    if (zoomed.length > 800)
        zoomed = zoomed[0 .. 800] ~ "\n…";
    kids ~= Text(zoomed.length ? zoomed : "(empty)")
        .fontSize(8)
        .width(Length.percent(100));

    if (st.compareMode.value)
        kids ~= Text("Compare: before/after vs last saved export (stub).").fontSize(11);
    if (st.showPreview.value)
        kids ~= Text("Preview pane (stub) — rendered view beside source next.").fontSize(11);

    return VStack(kids)
        .spacing(6)
        .padding(8)
        .width(220)
        .background(ColorRgba.rgb(240, 242, 246));
}

Widget buildSourceEditor(ref NoteDoc doc, ref CopyAsState st, ref State!string editorStatus) @safe
{
    auto f = findFormat(st.sourceFormatId.value);
    auto label = f !is null ? f.label : "source";

    return HStack(
        VStack(
            HStack(
                Text("Source · " ~ label).fontSize(14).bold(),
                Spacer(),
                Button("Copy").touchFriendly().onClick(() {
                    if (st.sourceFormatId.value.length)
                        copyFormatId(doc, st, editorStatus, st.sourceFormatId.value);
                }),
                Button("Close source").touchFriendly().onClick(() {
                    closeSourceView(st, editorStatus);
                }),
            ).spacing(8).width(Length.percent(100)),
            boundTextArea(st.sourceText, "Exported source…", 360)
                .width(Length.percent(100)),
        ).spacing(8).flexGrow(1).width(Length.percent(100)),
        buildNavigatorPanel(st),
    ).spacing(8).width(Length.percent(100));
}
