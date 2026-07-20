-- Macro per gestione tag root - tag child
{%- macro flatten_xml(root_xml_col, child_tag_name, alias, dt_type='VARCHAR', outer=false) -%}
    -- versione deprecata -- LATERAL FLATTEN(input => { root_xml_col }:"$", OUTER => {{ outer | upper }}) {{ alias }}
    LATERAL FLATTEN(input => TO_ARRAY({{ root_xml_col }}:"$"), OUTER => {{ outer | upper }}) {{ alias }}
    WHERE {{ alias }}.value:"@"::{{ dt_type }} = '{{ child_tag_name }}'
{%- endmacro -%}


-- Macro per estrazione nodi figli in unica root
{%- macro get_xml_path(xml_col, path_string, data_type='VARCHAR') -%}
    {# Suddivide il percorso (es. 'ChargingTimings/Start/Day') in una lista #}
    {%- set tags = path_string.split('/') -%}
    {%- set ns = namespace(current_expr = xml_col) -%}
    {# Cicla per annidare gli XMLGET in base alla lunghezza del percorso #}
    {%- for tag in tags -%}
        {%- set ns.current_expr = "XMLGET(" ~ ns.current_expr ~ ", '" ~ tag ~ "')" -%}
    {%- endfor -%}
    {# Estrae il valore testuale finale e fa il cast al tipo di dato richiesto #}
    {{ ns.current_expr }}:"$"::{{ data_type }}
{%- endmacro -%}