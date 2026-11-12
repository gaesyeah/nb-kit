package jakarta.faces.context;

public abstract class FacesContext {
    public abstract ExternalContext getExternalContext();
    public static FacesContext getCurrentInstance() { return null; }
}
