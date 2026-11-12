package nbkit.jsf.nb;

import java.awt.Color;
import org.netbeans.editor.AnnotationType;
import org.netbeans.editor.AnnotationTypes;

/**
 * How loud the blue notes are, in one place. Discreet (Tools > Options > Editor > JSF, "Discreet blue notes"; default
 * below) makes all four parts more see-through by the shares below, each through the only way NetBeans leaves for it:
 * background and wave are mixed with the editor background here (OriginNotes draws them); the icons are the -quiet
 * PNGs, half see-through, of the annotation types nbkit-jsf-origin(-fixable)-quiet; the mark on the right stripe gets a
 * color with alpha here, since annotation type files take no alpha (Color.decode) but the stripe paints whatever
 * color the type has (editor.errorstripe AnnotationView).
 */
final class QuietNotes {

    /** default of the option */
    static final boolean DEFAULT = true;
    /** blue of the background when not discreet: as see-through as the theme warnings, about 10% of their wave color */
    static final double BACKGROUND = 0.1;
    /** share of that background blue kept when discreet (0.5: half, 50% more see-through) */
    static final double BACKGROUND_KEPT = 0.5;
    /** opacity of each part when discreet (1: as when not discreet); the -quiet icons were made with ICONS (alpha of
     *  origin-glyph.png and origin-fixable-glyph.png times 0.25) */
    static final double WAVE = 0.25;
    static final double ICONS = 0.25;
    static final double STRIPE = 0.1;

    static final String KEY = "notes.quiet";

    private QuietNotes() {
    }

    static boolean on() {
        return Settings.prefs().getBoolean(KEY, DEFAULT);
    }

    /** share of blue in the background */
    static double background() {
        return on() ? BACKGROUND * BACKGROUND_KEPT : BACKGROUND;
    }

    static Color wave(Color editorBackground) {
        return on() ? OriginNotes.mix(editorBackground, OriginNotes.BLUE, WAVE) : OriginNotes.BLUE;
    }

    /** annotation type of a note (icon and stripe mark) */
    static String type(boolean fixable) {
        String type = fixable ? OriginNotes.TYPE_FIXABLE : OriginNotes.TYPE;
        if (!on()) {
            return type;
        }
        type += "-quiet";
        AnnotationType annotationType = AnnotationTypes.getTypes().getType(type);
        if (annotationType != null) {
            Color blue = OriginNotes.BLUE;
            annotationType.setCustomSidebarColor(new Color(blue.getRed(), blue.getGreen(), blue.getBlue(),
                    (int) Math.round(255 * STRIPE)));
        }
        return type;
    }
}
