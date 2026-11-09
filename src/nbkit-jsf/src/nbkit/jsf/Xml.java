package nbkit.jsf;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Tolerant xhtml (Facelets) parser. Keeps offsets of everything to mark errors in the editor.
 * Does not validate XML: files broken while typing still become a usable tree.
 */
public final class Xml {

    public static abstract class Node {
        public Element parent;
        public int start, end;
    }

    public static final class Text extends Node {
        public String raw;
    }

    public static final class Comment extends Node {
        public int contentStart;
        public String content;
    }

    public static final class Attr {
        public String name;
        /** value with XML entities decoded */
        public String value;
        /** document offset of each character of value (size value.length() + 1) */
        public int[] map;
        public int nameStart, valueStart, valueEnd;
        public Element owner;

        public int offset(int i) {
            return map[Math.max(0, Math.min(i, map.length - 1))];
        }
    }

    public static final class Element extends Node {
        public String name, prefix, local;
        /** namespace of the prefix (or of jsfc), resolved by the xmlns in scope */
        public String ns;
        public final List<Attr> attrs = new ArrayList<>();
        public final List<Node> children = new ArrayList<>();
        public final Map<String, String> xmlns = new HashMap<>();
        public int startTagEnd;
        public boolean selfClosing, closed;
        public int nameEnd;

        public Attr attr(String n) {
            for (Attr a : attrs) {
                if (a.name.equals(n)) {
                    return a;
                }
            }
            return null;
        }

        public String value(String n) {
            Attr a = attr(n);
            return a == null ? null : a.value;
        }

        public boolean is(String lib, String... locals) {
            if (!lib.equals(Ns.lib(ns))) {
                return false;
            }
            for (String l : locals) {
                if (l.equals(local)) {
                    return true;
                }
            }
            return false;
        }

        public String nsFor(String pfx) {
            for (Element e = this; e != null; e = e.parent) {
                String u = e.xmlns.get(pfx);
                if (u != null) {
                    return u;
                }
            }
            return null;
        }

        public List<Element> elements() {
            List<Element> r = new ArrayList<>();
            for (Node n : children) {
                if (n instanceof Element) {
                    r.add((Element) n);
                }
            }
            return r;
        }
    }

    public static final class Entity {
        public String name;
        public int start, end;
    }

    public static final class Doc {
        public final String text;
        public final Element root = new Element();
        public final List<Comment> comments = new ArrayList<>();
        public final List<Entity> entities = new ArrayList<>();
        public final List<Element> all = new ArrayList<>();
        public String doctype;
        private int[] lineStarts;

        Doc(String text) {
            this.text = text;
            root.name = root.local = "#root";
            root.prefix = "";
            root.start = 0;
            root.end = text.length();
            root.closed = true;
        }

        public int line(int offset) {
            if (lineStarts == null) {
                List<Integer> l = new ArrayList<>();
                l.add(0);
                for (int i = 0; i < text.length(); i++) {
                    if (text.charAt(i) == '\n') {
                        l.add(i + 1);
                    }
                }
                lineStarts = l.stream().mapToInt(Integer::intValue).toArray();
            }
            int lo = 0, hi = lineStarts.length - 1;
            while (lo < hi) {
                int mid = (lo + hi + 1) / 2;
                if (lineStarts[mid] <= offset) {
                    lo = mid;
                } else {
                    hi = mid - 1;
                }
            }
            return lo + 1;
        }
    }

