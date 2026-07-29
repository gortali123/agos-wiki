
select
    'OCS' as cd_sorgente,
    cast(a.cser_cod_servizio as varchar(11)) as cd_servizio,
    cast(a.cser_descrizione as varchar(100)) as ds_servizio,
    -- Da Completare quando sarà disponibile la Tabella
    null as cd_pacchetto,
    null as ds_pacchetto,
    null as tp_pacchetto,
    null as tp_classe,
    null as tp_famiglia,
    null as cd_compagnia_contribuzione,
    a.cser_cod_forn as cd_compagnia,
    null as ds_nodo,
    cast(b.ac_rag_sociale_1 as varchar(250)) as ds_compagnia,
    {{ custom_to_date("A.CSER_DATA_INIZIO") }} as dt_inizio_validita,
    {{ custom_to_date("A.CSER_DATA_FINE") }} as dt_fine_validita,
    a.lastmodifieddata as lastmodifieddata
from {{ ref("cctabser") }} a
left join {{ ref("ccanagr") }} b on b.ac_codice = a.cser_cod_forn
where a.fl_deleted = 'N' 
and current_timestamp >= a.ts_inizio_validita and current_timestamp < a.ts_fine_validita
union all
-- Procedura 2: FEA (tblprodottiversioni)
select
    'FEA' as cd_sorgente,
    cast(pv.idprodottoversione as varchar(11)) as cd_servizio,
    pv.dsversione as ds_servizio,
    pv.idprodotto as cd_pacchetto,
    pv.codiceversione as ds_pacchetto,
    null as tp_pacchetto,
    pv.idclasse as tp_classe,
    null as tp_famiglia,
    pr.idcompagnia as cd_compagnia_contribuzione,
    pr.idcompagnia as cd_compagnia,
    n.dsnodo as ds_nodo,
    pr.dsprodotto as ds_compagnia,
    {{ custom_to_date("PV.data_creazione") }} as dt_inizio_validita,
    {{ custom_to_date("PV.data_modifica") }} as dt_fine_validita,
    null as lastmodifieddata
from {{ ref('tblprodottiversioni') }} pv
left join {{ ref("tblprodotti") }} pr 
    on pr.idprodotto = pv.idprodotto
    and current_timestamp >= pr.ts_inizio_validita and current_timestamp < pr.ts_fine_validita
left join {{ ref("tblnodi") }} n 
    on n.idnodo = pr.idcompagnia
    and current_timestamp >= n.ts_inizio_validita and current_timestamp < n.ts_fine_validita
where current_timestamp >= pv.ts_inizio_validita and current_timestamp < pv.ts_fine_validita
