{#
  dbt snapshot non supporta nativamente --full-refresh: la materialization
  snapshot decide se la tabella target esiste (e con quali colonne) PRIMA di
  eseguire eventuali pre-hook, quindi droppare la tabella da un pre-hook sullo
  snapshot stesso disallinea lo stato interno della materialization dal DB e
  produce errori tipo "tried to drop relation ... but its type is null" o
  "snapshot target is missing configured columns".

  Questo macro va agganciato come on-run-start a livello di dbt_project.yml
  (non come pre-hook di uno snapshot): a quel punto del run nessuno snapshot
  ha ancora iniziato la propria materialization, quindi il drop e' sicuro.
  Droppa solo gli snapshot effettivamente selezionati nell'invocazione
  corrente, e solo se il flag --full-refresh e' stato passato.
#}
{% macro drop_snapshots_on_full_refresh() %}
  {% if execute and flags.FULL_REFRESH %}
    {% for node in graph.nodes.values() | selectattr('resource_type', 'equalto', 'snapshot') %}
      {% if node.unique_id in selected_resources %}
        {% set relation = adapter.get_relation(database=node.database, schema=node.schema, identifier=node.alias) %}
        {% if relation is not none %}
          {% do log('--full-refresh: drop snapshot ' ~ relation, info=true) %}
          {% do adapter.drop_relation(relation) %}
        {% endif %}
      {% endif %}
    {% endfor %}
  {% endif %}
{% endmacro %}
