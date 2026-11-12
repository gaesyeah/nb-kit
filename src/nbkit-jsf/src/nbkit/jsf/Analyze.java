package nbkit.jsf;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

/**
 * Runs the JSF checks on every xhtml of a project, without NetBeans: "nbkit analyze jsf <project>" (lib/analyze.sh).
 * Arguments: the project folder, then the classpath (jars and class folders); the project's own output folders
 * (target/classes...) are found by Workspace. Prints each problem as file:line:column with what the lightbulb would
 * offer, then a summary. Exit code: 0 when it ran (what it found is in the summary), 2 nothing to analyze.
 * -Dnbkit.color=1 colors the output.
 */
public final class Analyze {

    private Analyze() {
    }

    public static void main(String[] args) throws IOException {
        File project = new File(args[0]).getAbsoluteFile();
        List<File> cp = new ArrayList<>();
        for (int i = 1; i < args.length; i++) {
            cp.add(new File(args[i]));
        }
        List<File> files = new ArrayList<>();
        for (File w : Workspace.webrootsOf(project, null)) {
            try (Stream<Path> s = Files.walk(w.toPath())) {
                s.filter(p -> p.toString().endsWith(".xhtml")).sorted().forEach(p -> files.add(p.toFile()));
            }
        }
        if (files.isEmpty()) {
            System.out.println(Msg.t("analyze.none", project));
            System.exit(2);
        }
        boolean color = "1".equals(System.getProperty("nbkit.color"));
        Workspace ws = Workspace.get(files.get(0), cp);
        int[] count = new int[Rules.Severity.values().length];
        int withProblems = 0;
        for (File f : files) {
            String text = Files.readString(f.toPath());
            List<Rules.Problem> ps = Analyzer.run(ws, f, text, Rules.ALL_ON);
            if (ps.isEmpty()) {
                continue;
            }
            withProblems++;
            System.out.println((color ? "\u001b[1m" : "") + project.toPath().relativize(f.toPath()) + (color ? "\u001b[0m" : ""));
            for (Rules.Problem p : ps) {
                count[p.severity.ordinal()]++;
                int line = 1, col = 1;
                for (int i = 0; i < p.start && i < text.length(); i++) {
                    if (text.charAt(i) == '\n') {
                        line++;
                        col = 1;
                    } else {
                        col++;
                    }
                }
                String sev = Msg.t("analyze." + p.severity.name().toLowerCase());
                String paint = !color ? "" : p.severity == Rules.Severity.ERROR ? "\u001b[31m" : p.severity == Rules.Severity.WARNING ? "\u001b[33m" : "\u001b[34m";
                StringBuilder s = new StringBuilder("  ").append(line).append(':').append(col).append("  ")
                        .append(paint).append(sev).append(color ? "\u001b[0m" : "").append("  ").append(p.message)
                        .append("  [").append(p.rule).append(']');
                if (p.replacement != null) {
                    s.append("\n      ").append(Msg.t("replace", p.replacement));
                }
                for (Rules.Target t : p.targets) {
                    Path where = t.file.toPath().toAbsolutePath();
                    s.append("\n      ").append(Msg.t("goto", (where.startsWith(project.toPath()) ? project.toPath().relativize(where) : where) + ":" + t.line));
                }
                System.out.println(s);
            }
        }
        int e = count[Rules.Severity.ERROR.ordinal()];
        System.out.println();
        System.out.println(Msg.t("analyze.summary", files.size(), withProblems, e, count[Rules.Severity.WARNING.ordinal()],
                count[Rules.Severity.INFO.ordinal()]));
        System.exit(0);
    }
}
