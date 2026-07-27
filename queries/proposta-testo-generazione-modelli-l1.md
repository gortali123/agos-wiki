---
title: "Proposta testo unificato: L1 - Generazione dei modelli DBT (autoconclusiva, assorbe guida sviluppo 4.1)"
type: query
tags: [layer/L1, source/docx, codegen, ocs]
updated: 2026-07-28
---

Proposta di riscrittura del capitolo "L1: Generazione dei modelli DBT" in `raw/Agos X - Caricamento layer L0-L1.docx`. Obiettivi, su richiesta dell'utente:

1. Completare il paragrafo troncato a "Nel dettaglio..." (vedi versione precedente di questa pagina).
2. Integrare la parte operativa (CLI, `--force`, esempio) della sezione **4.1 Generazione Modelli** di `raw/guida_sviluppo.docx`, così che il capitolo sia autoconclusivo e la 4.1 possa essere rimossa da lì. La tabella CLI **non elenca** l'opzione per generare tutti i modelli senza filtri: comando troppo rischioso da mettere in evidenza in un documento di riferimento.

Per il capitolo (separato) sulla gestione dei job dbt Cloud, vedi [[proposta-testo-job-l1]].

**Aggiornamento 2026-07-28**: dopo il resync di `raw/dwh-code/` da parte dell'utente, le macro joinano anche una seconda tabella di configurazione, `TECH.CFG_L0_L1_MODULO_LOOKUP`, per gli archivi OCS — non solo `TECH.CFG_L1_SCHEMA`/`TECH.CFG_L1_CLUSTER_STO` come descritto finora. Il testo proposto sotto è stato aggiornato di conseguenza (era la proposta `develop/` del 2026-07-24, ora applicata upstream — vedi nota in fondo alla pagina).

`raw/` è immutabile: questa pagina è la proposta da incollare a mano nei due `.docx`, non un'edit dei file stessi.

## Testo proposto — sostituisce l'intero capitolo "L1: Generazione dei modelli DBT"

> Per la generazione dei modelli L1 in DBT vengono eseguite in maniera estemporanea quattro macro per ogni archivio: `generate_source`, `generate_yaml`, `generate_model`, `generate_snapshots`. Le macro leggono dai metadati della tabella di configurazione `TECH.CFG_L1_SCHEMA`, dalla tabella `TECH.CFG_L1_CLUSTER_STO` (cluster di storicizzazione) e — per i soli archivi OCS — dalla tabella `TECH.CFG_L0_L1_MODULO_LOOKUP`, che associa ogni modulo "grezzo" (`cd_modulo`, es. `ANA`, `XAN`) al proprio modulo aggregato/soprafolder (`cd_modulo_l1`, es. `ANA` per entrambi). Generano:
>
> - **generate_source**: file di source `<nome_tabella>_source.yml` (`models/L0/`) — specifica la tabella L0 e i test di nullability, casting e unicità della chiave da effettuare sulle colonne prima del caricamento in L1.
> - **generate_yaml**: file di configurazione `<nome_tabella>.yml` (`models/L1/`) — colonne, tipi dato, constraint, materializzazione/strategia per cluster, query_tag, masking.
> - **generate_model**: file di modello `<nome_tabella>.sql` (`models/L1/`) — lettura dalla tabella L0 e casting delle colonne. Per cluster C genera anche il modello di staging `stg_<nome_tabella>.sql`.
> - **generate_snapshots**: file di configurazione snapshot `<nome_tabella>.yml` (`snapshots/L1/`), solo per cluster C.
>
> È definita inoltre una macro di transcodifica dtype (`transcod_dtype`), che mappa il tipo dato dichiarato in `TECH.CFG_L1_SCHEMA` verso il tipo Snowflake corrispondente (es. `VARCHAR`/`NUMBER` con lunghezza, `TIMESTAMP_NTZ`, ...), usata da `generate_model` e `generate_yaml`. Per un tipo non mappato restituisce il valore sentinella `TRANSCOD_ERROR`, visibile direttamente nel file generato.
>
> Gli script potranno quindi essere usati sia nel caso dell'aggiunta di un nuovo archivio (OCS o non OCS) sia nel caso di un'evolutiva del tracciato di un archivio già esistente (OCS o non OCS). Nel dettaglio:
>
> - **Nuovo archivio**: i file non esistono ancora, lo script li genera direttamente.
> - **Evolutiva**: i file esistono già (es. dopo una modifica a `TECH.CFG_L1_SCHEMA`) — lo script segnala un warning e non li sovrascrive; per rigenerarli va passata l'opzione `--force`.
> - **Archivi OCS**: output in `models/L1/OCS/<cd_modulo_l1>/<cd_modulo>` — due livelli di sottocartella, soprafolder aggregato e sottofolder specifico (es. `OCS/ANA/ANA`, `OCS/ANA/XAN`). La logica di questo raggruppamento per modulo OCS è la stessa già descritta più sopra, nel capitolo L0 di questo documento, a proposito della struttura dei moduli/archivi nel bucket S3 — quella sezione andrà aggiornata di conseguenza, non ancora fatto in questa proposta.
> - **Archivi non OCS**: output in `models/L1/<SORGENTE>`, senza sottocartella per modulo.
>
> Le macro sono richiamate dallo script PowerShell `generate_models.ps1`:
>
> | Caso d'uso | Comando |
> |---|---|
> | Lista specifica di modelli | `./generate_models.ps1 --models "model1,model2,model3"` |
> | Tutti i modelli di un modulo OCS | `./generate_models.ps1 --modulo "ana"` |
> | Tutti i modelli di una sorgente | `./generate_models.ps1 --sorgente "SAP"` |
> | Solo parti specifiche | `./generate_models.ps1 --models "m1" --only yaml,models` |
> | Forzare sovrascrittura | aggiungere `--force` |
>
> Esempio di esecuzione (PowerShell), archivi del modulo `ANA`:
> ```
> ./generate_models.ps1 -Models "ATIFFGCR","CCBANCHE"
> ```
> output (assumendo `ATIFFGCR` sul modulo grezzo `ANA` e `CCBANCHE` sul modulo grezzo `XAN`, entrambi aggregati sotto `cd_modulo_l1 = ANA`):
> ```
> models/L1/OCS/ANA/ANA/ATIFFGCR.yml
> models/L1/OCS/ANA/ANA/ATIFFGCR.sql
> models/L0/OCS/ANA/ANA/ATIFFGCR_source.yml
> models/L1/OCS/ANA/XAN/CCBANCHE.yml
> models/L1/OCS/ANA/XAN/CCBANCHE.sql
> models/L0/OCS/ANA/XAN/CCBANCHE_source.yml
> ```
> I file generati sono poi versionati nel progetto DBT, garantendo tracciabilità e coerenza.

