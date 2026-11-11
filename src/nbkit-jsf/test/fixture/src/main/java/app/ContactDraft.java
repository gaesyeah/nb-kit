package app;
/** a second implementation, without setEmail (and, like the first one, without setNote) */
public class ContactDraft extends AbstractContact {
  public void setPhone(String phone) { }
  public ContactDraft setPhoneChained(String phone) { return this; }
  public ContactDraft setEmailChained(String email) { return this; }
}
