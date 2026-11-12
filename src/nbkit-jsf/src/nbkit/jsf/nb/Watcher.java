package nbkit.jsf.nb;

import nbkit.jsf.Analyzer;
import nbkit.jsf.Rules;
import nbkit.jsf.Workspace;
import java.io.File;
import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.WeakHashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.swing.event.DocumentEvent;
import javax.swing.event.DocumentListener;
import javax.swing.text.BadLocationException;
import javax.swing.text.Document;
import javax.swing.text.Position;
import org.netbeans.api.java.classpath.ClassPath;
import org.netbeans.spi.editor.hints.ErrorDescription;
import org.netbeans.spi.editor.hints.ErrorDescriptionFactory;
import org.netbeans.spi.editor.hints.Fix;
import org.netbeans.spi.editor.hints.HintsController;
import org.netbeans.spi.editor.hints.Severity;
import org.openide.filesystems.FileObject;
import org.openide.filesystems.FileUtil;
import org.openide.util.RequestProcessor;

/**
 * Follows an open xhtml file: analyzes on open, on edit and when other project files change. To see what it does,
 * create the file ~/.cache/nbkit/jsf-debug: while it exists, each step goes to messages.log ("nbkit JSF debug").
 */
final class Watcher implements DocumentListener {

    private static final Logger LOG = Logger.getLogger("nbkit.jsf");
    private static final String LAYER = "nbkit-jsf";
    static final RequestProcessor RP = new RequestProcessor("nbkit JSF", 1, true);
    private static final Map<Document, Watcher> ALL = Collections.synchronizedMap(new WeakHashMap<>());
    private static RequestProcessor.Task poll;

    private final WeakReference<Document> doc;
    private final RequestProcessor.Task task;
    private volatile boolean edited;
    private String lastSignature = "";

    private static final File DEBUG = new File(System.getProperty("user.home"), ".cache/nbkit/jsf-debug");

    static void debug(String what, Document d) {
        if (DEBUG.exists()) {
            File f = d == null ? null : file(d);
            LOG.log(Level.INFO, "nbkit JSF debug: {0}: {1}", new Object[]{f == null ? "(no file)" : f.getName(), what});
        }
    }

    private Watcher(Document d) {
        doc = new WeakReference<>(d);
        task = RP.create(this::run);
    }

    static void attach(Document d) {
        if (d == null || ALL.containsKey(d)) {
            debug("already followed", d);
            return;
        }
        debug("follows the document", d);
        Watcher w = new Watcher(d);
        ALL.put(d, w);
        d.addDocumentListener(w);
        w.task.schedule(400);
        synchronized (Watcher.class) {
            if (poll == null) {
                poll = RP.create(Watcher::pollAll);
                poll.schedule(4000);
            }
        }
    }

    /** after the preferences change */
    static void rescheduleAll() {
        for (Watcher w : snapshot()) {
            w.task.schedule(100);
        }
    }

    private static List<Watcher> snapshot() {
        synchronized (ALL) {
            return new ArrayList<>(ALL.values());
        }
    }

    /** other files changed on disk (template saved, class recompiled): analyze again */
    private static void pollAll() {
        try {
            for (Watcher w : snapshot()) {
                Document d = w.doc.get();
                File f = d == null ? null : file(d);
                if (f == null) {
                    continue;
                }
                String sig = signature(f);
                if (!sig.equals(w.lastSignature)) {
                    w.task.schedule(50);
                }
            }
        } catch (RuntimeException ex) {
            LOG.log(Level.FINE, null, ex);
        } finally {
            poll.schedule(4000);
        }
    }

    private static String signature(File f) {
        File project = Workspace.projectOf(f);
        long sum = 0;
        int n = 0;
        for (File w : Workspace.webrootsOf(project, f)) {
            try (var s = java.nio.file.Files.walk(w.toPath())) {
                for (var p : (Iterable<java.nio.file.Path>) s::iterator) {
                    String name = p.toString();
                    if (name.endsWith(".xhtml") || name.endsWith(".xml")) {
                        sum += p.toFile().lastModified();
                        n++;
                    }
                }
            } catch (Exception ex) {
                // ignore
            }
        }
        File classes = new File(project, "target/classes");
        return n + ":" + sum + ":" + (classes.isDirectory() ? classes.lastModified() : 0);
    }

    @Override
    public void insertUpdate(DocumentEvent e) {
        debug("edit received (insert)", e.getDocument());
        edited = true;
        task.schedule(700);
    }

    @Override
    public void removeUpdate(DocumentEvent e) {
        debug("edit received (remove)", e.getDocument());
        edited = true;
        task.schedule(700);
    }

    @Override
    public void changedUpdate(DocumentEvent e) {
    }

