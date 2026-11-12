package nbkit.jsf;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Consumer;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/**
 * Reads .class files directly (folders, jars and the JDK through jrt:/), without loading anything into the JVM.
 * Gives types, getters, setters, methods, enum constants and annotations.
 */
public final class ClassModel {

    public static final class Annotation {
        public String type; // descriptor, e.g. Lorg/springframework/stereotype/Component;
        public final Map<String, Object> values = new HashMap<>();

        public String string(String key) {
            Object o = values.get(key);
            if (o instanceof String) {
                return (String) o;
            }
            if (o instanceof List && !((List<?>) o).isEmpty() && ((List<?>) o).get(0) instanceof String) {
                return (String) ((List<?>) o).get(0);
            }
            return null;
        }
    }

    public static final class MethodInfo {
        public String name, desc, owner;
        public String signature; // generic form, e.g. ()Ljava/util/List<Lapp/Slide;>; (null when not generic)
        public int access;
        public final List<Annotation> annotations = new ArrayList<>();

        public int params() {
            return paramTypes().size();
        }

        public List<String> paramTypes() {
            List<String> r = new ArrayList<>();
            int i = 1;
            while (desc.charAt(i) != ')') {
                int s = i;
                while (desc.charAt(i) == '[') {
                    i++;
                }
                if (desc.charAt(i) == 'L') {
                    i = desc.indexOf(';', i);
                }
                i++;
                r.add(desc.substring(s, i));
            }
            return r;
        }

        public String returnType() {
            return desc.substring(desc.indexOf(')') + 1);
        }

        /** the return type with its type arguments when the class file has them */
        public String genericReturn() {
            return signature == null ? returnType() : signature.substring(signature.lastIndexOf(')') + 1);
        }

        public boolean isPublic() {
            return (access & 0x0001) != 0;
        }

        public boolean isStatic() {
            return (access & 0x0008) != 0;
        }
    }

    public static final class FieldInfo {
        public String name, desc;
        public int access;
    }

    public static final class ClassInfo {
        public String name, superName;
        public String signature; // generic form, e.g. <T:Ljava/lang/Object;>Ljava/util/ArrayList<TT;>; (null when not generic)
        public int access;
        public final List<String> interfaces = new ArrayList<>();
        public final List<MethodInfo> methods = new ArrayList<>();
        public final List<FieldInfo> fields = new ArrayList<>();
        public final List<Annotation> annotations = new ArrayList<>();

        public boolean isAnnotation() {
            return (access & 0x2000) != 0;
        }

        public boolean isEnum() {
            return (access & 0x4000) != 0;
        }

        public boolean isInterface() {
            return (access & 0x0200) != 0;
        }

        public String simpleName() {
            String s = name.substring(name.lastIndexOf('/') + 1);
            return s.substring(s.lastIndexOf('$') + 1);
        }

        public List<String> enumConstants() {
            List<String> r = new ArrayList<>();
            for (FieldInfo f : fields) {
                if ((f.access & 0x4000) != 0) {
                    r.add(f.name);
                }
            }
            return r;
        }
    }

    // ---------- reading ----------

