package nbkit.jsf;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.function.Predicate;

/** Rules, with a stable id (used in the preferences) and the text shown in the options page. */
public final class Rules {

    private Rules() {
    }

    /** INFO: nothing wrong, it only says where a name or id comes from when that is in another file */
    public enum Severity { ERROR, WARNING, INFO }

    public static final class Problem {
        public final String rule;
        public final Severity severity;
        public final int start, end;
        public final String message;

        public Problem(String rule, Severity severity, int start, int end, String message) {
            this.rule = rule;
            this.severity = severity;
            this.start = start;
            this.end = Math.max(end, start + 1);
            this.message = message;
        }

        @Override
        public String toString() {
            return severity + " " + rule + " [" + start + "-" + end + "] " + message;
        }
    }

    /** id -> description (order of the options page) */
    public static final Map<String, String> ALL = new LinkedHashMap<>();

    static {
        ALL.put("el.unknown", Msg.t("rule.el.unknown"));
        ALL.put("el.scope", Msg.t("rule.el.scope"));
        ALL.put("el.member", Msg.t("rule.el.member"));
        ALL.put("el.readonly", Msg.t("rule.el.readonly"));
        ALL.put("el.kind", Msg.t("rule.el.kind"));
        ALL.put("el.enum", Msg.t("rule.el.enum"));
        ALL.put("cc.attrs", Msg.t("rule.cc.attrs"));
        ALL.put("unused", Msg.t("rule.unused"));
        ALL.put("id.missing", Msg.t("rule.id.missing"));
        ALL.put("id.keyword", Msg.t("rule.id.keyword"));
        ALL.put("id.invalid", Msg.t("rule.id.invalid"));
        ALL.put("id.duplicate", Msg.t("rule.id.duplicate"));
        ALL.put("id.rendered", Msg.t("rule.id.rendered"));
        ALL.put("js.widgetvar", Msg.t("rule.js.widgetvar"));
        ALL.put("form.outside", Msg.t("rule.form.outside"));
        ALL.put("form.nested", Msg.t("rule.form.nested"));
        ALL.put("form.dialog", Msg.t("rule.form.dialog"));
        ALL.put("form.upload", Msg.t("rule.form.upload"));
        ALL.put("form.messages", Msg.t("rule.form.messages"));
        ALL.put("jstl.iteration", Msg.t("rule.jstl.iteration"));
        ALL.put("meta.viewparam", Msg.t("rule.meta.viewparam"));
        ALL.put("ajax.event", Msg.t("rule.ajax.event"));
        ALL.put("tpl.define", Msg.t("rule.tpl.define"));
        ALL.put("tpl.path", Msg.t("rule.tpl.path"));
        ALL.put("res.missing", Msg.t("rule.res.missing"));
        ALL.put("nav.missing", Msg.t("rule.nav.missing"));
        ALL.put("comment.el", Msg.t("rule.comment.el"));
        ALL.put("xml.entity", Msg.t("rule.xml.entity"));
        ALL.put("sec.escape", Msg.t("rule.sec.escape"));
        ALL.put("el.immediate", Msg.t("rule.el.immediate"));
        ALL.put("origin", Msg.t("rule.origin"));
        ALL.put("css.class", Msg.t("rule.css.class"));
    }

    public static final Predicate<String> ALL_ON = r -> true;
}
