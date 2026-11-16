package nbkit.jsf;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * What NetBeans marks on the xhtml of a project, as collected by the module (nb/Collector) and read by the comparison
 * with nbkit's own problems: the request file, the collection file and the marker that it is done. No NetBeans here.
 * <p>
 * The collection is UTF-8 text, one record per line, fields split by tabs (tab, line break and backslash inside a
 * field written as \t, \n, \r and \\):
 * <pre>
 * # nbkit NetBeans marks 1
 * info  &lt;key&gt;  &lt;value&gt;          (project, netbeans, nbkit-jsf, date...)
 * file  &lt;path&gt;  &lt;sha256&gt;        (each xhtml, path relative to the project)
 * mark  &lt;path&gt;  &lt;line&gt;  &lt;column&gt;  &lt;start&gt;  &lt;end&gt;  &lt;rule&gt;  &lt;severity&gt;  on|off  &lt;message&gt;
 * </pre>
 * Lines and columns start at 1; start and end are offsets in the file's text; on/off is whether the rule is on in
 * NetBeans' settings (the module runs it either way). Two info lines say what NetBeans did not run at all, above the
 * rules' own on/off, so that no mark there is not taken as agreement (see notRun).
 */
public final class NetBeansMarks {

    public static final String HEADER = "# nbkit NetBeans marks 1";
    /** "on|off &lt;mime&gt;": HTML error checking for the content of JSF pages; off, no HTML rule runs (Missing CSS Class...) */
    public static final String INFO_HTML_ERRORS = "html-error-checking";
    /** "yes|no": the project is a web module for NetBeans; no, EL's Identifiers never applies */
    public static final String INFO_WEB_MODULE = "web-module";
    /** the content mime of a JSF page in NetBeans (web.jsfapi JsfUtils.JSF_XHTML_FILE_MIMETYPE) */
    public static final String FACELETS = "text/facelets";

    private NetBeansMarks() {
    }

    /** one mark of NetBeans on a page */
    public record Mark(String file, int line, int column, int start, int end, String rule, String severity, boolean enabled,
            String message) {
    }

    /** a collection read back */
    public record Collected(Map<String, String> info, Map<String, String> hashes, List<Mark> marks) {
    }

    /** ~/.cache/nbkit, where the debug switch also lives */
    public static File cache() {
        return new File(System.getProperty("user.home"), ".cache/nbkit");
    }

    public static File requestFile(File cache) {
        return new File(cache, "collect-request");
    }

    public static File doneFile(File cache) {
        return new File(cache, "collect-done");
    }

    /** the project of the request (its first line that is not blank, ~ is the home folder), or null when there is none */
    public static File readRequest(File request) {
        List<String> lines;
        try {
            lines = Files.readAllLines(request.toPath(), StandardCharsets.UTF_8);
        } catch (IOException ex) {
            return null;
        }
        for (String l : lines) {
            String p = l.strip();
            if (!p.isEmpty()) {
                if (p.equals("~") || p.startsWith("~/")) {
                    p = System.getProperty("user.home") + p.substring(1);
                }
                return new File(p);
            }
        }
        return null;
    }

    /**
     * Takes the request: its project (null when there is none or it is empty), and the request and the done marker of
     * the collection before are gone, so each request is answered once and a reader never sees an old done marker.
     */
    public static File take(File cache) {
        File request = requestFile(cache);
        if (!request.exists()) {
            return null;
        }
        File project = readRequest(request);
        request.delete();
        doneFile(cache).delete();
        return project;
    }

    /**
     * Whether NetBeans checks HTML errors in that content mime, from its setting mimetypesWithEnabledHtmlErrorChecking
     * (";" between mimes): html.editor HtmlPreferences.isHtmlErrorCheckingEnabledForMimetype, where text/html and
     * text/xhtml are on unless listed and every other mime (JSF pages: text/facelets) is on only when listed.
     */
    public static boolean htmlErrorChecking(String setting, String mime) {
        boolean listed = List.of(setting == null ? new String[0] : setting.split(";")).contains(mime);
        boolean html = mime.equals("text/html") || mime.equals("text/xhtml");
        return html != listed;
    }

