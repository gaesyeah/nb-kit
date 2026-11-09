package nbkit.jsf;

/** Namespaces conhecidos (javax antigo, jcp.org e jakarta) reduzidos a um nome curto de biblioteca. */
public final class Ns {

    private Ns() {
    }

    public static String lib(String uri) {
        if (uri == null) {
            return "";
        }
        String u = uri.trim();
        switch (u) {
            case "http://java.sun.com/jsf/facelets":
            case "http://xmlns.jcp.org/jsf/facelets":
            case "jakarta.faces.facelets":
                return "ui";
            case "http://java.sun.com/jsf/html":
            case "http://xmlns.jcp.org/jsf/html":
            case "jakarta.faces.html":
                return "h";
            case "http://java.sun.com/jsf/core":
            case "http://xmlns.jcp.org/jsf/core":
            case "jakarta.faces.core":
                return "f";
            case "http://java.sun.com/jsp/jstl/core":
            case "http://xmlns.jcp.org/jsp/jstl/core":
            case "jakarta.tags.core":
                return "c";
            case "http://java.sun.com/jsp/jstl/functions":
            case "http://xmlns.jcp.org/jsp/jstl/functions":
            case "jakarta.tags.functions":
                return "fn";
            case "http://java.sun.com/jsf/composite":
            case "http://xmlns.jcp.org/jsf/composite":
            case "jakarta.faces.composite":
                return "cc";
            case "http://xmlns.jcp.org/jsf/passthrough":
            case "http://java.sun.com/jsf/passthrough":
            case "jakarta.faces.passthrough":
                return "pt";
            case "http://xmlns.jcp.org/jsf":
            case "http://java.sun.com/jsf":
            case "jakarta.faces":
                return "jsf";
            case "http://primefaces.org/ui":
            case "primefaces":
                return "p";
            case "http://primefaces.org/ui/extensions":
            case "primefaces.extensions":
                return "pe";
            case "http://omnifaces.org/ui":
            case "omnifaces":
                return "o";
            case "http://omnifaces.org/functions":
            case "omnifaces.functions":
                return "of";
            case "http://www.w3.org/1999/xhtml":
                return "html";
            default:
                break;
        }
        if (compositeLibrary(u) != null) {
            return "comp";
        }
        return "?";
    }

    /** Biblioteca de componentes compostos: resources/&lt;lib&gt;/&lt;tag&gt;.xhtml */
    public static String compositeLibrary(String uri) {
        if (uri == null) {
            return null;
        }
        for (String p : new String[]{"http://java.sun.com/jsf/composite/", "http://xmlns.jcp.org/jsf/composite/", "jakarta.faces.composite/"}) {
            if (uri.startsWith(p) && uri.length() > p.length()) {
                return uri.substring(p.length());
            }
        }
        return null;
    }

    /** Tag de componente JSF (cria UIComponent na arvore), e nao HTML puro. */
    public static boolean isJsfTag(Xml.Element e) {
        String l = lib(e.ns);
        return l.equals("h") || l.equals("f") || l.equals("p") || l.equals("pe") || l.equals("o") || l.equals("comp")
                || l.equals("ui") || l.equals("c") || l.equals("?") && e.ns != null;
    }
}
