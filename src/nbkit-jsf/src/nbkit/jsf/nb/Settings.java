package nbkit.jsf.nb;

import java.util.prefs.Preferences;
import org.openide.util.NbPreferences;

/** Turns each rule on and off (Tools > Options > Editor > JSF). Everything on by default. */
final class Settings {

    private Settings() {
    }

    static Preferences prefs() {
        return NbPreferences.forModule(Settings.class);
    }

    static boolean enabled(String rule) {
        try {
            return prefs().getBoolean(rule, true);
        } catch (RuntimeException ex) {
            return true;
        }
    }
}
