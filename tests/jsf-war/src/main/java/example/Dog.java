package example;

public class Dog implements Pet {

    @Override
    public String getName() {
        return "Rex";
    }

    /** only here, not in Pet: EL finds it at runtime, since the object is a Dog */
    public String getBark() {
        return "woof";
    }
}
