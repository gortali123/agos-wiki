	{% macro transcod_dtype(data_type, length_col) %}
  {%- set dt = data_type | upper | trim -%}
  {%- set l  = length_col | string | trim -%}
  {%- set has_length = l not in ('', 'None', 'none', 'null', 'NULL') and l is not none -%}
  {%- set result = 'TRANSCOD_ERROR' -%}

  {%- if dt in ('CHAR', 'VARCHAR', 'STRING') and has_length -%}
    {%- set result = 'VARCHAR(' ~ l ~ ')' -%}
  {%- elif dt in ('NUMERIC', 'DECIMAL', 'NUMBER') and has_length -%}
    {%- set result = 'NUMBER(' ~ l ~ ')' -%}  
  {%- elif dt in ('BOOLEAN', 'BINARY') -%}
    {%- set result = 'BOOLEAN' -%}
  {%- elif dt == 'DATE' -%}
    {%- set result = 'DATE' -%}
  {%- elif dt in ('INT', 'INTEGER', 'SMALLINT', 'TINYINT', 'BIGINT') -%}
    {%- set result = 'NUMBER(38, 0)' -%}
  {%- elif 'TIMESTAMP' in dt or 'TINMESTAMP' in dt -%}
    {%- set result = 'TIMESTAMP_NTZ' -%}
  {%- elif 'TEXT' in dt or 'VARCHAR' in dt or 'CHAR' in dt or 'STRING' in dt -%}    
    {%- set result = 'VARCHAR' -%}
  {%- elif 'FLOAT' in dt or 'DOUBLE' in dt or 'REAL' in dt -%}
    {%- set result = 'NUMBER(38,10)' -%}
  {%- elif 'NUMBER' in dt or 'NUMERIC' in dt or 'DECIMAL' in dt -%}
    {%- set result = 'NUMBER(38,10)' -%}
  {%- elif 'VARIANT' in dt or 'OBJECT' in dt or 'ARRAY' in dt -%}
    {%- set result = 'VARIANT' -%}
  {%- endif -%}

  {{ return(result) }}
{% endmacro %}