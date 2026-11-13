package app;
import org.springframework.stereotype.Component;
@Component
public class LockVM {
  private boolean flag;
  public String getCode() { return "x"; }
  public boolean isLocked() { return true; }
  public boolean isOpen() {
    return false;
  }
  public boolean isBusy() { return flag; }
  public boolean isFlag() { return flag; }
  public void setFlag(boolean f) { flag = f; }
  public String save() { return null; }
}
