package jakarta.faces.convert;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME) public @interface FacesConverter { String value() default ""; Class<?> forClass() default Object.class; }
