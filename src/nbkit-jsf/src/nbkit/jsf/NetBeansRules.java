package nbkit.jsf;

import java.util.List;

/**
 * NetBeans hint rules that have a pair in nbkit: what the comparison with NetBeans crosses (any other NetBeans rule,
 * like the HTML validator, stays out) and what NetBeansOverrides turns off while the nbkit rule is on. The ids are the
 * ones of the collection (NetBeansMarks: &lt;mime with _&gt;_&lt;rule id&gt;), which are also the names of their preference
 * nodes in NetBeans (csl HintsSettings: org/netbeans/modules/csl/api/&lt;profile&gt;/&lt;id&gt;).
 */
public final class NetBeansRules {

    private NetBeansRules() {
    }

    /** a NetBeans rule, the nbkit rules that check the same, and the nbkit rule that replaces it (null: kept on) */
    public record Pair(String netbeans, List<String> nbkit, String replacedBy) {

        /** the id without the mime: Identifiers, MissingClassRule */
        public String shortName() {
            return netbeans.substring(netbeans.lastIndexOf('_') + 1);
        }

        /** its preference node in NetBeans (where "enabled" is kept) */
        public String preferencesNode() {
            return "org/netbeans/modules/csl/api/default/" + netbeans;
        }
    }

    public static final List<Pair> ALL = List.of(
            new Pair("text_x-el_Identifiers", List.of("el.member", "el.kind"), null),
            new Pair("text_x-el_ResourceBundleKeys", List.of("bundle.key"), null),
            // it only looks at the stylesheets the file itself loads: a class styled in the template's CSS shows as missing
            new Pair("text_html_MissingClassRule", List.of("css.class"), "css.class"));

    /** the pair of a NetBeans rule of the collection, or null when nbkit has none */
    public static Pair of(String netbeansRule) {
        return ALL.stream().filter(p -> p.netbeans().equals(netbeansRule)).findFirst().orElse(null);
    }

    /** the pair whose nbkit rules include this one, or null */
    public static Pair ofNbkit(String nbkitRule) {
        return ALL.stream().filter(p -> p.nbkit().contains(nbkitRule)).findFirst().orElse(null);
    }
}
