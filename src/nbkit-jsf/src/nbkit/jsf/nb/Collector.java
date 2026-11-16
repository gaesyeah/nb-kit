package nbkit.jsf.nb;

import java.io.File;
import java.nio.file.Files;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.prefs.Preferences;
import javax.swing.text.Document;
import nbkit.jsf.NetBeansMarks;
import nbkit.jsf.Workspace;
import org.netbeans.api.editor.mimelookup.MimeLookup;
import org.netbeans.api.project.Project;
import org.netbeans.api.project.ProjectManager;
import org.netbeans.api.project.ui.OpenProjects;
import org.netbeans.editor.BaseDocument;
import org.netbeans.modules.csl.api.Error;
import org.netbeans.modules.csl.api.Hint;
import org.netbeans.modules.csl.api.HintsProvider;
import org.netbeans.modules.csl.api.HintsProvider.HintsManager;
import org.netbeans.modules.csl.api.OffsetRange;
import org.netbeans.modules.csl.api.Rule;
import org.netbeans.modules.csl.api.Rule.AstRule;
import org.netbeans.modules.csl.api.Rule.ErrorRule;
import org.netbeans.modules.csl.api.Rule.SelectionRule;
import org.netbeans.modules.csl.api.Rule.UserConfigurableRule;
import org.netbeans.modules.csl.api.RuleContext;
import org.netbeans.modules.csl.spi.DefaultLanguageConfig;
import org.netbeans.modules.csl.spi.ParserResult;
import org.netbeans.modules.parsing.api.Embedding;
import org.netbeans.modules.parsing.api.ParserManager;
import org.netbeans.modules.parsing.api.ResultIterator;
import org.netbeans.modules.parsing.api.Snapshot;
import org.netbeans.modules.parsing.api.Source;
import org.netbeans.modules.parsing.api.UserTask;
import org.netbeans.modules.parsing.api.indexing.IndexingManager;
import org.netbeans.modules.web.api.webmodule.WebModule;
import org.netbeans.spi.options.OptionsPanelController;
import org.openide.filesystems.FileObject;
import org.openide.filesystems.FileUtil;
import org.openide.modules.ModuleInfo;
import org.openide.modules.Modules;
import org.openide.util.RequestProcessor;
import org.openide.util.lookup.Lookups;

/**
 * Collects what NetBeans marks on every xhtml of a project, for the comparison with nbkit's own checks. Asked by the
 * file ~/.cache/nbkit/collect-request (the project's path): the module opens the project if needed, waits for the
 * scan (the EL rules need the index), runs NetBeans' hint rules of each language in the page (EL, HTML, CSS...) the
 * way NetBeans' own CSL infrastructure does (GsfHintsManager.collectHints, GsfHintsProvider.processErrors), and
 * writes the collection, then the done marker (NetBeansMarks has the files and their format).
 * <p>
 * Only public CSL API: the providers come from CslPlugins/&lt;mime&gt; in the layer, and run with a HintsManager of
 * nbkit that says every rule is on, so rules turned off in Tools &gt; Options (or by NetBeansOverrides) are collected
 * too, each saying whether it is on in NetBeans' settings.
 */
final class Collector {

    private static final File CACHE = NetBeansMarks.cache();
    /** its own thread: a collection takes minutes, and must not hold the analysis of the open files (Watcher.RP) */
    private static final RequestProcessor RP = new RequestProcessor("nbkit JSF collect", 1);

    private Collector() {
    }

    /** looks for a request every few seconds */
    static void start() {
        RP.post(Collector::poll, 5000);
    }

    private static void poll() {
        try {
            File project = NetBeansMarks.take(CACHE);
            if (project != null) {
                collect(project.getAbsoluteFile());
            }
        } catch (Throwable ex) {
            // never breaks NetBeans
            Watcher.debug("collect: failed: " + ex);
        } finally {
            RP.post(Collector::poll, 3000);
        }
    }

