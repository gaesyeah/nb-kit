package nbkit.jsf;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.xml.parsers.DocumentBuilderFactory;
import org.w3c.dom.Document;
import org.w3c.dom.NodeList;

/**
 * Tudo o que um arquivo precisa saber do projeto: pastas web, beans, faces-config, web.xml,
 * os outros xhtml (includes e templates) e as bibliotecas de componentes. Tudo em cache.
 */
public final class Workspace {

    public static final class Bean {
        public String name, type; // type: nome interno da classe ou null
        public String origin;
    }

    public final File projectDir;
    public final List<File> webroots;
    public final List<File> javaSources;
    public final List<File> classRoots;
    public final ClassModel classes;

    public final Map<String, Bean> beans = new ConcurrentHashMap<>();
    public final Set<String> facesVars = new HashSet<>();
    public final Set<String> navOutcomes = new HashSet<>();
    public boolean customElResolver;
    public boolean skipComments;
    public boolean omnifaces;
    public boolean beansKnown;
    /** namespace -> tag -> component-type */
    public final Map<String, Map<String, String>> tagTypes = new HashMap<>();
    /** component-type -> classe */
    public final Map<String, String> componentClasses = new HashMap<>();
    public final Events events;
    /** tag files do proprio projeto (taglib.xml com source): arquivo -> atributos declarados */
    public final Map<File, Set<String>> tagFiles = new HashMap<>();
    /** namespace -> tag -> arquivo */
    public final Map<String, Map<String, File>> tagSources = new HashMap<>();

    private Workspace(File projectDir, List<File> webroots, List<File> javaSources, List<File> classRoots) {
        this.projectDir = projectDir;
        this.webroots = webroots;
        this.javaSources = javaSources;
        this.classRoots = classRoots;
        this.classes = new ClassModel(classRoots);
        this.events = new Events(this);
    }

    // ---------- cache por projeto ----------

    private static final Map<String, Workspace> ALL = new ConcurrentHashMap<>();
    private long scannedAt;
    private String scannedSignature;

    /** pasta do projeto a partir de um xhtml: sobe ate achar pom.xml, build.gradle ou WEB-INF */
    public static File projectOf(File file) {
        File webInf = null;
        for (File d = file.getParentFile(); d != null; d = d.getParentFile()) {
            if (new File(d, "pom.xml").isFile() || new File(d, "build.gradle").isFile() || new File(d, "build.gradle.kts").isFile()
                    || new File(d, "nbproject").isDirectory()) {
                return d;
            }
            if (webInf == null && new File(d, "WEB-INF").isDirectory()) {
                webInf = d;
            }
        }
        return webInf != null ? webInf.getParentFile() : file.getParentFile();
    }

    public static List<File> webrootsOf(File project, File file) {
        List<File> r = new ArrayList<>();
        for (String p : new String[]{"src/main/webapp", "src/main/resources/META-INF/resources", "src/main/resources/static",
            "web", "WebContent", "WebRoot"}) {
            File d = new File(project, p);
            if (d.isDirectory()) {
                r.add(d);
            }
        }
        if (r.isEmpty() && file != null) {
            for (File d = file.getParentFile(); d != null && !d.equals(project.getParentFile()); d = d.getParentFile()) {
                if (new File(d, "WEB-INF").isDirectory()) {
                    r.add(d);
                    break;
                }
            }
        }
        if (r.isEmpty() && file != null) {
            r.add(file.getParentFile());
        }
        return r;
    }

    /**
     * classpath: jars e pastas de classes (vindos do NetBeans) mais as pastas de saida do proprio projeto.
     */
    public static synchronized Workspace get(File file, List<File> classpath) {
        File project = projectOf(file);
        List<File> roots = new ArrayList<>();
        for (String p : new String[]{"target/classes", "build/classes/java/main", "build/classes", "build/web/WEB-INF/classes"}) {
            File d = new File(project, p);
            if (d.isDirectory()) {
                roots.add(d);
            }
        }
        for (File f : classpath) {
            if (!roots.contains(f) && f.exists()) {
                roots.add(f);
            }
        }
        String key = project.getAbsolutePath() + "|" + roots;
        Workspace w = ALL.get(key);
        if (w == null) {
            // classpath mudou: descarta o antigo do mesmo projeto
            ALL.entrySet().removeIf(e -> {
                if (e.getKey().startsWith(project.getAbsolutePath() + "|")) {
                    e.getValue().classes.close();
                    e.getValue().events.close();
                    return true;
                }
                return false;
            });
            List<File> src = new ArrayList<>();
            for (String p : new String[]{"src/main/java", "src"}) {
                File d = new File(project, p);
                if (d.isDirectory()) {
                    src.add(d);
                    break;
                }
            }
            w = new Workspace(project, webrootsOf(project, file), src, roots);
            ALL.put(key, w);
        }
        w.refresh();
        return w;
    }

