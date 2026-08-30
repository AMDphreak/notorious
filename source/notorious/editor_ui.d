/// Note editor: text / canvas mode switch, formatting, clipboard shortcuts.
module notorious.editor_ui;

import std.format : format;
import dew;
import dui;
import notorious.model;
import notorious.store;
import notorious.markdown;
import notorious.html_export;
import notorious.formats;
import notorious.copy_as;

struct EditorState
{
    NoteStore* store;
    NoteDoc doc;
    UndoStack!NoteDoc undo;
    CopyAsState copyAs;
    State!string title = State!string("");
    State!string bodyText = State!string("");
    State!string status = State!string("");
    State!int fontSize = State!int(14);
    State!bool bold = State!bool(false);
    void delegate() @safe onBack;
    void delegate() @safe onSaved;
}

void syncFromDoc(ref EditorState st) @safe
{
    st.title = st.doc.title;
    st.bodyText = st.doc.bodyText;
}

void syncToDoc(ref EditorState st) @safe
{
    st.doc.title = st.title.value;
    if (st.doc.mode == NoteMode.text)
        st.doc.bodyText = st.bodyText.value;
}

void pushUndo(ref EditorState st) @safe
{
    syncToDoc(st);
    st.undo.push(st.doc);
}

bool doUndo(ref EditorState st) @safe
{
    syncToDoc(st);
    if (!st.undo.popUndo(st.doc))
        return false;
    syncFromDoc(st);
    st.status = "Undid last change";
    return true;
}

bool doRedo(ref EditorState st) @safe
{
    syncToDoc(st);
    if (!st.undo.popRedo(st.doc))
        return false;
    syncFromDoc(st);
    st.status = "Redid change";
    return true;
}

void switchToCanvas(ref EditorState st) @safe
{
    if (st.doc.mode == NoteMode.canvas)
        return;
    pushUndo(st);
    syncToDoc(st);
    convertTextToCanvas(st.doc);
    st.status = "Canvas mode — Undo reverts until you add shapes";
}

void switchToText(ref EditorState st) @safe
{
    if (st.doc.mode == NoteMode.text)
        return;
    if (!canRevertToText(st.doc))
    {
        st.status = "Locked in canvas: diagram shapes present (Undo may still help)";
        return;
    }
    pushUndo(st);
    if (!convertCanvasToText(st.doc))
    {
        st.status = "Could not convert canvas → text";
        return;
    }
    syncFromDoc(st);
    st.status = "Text mode";
}

void copyAsHtml(ref EditorState st) @safe
{
    syncToDoc(st);
    auto html = toHtmlFragment(st.doc);
    auto plain = st.doc.mode == NoteMode.text ? st.doc.bodyText : toMarkdown(st.doc);
    if (copyHtml(html, plain))
        st.status = "Copied HTML (no sticky background)";
    else
        st.status = "Clipboard HTML failed; plain text may still be set";
}

void copyAsMarkdown(ref EditorState st) @safe
{
    syncToDoc(st);
    openCopyAs(st.copyAs);
    st.status = "Copy as…";
}

void saveNote(ref EditorState st) @safe
{
    syncToDoc(st);
    // Apply font toolbar to a span covering whole body when bold toggled in text mode.
    if (st.doc.mode == NoteMode.text && (st.bold.value || st.fontSize.value != 14))
    {
        TextSpan sp;
        sp.start = 0;
        sp.end = st.doc.bodyText.length;
        sp.bold = st.bold.value;
        sp.fontSize = cast(float) st.fontSize.value;
        st.doc.spans = [sp];
    }
    st.store.save(st.doc);
    st.status = "Saved";
    if (st.onSaved !is null)
        st.onSaved();
}

void cycleBackground(ref EditorState st) @safe
{
    static immutable ColorRgba[] palette = [
        ColorRgba.rgb(255, 249, 196),
        ColorRgba.rgb(200, 230, 255),
        ColorRgba.rgb(220, 255, 220),
        ColorRgba.rgb(255, 220, 230),
        ColorRgba.rgb(245, 245, 245),
    ];
    pushUndo(st);
    size_t idx = 0;
    foreach (i, c; palette)
        if (c.r == st.doc.background.r && c.g == st.doc.background.g && c.b == st.doc.background.b)
        {
            idx = (i + 1) % palette.length;
            break;
        }
    st.doc.background = palette[idx];
    st.status = "Background updated";
}

