package nbkit.jsf;

import nbkit.jsf.Rules.Problem;
import nbkit.jsf.Rules.Severity;
import nbkit.jsf.Workspace.FileFacts;
import nbkit.jsf.Workspace.Inc;
import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Predicate;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Applies the rules to an xhtml file. Does not depend on NetBeans. */
public final class Analyzer {

    // ---------- fixed lists ----------

    static final Set<String> IMPLICIT = Set.of("facesContext", "view", "component", "cc", "request", "session", "application",
            "param", "paramValues", "header", "headerValues", "cookie", "initParam", "flash", "resource", "requestScope",
            "viewScope", "sessionScope", "applicationScope", "flowScope", "externalContext", "pfExceptionHandler");

    static final Set<String> METHOD_ATTRS = Set.of("action", "actionListener", "listener", "valueChangeListener", "validator",
            "completeMethod");

    /** attributes that create a variable: var, varStatus, varGroup, rowIndexVar, columnIndexVar... (not widgetVar) */
    static boolean isVarAttr(String n) {
        return n.equals("var") || n.startsWith("var") && n.length() > 3 && Character.isUpperCase(n.charAt(3))
                || n.endsWith("Var") && !n.equals("widgetVar");
    }

    static final Set<String> PF_KEYWORDS = Set.of("this", "form", "all", "none", "parent", "namingcontainer", "composite",
            "child", "next", "previous", "root", "id", "obs", "row", "widgetVar");

    static final Set<String> NC_STATIC = Set.of("h:form", "h:dataTable", "ui:repeat", "f:subview", "o:form",
            "p:accordionPanel", "p:carousel", "p:chronoline", "p:columns", "p:dataGrid", "p:dataList", "p:dataScroller",
            "p:dataTable", "p:dataView", "p:diagram", "p:galleria", "p:subTable", "p:tabView", "p:tree", "p:treeTable");

    static final Set<String> FOR_TAGS = Set.of("h:outputLabel", "h:message", "p:outputLabel", "p:message", "p:tooltip",
            "p:overlayPanel", "p:contextMenu", "p:watermark", "p:focus", "p:draggable", "p:droppable", "p:resizable", "p:keyFilter");

    static final Set<String> COMMANDS = Set.of("h:commandButton", "h:commandLink", "h:commandScript", "p:commandButton",
            "p:commandLink", "p:remoteCommand", "p:poll", "p:splitButton", "p:fileUpload", "o:commandScript");

    static final Set<String> P_INPUTS = Set.of("autoComplete", "calendar", "datePicker", "chips", "spinner", "rating",
            "toggleSwitch", "inputSwitch", "keyboard", "editor", "textEditor", "colorPicker", "password", "knob", "signature",
            "cascadeSelect", "triStateCheckbox", "multiSelectListbox", "inputOtp", "treeSelect");

    // ---------- state ----------

    final Workspace ws;
    final File file;
    final Predicate<String> on;
    final List<Problem> out = new ArrayList<>();
    FileFacts ff;
    Xml.Doc doc;
    Graph g;

    private Analyzer(Workspace ws, File file, Predicate<String> on) {
        this.ws = ws;
        this.file = file.getAbsoluteFile();
        this.on = on;
    }

    public static List<Problem> run(Workspace ws, File file, String text, Predicate<String> on) {
        Analyzer a = new Analyzer(ws, file, on);
        ws.override(a.file, text);
        try {
            a.go();
        } finally {
            ws.override(a.file, null);
        }
        a.out.sort((x, y) -> Integer.compare(x.start, y.start));
        return a.out;
    }

    void report(String rule, Severity s, int start, int end, String msg) {
        if (on.test(rule)) {
            for (Problem p : out) {
                if (p.start == start && p.rule.equals(rule)) {
                    return;
                }
            }
            out.add(new Problem(rule, s, start, end, msg));
        }
    }

    static String tag(Xml.Element e) {
        return Ns.lib(e.ns) + ":" + e.local;
    }

    // ---------- include graph ----------

    final class Graph {
        final Map<File, List<Inc>> incoming = new HashMap<>();
        // the files each dynamic include (src with EL) can bring in
        final Map<Inc, List<File>> dynTargets = new HashMap<>();
        final Map<File, Set<File>> composedCache = new HashMap<>();
        final Map<File, Set<File>> rootsCache = new HashMap<>();

        Graph() {
            List<File> all = new ArrayList<>(ws.xhtmlFiles());
            if (!all.contains(file)) {
                all.add(file);
            }
            for (File x : all) {
                FileFacts f = ws.facts(x);
                if (f == null) {
                    continue;
                }
                for (Inc in : f.edges) {
                    if (in.dynamic) {
                        List<File> ts = new ArrayList<>();
                        for (File y : all) {
                            if (canName(in, y)) {
                                ts.add(y);
                                incoming.computeIfAbsent(y, k -> new ArrayList<>()).add(in);
                            }
                        }
                        dynTargets.put(in, ts);
                    } else if (in.target != null) {
                        incoming.computeIfAbsent(in.target, k -> new ArrayList<>()).add(in);
                    }
                }
            }
        }

        List<Inc> in(File f) {
            return incoming.getOrDefault(f, List.of());
        }

        /** the files an include brings in: its target, or every file a dynamic src can name */
        List<File> targets(Inc in) {
            return in.dynamic ? dynTargets.getOrDefault(in, List.of()) : in.target == null ? List.of() : List.of(in.target);
        }

        // a dynamic src, with each EL as a wildcard, can name f: the literal folder before the first EL is resolved
        // like a static include (/ from each webroot, otherwise from the including file's folder)
        // shortcut: a ../ written after an EL is not normalized; resolve it if a project needs it
        boolean canName(Inc in, File f) {
            String src = in.path.replaceFirst("\\?.*$", "");
            int el = src.length();
            Matcher first = Pattern.compile("[#$]\\{").matcher(src);
            if (first.find()) {
                el = first.start();
            }
            int cut = src.lastIndexOf('/', el) + 1;
            StringBuilder re = new StringBuilder();
            Matcher m = Pattern.compile("[#$]\\{[^}]*}").matcher(src);
            int last = cut;
            while (m.find()) {
                re.append(Pattern.quote(src.substring(last, m.start()))).append(".*");
                last = m.end();
            }
            re.append(Pattern.quote(src.substring(last)));
            List<File> bases = src.startsWith("/") ? ws.webroots : List.of(in.from.getAbsoluteFile().getParentFile());
            java.nio.file.Path file = f.getAbsoluteFile().toPath().normalize();
            for (File base : bases) {
                java.nio.file.Path dir = base.getAbsoluteFile().toPath().resolve(src.substring(src.startsWith("/") ? 1 : 0, cut)).normalize();
                if (file.startsWith(dir) && dir.relativize(file).toString().replace('\\', '/').matches(re.toString())) {
                    return true;
                }
            }
            return false;
        }

        Set<File> composed(File root) {
            return composedCache.computeIfAbsent(root, r -> {
                Set<File> seen = new LinkedHashSet<>();
                List<File> todo = new ArrayList<>(List.of(r));
                while (!todo.isEmpty()) {
                    File f = todo.remove(0);
                    if (!seen.add(f)) {
                        continue;
                    }
                    FileFacts x = ws.facts(f);
                    if (x == null) {
                        continue;
                    }
                    for (Inc in : x.edges) {
                        todo.addAll(targets(in));
                    }
                    // composite components used
                    for (Xml.Element e : x.doc.all) {
                        if ("comp".equals(Ns.lib(e.ns))) {
                            File c = ws.compositeFile(e.ns, e.local);
                            if (c != null) {
                                todo.add(c);
                            }
                        } else if (e.ns != null && ws.tagSources.containsKey(e.ns.trim())) {
                            File c = ws.tagSources.get(e.ns.trim()).get(e.local);
                            if (c != null) {
                                todo.add(c);
                            }
                        }
                    }
                }
                return seen;
            });
        }

        Set<File> roots(File f) {
            return rootsCache.computeIfAbsent(f, k -> {
                Set<File> roots = new LinkedHashSet<>();
                Set<File> seen = new HashSet<>();
                List<File> todo = new ArrayList<>(List.of(k));
                while (!todo.isEmpty()) {
                    File x = todo.remove(0);
                    if (!seen.add(x)) {
                        continue;
                    }
                    List<Inc> inc = in(x);
                    if (inc.isEmpty()) {
                        roots.add(x);
                    }
                    for (Inc i : inc) {
                        todo.add(i.from);
                    }
                }
                return roots;
            });
        }

        Set<String> usedIn(File f) {
            Set<String> r = new HashSet<>();
            for (File x : composed(f)) {
                FileFacts y = ws.facts(x);
                if (y != null) {
                    r.addAll(y.usedNames);
                }
            }
            return r;
        }
    }

    boolean pageLike(FileFacts f) {
        if (f.page || f.composite) {
            return true;
        }
        Xml.Element top = firstElement(f.doc.root);
        return top == null || !(top.is("ui", "composition", "component", "fragment") || "ui".equals(Ns.lib(top.ns)));
    }

    static Xml.Element firstElement(Xml.Element e) {
        for (Xml.Node n : e.children) {
            if (n instanceof Xml.Element) {
                return (Xml.Element) n;
            }
        }
        return null;
    }

    // ---------- variable declarations ----------