    public static Doc parse(String s) {
        Doc d = new Doc(s);
        Element cur = d.root;
        int i = 0, n = s.length();
        int textStart = 0;
        while (i < n) {
            char c = s.charAt(i);
            if (c != '<') {
                if (c == '&') {
                    entity(d, s, i);
                }
                i++;
                continue;
            }
            // text accumulated before the tag
            if (i > textStart) {
                addText(cur, s, textStart, i);
            }
            if (s.startsWith("<!--", i)) {
                int e = s.indexOf("-->", i + 4);
                int stop = e < 0 ? n : e + 3;
                Comment cm = new Comment();
                cm.start = i;
                cm.end = stop;
                cm.contentStart = i + 4;
                cm.content = s.substring(i + 4, e < 0 ? n : e);
                cm.parent = cur;
                cur.children.add(cm);
                d.comments.add(cm);
                i = stop;
            } else if (s.startsWith("<![CDATA[", i)) {
                int e = s.indexOf("]]>", i);
                int stop = e < 0 ? n : e + 3;
                Text t = new Text();
                t.start = i + 9;
                t.end = e < 0 ? n : e;
                t.raw = s.substring(t.start, t.end);
                t.parent = cur;
                cur.children.add(t);
                i = stop;
            } else if (s.startsWith("<!", i)) {
                int e = findTagEnd(s, i + 2);
                if (s.regionMatches(true, i, "<!DOCTYPE", 0, 9)) {
                    d.doctype = s.substring(i, Math.min(n, e + 1));
                }
                i = e < 0 ? n : e + 1;
            } else if (s.startsWith("<?", i)) {
                int e = s.indexOf("?>", i);
                i = e < 0 ? n : e + 2;
            } else if (i + 1 < n && s.charAt(i + 1) == '/') {
                int j = i + 2;
                int ns = j;
                while (j < n && isNameChar(s.charAt(j))) {
                    j++;
                }
                String name = s.substring(ns, j);
                int e = s.indexOf('>', j);
                int stop = e < 0 ? n : e + 1;
                // close until the matching opening is found (tolerant)
                Element m = cur;
                while (m != d.root && !m.name.equals(name)) {
                    m = m.parent;
                }
                if (m != d.root) {
                    for (Element x = cur; x != m; x = x.parent) {
                        x.end = i;
                    }
                    m.end = stop;
                    m.closed = true;
                    cur = m.parent;
                }
                i = stop;
            } else if (i + 1 < n && isNameStart(s.charAt(i + 1))) {
                Element el = new Element();
                el.start = i;
                int j = i + 1;
                while (j < n && isNameChar(s.charAt(j))) {
                    j++;
                }
                el.name = s.substring(i + 1, j);
                el.nameEnd = j;
                int colon = el.name.indexOf(':');
                el.prefix = colon < 0 ? "" : el.name.substring(0, colon);
                el.local = colon < 0 ? el.name : el.name.substring(colon + 1);
                // attributes
                while (j < n) {
                    while (j < n && Character.isWhitespace(s.charAt(j))) {
                        j++;
                    }
                    if (j >= n) {
                        break;
                    }
                    char ch = s.charAt(j);
                    if (ch == '>') {
                        j++;
                        break;
                    }
                    if (ch == '/' && j + 1 < n && s.charAt(j + 1) == '>') {
                        el.selfClosing = true;
                        j += 2;
                        break;
                    }
                    if (ch == '<') {
                        break; // unclosed tag: let the next tag be read
                    }
                    if (!isNameChar(ch)) {
                        j++;
                        continue;
                    }
                    Attr a = new Attr();
                    a.owner = el;
                    a.nameStart = j;
                    while (j < n && isNameChar(s.charAt(j))) {
                        j++;
                    }
                    a.name = s.substring(a.nameStart, j);
                    while (j < n && Character.isWhitespace(s.charAt(j))) {
                        j++;
                    }
                    if (j < n && s.charAt(j) == '=') {
                        j++;
                        while (j < n && Character.isWhitespace(s.charAt(j))) {
                            j++;
                        }
                        if (j < n && (s.charAt(j) == '"' || s.charAt(j) == '\'')) {
                            char q = s.charAt(j);
                            int vs = j + 1;
                            int ve = s.indexOf(q, vs);
                            if (ve < 0) {
                                ve = n;
                            }
                            decode(d, s, vs, ve, a);
                            j = Math.min(n, ve + 1);
                        } else {
                            int vs = j;
                            while (j < n && !Character.isWhitespace(s.charAt(j)) && s.charAt(j) != '>') {
                                j++;
                            }
                            decode(d, s, vs, j, a);
                        }
                    } else {
                        decode(d, s, j, j, a);
                    }
                    el.attrs.add(a);
                    if (a.name.equals("xmlns")) {
                        el.xmlns.put("", a.value);
                    } else if (a.name.startsWith("xmlns:")) {
                        el.xmlns.put(a.name.substring(6), a.value);
                    }
                }
                el.startTagEnd = j;
                el.parent = cur;
                cur.children.add(el);
                d.all.add(el);
                String jsfc = el.value("jsfc");
                if (jsfc != null && jsfc.indexOf(':') > 0) {
                    String p = jsfc.substring(0, jsfc.indexOf(':'));
                    el.ns = el.nsFor(p);
                    el.local = jsfc.substring(jsfc.indexOf(':') + 1);
                } else {
                    el.ns = el.nsFor(el.prefix);
                }
                if (el.selfClosing) {
                    el.end = j;
                    el.closed = true;
                } else {
                    el.end = n;
                    cur = el;
                }
                i = j;
            } else {
                i++;
                continue;
            }
            textStart = i;
        }
        if (n > textStart) {
            addText(cur, s, textStart, n);
        }
        return d;
    }