    public static ClassInfo read(byte[] b, boolean withMembers) throws IOException {
        DataInputStream in = new DataInputStream(new ByteArrayInputStream(b));
        if (in.readInt() != 0xCAFEBABE) {
            throw new IOException("not a class file");
        }
        in.readUnsignedShort();
        in.readUnsignedShort();
        int n = in.readUnsignedShort();
        Object[] cp = new Object[n];
        int[] tags = new int[n];
        for (int i = 1; i < n; i++) {
            int tag = in.readUnsignedByte();
            tags[i] = tag;
            switch (tag) {
                case 1:
                    cp[i] = in.readUTF();
                    break;
                case 3:
                    cp[i] = in.readInt();
                    break;
                case 4:
                    cp[i] = in.readFloat();
                    break;
                case 5:
                    cp[i] = in.readLong();
                    i++;
                    break;
                case 6:
                    cp[i] = in.readDouble();
                    i++;
                    break;
                case 7:
                case 8:
                case 16:
                case 19:
                case 20:
                    cp[i] = in.readUnsignedShort();
                    break;
                case 15:
                    in.readUnsignedByte();
                    in.readUnsignedShort();
                    break;
                default:
                    in.readInt(); // 9,10,11,12,17,18
                    break;
            }
        }
        ClassInfo c = new ClassInfo();
        c.access = in.readUnsignedShort();
        c.name = utf(cp, (Integer) cp[in.readUnsignedShort()]);
        int sup = in.readUnsignedShort();
        c.superName = sup == 0 ? null : utf(cp, (Integer) cp[sup]);
        int ic = in.readUnsignedShort();
        for (int i = 0; i < ic; i++) {
            c.interfaces.add(utf(cp, (Integer) cp[in.readUnsignedShort()]));
        }
        int fc = in.readUnsignedShort();
        for (int i = 0; i < fc; i++) {
            FieldInfo f = new FieldInfo();
            f.access = in.readUnsignedShort();
            f.name = (String) cp[in.readUnsignedShort()];
            f.desc = (String) cp[in.readUnsignedShort()];
            skipAttrs(in, cp, null);
            if (withMembers || (f.access & 0x4000) != 0) {
                c.fields.add(f);
            }
        }
        int mc = in.readUnsignedShort();
        for (int i = 0; i < mc; i++) {
            MethodInfo m = new MethodInfo();
            m.access = in.readUnsignedShort();
            m.name = (String) cp[in.readUnsignedShort()];
            m.desc = (String) cp[in.readUnsignedShort()];
            m.signature = skipAttrs(in, cp, m.annotations);
            m.owner = c.name;
            if (withMembers || !m.annotations.isEmpty()) {
                c.methods.add(m);
            }
        }
        c.signature = skipAttrs(in, cp, c.annotations);
        return c;
    }

    private static String utf(Object[] cp, int idx) {
        return (String) cp[idx];
    }

    /** reads the annotations into out (when given) and skips the rest; returns the generic Signature, if any */
    private static String skipAttrs(DataInputStream in, Object[] cp, List<Annotation> out) throws IOException {
        String signature = null;
        int ac = in.readUnsignedShort();
        for (int i = 0; i < ac; i++) {
            String an = (String) cp[in.readUnsignedShort()];
            int len = in.readInt();
            if ("Signature".equals(an) && len == 2) {
                signature = (String) cp[in.readUnsignedShort()];
            } else if (out != null && "RuntimeVisibleAnnotations".equals(an)) {
                byte[] data = new byte[len];
                in.readFully(data);
                DataInputStream a = new DataInputStream(new ByteArrayInputStream(data));
                int na = a.readUnsignedShort();
                for (int k = 0; k < na; k++) {
                    out.add(annotation(a, cp));
                }
            } else {
                in.skipBytes(len);
            }
        }
        return signature;
    }

    private static Annotation annotation(DataInputStream a, Object[] cp) throws IOException {
        Annotation an = new Annotation();
        an.type = (String) cp[a.readUnsignedShort()];
        int pairs = a.readUnsignedShort();
        for (int i = 0; i < pairs; i++) {
            String k = (String) cp[a.readUnsignedShort()];
            an.values.put(k, elementValue(a, cp));
        }
        return an;
    }

    private static Object elementValue(DataInputStream a, Object[] cp) throws IOException {
        int tag = a.readUnsignedByte();
        switch (tag) {
            case 's':
                return cp[a.readUnsignedShort()];
            case 'e':
                a.readUnsignedShort();
                return cp[a.readUnsignedShort()];
            case 'c':
                return cp[a.readUnsignedShort()];
            case '@':
                return annotation(a, cp);
            case '[': {
                int n = a.readUnsignedShort();
                List<Object> l = new ArrayList<>();
                for (int i = 0; i < n; i++) {
                    l.add(elementValue(a, cp));
                }
                return l;
            }
            default:
                return cp[a.readUnsignedShort()];
        }
    }

    // ---------- classpath ----------

    private final List<File> roots;
    private final Map<String, ClassInfo> cache = new ConcurrentHashMap<>();
    private final Map<File, ZipFile> zips = new HashMap<>();
    private static FileSystem jrt;