    /** Para testes: workspace explicito */
    public static Workspace create(File project, List<File> webroots, List<File> javaSources, List<File> classRoots) {
        Workspace w = new Workspace(project, webroots, javaSources, classRoots);
        w.refresh();
        return w;
    }

    // ---------- varredura (beans, faces-config, web.xml, taglibs) ----------

    private String signature() {
        StringBuilder b = new StringBuilder();
        for (File r : classRoots) {
            b.append(r.getPath()).append(':').append(r.isFile() ? r.lastModified() + "/" + r.length() : newest(r)).append(';');
        }
        for (File s : javaSources) {
            b.append(newest(s)).append(';');
        }
        for (File w : webroots) {
            b.append(new File(w, "WEB-INF/faces-config.xml").lastModified()).append(new File(w, "WEB-INF/web.xml").lastModified());
        }
        return b.toString();
    }

    private static long newest(File dir) {
        long[] m = {dir.lastModified()};
        try (var s = Files.walk(dir.toPath())) {
            s.forEach(p -> m[0] = Math.max(m[0], p.toFile().lastModified()));
        } catch (IOException | RuntimeException ex) {
            // ignora
        }
        return m[0];
    }

    public synchronized void refresh() {
        long now = System.currentTimeMillis();
        if (scannedSignature != null && now - scannedAt < 5000) {
            return;
        }
        scannedAt = now;
        String sig = signature();
        if (sig.equals(scannedSignature)) {
            return;
        }
        scannedSignature = sig;
        classes.close();
        classes.clearCache();
        events.close();
        scanAll();
    }

    private static final String COMPONENT = "Lorg/springframework/stereotype/Component;";
    private static final Set<String> NAMED = Set.of("Ljavax/inject/Named;", "Ljakarta/inject/Named;");
    private static final String MANAGED = "Ljavax/faces/bean/ManagedBean;";
    private static final String BEAN = "Lorg/springframework/context/annotation/Bean;";

