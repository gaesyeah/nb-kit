package app;
import org.springframework.stereotype.Component;
@Component
public class CustomerVM {
  private Customer customer = new Customer();
  public Customer getCustomer() { return customer; }
  public Contact getContact() { return new ContactRecord(); }
  public java.util.List<Customer> getItems() { return null; }
  public java.util.Map<String,String> getMap() { return null; }
  public String save() { return null; }
  public void delete(Customer c) { }
  public String getTitle() { return ""; }
  public boolean isCanEdit() { return true; }
  public String format(String s) { return s; }
  public Rows<String, Customer> getRows() { return null; }
  public CustomerRows getCustomerRows() { return null; }
  public java.util.List<Contact> getContacts() { return null; }
  public Customer[] getArray() { return null; }
  public outside.Thing getThing() { return null; }
  public String join(String... parts) { return ""; }
  public String toList() { return "customers"; }
  public String toNowhere() { return "nowhere"; }
  public String branch() {
    if (isCanEdit()) {
      return "customers";
    }
    return "kinds?faces-redirect=true";
  }
  public String nextPage() { return getTitle(); }
  public void listen(jakarta.faces.event.ActionEvent e) { }
  public boolean canArchive(Customer c) { return true; }
  public Customer ownerOf(Customer c) { return c; }
  public String pick(String a) { return a; }
  public String pick(String a, String b, String c) { return a; }
}
