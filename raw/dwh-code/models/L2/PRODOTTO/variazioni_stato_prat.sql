-------------------- PROCEDURA CQ ----------------------------

with base_cq as (
    select
        a.QPRST_NUM_PRATICA,
        a.QPRST_STATO,
        a.QPRST_ATTRIBUTO,
        a.QPRST_UTENTE,
        a.QPRST_EVENTO,
        a.LASTMODIFIEDDATA,
        a.QPRST_DATA,
        a.QPRST_TIME,
        {{ custom_to_timestamp_ntz('a.QPRST_DATA', 'a.QPRST_TIME')}} as TS_EVENTO
        --to_timestamp_ntz(QPRST_DATA || ' ' || lpad(QPRST_TIME,6,'0'),'YYYYMMDD HH24MISS') as TS_EVENTO
    from {{ ref('qsprast') }} a
    WHERE FL_DELETED = 'N'
    and a.QPRST_TIME <> '900000'  -- elimina completata fix su L1
    and a.QPRST_TIME not like '%60'  -- elimina completata fix su L1
),

int_1_cq as (
    select
        'CQ' as TP_PROCEDURA
        ,a.QPRST_NUM_PRATICA AS CD_PRATICA
        ,a.TS_EVENTO as TS_INIZIO_VALIDITA
        ,CAST(a.QPRST_STATO AS VARCHAR(2)) AS CD_STATO
        ,b.QTSTA_DESCRIZIONE as DS_STATO
        ,a.QPRST_ATTRIBUTO AS CD_ATTRIBUTO
        ,c.QTATR_DESCRIZIONE AS DS_ATTRIBUTO
        ,a.QPRST_UTENTE AS CD_UTENTE
        ,a.QPRST_EVENTO AS CD_EVENTO
        ,a.LASTMODIFIEDDATA
    from base_cq a
    left join {{ ref('qstabsta') }} as b 
        on a.QPRST_STATO = b.QTSTA_STATO
        and b.TS_FINE_VALIDITA = TO_TIMESTAMP_NTZ('9999-12-31 00:00:00.000')
        AND B.FL_DELETED = 'N'
    left join {{ ref('qstabatr') }} as c 
        on a.QPRST_ATTRIBUTO = c.QTATR_ATTRIBUTO
        and c.TS_FINE_VALIDITA = TO_TIMESTAMP_NTZ('9999-12-31 00:00:00.000')
        AND C.FL_DELETED = 'N'
)

