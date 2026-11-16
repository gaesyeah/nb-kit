package example;

import jakarta.inject.Named;

/** The bean of the page (#{greeter}). */
@Named
public class Greeter {

    public String getName() {
        return "nbkit";
    }

    public int count(String text) {
        return text.length();
    }

    public Holder<Person> getPerson() {
        return new Holder<>(new Person("Ana"));
    }
}
