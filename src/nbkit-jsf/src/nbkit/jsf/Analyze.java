package nbkit.jsf;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Runs the JSF checks on every xhtml of a project, without NetBeans: "nbkit analyze jsf <project>" (lib/analyze.sh).
 * Arguments: the project folder, then the classpath (jars and class folders); the project's own output folders
 * (target/classes...) are found by Workspace. Prints each problem as file:line:column with what the lightbulb would
 * offer, then a summary. -Dnbkit.explain=<file> analyzes only the files whose path ends with it and also says how
 * each name of the EL was resolved (its type at each step, and where and why the checking stopped). Exit code: 0 when it ran (what it found is in the summary), 2 nothing to analyze.
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
        List<File> files = Workspace.pages(project);
        if (files.isEmpty()) {
            System.out.println(Msg.t("analyze.none", project));
            System.exit(2);
        }
        boolean color = "1".equals(System.getProperty("nbkit.color"));
        String explain = System.getProperty("nbkit.explain");
        if (explain != null) {
            String want = explain.replace('\\', '/');
            files.removeIf(f -> !f.getPath().replace('\\', '/').endsWith(want.startsWith("/") ? want : "/" + want));
            if (files.isEmpty()) {
                System.out.println(Msg.t("explain.none", project, explain));
                System.exit(2);
            }
        }
        Workspace ws = Workspace.get(files.get(0), cp);
        // what was not checked, by reason: "<message>  [<rule>]" -> "file:line:col" of each
        Map<String, List<String>> notChecked = new LinkedHashMap<>();
        Map<String, Rules.SkipGroup> groupOf = new HashMap<>();
        int[] count = new int[Rules.Severity.values().length];
        int withProblems = 0;
        for (File f : files) {
            String text = Files.readString(f.toPath());
            List<Analyzer.Explained> how = explain == null ? null : new ArrayList<>();
            Analyzer.Result res = Analyzer.analyze(ws, f, text, Rules.ALL_ON, how);
            List<Rules.Problem> ps = res.problems;
            for (Rules.Skipped k : res.skipped) {
                int[] lc = lineCol(text, k.start);
                String key = k.message + "  [" + k.rule + "]";
                notChecked.computeIfAbsent(key, x -> new ArrayList<>()).add(project.toPath().relativize(f.toPath()) + ":" + lc[0] + ":" + lc[1]);
                groupOf.put(key, k.group);
            }
            if (!ps.isEmpty()) {
                withProblems++;
                System.out.println((color ? "\u001b[1m" : "") + project.toPath().relativize(f.toPath()) + (color ? "\u001b[0m" : ""));
                for (Rules.Problem p : ps) {
                    count[p.severity.ordinal()]++;
                    int[] lc = lineCol(text, p.start);
                    int line = lc[0], col = lc[1];
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
            if (how != null) {
                System.out.println();
                System.out.println((color ? "\u001b[1m" : "") + Msg.t("explain.header", project.toPath().relativize(f.toPath())) + (color ? "\u001b[0m" : ""));
                for (Analyzer.Explained x : how) {
                    int[] lc = lineCol(text, x.offset);
                    System.out.println("  " + lc[0] + ":" + lc[1] + "  #{" + x.expr + "}\n      " + x.steps);
                }
                System.out.println();
                if (!res.skipped.isEmpty()) {
                    System.out.println((color ? "\u001b[1m" : "") + Msg.t("skip.file") + (color ? "\u001b[0m" : ""));
                    for (Rules.Skipped k : res.skipped) {
                        int[] lc = lineCol(text, k.start);
                        System.out.println("  " + lc[0] + ":" + lc[1] + "  [" + k.rule + "]  " + k.message + "  «"
                                + text.substring(k.start, Math.min(k.end, text.length())).replace('\n', ' ') + "»");
                    }
                    System.out.println();
                }
            }
        }
        int e = count[Rules.Severity.ERROR.ordinal()];
        System.out.println();
        System.out.println(Msg.t("analyze.summary", files.size(), withProblems, e, count[Rules.Severity.WARNING.ordinal()],
                count[Rules.Severity.INFO.ordinal()]));
        if (explain == null) {
            printNotChecked(notChecked, groupOf, project, color);
        }
        System.exit(0);
    }

    /**
     * what was not checked, by group and then by reason (most first), with up to 20 places each; when a list is cut,
     * how to see everything of one file
     */
    static void printNotChecked(Map<String, List<String>> notChecked, Map<String, Rules.SkipGroup> groupOf, File project, boolean color) {
        if (notChecked.isEmpty()) {
            return;
        }
        int[] per = new int[Rules.SkipGroup.values().length];
        notChecked.forEach((k, l) -> per[groupOf.get(k).ordinal()] += l.size());
        System.out.println();
        System.out.println((color ? "\u001b[1m" : "") + Msg.t("skip.header", per[0] + per[1], per[Rules.SkipGroup.STATIC.ordinal()],
                per[Rules.SkipGroup.GAP.ordinal()]) + (color ? "\u001b[0m" : ""));
        boolean cut = false;
        for (Rules.SkipGroup g : Rules.SkipGroup.values()) {
            List<String> keys = notChecked.keySet().stream().filter(k -> groupOf.get(k) == g)
                    .sorted((a, b) -> notChecked.get(b).size() - notChecked.get(a).size()).toList();
            if (keys.isEmpty()) {
                continue;
            }
            System.out.println("  " + Msg.t("skip.group." + g.name()));
            for (String k : keys) {
                List<String> where = notChecked.get(k);
                System.out.println("    " + k + ": " + where.size());
                for (String w : where.subList(0, Math.min(20, where.size()))) {
                    System.out.println("      " + w);
                }
                if (where.size() > 20) {
                    System.out.println("      " + Msg.t("skip.more", where.size() - 20));
                    cut = true;
                }
            }
        }
        if (cut) {
            System.out.println("  " + Msg.t("skip.howto", project));
        }
    }

    static int[] lineCol(String text, int offset) {
        int line = 1, col = 1;
        for (int i = 0; i < offset && i < text.length(); i++) {
            if (text.charAt(i) == '\n') {
                line++;
                col = 1;
            } else {
                col++;
            }
        }
        return new int[]{line, col};
    }
}
