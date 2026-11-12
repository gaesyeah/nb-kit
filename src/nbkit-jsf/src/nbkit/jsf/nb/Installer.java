package nbkit.jsf.nb;

import org.openide.modules.ModuleInstall;

/** Module start and exit: the NetBeans rules nbkit replaces (see NetBeansOverrides). */
public final class Installer extends ModuleInstall {

    @Override
    public void restored() {
        try {
            NetBeansOverrides.apply();
        } catch (RuntimeException ex) {
            // never breaks NetBeans
        }
    }

    @Override
    public void uninstalled() {
        try {
            NetBeansOverrides.restoreAll();
        } catch (RuntimeException ex) {
            // never breaks NetBeans
        }
    }
}
