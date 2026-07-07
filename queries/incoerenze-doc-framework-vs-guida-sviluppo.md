---
title: Incoerenze tra documenti di framework e guida sviluppo
type: query
tags: [lint, incoerenze]
updated: 2026-07-07
---

Analisi comparativa dei tre documenti ingeriti in questa sessione ([[agosx-caricamento-l0-l1]], [[agosx-caricamento-l2]], [[guida-sviluppo]]), rispetto al principio dichiarato dall'utente: i documenti di framework contengono le cose importanti/ufficiali, la guida sviluppo aggiunge solo dettaglio per sviluppatori senza ripetere (salvo l'essenziale).

## 1. Orchestrazione: Control-M vs dbt Cloud (rilevanza alta)

I documenti ufficiali dicono che **Control-M** orchestra l'intera pipeline (Glue + tutti i comandi `dbt build`). La guida sviluppo descrive invece un flusso operativo basato su **dbt Cloud** (setup CLI, `.env` con credenziali dbt Cloud, `generate_jobs.ps1` → `jobs.yml` → `dbt-jobs-as-code sync`). Nessun documento spiega come questi due meccanismi coesistano. Dettaglio in [[orchestrazione-control-m-vs-dbt-cloud]].

## 2. Comando dbt L1 vs L2 (rilevanza media)

- L1: `dbt build -s +<model_name>` (il `+` include i test sulle source), confermato obbligatorio dalla guida sviluppo ("snapshot e test non vengono eseguiti dal solo dbt run").
- L2: `dbt build -s <nome_modello>` — **senza** `+` in entrambi gli esempi del documento ufficiale L2.

Se il `+` serve a eseguire i test sulle source, la sua assenza nel comando L2 implicherebbe che i test sorgente per L2 non vengano eseguiti allo stesso modo — da verificare se è intenzionale (L2 ha un meccanismo di controllo diverso, basato su `VW_L1_TEST_RESULTS`) o un'omissione nel documento.

## 3. Nome tabella di monitoraggio (rilevanza media)

Il documento L0-L1 la chiama `TECH.CFG_PROCESS_MONITORING`; la guida sviluppo la chiama `TECH.CFG_L0_L1_PROCESS_MONITORING`. Stessa funzione descritta (stato/ultimo run per archivio), nome diverso. Vedi [[cfg-process-monitoring]].

## 4. Query tag L2: chiave accentata vs non accentata (rilevanza media — rischio tecnico concreto)

- Documento ufficiale L2: esempio con chiave **`"entità"`** (con accento).
- Stesso documento, esempio Glue L0 per confronto: chiavi tutte senza accenti (`sorgente`, `schema`, `modulo`).
- Guida sviluppo: esempio con chiave **`"entita"`** (senza accento).

Una chiave JSON con carattere accentato è un rischio concreto se qualche processo di parsing/monitoring fa match testuale sulla chiave — vale la pena chiarire quale sia la chiave "vera" da usare in produzione, dato che i due documenti non concordano.

## 5. Sotto-cluster "A1/A2" non definiti (rilevanza media)

La guida sviluppo cita "Cluster A1/A2" nella sezione data quality L1 e nel pre-hook `delete_l2`, ma il documento ufficiale L0-L1 definisce solo Cluster A (unico), B, C. Non è chiaro se A1/A2 siano una sotto-classificazione reale già presente in [[cfg-l1-cluster-sto]] o un refuso per "Cluster A". Vedi [[storicizzazione-l1-cluster]].

## 6. Storicizzazione S5 (L3) non presente nel framework (rilevanza media)

La guida sviluppo introduce e documenta in grande dettaglio (macro, esempio numerico) una storicizzazione **S5 "SCD2 mensile"** per L3, mai menzionata nel documento ufficiale L2/L3 (che per L3 parla solo di S2/S3/S4 "analoghe a L2"). Se S5 è una scelta implementativa reale e stabile, andrebbe idealmente anche nel documento di framework condiviso col cliente, non solo nella guida interna — altrimenti resta "invisibile" a chi guarda solo la documentazione ufficiale. Vedi [[storicizzazione-l3-s5]].

## 7. Sezione "Raccolta log" L1 marcata obsoleta, ma quasi identica alla sezione L2 non marcata tale (rilevanza bassa-media)

