package jakarta.faces.validator;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME) public @interface FacesValidator { String value() default ""; }
