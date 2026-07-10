{#
  Pre-hook per snapshot: replica il comportamento --full-refresh delle tabelle normali.

  I dbt snapshot ignorano il flag --full-refresh (fanno sempre merge incrementale sulla
  unique_key). Droppando la relazione qui, in pre-hook, dbt la trova inesistente e la
  ricostruisce da zero come fosse il primo run.

  Attenzione: a differenza del full-refresh su una tabella normale (che puo' ricostruire
  l'intera storia dalla sorgente), uno snapshot droppato riparte con una singola riga
  "aperta" per ogni record corrente della sorgente: tutta la storia SCD2 accumulata nello
  snapshot fino a quel momento viene persa e NON e' ricostruibile, perche' la sorgente ha
  solo lo stato attuale, non le versioni passate.
#}
{% macro drop_on_full_refresh() %}
  {% if flags.FULL_REFRESH %}
    {% do log('--full-refresh: drop snapshot ' ~ this, info=true) %}
    {% do adapter.drop_relation(this) %}
  {% endif %}
{% endmacro %}
