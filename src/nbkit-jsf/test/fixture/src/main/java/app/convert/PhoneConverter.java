package app.convert;

import jakarta.faces.convert.FacesConverter;

/** registered with its full name as id, the way a page can name it: converter="app.convert.PhoneConverter" */
@FacesConverter("app.convert.PhoneConverter")
public class PhoneConverter {
}