    /** the NetBeans rules that did not run at all (rule id prefix of the marks), each with the info line that says why */
    public static Map<String, String> notRun(Collected c) {
        Map<String, String> r = new LinkedHashMap<>();
        String html = c.info().getOrDefault(INFO_HTML_ERRORS, "");
        if (html.startsWith("off")) {
            r.put("text_html_", INFO_HTML_ERRORS + " " + html);
        }
        if ("no".equals(c.info().get(INFO_WEB_MODULE))) {
            r.put("text_x-el_Identifiers", INFO_WEB_MODULE + " no");
        }
        return r;
    }

    /** collect/&lt;project folder name&gt;-&lt;8 hex of its path&gt;.tsv: one file per project, the same every time */
    public static File outputFile(File cache, File project) {
        String path = project.getAbsolutePath();
        return new File(cache, "collect/" + project.getName() + "-" + sha256(path.getBytes(StandardCharsets.UTF_8)).substring(0, 8)
                + ".tsv");
    }

    public static String sha256(byte[] data) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(data));
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException(ex);
        }
    }

    /** { line, column } of an offset in the text, both from 1; \r\n, \n and \r are one line break each */
    public static int[] lineColumn(String text, int offset) {
        int line = 1;
        int lineStart = 0;
        int end = Math.min(offset, text.length());
        for (int i = 0; i < end; i++) {
            char c = text.charAt(i);
            if (c == '\n' || (c == '\r' && (i + 1 >= text.length() || text.charAt(i + 1) != '\n'))) {
                line++;
                lineStart = i + 1;
            }
        }
        return new int[]{line, end - lineStart + 1};
    }

    /** writes the collection whole (a temporary file renamed at the end): a reader never sees half of it */
    public static void write(File out, Map<String, String> info, Map<String, String> hashes, List<Mark> marks) throws IOException {
        StringBuilder sb = new StringBuilder(HEADER).append('\n');
        for (Map.Entry<String, String> e : info.entrySet()) {
            line(sb, "info", e.getKey(), e.getValue());
        }
        for (Map.Entry<String, String> e : hashes.entrySet()) {
            line(sb, "file", e.getKey(), e.getValue());
        }
        for (Mark m : marks) {
            line(sb, "mark", m.file(), "" + m.line(), "" + m.column(), "" + m.start(), "" + m.end(), m.rule(), m.severity(),
                    m.enabled() ? "on" : "off", m.message());
        }
        out.getParentFile().mkdirs();
        File tmp = new File(out.getPath() + ".tmp");
        Files.writeString(tmp.toPath(), sb, StandardCharsets.UTF_8);
        Files.move(tmp.toPath(), out.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
    }

    public static Collected read(File in) throws IOException {
        Map<String, String> info = new LinkedHashMap<>();
        Map<String, String> hashes = new LinkedHashMap<>();
        List<Mark> marks = new ArrayList<>();
        for (String l : Files.readAllLines(in.toPath(), StandardCharsets.UTF_8)) {
            if (l.isEmpty() || l.startsWith("#")) {
                continue;
            }
            String[] f = l.split("\t", -1);
            for (int i = 0; i < f.length; i++) {
                f[i] = unescape(f[i]);
            }
            switch (f[0]) {
                case "info" -> info.put(f[1], f[2]);
                case "file" -> hashes.put(f[1], f[2]);
                case "mark" -> marks.add(new Mark(f[1], Integer.parseInt(f[2]), Integer.parseInt(f[3]), Integer.parseInt(f[4]),
                        Integer.parseInt(f[5]), f[6], f[7], f[8].equals("on"), f[9]));
                default -> {
                    // a kind of line from a newer module: skipped
                }
            }
        }
        return new Collected(info, hashes, marks);
    }

    /** the marker that the collection is complete: the path of the collection, written after it */
    public static void done(File cache, File out) throws IOException {
        cache.mkdirs();
        Files.writeString(doneFile(cache).toPath(), out.getPath() + "\n", StandardCharsets.UTF_8);
    }

    private static void line(StringBuilder sb, String... fields) {
        for (int i = 0; i < fields.length; i++) {
            if (i > 0) {
                sb.append('\t');
            }
            sb.append(escape(fields[i] == null ? "" : fields[i]));
        }
        sb.append('\n');
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n").replace("\r", "\\r");
    }

    private static String unescape(String s) {
        if (s.indexOf('\\') < 0) {
            return s;
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '\\' && i + 1 < s.length()) {
                char n = s.charAt(++i);
                sb.append(n == 't' ? '\t' : n == 'n' ? '\n' : n == 'r' ? '\r' : n);
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }
}