    private static void collect(File dir) throws Exception {
        Watcher.debug("collect: request for " + dir);
        File out = NetBeansMarks.outputFile(CACHE, dir);
        Map<String, String> info = new LinkedHashMap<>();
        info.put("project", dir.getPath());
        info.put("netbeans", System.getProperty("netbeans.productversion", "") + " " + System.getProperty("netbeans.buildnumber", ""));
        ModuleInfo self = Modules.getDefault().ownerOf(Collector.class);
        info.put("nbkit-jsf", self == null ? "" : self.getSpecificationVersion() + " " + self.getAttribute("NbKit-Source-Hash"));
        info.put("date", Instant.now().toString());
        Map<String, String> hashes = new LinkedHashMap<>();
        List<NetBeansMarks.Mark> marks = new ArrayList<>();
        FileObject fo = FileUtil.toFileObject(dir);
        Project project = fo == null ? null : ProjectManager.getDefault().findProject(fo);
        if (project == null) {
            info.put("error", "not a NetBeans project: " + dir);
        } else {
            open(project);
            waitScan();
            // what NetBeans does not run at all here: no mark there is not agreement (NetBeansMarks.notRun)
            Preferences html = MimeLookup.getLookup("text/html").lookup(Preferences.class);
            String setting = html == null ? "" : html.get("mimetypesWithEnabledHtmlErrorChecking", "");
            info.put(NetBeansMarks.INFO_HTML_ERRORS, (NetBeansMarks.htmlErrorChecking(setting, NetBeansMarks.FACELETS) ? "on " : "off ")
                    + NetBeansMarks.FACELETS);
            info.put(NetBeansMarks.INFO_WEB_MODULE, WebModule.getWebModule(fo) != null ? "yes" : "no");
            Watcher.debug("collect: " + NetBeansMarks.INFO_HTML_ERRORS + " " + info.get(NetBeansMarks.INFO_HTML_ERRORS) + ", "
                    + NetBeansMarks.INFO_WEB_MODULE + " " + info.get(NetBeansMarks.INFO_WEB_MODULE));
            List<File> pages = Workspace.pages(dir);
            Watcher.debug("collect: " + pages.size() + " xhtml file(s)");
            for (File page : pages) {
                String rel = dir.toPath().relativize(page.toPath()).toString().replace('\\', '/');
                hashes.put(rel, NetBeansMarks.sha256(Files.readAllBytes(page.toPath())));
                FileObject pfo = FileUtil.toFileObject(page);
                if (pfo == null) {
                    continue;
                }
                List<NetBeansMarks.Mark> found = new ArrayList<>();
                Source source = Source.create(pfo);
                // the document is loaded here, not inside the parse (the rules want it; see run)
                source.getDocument(true);
                ParserManager.parseWhenScanFinished(Collections.singleton(source), new UserTask() {
                    @Override
                    public void run(ResultIterator it) throws Exception {
                        String text = it.getSnapshot().getText().toString();
                        walk(it, text, rel, found);
                    }
                }).get();
                Watcher.debug("collect: " + rel + ": " + found.size() + " mark(s)");
                marks.addAll(found);
            }
        }
        NetBeansMarks.write(out, info, hashes, marks);
        NetBeansMarks.done(CACHE, out);
        Watcher.debug("collect: done, " + marks.size() + " mark(s) in " + out);
    }

    /** opens the project in NetBeans when it is not open yet (its classpath and index come with it) */
    private static void open(Project project) throws Exception {
        OpenProjects op = OpenProjects.getDefault();
        if (!op.isProjectOpen(project)) {
            Watcher.debug("collect: opening the project");
            op.open(new Project[]{project}, false);
        }
        op.openProjects().get();
    }

    /** the scan starts a moment after the project opens: waits for it to start, then to end */
    private static void waitScan() throws InterruptedException {
        IndexingManager im = IndexingManager.getDefault();
        for (int i = 0; i < 10 && !im.isIndexing(); i++) {
            Thread.sleep(500);
        }
        Watcher.debug("collect: waiting for the scan");
        while (im.isIndexing()) {
            Thread.sleep(1000);
        }
        Watcher.debug("collect: scan finished");
    }

    /** the page and each language embedded in it */
    private static void walk(ResultIterator it, String text, String rel, List<NetBeansMarks.Mark> out) throws Exception {
        for (Embedding e : it.getEmbeddings()) {
            walk(it.getResultIterator(e), text, rel, out);
        }
        if (it.getParserResult() instanceof ParserResult result) {
            run(result, text, rel, out);
        }
    }