    static final int SUBTREE = 0, AFTER = 1, FILE = 2;

    static final class Decl {
        String name, kind;
        Xml.Element el;
        Xml.Attr attr;
        int scope;
        boolean renderIter, used, passed;
    }

    static List<Decl> decls(Xml.Doc d) {
        List<Decl> r = new ArrayList<>();
        for (Xml.Element e : d.all) {
            if (Workspace.inRemove(e)) {
                continue;
            }
            String lib = Ns.lib(e.ns);
            boolean jstl = lib.equals("c");
            for (Xml.Attr a : e.attrs) {
                if (!isVarAttr(a.name) || a.value.isBlank() || a.value.contains("{")) {
                    continue;
                }
                Decl x = new Decl();
                x.name = a.value.trim();
                x.el = e;
                x.attr = a;
                x.kind = a.name;
                if (jstl && (e.local.equals("if") || e.local.equals("catch") || e.local.equals("set"))) {
                    x.scope = e.local.equals("set") && e.value("scope") != null ? FILE : AFTER;
                    x.kind = "c:" + e.local;
                } else if (lib.equals("f") && e.local.equals("loadBundle") || e.local.equals("importConstants") || e.local.equals("importFunctions")
                        || e.local.equals("importEnum")) {
                    x.scope = FILE;
                    x.kind = tag(e);
                } else {
                    x.scope = SUBTREE;
                    x.renderIter = !(jstl && e.local.equals("forEach")) && !(lib.equals("f") && e.local.equals("selectItems"));
                }
                r.add(x);
            }
            // f:importConstants / o:importConstants / o:importFunctions without var: simple class name
            if ((e.local.equals("importConstants") || e.local.equals("importFunctions") || e.local.equals("importEnum")) && e.value("var") == null
                    && e.value("type") != null) {
                String t = e.value("type").trim();
                Decl x = new Decl();
                x.name = t.substring(t.lastIndexOf('.') + 1);
                x.el = e;
                x.attr = e.attr("type");
                x.scope = FILE;
                x.kind = tag(e);
                x.used = true; // implicit: usage is not required
                r.add(x);
            }
            if (lib.equals("ui") && e.local.equals("param") && e.value("name") != null) {
                Decl x = new Decl();
                x.name = e.value("name").trim();
                x.el = e;
                x.attr = e.attr("name");
                x.kind = "ui:param";
                x.scope = FILE;
                x.passed = e.parent != null && e.parent.is("ui", "include");
                r.add(x);
            }
        }
        return r;
    }

    static boolean visible(Decl d, Xml.Element site, String attrName, int offset) {
        switch (d.scope) {
            case FILE:
                return !d.passed;
            case AFTER:
                return offset >= d.el.end;
            default:
                if (site == d.el) {
                    return attrName == null || !(attrName.equals("value") || attrName.equals("items") || attrName.equals(d.attr.name));
                }
                for (Xml.Element p = site; p != null; p = p.parent) {
                    if (p == d.el) {
                        return true;
                    }
                }
                return false;
        }
    }

    // ---------- names that come from outside (includes and templates) ----------

    static final class Ext {
        final Set<String> names = new HashSet<>();
        final Map<String, List<String>> from = new HashMap<>();
        boolean complete = true;

        void add(String name, String origin) {
            names.add(name);
            List<String> l = from.computeIfAbsent(name, k -> new ArrayList<>());
            if (origin != null && !l.contains(origin)) {
                l.add(origin);
            }
        }
    }

    // ---------- where names and ids come from (the blue notes) ----------

    /** "pages/a.xhtml, line 12 (ui:param)": the file from its webroot, the line of the element and what it is */
    String origin(File f, Xml.Element e, String what) {
        File w = ws.webrootOf(f);
        String path = w == null ? f.getName() : w.getAbsoluteFile().toPath().relativize(f.getAbsoluteFile().toPath()).toString().replace('\\', '/');
        Xml.Doc d = f.equals(file) ? doc : ws.doc(f);
        String place = e == null || d == null ? path : Msg.t("origin.place", path, d.line(e.start));
        return what == null ? place : place + " (" + what + ")";
    }

    /** a blue note: nothing is wrong, it only says where the thing comes from */
    void note(int a, int b, String key, String name, List<String> origins) {
        note("origin", a, b, key, name, origins);
    }

    void note(String rule, int a, int b, String key, String name, List<String> origins) {
        if (origins == null || origins.isEmpty()) {
            return;
        }
        String more = origins.size() > 1 ? Msg.t("origin.more", origins.size() - 1) : "";
        report(rule, Severity.INFO, a, b, Msg.t(key, name, origins.get(0), more));
    }

    static String what(Decl d) {
        return d.kind.contains(":") ? d.kind : d.el.name + " " + d.kind;
    }

    /** the element of f whose EL first uses name (shortcut: a text search, enough to point at a line) */
    static Xml.Element useIn(Xml.Doc d, String name) {
        Pattern p = Pattern.compile("[#$]\\{[^}]*(?<![\\w.])" + Pattern.quote(name) + "(?!\\w)");
        for (Xml.Element e : d.all) {
            for (Xml.Attr a : e.attrs) {
                if (p.matcher(a.value).find()) {
                    return e;
                }
            }
            for (Xml.Node n : e.children) {
                if (n instanceof Xml.Text && p.matcher(((Xml.Text) n).raw).find()) {
                    return e;
                }
            }
        }
        return null;
    }

    /** where a name passed to t (and the files it brings in) is used, or null */
    String usedAt(File t, String name) {
        for (File x : g.composed(t)) {
            FileFacts y = ws.facts(x);
            if (y != null && y.usedNames.contains(name)) {
                Xml.Element e = useIn(y.doc, name);
                return origin(x, e, null);
            }
        }
        return null;
    }

    static Xml.Element withAttr(Xml.Doc d, String attr, String value) {
        for (Xml.Element e : d.all) {
            if (e.value(attr) != null && e.value(attr).trim().equals(value)) {
                return e;
            }
        }
        return null;
    }

    final Map<File, Ext> extCache = new HashMap<>();

    Ext ext(File f, Set<File> guard) {
        Ext cached = extCache.get(f);
        if (cached != null) {
            return cached;
        }
        Ext r = new Ext();
        if (!guard.add(f)) {
            return r; // a cycle: the other includers of the file bring their names
        }
        FileFacts x = ws.facts(f);
        if (x == null || x.composite) {
            extCache.put(f, r);
            return r;
        }
        Set<String> tagAttrs = ws.tagFiles.get(f);
        if (tagAttrs != null) {
            // tag file: the declared attributes and every attribute its usages pass become variables
            r.names.addAll(tagAttrs);
            for (File u : ws.xhtmlFiles()) {
                FileFacts uf = ws.facts(u);
                if (uf == null) {
                    continue;
                }
                for (Xml.Element e : uf.doc.all) {
                    Map<String, File> lib = e.ns == null ? null : ws.tagSources.get(e.ns.trim());
                    if (lib != null && f.equals(lib.get(e.local))) {
                        for (Xml.Attr a : e.attrs) {
                            r.add(a.name, origin(u, e, e.name));
                        }
                    }
                }
            }
            extCache.put(f, r);
            return r;
        }
        for (Inc in : g.in(f)) {
            FileFacts from = ws.facts(in.from);
            if (from == null) {
                r.complete = false;
                continue;
            }
            for (Xml.Element p : in.el.elements()) {
                if (p.is("ui", "param") && p.value("name") != null) {
                    r.add(p.value("name").trim(), origin(in.from, p, "ui:param"));
                }
            }
            for (Decl d : decls(from.doc)) {
                if (d.scope == FILE && !d.passed || visible(d, in.el, null, in.el.start)) {
                    r.add(d.name, origin(in.from, d.el, what(d)));
                }
            }
            for (String b : from.bindings) {
                r.add(b, origin(in.from, useIn(from.doc, b), "binding"));
            }
            Ext up = ext(in.from, guard);
            for (String n : up.names) {
                for (String o : up.from.getOrDefault(n, List.of())) {
                    r.add(n, o);
                }
                r.names.add(n);
            }
            r.complete &= up.complete;
        }
        extCache.put(f, r);
        return r;
    }

    // ---------- run ----------

    static final class Site {
        El.Expr x;
        Xml.Element el;
        Xml.Attr attr;
    }

    List<Site> sites = new ArrayList<>();
    List<Decl> decls;
    Set<String> globals = new HashSet<>();
    final Map<String, List<String>> globalFrom = new HashMap<>();
    Ext ext;

    void go() {
        ff = ws.facts(file);
        if (ff == null) {
            return;
        }
        doc = ff.doc;
        g = new Graph();
        collectSites(doc.root);
        decls = decls(doc);
        globals.addAll(IMPLICIT);
        globals.addAll(ws.beans.keySet());
        globals.addAll(ws.facesVars);
        for (String v : ws.facesVars) {
            globalFrom.computeIfAbsent(v, k -> new ArrayList<>()).add(Msg.t("origin.faces"));
        }
        if (ws.omnifaces) {
            globals.add("now");
            globals.add("startup");
        }
        for (File r : g.roots(file)) {
            for (File f : g.composed(r)) {
                FileFacts x = ws.facts(f);
                if (x != null) {
                    globals.addAll(x.bindings);
                    if (!f.equals(file)) {
                        for (String b : x.bindings) {
                            String o = origin(f, useIn(x.doc, b), "binding");
                            List<String> l = globalFrom.computeIfAbsent(b, k -> new ArrayList<>());
                            if (!l.contains(o)) {
                                l.add(o);
                            }
                        }
                    }
                }
            }
        }
        globals.addAll(ff.bindings);
        ext = ext(file, new HashSet<>());

        names();
        unused();
        cssClasses();
        compositeAttrs();
        elements();
        ids();
        forms();
        templates();
        comments();
        entities();
    }