## Nota per chi porta la modifica nei due docx

- Dopo aver incollato questo testo in `caricamento_l0_l1.docx`, la sola sezione **4.1 Generazione Modelli** di `guida_sviluppo.docx` diventa ridondante e può essere rimossa (o ridotta a un rimando). **4.2 Gestione Job dbt Cloud non va toccata** — vedi [[proposta-testo-job-l1]] per il capitolo breve proposto su questo tema.
- Se si rimuove il contenuto 4.1 da `guida_sviluppo.docx`, aggiornare `sources/guida-sviluppo.md` (sezione "Layer L1 — generazione modelli e job") togliendo la parte di generazione modelli e lasciando solo quella job, con rimando a [[caricamento-layer-l0-l1]].

## Basi di questa proposta

- Testo esistente di `raw/Agos X - Caricamento layer L0-L1.docx` (paragrafo sulle 4 macro, esempio PowerShell, "Nel dettaglio..." troncato).
- `raw/guida_sviluppo.docx`, sezione 4.1 (tabella CLI, `--force`).
- `raw/dwh-code/macros/generate_models/transcod_dtype.sql` — mappatura tipi e sentinella `TRANSCOD_ERROR`, vedi [[macro-catalogo-dbt]].
- `raw/dwh-code/generate_models.ps1` — skip-on-exists salvo `-Force`, struttura cartelle OCS vs non-OCS.
- `raw/dwh-code/macros/generate_models/generate_source.sql`, `generate_yaml.sql` — verificati dopo il resync 2026-07-28: join a `TECH.CFG_L0_L1_MODULO_LOOKUP` (`mlk.cd_modulo = s.cd_modulo`, solo per `ds_sorgente = 'OCS'`) e struttura a due livelli `OCS/<cd_modulo_l1>/<cd_modulo>`, byte-identici alla proposta `develop/` del 2026-07-24 — **ora applicati upstream**, quindi rimossi da questa proposta come "non incluso".
- **Ancora aperto, fuori perimetro di questa proposta**: il capitolo L0 di `caricamento_l0_l1.docx` descrive già la struttura ad archivi/moduli OCS nel bucket S3, ma non nei termini di `cd_modulo`/`cd_modulo_l1` introdotti qui — quella sezione andrà rivista per restare coerente con questo capitolo, in una proposta separata.

## Collegamenti

- [[caricamento-layer-l0-l1]]
- [[guida-sviluppo]]
- [[macro-catalogo-dbt]]
- [[proposta-testo-log-l1]]
- [[proposta-testo-test-l1-ocs]]
- [[proposta-testo-job-l1]]