, fin_cq as (select
    TP_PROCEDURA,
    CD_PRATICA,
    TS_INIZIO_VALIDITA,
    -- vecchia versione -- cast(coalesce(TS_FINE_VALIDITA_raw, '9999-12-31'::timestamp) as timestamp_ntz) as TS_FINE_VALIDITA,
    {{ ts_fine_validita('TP_PROCEDURA, CD_PRATICA', 'TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
    CD_STATO,
    DS_STATO,
    CD_ATTRIBUTO,
    DS_ATTRIBUTO,
    CD_UTENTE,
    CD_EVENTO,
    LASTMODIFIEDDATA
from int_1_cq
),

dedup_cq AS (
    SELECT
        TP_PROCEDURA,
        CD_PRATICA,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_STATO,
        DS_STATO,
        CD_ATTRIBUTO,
        DS_ATTRIBUTO,
        CD_UTENTE,
        CD_EVENTO,
        LASTMODIFIEDDATA,
        {{ hash_cols([
            'TP_PROCEDURA',
            'CD_PRATICA',
            'CD_STATO',
            'DS_STATO',
            'CD_ATTRIBUTO',
            'DS_ATTRIBUTO',
            'CD_UTENTE',
            'CD_EVENTO'
        ]) }} AS HASHED_COLS
    FROM fin_cq
    {{ is_incremental_S1('TP_PROCEDURA, CD_PRATICA') }}
),

-------------------- PROCEDURA CO ----------------------------

base_co as (
    select
        a.PLPRA_NUM_PRATICA,
        a.PLPRA_STATO,
        a.PLPRA_ATTRIBUTO,
        a.PLPRA_UTENTE,
        a.LASTMODIFIEDDATA,
        a.PLPRA_DATA,
        a.PLPRA_TIME,
        {{ custom_to_timestamp_ntz('a.PLPRA_DATA', 'PLPRA_TIME')}} as TS_EVENTO
    from {{ ref('plpratst') }} A
    WHERE A.FL_DELETED = 'N'
),

int_1_co as (
    select
        'CO' as TP_PROCEDURA
        ,a.PLPRA_NUM_PRATICA AS CD_PRATICA
        ,a.TS_EVENTO as TS_INIZIO_VALIDITA
        ,CAST(a.PLPRA_STATO AS VARCHAR(2)) AS CD_STATO
        ,b.PLSTAT_DESCRIZIONE AS DS_STATO
        ,a.PLPRA_ATTRIBUTO AS CD_ATTRIBUTO
        ,c.PLATT_DESCRIZIONE AS DS_ATTRIBUTO
        ,a.PLPRA_UTENTE AS CD_UTENTE
        ,null AS CD_EVENTO
        ,a.LASTMODIFIEDDATA
    from base_co as a
    left join {{ ref('pltbfstat') }} as b
    on a.PLPRA_STATO = b.PLSTAT_CODICE
    AND b.TS_FINE_VALIDITA = TO_TIMESTAMP_NTZ('9999-12-31 00:00:00.000')
    AND B.FL_DELETED = 'N'
    left join {{ ref('pltbfattr') }} as c
    on a.PLPRA_ATTRIBUTO = c.PLATT_COD_ATTRIBUTO
    and c.TS_FINE_VALIDITA = TO_TIMESTAMP_NTZ('9999-12-31 00:00:00.000')
    AND C.FL_DELETED = 'N'
)

, fin_co as (select
    TP_PROCEDURA,
    CD_PRATICA,
    TS_INIZIO_VALIDITA,
    -- vecchia versione -- cast(coalesce(TS_FINE_VALIDITA_raw, '9999-12-31'::timestamp) as timestamp_ntz) as TS_FINE_VALIDITA,
    {{ ts_fine_validita('TP_PROCEDURA, CD_PRATICA', 'TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
    CD_STATO,
    DS_STATO,
    CD_ATTRIBUTO,
    DS_ATTRIBUTO,
    CD_UTENTE,
    CD_EVENTO,
    LASTMODIFIEDDATA
from int_1_co
),

dedup_co AS (
    SELECT
        TP_PROCEDURA,
        CD_PRATICA,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_STATO,
        DS_STATO,
        CD_ATTRIBUTO,
        DS_ATTRIBUTO,
        CD_UTENTE,
        CD_EVENTO,
        LASTMODIFIEDDATA,
        {{ hash_cols([
            'TP_PROCEDURA', 'CD_PRATICA', 'CD_STATO', 'DS_STATO', 'CD_ATTRIBUTO',
            'DS_ATTRIBUTO', 'CD_UTENTE', 'CD_EVENTO']) }} AS HASHED_COLS
    FROM fin_co
    {{ is_incremental_S1('TP_PROCEDURA, CD_PRATICA') }}
),

-------------------- PROCEDURA CA ----------------------------

base_ca as (
    select
        a.LOGSB_NUM_CARTA,
        a.LOGSB_CODICE,
        a.LOGSB_OPERATORE,
        a.LASTMODIFIEDDATA,
        a.LOGSB_DATA,
        a.LOGSB_ORA,
        {{ custom_to_timestamp_ntz('a.LOGSB_DATA', 'a.LOGSB_ORA')}} as TS_EVENTO
        --to_timestamp_ntz(LOGSB_DATA || ' ' || lpad(LOGSB_ORA,6,'0'),'YYYYMMDD HH24MISS') as TS_EVENTO
    from {{ ref('crlogstbl') }} a
    WHERE FL_DELETED = 'N'
),

int_1_ca as (
    select
        'CA' as TP_PROCEDURA
        ,a.LOGSB_NUM_CARTA AS CD_PRATICA
        ,a.TS_EVENTO as TS_INIZIO_VALIDITA
        ,CAST(a.LOGSB_CODICE AS VARCHAR(2)) AS CD_STATO
        ,b.CRTSTA_DESCRIZIONE as DS_STATO
        ,null AS CD_ATTRIBUTO
        ,null as DS_ATTRIBUTO
        ,a.LOGSB_OPERATORE AS CD_UTENTE
        ,null AS CD_EVENTO
        ,a.LASTMODIFIEDDATA
    from base_ca as a
    left join {{ ref('crtabsta') }} as b 
    on a.LOGSB_CODICE = b.CRTSTA_STATO
    and b.TS_FINE_VALIDITA = TO_TIMESTAMP_NTZ('9999-12-31 00:00:00.000')
    AND B.FL_DELETED = 'N'
)

, fin_ca as (select
    TP_PROCEDURA,
    CD_PRATICA,
    TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('TP_PROCEDURA, CD_PRATICA', 'TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
    CD_STATO,
    DS_STATO,
    CD_ATTRIBUTO,
    DS_ATTRIBUTO,
    CD_UTENTE,
    CD_EVENTO,
    LASTMODIFIEDDATA
from int_1_ca
 {% if is_incremental() %}
    -- Considero solo le pratiche che hanno record più recenti
    -- rispetto all'ultima estrazione già processata
    where CD_PRATICA in (
        select distinct LOGSB_NUM_CARTA 
        FROM {{ ref('crlogstbl') }}
        where LASTMODIFIEDDATA > (
            select max(LASTMODIFIEDDATA) from {{ this }}))
    {% endif %}
),

dedup_ca AS (
    SELECT
        TP_PROCEDURA,
        CD_PRATICA,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_STATO,
        DS_STATO,
        CD_ATTRIBUTO,
        DS_ATTRIBUTO,
        CD_UTENTE,
        CD_EVENTO,
        LASTMODIFIEDDATA,
        {{ hash_cols([
            'TP_PROCEDURA', 'CD_PRATICA', 'CD_STATO', 'DS_STATO', 'CD_ATTRIBUTO',
            'DS_ATTRIBUTO', 'CD_UTENTE', 'CD_EVENTO'
        ]) }} AS HASHED_COLS
    FROM fin_ca
    {{ is_incremental_S1('TP_PROCEDURA, CD_PRATICA') }}
)

select 
   TP_PROCEDURA,
   CD_PRATICA,
   TS_INIZIO_VALIDITA,
   {{ ts_fine_validita('TP_PROCEDURA, CD_PRATICA', 'TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
   CD_STATO,
   DS_STATO,
   CD_ATTRIBUTO,
   DS_ATTRIBUTO,
   CD_UTENTE,
   CD_EVENTO,
   LASTMODIFIEDDATA
from dedup_cq
union all
select 
   TP_PROCEDURA,
   CD_PRATICA,
   TS_INIZIO_VALIDITA,
   {{ ts_fine_validita('TP_PROCEDURA, CD_PRATICA', 'TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
   CD_STATO,
   DS_STATO,
   CD_ATTRIBUTO,
   DS_ATTRIBUTO,
   CD_UTENTE,
   CD_EVENTO,
   LASTMODIFIEDDATA
from dedup_co
union all
select 
   TP_PROCEDURA,
   CD_PRATICA,
   TS_INIZIO_VALIDITA,
   {{ ts_fine_validita('TP_PROCEDURA, CD_PRATICA', 'TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
   CD_STATO,
   DS_STATO,
   CD_ATTRIBUTO,
   DS_ATTRIBUTO,
   CD_UTENTE,
   CD_EVENTO,
   LASTMODIFIEDDATA
from dedup_ca