Widget buildEditor(ref EditorState st) @safe
{
    Widget[] kids;
    kids ~= HStack(
        Button("← Catalog").touchFriendly().onClick(() {
            if (st.onBack !is null)
                st.onBack();
        }),
        boundTextField(st.title, "Title").width(280).height(36),
        Spacer(),
        Button("Save").touchFriendly().onClick(() { saveNote(st); }),
        Button("Undo").touchFriendly().onClick(() { doUndo(st); }),
        Button("Redo").touchFriendly().onClick(() { doRedo(st); }),
    ).spacing(8).width(Length.percent(100));

    kids ~= HStack(
        Button(st.doc.mode == NoteMode.text ? "Mode: Text" : "Mode: Canvas")
            .touchFriendly()
            .onClick(() {
                if (st.doc.mode == NoteMode.text)
                    switchToCanvas(st);
                else
                    switchToText(st);
            }),
        Button("Bg color").touchFriendly().onClick(() { cycleBackground(st); }),
        Button("Bold").touchFriendly().onClick(() { st.bold = !st.bold.value; }),
        Button("A−").touchFriendly().onClick(() {
            if (st.fontSize.value > 10)
                st.fontSize = st.fontSize.value - 1;
        }),
        Text(format("%s pt", st.fontSize.value)).fontSize(12),
        Button("A+").touchFriendly().onClick(() {
            if (st.fontSize.value < 48)
                st.fontSize = st.fontSize.value + 1;
        }),
        Button("Copy HTML").touchFriendly().onClick(() { copyAsHtml(st); }),
        Button("Copy as…").touchFriendly().onClick(() {
            syncToDoc(st);
            openCopyAs(st.copyAs);
            st.status = "Copy as…";
        }),
        Text(st.doc.lineEnding == LineEnding.lf ? "LF · UTF-8" : "line endings").fontSize(11),
    ).spacing(6).width(Length.percent(100));

    if (st.copyAs.sourceFormatId.value.length)
    {
        kids ~= buildSourceEditor(st.doc, st.copyAs, st.status);
    }
    else if (st.doc.mode == NoteMode.text)
    {
        kids ~= boundTextArea(st.bodyText, "Write your note…", 360)
            .background(st.doc.background)
            .fontSize(cast(float) st.fontSize.value)
            .bold(st.bold.value);
    }
    else
    {
        Widget[] canvasKids;
        foreach (ref ct; st.doc.canvasTexts)
        {
            auto label = ct.text.length ? ct.text : "(empty text)";
            canvasKids ~= Text(label)
                .fontSize(ct.fontSize)
                .bold(ct.bold);
        }
        if (st.doc.shapes.length)
            canvasKids ~= Text(format("%s shape(s) — text reverse locked", st.doc.shapes.length))
                .fontSize(12);
        kids ~= Canvas(canvasKids)
            .showGrid(true)
            .background(st.doc.background)
            .width(Length.percent(100))
            .height(360)
            .padding(16)
            .spacing(8);
        kids ~= Text("Canvas text from conversion. Diagram tools land in a later version; Undo restores text mode.")
            .fontSize(11);
        kids ~= Text("Codebox overlay preview (50% → pop-out) is planned; formats stay first-party D modules.")
            .fontSize(11);
    }

    if (st.copyAs.open.value)
        kids ~= buildCopyAsModal(st.doc, st.copyAs, st.status);

    kids ~= Text(st.status.value).fontSize(12);

    return VStack(kids)
        .spacing(10)
        .padding(12)
        .width(Length.percent(100))
        .height(Length.percent(100));
}

/// Handle global editor shortcuts from host key polling.
void handleEditorShortcut(ref EditorState st, KeyEvent ev) @safe
{
    if (ev.phase != KeyPhase.Down)
        return;
    if (ev.ctrl && ev.shift && (ev.key == "c" || ev.key == "C"))
    {
        syncToDoc(st);
        openCopyAs(st.copyAs);
        st.status = "Copy as…";
        return;
    }
    if (ev.ctrl && !ev.shift && (ev.key == "c" || ev.key == "C"))
    {
        copyAsHtml(st);
        return;
    }
    if (ev.ctrl && (ev.key == "z" || ev.key == "Z"))
    {
        doUndo(st);
        return;
    }
    if (ev.ctrl && (ev.key == "y" || ev.key == "Y"))
    {
        doRedo(st);
        return;
    }
    if (ev.ctrl && (ev.key == "s" || ev.key == "S"))
    {
        saveNote(st);
        return;
    }
}
