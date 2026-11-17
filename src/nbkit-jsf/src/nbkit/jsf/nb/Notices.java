package nbkit.jsf.nb;

import java.awt.BorderLayout;
import java.awt.FlowLayout;
import javax.swing.Icon;
import javax.swing.JButton;
import javax.swing.JComponent;
import javax.swing.JLabel;
import javax.swing.JPanel;
import org.openide.awt.Notification;
import org.openide.awt.NotificationDisplayer;
import org.openide.util.ImageUtilities;

/**
 * The notifications of nbkit in the corner of NetBeans, in one place: a title, a text and its buttons (NetBeansJsf for
 * NetBeans' JSF support, Collector for the collection of what NetBeans marks).
 */
final class Notices {

    private static final Icon ICON = ImageUtilities.loadImageIcon("nbkit/jsf/origin-glyph.png", false);

    private Notices() {
    }

    /** a button of a notification: clicking it closes the notification, then runs the action */
    record Button(String label, Runnable action) {
    }

    static Notification show(String title, String text, Button... buttons) {
        Notification[] shown = new Notification[1];
        // the balloon and the list of notifications each get their own panel (a component lives in one place)
        shown[0] = NotificationDisplayer.getDefault().notify(title, ICON, panel(text, shown, buttons), panel(text, shown, buttons),
                NotificationDisplayer.Priority.NORMAL);
        return shown[0];
    }

    private static JComponent panel(String text, Notification[] shown, Button... buttons) {
        JPanel row = new JPanel(new FlowLayout(FlowLayout.LEADING, 4, 0));
        row.setOpaque(false);
        for (Button b : buttons) {
            JButton button = new JButton(b.label());
            button.addActionListener(e -> {
                shown[0].clear();
                b.action().run();
            });
            row.add(button);
        }
        JPanel panel = new JPanel(new BorderLayout(0, 4));
        panel.setOpaque(false);
        panel.add(new JLabel(text), BorderLayout.NORTH);
        panel.add(row, BorderLayout.SOUTH);
        return panel;
    }
}
