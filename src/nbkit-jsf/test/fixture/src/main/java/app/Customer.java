package app;
public class Customer {
  private String name; private Status status;
  public String getName() { return name; } public void setName(String n) { name = n; }
  public Status getStatus() { return status; } public void setStatus(Status s) { status = s; }
  public String getCode() { return "x"; }
  public boolean isActive() { return true; }
}