    private void scanAll() {
        beans.clear();
        facesVars.clear();
        navOutcomes.clear();
        tagTypes.clear();
        componentClasses.clear();
        customElResolver = false;
        Map<String, List<String>> annotationMeta = new HashMap<>();
        List<ClassModel.ClassInfo> candidates = new ArrayList<>();
        boolean[] any = {false};
        classes.forEachClass(b -> {
            any[0] = true;
            try {
                ClassModel.ClassInfo c = ClassModel.read(b, false);
                if (c.isAnnotation()) {
                    List<String> l = new ArrayList<>();
                    for (ClassModel.Annotation a : c.annotations) {
                        l.add(a.type);
                    }
                    annotationMeta.put("L" + c.name + ";", l);
                } else if (!c.annotations.isEmpty() || !c.methods.isEmpty()) {
                    candidates.add(c);
                }
            } catch (IOException | RuntimeException ex) {
                // classe ilegivel
            }
        });
        // esteriotipos do Spring, incluindo os proprios (meta-anotacoes)
        Set<String> stereo = new HashSet<>();
        stereo.add(COMPONENT);
        boolean changed = true;
        while (changed) {
            changed = false;
            for (Map.Entry<String, List<String>> e : annotationMeta.entrySet()) {
                if (!stereo.contains(e.getKey())) {
                    for (String t : e.getValue()) {
                        if (stereo.contains(t)) {
                            stereo.add(e.getKey());
                            changed = true;
                            break;
                        }
                    }
                }
            }
        }
        for (ClassModel.ClassInfo c : candidates) {
            for (ClassModel.Annotation a : c.annotations) {
                String name = null;
                if (stereo.contains(a.type) && !c.isInterface()) {
                    name = a.string("value");
                } else if (NAMED.contains(a.type)) {
                    name = a.string("value");
                } else if (MANAGED.equals(a.type)) {
                    name = a.string("name");
                } else {
                    continue;
                }
                if (name == null || name.isBlank()) {
                    name = ClassModel.decap(c.simpleName());
                }
                addBean(name, c.name, "anotacao");
            }
            for (ClassModel.MethodInfo m : c.methods) {
                for (ClassModel.Annotation a : m.annotations) {
                    if (BEAN.equals(a.type)) {
                        List<String> names = new ArrayList<>();
                        for (String k : new String[]{"name", "value"}) {
                            Object o = a.values.get(k);
                            if (o instanceof List) {
                                for (Object x : (List<?>) o) {
                                    names.add(String.valueOf(x));
                                }
                            }
                        }
                        if (names.isEmpty()) {
                            names.add(m.name);
                        }
                        for (String n : names) {
                            addBean(n, ClassModel.classOf(m.returnType()), "@Bean");
                        }
                    } else if (NAMED.contains(a.type)) {
                        String n = a.string("value");
                        if (n == null || n.isBlank()) {
                            n = m.name.startsWith("get") && m.name.length() > 3 ? ClassModel.decap(m.name.substring(3)) : m.name;
                        }
                        addBean(n, ClassModel.classOf(m.returnType()), "@Named");
                    }
                }
            }
        }
        // classes ainda nao compiladas: nomes pelo codigo-fonte
        Set<String> stereoSimple = new HashSet<>(Set.of("Component", "Service", "Controller", "Repository", "RestController",
                "Configuration", "Named", "ManagedBean"));
        for (String s : stereo) {
            String n = s.substring(s.lastIndexOf('/') + 1, s.length() - 1);
            stereoSimple.add(n.substring(n.lastIndexOf('$') + 1));
        }
        for (File src : javaSources) {
            scanSources(src, stereoSimple);
        }
        // beans que o proprio Spring registra (nao tem @Component em lugar nenhum)
        if (classes.get("org/springframework/context/ApplicationContext") != null || !beans.isEmpty()) {
            for (String n : new String[]{"environment", "systemProperties", "systemEnvironment", "messageSource",
                "applicationEventMulticaster", "lifecycleProcessor"}) {
                addBean(n, null, "spring");
            }
        }
        beansKnown = any[0] || !beans.isEmpty();

        // faces-config.xml: do projeto e de dentro dos jars
        List<byte[]> fcs = new ArrayList<>(classes.resources("META-INF/faces-config.xml"));
        for (File w : webroots) {
            File f = new File(w, "WEB-INF/faces-config.xml");
            if (f.isFile()) {
                try {
                    fcs.add(Files.readAllBytes(f.toPath()));
                } catch (IOException ex) {
                    // ignora
                }
            }
        }
        for (byte[] b : fcs) {
            Document d = xml(b);
            if (d == null) {
                continue;
            }
            for (String v : texts(d, "var")) {
                facesVars.add(v);
            }
            for (String v : texts(d, "managed-bean-name")) {
                addBean(v, null, "faces-config");
            }
            for (String v : texts(d, "from-outcome")) {
                navOutcomes.add(v);
            }
            for (String v : texts(d, "el-resolver")) {
                if (!v.contains("springframework") && !v.contains("primefaces") && !v.contains("omnifaces")) {
                    customElResolver = true;
                }
            }
            NodeList comps = d.getElementsByTagNameNS("*", "component");
            for (int i = 0; i < comps.getLength(); i++) {
                org.w3c.dom.Element c = (org.w3c.dom.Element) comps.item(i);
                String type = child(c, "component-type"), cls = child(c, "component-class");
                if (type != null && cls != null) {
                    componentClasses.put(type, cls.replace('.', '/'));
                }
            }
        }
        // taglibs dos jars: tag -> component-type (para os eventos de p:ajax)
        for (byte[] b : classes.resourcesMatching("META-INF", ".taglib.xml")) {
            Document d = xml(b);
            if (d == null) {
                continue;
            }
            String ns = texts(d, "namespace").stream().findFirst().orElse(null);
            if (ns == null) {
                continue;
            }
            Map<String, String> m = tagTypes.computeIfAbsent(ns.trim(), k -> new HashMap<>());
            NodeList tags = d.getElementsByTagNameNS("*", "tag");
            for (int i = 0; i < tags.getLength(); i++) {
                org.w3c.dom.Element t = (org.w3c.dom.Element) tags.item(i);
                String name = child(t, "tag-name");
                NodeList comp = t.getElementsByTagNameNS("*", "component");
                if (name != null && comp.getLength() > 0) {
                    String type = child((org.w3c.dom.Element) comp.item(0), "component-type");
                    if (type != null) {
                        m.put(name, type);
                    }
                }
            }
        }
        // taglibs do proprio projeto com tag files (source)
        tagFiles.clear();
        tagSources.clear();
        List<File> tlDirs = new ArrayList<>();
        for (File w : webroots) {
            tlDirs.add(new File(w, "WEB-INF"));
        }
        tlDirs.add(new File(projectDir, "src/main/resources/META-INF"));
        for (File dir : tlDirs) {
            if (!dir.isDirectory()) {
                continue;
            }
            try (var st = Files.walk(dir.toPath())) {
                for (var path : (Iterable<java.nio.file.Path>) st::iterator) {
                    if (!path.toString().endsWith(".taglib.xml")) {
                        continue;
                    }
                    Document d = xml(Files.readAllBytes(path));
                    if (d == null) {
                        continue;
                    }
                    String ns = texts(d, "namespace").stream().findFirst().orElse("");
                    NodeList tags = d.getElementsByTagNameNS("*", "tag");
                    for (int i = 0; i < tags.getLength(); i++) {
                        org.w3c.dom.Element t = (org.w3c.dom.Element) tags.item(i);
                        String src = child(t, "source"), name = child(t, "tag-name");
                        if (src == null) {
                            continue;
                        }
                        File f = new File(path.toFile().getParentFile(), src).getAbsoluteFile();
                        if (!f.isFile()) {
                            continue;
                        }
                        Set<String> attrs = new HashSet<>();
                        NodeList as = t.getElementsByTagNameNS("*", "attribute");
                        for (int k = 0; k < as.getLength(); k++) {
                            String an = child((org.w3c.dom.Element) as.item(k), "name");
                            if (an != null) {
                                attrs.add(an);
                            }
                        }
                        tagFiles.computeIfAbsent(f, x -> new HashSet<>()).addAll(attrs);
                        if (name != null) {
                            tagSources.computeIfAbsent(ns.trim(), x -> new HashMap<>()).put(name, f);
                        }
                    }
                }
            } catch (IOException | RuntimeException ex) {
                // ignora
            }
        }
        omnifaces = tagTypes.containsKey("http://omnifaces.org/ui") || classes.get("org/omnifaces/util/Faces") != null;

        // FACELETS_SKIP_COMMENTS: web.xml, properties do Spring Boot ou codigo Java
        skipComments = false;
        for (File w : webroots) {
            if (hasSkip(new File(w, "WEB-INF/web.xml"))) {
                skipComments = true;
            }
        }
        File res = new File(projectDir, "src/main/resources");
        if (res.isDirectory()) {
            File[] fs = res.listFiles((dd, n) -> n.startsWith("application") && (n.endsWith(".properties") || n.endsWith(".yml") || n.endsWith(".yaml")));
            if (fs != null) {
                for (File f : fs) {
                    if (hasSkip(f)) {
                        skipComments = true;
                    }
                }
            }
        }
        for (File src : javaSources) {
            if (!skipComments) {
                try (var s = Files.walk(src.toPath())) {
                    skipComments = s.filter(p -> p.toString().endsWith(".java")).anyMatch(p -> hasSkip(p.toFile()));
                } catch (IOException | RuntimeException ex) {
                    // ignora
                }
            }
        }
    }