    public ClassModel(List<File> roots) {
        this.roots = new ArrayList<>(roots);
    }

    public List<File> roots() {
        return Collections.unmodifiableList(roots);
    }

    /** internal name (a/b/C) */
    public synchronized ClassInfo get(String name) {
        if (name == null) {
            return null;
        }
        ClassInfo c = cache.get(name);
        if (c != null) {
            return c.name == null ? null : c;
        }
        byte[] b = bytes(name + ".class");
        ClassInfo r = null;
        if (b != null) {
            try {
                r = read(b, true);
            } catch (IOException | RuntimeException ex) {
                r = null;
            }
        }
        cache.put(name, r == null ? new ClassInfo() : r);
        return r;
    }

    private byte[] bytes(String path) {
        for (File root : roots) {
            try {
                if (root.isDirectory()) {
                    File f = new File(root, path);
                    if (f.isFile()) {
                        return Files.readAllBytes(f.toPath());
                    }
                } else if (root.isFile()) {
                    ZipFile z = zip(root);
                    ZipEntry e = z == null ? null : z.getEntry(path);
                    if (e != null) {
                        try (InputStream in = z.getInputStream(e)) {
                            return in.readAllBytes();
                        }
                    }
                }
            } catch (IOException ex) {
                // skip unreadable root
            }
        }
        try {
            if (jrt == null) {
                jrt = FileSystems.getFileSystem(URI.create("jrt:/"));
            }
            Path p = jrt.getPath("/packages", packageOf(path));
            if (Files.isDirectory(p)) {
                try (var mods = Files.list(p)) {
                    for (Path m : (Iterable<Path>) mods::iterator) {
                        Path f = m.resolve(path);
                        if (Files.isRegularFile(f)) {
                            return Files.readAllBytes(f);
                        }
                    }
                }
            }
        } catch (IOException | RuntimeException ex) {
            // no jrt
        }
        return null;
    }

    private static String packageOf(String path) {
        int i = path.lastIndexOf('/');
        return i < 0 ? "" : path.substring(0, i).replace('/', '.');
    }

    private ZipFile zip(File f) {
        return zips.computeIfAbsent(f, k -> {
            try {
                return new ZipFile(k);
            } catch (IOException ex) {
                return null;
            }
        });
    }

    public synchronized void clearCache() {
        cache.clear();
        membersCache.clear();
    }

    public synchronized void close() {
        for (ZipFile z : zips.values()) {
            try {
                if (z != null) {
                    z.close();
                }
            } catch (IOException ex) {
                // ignore
            }
        }
        zips.clear();
    }

    /** Walks all classes of the roots (without the JDK) */
    public void forEachClass(Consumer<byte[]> f) {
        for (File root : roots) {
            try {
                if (root.isDirectory()) {
                    try (var s = Files.walk(root.toPath())) {
                        s.filter(p -> p.toString().endsWith(".class")).forEach(p -> {
                            try {
                                f.accept(Files.readAllBytes(p));
                            } catch (IOException ex) {
                                // ignore
                            }
                        });
                    }
                } else if (root.isFile()) {
                    ZipFile z = zip(root);
                    if (z == null) {
                        continue;
                    }
                    Enumeration<? extends ZipEntry> en = z.entries();
                    while (en.hasMoreElements()) {
                        ZipEntry e = en.nextElement();
                        if (e.getName().endsWith(".class") && !e.getName().startsWith("META-INF/")) {
                            try (InputStream in = z.getInputStream(e)) {
                                f.accept(in.readAllBytes());
                            }
                        }
                    }
                }
            } catch (IOException ex) {
                // ignore
            }
        }
    }

    /** Reads any file inside the roots (e.g. META-INF/faces-config.xml of each jar) */
    public List<byte[]> resources(String path) {
        List<byte[]> r = new ArrayList<>();
        for (File root : roots) {
            try {
                if (root.isDirectory()) {
                    File f = new File(root, path);
                    if (f.isFile()) {
                        r.add(Files.readAllBytes(f.toPath()));
                    }
                } else if (root.isFile()) {
                    ZipFile z = zip(root);
                    ZipEntry e = z == null ? null : z.getEntry(path);
                    if (e != null) {
                        try (InputStream in = z.getInputStream(e)) {
                            r.add(in.readAllBytes());
                        }
                    }
                }
            } catch (IOException ex) {
                // ignore
            }
        }
        return r;
    }

