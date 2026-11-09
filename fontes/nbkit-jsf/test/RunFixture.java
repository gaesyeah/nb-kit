import nbkit.jsf.*;
import java.io.File;
import java.nio.file.*;
import java.util.*;
import java.util.regex.*;

public class RunFixture {
    public static void main(String[] a) throws Exception {
        File proj = new File(a[0]);
        List<File> cp = new ArrayList<>();
        for (int i = 1; i < a.length; i++) cp.add(new File(a[i]));
        File web = new File(proj, "src/main/webapp");
        List<File> files = new ArrayList<>();
        try (var s = Files.walk(web.toPath())) { s.filter(p -> p.toString().endsWith(".xhtml")).sorted().forEach(p -> files.add(p.toFile())); }
        int fails = 0;
        long t0 = System.currentTimeMillis();
        Workspace ws = Workspace.get(files.get(0), cp);
        System.out.println("beans: " + new TreeSet<>(ws.beans.keySet()) + " (" + (System.currentTimeMillis() - t0) + " ms)");
        for (File f : files) {
            String text = Files.readString(f.toPath());
            List<Rules.Problem> ps = Analyzer.run(ws, f, text, Rules.ALL_ON);
            String[] lines = text.split("\n", -1);
            Set<String> expected = new TreeSet<>(), got = new TreeSet<>();
            Pattern m = Pattern.compile("<!--((?:[EW]:[\\w.]+\\s*)+)-->");
            for (int i = 0; i < lines.length; i++) {
                Matcher mm = m.matcher(lines[i]);
                while (mm.find()) for (String x : mm.group(1).trim().split("\\s+")) expected.add((i + 1) + " " + x);
            }
            Map<String, String> msgs = new HashMap<>();
            int[] starts = new int[lines.length + 1];
            for (int i = 1; i <= lines.length; i++) starts[i] = starts[i - 1] + lines[i - 1].length() + 1;
            for (Rules.Problem p : ps) {
                int line = 1;
                while (line < lines.length && starts[line] <= p.start) line++;
                String k = line + " " + (p.severity == Rules.Severity.ERROR ? "E:" : "W:") + p.rule;
                got.add(k);
                msgs.put(k, p.message + "  «" + text.substring(p.start, Math.min(p.end, text.length())).replace("\n", " ") + "»");
            }
            System.out.println("== " + web.toPath().relativize(f.toPath()));
            for (String k : got) System.out.println((expected.contains(k) ? "  ok   " : "  MAIS ") + k + "  " + msgs.get(k));
            for (String k : expected) if (!got.contains(k)) { System.out.println("  FALTA " + k); fails++; }
            for (String k : got) if (!expected.contains(k)) fails++;
        }
        System.out.println(fails == 0 ? "TUDO CERTO" : "DIFERENCAS: " + fails);
    }
}