    private static void addText(Element cur, String s, int a, int b) {
        Text t = new Text();
        t.start = a;
        t.end = b;
        t.raw = s.substring(a, b);
        t.parent = cur;
        cur.children.add(t);
    }

    private static int findTagEnd(String s, int from) {
        int depth = 0;
        for (int i = from; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '[') {
                depth++;
            } else if (c == ']') {
                depth--;
            } else if (c == '>' && depth <= 0) {
                return i;
            }
        }
        return -1;
    }

    private static void entity(Doc d, String s, int i) {
        int j = i + 1;
        while (j < s.length() && j - i < 40 && (Character.isLetterOrDigit(s.charAt(j)) || s.charAt(j) == '#')) {
            j++;
        }
        if (j < s.length() && s.charAt(j) == ';' && j > i + 1) {
            Entity e = new Entity();
            e.name = s.substring(i + 1, j);
            e.start = i;
            e.end = j + 1;
            d.entities.add(e);
        }
    }

    static final Map<String, String> XML_ENTITIES = Map.of("amp", "&", "lt", "<", "gt", ">", "quot", "\"", "apos", "'");

    private static void decode(Doc d, String s, int a, int b, Attr at) {
        StringBuilder v = new StringBuilder();
        int[] map = new int[b - a + 1];
        int k = 0;
        for (int i = a; i < b; ) {
            char c = s.charAt(i);
            if (c == '&') {
                int semi = s.indexOf(';', i);
                if (semi > i && semi < b && semi - i < 12) {
                    String name = s.substring(i + 1, semi);
                    String rep = XML_ENTITIES.get(name);
                    if (rep == null && name.startsWith("#")) {
                        try {
                            int cp = name.startsWith("#x") ? Integer.parseInt(name.substring(2), 16) : Integer.parseInt(name.substring(1));
                            rep = new String(Character.toChars(cp));
                        } catch (RuntimeException ex) {
                            rep = null;
                        }
                    }
                    if (rep == null) {
                        entity(d, s, i);
                    }
                    if (rep != null) {
                        for (int r = 0; r < rep.length(); r++) {
                            map[k++] = i;
                            v.append(rep.charAt(r));
                        }
                        i = semi + 1;
                        continue;
                    }
                }
            }
            map[k++] = i;
            v.append(c);
            i++;
        }
        map[k] = b;
        at.value = v.toString();
        int[] m2 = new int[k + 1];
        System.arraycopy(map, 0, m2, 0, k + 1);
        at.map = m2;
        at.valueStart = a;
        at.valueEnd = b;
    }

    static boolean isNameStart(char c) {
        return Character.isLetter(c) || c == '_' || c == ':';
    }

    static boolean isNameChar(char c) {
        return Character.isLetterOrDigit(c) || c == '_' || c == ':' || c == '-' || c == '.';
    }
}