    private static void run(ParserResult result, String text, String rel, List<NetBeansMarks.Mark> out) {
        Snapshot snapshot = result.getSnapshot();
        String mime = snapshot.getMimeType();
        HintsManager real = HintsManager.getManagerForMimeType(mime);
        DefaultLanguageConfig language = Lookups.forPath("CslPlugins/" + mime).lookup(DefaultLanguageConfig.class);
        HintsProvider provider = language == null ? null : language.getHintsProvider();
        if (real == null || provider == null) {
            return;
        }
        All manager = new All(real);
        RuleContext context = provider.createRuleContext();
        context.manager = manager;
        context.parserResult = result;
        context.caretOffset = -1;
        context.selectionStart = -1;
        context.selectionEnd = -1;
        Document doc = snapshot.getSource().getDocument(false);
        context.doc = doc instanceof BaseDocument b ? b : null;
        List<Hint> hints = new ArrayList<>();
        List<Error> unhandled = new ArrayList<>();
        provider.computeErrors(manager, context, hints, unhandled);
        provider.computeHints(manager, context, hints);
        // which rules applied to the page (e.g. EL's Identifiers only in a web module): a page with no mark says why
        List<String> applied = new ArrayList<>();
        for (List<? extends AstRule> rules : manager.getHints(false, context).values()) {
            for (AstRule r : rules) {
                applied.add(r.getId() + (real.isEnabled(r) ? "" : " (off)"));
            }
        }
        Watcher.debug("collect: " + rel + ": " + mime + ": rules that apply " + applied + ", " + hints.size() + " hint(s), "
                + unhandled.size() + " other error(s)");
        String prefix = mime.replace('/', '_') + "_";
        for (Hint h : hints) {
            OffsetRange r = h.getRange();
            if (r == null || r.getStart() < 0 || r.getEnd() > text.length() || r.getStart() > r.getEnd()) {
                continue;   // NetBeans does not show it either
            }
            Rule rule = h.getRule();
            String id = rule instanceof UserConfigurableRule u ? u.getId() : rule.getClass().getSimpleName();
            String severity = rule.getDefaultSeverity().name();
            boolean on = true;
            if (rule instanceof UserConfigurableRule u) {
                Preferences p = real.getPreferences(u);
                severity = p == null ? severity : p.get("severity", severity);
                on = real.isEnabled(u);
            }
            out.add(mark(text, rel, r.getStart(), r.getEnd(), prefix + id, severity, on, h.getDescription()));
        }
        // errors no rule took (parser errors): shown by NetBeans as they are, in the snapshot's own offsets
        for (Error e : unhandled) {
            int start = snapshot.getOriginalOffset(e.getStartPosition());
            if (start < 0) {
                continue;
            }
            int end = Math.min(text.length(), start + Math.max(0, e.getEndPosition() - e.getStartPosition()));
            out.add(mark(text, rel, start, end, prefix + "error", e.getSeverity().name(), true, e.getDisplayName()));
        }
    }

    private static NetBeansMarks.Mark mark(String text, String rel, int start, int end, String rule, String severity, boolean on,
            String message) {
        int[] lc = NetBeansMarks.lineColumn(text, start);
        return new NetBeansMarks.Mark(rel, lc[0], lc[1], start, end, rule, severity, on, message);
    }

    /**
     * NetBeans' own HintsManager of the language, except that every rule is on: the providers only ask isEnabled
     * (ELHintsProvider.computeHints, HtmlHintsProvider.computeErrors), so the rules turned off run too. The rule
     * lists are the same, every rule that applies to the file, also those whose severity is "current line".
     */
    private static final class All extends HintsManager {

        private final HintsManager real;

        All(HintsManager real) {
            this.real = real;
        }

        @Override
        public boolean isEnabled(UserConfigurableRule rule) {
            return true;
        }

        @Override
        public Map<?, List<? extends ErrorRule>> getErrors() {
            return real.getErrors();
        }

        @Override
        public Map<?, List<? extends AstRule>> getHints() {
            return real.getHints();
        }

        @Override
        public List<? extends SelectionRule> getSelectionHints() {
            return real.getSelectionHints();
        }

        @Override
        public Map<?, List<? extends AstRule>> getHints(boolean onLine, RuleContext context) {
            Map<Object, List<? extends AstRule>> r = new HashMap<>();
            if (onLine) {
                return r;
            }
            for (Map.Entry<?, List<? extends AstRule>> e : real.getHints().entrySet()) {
                List<AstRule> rules = new LinkedList<>();
                for (AstRule rule : e.getValue()) {
                    if (rule.appliesTo(context)) {
                        rules.add(rule);
                    }
                }
                if (!rules.isEmpty()) {
                    r.put(e.getKey(), rules);
                }
            }
            return r;
        }

        @Override
        public Map<?, List<? extends AstRule>> getSuggestions() {
            return real.getSuggestions();
        }

        @Override
        public void refreshHints(RuleContext context) {
            // the collection never touches the editor
        }

        @Override
        public OptionsPanelController getOptionsController() {
            return real.getOptionsController();
        }

        @Override
        public Preferences getPreferences(UserConfigurableRule rule) {
            return real.getPreferences(rule);
        }
    }
}
