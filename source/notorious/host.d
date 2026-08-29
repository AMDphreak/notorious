/// Headless + windowed hosts for catalog/editor navigation.
module notorious.host;

import std.stdio;
import dew;
import dui;
import notorious.store;
import notorious.model;
import notorious.catalog_ui;
import notorious.editor_ui;
import notorious.about;
import notorious.debug_dump;
import notorious.versioninfo;

enum Screen : ubyte
{
    catalog,
    editor,
    about,
    help_,
}

struct AppSession
{
    NoteStore store;
    Screen screen = Screen.catalog;
    CatalogState catalog;
    EditorState editor;
    State!int tick = State!int(0);
}

void wireCatalog(ref AppSession s) @safe
{
    s.catalog.store = &s.store;
    s.catalog.onNew = () {
        auto n = newNote();
        s.store.save(n);
        openEditor(s, n.id);
    };
    s.catalog.onOpen = (string id) { openEditor(s, id); };
    s.catalog.onAbout = () { s.screen = Screen.about; s.tick = s.tick.value + 1; };
    s.catalog.onHelp = () { s.screen = Screen.help_; s.tick = s.tick.value + 1; };
    s.catalog.onDump = () {
        auto p = writeDebugDump(s.store);
        s.catalog.status = "Dump: " ~ p;
        s.tick = s.tick.value + 1;
    };
}

void openEditor(ref AppSession s, string id) @safe
{
    s.editor = EditorState.init;
    s.editor.store = &s.store;
    s.editor.doc = s.store.load(id);
    syncFromDoc(s.editor);
    s.editor.onBack = () {
        s.screen = Screen.catalog;
        s.tick = s.tick.value + 1;
    };
    s.editor.onSaved = () { s.tick = s.tick.value + 1; };
    s.screen = Screen.editor;
    s.tick = s.tick.value + 1;
}

Widget buildRoot(ref AppSession s) @safe
{
    final switch (s.screen)
    {
    case Screen.catalog:
        return buildCatalog(s.catalog);
    case Screen.editor:
        return buildEditor(s.editor);
    case Screen.about:
        return VStack(
            buildAbout(),
            Button("Back").touchFriendly().onClick(() {
                s.screen = Screen.catalog;
                s.tick = s.tick.value + 1;
            })
        ).spacing(12).padding(16);
    case Screen.help_:
        return VStack(
            Text("Help").fontSize(20).bold(),
            Text("Catalog: search, list/grid, open notes.").fontSize(14),
            Text("Editor: Text ↔ Canvas mode; Undo reverses conversion until shapes exist.").fontSize(14),
            Text("Ctrl+C = HTML without sticky background; Ctrl+Shift+C = Markdown.").fontSize(14),
            Text("Line endings default to LF; encoding UTF-8 (code-friendly).").fontSize(14),
            Text("Report issues: https://github.com/AMDphreak/notorious/issues").fontSize(12),
            Button("Back").touchFriendly().onClick(() {
                s.screen = Screen.catalog;
                s.tick = s.tick.value + 1;
            })
        ).spacing(8).padding(16);
    }
}

void runHeadlessCatalog(ref NoteStore store) @safe
{
    writeln(appVersionLine());
    AppSession session;
    session.store = store;
    wireCatalog(session);

    DuiApp app;
    app.bind(session.tick);
    app.bind(session.catalog.search);
    app.bind(session.catalog.viewMode);
    app.bind(session.catalog.status);

    app.init((ref UiBuilder ui) { return buildRoot(session); }, new SoftwareBackend(960, 640));
    app.dew.resize(960, 640);
    app.frame();
    writeln("headless OK; notes=", store.listMeta().length,
        " cmds=", app.dew.list.cmds.length);
}