    private static final Pattern SKIP = Pattern.compile("(?is)(SKIP_COMMENTS|skip-comments|skipComments)[\"'\\s,:=>/a-z-]*(<param-value>\\s*)?true");

    private static boolean hasSkip(File f) {
        if (!f.isFile()) {
            return false;
        }
        try {
            String s = Files.readString(f.toPath(), StandardCharsets.UTF_8);
            return SKIP.matcher(s).find();
        } catch (IOException | RuntimeException ex) {
            return false;
        }
    }

    private void addBean(String name, String type, String origin) {
        if (name == null || name.isBlank()) {
            return;
        }
        Bean b = beans.get(name);
        if (b == null || b.type == null && type != null) {
            b = new Bean();
            b.name = name;
            b.type = type;
            b.origin = origin;
            beans.put(name, b);
        }
    }

    private static final Pattern PKG = Pattern.compile("(?m)^\\s*package\\s+([\\w.]+)\\s*;");

    private void scanSources(File dir, Set<String> stereo) {
        String alt = String.join("|", stereo);
        Pattern p = Pattern.compile("@(?:[\\w.]+\\.)?(" + alt + ")\\b\\s*(\\(\\s*(?:(?:value|name)\\s*=\\s*)?\"([^\"]*)\"[^)]*\\)|\\([^)]*\\))?"
                + "(?:\\s*@[\\w.]+(?:\\([^)]*\\))?|\\s+(?:public|abstract|final|protected|private|static))*\\s*(?:class|record)\\s+(\\w+)");
        try (var s = Files.walk(dir.toPath())) {
            s.filter(f -> f.toString().endsWith(".java")).forEach(f -> {
                try {
                    String src = Files.readString(f, StandardCharsets.UTF_8);
                    Matcher m = p.matcher(src);
                    while (m.find()) {
                        String name = m.group(3);
                        String cls = m.group(4);
                        if (name == null || name.isBlank()) {
                            name = ClassModel.decap(cls);
                        }
                        Matcher pk = PKG.matcher(src);
                        String type = pk.find() ? pk.group(1).replace('.', '/') + "/" + cls : cls;
                        if (!beans.containsKey(name)) {
                            addBean(name, classes.get(type) != null ? type : null, "fonte");
                        }
                    }
                } catch (IOException | RuntimeException ex) {
                    // ignora
                }
            });
        } catch (IOException | RuntimeException ex) {
            // ignora
        }
    }