Nel documento L0-L1, la sezione sulla raccolta log per L1 è preceduta da: *"Obsoleto, da aggiornare sulla base della discussione con Snowflake (questione concorrenza)"*, e include un hook aggiuntivo (`pop_test_log_records(results)`) assente nella sezione equivalente del documento L2 (non marcata obsoleta). Rischio: chi legge solo il documento L2 potrebbe assumere che il meccanismo descritto sia quello corrente anche per L1, quando invece per L1 è dichiarato da rivedere.

## 8. Duplicazione di contenuto framework nella guida sviluppo (rilevanza bassa, ma è esattamente il criterio che l'utente ha chiesto di sorvegliare)

La guida sviluppo §5.1 e §5.3 **ripete** in forma tabellare quasi tutto il contenuto di storicizzazione L2 (S1-S4: strategia, unique key, campi tecnici) già presente nel documento ufficiale L2, invece di limitarsi ad aggiungere solo il dettaglio implementativo (frammenti SQL/YML). Non è un errore di contenuto, ma va contro il principio dichiarato ("guida sviluppo non ripete le cose, a meno di cose essenziali"): qui la tabella riepilogativa è probabilmente utile come "cheat sheet", ma sarebbe da valutare se linkare/citare piuttosto che duplicare.

## 9. Refusi minori

- `FL_DELETE` vs `FL_DELETED` nel documento L2 (§ cancellazioni) — quasi certo refuso, il campo è sempre `FL_DELETED` altrove.
- `TS_INSERIMENTO` (tabella colonne) vs `DT_INSERIMENTO` (testo esplicativo) per lo stesso campo tecnico in [[cfg-l1-schema]], nel documento L0-L1.
- Placeholder non risolti nel documento ufficiale L0-L1: periodo di retention file "xxx giorni", rimando a "capitolo xxx" per la forzatura del caricamento L1 dopo retry L0.
- Punti aperti esplicitamente lasciati come domande nel testo della guida sviluppo (sezione L3): "S1 non previsto?", scelta della colonna per il blocco incrementale S3 quando manca `DT_OSSERVAZIONE`, gestione di funzioni di conversione chiave più complesse in `delete_l2`.

## Risoluzione (confermata dall'utente il 2026-07-07)

| # | Verdetto | Nota |
|---|---|---|
| 1 | **Reale, da documentare** | Control-M orchestra l'esecuzione; la creazione/gestione dei job dbt (jobs-as-code, sync verso dbt Cloud) è responsabilità del team ed è un meccanismo distinto e complementare, non alternativo. Manca solo nel documento di framework. |
| 2 | **Non è un'incoerenza** | I test sulle source si eseguono solo in L1 (da cui il `+`), non in L2 — il comando L2 senza `+` è corretto per design. |
| 3 | **Refuso nel doc ufficiale** | Il nome vero è `TECH.CFG_L0_L1_PROCESS_MONITORING` (versione guida sviluppo). Il documento L0-L1 va corretto. |
| 4 | **Refuso nel doc ufficiale** | La chiave vera è `"entita"` (senza accento), come in guida sviluppo. Il documento L2 va corretto. |
| 5 | **Reale, da documentare** | I sotto-cluster A1/A2 esistono davvero — vanno definiti e aggiunti al documento di framework (oggi solo citati, mai spiegati, nemmeno in guida sviluppo). |
| 6 | **Reale, da documentare** | S5 (SCD2 mensile, L3) è implementazione reale e stabile — va portata nel documento di framework, non lasciata solo in guida sviluppo. |
| 7 | **Confermato obsoleto** | Le sezioni "Raccolta log" di entrambi i documenti ufficiali sono da riscrivere: il meccanismo reale non è dbt Artifacts (vedi [[incoerenze-codice-vs-documentazione]] — stored procedure custom `TECH.LOG_DBT`). |
| 8 | **Nessuna azione** | La duplicazione in guida sviluppo §5.1/5.3 va bene così (cheat-sheet utile). |
| 9 (refusi) | **Confermato** | `FL_DELETED` e `TS_INSERIMENTO` sono i nomi corretti; il documento L2 (`FL_DELETE`) e la nota esplicativa del documento L0-L1 (`DT_INSERIMENTO`) vanno corretti. I placeholder "xxx giorni"/"capitolo xxx" e i punti aperti in guida sviluppo restano da risolvere (non trattati in questa sessione). |

Vedi [[todo-allineamento-documentazione]] per le liste di azioni concrete derivate da questa tabella.

## Collegato da
[[agosx-caricamento-l0-l1]], [[agosx-caricamento-l2]], [[guida-sviluppo]], [[orchestrazione-control-m-vs-dbt-cloud]], [[todo-allineamento-documentazione]]
