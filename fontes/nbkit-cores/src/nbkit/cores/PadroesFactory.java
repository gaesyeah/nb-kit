package nbkit.cores;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.swing.Timer;
import javax.swing.event.DocumentEvent;
import javax.swing.event.DocumentListener;
import javax.swing.text.AttributeSet;
import javax.swing.text.Document;
import org.netbeans.api.editor.mimelookup.MimeLookup;
import org.netbeans.api.editor.settings.FontColorSettings;
import org.netbeans.api.lexer.Token;
import org.netbeans.api.lexer.TokenHierarchy;
import org.netbeans.api.lexer.TokenSequence;
import org.netbeans.spi.editor.highlighting.HighlightsLayer;
import org.netbeans.spi.editor.highlighting.HighlightsLayerFactory;
import org.netbeans.spi.editor.highlighting.ZOrder;
import org.netbeans.spi.editor.highlighting.support.OffsetsBag;

/**
 * Coloracao por padrao de texto, como a gramatica do VS Code faz e o NetBeans nao:
 * JS e EL (chamada, objeto antes de ponto, tipo apos instanceof, undefined/NaN/Infinity)
 * e CSS/SCSS/LESS (unidade separada do numero, nome de funcao, tag e id em seletor).
 * As cores vem das categorias nbkit-* do perfil ativo; em outro perfil nada e pintado.
 */
public final class PadroesFactory implements HighlightsLayerFactory {

    @Override
    public HighlightsLayer[] createLayers(Context context) {
        Document doc = context.getDocument();
        Object bag = doc.getProperty(Painter.class);
        Painter p = bag instanceof Painter ? (Painter) bag : new Painter(doc);
        doc.putProperty(Painter.class, p);
        return new HighlightsLayer[]{
            HighlightsLayer.create(PadroesFactory.class.getName(), ZOrder.SYNTAX_RACK.forPosition(2000), false, p.bag)
        };
    }

    private static final class Tok {
        final String id;
        final String text;
        final int start;
        Tok(String id, String text, int start) { this.id = id; this.text = text; this.start = start; }
        int end() { return start + text.length(); }
    }

    private static final class Painter implements DocumentListener {
        final Document doc;
        final OffsetsBag bag;
        final Timer timer;

        Painter(Document doc) {
            this.doc = doc;
            this.bag = new OffsetsBag(doc);
            this.timer = new Timer(300, e -> refresh());
            this.timer.setRepeats(false);
            doc.addDocumentListener(this);
            timer.start();
        }

        @Override public void insertUpdate(DocumentEvent e) { timer.restart(); }
        @Override public void removeUpdate(DocumentEvent e) { timer.restart(); }
        @Override public void changedUpdate(DocumentEvent e) { }

        void refresh() {
            OffsetsBag fresh = new OffsetsBag(doc);
            doc.render(() -> {
                try {
                    TokenHierarchy<Document> th = TokenHierarchy.get(doc);
                    TokenSequence<?> ts = th == null ? null : th.tokenSequence();
                    if (ts != null) {
                        walk(ts, fresh, new HashMap<>(), elLocals(doc.getText(0, doc.getLength())));
                    }
                } catch (RuntimeException | javax.swing.text.BadLocationException ex) {
                    // documento mudou no meio: o timer roda de novo na proxima edicao
                }
            });
            bag.setHighlights(fresh);
            fresh.discard();
        }
    }

    private static final Pattern EL_DECL = Pattern.compile(
        "\\b(?:var|varStatus)\\s*=\\s*[\"']([A-Za-z_$][\\w$]*)[\"']|<ui:param\\b[^>]*?\\bname\\s*=\\s*[\"']([A-Za-z_$][\\w$]*)[\"']");

    /** Nomes declarados na pagina (c:set, c:forEach, ui:repeat, p:dataTable... e ui:param): equivalem a variaveis locais. */
    private static Set<String> elLocals(String text) {
        Set<String> s = new HashSet<>();
        Matcher m = EL_DECL.matcher(text);
        while (m.find()) {
            s.add(m.group(1) != null ? m.group(1) : m.group(2));
        }
        return s;
    }

