package app;
/** the only implementation that has every setter */
public class ContactRecord implements Contact {
  private String phone, email, note;
  public String getPhone() { return phone; }
  public void setPhone(String phone) { this.phone = phone; }
  public ContactRecord setPhoneChained(String phone) { setPhone(phone); return this; }
  public String getEmail() { return email; }
  public void setEmail(String email) { this.email = email; }
  public ContactRecord setEmailChained(String email) { setEmail(email); return this; }
  public String getNote() { return note; }
}
