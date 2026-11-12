package nbkit.jsf.nb;

import java.awt.BorderLayout;
import java.awt.FlowLayout;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.prefs.Preferences;
import javax.swing.Icon;
import javax.swing.JButton;
import javax.swing.JComponent;
import javax.swing.JLabel;
import javax.swing.JPanel;
import nbkit.jsf.Msg;
import org.netbeans.api.autoupdate.OperationContainer;
import org.netbeans.api.autoupdate.OperationException;
import org.netbeans.api.autoupdate.OperationSupport;
import org.netbeans.api.autoupdate.UpdateElement;
import org.netbeans.api.autoupdate.UpdateManager;
import org.netbeans.api.autoupdate.UpdateUnit;
import org.openide.LifecycleManager;
import org.openide.awt.Notification;
import org.openide.awt.NotificationDisplayer;
import org.openide.util.ImageUtilities;
import org.openide.util.RequestProcessor;

/** Turns NetBeans' JSF support on once, the way Tools > Plugins > Activate does (see JsfSupportMark). */
final class NetBeansJsf {

    /** the "JSF" entry of Tools > Plugins (category Java Web and EE); NetBeans turns on what it needs with it */
    static final String KIT = "org.netbeans.modules.web.jsf.kit";

    private static final Logger LOG = Logger.getLogger(NetBeansJsf.class.getName());
    private static final RequestProcessor RP = new RequestProcessor("nbkit JSF support", 1, false);
    private static final Icon ICON = ImageUtilities.loadImageIcon("nbkit/jsf/origin-glyph.png", false);

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
            Notification[] shown = new Notification[1];
            shown[0] = NotificationDisplayer.getDefault().notify(Msg.t("netbeans.jsf.activated.title"), ICON,
                    restartPanel(shown), restartPanel(shown), NotificationDisplayer.Priority.NORMAL);
        } catch (OperationException ex) {
            LOG.log(Level.INFO, "nbkit: NetBeans' JSF support could not be turned on", ex);
        }
    }

    private static JComponent restartPanel(Notification[] shown) {
        JButton restart = new JButton(Msg.t("netbeans.jsf.activated.restart"));
        restart.addActionListener(e -> {
            shown[0].clear();
            // NetBeans asks about unsaved files before closing, as always
            LifecycleManager.getDefault().markForRestart();
            LifecycleManager.getDefault().exit();
        });
        return panel(Msg.t("netbeans.jsf.activated"), restart);
    }

    /** it was turned off after the mark: asks (closing the notification asks again on the next start) */
    private static void ask(UpdateElement kit) {
        Notification[] shown = new Notification[1];
        shown[0] = NotificationDisplayer.getDefault().notify(Msg.t("netbeans.jsf.ask.title"), ICON,
                askPanel(kit, shown), askPanel(kit, shown), NotificationDisplayer.Priority.NORMAL);
    }

    private static JComponent askPanel(UpdateElement kit, Notification[] shown) {
        JButton activate = new JButton(Msg.t("netbeans.jsf.ask.activate"));
        activate.addActionListener(e -> {
            shown[0].clear();
            RP.create(() -> activate(kit)).schedule(0);
        });
        JButton never = new JButton(Msg.t("netbeans.jsf.ask.never"));
        never.addActionListener(e -> {
            shown[0].clear();
            Settings.prefs().putBoolean(JsfSupportMark.NO_ASK, true);
        });
        return panel(Msg.t("netbeans.jsf.ask"), activate, never);
    }

    private static JComponent panel(String text, JButton... actions) {
        JPanel buttons = new JPanel(new FlowLayout(FlowLayout.LEADING, 4, 0));
        buttons.setOpaque(false);
        for (JButton action : actions) {
            buttons.add(action);
        }
        JPanel panel = new JPanel(new BorderLayout(0, 4));
        panel.setOpaque(false);
        panel.add(new JLabel(text), BorderLayout.NORTH);
        panel.add(buttons, BorderLayout.SOUTH);
        return panel;
    }
}
