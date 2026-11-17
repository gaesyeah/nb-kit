package nbkit.jsf.nb;

import java.util.prefs.Preferences;
import nbkit.jsf.NetBeansRules;
import org.openide.util.NbPreferences;

/**
 * NetBeans hint rules that an nbkit rule replaces (NetBeansRules, replacedBy): while the nbkit rule is on, the NetBeans one is off; when the nbkit
 * rule is turned off, or the module leaves, the NetBeans one goes back to how it was (never neither of the two).
 * How it was is kept in nbkit's preferences as override.&lt;node&gt; = true, false or absent: the nbkit uninstall
 * (lib/tools.sh, tool_module_overrides_back) reads it to put the rules back, since it runs with NetBeans closed.
 */
final class NetBeansOverrides {

    private NetBeansOverrides() {
    }

    static final String ABSENT = "absent";

    /** turns off the NetBeans rules whose nbkit rule is on, and puts back the others */
    static void apply() {
        for (NetBeansRules.Pair p : NetBeansRules.ALL) {
            if (p.replacedBy() != null) {
                set(p.preferencesNode(), Settings.enabled(p.replacedBy()));
            }
        }
    }

    /** puts every NetBeans rule back (the module is leaving) */
    static void restoreAll() {
        for (NetBeansRules.Pair p : NetBeansRules.ALL) {
            if (p.replacedBy() != null) {
                set(p.preferencesNode(), false);
            }
        }
    }

    private static void set(String node, boolean replaced) {
        Preferences rule = NbPreferences.root().node(node);
        Preferences mine = Settings.prefs();
        String key = "override." + node;
        String before = mine.get(key, null);
        if (replaced && before == null) {
            mine.put(key, rule.get("enabled", ABSENT));
            rule.putBoolean("enabled", false);
        } else if (!replaced && before != null) {
            if (before.equals(ABSENT)) {
                rule.remove("enabled");
            } else {
                rule.put("enabled", before);
            }
            mine.remove(key);
        }
    }
}
