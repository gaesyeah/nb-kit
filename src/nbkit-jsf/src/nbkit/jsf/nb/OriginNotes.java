package nbkit.jsf.nb;

import nbkit.jsf.Rules;
import java.awt.Color;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.WeakHashMap;
import javax.swing.SwingUtilities;
import javax.swing.text.BadLocationException;
import javax.swing.text.Document;
import javax.swing.text.StyleConstants;
import javax.swing.text.StyledDocument;
import org.netbeans.api.editor.settings.AttributesUtilities;
import org.netbeans.api.editor.settings.EditorStyleConstants;
import org.netbeans.spi.editor.highlighting.support.OffsetsBag;
import org.openide.text.Annotation;
import org.openide.text.NbDocument;

/**
 * The blue notes (Severity.INFO): one annotation of type nbkit-jsf-origin per note, which gives the icon and the mark
 * on the right stripe, plus, through the highlights layer JsfLayerFactory registers with the bag below, the blue wave,
 * a see-through blue background and the text as a tooltip on the name itself. The background is mixed with the
 * editor's own (an annotation type only takes one fixed color, too light on a dark theme, too strong on a light one).
 */
final class OriginNotes {

    static final String TYPE = "nbkit-jsf-origin";
    static final Color BLUE = new Color(0x3F8EE3);
    private static final Map<Document, OriginNotes> ALL = Collections.synchronizedMap(new WeakHashMap<>());

    final OffsetsBag tips;
    /** the editor's background, from the component the layer was made for */
    volatile Color editorBackground = Color.WHITE;
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
        Color back = mix(editorBackground, BLUE, 0.1); // as see-through as the theme warnings: about 10% of their wave color
        int len = d.getLength();
        for (Rules.Problem p : notes) {
            int s = Math.min(p.start, len), e = Math.min(p.end, len);
            try {
                Note n = new Note(p.message);
                NbDocument.addAnnotation(d, d.createPosition(s), e - s, n);
                shown.add(n);
                fresh.addHighlight(s, e, AttributesUtilities.createImmutable(StyleConstants.Background, back,
                        EditorStyleConstants.WaveUnderlineColor, BLUE, EditorStyleConstants.Tooltip, p.message));
            } catch (BadLocationException ex) {
                // the document changed midway: the next analysis fixes it
            }
        }
        tips.setHighlights(fresh);
    }

    /** a over b at the given share of b: a see-through b on top of a */
    static Color mix(Color a, Color b, double share) {
        return new Color((int) Math.round(a.getRed() * (1 - share) + b.getRed() * share),
                (int) Math.round(a.getGreen() * (1 - share) + b.getGreen() * share),
                (int) Math.round(a.getBlue() * (1 - share) + b.getBlue() * share));
    }
}
