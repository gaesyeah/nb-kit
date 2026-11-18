package app.convert;

import jakarta.faces.validator.FacesValidator;

/** a validator is looked up by its id too: f:validator validatorId="app.cpf" */
@FacesValidator("app.cpf")
public class CpfValidator {
}
