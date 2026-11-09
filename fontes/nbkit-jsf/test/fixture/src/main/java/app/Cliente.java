package app;
public class Cliente {
  private String nome; private Status status;
  public String getNome() { return nome; } public void setNome(String n) { nome = n; }
  public Status getStatus() { return status; } public void setStatus(Status s) { status = s; }
  public String getCodigo() { return "x"; }
  public boolean isAtivo() { return true; }
}