    private static void walk(TokenSequence<?> ts, OffsetsBag out, Map<String, Map<String, AttributeSet>> cache, Set<String> elLocals) {
        List<Tok> toks = new ArrayList<>();
        List<TokenSequence<?>> embedded = new ArrayList<>();
        ts.moveStart();
        while (ts.moveNext()) {
            Token<?> t = ts.token();
            toks.add(new Tok(t.id().name(), t.text().toString(), ts.offset()));
            TokenSequence<?> e = ts.embedded();
            if (e != null) {
                embedded.add(e);
            }
        }
        String mime = ts.language().mimeType();
        String path = ts.languagePath().mimePath();
        Map<String, AttributeSet> colors = cache.computeIfAbsent(path, PadroesFactory::colors);
        if (!colors.isEmpty()) {
            switch (mime) {
                case "text/javascript": js(toks, out, colors); break;
                case "text/x-el": el(toks, out, colors, elLocals); break;
                case "text/css": css(toks, out, colors); break;
                case "text/html": html(toks, out, colors); break;
                case "text/xml": case "text/xml-external-parsed-entity": xml(toks, out, colors); break;
                default: break;
            }
            switch (mime) {
                case "text/x-java": case "text/javascript": case "text/x-json": case "text/css": case "text/x-el":
                    brackets(toks, out, colors);
                    break;
                default: break;
            }
        }
        for (TokenSequence<?> e : embedded) {
            walk(e, out, cache, elLocals);
        }
    }

    private static final String[] NAMES = {
        "nbkit-call", "nbkit-object", "nbkit-type", "nbkit-constant",
        "nbkit-library", "nbkit-readonly", "nbkit-library-function",
        "nbkit-unit", "nbkit-function", "nbkit-tag", "nbkit-id",
        "nbkit-bracket1", "nbkit-bracket2", "nbkit-bracket3", "nbkit-bracket-unexpected",
        "nbkit-attribute", "nbkit-string", "nbkit-plain", "nbkit-url-parameter", "nbkit-doctype",
        "nbkit-keyword", "nbkit-documentroot"
    };

    private static Map<String, AttributeSet> colors(String mimePath) {
        Map<String, AttributeSet> m = new HashMap<>();
        FontColorSettings fcs = MimeLookup.getLookup(mimePath).lookup(FontColorSettings.class);
        if (fcs != null) {
            for (String n : NAMES) {
                AttributeSet a = fcs.getTokenFontColors(n);
                if (a != null) {
                    m.put(n, a);
                }
            }
        }
        return m;
    }

    private static void paint(OffsetsBag out, Map<String, AttributeSet> colors, String name, int start, int end) {
        AttributeSet a = colors.get(name);
        if (a != null && end > start) {
            out.addHighlight(start, end, a);
        }
    }

    // ---------------- JS ----------------

    private static boolean jsSkip(String id) {
        return id.equals("WHITESPACE") || id.equals("EOL") || id.endsWith("COMMENT");
    }

    private static final Set<String> JS_CONSTANTS = Set.of("undefined", "NaN", "Infinity");

    // Globais da biblioteca padrao (lib.dom / lib.es): no VS Code viram variable.defaultLibrary (amarelo no Mix)
    private static final Set<String> LIB_VARS = Set.of(
        "window", "document", "console", "navigator", "location", "history", "localStorage", "sessionStorage",
        "globalThis", "self", "Math", "JSON", "Intl", "Reflect", "Atomics", "screen", "performance", "crypto");
    // Classes da biblioteca padrao: class/support.class (amarelo)
    private static final Set<String> LIB_CLASSES = Set.of(
        "Object", "Array", "String", "Number", "Boolean", "Date", "RegExp", "Promise", "Map", "Set", "WeakMap",
        "WeakSet", "Error", "TypeError", "RangeError", "SyntaxError", "Symbol", "BigInt", "Proxy", "Function",
        "URL", "URLSearchParams", "FormData", "Event", "CustomEvent", "XMLHttpRequest", "Image", "Blob", "File",
        "FileReader", "Headers", "Request", "Response", "AbortController", "MutationObserver",
        "IntersectionObserver", "ResizeObserver", "Node", "Element", "HTMLElement", "Document", "Window");
    // Funcoes globais da biblioteca padrao: function.defaultLibrary -> support.function (ciano no Mix)
    private static final Set<String> LIB_FUNCS = Set.of(
        "setTimeout", "setInterval", "clearTimeout", "clearInterval", "requestAnimationFrame",
        "cancelAnimationFrame", "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURIComponent",
        "decodeURIComponent", "encodeURI", "decodeURI", "alert", "confirm", "prompt", "fetch", "queueMicrotask",
        "structuredClone", "atob", "btoa", "getComputedStyle", "matchMedia", "eval");
    private static final Set<String> GLOBAL_OBJECTS = Set.of("window", "globalThis", "self");