    /** Files in META-INF (or another folder) whose name ends with the suffix, in all roots */
    public List<byte[]> resourcesMatching(String folder, String suffix) {
        List<byte[]> r = new ArrayList<>();
        for (File root : roots) {
            try {
                if (root.isDirectory()) {
                    File[] fs = new File(root, folder).listFiles((d, n) -> n.endsWith(suffix));
                    if (fs != null) {
                        for (File f : fs) {
                            r.add(Files.readAllBytes(f.toPath()));
                        }
                    }
                } else if (root.isFile()) {
                    ZipFile z = zip(root);
                    if (z == null) {
                        continue;
                    }
                    Enumeration<? extends ZipEntry> en = z.entries();
                    while (en.hasMoreElements()) {
                        ZipEntry e = en.nextElement();
                        String n = e.getName();
                        if (n.startsWith(folder + "/") && n.indexOf('/', folder.length() + 1) < 0 && n.endsWith(suffix)) {
                            try (InputStream in = z.getInputStream(e)) {
                                r.add(in.readAllBytes());
                            }
                        }
                    }
                }
            } catch (IOException ex) {
                // ignore
            }
        }
        return r;
    }

    public boolean hasResource(String path) {
        for (File root : roots) {
            if (root.isDirectory()) {
                if (new File(root, path).exists()) {
                    return true;
                }
            } else if (root.isFile()) {
                ZipFile z = zip(root);
                if (z != null && z.getEntry(path) != null) {
                    return true;
                }
            }
        }
        return false;
    }

    // ---------- members ----------

    /** All supertypes (including itself), in order. */
    public List<ClassInfo> hierarchy(String name) {
        List<ClassInfo> r = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        List<String> todo = new ArrayList<>();
        todo.add(name);
        while (!todo.isEmpty()) {
            String n = todo.remove(0);
            if (n == null || !seen.add(n)) {
                continue;
            }
            ClassInfo c = get(n);
            if (c == null) {
                continue;
            }
            r.add(c);
            todo.add(c.superName);
            todo.addAll(c.interfaces);
        }
        if (!seen.contains("java/lang/Object")) {
            ClassInfo o = get("java/lang/Object");
            if (o != null) {
                r.add(o);
            }
        }
        return r;
    }

    /** was the whole hierarchy read? (without it there is no way to state that a member does not exist) */
    public boolean complete(String name) {
        Set<String> seen = new HashSet<>();
        List<String> todo = new ArrayList<>();
        todo.add(name);
        while (!todo.isEmpty()) {
            String n = todo.remove(0);
            if (n == null || !seen.add(n)) {
                continue;
            }
            ClassInfo c = get(n);
            if (c == null) {
                return false;
            }
            todo.add(c.superName);
            todo.addAll(c.interfaces);
        }
        return true;
    }

    public boolean isA(String name, String target) {
        for (ClassInfo c : hierarchy(name)) {
            if (c.name.equals(target)) {
                return true;
            }
        }
        return false;
    }

    /** JavaBeans style properties + public methods, merging the hierarchy. */
    public static final class Members {
        public final Map<String, String> getters = new LinkedHashMap<>(); // property -> type descriptor
        public final Map<String, MethodInfo> getterMethods = new HashMap<>(); // property -> its get method
        public final Set<String> setters = new HashSet<>();
        public final Map<String, List<MethodInfo>> methods = new HashMap<>();
    }

    private final Map<String, Members> membersCache = new ConcurrentHashMap<>();

