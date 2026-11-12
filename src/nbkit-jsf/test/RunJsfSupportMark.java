/** Prints what the module does about NetBeans' JSF support in each case (tests/jsf.sh checks the lines). */
public class RunJsfSupportMark {
    public static void main(String[] args) throws Exception {
        java.lang.reflect.Method next = Class.forName("nbkit.jsf.nb.JsfSupportMark")
                .getDeclaredMethod("next", String.class, boolean.class, boolean.class);
        next.setAccessible(true);
        String[][] cases = {{null, "false", "false"}, {null, "true", "false"}, {"activated", "true", "false"},
            {"found", "false", "false"}, {"activated", "false", "true"}};
        for (String[] c : cases) {
            System.out.println(c[0] + " active=" + c[1] + " noask=" + c[2] + " -> "
                    + next.invoke(null, c[0], Boolean.parseBoolean(c[1]), Boolean.parseBoolean(c[2])));
        }
    }
}
