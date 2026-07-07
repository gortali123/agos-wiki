{# -----------------------------------------------------------
   check_values(campo, valori)
   Campo obbligatorio con dominio fisso.
   valori: lista python es. ['Y','N']
   → COUNT_IF(campo IS NULL OR campo NOT IN ('Y','N'))
----------------------------------------------------------- #}
{% macro check_values(campo, valori) %}
    COUNT_IF(
        {{ campo }} IS NULL
        OR {{ campo }} NOT IN (
            {% for v in valori %}'{{ v }}'{% if not loop.last %}, {% endif %}{% endfor %}
        )
    )
{% endmacro %}