/// Main catalog: list / grid / search.
module notorious.catalog_ui;

import std.format : format;
import std.algorithm : min;
import dew;
import dui;
import notorious.model;
import notorious.store;

enum CatalogView : ubyte
{
    list,
    grid,
}

struct CatalogState
{
    NoteStore* store;
    State!string search = State!string("");
    State!int viewMode = State!int(0); // 0 list, 1 grid
    State!string status = State!string("Ready");
    string selectedId;
    void delegate(string id) @safe onOpen;
    void delegate() @safe onNew;
    void delegate() @safe onAbout;
    void delegate() @safe onHelp;
    void delegate() @safe onDump;
}

Widget buildCatalog(ref CatalogState st) @safe
{
    auto notes = st.store.search(st.search.value);
    Widget[] rows;
    rows ~= HStack(
        Text("Notorious").fontSize(22).bold(),
        Spacer(),
        Button("New note").touchFriendly().onClick(() {
            if (st.onNew !is null)
                st.onNew();
        }),
        Button(st.viewMode.value == 0 ? "Grid" : "List").touchFriendly().onClick(() {
            st.viewMode = st.viewMode.value == 0 ? 1 : 0;
        }),
        Button("About").touchFriendly().onClick(() {
            if (st.onAbout !is null)
                st.onAbout();
        }),
        Button("Help").touchFriendly().onClick(() {
            if (st.onHelp !is null)
                st.onHelp();
        }),
        Button("Dump").touchFriendly().onClick(() {
            if (st.onDump !is null)
                st.onDump();
        }),
    ).spacing(8).width(Length.percent(100));

    rows ~= boundTextField(st.search, "Search notes…").height(36);

    if (st.viewMode.value == 0)
    {
        Widget[] listKids;
        foreach (n; notes)
        {
            auto id = n.id;
            auto label = format("%s  ·  %s", n.title, cast(string) n.mode);
            listKids ~= Button(label)
                .touchFriendly()
                .width(Length.percent(100))
                .height(40)
                .onClick(() {
                    st.selectedId = id;
                    if (st.onOpen !is null)
                        st.onOpen(id);
                });
        }
        if (!listKids.length)
            listKids ~= Text("No notes yet — tap New note.").fontSize(14);
        rows ~= ScrollView(VStack(listKids).spacing(6).width(Length.percent(100)))
            .width(Length.percent(100))
            .height(420)
            .flexGrow(1);
    }
    else
    {
        Widget[] cells;
        foreach (n; notes)
        {
            auto id = n.id;
            auto title = n.title;
            cells ~= Container(
                Text(title).fontSize(14).bold(),
                Text(cast(string) n.mode).fontSize(11),
            )
                .background(n.background)
                .padding(12)
                .width(160)
                .height(100)
                .onClick(() {
                    st.selectedId = id;
                    if (st.onOpen !is null)
                        st.onOpen(id);
                })
                .touchFriendly();
        }
        if (!cells.length)
            cells ~= Text("No notes.").fontSize(14);
        rows ~= ScrollView(HStack(cells).spacing(10).flexWrap(FlexWrap.Wrap).width(Length.percent(100)))
            .width(Length.percent(100))
            .height(420)
            .flexGrow(1);
    }

    rows ~= Text(st.status.value).fontSize(12);

    return VStack(rows)
        .spacing(10)
        .padding(16)
        .width(Length.percent(100))
        .height(Length.percent(100))
        .background(ColorRgba.rgb(245, 246, 250));
}
