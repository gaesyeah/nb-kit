package nbkit.jsf.nb;

import org.netbeans.spi.editor.highlighting.HighlightsLayer;
import org.netbeans.spi.editor.highlighting.HighlightsLayerFactory;
import org.netbeans.spi.editor.highlighting.ZOrder;

/**
 * Registered for text/xhtml: NetBeans calls it when each xhtml file opens. It starts following the document; the
 * errors and warnings come out through the same mechanism as the Java hints. Its only layer carries the tooltip of
 * the blue notes (their colors come from the nbkit-jsf-origin annotation type, see OriginNotes).
 */
public final class JsfLayerFactory implements HighlightsLayerFactory {

    @Override
    public HighlightsLayer[] createLayers(Context context) {
        try {
            Watcher.attach(context.getDocument());
            return new HighlightsLayer[]{
                HighlightsLayer.create(OriginNotes.TYPE, ZOrder.SHOW_OFF_RACK, true, OriginNotes.of(context.getDocument()).tips)
            };
        } catch (Throwable ex) {
            // never breaks the editor
            return new HighlightsLayer[0];
        }
    }
}
