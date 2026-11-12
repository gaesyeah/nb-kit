package nbkit.jsf.nb;

import javax.swing.text.BadLocationException;
import javax.swing.text.Document;
import javax.swing.text.Position;
import javax.swing.text.StyledDocument;
import nbkit.jsf.Msg;
import org.netbeans.spi.editor.hints.ChangeInfo;
import org.netbeans.spi.editor.hints.Fix;
import org.openide.text.NbDocument;

/**
 * "Replace with 'x'" in Alt+Enter: writes the suggestion over the marked text. Only when that text is still the one
 * analyzed (the file may have changed since): otherwise it does nothing, and the next analysis offers it again.
 */
final class Replace implements Fix {

    private final Document document;
    private final Position start, end;
    private final String was, now;

    Replace(Document document, Position start, Position end, String was, String now) {
        this.document = document;
        this.start = start;
        this.end = end;
        this.was = was;
        this.now = now;
    }

    @Override
    public String getText() {
        return Msg.t("replace", now);
    }

    @Override
    public ChangeInfo implement() throws Exception {
        Runnable write = () -> {
            try {
                int s = start.getOffset(), e = end.getOffset();
                if (e - s == was.length() && document.getText(s, e - s).equals(was)) {
                    document.remove(s, e - s);
                    document.insertString(s, now, null);
                }
            } catch (BadLocationException ex) {
                // changed meanwhile: nothing written
            }
        };
        if (document instanceof StyledDocument styled) {
            NbDocument.runAtomicAsUser(styled, write);
        } else {
            write.run();
        }
        return null;
    }
}
