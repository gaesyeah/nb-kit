package nbkit.core;

import java.awt.EventQueue;
import java.util.Collections;
import java.util.Map;
import java.util.Set;
import org.netbeans.spi.sendopts.Env;
import org.netbeans.spi.sendopts.Option;
import org.netbeans.spi.sendopts.OptionProcessor;
import org.openide.LifecycleManager;

/**
 * Command line option --nbkit-close: asks the NetBeans instance that is already open to close the normal way
 * (the same as File > Exit), so it asks about unsaved files and running processes itself.
 * nbkit uses this to close NetBeans before changing modules.
 */
public final class CloseOption extends OptionProcessor {

    private static final Option CLOSE = Option.withoutArgument(Option.NO_SHORT_NAME, "nbkit-close");

    @Override
    protected Set<Option> getOptions() {
        return Collections.singleton(CLOSE);
    }

    @Override
    protected void process(Env env, Map<Option, String[]> values) {
        if (values.containsKey(CLOSE)) {
            // outside the command line call, so the launcher that asked can finish
            EventQueue.invokeLater(() -> LifecycleManager.getDefault().exit());
        }
    }
}