    private static boolean isIdent(Tok k) {
        return k.id.equals("IDENTIFIER") || k.id.equals("PRIVATE_IDENTIFIER");
    }

    private static boolean isDot(String id) {
        return id.equals("OPERATOR_DOT") || id.equals("OPERATOR_OPTIONAL_ACCESS");
    }

    /** Indice do parentese que fecha o que abre em i (ou -1). */
    private static int closing(List<Tok> t, int i, String open, String close) {
        int depth = 0;
        for (int j = i; j < t.size(); j++) {
            if (t.get(j).id.equals(open)) {
                depth++;
            } else if (t.get(j).id.equals(close) && --depth == 0) {
                return j;
            }
        }
        return -1;
    }

    /** Identificadores de uma lista de parametros/padrao (o nome antes de , ) ] } = ou fim). */
    private static void collectNames(List<Tok> t, int from, int to, Set<String> into) {
        for (int j = from; j < to; j++) {
            if (isIdent(t.get(j))) {
                String next = j + 1 < t.size() ? t.get(j + 1).id : "";
                String prev = j > 0 ? t.get(j - 1).id : "";
                boolean key = next.equals("OPERATOR_COLON");      // {a: b} -> a e chave
                if (!key && !isDot(prev)) {
                    into.add(t.get(j).text);
                }
            }
        }
    }

    /** O valor depois de "=" e uma funcao? (function, x => , (...) =>, async ...) */
    private static boolean functionValue(List<Tok> t, int eq) {
        int j = eq + 1;
        if (j < t.size() && t.get(j).text.equals("async")) {
            j++;
        }
        if (j >= t.size()) {
            return false;
        }
        if (t.get(j).id.equals("KEYWORD_FUNCTION")) {
            return true;
        }
        if (isIdent(t.get(j)) && j + 1 < t.size() && t.get(j + 1).id.equals("OPERATOR_ARROW")) {
            return true;
        }
        if (t.get(j).id.equals("BRACKET_LEFT_PAREN")) {
            int c = closing(t, j, "BRACKET_LEFT_PAREN", "BRACKET_RIGHT_PAREN");
            return c > 0 && c + 1 < t.size() && t.get(c + 1).id.equals("OPERATOR_ARROW");
        }
        return false;
    }