    static Document xml(byte[] b) {
        try {
            DocumentBuilderFactory f = DocumentBuilderFactory.newInstance();
            f.setNamespaceAware(true);
            f.setValidating(false);
            f.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
            f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", false);
            f.setExpandEntityReferences(false);
            return f.newDocumentBuilder().parse(new ByteArrayInputStream(b));
        } catch (Exception ex) {
            return null;
        }
    }

    static List<String> texts(Document d, String local) {
        List<String> r = new ArrayList<>();
        NodeList l = d.getElementsByTagNameNS("*", local);
        for (int i = 0; i < l.getLength(); i++) {
            String t = l.item(i).getTextContent();
            if (t != null && !t.isBlank()) {
                r.add(t.trim());
            }
        }
        return r;
    }

    static String child(org.w3c.dom.Element e, String local) {
        NodeList l = e.getElementsByTagNameNS("*", local);
        return l.getLength() == 0 ? null : l.item(0).getTextContent().trim();
    }

    // ---------- outros xhtml ----------

    public static final class Inc {
        public File from;
        public Xml.Element el;
        public String path;
        public File target;     // null: caminho nao existe (ou dinamico)
        public boolean dynamic;
        public String kind;     // include, template, decorate
    }

    public static final class FileFacts {
        public File file;
        public Xml.Doc doc;
        public long mtime;
        public final List<Inc> edges = new ArrayList<>();
        public final Set<String> inserts = new HashSet<>();
        public boolean unnamedInsert;
        public final Set<String> ids = new HashSet<>();
        public boolean dynamicIds;
        public final Set<String> widgetVars = new HashSet<>();
        public boolean dynamicWidgetVars;
        public boolean messages;
        public boolean composite;
        public boolean page; // tem <html>, f:view ou e cliente de template
        public final Set<String> usedNames = new HashSet<>();
        public final Set<String> bindings = new HashSet<>();
    }

    private final Map<File, FileFacts> facts = new ConcurrentHashMap<>();
    private final Map<File, String> overrides = new ConcurrentHashMap<>();
    private List<File> xhtmlList = new ArrayList<>();
    private long listedAt;

    /** texto do editor (ainda nao salvo) tem prioridade sobre o disco */
    public void override(File f, String text) {
        if (text == null) {
            overrides.remove(f);
        } else {
            overrides.put(f, text);
        }
        facts.remove(f);
    }

