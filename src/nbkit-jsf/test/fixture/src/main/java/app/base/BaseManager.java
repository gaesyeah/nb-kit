package app.base;

/** like MkaBaseViewModelControlViewManager<..., P>: the item and entity types are type parameters, bound only by the subclass */
public abstract class BaseManager<I, M, P> {
  public Paged<P> getPaginationListDataModel() { return null; }
  public Holder<M> getEntityHolderCommand() { return null; }
  public java.util.List<? extends P> getSelection() { return null; }
}
