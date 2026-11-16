package example;

/** A generic class of the project itself: its value has the type given to T. */
public class Holder<T> {

    private final T value;

    public Holder(T value) {
        this.value = value;
    }

    public T getValue() {
        return value;
    }
}