    public synchronized List<File> xhtmlFiles() {
        long now = System.currentTimeMillis();
        if (now - listedAt > 3000) {
            listedAt = now;
            List<File> l = new ArrayList<>();
            for (File w : webroots) {
                try (var s = Files.walk(w.toPath())) {
                    s.filter(p -> p.toString().endsWith(".xhtml")).forEach(p -> l.add(p.toFile().getAbsoluteFile()));
                } catch (IOException | RuntimeException ex) {
                    // ignora
                }
            }
            xhtmlList = l;
        }
        return xhtmlList;
    }

    public FileFacts facts(File f) {
        f = f.getAbsoluteFile();
        String over = overrides.get(f);
        long mt = over != null ? -1 : f.lastModified();
        FileFacts ff = facts.get(f);
        if (ff != null && ff.mtime == mt) {
            return ff;
        }
        String text = over;
        if (text == null) {
            try {
                text = Files.readString(f.toPath(), StandardCharsets.UTF_8);
            } catch (IOException ex) {
                return null;
            }
        }
        ff = compute(f, Xml.parse(text));
        ff.mtime = mt;
        facts.put(f, ff);
        return ff;
    }

    FileFacts compute(File f, Xml.Doc d) {
        FileFacts ff = new FileFacts();
        ff.file = f;
        ff.doc = d;
        for (Xml.Element e : d.all) {
            if (inRemove(e)) {
                continue;
            }
            String lib = Ns.lib(e.ns);
            if (lib.equals("ui")) {
                String attr = e.local.equals("include") ? "src" : (e.local.equals("composition") || e.local.equals("decorate")) ? "template" : null;
                if (attr != null && e.value(attr) != null) {
                    Inc in = new Inc();
                    in.from = f;
                    in.el = e;
                    in.path = e.value(attr).trim();
                    in.kind = e.local.equals("include") ? "include" : e.local;
                    in.dynamic = in.path.contains("#{") || in.path.contains("${");
                    if (!in.dynamic) {
                        in.target = resolve(f, in.path);
                    }
                    ff.edges.add(in);
                    if (!e.local.equals("include")) {
                        ff.page = true;
                    }
                }
                if (e.local.equals("insert")) {
                    String n = e.value("name");
                    if (n == null || n.isBlank()) {
                        ff.unnamedInsert = true;
                    } else {
                        ff.inserts.add(n.trim());
                    }
                }
            }
            if (lib.equals("cc") && (e.local.equals("interface") || e.local.equals("implementation"))) {
                ff.composite = true;
            }
            if (lib.equals("f") && e.local.equals("view") || lib.equals("html") && e.local.equals("html") || e.parent == d.root && e.local.equals("html")) {
                ff.page = true;
            }
            String id = e.value("id");
            if (id != null && Ns.isJsfTag(e)) {
                if (id.contains("#{") || id.contains("${")) {
                    ff.dynamicIds = true;
                } else {
                    ff.ids.add(id.trim());
                }
            }
            String wv = e.value("widgetVar");
            if (wv != null) {
                if (wv.contains("#{") || wv.contains("${")) {
                    ff.dynamicWidgetVars = true;
                } else {
                    ff.widgetVars.add(wv.trim());
                }
            }
            if ((lib.equals("h") || lib.equals("p") || lib.equals("o")) && (e.local.equals("messages") || e.local.equals("message") || e.local.equals("growl"))) {
                ff.messages = true;
            }
            for (Xml.Attr a : e.attrs) {
                for (El.Expr x : El.find(a.value, a.map)) {
                    for (El.Ref r : x.refs) {
                        ff.usedNames.add(r.name);
                        if (a.name.equals("binding") && r.chain.isEmpty() && x.whole) {
                            ff.bindings.add(r.name);
                        }
                    }
                }
            }
        }
        textRefs(d.root, ff.usedNames);
        return ff;
    }

    private static void textRefs(Xml.Element e, Set<String> out) {
        for (Xml.Node n : e.children) {
            if (n instanceof Xml.Text) {
                for (El.Expr x : El.find(((Xml.Text) n).raw, n.start)) {
                    for (El.Ref r : x.refs) {
                        out.add(r.name);
                    }
                }
            } else if (n instanceof Xml.Element && !inRemove((Xml.Element) n)) {
                textRefs((Xml.Element) n, out);
            }
        }
    }

