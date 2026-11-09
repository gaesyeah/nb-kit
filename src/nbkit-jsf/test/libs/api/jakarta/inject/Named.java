package jakarta.inject;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME) public @interface Named { String value() default ""; }
