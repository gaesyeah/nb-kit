package nbkit.jsf.nb;

import org.netbeans.spi.editor.highlighting.HighlightsLayer;
import org.netbeans.spi.editor.highlighting.HighlightsLayerFactory;

/**
 * Registrado para text/xhtml: o NetBeans chama ao abrir cada xhtml. Nao pinta nada, so passa a
 * acompanhar o documento; os avisos saem pelo mesmo mecanismo das dicas do Java.
 */
public final class JsfLayerFactory implements HighlightsLayerFactory {

    @Override
    public HighlightsLayer[] createLayers(Context context) {
        try {
            Watcher.attach(context.getDocument());
        } catch (Throwable ex) {
            // nunca derruba o editor
        }
        return new HighlightsLayer[0];
    }
}
