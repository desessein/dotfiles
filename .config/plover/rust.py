import time

import plover_python_dictionary_cmd

LONGEST_KEY = 1

# ==============================================================================
# CONFIGURATION
# ==============================================================================


@plover_python_dictionary_cmd.register
def delay(engine):
    time.sleep(0.1)


# ==============================================================================
# THE MAPPING
# ==============================================================================

RUST_SNIPPETS = {
    "TP*PB": "rs_fn",
    "HR*ET": "rs_let",
    "PH*AFP": "rs_match",
    "TKR*EUFB": "rs_derive",
    "HRAO*EGS": "rs_logos",
    "HRAO*EP": "rs_lexerloop",
}

RUST_MACROS = {
    "PR*PB": 'println!("{:?}", ${1});{#Left}{#Left}{#Left}',
    "STR*U": "struct ${1:Name} {{#Enter}${0}{#Enter}}{#Up}{#Up}{#Tab}",
}

# ==============================================================================
# THE LOOKUP
# ==============================================================================
trigger_snippet_suffix = "{#Return}"


def lookup(chord):
    if len(chord) != 1:
        raise KeyError

    stroke = chord[0]

    # 1. Macros (Return raw string)
    if stroke in RUST_MACROS:
        return RUST_MACROS[stroke]

    # 2. Snippets (Return the Command String)
    if stroke in RUST_SNIPPETS:
        snippet_text = RUST_SNIPPETS[stroke]

        return snippet_text + delay.str_with_args() + trigger_snippet_suffix

    raise KeyError