    private static void js(List<Tok> all, OffsetsBag out, Map<String, AttributeSet> colors) {
        List<Tok> t = new ArrayList<>();
        for (Tok k : all) {
            if (!jsSkip(k.id)) {
                t.add(k);
            }
        }
        int n = t.size();
        // ---- 1a passada: o que esta declarado no trecho (sem escopo: vale para o trecho todo) ----
        Set<String> vars = new HashSet<>();      // var, let, parametros, catch: variable/parameter (vermelho)
        Set<String> consts = new HashSet<>();    // const: variable.readonly (amarelo)
        Set<String> funcs = new HashSet<>();     // function x, const x = () => ...: function (azul)
        Set<String> classes = new HashSet<>();   // class X (amarelo)
        for (int i = 0; i < n; i++) {
            String id = t.get(i).id;
            if (id.equals("KEYWORD_VAR") || id.equals("RESERVED_LET") || id.equals("KEYWORD_CONST")) {
                boolean isConst = id.equals("KEYWORD_CONST");
                int j = i + 1;
                // declaradores separados por virgula, ate ; ou fim da linha logica
                while (j < n) {
                    Tok d = t.get(j);
                    Set<String> names = new HashSet<>();
                    int after;
                    if (isIdent(d)) {
                        names.add(d.text);
                        after = j + 1;
                    } else if (d.id.equals("BRACKET_LEFT_BRACKET") || d.id.equals("BRACKET_LEFT_CURLY")) {
                        String close = d.id.equals("BRACKET_LEFT_BRACKET") ? "BRACKET_RIGHT_BRACKET" : "BRACKET_RIGHT_CURLY";
                        int c = closing(t, j, d.id, close);
                        if (c < 0) {
                            break;
                        }
                        collectNames(t, j + 1, c, names);
                        after = c + 1;
                    } else {
                        break;
                    }
                    boolean fn = after < n && t.get(after).id.equals("OPERATOR_ASSIGNMENT") && functionValue(t, after);
                    for (String nm : names) {
                        (fn ? funcs : isConst ? consts : vars).add(nm);
                    }
                    // pula o inicializador ate a proxima virgula no mesmo nivel
                    int depth = 0;
                    j = after;
                    while (j < n) {
                        String x = t.get(j).id;
                        if (x.startsWith("BRACKET_LEFT")) {
                            depth++;
                        } else if (x.startsWith("BRACKET_RIGHT")) {
                            if (depth == 0) {
                                break;
                            }
                            depth--;
                        } else if (depth == 0 && (x.equals("OPERATOR_COMMA") || x.equals("OPERATOR_SEMICOLON"))) {
                            break;
                        }
                        j++;
                    }
                    if (j < n && t.get(j).id.equals("OPERATOR_COMMA")) {
                        j++;
                        continue;
                    }
                    break;
                }
            } else if (id.equals("KEYWORD_FUNCTION")) {
                int j = i + 1;
                if (j < n && t.get(j).text.equals("*")) {
                    j++;
                }
                if (j < n && isIdent(t.get(j))) {
                    funcs.add(t.get(j).text);
                    j++;
                }
                if (j < n && t.get(j).id.equals("BRACKET_LEFT_PAREN")) {
                    int c = closing(t, j, "BRACKET_LEFT_PAREN", "BRACKET_RIGHT_PAREN");
                    if (c > 0) {
                        collectNames(t, j + 1, c, vars);
                    }
                }
            } else if (id.equals("OPERATOR_ARROW") && i > 0) {
                Tok p = t.get(i - 1);
                if (isIdent(p)) {
                    vars.add(p.text);
                } else if (p.id.equals("BRACKET_RIGHT_PAREN")) {
                    int depth = 0;
                    for (int j = i - 1; j >= 0; j--) {
                        String x = t.get(j).id;
                        if (x.equals("BRACKET_RIGHT_PAREN")) {
                            depth++;
                        } else if (x.equals("BRACKET_LEFT_PAREN") && --depth == 0) {
                            collectNames(t, j + 1, i - 1, vars);
                            break;
                        }
                    }
                }
            } else if (id.equals("KEYWORD_CATCH") && i + 2 < n && t.get(i + 1).id.equals("BRACKET_LEFT_PAREN")
                    && isIdent(t.get(i + 2))) {
                vars.add(t.get(i + 2).text);
            } else if (id.equals("KEYWORD_CLASS") && i + 1 < n && isIdent(t.get(i + 1))) {
                classes.add(t.get(i + 1).text);
            }
        }
        // metodos de classe: nome( ... ) { dentro do corpo da classe sao declaracoes de metodo (azul)
        // (ja cobertos pela regra de chamada abaixo, pois o nome vem antes de "(")

        // ---- 2a passada: cor de cada identificador ----
        boolean typeChain = false;
        for (int i = 0; i < n; i++) {
            Tok k = t.get(i);
            if (k.id.equals("KEYWORD_INSTANCEOF")) {
                typeChain = true;
                continue;
            }
            if (!isIdent(k)) {
                if (!isDot(k.id)) {
                    typeChain = false;
                }
                continue;
            }
            String next = i + 1 < n ? t.get(i + 1).id : "";
            boolean call = next.equals("BRACKET_LEFT_PAREN");
            boolean beforeDot = isDot(next);
            boolean afterDot = i > 0 && isDot(t.get(i - 1).id);
            boolean declName = i > 0 && (t.get(i - 1).id.equals("KEYWORD_FUNCTION") || t.get(i - 1).id.equals("KEYWORD_CLASS"));

            if (typeChain) {
                paint(out, colors, isResolved(k.text, vars, consts, funcs, classes) && !classes.contains(k.text)
                    && !LIB_CLASSES.contains(k.text) && !LIB_VARS.contains(k.text) ? null : "nbkit-type", k.start, k.end());
                continue;
            }
            if (!afterDot) {
                String name = k.text;
                if (declName) {
                    continue;                                    // nome na declaracao: o NetBeans ja pinta
                } else if (funcs.contains(name)) {
                    paint(out, colors, "nbkit-call", k.start, k.end());
                } else if (classes.contains(name) || LIB_CLASSES.contains(name)) {
                    paint(out, colors, "nbkit-type", k.start, k.end());
                } else if (vars.contains(name)) {
                    // variable/parameter: vermelho, cor do proprio NetBeans (sem pintar)
                } else if (consts.contains(name)) {
                    paint(out, colors, "nbkit-readonly", k.start, k.end());
                } else if (LIB_VARS.contains(name)) {
                    paint(out, colors, "nbkit-library", k.start, k.end());
                } else if (LIB_FUNCS.contains(name)) {
                    paint(out, colors, "nbkit-library-function", k.start, k.end());
                } else if (JS_CONSTANTS.contains(name)) {
                    paint(out, colors, "nbkit-constant", k.start, k.end());
                } else {
                    textmate(out, colors, k, call, beforeDot);    // nao resolvido: regras da gramatica
                }
                continue;
            }
            // membro (depois do ponto): resolvido se a raiz da cadeia e conhecida
            int r = i;
            while (r - 2 >= 0 && isDot(t.get(r - 1).id) && (isIdent(t.get(r - 2)) || t.get(r - 2).id.equals("KEYWORD_THIS"))) {
                r -= 2;
            }
            Tok root = t.get(r);
            boolean resolvedRoot = root.id.equals("KEYWORD_THIS")
                || isIdent(root) && isResolved(root.text, vars, consts, funcs, classes);
            if (!resolvedRoot) {
                textmate(out, colors, k, call, beforeDot);
            } else if (call) {
                boolean libFn = GLOBAL_OBJECTS.contains(root.text) && r == i - 2 && LIB_FUNCS.contains(k.text);
                paint(out, colors, libFn ? "nbkit-library-function" : "nbkit-call", k.start, k.end());
            }
            // propriedade resolvida: vermelho (cor do NetBeans)
        }
    }