    public Members members(String name) {
        return membersCache.computeIfAbsent(name, k -> {
            Members m = new Members();
            for (ClassInfo c : hierarchy(k)) {
                for (MethodInfo mi : c.methods) {
                    if (!mi.isPublic() || mi.isStatic() || mi.name.startsWith("<")) {
                        continue;
                    }
                    m.methods.computeIfAbsent(mi.name, x -> new ArrayList<>()).add(mi);
                    int pc = mi.params();
                    String rt = mi.returnType();
                    if (pc == 0 && mi.name.startsWith("get") && mi.name.length() > 3 && !rt.equals("V")) {
                        m.getters.putIfAbsent(decap(mi.name.substring(3)), rt);
                        m.getterMethods.putIfAbsent(decap(mi.name.substring(3)), mi);
                    } else if (pc == 0 && mi.name.startsWith("is") && mi.name.length() > 2 && (rt.equals("Z") || rt.equals("Ljava/lang/Boolean;"))) {
                        m.getters.putIfAbsent(decap(mi.name.substring(2)), rt);
                    } else if (pc == 1 && mi.name.startsWith("set") && mi.name.length() > 3) {
                        m.setters.add(decap(mi.name.substring(3)));
                    }
                }
            }
            return m;
        });
    }

    /** same rule as java.beans.Introspector */
    public static String decap(String s) {
        if (s.isEmpty()) {
            return s;
        }
        if (s.length() > 1 && Character.isUpperCase(s.charAt(0)) && Character.isUpperCase(s.charAt(1))) {
            return s;
        }
        return Character.toLowerCase(s.charAt(0)) + s.substring(1);
    }

    /**
     * The type of the items of a collection: the element of an array, or what an Iterable (List, Set, JSF DataModel,
     * PrimeFaces LazyDataModel, a subclass of one...) holds, following the type arguments through superclasses and
     * interfaces. Null when unknown (a type variable, a raw type, ? super).
     */
    public String elementOf(String generic) {
        return erase(elementGeneric(generic));
    }

    /** like elementOf, keeping the type arguments of the item (Frame<T> stays Frame<T>) */
    public String elementGeneric(String generic) {
        if (generic == null) {
            return null;
        }
        if (generic.startsWith("[")) {
            return generic.substring(1);
        }
        List<String> it = argsAs(generic, "java/lang/Iterable", new HashSet<>());
        return it == null || it.size() != 1 ? null : it.get(0).startsWith("+") ? it.get(0).substring(1) : it.get(0);
    }

    /**
     * The type m returns when called on t (a type with its type arguments, e.g. Lapp/OrderManager;): the type
     * variables of the class that declares m are replaced by what t gives them through its supertypes
     * (OrderManager extends BaseManager<Integer, Order, OrderPagination>: P is OrderPagination). Unknown ones stay.
     */
    public String resolve(String t, MethodInfo m) {
        String declared = m.genericReturn();
        ClassInfo c = get(m.owner);
        Map<String, String> bind = new HashMap<>();
        if (t != null && c != null && c.signature != null && c.signature.startsWith("<")) {
            List<String> params = new ArrayList<>();
            typeParams(c.signature, params);
            List<String> args = argsAs(t, m.owner, new HashSet<>());
            if (args != null && args.size() == params.size()) {
                for (int k = 0; k < params.size(); k++) {
                    bind.put(params.get(k), args.get(k));
                }
            }
        }
        if (m.signature != null && m.signature.startsWith("<")) {
            List<String> own = new ArrayList<>();
            typeParams(m.signature, own);
            own.forEach(bind::remove); // <T> T get(): the method's own T, not the class's
        }
        StringBuilder out = new StringBuilder();
        substitute(declared, 0, bind, out);
        return out.toString();
    }

    /** the type arguments of target that the parameterized type t gives it, following its supertypes; null if not one */
    private List<String> argsAs(String t, String target, Set<String> seen) {
        List<String> args = typeArgs(t);
        if (args == null) {
            return null;
        }
        String name = t.substring(1, t.indexOf(args.isEmpty() ? ';' : '<'));
        if (name.equals(target)) {
            return args;
        }
        ClassInfo c = seen.add(name) ? get(name) : null;
        if (c == null || c.signature == null) {
            return null; // not generic: its supertypes are raw, so nothing to give
        }
        String sig = c.signature;
        Map<String, String> bind = new HashMap<>();
        List<String> params = new ArrayList<>();
        int i = typeParams(sig, params);
        if (params.size() == args.size()) {
            for (int k = 0; k < params.size(); k++) {
                bind.put(params.get(k), args.get(k));
            }
        }
        while (i < sig.length()) {
            StringBuilder sup = new StringBuilder();
            i = substitute(sig, i, bind, sup);
            List<String> r = argsAs(sup.toString(), target, seen);
            if (r != null) {
                return r;
            }
        }
        return null;
    }

