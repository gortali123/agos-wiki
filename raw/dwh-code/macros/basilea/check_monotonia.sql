{# -----------------------------------------------------------
   check_monotonia(campo_maggiore, campo_minore)
   Verifica campo_maggiore >= campo_minore; entrambi devono essere NOT NULL.
   Es (catena a 3): usare due volte in UNION ALL o nidificare
   {{ check_monotonia('MAX_INS_CLI_L18M', 'MAX_INS_CLI_L9M') }}
   → COUNT_IF(
         MAX_INS_CLI_L18M IS NULL OR MAX_INS_CLI_L9M IS NULL
         OR MAX_INS_CLI_L18M < MAX_INS_CLI_L9M
     )
----------------------------------------------------------- #}
{% macro check_monotonia(campo_maggiore, campo_minore) %}
    COUNT_IF(
        {{ campo_maggiore }} IS NULL
        OR {{ campo_minore }} IS NULL
        OR {{ campo_maggiore }} < {{ campo_minore }}
    )
{% endmacro %}