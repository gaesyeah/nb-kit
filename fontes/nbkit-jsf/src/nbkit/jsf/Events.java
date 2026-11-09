package nbkit.jsf;

import java.io.File;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Eventos que cada componente aceita em p:ajax/f:ajax. Pergunta ao proprio componente
 * (getEventNames), carregado num classloader isolado com os jars do projeto.
 */
public final class Events {

    private final Workspace ws;
    private URLClassLoader loader;
    private final Map<String, Set<String>> cache = new HashMap<>();

    Events(Workspace ws) {
        this.ws = ws;
    }

    public synchronized void close() {
        if (loader != null) {
            try {
                loader.close();
            } catch (Exception ex) {
                // ignora
            }
            loader = null;
        }
        cache.clear();
    }

    /** null quando nao da pra saber */
    public synchronized Set<String> of(Xml.Element e) {
        String cls = componentClass(e);
        if (cls == null) {
            return null;
        }
        if (cache.containsKey(cls)) {
            return cache.get(cls);
        }
        Set<String> r = null;
        try {
            if (loader == null) {
                List<URL> urls = new ArrayList<>();
                for (File f : ws.classRoots) {
                    if (f.isFile()) {
                        urls.add(f.toURI().toURL());
                    }
                }
                loader = new URLClassLoader(urls.toArray(new URL[0]), ClassLoader.getPlatformClassLoader());
            }
            Class<?> c = Class.forName(cls.replace('/', '.'), false, loader);
            Object o = c.getDeclaredConstructor().newInstance();
            Method m = c.getMethod("getEventNames");
            Object names = m.invoke(o);
            if (names instanceof Collection) {
                r = new LinkedHashSet<>();
                for (Object x : (Collection<?>) names) {
                    r.add(String.valueOf(x));
                }
            }
        } catch (Throwable ex) {
            r = null;
        }
        cache.put(cls, r);
        return r;
    }

    private String componentClass(Xml.Element e) {
        String lib = Ns.lib(e.ns);
        if (lib.equals("h")) {
            String base = ws.classes.get("jakarta/faces/component/UIComponent") != null ? "jakarta" : "javax";
            String cls = base + "/faces/component/html/Html" + Character.toUpperCase(e.local.charAt(0)) + e.local.substring(1);
            return ws.classes.get(cls) != null ? cls : null;
        }
        Map<String, String> tags = ws.tagTypes.get(e.ns == null ? "" : e.ns.trim());
        if (tags == null) {
            return null;
        }
        String type = tags.get(e.local);
        return type == null ? null : ws.componentClasses.get(type);
    }

    /** eventos de componente composto: cc:clientBehavior do arquivo do componente */
    public static Set<String> compositeEvents(Xml.Doc cc) {
        Set<String> r = new LinkedHashSet<>();
        for (Xml.Element e : cc.all) {
            if (e.is("cc", "clientBehavior") && e.value("name") != null) {
                r.add(e.value("name"));
            }
        }
        return r;
    }

    static Map<String, Set<String>> debug(Events ev) {
        return new HashMap<>(ev.cache);
    }
}
