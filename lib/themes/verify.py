"""Before installing a theme: the NetBeans installation is found, has the base profile, and its lexers still have
the tokens the coloring module uses; warns when NetBeans runs on a Java older than 17.
    verify.py <userdir>      (exits 2 with the reason when the installation is not usable)"""
import os
import re
import struct
import sys

from nbinstall import Jars, base_profile
from text import T

# lexer classes and the token names the coloring module (nbkit-colors) looks for
NEEDED = {
    'Java': ('org/netbeans/api/java/lexer/JavaTokenId.class',
             'LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET'),
    'JavaScript/JSON': ('org/netbeans/modules/javascript2/lexer/api/JsTokenId.class',
                        'IDENTIFIER PRIVATE_IDENTIFIER WHITESPACE EOL BRACKET_LEFT_PAREN BRACKET_RIGHT_PAREN '
                        'BRACKET_LEFT_CURLY BRACKET_RIGHT_CURLY BRACKET_LEFT_BRACKET BRACKET_RIGHT_BRACKET '
                        'OPERATOR_DOT OPERATOR_OPTIONAL_ACCESS OPERATOR_ARROW OPERATOR_ASSIGNMENT OPERATOR_COMMA '
                        'OPERATOR_SEMICOLON OPERATOR_COLON KEYWORD_INSTANCEOF KEYWORD_VAR RESERVED_LET KEYWORD_CONST '
                        'KEYWORD_FUNCTION KEYWORD_CATCH KEYWORD_CLASS KEYWORD_THIS KEYWORD_SUPER KEYWORD_TRUE '
                        'KEYWORD_FALSE KEYWORD_NULL TEMPLATE_EXP_BEGIN TEMPLATE_EXP_END'),
    'CSS/SCSS/LESS': ('org/netbeans/modules/css/lib/api/CssTokenId.class',
                      'IDENT LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET SEMI DOT COLON DCOLON HASH HASH_SYMBOL '
                      'LESS_AND MINUS PERCENTAGE_SYMBOL WS NL COMMENT LINE_COMMENT URI URL OPEQ INCLUDES DASHMATCH '
                      'BEGINS ENDS CONTAINS SASS_INCLUDE SASS_MIXIN SASS_FUNCTION SASS_VAR VARIABLE IMPORTANT_SYM '
                      'KEYFRAMES_SYM PERCENTAGE LENGTH EMS REM DIMENSION STAR GREATER TILDE PLUS CP_EQ CP_NOT_EQ'),
    'EL': ('org/netbeans/modules/el/lexer/api/ELTokenId.class',
           'IDENTIFIER DOT LPAREN RPAREN LBRACKET RBRACKET WHITESPACE EOL TRUE_KEYWORD FALSE_KEYWORD NULL_KEYWORD'),
    'HTML': ('org/netbeans/api/html/lexer/HTMLTokenId.class', 'DECLARATION'),
}


def die(msg):
    print(os.environ.get('NBKIT_R', '') + T('cli.error') + os.environ.get('NBKIT_N', '') + ' ' + msg, file=sys.stderr)
    sys.exit(2)


def missing_tokens(jars):
    """[(language, [token names the class no longer has])] (a language not installed has nothing to color)"""
    out = []
    for lang, (cls, names) in NEEDED.items():
        data = jars.read(cls)
        if data is None:
            continue
        missing = [n for n in names.split() if struct.pack('>H', len(n)) + n.encode() not in data]
        if missing:
            out.append((lang, missing))
    return out


def main():
    ud = sys.argv[1]
    base = os.environ.get('NBKIT_THEME_BASE', 'FlatLafDark')
    jars = Jars(ud)
    if not jars.paths:
        die(T('theme.no_netbeans'))
    if not any(m == '' for m, *_ in base_profile(jars, base)):
        die(T('theme.no_base_colors', os.environ.get('NBKIT_THEME_BASE_NAME', 'FlatLaf Dark')))
    problems = missing_tokens(jars)
    if problems:
        print(T('theme.tokens_missing'))
        print('\n'.join(f'  {lang}: {", ".join(names)}' for lang, names in problems))
    log = os.path.join(ud, 'var', 'log', 'messages.log')
    if os.path.exists(log):
        with open(log, errors='replace') as f:
            m = re.search(r'Java; VM; Vendor\s*=\s*(\d+)', f.read())
        if m and int(m.group(1)) < 17:
            print(T('theme.old_java', m.group(1)))


if __name__ == '__main__':
    main()