    static File file(Document d) {
        Object o = d.getProperty(Document.StreamDescriptionProperty);
        if (o == null) {
            return null;
        }
        try {
            Object fo = o.getClass().getMethod("getPrimaryFile").invoke(o);
            if (fo instanceof FileObject) {
                return FileUtil.toFile((FileObject) fo);
            }
        } catch (ReflectiveOperationException | RuntimeException ex) {
            // not a DataObject
        }
        return null;
    }

    private void run() {
        Document d = doc.get();
        if (d == null) {
            debug("analysis skipped: the document is gone", null);
            return;
        }
        try {
            File f = file(d);
            if (f == null) {
                debug("analysis skipped: no file", d);
                return;
            }
            debug("analysis starts", d);
            String[] text = new String[1];
            d.render(() -> {
                try {
                    text[0] = d.getText(0, d.getLength());
                } catch (BadLocationException ex) {
                    text[0] = null;
                }
            });
            if (text[0] == null) {
                debug("analysis skipped: text not read", d);
                return;
            }
            lastSignature = signature(f);
            Workspace ws = Workspace.get(f, classpath(f));
            List<Rules.Problem> ps = Analyzer.run(ws, f, text[0], Settings::enabled);
            List<ErrorDescription> eds = new ArrayList<>();
            List<Rules.Problem> notes = new ArrayList<>();
            int len = d.getLength();
            javax.swing.text.Element lines = d.getDefaultRootElement();
            // lines with an error or warning of nbkit: there a note gives up its blue icon, so that it never hides
            // the problem (NetBeans shows one icon per line)
            Set<Integer> problemLines = new HashSet<>();
            for (Rules.Problem p : ps) {
                if (p.severity != Rules.Severity.INFO) {
                    problemLines.add(lines.getElementIndex(Math.min(p.start, len)));
                } else {
                    notes.add(p);
                }
            }
            for (Rules.Problem p : ps) {
                try {
                    Position s = d.createPosition(Math.min(p.start, len));
                    Position e = d.createPosition(Math.min(p.end, len));
                    List<Fix> fixes = new ArrayList<>();
                    if (p.replacement != null && p.end <= text[0].length()) {
                        fixes.add(new Replace(d, s, e, text[0].substring(p.start, p.end), p.replacement));
                    }
                    for (Rules.Target t : p.targets) {
                        fixes.add(new GoTo(t));
                    }
                    Severity sev = p.severity == Rules.Severity.ERROR ? Severity.ERROR : p.severity == Rules.Severity.WARNING
                            ? Severity.WARNING : Severity.HINT;
                    String type = null;
                    if (sev == Severity.HINT && !problemLines.contains(lines.getElementIndex(Math.min(p.start, len)))) {
                        type = QuietNotes.type(!fixes.isEmpty());
                    }
                    eds.add(ErrorDescriptionFactory.createErrorDescription(null, sev, type, p.message, null, fixes, d, s, e));
                } catch (BadLocationException ex) {
                    // the document changed midway: the next analysis fixes it
                }
            }
            HintsController.setErrors(d, LAYER, eds);
            OriginNotes.set(d, notes);
            debug("analysis done, " + eds.size() + " warning(s), " + notes.size() + " note(s) " + ps.stream().map(p -> p.rule).toList(), d);
            if (edited) {
                edited = false;
                // a template or include changed: the other open files may depend on it
                for (Watcher w : snapshot()) {
                    if (w != this) {
                        w.task.schedule(1500);
                    }
                }
            }
        } catch (Throwable ex) {
            // never breaks the editor
            LOG.log(Level.INFO, "nbkit JSF: falha ao analisar", ex);
        }
    }

    /** project jars and class folders, through the NetBeans classpath */
    static List<File> classpath(File xhtml) {
        Set<File> r = new LinkedHashSet<>();
        File project = Workspace.projectOf(xhtml);
        List<FileObject> probes = new ArrayList<>();
        for (String p : new String[]{"src/main/java", "src"}) {
            File d = new File(project, p);
            if (d.isDirectory()) {
                FileObject fo = FileUtil.toFileObject(d);
                if (fo != null) {
                    probes.add(fo);
                }
            }
        }
        FileObject self = FileUtil.toFileObject(xhtml);
        if (self != null) {
            probes.add(self);
        }
        for (FileObject probe : probes) {
            for (String type : new String[]{ClassPath.COMPILE, ClassPath.EXECUTE}) {
                try {
                    ClassPath cp = ClassPath.getClassPath(probe, type);
                    if (cp == null) {
                        continue;
                    }
                    for (FileObject root : cp.getRoots()) {
                        FileObject archive = FileUtil.getArchiveFile(root);
                        File f = FileUtil.toFile(archive != null ? archive : root);
                        if (f != null) {
                            r.add(f);
                        }
                    }
                } catch (RuntimeException ex) {
                    // ignore
                }
            }
            if (!r.isEmpty()) {
                break;
            }
        }
        return new ArrayList<>(r);
    }
}
