package nbkit.jsf.nb;

import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.prefs.Preferences;
import nbkit.jsf.Msg;
import org.netbeans.api.autoupdate.OperationContainer;
import org.netbeans.api.autoupdate.OperationException;
import org.netbeans.api.autoupdate.OperationSupport;
import org.netbeans.api.autoupdate.UpdateElement;
import org.netbeans.api.autoupdate.UpdateManager;
import org.netbeans.api.autoupdate.UpdateUnit;
import org.openide.LifecycleManager;
import org.openide.util.RequestProcessor;

/** Turns NetBeans' JSF support on once, the way Tools > Plugins > Activate does (see JsfSupportMark). */
final class NetBeansJsf {

    /** the "JSF" entry of Tools > Plugins (category Java Web and EE); NetBeans turns on what it needs with it */
    static final String KIT = "org.netbeans.modules.web.jsf.kit";

    private static final Logger LOG = Logger.getLogger(NetBeansJsf.class.getName());
    private static final RequestProcessor RP = new RequestProcessor("nbkit JSF support", 1, false);

    private NetBeansJsf() {
    }

    /** after NetBeans has started: the list of modules is complete then */
    static void checkLater() {
        RP.create(() -> {
            try {
                check();
            } catch (RuntimeException ex) {
                LOG.log(Level.INFO, "nbkit: NetBeans' JSF support not checked", ex);
            }
        }).schedule(5000);
    }

    private static void check() {
        UpdateElement kit = installed();
        if (kit == null) {
            return; // this NetBeans has no JSF support to turn on
        }
        Preferences prefs = Settings.prefs();
        switch (JsfSupportMark.next(prefs.get(JsfSupportMark.KEY, null), kit.isEnabled(),
                prefs.getBoolean(JsfSupportMark.NO_ASK, false))) {
            case MARK_FOUND -> prefs.put(JsfSupportMark.KEY, JsfSupportMark.FOUND);
            case ACTIVATE -> activate(kit);
            case ASK -> ask(kit);
            default -> {
            }
        }
    }

    private static UpdateElement installed() {
        for (UpdateUnit unit : UpdateManager.getDefault().getUpdateUnits()) {
            if (KIT.equals(unit.getCodeName())) {
                return unit.getInstalled();
            }
        }
        return null;
    }

    /** turns it on, writes the mark and offers the restart (files keep no EL colors until NetBeans restarts) */
    private static void activate(UpdateElement kit) {
        try {
            OperationContainer<OperationSupport> container = OperationContainer.createForEnable();
            OperationContainer.OperationInfo<OperationSupport> info = container.add(kit);
            if (info == null) {
                return;
            }
            container.add(info.getRequiredElements());
            OperationSupport support = container.getSupport();
            if (support == null) {
                LOG.info("nbkit: NetBeans' JSF support cannot be turned on (missing modules)");
                return;
            }
            OperationSupport.Restarter restarter = support.doOperation(null);
            Settings.prefs().put(JsfSupportMark.KEY, JsfSupportMark.ACTIVATED);
            if (restarter != null) {
                support.doRestartLater(restarter);
            }
            Notices.show(Msg.t("netbeans.jsf.activated.title"), Msg.t("netbeans.jsf.activated"),
                    new Notices.Button(Msg.t("netbeans.jsf.activated.restart"), () -> {
                        // NetBeans asks about unsaved files before closing, as always
                        LifecycleManager.getDefault().markForRestart();
                        LifecycleManager.getDefault().exit();
                    }));
        } catch (OperationException ex) {
            LOG.log(Level.INFO, "nbkit: NetBeans' JSF support could not be turned on", ex);
        }
    }

    /** it was turned off after the mark: asks (closing the notification asks again on the next start) */
    private static void ask(UpdateElement kit) {
        Notices.show(Msg.t("netbeans.jsf.ask.title"), Msg.t("netbeans.jsf.ask"),
                new Notices.Button(Msg.t("netbeans.jsf.ask.activate"), () -> RP.create(() -> activate(kit)).schedule(0)),
                new Notices.Button(Msg.t("netbeans.jsf.ask.never"), () -> Settings.prefs().putBoolean(JsfSupportMark.NO_ASK, true)));
    }
}
