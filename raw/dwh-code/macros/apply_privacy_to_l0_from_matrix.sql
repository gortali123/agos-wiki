{% macro apply_privacy_to_l0_from_matrix(results) %}
  {% if execute %}

    {{ log("========== INIZIO SETUP TAG E MASKING POLICY ==========", info=True) }}

    {% set setup_schema %}
      CREATE SCHEMA IF NOT EXISTS AGOS_DEV_16000.TAGS;
    {% endset %}
    {% do run_query(setup_schema) %}

    {% set setup_tag %}
      CREATE TAG IF NOT EXISTS AGOS_DEV_16000.TAGS.sensitivity
        ALLOWED_VALUES 'DOLLAR', 'SPACES', 'ZEROS';
    {% endset %}
    {% do run_query(setup_tag) %}

    {% set unset_policy %}
      ALTER TAG AGOS_DEV_16000.TAGS.sensitivity
        UNSET MASKING POLICY AGOS_DEV_16000.TAGS.policy_mask_by_sensitivity;
    {% endset %}
    {% do run_query(unset_policy) %}
    {{ log("⚠️  UNSET policy eseguito.", info=True) }}

    {% set create_policy %}
      CREATE OR REPLACE MASKING POLICY AGOS_DEV_16000.TAGS.policy_mask_by_sensitivity
      AS (val STRING) RETURNS STRING ->
        CASE
          WHEN CURRENT_ROLE() = 'DEVELOPER' THEN val
          WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('AGOS_DEV_16000.TAGS.SENSITIVITY') = 'DOLLAR'
            THEN REGEXP_REPLACE(val, '.', '$')
          WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('AGOS_DEV_16000.TAGS.SENSITIVITY') = 'SPACES'
            THEN REGEXP_REPLACE(val, '.', ' ')
          WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('AGOS_DEV_16000.TAGS.SENSITIVITY') = 'ZEROS'
            THEN REGEXP_REPLACE(val, '.', '0')
          ELSE '********'
        END;
    {% endset %}
    {% do run_query(create_policy) %}
    {{ log("✅ Masking policy creata/aggiornata.", info=True) }}
    {% set set_policy %}
      ALTER TAG AGOS_DEV_16000.TAGS.sensitivity
        SET MASKING POLICY AGOS_DEV_16000.TAGS.policy_mask_by_sensitivity;
    {% endset %}
    {% do run_query(set_policy) %}
    {{ log("✅ Policy associata al tag.", info=True) }}

    {{ log("========== FINE SETUP TAG E MASKING POLICY ==========", info=True) }}

    {{ log("========== INIZIO APPLICAZIONE MATRICE PRIVACY SU LIVELLO L0 ==========", info=True) }}

    {% set matrix = var('l0_privacy_matrix', {}) %}
    {% set tag_name = 'AGOS_DEV_16000.TAGS.sensitivity' %}
    {% set target_database = 'AGOS_DEV_16000' %}
    {% set target_schema = 'L0' %}

    {{ log("🔍 dbt sta leggendo la matrice: " ~ matrix, info=True) }}

    {% for table_name, columns in matrix.items() %}
      {% for column_name, tag_value in columns.items() %}

        {% set target_table = target_database ~ "." ~ target_schema ~ "." ~ table_name %}

        {% set alter_query %}
          ALTER TABLE {{ target_table }}
            MODIFY COLUMN {{ column_name }}
            SET TAG {{ tag_name }} = '{{ tag_value }}';
        {% endset %}

        {{ log("🔒 Blindatura L0 -> " ~ target_table | upper ~ "." ~ column_name | upper ~ " = " ~ tag_value, info=True) }}
        {% do run_query(alter_query) %}

      {% endfor %}
    {% endfor %}

    {{ log("========== FINE APPLICAZIONE MATRICE PRIVACY SU LIVELLO L0 ==========", info=True) }}

  {% endif %}
{% endmacro %}