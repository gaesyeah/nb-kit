package nbkit.jsf.nb;

import java.util.prefs.Preferences;
import org.openide.util.NbPreferences;

/** Liga e desliga cada regra (Tools > Options > Editor > JSF). Tudo ligado por padrao. */
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
