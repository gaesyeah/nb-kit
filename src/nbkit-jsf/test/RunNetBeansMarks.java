import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import nbkit.jsf.NetBeansMarks;

/** Prints what NetBeansMarks does with the request, the hash, the positions and the collection (tests/jsf.sh checks the lines). */
public class RunNetBeansMarks {
    public static void main(String[] args) throws Exception {
        File cache = new File(args[0]);
        File home = new File(System.getProperty("user.home"));
        File request = NetBeansMarks.requestFile(cache);
        System.out.println("request file: " + request.getPath().substring(cache.getPath().length()));
        System.out.println("no request: " + NetBeansMarks.readRequest(request));
        Files.writeString(request.toPath(), "  \n");
        System.out.println("empty request: " + NetBeansMarks.readRequest(request));
        Files.writeString(request.toPath(), "\n  /work/my project  \n");
        System.out.println("request: " + NetBeansMarks.readRequest(request));
        Files.writeString(request.toPath(), "~/Documents/app\n");
        System.out.println("request with ~: " + NetBeansMarks.readRequest(request).getPath().replace(home.getPath(), "HOME"));

        System.out.println("sha256 abc: " + NetBeansMarks.sha256("abc".getBytes(StandardCharsets.UTF_8)));
        String text = "ab\ncd\r\nef";
        for (int off : new int[]{0, 1, 3, 4, 7, 9}) {
            int[] lc = NetBeansMarks.lineColumn(text, off);
            System.out.println("offset " + off + " -> " + lc[0] + ":" + lc[1]);
        }

        File out = NetBeansMarks.outputFile(cache, new File("/work/my project"));
        System.out.println("output: " + out.getPath().substring(cache.getPath().length()));
        System.out.println("same project, same output: " + out.equals(NetBeansMarks.outputFile(cache, new File("/work/my project"))));
        System.out.println("another project, another output: " + !out.equals(NetBeansMarks.outputFile(cache, new File("/other/my project"))));

        Map<String, String> info = new LinkedHashMap<>();
        info.put("project", "/work/my project");
        info.put("netbeans", "31");
        Map<String, String> hashes = new LinkedHashMap<>();
        hashes.put("src/main/webapp/a.xhtml", NetBeansMarks.sha256("abc".getBytes(StandardCharsets.UTF_8)));
        List<NetBeansMarks.Mark> marks = List.of(
                new NetBeansMarks.Mark("src/main/webapp/a.xhtml", 2, 5, 12, 20, "text_x-el_Identifiers", "WARNING", false,
                        "Unknown property \"x\"\twith a tab\nand a line \\ backslash"),
                new NetBeansMarks.Mark("src/main/webapp/a.xhtml", 3, 1, 30, 31, "text_html_MissingClassRule", "WARNING", true, "Class y not found"));
        NetBeansMarks.write(out, info, hashes, marks);
        for (String line : Files.readAllLines(out.toPath(), StandardCharsets.UTF_8)) {
            System.out.println("line: " + line);
        }
        NetBeansMarks.Collected c = NetBeansMarks.read(out);
        System.out.println("read info: " + c.info());
        System.out.println("read hashes: " + c.hashes());
        System.out.println("read back the same marks: " + c.marks().equals(marks));
        System.out.println("no temporary file left: " + (out.getParentFile().list().length == 1));

        NetBeansMarks.done(cache, out);
        System.out.println("done marker: " + Files.readString(NetBeansMarks.doneFile(cache).toPath()).trim().equals(out.getPath()));

        // a request is taken once: the request goes, and so does the done marker of the collection before
        Files.writeString(request.toPath(), "/work/next\n");
        System.out.println("take: " + NetBeansMarks.take(cache) + " request left: " + request.exists()
                + " old done left: " + NetBeansMarks.doneFile(cache).exists());
        System.out.println("take again: " + NetBeansMarks.take(cache));
        Files.writeString(request.toPath(), " \n");
        System.out.println("take an empty request: " + NetBeansMarks.take(cache) + " request left: " + request.exists());

        // HTML error checking (html.editor HtmlPreferences): the HTML mimes are on unless listed, the others only listed
        for (String[] h : new String[][]{{"", "text/facelets"}, {"text/facelets", "text/facelets"}, {"", "text/xhtml"},
            {"text/xhtml;text/facelets", "text/xhtml"}, {"", "text/html"}}) {
            System.out.println("html error checking setting='" + h[0] + "' " + h[1] + ": "
                    + NetBeansMarks.htmlErrorChecking(h[0], h[1]));
        }

        // what did not run, so that no mark there says nothing
        Map<String, String> off = new LinkedHashMap<>();
        off.put(NetBeansMarks.INFO_HTML_ERRORS, "off text/facelets");
        off.put(NetBeansMarks.INFO_WEB_MODULE, "no");
        NetBeansMarks.write(out, off, Map.of(), List.of());
        for (String line : Files.readAllLines(out.toPath(), StandardCharsets.UTF_8)) {
            System.out.println("line: " + line);
        }
        System.out.println("not run: " + NetBeansMarks.notRun(NetBeansMarks.read(out)));
        Map<String, String> on = new LinkedHashMap<>();
        on.put(NetBeansMarks.INFO_HTML_ERRORS, "on text/facelets");
        on.put(NetBeansMarks.INFO_WEB_MODULE, "yes");
        NetBeansMarks.write(out, on, Map.of(), List.of());
        System.out.println("all ran: " + NetBeansMarks.notRun(NetBeansMarks.read(out)));
    }
}
