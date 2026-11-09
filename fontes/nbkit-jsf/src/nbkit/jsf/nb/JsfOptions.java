package nbkit.jsf.nb;

import nbkit.jsf.Rules;
import java.awt.BorderLayout;
import java.awt.GridLayout;
import java.beans.PropertyChangeListener;
import java.beans.PropertyChangeSupport;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JComponent;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import org.netbeans.spi.options.OptionsPanelController;
import org.openide.util.HelpCtx;
import org.openide.util.Lookup;

/** Aba "JSF" em Tools > Options > Editor: uma caixa por regra. */
public final class JsfOptions extends OptionsPanelController {

    private final PropertyChangeSupport pcs = new PropertyChangeSupport(this);
    private final Map<String, JCheckBox> boxes = new LinkedHashMap<>();
    private JPanel panel;

    private JPanel panel() {
        if (panel == null) {
            JPanel list = new JPanel(new GridLayout(0, 1, 0, 2));
            for (Map.Entry<String, String> e : Rules.ALL.entrySet()) {
                JCheckBox b = new JCheckBox(e.getValue());
                b.addActionListener(a -> pcs.firePropertyChange(PROP_CHANGED, false, true));
                boxes.put(e.getKey(), b);
                list.add(b);
            }
            JPanel buttons = new JPanel(new GridLayout(1, 2, 6, 0));
            JButton all = new JButton("Marcar todas");
            all.addActionListener(a -> setAll(true));
            JButton none = new JButton("Desmarcar todas");
            none.addActionListener(a -> setAll(false));
            buttons.add(all);
            buttons.add(none);
            JPanel top = new JPanel(new BorderLayout(0, 6));
            top.add(new JLabel("<html>Verificações de xhtml (JSF, Facelets e PrimeFaces) do nbkit.<br>"
                    + "Vermelho: quebra com certeza. Amarelo: provável erro, ou depende de algo fora do arquivo.</html>"), BorderLayout.NORTH);
            JPanel bl = new JPanel(new BorderLayout());
            bl.add(buttons, BorderLayout.WEST);
            top.add(bl, BorderLayout.SOUTH);
            panel = new JPanel(new BorderLayout(0, 8));
            panel.setBorder(BorderFactory.createEmptyBorder(8, 8, 8, 8));
            panel.add(top, BorderLayout.NORTH);
            panel.add(new JScrollPane(list), BorderLayout.CENTER);
        }
        return panel;
    }

    private void setAll(boolean v) {
        for (JCheckBox b : boxes.values()) {
            b.setSelected(v);
        }
        pcs.firePropertyChange(PROP_CHANGED, false, true);
    }

    @Override
    public void update() {
        panel();
        for (Map.Entry<String, JCheckBox> e : boxes.entrySet()) {
            e.getValue().setSelected(Settings.enabled(e.getKey()));
        }
    }

    @Override
    public void applyChanges() {
        for (Map.Entry<String, JCheckBox> e : boxes.entrySet()) {
            Settings.prefs().putBoolean(e.getKey(), e.getValue().isSelected());
        }
        Watcher.rescheduleAll();
    }

    @Override
    public void cancel() {
    }

    @Override
    public boolean isValid() {
        return true;
    }

    @Override
    public boolean isChanged() {
        for (Map.Entry<String, JCheckBox> e : boxes.entrySet()) {
            if (e.getValue().isSelected() != Settings.enabled(e.getKey())) {
                return true;
            }
        }
        return false;
    }

    @Override
    public JComponent getComponent(Lookup masterLookup) {
        return panel();
    }

    @Override
    public HelpCtx getHelpCtx() {
        return null;
    }

    @Override
    public void addPropertyChangeListener(PropertyChangeListener l) {
        pcs.addPropertyChangeListener(l);
    }

    @Override
    public void removePropertyChangeListener(PropertyChangeListener l) {
        pcs.removePropertyChangeListener(l);
    }
}
