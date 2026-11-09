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
 * Opcao de linha de comando --nbkit-close: pede para o NetBeans que ja esta aberto fechar pelo caminho normal
 * (o mesmo de File > Exit), entao ele mesmo pergunta sobre arquivos nao salvos e processos rodando.
 * O nbkit usa isso para fechar o NetBeans antes de atualizar o tema.
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
            // fora da chamada da linha de comando, para o launcher que pediu poder terminar
            EventQueue.invokeLater(() -> LifecycleManager.getDefault().exit());
        }
    }
}