    static boolean inRemove(Xml.Element e) {
        for (Xml.Element p = e; p != null; p = p.parent) {
            if ("remove".equals(p.local) && "ui".equals(Ns.lib(p.ns))) {
                return true;
            }
        }
        return false;
    }

    /** caminho de ui:include/template: "/..." a partir das pastas web, senao relativo ao arquivo */
    public File resolve(File from, String path) {
        String p = path;
        int q = p.indexOf('?');
        if (q >= 0) {
            p = p.substring(0, q);
        }
        if (p.startsWith("/")) {
            for (File w : webroots) {
                File f = new File(w, p.substring(1));
                if (f.isFile()) {
                    return f.getAbsoluteFile();
                }
            }
            return null;
        }
        File f = new File(from.getParentFile(), p);
        return f.isFile() ? f.getAbsoluteFile() : null;
    }

    public File webrootOf(File f) {
        for (File w : webroots) {
            if (f.getAbsolutePath().startsWith(w.getAbsolutePath() + File.separator)) {
                return w;
            }
        }
        return null;
    }

    /** quem inclui, usa como template ou decora este arquivo */
    public List<Inc> incoming(File f) {
        List<Inc> r = new ArrayList<>();
        File af = f.getAbsoluteFile();
        for (File x : xhtmlFiles()) {
            if (x.equals(af)) {
                continue;
            }
            FileFacts ff = facts(x);
            if (ff == null) {
                continue;
            }
            for (Inc in : ff.edges) {
                if (af.equals(in.target)) {
                    r.add(in);
                }
            }
        }
        return r;
    }

    public boolean anyDynamicInclude() {
        for (File x : xhtmlFiles()) {
            FileFacts ff = facts(x);
            if (ff != null) {
                for (Inc in : ff.edges) {
                    if (in.dynamic) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    /** arquivos que montam a mesma tela (o proprio, includes, templates, recursivo) */
    public Set<File> composed(File root) {
        Set<File> seen = new HashSet<>();
        List<File> todo = new ArrayList<>();
        todo.add(root.getAbsoluteFile());
        List<File> out = new ArrayList<>();
        while (!todo.isEmpty()) {
            File f = todo.remove(0);
            if (!seen.add(f)) {
                continue;
            }
            out.add(f);
            FileFacts ff = facts(f);
            if (ff == null) {
                continue;
            }
            for (Inc in : ff.edges) {
                if (in.target != null) {
                    todo.add(in.target);
                }
            }
        }
        return new HashSet<>(out);
    }

    /** telas (paginas de verdade) que acabam usando este arquivo */
    public Set<File> rootViews(File f) {
        Set<File> roots = new HashSet<>();
        Set<File> seen = new HashSet<>();
        List<File> todo = new ArrayList<>();
        todo.add(f.getAbsoluteFile());
        while (!todo.isEmpty()) {
            File x = todo.remove(0);
            if (!seen.add(x)) {
                continue;
            }
            List<Inc> inc = incoming(x);
            if (inc.isEmpty()) {
                roots.add(x);
            }
            for (Inc in : inc) {
                todo.add(in.from);
            }
        }
        return roots;
    }

    public Xml.Doc doc(File f) {
        FileFacts ff = facts(f);
        return ff == null ? null : ff.doc;
    }

    public File compositeFile(String uri, String tag) {
        String lib = Ns.compositeLibrary(uri);
        if (lib == null) {
            return null;
        }
        for (File w : webroots) {
            File c = new File(w, "resources/" + lib + "/" + tag + ".xhtml");
            if (c.isFile()) {
                return c.getAbsoluteFile();
            }
        }
        return null;
    }

    /** recurso (h:outputStylesheet etc.): resources/ da aplicacao ou META-INF/resources dos jars */
    public boolean resourceExists(String library, String name) {
        String rel = (library == null || library.isBlank() ? "" : library + "/") + name;
        for (File w : webroots) {
            if (new File(w, "resources/" + rel).exists()) {
                return true;
            }
        }
        if (classes.hasResource("META-INF/resources/" + rel)) {
            return true;
        }
        File res = new File(projectDir, "src/main/resources/META-INF/resources/" + rel);
        return res.exists();
    }
}
