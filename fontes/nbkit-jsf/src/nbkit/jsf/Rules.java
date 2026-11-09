package nbkit.jsf;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.function.Predicate;

/** Regras, com id estavel (usado nas preferencias) e o texto mostrado na tela de opcoes. */
public final class Rules {

    private Rules() {
    }

    public enum Severity { ERROR, WARNING }

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
            return (severity == Severity.ERROR ? "ERRO " : "AVISO ") + rule + " [" + start + "-" + end + "] " + message;
        }
    }

    /** id -> descricao (ordem da tela de opcoes) */
    public static final Map<String, String> ALL = new LinkedHashMap<>();

    static {
        ALL.put("el.unknown", "EL: nome que não existe (#{batataDoce})");
        ALL.put("el.scope", "EL: variável usada fora de onde ela existe");
        ALL.put("el.member", "EL: propriedade ou método que não existe no bean");
        ALL.put("el.readonly", "EL: campo de entrada com value que não pode ser gravado");
        ALL.put("el.kind", "EL: método onde se espera propriedade, e o contrário");
        ALL.put("el.enum", "EL: comparação com constante de enum que não existe");
        ALL.put("cc.attrs", "Componente composto: cc.attrs não declarado no cc:interface");
        ALL.put("unused", "Declarado e não usado (ui:param, c:set, var, cc:attribute...)");
        ALL.put("id.missing", "IDs: update/process/for apontando para id que não existe");
        ALL.put("id.keyword", "IDs: palavra de busca do PrimeFaces errada (@from)");
        ALL.put("id.invalid", "IDs: id com formato inválido");
        ALL.put("id.duplicate", "IDs: id repetido no mesmo container");
        ALL.put("id.rendered", "IDs: update de componente que tem rendered");
        ALL.put("js.widgetvar", "JavaScript: PF('nome') sem widgetVar correspondente");
        ALL.put("form.outside", "Formulário: botão ou campo fora de h:form");
        ALL.put("form.nested", "Formulário: h:form dentro de h:form");
        ALL.put("form.dialog", "Formulário: p:dialog com appendTo body sem form dentro");
        ALL.put("form.upload", "Formulário: p:fileUpload sem enctype multipart");
        ALL.put("form.messages", "Formulário: validação sem componente de mensagem");
        ALL.put("jstl.iteration", "JSTL usando a variável de um ui:repeat/p:dataTable");
        ALL.put("meta.viewparam", "f:viewParam/f:viewAction fora de f:metadata");
        ALL.put("ajax.event", "p:ajax/f:ajax com evento que o componente não tem");
        ALL.put("tpl.define", "Template: ui:define sem ui:insert, e conteúdo ignorado");
        ALL.put("tpl.path", "Template: ui:include/template com caminho que não existe");
        ALL.put("res.missing", "Recurso (css, js, imagem) que não existe");
        ALL.put("nav.missing", "Navegação para página que não existe");
        ALL.put("comment.el", "EL dentro de comentário (é executado)");
        ALL.put("xml.entity", "Entidade HTML (&nbsp;) que quebra o Facelets");
        ALL.put("sec.escape", "escape=\"false\" com valor dinâmico (XSS)");
        ALL.put("el.immediate", "${...} em atributo de componente JSF");
    }

    public static final Predicate<String> ALL_ON = r -> true;
}
