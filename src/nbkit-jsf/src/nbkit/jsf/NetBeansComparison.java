package nbkit.jsf;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Crosses one page's nbkit result (problems, skipped and how each EL name was resolved) with what NetBeans marks on
 * it (NetBeansMarks), by place, for the NetBeans rules that have a pair in nbkit (NetBeansRules). Fully automatic: no
 * known case is written by hand.
 */
public final class NetBeansComparison {

    private NetBeansComparison() {
    }

    /** what a crossing says: both mark it, NetBeans is wrong (nbkit resolved it), NetBeans catches what nbkit skipped, only nbkit marks it, or NetBeans did not run that rule */
    public enum Category { AGREE, NETBEANS_FALSE_POSITIVE, NETBEANS_CATCHES_SKIPPED, NBKIT_ONLY, NOT_COLLECTED }

    /**
     * One crossing at a place: the NetBeans rule (short id, e.g. Identifiers) and its message (null when only nbkit has
     * something there), the nbkit rule and its message or the skipped reason (null when nbkit has nothing), the category,
     * and why nbkit says otherwise (from the steps of --explain)
     */
    public record Match(String file, int start, int end, String netbeansRule, String netbeansMessage, String nbkitRule,
            String nbkitMessage, String skipReason, Category category, String why) {
    }

    /** notRun: NetBeansMarks.notRun of the collection, the NetBeans rules that did not run at all */
    public static List<Match> compare(String file, Analyzer.Result r, List<NetBeansMarks.Mark> marks,
            Map<String, String> notRun) {
        List<Match> out = new ArrayList<>();
        List<Rules.Problem> found = new ArrayList<>();
        for (Rules.Problem p : r.problems) {
            NetBeansRules.Pair pair = NetBeansRules.ofNbkit(p.rule);
            // what nbkit marks: an error, a warning or a note with a close name (a typo); not where a name comes from
            if (pair != null && (p.severity != Rules.Severity.INFO || p.replacement != null)) {
                found.add(p);
            }
        }
        List<Rules.Problem> matched = new ArrayList<>();
        for (NetBeansMarks.Mark m : marks) {
            NetBeansRules.Pair pair = NetBeansRules.of(m.rule());
            if (pair == null || !m.file().equals(file)) {
                continue;
            }
            Rules.Problem same = found.stream().filter(p -> pair.nbkit().contains(p.rule) && overlaps(p.start, p.end, m)).findFirst().orElse(null);
            if (same != null) {
                matched.add(same);
                out.add(entry(file, m, pair, same.rule, same.message, null, Category.AGREE, null));
                continue;
            }
            Rules.Skipped skip = r.skipped.stream().filter(k -> overlaps(k.start, k.end, m)).findFirst().orElse(null);
            if (skip != null && !skip.reason.equals("el.impl")) {
                out.add(entry(file, m, pair, skip.rule, skip.message, skip.reason, Category.NETBEANS_CATCHES_SKIPPED, null));
                continue;
            }
            // nbkit resolved it: why, from how it did (or where the class comes from)
            String why = skip != null ? Msg.t("why.impl") : whyAt(r, m);
            out.add(entry(file, m, pair, null, null, null, Category.NETBEANS_FALSE_POSITIVE, why));
        }
        for (Rules.Problem p : found) {
            if (matched.contains(p)) {
                continue;
            }
            NetBeansRules.Pair pair = NetBeansRules.ofNbkit(p.rule);
            boolean notCollected = notRun.keySet().stream().anyMatch(prefix -> pair.netbeans().startsWith(prefix));
            out.add(new Match(file, p.start, p.end, notCollected ? pair.shortName() : null, null, p.rule, p.message, null,
                    notCollected ? Category.NOT_COLLECTED : Category.NBKIT_ONLY,
                    notCollected ? notRun.entrySet().stream().filter(e -> pair.netbeans().startsWith(e.getKey())).findFirst().get().getValue() : null));
        }
        out.sort((a, b) -> Integer.compare(a.start(), b.start()));
        return out;
    }

    static boolean overlaps(int start, int end, NetBeansMarks.Mark m) {
        return start < Math.max(m.end(), m.start() + 1) && m.start() < end;
    }

    private static Match entry(String file, NetBeansMarks.Mark m, NetBeansRules.Pair pair, String nbkitRule,
            String nbkitMessage, String skip, Category c, String why) {
        return new Match(file, m.start(), m.end(), pair.shortName(), m.message(), nbkitRule, nbkitMessage, skip, c, why);
    }

    /** "text literal inside a method argument: 'a': String -> concat(): String", or the note nbkit has there */
    static String whyAt(Analyzer.Result r, NetBeansMarks.Mark m) {
        if (r.explained != null) {
            for (Analyzer.Explained x : r.explained) {
                if (x.offset <= m.start() && m.start() < Math.max(x.end, x.offset + 1)) {
                    return (x.kind == null ? Msg.t("why.plain") : Msg.t("why." + x.kind)) + ": " + x.steps;
                }
            }
        }
        for (Rules.Problem p : r.problems) {
            if (overlaps(p.start, p.end, m)) {
                return p.message;
            }
        }
        return Msg.t("why.nothing");
    }
}
