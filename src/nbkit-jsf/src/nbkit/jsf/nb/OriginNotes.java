package nbkit.jsf.nb;

import nbkit.jsf.Rules;
import java.awt.Color;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.WeakHashMap;
import javax.swing.SwingUtilities;
import javax.swing.text.Document;
import javax.swing.text.StyleConstants;
import org.netbeans.api.editor.settings.AttributesUtilities;
import org.netbeans.api.editor.settings.EditorStyleConstants;
import org.netbeans.spi.editor.highlighting.support.OffsetsBag;

/**
 * The look of the blue notes (Severity.INFO) on the text: blue wave, see-through blue background and the text as a
 * tooltip, through the highlights layer JsfLayerFactory registers with the bag below. The icon, the mark on the right
 * stripe and Alt+Enter come from the hints (Watcher), with the annotation types nbkit-jsf-origin and, when the note
 * has "Go to" actions, nbkit-jsf-origin-fixable (the NetBeans lightbulb with a blue badge), or their -quiet versions.
 * The background is mixed with the editor's own (an annotation type only takes one fixed color, too light on a dark
 * theme). How see-through each part is: QuietNotes.
 */
final class OriginNotes {

    static final String TYPE = "nbkit-jsf-origin";
    static final String TYPE_FIXABLE = "nbkit-jsf-origin-fixable";
    static final Color BLUE = new Color(0x3F8EE3);
    private static final Map<Document, OriginNotes> ALL = Collections.synchronizedMap(new WeakHashMap<>());

    final OffsetsBag tips;
    /** the editor's background, from the component the layer was made for */
    volatile Color editorBackground = Color.WHITE;

    private OriginNotes(Document d) {
        tips = new OffsetsBag(d);
    }

    static OriginNotes of(Document d) {
        return ALL.computeIfAbsent(d, OriginNotes::new);
    }

    /** replaces the notes of the document, on the AWT thread like the editor's own highlights */
    static void set(Document d, List<Rules.Problem> notes) {
        OriginNotes o = of(d);
        SwingUtilities.invokeLater(() -> o.apply(d, notes));
    }

    private void apply(Document d, List<Rules.Problem> notes) {
        OffsetsBag fresh = new OffsetsBag(d);
        Color back = mix(editorBackground, BLUE, QuietNotes.background());
        Color wave = QuietNotes.wave(editorBackground);
        int len = d.getLength();
        for (Rules.Problem p : notes) {
            int s = Math.min(p.start, len), e = Math.min(p.end, len);
            fresh.addHighlight(s, e, AttributesUtilities.createImmutable(StyleConstants.Background, back,
                    EditorStyleConstants.WaveUnderlineColor, wave, EditorStyleConstants.Tooltip, p.message));
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
