package nbkit.jsf.nb;

/**
 * What the module does, when NetBeans starts, about NetBeans' own JSF support (what colors EL and knows JSF in the
 * editor; NetBeans ships it inactive until it is activated in Tools > Plugins). The mark in nbkit's preferences says
 * it was handled once: "activated" (nbkit turned it on) or "found" (it was on already). After that the module never turns it on by itself again: if it is off, it asks, until "Don't ask again".
 * The nbkit uninstall (lib/tools.sh) reads the mark to say what stays on.
 */
final class JsfSupportMark {

    static final String KEY = "netbeans.jsf";
    static final String ACTIVATED = "activated";
    static final String FOUND = "found";
    static final String NO_ASK = "netbeans.jsf.noask";

    enum Action { NOTHING, ACTIVATE, MARK_FOUND, ASK }

    private JsfSupportMark() {
    }

    static Action next(String mark, boolean active, boolean noAsk) {
        if (mark == null) {
            return active ? Action.MARK_FOUND : Action.ACTIVATE;
        }
        return active || noAsk ? Action.NOTHING : Action.ASK;
    }
}