    /** reads the <T:...;U:...> at the start of a class or method signature into out; returns the index after it */
    private static int typeParams(String sig, List<String> out) {
        if (sig.charAt(0) != '<') {
            return 0;
        }
        int i = 1;
        while (sig.charAt(i) != '>') {
            int colon = sig.indexOf(':', i);
            out.add(sig.substring(i, colon));
            for (i = colon; sig.charAt(i) == ':';) {
                char b = sig.charAt(++i);
                if (b == 'L' || b == 'T' || b == '[') {
                    i = typeEnd(sig, i);
                }
            }
        }
        return i + 1;
    }

    /** type arguments of Lname<...>; (empty when raw), null for anything else (type variable, array, inner class) */
    private static List<String> typeArgs(String t) {
        if (t == null || !t.startsWith("L")) {
            return null;
        }
        int lt = t.indexOf('<'), semi = t.indexOf(';');
        if (lt < 0 || semi < lt) {
            return t.indexOf('.') < 0 ? List.of() : null;
        }
        List<String> r = new ArrayList<>();
        int i = lt + 1;
        while (t.charAt(i) != '>') {
            int e = typeEnd(t, i);
            r.add(t.substring(i, e));
            i = e;
        }
        return t.charAt(i + 1) == ';' ? r : null;
    }

    /** index just after the type signature starting at i */
    private static int typeEnd(String s, int i) {
        switch (s.charAt(i)) {
            case '+': case '-': case '[':
                return typeEnd(s, i + 1);
            case 'T':
                return s.indexOf(';', i) + 1;
            case 'L':
                for (int depth = 0, k = i + 1;; k++) {
                    char c = s.charAt(k);
                    if (c == '<') {
                        depth++;
                    } else if (c == '>') {
                        depth--;
                    } else if (c == ';' && depth == 0) {
                        return k + 1;
                    }
                }
            default:
                return i + 1; // primitive or *
        }
    }

    /** copies the type signature at i into out with type variables replaced; returns the index after it */
    private static int substitute(String s, int i, Map<String, String> bind, StringBuilder out) {
        char c = s.charAt(i);
        if (c == '+' || c == '-' || c == '[') {
            out.append(c);
            return substitute(s, i + 1, bind, out);
        }
        if (c == 'T') {
            int e = s.indexOf(';', i) + 1;
            out.append(bind.getOrDefault(s.substring(i + 1, e - 1), s.substring(i, e)));
            return e;
        }
        if (c != 'L') {
            out.append(c);
            return i + 1;
        }
        int from = i;
        for (int k = i + 1;; k++) {
            char d = s.charAt(k);
            if (d == '<') {
                out.append(s, from, k + 1);
                for (k++; s.charAt(k) != '>';) {
                    k = substitute(s, k, bind, out);
                }
                from = k;
            } else if (d == ';') {
                out.append(s, from, k + 1);
                return k + 1;
            }
        }
    }

    /** class of a type argument: ? extends X is still an X; a type variable, ? super, * or an array give null */
    public static String erase(String t) {
        if (t != null && t.startsWith("+")) {
            t = t.substring(1);
        }
        List<String> args = typeArgs(t);
        return args == null ? null : t.substring(1, t.indexOf(args.isEmpty() ? ';' : '<'));
    }

    /** descriptor -> internal name (or null for primitives/arrays) */
    public static String classOf(String desc) {
        if (desc != null && desc.startsWith("L") && desc.endsWith(";")) {
            return desc.substring(1, desc.length() - 1);
        }
        return null;
    }

    public static String display(String internal) {
        if (internal == null) {
            return "?";
        }
        String s = internal.substring(internal.lastIndexOf('/') + 1);
        return s.replace('$', '.');
    }
}
