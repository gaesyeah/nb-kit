package com.sun.faces.cdi;

/** like Mojarra's: the implicit object #{resource} given to CDI as a @Named producer */
public class ResourceHandlerProducer {
    @jakarta.inject.Named("resource")
    public jakarta.faces.application.ResourceHandler produce() {
        return null;
    }
}
