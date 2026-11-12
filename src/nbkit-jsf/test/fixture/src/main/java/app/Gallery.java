package app;

/** a generic model whose items come as ? extends Frame<T> (the T itself stays unknown) */
public interface Gallery<T> {
  java.util.List<? extends Frame<T>> getFrames();
}
