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
 * Le arquivos .class direto (pastas, jars e o JDK pelo jrt:/), sem carregar nada na JVM.
 * Da tipos, getters, setters, metodos, constantes de enum e anotacoes.
 */
public final class ClassModel {

    public static final class Annotation {
        public String type; // descritor, ex: Lorg/springframework/stereotype/Component;
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
        public String name, desc;
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

    // ---------- leitura ----------

    public static ClassInfo read(byte[] b, boolean withMembers) throws IOException {
        DataInputStream in = new DataInputStream(new ByteArrayInputStream(b));
        if (in.readInt() != 0xCAFEBABE) {
            throw new IOException("nao e class");
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
            skipAttrs(in, cp, m.annotations);
            if (withMembers || !m.annotations.isEmpty()) {
                c.methods.add(m);
            }
        }
        skipAttrs(in, cp, c.annotations);
        return c;
    }

    private static String utf(Object[] cp, int idx) {
        return (String) cp[idx];
    }

    private static void skipAttrs(DataInputStream in, Object[] cp, List<Annotation> out) throws IOException {
        int ac = in.readUnsignedShort();
        for (int i = 0; i < ac; i++) {
            String an = (String) cp[in.readUnsignedShort()];
            int len = in.readInt();
            if (out != null && "RuntimeVisibleAnnotations".equals(an)) {
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

    /** nome interno (a/b/C) */
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
                // ignora raiz ilegivel
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
            // sem jrt
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
                // ignora
            }
        }
        zips.clear();
    }

    /** Percorre todas as classes das raizes (sem o JDK) */
    public void forEachClass(Consumer<byte[]> f) {
        for (File root : roots) {
            try {
                if (root.isDirectory()) {
                    try (var s = Files.walk(root.toPath())) {
                        s.filter(p -> p.toString().endsWith(".class")).forEach(p -> {
                            try {
                                f.accept(Files.readAllBytes(p));
                            } catch (IOException ex) {
                                // ignora
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
                // ignora
            }
        }
    }

    /** Le um arquivo qualquer de dentro das raizes (ex: META-INF/faces-config.xml de cada jar) */
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
                // ignora
            }
        }
        return r;
    }

    /** Arquivos de META-INF (ou outra pasta) cujo nome termina com o sufixo, em todas as raizes */
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
                // ignora
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

    // ---------- membros ----------

    /** Todos os supertipos (inclui o proprio), em ordem. */
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

    /** a hierarquia foi lida inteira? (sem isso nao da pra afirmar que um membro nao existe) */
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

    /** Propriedades no estilo JavaBeans + metodos publicos, juntando a hierarquia. */
    public static final class Members {
        public final Map<String, String> getters = new LinkedHashMap<>(); // propriedade -> descritor do tipo
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

    /** mesma regra do java.beans.Introspector */
    public static String decap(String s) {
        if (s.isEmpty()) {
            return s;
        }
        if (s.length() > 1 && Character.isUpperCase(s.charAt(0)) && Character.isUpperCase(s.charAt(1))) {
            return s;
        }
        return Character.toLowerCase(s.charAt(0)) + s.substring(1);
    }

    /** descritor -> nome interno (ou null para primitivos/arrays) */
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
