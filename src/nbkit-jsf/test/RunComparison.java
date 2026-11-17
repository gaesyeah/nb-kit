import java.io.File;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import nbkit.jsf.*;

/** Crosses pages/compare.xhtml of the fixture with a fake NetBeans collection (tests/jsf.sh checks the lines). */
public class RunComparison {
    public static void main(String[] a) throws Exception {
        File proj = new File(a[0]);
        List<File> cp = new ArrayList<>();
        for (int i = 1; i < a.length; i++) cp.add(new File(a[i]));
        File page = new File(proj, "src/main/webapp/pages/compare.xhtml");
        String text = Files.readString(page.toPath());
        Workspace ws = Workspace.get(page, cp);
        Analyzer.Result r = Analyzer.analyze(ws, page, text, Rules.ALL_ON, new ArrayList<>());
        String f = "src/main/webapp/pages/compare.xhtml";
        List<NetBeansMarks.Mark> marks = List.of(
                mark(f, text, "titl}", 4, "text_x-el_Identifiers", "Unknown property titl"),
                mark(f, text, "concat(", 6, "text_x-el_Identifiers", "Unknown method concat"),
                mark(f, text, "total}", 5, "text_x-el_Identifiers", "Unknown property total"),
                mark(f, text, "anything.more", 8, "text_x-el_Identifiers", "Unknown property anything"),
                mark(f, text, "company}", 7, "text_x-el_Identifiers", "Unknown property company"),
                mark(f, text, "zz-compare", 10, "text_html_MissingClassRule", "Class zz-compare not found"),
                mark(f, text, "<div>x", 5, "text_html_Other", "an HTML validator mark"));
        print("all rules ran", NetBeansComparison.compare(f, r, marks, Map.of()), text);
        print("HTML checking off", NetBeansComparison.compare(f, r, marks.subList(0, 5), Map.of("text_html_", "html-error-checking off text/facelets")), text);
        // -Dnbkit.write=<file>: the same marks as a collection of the project (as nb/Collector writes it), for analyze
        String out = System.getProperty("nbkit.write");
        if (out != null) {
            java.util.Map<String, String> info = new java.util.LinkedHashMap<>();
            info.put("project", proj.getPath());
            info.put("netbeans", "Apache NetBeans IDE 31 31-test");
            info.put("date", "2026-11-16T19:00:00Z");
            info.put(NetBeansMarks.INFO_CLASSES, "" + (System.currentTimeMillis() + 60000));
            java.util.Map<String, String> hashes = new java.util.LinkedHashMap<>();
            for (File p : Workspace.pages(proj)) {
                hashes.put(proj.toPath().relativize(p.toPath()).toString().replace('\\', '/'), NetBeansMarks.sha256(Files.readAllBytes(p.toPath())));
            }
            NetBeansMarks.write(new File(out), info, hashes, marks);
        }
        System.out.println("pairs: " + NetBeansRules.ALL.stream().map(p -> p.shortName() + "->" + p.nbkit() + (p.replacedBy() == null ? "" : " off " + p.preferencesNode())).toList());
    }

    static NetBeansMarks.Mark mark(String f, String text, String at, int len, String rule, String msg) {
        int s = text.indexOf(at);
        int[] lc = NetBeansMarks.lineColumn(text, s);
        return new NetBeansMarks.Mark(f, lc[0], lc[1], s, s + len, rule, "WARNING", true, msg);
    }

    static void print(String title, List<NetBeansComparison.Match> l, String text) {
        System.out.println("== " + title);
        for (NetBeansComparison.Match x : l) {
            System.out.println("line " + NetBeansMarks.lineColumn(text, x.start())[0] + ": " + x.category() + " " + x.netbeansRule() + " / " + x.nbkitRule()
                    + (x.skipReason() == null ? "" : " skipped " + x.skipReason()) + (x.why() == null ? "" : " why: " + x.why()));
        }
    }
}
