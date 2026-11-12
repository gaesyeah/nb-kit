package nbkit.jsf.nb;

import org.netbeans.spi.editor.highlighting.HighlightsLayer;
import org.netbeans.spi.editor.highlighting.HighlightsLayerFactory;
import org.netbeans.spi.editor.highlighting.ZOrder;

/**
 * Registered for text/xhtml: NetBeans calls it when each xhtml file opens. It starts following the document; the
 * errors and warnings come out through the same mechanism as the Java hints. Its only layer carries the wave, the
 * see-through background and the tooltip of the blue notes (see OriginNotes).
 */
public final class JsfLayerFactory implements HighlightsLayerFactory {

    @Override
    public HighlightsLayer[] createLayers(Context context) {
        try {
            Watcher.attach(context.getDocument());
            OriginNotes notes = OriginNotes.of(context.getDocument());
            if (context.getComponent().getBackground() != null) {
                notes.editorBackground = context.getComponent().getBackground();
            }
            return new HighlightsLayer[]{
                HighlightsLayer.create(OriginNotes.TYPE, ZOrder.SHOW_OFF_RACK, true, notes.tips)
            };
        } catch (Throwable ex) {
            // never breaks the editor
            return new HighlightsLayer[0];
        }
    }
}
