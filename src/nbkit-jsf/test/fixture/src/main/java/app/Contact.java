package app;
/** declared type with getters and only "chained" setters: the setter that EL uses lives in the implementations */
public interface Contact {
  String getPhone();
  Contact setPhoneChained(String phone);
  String getEmail();
  Contact setEmailChained(String email);
  String getNote();
}
