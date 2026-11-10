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
        boolean dynamic;
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
                        dynamic = true;
                    } else if (in.target != null) {
                        incoming.computeIfAbsent(in.target, k -> new ArrayList<>()).add(in);
                    }
                }
            }
        }

        List<Inc> in(File f) {
            return incoming.getOrDefault(f, List.of());
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
                        if (in.target != null) {
                            todo.add(in.target);
                        }
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
        boolean complete = true;
    }

    final Map<File, Ext> extCache = new HashMap<>();

    Ext ext(File f, Set<File> guard) {
        Ext cached = extCache.get(f);
        if (cached != null) {
            return cached;
        }
        Ext r = new Ext();
        if (!guard.add(f)) {
            r.complete = false;
            return r;
        }
        FileFacts x = ws.facts(f);
        if (x == null || x.composite) {
            extCache.put(f, r);
            return r;
        }
        Set<String> tagAttrs = ws.tagFiles.get(f);
        if (tagAttrs != null) {
            // tag file: the attributes of whoever uses the tag become variables
            r.names.addAll(tagAttrs);
            r.complete = false;
            extCache.put(f, r);
            return r;
        }
        List<Inc> inc = g.in(f);
        if (inc.isEmpty()) {
            r.complete = pageLike(x);
        } else {
            r.complete = !g.dynamic;
            for (Inc in : inc) {
                FileFacts from = ws.facts(in.from);
                if (from == null) {
                    r.complete = false;
                    continue;
                }
                for (Xml.Element p : in.el.elements()) {
                    if (p.is("ui", "param") && p.value("name") != null) {
                        r.names.add(p.value("name").trim());
                    }
                }
                for (Decl d : decls(from.doc)) {
                    if (d.scope == FILE && !d.passed || visible(d, in.el, null, in.el.start)) {
                        r.names.add(d.name);
                    }
                }
                r.names.addAll(from.bindings);
                Ext up = ext(in.from, guard);
                r.names.addAll(up.names);
                r.complete &= up.complete;
            }
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
        if (ws.omnifaces) {
            globals.add("now");
            globals.add("startup");
        }
        for (File r : g.roots(file)) {
            for (File f : g.composed(r)) {
                FileFacts x = ws.facts(f);
                if (x != null) {
                    globals.addAll(x.bindings);
                }
            }
        }
        globals.addAll(ff.bindings);
        ext = ext(file, new HashSet<>());

        names();
        unused();
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
                if (!ws.beansKnown) {
                    continue;
                }
                boolean sure = ext.complete && !ws.customElResolver;
                String hint = closest(r.name, allNamesAt(s, attrName, pos));
                report("el.unknown", sure ? Severity.ERROR : Severity.WARNING, pos, s.x.off(r.b),
                        Msg.t(sure ? "el.unknown" : "el.unknown.maybe", r.name) + Msg.hint(hint));
            }
            enumCompare(s);
            readonly(s);
        }
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
        boolean methodAttr = s.attr != null && METHOD_ATTRS.contains(s.attr.name) && isJsfLib(s.el) && s.x.whole && r.chain.size() > 0;
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
        boolean single = x.whole && x.refs.size() == 1 && x.refs.get(0).pureLvalue;
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
        if (mm.getters.containsKey(last.name) && !mm.setters.contains(last.name)) {
            report("el.readonly", Severity.ERROR, x.off(last.a), x.off(last.b), Msg.t("el.readonly.setter", last.name, cap(last.name), ClassModel.display(owner)));
        }
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
            boolean usedElsewhere = false;
            if (d.passed) {
                Inc inc = null;
                for (Inc in : ff.edges) {
                    if (in.el == d.el.parent) {
                        inc = in;
                    }
                }
                if (inc == null || inc.target == null) {
                    continue; // dynamic include or wrong path: no way to know
                }
                usedElsewhere = g.usedIn(inc.target).contains(d.name);
            } else {
                // inside some include reached by the declaration
                for (Inc in : ff.edges) {
                    if (in.dynamic) {
                        if (reaches(d, in.el)) {
                            usedElsewhere = true; // no way to know
                        }
                        continue;
                    }
                    if (in.target != null && reaches(d, in.el) && g.usedIn(in.target).contains(d.name)) {
                        usedElsewhere = true;
                    }
                }
                // ui:param of a template client: the template uses it
                if (d.kind.equals("ui:param") && d.el.parent != null && d.el.parent.value("template") != null) {
                    Inc t = null;
                    for (Inc in : ff.edges) {
                        if (in.el == d.el.parent) {
                            t = in;
                        }
                    }
                    if (t == null || t.target == null) {
                        continue;
                    }
                    usedElsewhere |= g.usedIn(t.target).contains(d.name);
                }
                if (d.scope == FILE && d.kind.equals("c:set")) {
                    continue; // with scope: may be read in another page or in Java
                }
            }
            if (!usedElsewhere) {
                int a = d.attr.offset(0), b = d.attr.offset(d.attr.value.length());
                report("unused", Severity.WARNING, a, b, Msg.t("unused.declared", d.name, d.kind));
            }
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
                    report("cc.attrs", Severity.ERROR, s.x.off(m.a), s.x.off(m.b), Msg.t("cc.attrs", m.name) + Msg.hint(hint));
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
                boolean any = false, known = !roots.isEmpty() && !g.dynamic;
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
                for (Inc in : x.edges) {
                    if (in.dynamic) {
                        u.dynamicIds = u.dynamicWv = true;
                    }
                }
            }
            if (!pageLike(ws.facts(root))) {
                u.dynamicIds = u.dynamicWv = true; // fragment nobody includes: no way to be sure
            }
            r.add(u);
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
                report("id.missing", dynamic ? Severity.WARNING : Severity.ERROR, a0, a1, Msg.t("id.missing", last) + Msg.hint(hint));
            } else if (missingIn > 0 && !dynamic) {
                report("id.missing", Severity.WARNING, a0, a1, Msg.t("id.missing.some", last));
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
        if (g.dynamic) {
            return Tri.UNKNOWN;
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
                    if (n != null && !(onlyMetadata && ws.incoming(in.from).isEmpty()) && !inserts.contains(n.value.trim())) {
                        String hint = closest(n.value.trim(), inserts);
                        report("tpl.define", Severity.ERROR, n.offset(0), n.offset(n.value.length()), Msg.t("tpl.define.name", n.value.trim()) + Msg.hint(hint));
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
