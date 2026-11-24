package nbkit.jsf.nb;

import org.openide.modules.ModuleInstall;

/**
 * Module start and exit: the NetBeans rules nbkit replaces (see NetBeansOverrides), NetBeans' JSF support (see
 * NetBeansJsf) and the collection of NetBeans' marks on request (see Collector).
 */
public final class Installer extends ModuleInstall {

    @Override
    public void restored() {
        try {
            NetBeansOverrides.apply();
        } catch (RuntimeException ex) {
            // never breaks NetBeans
        }
        try {
            NetBeansJsf.checkLater();
        } catch (RuntimeException ex) {
            // never breaks NetBeans
        }
        try {
            // NetBeans stopped in the middle of a collection: HTML error checking back to what it was
            nbkit.jsf.NetBeansMarks.restorePending(nbkit.jsf.NetBeansMarks.cache(), Collector::setHtmlChecking);
        } catch (java.io.IOException | RuntimeException ex) {
            // never breaks NetBeans
        }
        try {
            Collector.start();
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
