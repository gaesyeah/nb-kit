package app;

public interface Frame<T> {
  Long getIntervalMs();
  T getContent();
}
