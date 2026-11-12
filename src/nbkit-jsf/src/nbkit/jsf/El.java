package nbkit.jsf;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Extracts and analyzes EL expressions (#{...} and ${...}) without depending on libraries. */
public final class El {

    private El() {
    }

    public static final Set<String> KEYWORDS = Set.of("and", "or", "not", "eq", "ne", "lt", "gt", "le", "ge",
            "div", "mod", "empty", "instanceof", "true", "false", "null");

    /** An expression inside a text: absolute offsets in the document. */
    public static final class Expr {
        public String text;          // content between the braces
        public boolean deferred;     // #{ } (true) or ${ } (false)
        public int start, end;       // from the '#' to after the '}'
        public int[] map;            // document offset of each char of text
        public boolean whole;        // the expression takes the whole value (no text around it)
        public List<Tok> toks;
        public List<Ref> refs;
        /** string literals with a chain after them: 'abc'.concat(x) (their root is a String) */
        public List<Ref> literals;
        public List<Lambda> lambdas;

        public int off(int i) {
            return map[Math.max(0, Math.min(i, map.length - 1))];
        }
    }

    public enum T { ID, NUM, STR, OP, END }

    public static final class Tok {
        public T t;
        public String s;   // text (for STR, the content without quotes)
        public int a, b;   // position inside Expr.text
        public boolean spaceBefore;

        @Override
        public String toString() {
            return t + ":" + s;
        }
    }

    /** Member of a chain: .name, .name(...) or ['name'] */
    public static final class Member {
        public String name;      // null when the index is dynamic
        public boolean call;
        public int argCount;
        public int a, b;         // position of the name in Expr.text
    }

    /** Reference to a root name (variable, bean, implicit object) and the chain after it. */
    public static final class Ref {
        public String name;
        public int a, b;
        public final List<Member> chain = new ArrayList<>();
        public boolean assigned;
        /** the whole chain is just name.prop.prop (no call, operator or dynamic index) and it is the only content */
        public boolean pureLvalue;
        public int tokIndex, tokEnd;
        /** inside the arguments or brackets of another reference: bean.m(this) or list[this] */
        public boolean nested;
        /** a literal ('abc'.concat(x), [1, 2].stream(), {1, 2}.size()): name is how it reads */
        public boolean literal;
        /** the class of a collection literal: java/util/List, java/util/Set or java/util/Map (null for a string) */
        public String literalType;
    }

    public static final class Lambda {
        public final List<Tok> params = new ArrayList<>();
        public final Set<String> used = new HashSet<>();
    }

    /** Finds the expressions in an already decoded value, with the offset map. */
    public static List<Expr> find(String v, int[] map) {
        List<Expr> r = new ArrayList<>();
        int n = v.length();
        for (int i = 0; i < n - 1; i++) {
            char c = v.charAt(i);
            if ((c == '#' || c == '$') && v.charAt(i + 1) == '{') {
                if (i > 0 && v.charAt(i - 1) == '\\') {
                    continue;
                }
                int j = i + 2, depth = 1;
                char q = 0;
                while (j < n && depth > 0) {
                    char d = v.charAt(j);
                    if (q != 0) {
                        if (d == '\\') {
                            j++;
                        } else if (d == q) {
                            q = 0;
                        }
                    } else if (d == '\'' || d == '"') {
                        q = d;
                    } else if (d == '{') {
                        depth++;
                    } else if (d == '}') {
                        depth--;
                    }
                    j++;
                }
                if (depth != 0) {
                    break; // not closed: NetBeans already reports the syntax
                }
                Expr e = new Expr();
                e.deferred = c == '#';
                e.text = v.substring(i + 2, j - 1);
                e.start = map[i];
                e.end = map[Math.min(j, map.length - 1)];
                e.map = new int[e.text.length() + 1];
                for (int k = 0; k <= e.text.length(); k++) {
                    e.map[k] = map[Math.min(i + 2 + k, map.length - 1)];
                }
                e.whole = v.substring(0, i).isBlank() && v.substring(j).isBlank();
                analyze(e);
                r.add(e);
                i = j - 1;
            }
        }
        return r;
    }

    public static List<Expr> find(String v, int base) {
        int[] m = new int[v.length() + 1];
        for (int i = 0; i <= v.length(); i++) {
            m[i] = base + i;
        }
        return find(v, m);
    }

    static List<Tok> lex(String s) {
        List<Tok> r = new ArrayList<>();
        int n = s.length();
        int i = 0;
        boolean sp = false;
        while (i < n) {
            char c = s.charAt(i);
            if (Character.isWhitespace(c)) {
                sp = true;
                i++;
                continue;
            }
            Tok t = new Tok();
            t.a = i;
            t.spaceBefore = sp;
            sp = false;
            if (Character.isJavaIdentifierStart(c)) {
                int j = i + 1;
                while (j < n && Character.isJavaIdentifierPart(s.charAt(j))) {
                    j++;
                }
                t.t = T.ID;
                t.s = s.substring(i, j);
                i = j;
            } else if (Character.isDigit(c) || c == '.' && i + 1 < n && Character.isDigit(s.charAt(i + 1))) {
                int j = i + 1;
                while (j < n && (Character.isLetterOrDigit(s.charAt(j)) || s.charAt(j) == '.')) {
                    j++;
                }
                t.t = T.NUM;
                t.s = s.substring(i, j);
                i = j;
            } else if (c == '\'' || c == '"') {
                StringBuilder b = new StringBuilder();
                int j = i + 1;
                while (j < n && s.charAt(j) != c) {
                    if (s.charAt(j) == '\\' && j + 1 < n) {
                        j++;
                    }
                    b.append(s.charAt(j));
                    j++;
                }
                t.t = T.STR;
                t.s = b.toString();
                i = Math.min(n, j + 1);
            } else {
                String[] ops = {"->", "==", "!=", "<=", ">=", "&&", "||", "+=", "?.", "."};
                String op = null;
                for (String o : ops) {
                    if (s.startsWith(o, i)) {
                        op = o;
                        break;
                    }
                }
                if (op == null) {
                    op = String.valueOf(c);
                }
                t.t = T.OP;
                t.s = op;
                i += op.length();
            }
            t.b = i;
            r.add(t);
        }
        Tok end = new Tok();
        end.t = T.END;
        end.s = "";
        end.a = end.b = n;
        r.add(end);
        return r;
    }

    private static boolean op(List<Tok> ts, int i, String s) {
        return i >= 0 && i < ts.size() && ts.get(i).t == T.OP && ts.get(i).s.equals(s);
    }

    static void analyze(Expr e) {
        List<Tok> ts = lex(e.text);
        e.toks = ts;
        e.refs = new ArrayList<>();
        e.literals = new ArrayList<>();
        e.lambdas = new ArrayList<>();
        // lambda parameters: x -> ...  and  (x, y) -> ...
        List<int[]> lambdaScopes = new ArrayList<>(); // [start, end, lambda index]
        Set<Integer> paramTok = new HashSet<>();
        for (int i = 0; i < ts.size(); i++) {
            if (!op(ts, i, "->")) {
                continue;
            }
            Lambda l = new Lambda();
            int startTok;
            if (i > 0 && ts.get(i - 1).t == T.ID) {
                l.params.add(ts.get(i - 1));
                paramTok.add(i - 1);
                startTok = i - 1;
            } else if (op(ts, i - 1, ")")) {
                int j = i - 2;
                while (j >= 0 && !op(ts, j, "(")) {
                    if (ts.get(j).t == T.ID) {
                        l.params.add(0, ts.get(j));
                        paramTok.add(j);
                    }
                    j--;
                }
                startTok = Math.max(j, 0);
            } else {
                continue;
            }
            // body: until the surrounding parenthesis/bracket closes or the expression ends
            int depth = 0, k = i + 1;
            for (; k < ts.size(); k++) {
                Tok t = ts.get(k);
                if (t.t == T.END) {
                    break;
                }
                if (t.t == T.OP && (t.s.equals("(") || t.s.equals("[") || t.s.equals("{"))) {
                    depth++;
                } else if (t.t == T.OP && (t.s.equals(")") || t.s.equals("]") || t.s.equals("}"))) {
                    if (depth == 0) {
                        break;
                    }
                    depth--;
                } else if (depth == 0 && t.t == T.OP && (t.s.equals(",") || t.s.equals(";"))) {
                    break;
                }
            }
            e.lambdas.add(l);
            lambdaScopes.add(new int[]{startTok, k, e.lambdas.size() - 1});
        }
        int last = ts.size() - 1;
        int outerEnd = -1; // end of the last reference that is not nested
        for (int i = 0; i < last; i++) {
            Tok t = ts.get(i);
            if (t.t != T.ID || paramTok.contains(i) || KEYWORDS.contains(t.s)) {
                if (t.t == T.ID && t.s.equals("instanceof")) {
                    // skip the type name (a.b.C)
                    int j = i + 1;
                    while (j < last && (ts.get(j).t == T.ID || op(ts, j, "."))) {
                        j++;
                    }
                    i = j - 1;
                }
                continue;
            }
            if (op(ts, i - 1, ".") || op(ts, i - 1, "?.")) {
                continue;
            }
            // function with prefix: fn:length(  /  p:resolveClientId(
            if (op(ts, i + 1, ":") && !ts.get(i + 1).spaceBefore && i + 2 < last && ts.get(i + 2).t == T.ID
                    && !ts.get(i + 2).spaceBefore && op(ts, i + 3, "(")) {
                i += 2;
                continue;
            }
            if (op(ts, i - 1, ":") && !t.spaceBefore && i >= 2 && ts.get(i - 2).t == T.ID && !ts.get(i - 1).spaceBefore
                    && op(ts, i + 1, "(")) {
                continue;
            }
            // lambda parameter in use
            boolean isParam = false;
            for (int[] sc : lambdaScopes) {
                if (i > sc[0] && i < sc[1]) {
                    Lambda l = e.lambdas.get(sc[2]);
                    for (Tok p : l.params) {
                        if (p.s.equals(t.s)) {
                            l.used.add(t.s);
                            isParam = true;
                        }
                    }
                }
            }
            if (isParam) {
                continue;
            }
            Ref r = new Ref();
            r.name = t.s;
            r.a = t.a;
            r.b = t.b;
            r.tokIndex = i;
            int[] jp = readChain(ts, i + 1, last, r);
            int j = jp[0];
            boolean pure = jp[1] == 1;
            if (op(ts, j, "=") && !op(ts, j + 1, "=")) {
                r.assigned = true;
            }
            r.tokEnd = j;
            r.pureLvalue = pure && i == 0 && j == last;
            r.nested = i < outerEnd;
            if (!r.nested) {
                outerEnd = j;
            }
            e.refs.add(r);
            // no jump over the chain: the names inside its arguments and brackets, bean.m(other) or list[other], are
            // references too (the member names after "." are skipped above)
        }
        for (int i = 0; i + 2 < last; i++) {
            if (ts.get(i).t == T.STR && (op(ts, i + 1, ".") || op(ts, i + 1, "?.")) && ts.get(i + 2).t == T.ID) {
                Ref r = new Ref();
                r.literal = true;
                r.name = ts.get(i).s;
                r.a = ts.get(i).a;
                r.b = ts.get(i).b;
                r.tokIndex = i;
                r.tokEnd = readChain(ts, i + 1, last, r)[0];
                e.literals.add(r);
            }
            // [1, 2] and {1, 2} / {'a': 1} where an expression starts (not list[0] nor a lambda body in braces)
            boolean open = op(ts, i, "[") || op(ts, i, "{");
            boolean starts = i == 0 || ts.get(i - 1).t == T.OP && !op(ts, i - 1, ")") && !op(ts, i - 1, "]") && !op(ts, i - 1, "->");
            if (open && starts) {
                String o = ts.get(i).s, c = o.equals("[") ? "]" : "}";
                int close = matching(ts, i, o, c);
                if (close > i && close + 2 < ts.size() && (op(ts, close + 1, ".") || op(ts, close + 1, "?.")) && ts.get(close + 2).t == T.ID) {
                    Ref r = new Ref();
                    r.literal = true;
                    boolean map = false;
                    for (int k = i + 1, depth = 0; k < close; k++) {
                        if (op(ts, k, "(") || op(ts, k, "[") || op(ts, k, "{")) {
                            depth++;
                        } else if (op(ts, k, ")") || op(ts, k, "]") || op(ts, k, "}")) {
                            depth--;
                        } else if (depth == 0 && op(ts, k, ":")) {
                            map = true;
                        }
                    }
                    r.literalType = o.equals("[") ? "java/util/List" : map ? "java/util/Map" : "java/util/Set";
                    r.name = o.equals("[") ? "[...]" : "{...}";
                    r.a = ts.get(i).a;
                    r.b = ts.get(close).b;
                    r.tokIndex = i;
                    r.tokEnd = readChain(ts, close + 1, last, r)[0];
                    e.literals.add(r);
                }
            }
        }
    }

    /** reads .name, .call(...) and [index] after a root into r.chain; returns {index after them, 1 if no call or index} */
    static int[] readChain(List<Tok> ts, int j, int last, Ref r) {
        boolean pure = true;
        {
            while (j < last) {
                if ((op(ts, j, ".") || op(ts, j, "?.")) && ts.get(j + 1).t == T.ID) {
                    Member m = new Member();
                    Tok nt = ts.get(j + 1);
                    m.name = nt.s;
                    m.a = nt.a;
                    m.b = nt.b;
                    j += 2;
                    if (op(ts, j, "(")) {
                        m.call = true;
                        pure = false;
                        int[] res = skipArgs(ts, j);
                        m.argCount = res[1];
                        j = res[0];
                    }
                    r.chain.add(m);
                } else if (op(ts, j, "[")) {
                    Member m = new Member();
                    int close = matching(ts, j, "[", "]");
                    if (close == j + 2 && ts.get(j + 1).t == T.STR) {
                        m.name = ts.get(j + 1).s;
                        m.a = ts.get(j + 1).a + 1;
                        m.b = ts.get(j + 1).b - 1;
                    } else {
                        m.name = null;
                    }
                    r.chain.add(m);
                    j = close + 1;
                } else {
                    break;
                }
            }
        }
        return new int[]{j, pure ? 1 : 0};
    }

    private static int matching(List<Tok> ts, int i, String open, String close) {
        int depth = 0;
        for (int j = i; j < ts.size(); j++) {
            if (op(ts, j, open)) {
                depth++;
            } else if (op(ts, j, close)) {
                depth--;
                if (depth == 0) {
                    return j;
                }
            }
        }
        return ts.size() - 1;
    }

    /** skips (args) and counts arguments; returns [index after the ')', count] */
    private static int[] skipArgs(List<Tok> ts, int open) {
        int close = matching(ts, open, "(", ")");
        int count = 0;
        if (close > open + 1) {
            count = 1;
            int depth = 0;
            for (int k = open + 1; k < close; k++) {
                Tok t = ts.get(k);
                if (t.t == T.OP && (t.s.equals("(") || t.s.equals("[") || t.s.equals("{"))) {
                    depth++;
                } else if (t.t == T.OP && (t.s.equals(")") || t.s.equals("]") || t.s.equals("}"))) {
                    depth--;
                } else if (depth == 0 && op(ts, k, ",")) {
                    count++;
                }
            }
        }
        return new int[]{close + 1, count};
    }

    /** Comparisons "chain == 'text'" (or the other way around), for the enum rule. */
    public static final class Compare {
        public Ref ref;
        public String literal;
        public int litA, litB;
    }

    public static List<Compare> compares(Expr e) {
        List<Compare> r = new ArrayList<>();
        List<Tok> ts = e.toks;
        for (Ref ref : e.refs) {
            int after = ref.tokEnd;
            if (after < ts.size() - 1 && isEq(ts.get(after)) && ts.get(after + 1).t == T.STR) {
                Compare c = new Compare();
                c.ref = ref;
                c.literal = ts.get(after + 1).s;
                c.litA = ts.get(after + 1).a;
                c.litB = ts.get(after + 1).b;
                r.add(c);
            }
            int before = ref.tokIndex - 1;
            if (before >= 1 && isEq(ts.get(before)) && ts.get(before - 1).t == T.STR) {
                Compare c = new Compare();
                c.ref = ref;
                c.literal = ts.get(before - 1).s;
                c.litA = ts.get(before - 1).a;
                c.litB = ts.get(before - 1).b;
                r.add(c);
            }
        }
        return r;
    }

    private static boolean isEq(Tok t) {
        return t.t == T.OP && (t.s.equals("==") || t.s.equals("!=")) || t.t == T.ID && (t.s.equals("eq") || t.s.equals("ne"));
    }
}
