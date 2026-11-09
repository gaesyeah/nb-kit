package nbkit.jsf.nb;

import nbkit.jsf.Analyzer;
import nbkit.jsf.Rules;
import nbkit.jsf.Workspace;
import java.io.File;
import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Collections;
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
import org.netbeans.spi.editor.hints.HintsController;
import org.netbeans.spi.editor.hints.Severity;
import org.openide.filesystems.FileObject;
import org.openide.filesystems.FileUtil;
import org.openide.util.RequestProcessor;

/** Acompanha um xhtml aberto: analisa ao abrir, ao editar e quando outros arquivos do projeto mudam. */
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

    private Watcher(Document d) {
        doc = new WeakReference<>(d);
        task = RP.create(this::run);
    }

    static void attach(Document d) {
        if (d == null || ALL.containsKey(d)) {
            return;
        }
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

    /** depois de mudar as preferencias */
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

    /** outros arquivos mudaram no disco (template salvo, classe recompilada): analisa de novo */
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
                // ignora
            }
        }
        File classes = new File(project, "target/classes");
        return n + ":" + sum + ":" + (classes.isDirectory() ? classes.lastModified() : 0);
    }

    @Override
    public void insertUpdate(DocumentEvent e) {
        edited = true;
        task.schedule(700);
    }

    @Override
    public void removeUpdate(DocumentEvent e) {
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
            // nao e DataObject
        }
        return null;
    }

    private void run() {
        Document d = doc.get();
        if (d == null) {
            return;
        }
        try {
            File f = file(d);
            if (f == null) {
                return;
            }
            String[] text = new String[1];
            d.render(() -> {
                try {
                    text[0] = d.getText(0, d.getLength());
                } catch (BadLocationException ex) {
                    text[0] = null;
                }
            });
            if (text[0] == null) {
                return;
            }
            lastSignature = signature(f);
            Workspace ws = Workspace.get(f, classpath(f));
            List<Rules.Problem> ps = Analyzer.run(ws, f, text[0], Settings::enabled);
            List<ErrorDescription> eds = new ArrayList<>();
            int len = d.getLength();
            for (Rules.Problem p : ps) {
                try {
                    Position s = d.createPosition(Math.min(p.start, len));
                    Position e = d.createPosition(Math.min(p.end, len));
                    eds.add(ErrorDescriptionFactory.createErrorDescription(p.severity == Rules.Severity.ERROR ? Severity.ERROR
                            : Severity.WARNING, p.message, d, s, e));
                } catch (BadLocationException ex) {
                    // documento mudou no meio: a proxima analise corrige
                }
            }
            HintsController.setErrors(d, LAYER, eds);
            if (edited) {
                edited = false;
                // um template ou include mudou: os outros abertos podem depender dele
                for (Watcher w : snapshot()) {
                    if (w != this) {
                        w.task.schedule(1500);
                    }
                }
            }
        } catch (Throwable ex) {
            // nunca derruba o editor
            LOG.log(Level.INFO, "nbkit JSF: falha ao analisar", ex);
        }
    }

    /** jars e pastas de classes do projeto, pelo classpath do NetBeans */
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
                    // ignora
                }
            }
            if (!r.isEmpty()) {
                break;
            }
        }
        return new ArrayList<>(r);
    }
}
