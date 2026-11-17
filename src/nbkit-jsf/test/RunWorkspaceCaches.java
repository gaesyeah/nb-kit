import java.io.File;
import java.nio.file.Files;
import java.util.List;
import nbkit.jsf.Workspace;

/** Prints what the Workspace knows after a .js or a .properties changes (tests/jsf.sh checks the lines). */
public class RunWorkspaceCaches {
    public static void main(String[] args) throws Exception {
        File p = new File(args[0]);
        File web = new File(p, "src/main/webapp"), res = new File(p, "src/main/resources");
        web.mkdirs();
        res.mkdirs();
        Files.writeString(new File(p, "pom.xml").toPath(), "<project/>");
        File page = new File(web, "a.xhtml"), js = new File(web, "app.js"), props = new File(res, "m.properties");
        Files.writeString(page.toPath(), "<html/>");
        Files.writeString(js.toPath(), "$('.first')");
        Files.writeString(props.toPath(), "one=1\n");
        Workspace ws = Workspace.get(page, List.of());
        String sig = Workspace.filesSignature(p, page);
        System.out.println("js before: " + ws.jsClasses().keySet() + " keys before: " + ws.bundle("m").get(0).keys.keySet());
        // a later time, as an editor saving the file would give
        Files.writeString(js.toPath(), "$('.second')");
        js.setLastModified(js.lastModified() + 2000);
        Files.writeString(props.toPath(), "one=1\ntwo=2\n");
        props.setLastModified(props.lastModified() + 2000);
        ws = Workspace.get(page, List.of());
        System.out.println("js after: " + ws.jsClasses().keySet() + " keys after: " + ws.bundle("m").get(0).keys.keySet());
        System.out.println("the files' signature changes: " + !sig.equals(Workspace.filesSignature(p, page)));
    }
}
