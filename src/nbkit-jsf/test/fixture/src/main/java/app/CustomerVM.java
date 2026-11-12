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
}
