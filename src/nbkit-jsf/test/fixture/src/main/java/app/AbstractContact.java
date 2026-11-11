package app;
/** abstract: never the object that reaches the page, only its subclasses */
public abstract class AbstractContact implements Contact {
  public String getPhone() { return null; }
  public String getEmail() { return null; }
  public String getNote() { return null; }
}