    void collectSites(Xml.Element e) {
        for (Xml.Attr a : e.attrs) {
            if (a.name.startsWith("xmlns")) {
                continue;
            }
            for (El.Expr x : El.find(a.value, a.map)) {
                Site s = new Site();
                s.x = x;
                s.el = e;
                s.attr = a;
                sites.add(s);
            }
        }
        for (Xml.Node n : e.children) {
            if (n instanceof Xml.Element) {
                Xml.Element c = (Xml.Element) n;
                if (!c.is("ui", "remove")) {
                    collectSites(c);
                }
            } else if (n instanceof Xml.Text) {
                for (El.Expr x : El.find(((Xml.Text) n).raw, n.start)) {
                    Site s = new Site();
                    s.x = x;
                    s.el = e;
                    sites.add(s);
                }
            }
        }
    }

    /** e has a cc:<local> somewhere inside */
    static boolean encloses(Xml.Element e, String local) {
        for (Xml.Node n : e.children) {
            if (n instanceof Xml.Element && (((Xml.Element) n).is("cc", local) || encloses((Xml.Element) n, local))) {
                return true;
            }
        }
        return false;
    }

    /** the name is a variable that a composite component around e gives to its children: a loop (var, varStatus...)
     * around its cc:insertChildren, where what the page writes inside the tag is rendered */
    String fromComponentLoop(Xml.Element e, String name) {
        for (Xml.Element a = e; a != null; a = a.parent) {
            File c = a.ns == null ? null : ws.compositeFile(a.ns, a.local);
            Xml.Doc cd = c == null ? null : ws.doc(c);
            if (cd == null) {
                continue;
            }
            for (Xml.Element ins : cd.all) {
                if (!ins.is("cc", "insertChildren")) {
                    continue;
                }
                for (Xml.Element up = ins.parent; up != null; up = up.parent) {
                    for (Xml.Attr at : up.attrs) {
                        if (isVarAttr(at.name) && at.value.trim().equals(name)) {
                            return origin(c, up, up.name + " " + at.name);
                        }
                    }
                }
            }
        }
        return null;
    }

    // ---------- name and type rules (1 to 6, 19) ----------

    void names() {
        for (Site s : sites) {
            String attrName = s.attr == null ? null : s.attr.name;
            for (El.Lambda l : s.x.lambdas) {
                for (El.Tok p : l.params) {
                    if (!l.used.contains(p.s)) {
                        report("unused", Severity.WARNING, s.x.off(p.a), s.x.off(p.b),
                                Msg.t("unused.lambda", p.s));
                    }
                }
            }
            for (El.Ref r : s.x.refs) {
                if (r.assigned) {
                    continue;
                }
                int pos = s.x.off(r.a);
                Decl found = null;
                for (Decl d : decls) {
                    // the innermost (or the most recent) wins, as in Facelets
                    if (d.name.equals(r.name) && visible(d, s.el, attrName, pos) && (found == null || d.el.start >= found.el.start)) {
                        found = d;
                    }
                }
                if (found != null) {
                    found.used = true;
                    jstlIteration(s, r, found);
                    continue;
                }
                if (globals.contains(r.name) || ext.names.contains(r.name)) {
                    if (!ff.bindings.contains(r.name)) {
                        List<String> os = ext.from.get(r.name);
                        note(pos, s.x.off(r.b), "origin.name", r.name, os != null && !os.isEmpty() ? os : globalFrom.get(r.name));
                    }
                    types(s, r);
                    continue;
                }
                // exists in the file, but out of reach
                Decl elsewhere = null;
                for (Decl d : decls) {
                    if (d.name.equals(r.name) && !d.passed) {
                        elsewhere = d;
                        break;
                    }
                }
                if (elsewhere != null) {
                    String where = elsewhere.scope == AFTER
                            ? Msg.t("el.scope.after", tag(elsewhere.el), doc.line(elsewhere.el.start))
                            : Msg.t("el.scope.inside", tag(elsewhere.el), doc.line(elsewhere.el.start));
                    elsewhere.used = true;
                    report("el.scope", Severity.ERROR, pos, s.x.off(r.b), Msg.t("el.scope", r.name, where));
                    continue;
                }
                File bundle = bundleInView(r.name);
                if (bundle != null) {
                    String from = file.getParentFile().toPath().relativize(bundle.toPath()).toString();
                    report("el.unknown", Severity.WARNING, pos, s.x.off(r.b), Msg.t("el.bundle.included", r.name, from));
                    continue;
                }
                String loop = fromComponentLoop(s.el, r.name);
                if (loop != null) {
                    note(pos, s.x.off(r.b), "origin.name", r.name, List.of(loop));
                    continue;
                }
                if (!ws.beansKnown) {
                    continue;
                }
                if (!ext.complete) {
                    continue;
                }
                boolean sure = ws.customElResolver == null;
                String hint = closest(r.name, allNamesAt(s, attrName, pos));
                report("el.unknown", sure ? Severity.ERROR : Severity.WARNING, pos, s.x.off(r.b),
                        (sure ? Msg.t("el.unknown", r.name) : Msg.t("el.unknown.resolver", r.name, ws.customElResolver))
                        + Msg.hint(hint, placeOfName(hint, s, attrName, pos)));
            }
            enumCompare(s);
            readonly(s);
        }
    }

    // f:loadBundle puts its var in the request while the view is built, so one in any file of the view (the page,
    // its templates, the files it includes) reaches the EL evaluated when the page is drawn. The first file that
    // declares it, when every page that uses this file has one; null otherwise
    File bundleInView(String name) {
        File first = null;
        for (File root : ws.rootViews(file)) {
            File f = bundleBelow(root, name, new HashSet<>());
            if (f == null) {
                return null;
            }
            if (first == null) {
                first = f;
            }
        }
        return first;
    }

    File bundleBelow(File f, String name, Set<File> seen) {
        Workspace.FileFacts ff = seen.add(f) ? ws.facts(f) : null;
        if (ff == null) {
            return null;
        }
        for (Decl d : decls(ff.doc)) {
            if (d.name.equals(name) && d.kind.equals("f:loadBundle")) {
                return f;
            }
        }
        for (Workspace.Inc in : ff.edges) {
            File r = in.target == null ? null : bundleBelow(in.target, name, seen);
            if (r != null) {
                return r;
            }
        }
        return null;
    }

    Set<String> allNamesAt(Site s, String attrName, int pos) {
        Set<String> r = new HashSet<>(globals);
        r.addAll(ext.names);
        for (Decl d : decls) {
            if (visible(d, s.el, attrName, pos)) {
                r.add(d.name);
            }
        }
        return r;
    }

    /** where a name visible at the site is declared: this file, another file of the view, a bean or faces-config */
    String placeOfName(String name, Site s, String attrName, int pos) {
        if (name == null) {
            return null;
        }
        for (Decl d : decls) {
            if (d.name.equals(name) && visible(d, s.el, attrName, pos)) {
                return origin(file, d.el, what(d));
            }
        }
        List<String> os = ext.from.getOrDefault(name, List.of());
        if (os.isEmpty()) {
            os = globalFrom.getOrDefault(name, List.of());
        }
        if (!os.isEmpty()) {
            return os.get(0);
        }
        String bean = beanType(name);
        return bean == null ? null : Msg.t("hint.bean", ClassModel.display(bean));
    }

    /** the first element of these files with attr = value (and, when given, of that ui: tag), as "file, line N" */
    String placeOfAttr(Iterable<File> files, String uiTag, String attr, String value) {
        for (File f : files) {
            FileFacts x = ws.facts(f);
            for (Xml.Element e : x == null ? List.<Xml.Element>of() : x.doc.all) {
                if ((uiTag == null || e.is("ui", uiTag)) && e.value(attr) != null && e.value(attr).trim().equals(value)) {
                    return origin(f, e, null);
                }
            }
        }
        return null;
    }

    static String closest(String name, Set<String> options) {
        String best = null;
        int bestD = 3;
        for (String o : options) {
            int d = distance(name.toLowerCase(), o.toLowerCase());
            if (d < bestD && d <= Math.max(1, name.length() / 3)) {
                bestD = d;
                best = o;
            }
        }
        return best;
    }

