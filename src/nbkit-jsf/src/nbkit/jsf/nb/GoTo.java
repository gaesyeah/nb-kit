package nbkit.jsf.nb;

import nbkit.jsf.Msg;
import nbkit.jsf.Rules;
import org.netbeans.spi.editor.hints.ChangeInfo;
import org.netbeans.spi.editor.hints.Fix;
import org.openide.cookies.LineCookie;
import org.openide.filesystems.FileObject;
import org.openide.filesystems.FileUtil;
import org.openide.loaders.DataObject;
import org.openide.text.Line;

/** "Go to <file, line N>" in Alt+Enter: where a note's name comes from, or where a suggested name is */
final class GoTo implements Fix {

    private final Rules.Target target;

    GoTo(Rules.Target target) {
        this.target = target;
    }

    @Override
    public String getText() {
        return Msg.t("goto", target.label);
    }

    @Override
    public ChangeInfo implement() throws Exception {
        FileObject fo = FileUtil.toFileObject(FileUtil.normalizeFile(target.file));
        if (fo == null) {
            return null;
        }
        LineCookie lines = DataObject.find(fo).getLookup().lookup(LineCookie.class);
        if (lines != null) {
            lines.getLineSet().getOriginal(Math.max(0, target.line - 1)).show(Line.ShowOpenType.OPEN, Line.ShowVisibilityType.FOCUS);
        }
        return null;
    }
}
