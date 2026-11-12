package nbkit.jsf;

import java.util.Locale;
import java.util.MissingResourceException;
import java.util.ResourceBundle;

/**
 * Texts shown in NetBeans (hints and options page), in the system language:
 * Bundle.properties (English) and Bundle_pt.properties (Portuguese), picked by the default Locale.
 */
public final class Msg {

    private Msg() {
    }

    private static ResourceBundle bundle() {
        return ResourceBundle.getBundle("nbkit.jsf.Bundle", Locale.getDefault(), Msg.class.getClassLoader());
    }

    /** text of the key, with %s placeholders filled in order */
    public static String t(String key, Object... args) {
        String text;
        try {
            text = bundle().getString(key);
        } catch (MissingResourceException e) {
            text = key;
        }
        return args.length == 0 ? text : String.format(text, args);
    }

    /** " Did you mean 'x'?" or empty */
    public static String hint(String hint) {
        return hint == null ? "" : t("hint", hint);
    }

    /** " Did you mean 'x' (where it is)?" or empty; place may be null */
    public static String hint(String hint, String place) {
        // "file, line N (what)" inside the parentheses of the hint: "file, line N, what"
        return hint == null ? "" : place == null ? t("hint", hint) : t("hint.at", hint, place.replaceFirst("^(.*) \\((.*)\\)$", "$1, $2"));
    }
}