    private static boolean isResolved(String name, Set<String> vars, Set<String> consts, Set<String> funcs, Set<String> classes) {
        return vars.contains(name) || consts.contains(name) || funcs.contains(name) || classes.contains(name)
            || LIB_VARS.contains(name) || LIB_CLASSES.contains(name);
    }

    /** Camada da gramatica do VS Code: chamada azul, objeto antes de ponto amarelo, resto vermelho. */
    private static void textmate(OffsetsBag out, Map<String, AttributeSet> colors, Tok k, boolean call, boolean beforeDot) {
        if (call) {
            paint(out, colors, "nbkit-call", k.start, k.end());
        } else if (beforeDot) {
            paint(out, colors, "nbkit-object", k.start, k.end());
        }
    }

    // ---------------- EL ----------------

    // Objetos implicitos do JSF/JSP: equivalem aos globais da biblioteca padrao (amarelo)
    private static final Set<String> EL_IMPLICIT = Set.of(
        "cc", "component", "facesContext", "request", "session", "application", "param", "paramValues",
        "header", "headerValues", "cookie", "initParam", "view", "viewScope", "requestScope", "sessionScope",
        "applicationScope", "flash", "resource", "pageContext", "pageScope");

    private static void el(List<Tok> all, OffsetsBag out, Map<String, AttributeSet> colors, Set<String> locals) {
        List<Tok> t = new ArrayList<>();
        for (Tok k : all) {
            if (!k.id.equals("WHITESPACE") && !k.id.equals("EOL")) {
                t.add(k);
            }
        }
        for (int i = 0; i < t.size(); i++) {
            Tok k = t.get(i);
            if (!k.id.equals("IDENTIFIER")) {
                continue;
            }
            String next = i + 1 < t.size() ? t.get(i + 1).id : "";
            boolean call = next.equals("LPAREN");
            boolean beforeDot = next.equals("DOT");
            boolean afterDot = i > 0 && t.get(i - 1).id.equals("DOT");
            if (!afterDot) {
                if (locals.contains(k.text)) {
                    // variavel declarada na pagina: vermelho (cor do NetBeans)
                } else if (EL_IMPLICIT.contains(k.text)) {
                    paint(out, colors, "nbkit-library", k.start, k.end());
                } else {
                    textmate(out, colors, k, call, beforeDot);    // bean: nao resolvido
                }
                continue;
            }
            int r = i;
            while (r - 2 >= 0 && t.get(r - 1).id.equals("DOT") && t.get(r - 2).id.equals("IDENTIFIER")) {
                r -= 2;
            }
            Tok root = t.get(r);
            boolean resolvedRoot = root.id.equals("IDENTIFIER")
                && (locals.contains(root.text) || EL_IMPLICIT.contains(root.text));
            if (!resolvedRoot) {
                textmate(out, colors, k, call, beforeDot);
            } else if (call) {
                paint(out, colors, "nbkit-call", k.start, k.end());
            }
        }
    }

    // ---------------- CSS / SCSS / LESS ----------------

