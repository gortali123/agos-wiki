{#
  Chiude (SCD2) i record aperti sul target la cui chiave non e' piu' presente nello
  snapshot full corrente. Nessun DELETE: valorizza TS_FINE_VALIDITA. Post_hook, solo in
  incrementale.

  Descrizione della discesa XML tramite `levels` (una voce per livello di nodo ripetuto),
  root -> level_1 -> level_2 -> ...  Ogni livello e' un dict:
    - wrapper : (opz.) tag contenitore ripetuto (es. 'Plans'). Se assente, il `node` viene
                flattenato direttamente sul nodo del livello precedente (nodo figlio diretto,
                es. <ChargingProfile> sotto <Loan>).
    - node    : tag del singolo nodo ripetuto (es. 'Plan').
    - keys    : lista (anche vuota, per livelli solo di passaggio) di dict:
                  - name     : nome colonna sul target
                  - path     : path XML dentro il nodo (assente = testo del nodo :"$")
                  - type     : cast (default 'VARCHAR(50)')
                  - coalesce : default se il campo e' NULL (es. "'ND'"); deve combaciare con
                               la COALESCE usata nel modello.
  root_key_cols : colonne di PK prese dal livello root (valore di root_path), es. ['CD_CLIENTE'].
                  Per entita' root-only (nessun nodo ripetuto) passa levels=[] e questi.
  open_sentinel : valore del record aperto; DEVE combaciare con cio' che scrive ts_fine_validita.
                  Se none -> IS NULL.
#}
{% macro chiudi_finestre_scd2_sword(
        source_name,
        root_path,
        levels,
        root_key_cols=[],
        xml_col='GN_VALUE',
        ts_fine_col='TS_FINE_VALIDITA',
        lastmod_col='LASTMODIFIEDDATA',
        open_sentinel="'9999-12-31 00:00:00'::TIMESTAMP_NTZ"
) %}
{% if is_incremental() %}
{%- set ns = namespace(carry=['ROOT_KEY'], prev='r') -%}
UPDATE {{ this }} tgt
SET tgt.{{ ts_fine_col }} = (SELECT MAX({{ lastmod_col }}) FROM {{ this }})
WHERE tgt.{{ ts_fine_col }} {% if open_sentinel is none %}IS NULL{% else %}= {{ open_sentinel }}{% endif %}
  AND NOT EXISTS (
      SELECT 1
      FROM (
          WITH bd AS (
              SELECT PARSE_XML({{ xml_col }}) AS org_xml FROM {{ ref(source_name) }}
          ),
          r AS (
              SELECT
                  {{ get_xml_path('org_xml', root_path, 'VARCHAR(50)') }} AS ROOT_KEY,
                  org_xml AS node_xml
              FROM bd
          )
          {%- for lvl in levels %},
          {%- if lvl.get('wrapper') %}
          w{{ loop.index }} AS (
              SELECT
                  {%- for c in ns.carry %}
                  s.{{ c }},
                  {%- endfor %}
                  fl.value AS wrap_xml
              FROM {{ ns.prev }} s,
              {{ flatten_xml('s.node_xml', lvl['wrapper'], 'fl', outer=true) }}
          ),
          {%- endif %}
          n{{ loop.index }} AS (
              SELECT
                  {%- for c in ns.carry %}
                  s.{{ c }},
                  {%- endfor %}
                  nd.value AS node_xml
                  {%- for k in lvl['keys'] %},
                  {%- set kext %}{% if k.get('path') %}{{ get_xml_path('nd.value', k.path, k.get('type', 'VARCHAR(50)')) }}{% else %}nd.value:"$"::{{ k.get('type', 'VARCHAR(50)') }}{% endif %}{% endset %}
                  {% if k.get('coalesce') is not none %}COALESCE({{ kext }}, {{ k.coalesce }}){% else %}{{ kext }}{% endif %} AS {{ k.name }}
                  {%- endfor %}
              FROM {% if lvl.get('wrapper') %}w{{ loop.index }}{% else %}{{ ns.prev }}{% endif %} s,
              {{ flatten_xml(('s.wrap_xml' if lvl.get('wrapper') else 's.node_xml'), lvl['node'], 'nd', outer=true) }}
          )
          {%- set ns.carry = ns.carry + (lvl['keys'] | map(attribute='name') | list) -%}
          {%- set ns.prev = 'n' ~ loop.index -%}
          {%- endfor %}
          SELECT {{ ns.carry | join(', ') }}
          FROM {{ ns.prev }}
      ) src
      WHERE 1=1
      {%- for name in root_key_cols %}
        AND src.ROOT_KEY = tgt.{{ name }}
      {%- endfor %}
      {%- for name in ns.carry if name != 'ROOT_KEY' %}
        AND src.{{ name }} = tgt.{{ name }}
      {%- endfor %}
  )
{% endif %}
{% endmacro %}