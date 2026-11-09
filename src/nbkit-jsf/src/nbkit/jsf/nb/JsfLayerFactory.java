package nbkit.jsf.nb;

import org.netbeans.spi.editor.highlighting.HighlightsLayer;
import org.netbeans.spi.editor.highlighting.HighlightsLayerFactory;

/**
 * Registered for text/xhtml: NetBeans calls it when each xhtml file opens. It paints nothing, it only starts
 * following the document; the warnings come out through the same mechanism as the Java hints.
 */
public final class JsfLayerFactory implements HighlightsLayerFactory {

    @Override
    public HighlightsLayer[] createLayers(Context context) {
        try {
            Watcher.attach(context.getDocument());
        } catch (Throwable ex) {
            // never breaks the editor
        }
        return new HighlightsLayer[0];
    }
}
