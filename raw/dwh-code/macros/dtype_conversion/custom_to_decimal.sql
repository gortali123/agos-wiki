{% macro custom_to_decimal(column, precision=13, decimal=2) %}

{# decimal or precision non null #}
{% if decimal is none or precision is none %}
    {{ exceptions.raise_compiler_error("to_importo(): i parametri 'precision' e 'decimal' non possono essere null.") }}
{% endif %}

{# decimal > 0 and precision > 0 #}
{% if decimal <= 0 or precision <= 0 %}
    {{ exceptions.raise_compiler_error("to_importo(): i parametri 'precision' e 'decimal' devono essere maggiori di 0. Ricevuti: precision=" ~ precision ~ ", decimal=" ~ decimal) }}
{% endif %}

{# precision > decimal #}
{% if precision <= decimal %}
    {{ exceptions.raise_compiler_error("to_importo(): il parametro 'precision' deve essere maggiore di 'decimal'. Ricevuti: precision=" ~ precision ~ ", decimal=" ~ decimal) }}
{% endif %}

CAST(
    CASE
        WHEN ({{ column }}) IS NULL
            THEN NULL
        ELSE
            ({{column}}) / POWER(10, {{decimal}})
    END
    AS NUMBER({{ precision }}, {{ decimal }})
)

{% endmacro %}