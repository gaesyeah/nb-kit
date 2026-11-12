package nbkit.jsf.nb;

import java.util.prefs.Preferences;
import org.openide.util.NbPreferences;

/**
 * NetBeans hint rules that an nbkit rule replaces: while the nbkit rule is on, the NetBeans one is off; when the nbkit
 * rule is turned off, or the module leaves, the NetBeans one goes back to how it was (never neither of the two).
 * How it was is kept in nbkit's preferences as override.&lt;node&gt; = true, false or absent: the nbkit uninstall
 * (lib/tools.sh, tool_module_overrides_back) reads it to put the rules back, since it runs with NetBeans closed.
 */
final class NetBeansOverrides {

    private NetBeansOverrides() {
    }

    /**
     * { preferences node of the NetBeans rule, the nbkit rule that replaces it }. The rules of the HTML/CSS editor
     * (csl hints) keep "enabled" in org/netbeans/modules/csl/api/&lt;profile&gt;/&lt;language&gt;_&lt;rule class&gt;
     * (csl HintsSettings, html.editor HtmlRule.getId)
     */
    static final String[][] TABLE = {
        // only looks at the stylesheets the file itself loads: a class styled in the template's CSS shows as missing
        {"org/netbeans/modules/csl/api/default/text_html_MissingClassRule", "css.class"},
    };

    static final String ABSENT = "absent";

    /** turns off the NetBeans rules whose nbkit rule is on, and puts back the others */
    static void apply() {
        for (String[] o : TABLE) {
            set(o[0], Settings.enabled(o[1]));
        }
    }

    /** puts every NetBeans rule back (the module is leaving) */
    static void restoreAll() {
        for (String[] o : TABLE) {
            set(o[0], false);
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
