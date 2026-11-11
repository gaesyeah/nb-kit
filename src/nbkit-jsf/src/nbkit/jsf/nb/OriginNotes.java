package nbkit.jsf.nb;

import nbkit.jsf.Rules;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.WeakHashMap;
import javax.swing.SwingUtilities;
import javax.swing.text.BadLocationException;
import javax.swing.text.Document;
import javax.swing.text.StyledDocument;
import org.netbeans.api.editor.settings.AttributesUtilities;
import org.netbeans.api.editor.settings.EditorStyleConstants;
import org.netbeans.spi.editor.highlighting.support.OffsetsBag;
import org.openide.text.Annotation;
import org.openide.text.NbDocument;

/**
 * The blue notes (Severity.INFO): one annotation of type nbkit-jsf-origin per note, which gives the icon, the light
 * background, the wave and the mark on the right stripe (colors in Fonts & Colors > Annotations), plus the text as a
 * tooltip on the name itself, through the highlights layer JsfLayerFactory registers with the bag below.
 */
final class OriginNotes {

    static final String TYPE = "nbkit-jsf-origin";
    private static final Map<Document, OriginNotes> ALL = Collections.synchronizedMap(new WeakHashMap<>());

    final OffsetsBag tips;
    private final List<Annotation> shown = new ArrayList<>();

    private OriginNotes(Document d) {
        tips = new OffsetsBag(d);
    }

    static OriginNotes of(Document d) {
        return ALL.computeIfAbsent(d, OriginNotes::new);
    }

    static final class Note extends Annotation {

        private final String text;

        Note(String text) {
            this.text = text;
        }

        @Override
        public String getAnnotationType() {
            return TYPE;
        }

        @Override
        public String getShortDescription() {
            return text;
        }
    }

    /** replaces the notes of the document; on the AWT thread, like the editor's own annotations */
    static void set(Document d, List<Rules.Problem> notes) {
        if (!(d instanceof StyledDocument)) {
            return;
        }
        OriginNotes o = of(d);
        SwingUtilities.invokeLater(() -> o.apply((StyledDocument) d, notes));
    }

    private void apply(StyledDocument d, List<Rules.Problem> notes) {
        for (Annotation a : shown) {
            NbDocument.removeAnnotation(d, a);
        }
        shown.clear();
        OffsetsBag fresh = new OffsetsBag(d);
        int len = d.getLength();
        for (Rules.Problem p : notes) {
            int s = Math.min(p.start, len), e = Math.min(p.end, len);
            try {
                Note n = new Note(p.message);
                NbDocument.addAnnotation(d, d.createPosition(s), e - s, n);
                shown.add(n);
                fresh.addHighlight(s, e, AttributesUtilities.createImmutable(EditorStyleConstants.Tooltip, p.message));
            } catch (BadLocationException ex) {
                // the document changed midway: the next analysis fixes it
            }
        }
        tips.setHighlights(fresh);
    }
}
