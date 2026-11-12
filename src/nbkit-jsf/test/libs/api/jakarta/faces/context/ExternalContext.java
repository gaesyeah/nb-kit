package jakarta.faces.context;

public abstract class ExternalContext {
    public abstract String getRequestContextPath();
    public abstract java.util.Map<String, String> getRequestParameterMap();
}