version (NotoriousWindowed)
{
    import glfw3.api;

    version (Windows)
    {
        import core.sys.windows.windows;
        extern (C) HWND glfwGetWin32Window(GLFWwindow* window);
    }

    void runWindowedApp(ref NoteStore store) @trusted
    {
        AppSession session;
        session.store = store;
        wireCatalog(session);

        if (!glfwInit())
        {
            stderr.writeln("glfwInit failed");
            return;
        }
        scope (exit)
            glfwTerminate();

        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        auto window = glfwCreateWindow(1000, 700, "Notorious", null, null);
        if (window is null)
        {
            stderr.writeln("glfwCreateWindow failed");
            return;
        }
        scope (exit)
            glfwDestroyWindow(window);

        auto gpu = new VelloRenderBackend();
        version (Windows)
        {
            HWND hwnd = glfwGetWin32Window(window);
            HINSTANCE hinstance = GetModuleHandleA(null);
            gpu.attach(cast(void*) hwnd, cast(void*) hinstance, 1000, 700);
        }
        if (!gpu.attached)
        {
            stderr.writeln("Vello attach failed — falling back to headless smoke");
            runHeadlessCatalog(store);
            return;
        }
        scope (exit)
            gpu.shutdown();

        DuiApp app;
        app.bind(session.tick);
        app.bind(session.catalog.search);
        app.bind(session.catalog.viewMode);
        app.bind(session.catalog.status);
        app.bind(session.editor.title);
        app.bind(session.editor.bodyText);
        app.bind(session.editor.status);
        app.bind(session.editor.fontSize);
        app.bind(session.editor.bold);

        app.init((ref UiBuilder ui) { return buildRoot(session); }, gpu);

        extern (C) void scaleThunk(void* win, float* sx, float* sy) nothrow @nogc
        {
            glfwGetWindowContentScale(cast(GLFWwindow*) win, sx, sy);
        }

        {
            int fbW, fbH;
            glfwGetFramebufferSize(window, &fbW, &fbH);
            auto scale = contentScaleFromGlfw(cast(void*) window, cast(GlfwContentScaleFn) &scaleThunk);
            app.dew.syncFromFramebuffer(fbW, fbH, scale);
        }
        app.frame();

        bool mouseWasDown;
        while (!glfwWindowShouldClose(window))
        {
            glfwPollEvents();
            int fbW, fbH;
            glfwGetFramebufferSize(window, &fbW, &fbH);
            float sx, sy;
            glfwGetWindowContentScale(window, &sx, &sy);
            app.dew.syncFromFramebuffer(fbW, fbH, ScaleFactor(sx, sy));

            double mx, my;
            glfwGetCursorPos(window, &mx, &my);
            const down = glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS;
            if (down != mouseWasDown)
            {
                PointerEvent ev;
                ev.x = cast(float) mx;
                ev.y = cast(float) my;
                ev.kind = PointerKind.Mouse;
                ev.phase = down ? PointerPhase.Down : PointerPhase.Up;
                ev.button = PointerButton.Left;
                ev.pressed = down;
                ev.primary = true;
                app.pointer(ev);
                app.requestRebuild();
            }
            else if (down)
            {
                PointerEvent ev;
                ev.x = cast(float) mx;
                ev.y = cast(float) my;
                ev.kind = PointerKind.Mouse;
                ev.phase = PointerPhase.Move;
                ev.button = PointerButton.Left;
                ev.pressed = true;
                ev.primary = true;
                app.pointer(ev);
            }
            mouseWasDown = down;

            pollWindowKeys(app, session, window);
            app.frame();
        }
    }

    void pollWindowKeys(ref DuiApp app, ref AppSession session, GLFWwindow* window) @trusted
    {
        void edge(string key, int gk)
        {
            static bool[512] was;
            const down = glfwGetKey(window, gk) == GLFW_PRESS;
            const idx = gk & 511;
            if (down && !was[idx])
            {
                KeyEvent ev;
                ev.key = key;
                ev.phase = KeyPhase.Down;
                ev.ctrl = glfwGetKey(window, GLFW_KEY_LEFT_CONTROL) == GLFW_PRESS
                    || glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL) == GLFW_PRESS;
                ev.shift = glfwGetKey(window, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS
                    || glfwGetKey(window, GLFW_KEY_RIGHT_SHIFT) == GLFW_PRESS;
                if (session.screen == Screen.editor)
                    handleEditorShortcut(session.editor, ev);
                app.key(ev);
                app.requestRebuild();
            }
            was[idx] = down;
        }

        edge("Backspace", GLFW_KEY_BACKSPACE);
        edge("Enter", GLFW_KEY_ENTER);
        edge("Tab", GLFW_KEY_TAB);
        edge("c", GLFW_KEY_C);
        edge("z", GLFW_KEY_Z);
        edge("y", GLFW_KEY_Y);
        edge("s", GLFW_KEY_S);

        const ctrl = glfwGetKey(window, GLFW_KEY_LEFT_CONTROL) == GLFW_PRESS
            || glfwGetKey(window, GLFW_KEY_RIGHT_CONTROL) == GLFW_PRESS;
        if (ctrl)
            return;

        foreach (int code; 'A' .. 'Z' + 1)
        {
            auto gk = GLFW_KEY_A + (code - 'A');
            static bool[26] letterWas;
            const i = code - 'A';
            const down = glfwGetKey(window, gk) == GLFW_PRESS;
            if (down && !letterWas[i])
            {
                const shift = glfwGetKey(window, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS
                    || glfwGetKey(window, GLFW_KEY_RIGHT_SHIFT) == GLFW_PRESS;
                char ch = cast(char)(shift ? code : code + 32);
                KeyEvent ev;
                ev.key = [ch].idup;
                ev.phase = KeyPhase.Down;
                app.key(ev);
                app.requestRebuild();
            }
            letterWas[i] = down;
        }
        {
            static bool spaceWas;
            const down = glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_PRESS;
            if (down && !spaceWas)
            {
                KeyEvent ev;
                ev.key = " ";
                ev.phase = KeyPhase.Down;
                app.key(ev);
                app.requestRebuild();
            }
            spaceWas = down;
        }
    }
}
else
{
    void runWindowedApp(ref NoteStore store) @trusted
    {
        stderr.writeln("Build with -c windowed for the GLFW UI.");
        runHeadlessCatalog(store);
    }
}
