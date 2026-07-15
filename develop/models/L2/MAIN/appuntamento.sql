WITH base AS (

    SELECT
        NULL AS CD_APPUNTAMENTO, -- WARN: sorgente dichiarata 'BusinessID/subjectID' su 4314_Appointment non e' un nome di colonna valido e non c'e' RT che la disambigui; questo campo e' l'unica PK dell'entita', da chiarire col team prima di usare il modello
        A.version AS PR_APPUNTAMENTO,
        {{ custom_to_timestamp_ntz('A.startValidity') }} AS TS_INIZIO_VALIDITA,
        {{ custom_to_timestamp_ntz('A.endValidity') }} AS TS_FINE_VALIDITA,
        A.subjectCode AS CD_CLIENTE,
        NULL AS CD_PRATICA, -- WARN: stessa sorgente ambigua 'BusinessID/subjectID' di CD_APPUNTAMENTO, vedi sopra
        NULL AS TP_PROCEDURA, -- WARN: stessa sorgente ambigua 'BusinessID/subjectID' di CD_APPUNTAMENTO, vedi sopra
        A.branchCode AS CD_FILIALE,
        {{ custom_to_timestamp_ntz('A.startValidity') }} AS TS_PRESA_APPUNTAMENTO,
        {{ custom_to_timestamp_ntz('A.scheduledDate') }} AS TS_APPUNTAMENTO,
        {{ custom_to_timestamp_ntz('A.actualDate') }} AS TS_APPUNTAMENTO_EFFETTIVO,
        TIMESTAMPDIFF(MINUTE, A.scheduledDate, A.actualDate) AS NM_DURATA_APPUNTAMENTO,
        CASE
            WHEN HOUR(A.scheduledDate) = 9 THEN 1
            WHEN HOUR(A.scheduledDate) = 10 THEN 2
            WHEN HOUR(A.scheduledDate) = 11 THEN 3
            WHEN HOUR(A.scheduledDate) = 12 THEN 4
            WHEN HOUR(A.scheduledDate) = 13 THEN 5
            WHEN HOUR(A.scheduledDate) = 14 THEN 6
            WHEN HOUR(A.scheduledDate) = 15 THEN 7
            WHEN HOUR(A.scheduledDate) = 16 THEN 8
        END AS CD_SLOT_APPUNTAMENTO,
        A.appointmentTypeId AS CD_TIPO_APPUNTAMENTO,
        A.status AS CD_STATO_APPUNTAMENTO,
        CASE A.status
            WHEN 'SCHEDULED' THEN 'Pianificato'
            WHEN 'COMPLETED' THEN 'Completato'
            WHEN 'CANCELLED' THEN 'Annullato'
            ELSE A.status
        END AS DS_STATO_APPUNTAMENTO,
        NULL AS CD_UTENTE_APPUNTAMENTO, -- WARN: TAB/COL/RT tutti vuoti nel data model, nessuna sorgente indicata
        CASE
            WHEN A.actualDate > A.scheduledDate THEN 'S'
            ELSE 'N'
        END AS FL_POSTICIPO,
        CASE
            WHEN A.status IN ('SCHEDULED', 'COMPLETED') THEN 'S'
            ELSE 'N'
        END AS FL_FUNNEL,
        -- WARN: le 4 RT seguenti (NM_RISORSE_DISPONIBILI_SLOT, NM_APPUNTAMENTI_SLOT, FL_SOVRA_ALLOCAZIONE, FL_GIORNO_FESTIVO) nel data model hanno l'alias interno della SELECT che non corrisponde al nome del campo dichiarato: sembra un disallineamento a catena di una riga tra le RT. Trascritte esattamente come scritte, solo rinominate al campo dichiarato.
        CASE
            WHEN NWD.DATE IS NOT NULL OR NWDO.DATE IS NOT NULL THEN 'S'
            ELSE 'N'
        END AS NM_RISORSE_DISPONIBILI_SLOT, -- WARN: RT originale calcola un flag ('S'/'N') su un campo dichiarato NUMBER(5); mismatch di tipo, l'alias interno della RT era 'FL_GIORNO_FESTIVO'
        COALESCE(
            (
                SELECT RO.resourceCount
                FROM 4321_cfg_ResourceAvailabilityOverride RO
                WHERE RO.branchId = A.branchId
                  AND RO.DATE = DATE(A.scheduledDate)
                  AND TIME(A.scheduledDate) >= RO.timeSlotStart AND TIME(A.scheduledDate) < RO.timeSlotEnd
            ),
            (
                SELECT R.resourceCount
                FROM 4320_cfg_ResourceAvailability R
                WHERE R.branchId = A.branchId
                  AND R.dayOfWeek = DAYOFWEEK(A.scheduledDate)
                  AND TIME(A.scheduledDate) >= R.timeSlotStart AND TIME(A.scheduledDate) < R.timeSlotEnd
            )
        ) AS NM_APPUNTAMENTI_SLOT, -- WARN: l'alias interno della RT originale era 'NM_RISORSE_DISPONIBILI_SLOT'; qui rinominato al campo dichiarato
        (
            SELECT COUNT(*)
            FROM 4314_Appointment A2
            WHERE A2.branchId = A.branchId
              AND DATE(A2.scheduledDate) = DATE(A.scheduledDate)
              AND HOUR(A2.scheduledDate) = HOUR(A.scheduledDate)
              AND A2.status <> 'CANCELLED'
        ) AS FL_SOVRA_ALLOCAZIONE, -- WARN: RT originale restituisce un conteggio numerico su un campo dichiarato VARCHAR(1); mismatch di tipo, l'alias interno della RT era 'NM_APPUNTAMENTI_SLOT'
        CASE
            WHEN (
                SELECT COUNT(*)
                FROM 4314_Appointment A2
                WHERE A2.branchId = A.branchId
                  AND DATE(A2.scheduledDate) = DATE(A.scheduledDate)
                  AND HOUR(A2.scheduledDate) = HOUR(A.scheduledDate)
                  AND A2.status <> 'CANCELLED'
            ) > COALESCE(
                (
                    SELECT RO.resourceCount
                    FROM 4321_cfg_ResourceAvailabilityOverride RO
                    WHERE RO.branchId = A.branchId
                      AND RO.DATE = DATE(A.scheduledDate)
                      AND TIME(A.scheduledDate) >= RO.timeSlotStart AND TIME(A.scheduledDate) < RO.timeSlotEnd
                ),
                (
                    SELECT R.resourceCount
                    FROM 4320_cfg_ResourceAvailability R
                    WHERE R.branchId = A.branchId
                      AND R.dayOfWeek = DAYOFWEEK(A.scheduledDate)
                      AND TIME(A.scheduledDate) >= R.timeSlotStart AND TIME(A.scheduledDate) < R.timeSlotEnd
                ),
                0
            ) THEN 'S'
            ELSE 'N'
        END AS FL_GIORNO_FESTIVO, -- WARN: l'alias interno della RT originale era 'FL_SOVRA_ALLOCAZIONE'; qui rinominato al campo dichiarato
        A.appointmentTypeId AS APPOINTMENT_TYPE_ID_TEC,
        A.appointmentOutcomeId AS APPOINTMENT_OUTCOME_ID_TEC
    FROM {{ ref('4314_appointment') }} A -- WARN: nome tabella non conforme alla naming convention Agos (altre entita' L1 usano nomi tipo CCANAGR); verificare se esiste gia' un source/ref dbt per il sistema di booking, o se va referenziato con source() invece di ref()
    LEFT JOIN {{ ref('4318_cfg_nonworkingday') }} NWD
        ON DATE(A.scheduledDate) = NWD.DATE
       OR (NWD.recurrence = 1 AND MONTH(A.scheduledDate) = MONTH(NWD.DATE) AND DAY(A.scheduledDate) = DAY(NWD.DATE))
    LEFT JOIN {{ ref('4319_cfg_nonworkingdayoverride') }} NWDO
        ON DATE(A.scheduledDate) = NWDO.DATE
       AND A.branchId = NWDO.branchId

)

, dedup AS (

    SELECT
        CD_APPUNTAMENTO,
        PR_APPUNTAMENTO,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_CLIENTE,
        CD_PRATICA,
        TP_PROCEDURA,
        CD_FILIALE,
        TS_PRESA_APPUNTAMENTO,
        TS_APPUNTAMENTO,
        TS_APPUNTAMENTO_EFFETTIVO,
        NM_DURATA_APPUNTAMENTO,
        CD_SLOT_APPUNTAMENTO,
        CD_TIPO_APPUNTAMENTO,
        CD_STATO_APPUNTAMENTO,
        DS_STATO_APPUNTAMENTO,
        CD_UTENTE_APPUNTAMENTO,
        FL_POSTICIPO,
        FL_FUNNEL,
        NM_RISORSE_DISPONIBILI_SLOT,
        NM_APPUNTAMENTI_SLOT,
        FL_SOVRA_ALLOCAZIONE,
        FL_GIORNO_FESTIVO,
        APPOINTMENT_TYPE_ID_TEC,
        APPOINTMENT_OUTCOME_ID_TEC,
        {{ hash_cols([
            'CD_APPUNTAMENTO', 'PR_APPUNTAMENTO', 'CD_CLIENTE', 'CD_PRATICA', 'TP_PROCEDURA',
            'CD_FILIALE', 'TS_PRESA_APPUNTAMENTO', 'TS_APPUNTAMENTO', 'TS_APPUNTAMENTO_EFFETTIVO',
            'NM_DURATA_APPUNTAMENTO', 'CD_SLOT_APPUNTAMENTO', 'CD_TIPO_APPUNTAMENTO', 'CD_STATO_APPUNTAMENTO',
            'DS_STATO_APPUNTAMENTO', 'CD_UTENTE_APPUNTAMENTO', 'FL_POSTICIPO', 'FL_FUNNEL',
            'NM_RISORSE_DISPONIBILI_SLOT', 'NM_APPUNTAMENTI_SLOT', 'FL_SOVRA_ALLOCAZIONE', 'FL_GIORNO_FESTIVO',
            'APPOINTMENT_TYPE_ID_TEC', 'APPOINTMENT_OUTCOME_ID_TEC'
        ]) }} AS HASHED_COLS
    FROM base
    {{ is_incremental_S1('CD_APPUNTAMENTO') }}

)

SELECT
    H.CD_APPUNTAMENTO,
    H.PR_APPUNTAMENTO,
    H.TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('H.CD_APPUNTAMENTO', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
    H.CD_CLIENTE,
    H.CD_PRATICA,
    H.TP_PROCEDURA,
    H.CD_FILIALE,
    H.TS_PRESA_APPUNTAMENTO,
    H.TS_APPUNTAMENTO,
    H.TS_APPUNTAMENTO_EFFETTIVO,
    H.NM_DURATA_APPUNTAMENTO,
    H.CD_SLOT_APPUNTAMENTO,
    H.CD_TIPO_APPUNTAMENTO,
    AT.reason AS DS_MOTIVO_APPUNTAMENTO,
    AT.description AS TP_MODALITA_PRESA_APPUNTAMENTO,
    SC.sourceChannel AS CD_MODALITA_CONTATTO,
    SC.description AS DS_MODALITA_CONTATTO,
    H.CD_UTENTE_APPUNTAMENTO,
    H.CD_STATO_APPUNTAMENTO,
    H.DS_STATO_APPUNTAMENTO,
    OC.code AS CD_ESITO_APPUNTAMENTO,
    OC.description AS DS_ESITO_APPUNTAMENTO,
    CASE WHEN OC.noShow = 1 THEN 'S' ELSE 'N' END AS FL_NOSHOW,
    H.FL_POSTICIPO,
    H.FL_FUNNEL,
    CASE WHEN SC.sourceChannel = 'CALL_CENTER' THEN 'S' ELSE 'N' END AS FL_CALL_CENTER,
    H.NM_RISORSE_DISPONIBILI_SLOT,
    H.NM_APPUNTAMENTI_SLOT,
    H.FL_SOVRA_ALLOCAZIONE,
    H.FL_GIORNO_FESTIVO
FROM dedup H
LEFT JOIN {{ ref('4316_cfg_appointmenttype') }} AT
    ON H.APPOINTMENT_TYPE_ID_TEC = AT.id
LEFT JOIN {{ ref('4322_cfg_sourcechannelappointmenttype') }} SC
    ON H.APPOINTMENT_TYPE_ID_TEC = SC.appointmentTypeId
LEFT JOIN {{ ref('4315_cfg_appointmentoutcome') }} OC
    ON H.APPOINTMENT_OUTCOME_ID_TEC = OC.id
-- WARN: LASTMODIFIEDDATA (campo tecnico sempre richiesto per regola assoluta) non e' presente nel data model per questa entita'; omesso, da chiarire con chi ha compilato lo sheet