    private static final Set<String> CSS_UNITS = Set.of(
        "DIMENSION", "LENGTH", "EMS", "EXS", "ANGLE", "TIME", "FREQ", "RESOLUTION", "REM", "PERCENTAGE");
    private static final Pattern NUMBER = Pattern.compile("^[+-]?(\\d*\\.\\d+|\\d+)(e[+-]?\\d+)?");
    private static final Set<String> MIXIN_KEYWORDS = Set.of("SASS_INCLUDE", "SASS_MIXIN", "SASS_FUNCTION");

    private static boolean cssSkip(String id) {
        return id.equals("WS") || id.equals("NL") || id.endsWith("COMMENT");
    }

    private static boolean isAtRule(String id) {
        return id.endsWith("_SYM") || id.equals("AT_IDENT") || id.startsWith("SASS_") && !id.equals("SASS_VAR")
            && !id.equals("SASS_DEFAULT") && !id.equals("SASS_GLOBAL") && !id.equals("SASS_OPTIONAL")
            && !id.equals("SASS_EXTEND_ONLY_SELECTOR");
    }

    private static void css(List<Tok> t, OffsetsBag out, Map<String, AttributeSet> colors) {
        int n = t.size();
        // fim de cada "instrucao": indice do proximo { ; } fora de () [] e de #{...}
        int[] stmtEnd = new int[n];
        int[] stmtStart = new int[n];
        {
            int depth = 0;
            int start = 0;
            List<Integer> pending = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                String id = t.get(i).id;
                boolean interp = id.equals("LBRACE") && i > 0 && t.get(i - 1).id.equals("HASH_SYMBOL");
                if (id.equals("LPAREN") || id.equals("LBRACKET") || interp) {
                    depth++;
                } else if ((id.equals("RPAREN") || id.equals("RBRACKET") || id.equals("RBRACE")) && depth > 0) {
                    depth--;
                    stmtStart[i] = start;
                    pending.add(i);
                    continue;
                }
                stmtStart[i] = start;
                pending.add(i);
                if (depth == 0 && (id.equals("LBRACE") || id.equals("SEMI") || id.equals("RBRACE"))) {
                    for (int p : pending) {
                        stmtEnd[p] = i;
                    }
                    pending.clear();
                    start = i + 1;
                }
            }
            for (int p : pending) {
                stmtEnd[p] = n;
            }
        }
        int depth = 0;
        List<Boolean> blocks = new ArrayList<>();   // true = bloco de @keyframes
        for (int i = 0; i < n; i++) {
            Tok k = t.get(i);
            String id = k.id;
            boolean interp = id.equals("LBRACE") && i > 0 && t.get(i - 1).id.equals("HASH_SYMBOL");
            if (id.equals("LPAREN") || id.equals("LBRACKET") || interp) {
                depth++;
            } else if ((id.equals("RPAREN") || id.equals("RBRACKET") || id.equals("RBRACE")) && depth > 0) {
                depth--;
                continue;
            } else if (id.equals("LBRACE")) {
                boolean kf = false;
                for (int q = stmtStart[i]; q < i; q++) {
                    kf |= t.get(q).id.contains("KEYFRAMES_SYM");
                }
                blocks.add(kf);
                continue;
            } else if (id.equals("RBRACE")) {
                if (!blocks.isEmpty()) {
                    blocks.remove(blocks.size() - 1);
                }
                continue;
            }

            boolean selectorStmt = stmtEnd[i] < n && t.get(stmtEnd[i]).id.equals("LBRACE");
            boolean atRule = false;
            for (int q = stmtStart[i]; q < stmtEnd[i] && selectorStmt; q++) {
                if (isAtRule(t.get(q).id)) {
                    atRule = true;
                    break;
                }
            }
            boolean selector = selectorStmt && !atRule;
            boolean keyframeOffset = selector && !blocks.isEmpty() && blocks.get(blocks.size() - 1);

            String prevRaw = i > 0 ? t.get(i - 1).id : "";
            int j = i - 1;
            while (j >= 0 && cssSkip(t.get(j).id)) {
                j--;
            }
            String prev = j >= 0 ? t.get(j).id : "";

            // @keyframes: from, to e 50% sao entity.other.keyframe-offset (sem regra no Mix: cor do texto)
            if (keyframeOffset && (id.equals("IDENT") || id.equals("PERCENTAGE"))) {
                paint(out, colors, "nbkit-plain", k.start, k.end());
                continue;
            }

            if (CSS_UNITS.contains(id)) {
                Matcher m = NUMBER.matcher(k.text);
                if (m.find() && m.end() < k.text.length()) {
                    paint(out, colors, "nbkit-unit", k.start + m.end(), k.end());
                }
                continue;
            }

            if (id.equals("IDENT") && i + 1 < n && t.get(i + 1).id.equals("LPAREN")) {
                if (!MIXIN_KEYWORDS.contains(prev)) {
                    paint(out, colors, "nbkit-function", k.start, k.end());
                }
                continue;
            }

            if (!selector) {
                continue;
            }
            if (depth > 0) {
                // seletor de atributo: [nome op valor]
                if (id.equals("IDENT") && prev.equals("LBRACKET")) {
                    paint(out, colors, "nbkit-attribute", k.start, k.end());
                } else if (id.equals("IDENT") && (prev.equals("OPEQ") || prev.equals("INCLUDES") || prev.equals("DASHMATCH")
                        || prev.equals("BEGINS") || prev.equals("ENDS") || prev.equals("CONTAINS"))) {
                    paint(out, colors, "nbkit-string", k.start, k.end());
                }
                continue;
            }
            if (id.equals("IDENT") && !prevRaw.equals("DOT") && !prevRaw.equals("COLON")
                    && !prevRaw.equals("DCOLON") && !prevRaw.equals("LESS_AND") && !prevRaw.equals("MINUS")
                    && !prevRaw.equals("HASH_SYMBOL") && !prevRaw.equals("PERCENTAGE_SYMBOL")) {
                paint(out, colors, "nbkit-tag", k.start, k.end());
            } else if (id.equals("HASH")) {
                paint(out, colors, "nbkit-id", k.start, k.end());
            }
        }
    }

    // ---------------- Pares de colchetes (editor.bracketPairColorization, ligado por padrao no VS Code) ----------------

    private static final Map<String, String> PAIRS = new HashMap<>();
    static {
        // Java, CSS, EL
        PAIRS.put("LPAREN", "RPAREN");
        PAIRS.put("LBRACE", "RBRACE");
        PAIRS.put("LBRACKET", "RBRACKET");
        // JS, JSON (inclui ${ } de template, que e par de colchetes na configuracao de JS do VS Code)
        PAIRS.put("BRACKET_LEFT_PAREN", "BRACKET_RIGHT_PAREN");
        PAIRS.put("BRACKET_LEFT_CURLY", "BRACKET_RIGHT_CURLY");
        PAIRS.put("BRACKET_LEFT_BRACKET", "BRACKET_RIGHT_BRACKET");
        PAIRS.put("TEMPLATE_EXP_BEGIN", "TEMPLATE_EXP_END");
    }
    private static final Set<String> CLOSERS = new HashSet<>(PAIRS.values());
    private static final String[] LEVELS = {"nbkit-bracket1", "nbkit-bracket2", "nbkit-bracket3"};
    private static final Pattern URL_TOKEN = Pattern.compile("(?i)^(url)(\\()(\\s*)(.*?)(\\s*)(\\))$");

    /** Cor por nivel de aninhamento (um contador so para (), [] e {}); fechamento sem par fica vermelho. */
    private static void brackets(List<Tok> t, OffsetsBag out, Map<String, AttributeSet> colors) {
        List<String> stack = new ArrayList<>();
        for (Tok k : t) {
            String close = PAIRS.get(k.id);
            if (close != null) {
                paint(out, colors, LEVELS[stack.size() % 3], k.start, k.end());
                stack.add(close);
            } else if (CLOSERS.contains(k.id)) {
                if (!stack.isEmpty() && stack.get(stack.size() - 1).equals(k.id)) {
                    stack.remove(stack.size() - 1);
                    paint(out, colors, LEVELS[stack.size() % 3], k.start, k.end());
                } else {
                    paint(out, colors, "nbkit-bracket-unexpected", k.start, k.end());
                }
            } else if (k.id.equals("URI") || k.id.equals("URL")) {
                // url(...) e um token so no NetBeans: funcao ciano, parenteses pelo nivel, argumento string/parametro
                Matcher m = URL_TOKEN.matcher(k.text);
                if (m.matches()) {
                    String lvl = LEVELS[stack.size() % 3];
                    paint(out, colors, "nbkit-function", k.start + m.start(1), k.start + m.end(1));
                    paint(out, colors, lvl, k.start + m.start(2), k.start + m.end(2));
                    String arg = m.group(4);
                    boolean quoted = arg.length() >= 2 && (arg.charAt(0) == '"' || arg.charAt(0) == '\'');
                    paint(out, colors, quoted ? "nbkit-string" : "nbkit-url-parameter",
                        k.start + m.start(4), k.start + m.end(4));
                    paint(out, colors, lvl, k.start + m.start(6), k.start + m.end(6));
                }
            }
        }
    }

    // ---------------- HTML: <!DOCTYPE ...> (meta.tag.metadata.doctype.html) ----------------

    private static final Pattern DOCTYPE_PART = Pattern.compile("(?i)(<!)|(DOCTYPE)|(\"[^\"]*\"?)|([^\\s>\"]+)|(>)");

    private static void html(List<Tok> t, OffsetsBag out, Map<String, AttributeSet> colors) {
        for (Tok k : t) {
            if (k.id.equals("XML_PI")) {
                xmlPi(k, out, colors);                  // <?xml ...?> (meta.tag.metadata.processing.xml.html)
                continue;
            }
            if (!k.id.equals("DECLARATION") || !k.text.regionMatches(true, 0, "<!DOCTYPE", 0, 9)) {
                continue;
            }
            Matcher m = DOCTYPE_PART.matcher(k.text);
            boolean nameDone = false;
            while (m.find()) {
                int s = k.start + m.start(), e = k.start + m.end();
                if (m.group(1) != null || m.group(5) != null) {
                    paint(out, colors, "nbkit-plain", s, e);
                } else if (m.group(2) != null && !nameDone) {
                    paint(out, colors, "nbkit-doctype", s, e);
                    nameDone = true;
                } else if (m.group(3) != null) {
                    paint(out, colors, "nbkit-string", s, e);
                } else {
                    paint(out, colors, "nbkit-attribute", s, e);
                }
            }
        }
    }

    // ---------------- XML: <?xml ...?> e <!DOCTYPE ...> (meta.tag.preprocessor.xml / meta.tag.sgml.doctype.xml) ----------------

    private static final Pattern PI_PART = Pattern.compile("(<\\?)([-_a-zA-Z0-9]+)?|(\\?>)|(\"[^\"]*\"?|'[^']*'?)|([A-Za-z_:][-A-Za-z0-9_:.]*)|([^\\s])");

    /** Token unico com o PI inteiro (HTML) ou so o conteudo (XML, sem "<?" e "?>"). */
    private static void xmlPi(Tok k, OffsetsBag out, Map<String, AttributeSet> colors) {
        Matcher m = PI_PART.matcher(k.text);
        while (m.find()) {
            int base = k.start;
            if (m.group(1) != null) {
                paint(out, colors, "nbkit-plain", base + m.start(1), base + m.end(1));
                if (m.group(2) != null) {
                    paint(out, colors, "nbkit-doctype", base + m.start(2), base + m.end(2));
                }
            } else if (m.group(4) != null) {
                paint(out, colors, "nbkit-string", base + m.start(), base + m.end());
            } else if (m.group(5) != null) {
                paint(out, colors, "nbkit-attribute", base + m.start(), base + m.end());
            } else {
                paint(out, colors, "nbkit-plain", base + m.start(), base + m.end());
            }
        }
    }

    private static final Pattern XML_DOCTYPE = Pattern.compile("(?i)^(<!)(DOCTYPE)(\\s+)([:A-Za-z_][:A-Za-z0-9_.-]*)?");
    private static final Pattern XML_DOCTYPE_REST = Pattern.compile("(\"[^\"]*\"?|'[^']*'?)|([^\\s\"']+)");

    private static void xml(List<Tok> t, OffsetsBag out, Map<String, AttributeSet> colors) {
        for (Tok k : t) {
            if (k.id.equals("PI_CONTENT")) {
                xmlPi(k, out, colors);
            } else if (k.id.equals("DECLARATION")) {
                Matcher m = XML_DOCTYPE.matcher(k.text);
                if (!m.find()) {
                    continue;
                }
                paint(out, colors, "nbkit-plain", k.start + m.start(1), k.start + m.end(1));
                paint(out, colors, "nbkit-keyword", k.start + m.start(2), k.start + m.end(2));
                if (m.group(4) != null) {
                    paint(out, colors, "nbkit-documentroot", k.start + m.start(4), k.start + m.end(4));
                }
                Matcher r = XML_DOCTYPE_REST.matcher(k.text);
                r.region(m.end(), k.text.length());
                while (r.find()) {
                    paint(out, colors, r.group(1) != null ? "nbkit-string" : "nbkit-plain",
                        k.start + r.start(), k.start + r.end());
                }
            }
        }
    }
}
