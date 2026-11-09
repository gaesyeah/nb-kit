package app;
import org.springframework.stereotype.Component;
@Component
public class ClienteVM {
  private Cliente cliente = new Cliente();
  public Cliente getCliente() { return cliente; }
  public java.util.List<Cliente> getLista() { return null; }
  public java.util.Map<String,String> getMapa() { return null; }
  public String salvar() { return null; }
  public void excluir(Cliente c) { }
  public String getTitulo() { return ""; }
  public boolean isPodeEditar() { return true; }
  public String formatar(String s) { return s; }
}