    static int distance(String a, String b) {
        int[][] dp = new int[a.length() + 1][b.length() + 1];
        for (int i = 0; i <= a.length(); i++) {
            dp[i][0] = i;
        }
        for (int j = 0; j <= b.length(); j++) {
            dp[0][j] = j;
        }
        for (int i = 1; i <= a.length(); i++) {
            for (int j = 1; j <= b.length(); j++) {
                int c = a.charAt(i - 1) == b.charAt(j - 1) ? 0 : 1;
                dp[i][j] = Math.min(Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1), dp[i - 1][j - 1] + c);
                if (i > 1 && j > 1 && a.charAt(i - 1) == b.charAt(j - 2) && a.charAt(i - 2) == b.charAt(j - 1)) {
                    dp[i][j] = Math.min(dp[i][j], dp[i - 2][j - 2] + 1);
                }
            }
        }
        return dp[a.length()][b.length()];
    }

    /** rule 19: JSTL runs before the iteration */
    void jstlIteration(Site s, El.Ref r, Decl d) {
        if (!d.renderIter || s.attr == null) {
            return;
        }
        Xml.Element e = s.el;
        String lib = Ns.lib(e.ns);
        boolean buildTime = lib.equals("c") && (e.local.equals("if") && s.attr.name.equals("test")
                || e.local.equals("when") && s.attr.name.equals("test")
                || e.local.equals("forEach") && Set.of("items", "begin", "end", "step").contains(s.attr.name)
                || e.local.equals("set") && s.attr.name.equals("value") && e.value("scope") != null)
                || lib.equals("ui") && e.local.equals("include") && s.attr.name.equals("src");
        if (buildTime) {
            report("jstl.iteration", Severity.ERROR, s.x.off(r.a), s.x.off(r.b),
                    Msg.t("jstl.iteration", tag(e), r.name, tag(d.el)));
        }
    }

    String beanType(String name) {
        Workspace.Bean b = ws.beans.get(name);
        return b == null ? null : b.type;
    }

    /** walks the chain; returns the final type (or null). Reports missing members. */
    String walk(Site s, El.Ref r, int upto, boolean reportMissing) {
        String cur = beanType(r.name);
        boolean methodAttr = s.attr != null && METHOD_ATTRS.contains(s.attr.name) && isJsfLib(s.el) && s.x.whole && r.chain.size() > 0 && !r.nested;
        for (int k = 0; k < upto && k < r.chain.size(); k++) {
            El.Member m = r.chain.get(k);
            if (cur == null || m.name == null || !ws.classes.complete(cur) || dynamicType(cur)) {
                return null;
            }
            ClassModel.Members mm = ws.classes.members(cur);
            boolean last = k == r.chain.size() - 1;
            if (m.call) {
                List<ClassModel.MethodInfo> ms = mm.methods.get(m.name);
                if (ms == null) {
                    if (reportMissing) {
                        missing(s, m, cur, mm, true);
                    }
                    return null;
                }
                ClassModel.MethodInfo pick = null;
                for (ClassModel.MethodInfo mi : ms) {
                    if (mi.params() == m.argCount) {
                        pick = mi;
                    }
                }
                if (pick == null) {
                    return null;
                }
                cur = ClassModel.classOf(pick.returnType());
                continue;
            }
            String getter = mm.getters.get(m.name);
            if (getter != null) {
                if (last && methodAttr && !mm.methods.containsKey(m.name) && reportMissing) {
                    report("el.kind", Severity.ERROR, s.x.off(m.a), s.x.off(m.b), Msg.t("el.kind.method", s.attr.name, m.name, cap(m.name), ClassModel.display(cur)));
                    return null;
                }
                cur = ClassModel.classOf(getter);
                continue;
            }
            List<ClassModel.MethodInfo> ms = mm.methods.get(m.name);
            if (ms != null) {
                if (last && methodAttr) {
                    return null; // method reference: ok
                }
                ClassModel.MethodInfo noArg = null;
                for (ClassModel.MethodInfo mi : ws.classes.isA(cur, "java/lang/Record") ? ms : List.<ClassModel.MethodInfo>of()) {
                    if (mi.params() == 0 && !mi.returnType().equals("V")) {
                        noArg = mi; // record style accessor
                    }
                }
                if (noArg != null) {
                    cur = ClassModel.classOf(noArg.returnType());
                    continue;
                }
                if (reportMissing) {
                    report("el.kind", Severity.ERROR, s.x.off(m.a), s.x.off(m.b), Msg.t("el.kind.property", m.name, ClassModel.display(cur), m.name, cap(m.name)));
                }
                return null;
            }
            if (reportMissing) {
                missing(s, m, cur, mm, false);
            }
            return null;
        }
        return cur;
    }

    void missing(Site s, El.Member m, String cur, ClassModel.Members mm, boolean call) {
        Set<String> opts = new HashSet<>(mm.getters.keySet());
        opts.addAll(mm.methods.keySet());
        String hint = closest(m.name, opts);
        report("el.member", Severity.ERROR, s.x.off(m.a), s.x.off(m.b), Msg.t(call ? "el.member.method" : "el.member.property", m.name, ClassModel.display(cur)) + Msg.hint(hint));
    }

    boolean dynamicType(String t) {
        return t.equals("java/lang/Object") || ws.classes.isA(t, "java/util/Map") || ws.classes.isA(t, "java/util/ResourceBundle");
    }

    static String cap(String s) {
        return s.isEmpty() ? s : Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }

    static boolean isJsfLib(Xml.Element e) {
        String l = Ns.lib(e.ns);
        return l.equals("h") || l.equals("f") || l.equals("p") || l.equals("o") || l.equals("pe");
    }

    void types(Site s, El.Ref r) {
        if (beanType(r.name) == null || r.chain.isEmpty()) {
            return;
        }
        walk(s, r, r.chain.size(), true);
    }

    /** rule 6 */
    void enumCompare(Site s) {
        for (El.Compare c : El.compares(s.x)) {
            if (beanType(c.ref.name) == null) {
                continue;
            }
            String t = walk(s, c.ref, c.ref.chain.size(), false);
            ClassModel.ClassInfo ci = t == null ? null : ws.classes.get(t);
            if (ci == null || !ci.isEnum()) {
                continue;
            }
            List<String> consts = ci.enumConstants();
            if (!consts.isEmpty() && !consts.contains(c.literal)) {
                String hint = closest(c.literal, new HashSet<>(consts));
                report("el.enum", Severity.ERROR, s.x.off(c.litA), s.x.off(c.litB), Msg.t("el.enum", c.literal, ci.simpleName(), String.join(", ", consts.subList(0, Math.min(8, consts.size()))) + (consts.size() > 8 ? ", ..." : "")) + Msg.hint(hint));
            }
        }
    }

    static boolean isInput(Xml.Element e) {
        String lib = Ns.lib(e.ns);
        String l = e.local;
        if (lib.equals("h") || lib.equals("o")) {
            return l.startsWith("input") || l.startsWith("select");
        }
        if (lib.equals("p")) {
            return l.startsWith("input") || l.startsWith("select") || P_INPUTS.contains(l);
        }
        return false;
    }

    /** rule 4 */
    void readonly(Site s) {
        if (s.attr == null || !s.attr.name.equals("value") || !isInput(s.el)) {
            return;
        }
        El.Expr x = s.x;
        // the references inside its brackets (list[i]) do not count: the value is still the outer one
        boolean single = x.whole && x.refs.stream().filter(r -> !r.nested).count() == 1 && x.refs.get(0).pureLvalue;
        if (!single) {
            boolean literalOnly = x.refs.isEmpty() && x.whole;
            report("el.readonly", Severity.ERROR, x.start, x.end, Msg.t(literalOnly ? "el.readonly.literal" : "el.readonly.expr", tag(s.el)));
            return;
        }
        El.Ref r = x.refs.get(0);
        if (beanType(r.name) == null || r.chain.isEmpty()) {
            return;
        }
        String owner = walk(s, r, r.chain.size() - 1, false);
        El.Member last = r.chain.get(r.chain.size() - 1);
        if (owner == null || last.name == null || !ws.classes.complete(owner) || dynamicType(owner)) {
            return;
        }
        ClassModel.Members mm = ws.classes.members(owner);
        if (!mm.getters.containsKey(last.name) || mm.setters.contains(last.name)) {
            return;
        }
        // an interface or abstract class is never the object itself: EL writes on the object that arrives, so the
        // implementations decide (all with the setter: fine; some: depends on which one arrives; none: lost)
        ClassModel.ClassInfo oc = ws.classes.get(owner);
        if (oc != null && (oc.isInterface() || (oc.access & 0x0400) != 0)) {
            List<String> without = new ArrayList<>();
            int with = 0;
            for (String impl : ws.implementations(owner)) {
                if (!ws.classes.complete(impl)) {
                    return;
                }
                if (ws.classes.members(impl).setters.contains(last.name)) {
                    with++;
                } else {
                    without.add(ClassModel.display(impl));
                }
            }
            if (with > 0) {
                if (!without.isEmpty()) {
                    report("el.readonly", Severity.WARNING, x.off(last.a), x.off(last.b),
                            Msg.t("el.readonly.some", last.name, cap(last.name), ClassModel.display(owner), String.join(", ", without)));
                }
                return;
            }
        }
        report("el.readonly", Severity.ERROR, x.off(last.a), x.off(last.b), Msg.t("el.readonly.setter", last.name, cap(last.name), ClassModel.display(owner)));
    }

    // ---------- unused ----------

    void unused() {
        // uses by components that do not go through EL in the page: nothing to do
        for (Decl d : decls) {
            if (d.used || d.attr == null) {
                continue;
            }
            if (d.attr.name.equals("var") && Set.of("p", "pe").contains(Ns.lib(d.el.ns))) {
                continue; // PrimeFaces uses the var internally (field, sortBy, filterBy...)
            }
            // where the files this one brings in use it: a blue note on the declaration
            List<String> uses = new ArrayList<>();
            List<Inc> into = new ArrayList<>();
            for (Inc in : ff.edges) {
                // passed (ui:param inside the include), a template client's ui:param, or reached by the declaration
                boolean own = in.el == d.el.parent;
                if (d.passed ? own : own && d.kind.equals("ui:param") || !d.passed && reaches(d, in.el)) {
                    into.add(in);
                }
            }
            boolean wrongPath = false;
            for (Inc in : into) {
                wrongPath |= in.el == d.el.parent && !in.dynamic && in.target == null;
                for (File t : g.targets(in)) {
                    String at = usedAt(t, d.name);
                    if (at != null && !uses.contains(at)) {
                        uses.add(at);
                    }
                }
            }
            if (!uses.isEmpty()) {
                note(d.attr.offset(0), d.attr.offset(d.attr.value.length()), "origin.used", d.name, uses);
                continue;
            }
            if (wrongPath || d.passed && into.isEmpty()) {
                continue; // wrong path: tpl.path already says so
            }
            if (d.scope == FILE && d.kind.equals("c:set")) {
                continue; // with scope: may be read in another page or in Java
            }
            // a loop around cc:insertChildren: the variable is for what the page writes inside the component
            if (ff.composite && encloses(d.el, "insertChildren")) {
                continue;
            }
            int a = d.attr.offset(0), b = d.attr.offset(d.attr.value.length());
            report("unused", Severity.WARNING, a, b, Msg.t("unused.declared", d.name, d.kind));
        }
    }

    boolean reaches(Decl d, Xml.Element site) {
        return visible(d, site, null, site.start);
    }

    // ---------- composite component (rule 7 and unused cc:attribute) ----------

    void compositeAttrs() {
        if (!ff.composite) {
            return;
        }
        Map<String, Xml.Element> declared = new HashMap<>();
        for (Xml.Element e : doc.all) {
            if (e.is("cc", "attribute") && e.value("name") != null) {
                declared.put(e.value("name").trim(), e);
            }
        }
        Set<String> used = new HashSet<>();
        boolean dynamic = false;
        for (Site s : sites) {
            for (El.Ref r : s.x.refs) {
                if (!r.name.equals("cc") || r.chain.isEmpty() || !"attrs".equals(r.chain.get(0).name)) {
                    continue;
                }
                if (r.chain.size() < 2 || r.chain.get(1).name == null) {
                    dynamic = true;
                    continue;
                }
                El.Member m = r.chain.get(1);
                used.add(m.name);
                if (!declared.containsKey(m.name) && !Set.of("id", "rendered", "binding").contains(m.name)) {
                    String hint = closest(m.name, declared.keySet());
                    report("cc.attrs", Severity.ERROR, s.x.off(m.a), s.x.off(m.b), Msg.t("cc.attrs", m.name)
                            + Msg.hint(hint, hint == null ? null : origin(file, declared.get(hint), "cc:attribute")));
                }
            }
        }
        if (dynamic) {
            return;
        }
        for (Map.Entry<String, Xml.Element> e : declared.entrySet()) {
            Xml.Element el = e.getValue();
            if (used.contains(e.getKey()) || el.value("targets") != null || el.value("method-signature") != null
                    || METHOD_ATTRS.contains(e.getKey())) {
                continue;
            }
            Xml.Attr a = el.attr("name");
            report("unused", Severity.WARNING, a.offset(0), a.offset(a.value.length()), Msg.t("unused.ccattr", e.getKey()));
        }
    }

    // ---------- CSS classes (blue notes; they replace NetBeans' "Missing CSS Class", which only looks at the
    // stylesheets the file itself loads, not those of its template or of the pages that include it) ----------

    static final Map<File, Object[]> CSS_CACHE = new java.util.concurrent.ConcurrentHashMap<>();

    /** class -> line of its first rule (comments, strings, attribute selectors and declarations do not count) */
    static Map<String, Integer> cssClasses(File f) {
        Object[] c = CSS_CACHE.get(f);
        if (c != null && (long) c[0] == f.lastModified()) {
            @SuppressWarnings("unchecked")
            Map<String, Integer> r = (Map<String, Integer>) c[1];
            return r;
        }
        Map<String, Integer> r = new LinkedHashMap<>();
        try {
            r = cssClasses(java.nio.file.Files.readString(f.toPath()));
        } catch (java.io.IOException | RuntimeException e) {
            // unreadable: no classes
        }
        CSS_CACHE.put(f, new Object[]{f.lastModified(), r});
        return r;
    }

    static final Pattern CSS_CLASS = Pattern.compile("\\.(-?[_a-zA-Z][\\w-]*)");

    static Map<String, Integer> cssClasses(String text) {
        Map<String, Integer> r = new LinkedHashMap<>();
        // comments become spaces, keeping the lines
        String t = Pattern.compile("/\\*.*?\\*/", Pattern.DOTALL).matcher(text).replaceAll(m -> m.group().replaceAll("[^\n]", " "));
        int start = 0;
        for (int i = 0; i < t.length(); i++) {
            char ch = t.charAt(i);
            if (ch == '{') {
                // the selector is what comes before a block; @media and the like hold rules, they are no selector
                String prelude = t.substring(start, i);
                if (!prelude.trim().startsWith("@")) {
                    String clean = Pattern.compile("\"[^\"]*\"|'[^']*'|\\[[^\\]]*\\]").matcher(prelude).replaceAll(m -> " ".repeat(m.group().length()));
                    Matcher m = CSS_CLASS.matcher(clean);
                    while (m.find()) {
                        int line = 1;
                        for (int k = 0; k < start + m.start(); k++) {
                            if (t.charAt(k) == '\n') {
                                line++;
                            }
                        }
                        r.putIfAbsent(m.group(1), line);
                    }
                }
                start = i + 1;
            } else if (ch == '}' || ch == ';') {
                start = i + 1;
            }
        }
        return r;
    }

    /** the stylesheets an xhtml file loads (h:outputStylesheet, link rel=stylesheet), with the element that loads each */
    List<Object[]> stylesheets(File f, Xml.Doc d) {
        List<Object[]> r = new ArrayList<>();
        for (Xml.Element e : d.all) {
            List<File> candidates = new ArrayList<>();
            if (e.is("h", "outputStylesheet") && e.value("name") != null && !e.value("name").contains("{")) {
                File res = ws.resourceFile(e.value("library"), e.value("name"));
                if (res != null) {
                    candidates.add(res);
                }
            } else if (e.local.equals("link") && "stylesheet".equalsIgnoreCase(String.valueOf(e.value("rel"))) && e.value("href") != null) {
                // shortcut: an EL in front (#{request.contextPath}) is dropped; a full URL (CDN) is not read
                String href = e.value("href").replaceFirst("^.*[}]", "").replaceFirst("[?#].*$", "");
                if (href.isBlank() || href.contains("://") || href.startsWith("//")) {
                    continue;
                }
                if (href.startsWith("/")) {
                    for (File w : ws.webroots) {
                        candidates.add(new File(w, href.substring(1)));
                    }
                } else {
                    candidates.add(new File(f.getParentFile(), href));
                }
            }
            for (File c : candidates) {
                if (c.isFile()) {
                    r.add(new Object[]{c.getAbsoluteFile(), e});
                    break;
                }
            }
        }
        return r;
    }

    void cssClasses() {
        Map<String, List<String>> where = new LinkedHashMap<>(); // class -> "css/a.css, line N (loaded in x.xhtml, line M)"
        Set<String> own = new HashSet<>(); // the stylesheets this file loads itself: nothing to say about those
        Set<File> view = new LinkedHashSet<>(List.of(file));
        for (File root : g.roots(file)) {
            view.addAll(g.composed(root));
        }
        for (File x : view) {
            FileFacts xf = ws.facts(x);
            if (xf == null) {
                continue;
            }
            for (Object[] sheet : stylesheets(x, xf.doc)) {
                File css = (File) sheet[0];
                File w = ws.webrootOf(css);
                String path = w == null ? css.getName() : w.getAbsoluteFile().toPath().relativize(css.toPath()).toString().replace('\\', '/');
                for (Map.Entry<String, Integer> c : cssClasses(css).entrySet()) {
                    if (x.equals(file)) {
                        own.add(c.getKey());
                    }
                    String place = Msg.t("origin.css.place", Msg.t("origin.place", path, c.getValue()), origin(x, (Xml.Element) sheet[1], null));
                    List<String> l = where.computeIfAbsent(c.getKey(), k -> new ArrayList<>());
                    if (!l.contains(place)) {
                        l.add(place);
                    }
                }
            }
        }
        if (where.isEmpty()) {
            return;
        }
        for (Xml.Element e : doc.all) {
            for (Xml.Attr a : e.attrs) {
                if (!a.name.equals("class") && !a.name.equals("styleClass")) {
                    continue;
                }
                Matcher m = Pattern.compile("[^\\s]+").matcher(a.value);
                while (m.find()) {
                    String c = m.group();
                    if (c.contains("{") || c.contains("}") || own.contains(c)) {
                        continue; // EL, or a class of a stylesheet this file loads itself
                    }
                    int s0 = a.offset(m.start()), s1 = a.offset(m.end());
                    if (where.containsKey(c)) {
                        note("css.class", s0, s1, "origin.css", c, where.get(c));
                    } else {
                        // no rule: often on purpose (a hook for JavaScript, a CSS of a jar or CDN); said only when
                        // a rule with a close name exists, as a possible typo
                        String hint = closest(c, where.keySet());
                        if (hint != null) {
                            report("css.class", Severity.INFO, s0, s1, Msg.t("css.none", c) + Msg.hint(hint, where.get(hint).get(0)));
                        }
                    }
                }
            }
        }
    }

    // ---------- per element rules ----------

    void elements() {
        boolean messagesChecked = false;
        for (Xml.Element e : doc.all) {
            if (Workspace.inRemove(e)) {
                continue;
            }
            String lib = Ns.lib(e.ns);
            String t = tag(e);
            // 20
            if ((t.equals("f:viewParam") || t.equals("f:viewAction") || t.equals("o:viewParam")) && !hasAncestor(e, "f:metadata")) {
                report("meta.viewparam", Severity.ERROR, e.start + 1, e.nameEnd, Msg.t("meta.viewparam", t));
            }
            // 21
            if ((t.equals("p:ajax") || t.equals("f:ajax")) && e.value("event") != null && !e.value("event").contains("{")
                    && e.parent != null && e.parent != doc.root) {
                ajaxEvent(e);
            }
            // 24
            if (t.equals("h:outputStylesheet") || t.equals("h:outputScript") || t.equals("h:graphicImage")
                    || t.equals("p:graphicImage") || t.equals("o:graphicImage")) {
                resource(e, e.value("library"), e.attr("name"));
            }
            // 25
            if (COMMANDS.contains(t) || t.equals("p:menuitem")) {
                Xml.Attr a = e.attr("action");
                if (a != null && !a.value.contains("{") && !a.value.isBlank()) {
                    navigation(a);
                }
            }
            if (Set.of("h:button", "h:link", "p:button", "p:linkButton", "p:menuitem").contains(t)) {
                Xml.Attr a = e.attr("outcome");
                if (a != null && !a.value.contains("{") && !a.value.isBlank()) {
                    navigation(a);
                }
            }
            // 28
            Xml.Attr esc = e.attr("escape");
            if (esc != null && esc.value.trim().equals("false") && e.value("value") != null && e.value("value").contains("{")) {
                report("sec.escape", Severity.WARNING, esc.offset(0), esc.offset(esc.value.length()),
                        Msg.t("sec.escape"));
            }
            // 29
            if (isJsfLib(e) || lib.equals("comp") || lib.equals("ui")) {
                for (Xml.Attr a : e.attrs) {
                    int i = a.value.indexOf("${");
                    if (i >= 0) {
                        report("el.immediate", Severity.WARNING, a.offset(i), a.offset(i + 2),
                                Msg.t("el.immediate"));
                    }
                }
            }
            // 10
            String id = e.value("id");
            if (id != null && Ns.isJsfTag(e) && !lib.equals("?") && !id.contains("{")) {
                if (!id.matches("[A-Za-z_][A-Za-z0-9_-]*")) {
                    Xml.Attr a = e.attr("id");
                    report("id.invalid", Severity.ERROR, a.offset(0), a.offset(a.value.length()),
                            Msg.t("id.invalid"));
                }
            }
            // 17
            if (t.equals("p:fileUpload") && "simple".equals(e.value("mode")) && e.value("listener") == null && !"true".equals(e.value("auto"))) {
                Xml.Element form = ancestor(e, "h:form", "o:form");
                if (form != null && (form.value("enctype") == null || !form.value("enctype").contains("multipart"))) {
                    report("form.upload", Severity.WARNING, e.start + 1, e.nameEnd,
                            Msg.t("form.upload"));
                }
            }
            // 18
            if (!messagesChecked && !ff.composite && ws.tagFiles.get(file) == null && isInput(e) && hasValidation(e)) {
                messagesChecked = true;
                Set<File> roots = g.roots(file);
                boolean any = false, known = !roots.isEmpty();
                for (File r : roots) {
                    for (File f : g.composed(r)) {
                        FileFacts x = ws.facts(f);
                        if (x != null && x.messages) {
                            any = true;
                        }
                    }
                    if (!pageLike(ws.facts(r))) {
                        known = false;
                    }
                }
                if (known && !any) {
                    report("form.messages", Severity.WARNING, e.start + 1, e.nameEnd,
                            Msg.t("form.messages"));
                }
            }
        }
    }

    static boolean hasAncestor(Xml.Element e, String t) {
        return ancestor(e, t) != null;
    }

    static Xml.Element ancestor(Xml.Element e, String... tags) {
        for (Xml.Element p = e.parent; p != null; p = p.parent) {
            if (p.ns != null || p.prefix != null) {
                String pt = tag(p);
                for (String t : tags) {
                    if (t.equals(pt)) {
                        return p;
                    }
                }
            }
        }
        return null;
    }

    static boolean hasValidation(Xml.Element e) {
        String req = e.value("required");
        if (req != null && !req.trim().equals("false")) {
            return true;
        }
        if (e.value("validator") != null) {
            return true;
        }
        for (Xml.Element c : e.elements()) {
            String lib = Ns.lib(c.ns);
            if ((lib.equals("f") || lib.equals("o") || lib.equals("p")) && (c.local.startsWith("validate") || c.local.equals("validator"))) {
                return true;
            }
        }
        return false;
    }

    void ajaxEvent(Xml.Element e) {
        Xml.Element target = e.parent;
        Set<String> evs;
        if ("comp".equals(Ns.lib(target.ns))) {
            File c = ws.compositeFile(target.ns, target.local);
            Xml.Doc cd = c == null ? null : ws.doc(c);
            evs = cd == null ? null : Events.compositeEvents(cd);
            if (evs != null && evs.isEmpty()) {
                evs = null;
            }
        } else {
            evs = ws.events.of(target);
        }
        if (evs == null) {
            return;
        }
        Xml.Attr a = e.attr("event");
        String ev = a.value.trim();
        if (!evs.contains(ev)) {
            List<String> l = new ArrayList<>(evs);
            String hint = closest(ev, evs);
            report("ajax.event", Severity.ERROR, a.offset(0), a.offset(a.value.length()), Msg.t("ajax.event", ev, tag(target), Msg.hint(hint), String.join(", ", l.subList(0, Math.min(14, l.size()))) + (l.size() > 14 ? ", ..." : "")));
        }
    }

    void resource(Xml.Element e, String library, Xml.Attr nameAttr) {
        if (nameAttr == null || nameAttr.value.contains("{") || library != null && library.contains("{")) {
            return;
        }
        String lib = library == null ? null : library.trim();
        if (lib != null && Set.of("javax.faces", "jakarta.faces", "primefaces", "omnifaces", "primefaces-extensions").contains(lib)) {
            return;
        }
        if (!ws.resourceExists(lib, nameAttr.value.trim())) {
            report("res.missing", Severity.ERROR, nameAttr.offset(0), nameAttr.offset(nameAttr.value.length()), Msg.t("res.missing", (lib == null ? "" : lib + "/") + nameAttr.value.trim()));
        }
    }

    void navigation(Xml.Attr a) {
        String o = a.value.trim();
        int q = o.indexOf('?');
        String path = q >= 0 ? o.substring(0, q) : o;
        if (path.isEmpty() || ws.navOutcomes.contains(path) || path.startsWith("http") || path.startsWith("#")) {
            return;
        }
        if (path.endsWith(".jsf") || path.endsWith(".faces")) {
            path = path.substring(0, path.lastIndexOf('.')) + ".xhtml";
        } else if (!path.contains(".")) {
            path = path + ".xhtml";
        }
        Set<File> dirs = new LinkedHashSet<>();
        Set<File> roots = g.roots(file);
        for (File r : roots) {
            dirs.add(r.getParentFile());
        }
        if (dirs.isEmpty()) {
            dirs.add(file.getParentFile());
        }
        for (File d : dirs) {
            if (path.startsWith("/")) {
                for (File w : ws.webroots) {
                    if (new File(w, path.substring(1)).isFile()) {
                        return;
                    }
                }
            } else if (new File(d, path).isFile()) {
                return;
            }
        }
        report("nav.missing", roots.isEmpty() ? Severity.WARNING : Severity.ERROR, a.offset(0), a.offset(a.value.length()),
                Msg.t("nav.missing", path));
    }

    // ---------- ids (8 to 13) ----------

    static final class Universe {
        final Set<String> ids = new HashSet<>();
        final Set<String> widgetVars = new HashSet<>();
        boolean dynamicIds, dynamicWv;
    }

    List<Universe> universes() {
        List<Universe> r = new ArrayList<>();
        for (File root : g.roots(file)) {
            Universe u = new Universe();
            for (File f : g.composed(root)) {
                FileFacts x = ws.facts(f);
                if (x == null) {
                    u.dynamicIds = u.dynamicWv = true;
                    continue;
                }
                u.ids.addAll(x.ids);
                u.widgetVars.addAll(x.widgetVars);
                u.dynamicIds |= x.dynamicIds;
                u.dynamicWv |= x.dynamicWidgetVars;
            }
            r.add(u);
        }
        return r;
    }

    /** the other files of the view (every page that uses this one) that have the id or widgetVar */
    List<String> elsewhere(String attr, String value, Predicate<FileFacts> has) {
        List<String> r = new ArrayList<>();
        for (File root : g.roots(file)) {
            for (File f : g.composed(root)) {
                FileFacts x = ws.facts(f);
                if (!f.equals(file) && x != null && has.test(x)) {
                    String o = origin(f, withAttr(x.doc, attr, value), null);
                    if (!r.contains(o)) {
                        r.add(o);
                    }
                }
            }
        }
        return r;
    }

    boolean isNamingContainer(Xml.Element e) {
        if (NC_STATIC.contains(tag(e)) || "comp".equals(Ns.lib(e.ns))) {
            return true;
        }
        return false;
    }

    static final Pattern PF_CALL = Pattern.compile("PF\\(\\s*(['\"])([^'\"]+)\\1\\s*\\)");

    void ids() {
        List<Universe> us = universes();
        Map<Xml.Element, Map<String, Xml.Element>> byNc = new HashMap<>();
        Map<String, Xml.Element> localIds = new HashMap<>();
        for (Xml.Element e : doc.all) {
            String lid = e.value("id");
            if (lid != null && !lid.contains("{") && Ns.isJsfTag(e) && !Workspace.inRemove(e)) {
                localIds.putIfAbsent(lid.trim(), e);
            }
        }
        for (Xml.Element e : doc.all) {
            if (Workspace.inRemove(e)) {
                continue;
            }
            String t = tag(e);
            boolean jsf = Ns.isJsfTag(e) && !Ns.lib(e.ns).equals("?");
            String id = e.value("id");
            if (jsf && id != null && !id.contains("{")) {
                Xml.Element nc = doc.root;
                Xml.Element forEach = null;
                for (Xml.Element p = e.parent; p != null; p = p.parent) {
                    if (isNamingContainer(p)) {
                        nc = p;
                        break;
                    }
                    if (forEach == null && p.is("c", "forEach")) {
                        forEach = p;
                    }
                }
                Xml.Attr ia = e.attr("id");
                if (forEach != null && !isNamingContainer(e)) {
                    report("id.duplicate", Severity.ERROR, ia.offset(0), ia.offset(ia.value.length()), Msg.t("id.duplicate.foreach", id, doc.line(forEach.start)));
                }
                Map<String, Xml.Element> m = byNc.computeIfAbsent(nc, k -> new HashMap<>());
                Xml.Element prev = m.get(id.trim());
                if (prev != null) {
                    boolean exclusive = !conditionals(prev, nc).equals(conditionals(e, nc));
                    report("id.duplicate", exclusive ? Severity.WARNING : Severity.ERROR, ia.offset(0), ia.offset(ia.value.length()),
                            Msg.t(exclusive ? "id.duplicate.jstl" : "id.duplicate", id, doc.line(prev.start)));
                } else {
                    m.put(id.trim(), e);
                }
            }
            // update / process / for ...
            for (Xml.Attr a : e.attrs) {
                boolean search = (a.name.equals("update") || a.name.equals("process")) && (Ns.lib(e.ns).equals("p") || Ns.lib(e.ns).equals("pe"))
                        || (a.name.equals("render") || a.name.equals("execute")) && t.equals("f:ajax")
                        || a.name.equals("for") && FOR_TAGS.contains(t)
                        || (a.name.equals("block") || a.name.equals("trigger")) && t.equals("p:blockUI")
                        || a.name.equals("target") && (t.equals("p:defaultCommand") || t.equals("p:printer"));
                if (search && !a.value.contains("{")) {
                    searchExpr(e, a, us, localIds);
                }
                if (a.name.startsWith("on")) {
                    widgetRefs(a.value, i -> a.offset(i), us);
                }
            }
            if (t.equals("html:script") || e.local.equals("script") || t.equals("h:outputScript")) {
                for (Xml.Node n : e.children) {
                    if (n instanceof Xml.Text) {
                        int base = n.start;
                        widgetRefs(((Xml.Text) n).raw, i -> base + i, us);
                    }
                }
            }
        }
    }

    static List<Xml.Element> conditionals(Xml.Element e, Xml.Element stop) {
        List<Xml.Element> r = new ArrayList<>();
        for (Xml.Element p = e.parent; p != null && p != stop; p = p.parent) {
            if (p.is("c", "if", "when", "otherwise")) {
                r.add(p);
            }
        }
        return r;
    }

    void widgetRefs(String text, java.util.function.IntUnaryOperator off, List<Universe> us) {
        if (us.isEmpty()) {
            return;
        }
        Matcher m = PF_CALL.matcher(text);
        while (m.find()) {
            String wv = m.group(2);
            boolean found = false, dynamic = false;
            for (Universe u : us) {
                found |= u.widgetVars.contains(wv);
                dynamic |= u.dynamicWv;
            }
            if (!found && !dynamic) {
                report("js.widgetvar", Severity.WARNING, off.applyAsInt(m.start(2)), off.applyAsInt(m.end(2)),
                        Msg.t("js.widgetvar", wv));
            } else if (found && !ff.widgetVars.contains(wv)) {
                note(off.applyAsInt(m.start(2)), off.applyAsInt(m.end(2)), "origin.widgetvar", wv,
                        elsewhere("widgetVar", wv, x -> x.widgetVars.contains(wv)));
            }
        }
    }

    void searchExpr(Xml.Element e, Xml.Attr a, List<Universe> us, Map<String, Xml.Element> localIds) {
        String v = a.value;
        // split by space/comma outside parentheses: @(:input) and @(form > .x) stay whole
        List<int[]> toks = new ArrayList<>();
        int depth = 0, st = -1;
        for (int i = 0; i <= v.length(); i++) {
            char c = i < v.length() ? v.charAt(i) : ' ';
            if (c == '(') {
                depth++;
            } else if (c == ')') {
                depth = Math.max(0, depth - 1);
            }
            boolean sep = depth == 0 && (Character.isWhitespace(c) || c == ',');
            if (!sep && st < 0) {
                st = i;
            } else if (sep && st >= 0) {
                toks.add(new int[]{st, i});
                st = -1;
            }
        }
        for (int[] tk : toks) {
            String tok = v.substring(tk[0], tk[1]);
            int ts = tk[0];
            if (tok.contains("@")) {
                // keywords (may appear inside paths: form:@child(1))
                Matcher k = Pattern.compile("@(\\w*)").matcher(Pattern.compile("\\([^)]*\\)").matcher(tok).replaceAll(m2 -> "~".repeat(m2.group().length())));
                while (k.find()) {
                    String kw = k.group(1);
                    if (kw.isEmpty() || PF_KEYWORDS.contains(kw)) {
                        continue;
                    }
                    String hint = closest(kw, PF_KEYWORDS);
                    report("id.keyword", hint != null ? Severity.ERROR : Severity.WARNING, a.offset(ts + k.start()), a.offset(ts + k.end()),
                            Msg.t("id.keyword", kw) + (hint != null ? Msg.hint("@" + hint) : ""));
                }
                continue;
            }
            String[] segs = tok.split(":");
            String last = segs[segs.length - 1];
            if (last.isEmpty() || us.isEmpty()) {
                continue;
            }
            int missingIn = 0;
            boolean dynamic = false;
            for (Universe u : us) {
                if (!u.ids.contains(last)) {
                    missingIn++;
                    dynamic |= u.dynamicIds;
                }
            }
            int a0 = a.offset(ts + tok.length() - last.length()), a1 = a.offset(ts + tok.length());
            if (missingIn == us.size()) {
                Set<String> all = new HashSet<>();
                for (Universe u : us) {
                    all.addAll(u.ids);
                }
                String hint = closest(last, all);
                Set<File> view = new LinkedHashSet<>(List.of(file));
                for (File root : g.roots(file)) {
                    view.addAll(g.composed(root));
                }
                report("id.missing", dynamic ? Severity.WARNING : Severity.ERROR, a0, a1, Msg.t("id.missing", last)
                        + Msg.hint(hint, hint == null ? null : placeOfAttr(view, null, "id", hint)));
            } else if (missingIn > 0 && !dynamic) {
                report("id.missing", Severity.WARNING, a0, a1, Msg.t("id.missing.some", last));
            } else if (missingIn == 0 && !ff.ids.contains(last)) {
                note(a0, a1, "origin.id", last, elsewhere("id", last, x -> x.ids.contains(last)));
            } else if (a.name.equals("update") || a.name.equals("render")) {
                Xml.Element target = localIds.get(last);
                if (target != null && target.value("rendered") != null && target.value("rendered").contains("{")) {
                    report("id.rendered", Severity.WARNING, a0, a1, Msg.t("id.rendered", last));
                }
            }
        }
    }

    // ---------- forms (14 to 16) ----------

    enum Tri { TRUE, FALSE, DIALOG, UNKNOWN }

    static boolean isForm(Xml.Element e) {
        return e.is("h", "form") || e.is("o", "form");
    }

    static boolean bodyDialog(Xml.Element e) {
        if (!"p".equals(Ns.lib(e.ns)) || !Set.of("dialog", "confirmDialog", "overlayPanel", "sidebar").contains(e.local)) {
            return false;
        }
        String ap = e.value("appendTo");
        return ap != null && ap.replace(" ", "").matches("@\\(body\\)|@body|body");
    }

    Tri formCtx(File f, Xml.Doc d, Xml.Element el, Set<String> guard) {
        if (!guard.add(f.getPath() + "#" + el.start)) {
            return Tri.UNKNOWN;
        }
        Xml.Element define = null;
        for (Xml.Element p = el.parent; p != null && p != d.root; p = p.parent) {
            if (isForm(p)) {
                return Tri.TRUE;
            }
            if (bodyDialog(p)) {
                return Tri.DIALOG;
            }
            if (define == null && p.is("ui", "define")) {
                define = p;
            }
        }
        FileFacts x = ws.facts(f);
        if (x == null) {
            return Tri.UNKNOWN;
        }
        // ui:define content: goes to the template's ui:insert
        if (define != null) {
            Inc tpl = null;
            for (Inc in : x.edges) {
                if (!in.kind.equals("include") && isAncestor(in.el, define)) {
                    tpl = in;
                }
            }
            if (tpl == null || tpl.target == null) {
                return Tri.UNKNOWN;
            }
            String name = define.value("name");
            List<Tri> rs = new ArrayList<>();
            for (File tf : g.composed(tpl.target)) {
                FileFacts tx = ws.facts(tf);
                if (tx == null) {
                    continue;
                }
                for (Xml.Element ie : tx.doc.all) {
                    if (ie.is("ui", "insert") && name != null && name.equals(ie.value("name"))) {
                        rs.add(formCtx(tf, tx.doc, ie, guard));
                    }
                }
            }
            return combine(rs);
        }
        if (x.composite) {
            return Tri.UNKNOWN; // whoever uses the component decides
        }
        List<Inc> inc = g.in(f);
        if (inc.isEmpty()) {
            return pageLike(x) ? Tri.FALSE : Tri.UNKNOWN;
        }
        List<Tri> rs = new ArrayList<>();
        for (Inc in : inc) {
            FileFacts from = ws.facts(in.from);
            rs.add(from == null ? Tri.UNKNOWN : formCtx(in.from, from.doc, in.el, guard));
        }
        return combine(rs);
    }

    static boolean isAncestor(Xml.Element a, Xml.Element b) {
        for (Xml.Element p = b; p != null; p = p.parent) {
            if (p == a) {
                return true;
            }
        }
        return false;
    }

    static Tri combine(List<Tri> rs) {
        if (rs.isEmpty()) {
            return Tri.UNKNOWN;
        }
        Tri first = rs.get(0);
        for (Tri t : rs) {
            if (t != first) {
                return Tri.UNKNOWN;
            }
        }
        return first;
    }

    void forms() {
        for (Xml.Element e : doc.all) {
            if (Workspace.inRemove(e)) {
                continue;
            }
            String t = tag(e);
            boolean command = COMMANDS.contains(t) && !"button".equals(e.value("type"))
                    || t.equals("p:menuitem") && (e.value("action") != null || e.value("actionListener") != null || e.value("update") != null)
                    && e.value("url") == null && e.value("outcome") == null;
            boolean input = !command && isInput(e);
            if (command || input) {
                Tri c = formCtx(file, doc, e, new HashSet<>());
                if (c == Tri.DIALOG) {
                    report("form.dialog", Severity.ERROR, e.start + 1, e.nameEnd, Msg.t("form.dialog", t));
                } else if (c == Tri.FALSE) {
                    boolean acts = e.value("action") != null || e.value("actionListener") != null || e.value("update") != null
                            || e.value("process") != null || e.value("listener") != null || t.equals("p:remoteCommand") || t.equals("p:poll");
                    if (command) {
                        report("form.outside", acts ? Severity.ERROR : Severity.WARNING, e.start + 1, e.nameEnd, Msg.t(acts ? "form.outside.action" : "form.outside.button", t));
                    } else if (e.value("value") != null && e.value("value").contains("#{")) {
                        report("form.outside", Severity.WARNING, e.start + 1, e.nameEnd, Msg.t("form.outside.input", t));
                    }
                }
            }
            if (isForm(e)) {
                Tri c = formCtx(file, doc, e, new HashSet<>());
                if (c == Tri.TRUE) {
                    report("form.nested", Severity.ERROR, e.start + 1, e.nameEnd, Msg.t("form.nested"));
                }
            }
        }
    }

    // ---------- templates (22, 23) ----------

    void templates() {
        for (Inc in : ff.edges) {
            Xml.Attr a = in.el.attr(in.kind.equals("include") ? "src" : "template");
            if (!in.dynamic && in.target == null && a != null) {
                report("tpl.path", Severity.ERROR, a.offset(0), a.offset(a.value.length()), Msg.t("tpl.path", in.path));
            }
            if (in.kind.equals("include") || in.target == null) {
                continue;
            }
            Set<String> inserts = new HashSet<>();
            boolean unnamed = false;
            for (File tf : g.composed(in.target)) {
                FileFacts tx = ws.facts(tf);
                if (tx != null) {
                    inserts.addAll(tx.inserts);
                    unnamed |= tx.unnamedInsert;
                }
            }
            for (Xml.Element d : in.el.elements()) {
                if (d.is("ui", "define")) {
                    Xml.Attr n = d.attr("name");
                    // only f:metadata, in the page itself: works without the ui:insert. JSF reads the f:metadata of
                    // the page in a pass of its own, ignoring the template, and keeps it in the view on every request
                    // (Mojarra: SAXCompiler metadata compile, FaceletViewHandlingStrategy.restoreView, ComponentSupport;
                    // MyFaces since 2.1.11, MYFACES-3665). In a template or included file it is not read: error
                    boolean onlyMetadata = !d.elements().isEmpty() && d.elements().stream().allMatch(c -> c.is("f", "metadata"))
                            && d.children.stream().noneMatch(c -> c instanceof Xml.Text && !((Xml.Text) c).raw.isBlank());
                    // empty: nothing is lost, it just does nothing
                    boolean empty = d.elements().isEmpty()
                            && d.children.stream().noneMatch(c -> c instanceof Xml.Text && !((Xml.Text) c).raw.isBlank());
                    if (n != null && empty && !inserts.contains(n.value.trim())) {
                        report("tpl.define", Severity.WARNING, n.offset(0), n.offset(n.value.length()), Msg.t("tpl.define.empty", n.value.trim()));
                    } else if (n != null && !empty && !(onlyMetadata && ws.incoming(in.from).isEmpty()) && !inserts.contains(n.value.trim())) {
                        String hint = closest(n.value.trim(), inserts);
                        report("tpl.define", Severity.ERROR, n.offset(0), n.offset(n.value.length()), Msg.t("tpl.define.name", n.value.trim())
                                + Msg.hint(hint, hint == null ? null : placeOfAttr(g.composed(in.target), "insert", "name", hint)));
                    }
                }
            }
            if (!unnamed) {
                for (Xml.Node n : in.el.children) {
                    if (n instanceof Xml.Element) {
                        Xml.Element c = (Xml.Element) n;
                        if (!c.is("ui", "define", "param", "remove") && !c.is("f", "metadata")) {
                            report("tpl.define", Severity.ERROR, c.start + 1, c.nameEnd, Msg.t("tpl.define.tag", tag(c).replace("html:", "")));
                        }
                    } else if (n instanceof Xml.Text && !((Xml.Text) n).raw.isBlank()) {
                        String raw = ((Xml.Text) n).raw;
                        int s = n.start + (raw.length() - raw.stripLeading().length());
                        report("tpl.define", Severity.ERROR, s, s + Math.min(raw.strip().length(), 30),
                                Msg.t("tpl.define.text"));
                    }
                }
            }
        }
    }

    // ---------- comments, entities ----------

    void comments() {
        if (ws.skipComments) {
            return;
        }
        for (Xml.Comment c : doc.comments) {
            for (El.Expr x : El.find(c.content, c.contentStart)) {
                if (x.deferred || !x.text.isBlank()) {
                    report("comment.el", Severity.WARNING, x.start, x.end, Msg.t("comment.el"));
                }
            }
        }
    }

    void entities() {
        String dt = doc.doctype == null ? "" : doc.doctype;
        boolean xhtmlDtd = dt.contains("-//W3C//DTD XHTML");
        for (Xml.Entity en : doc.entities) {
            if (Xml.XML_ENTITIES.containsKey(en.name) || en.name.startsWith("#") || xhtmlDtd || dt.contains("ENTITY " + en.name)) {
                continue;
            }
            String code = HTML_CODES.get(en.name);
            report("xml.entity", Severity.ERROR, en.start, en.end, (code != null ? Msg.t("xml.entity.code", en.name, code) : Msg.t("xml.entity", en.name)));
        }
    }

    static final Map<String, String> HTML_CODES = Map.ofEntries(Map.entry("nbsp", "&#160;"), Map.entry("copy", "&#169;"),
            Map.entry("reg", "&#174;"), Map.entry("ndash", "&#8211;"), Map.entry("mdash", "&#8212;"), Map.entry("hellip", "&#8230;"),
            Map.entry("laquo", "&#171;"), Map.entry("raquo", "&#187;"), Map.entry("euro", "&#8364;"), Map.entry("trade", "&#8482;"),
            Map.entry("middot", "&#183;"), Map.entry("bull", "&#8226;"), Map.entry("times", "&#215;"), Map.entry("deg", "&#176;"),
            Map.entry("ccedil", "&#231;"), Map.entry("atilde", "&#227;"), Map.entry("aacute", "&#225;"), Map.entry("eacute", "&#233;"),
            Map.entry("iacute", "&#237;"), Map.entry("oacute", "&#243;"), Map.entry("uacute", "&#250;"), Map.entry("otilde", "&#245;"));

    static List<String> list(String... s) {
        return Arrays.asList(s);
    }
}
