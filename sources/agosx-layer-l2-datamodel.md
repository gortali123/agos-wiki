---
title: Agos X - Layer L2.xlsx (data model)
type: source
tags: [layer/L2, layer/L3, source/datamodel]
updated: 2026-07-08
---

Foglio di calcolo Excel (`raw/Agos X - Layer L2.xlsx`) che costituisce il **data model dettagliato di L2/L3**: è il documento a cui la [[guida-sviluppo]] rimanda nella checklist pre-rilascio L2 (§5.4, "Cluster tabelle sorgenti coerente con analisi tecnica — sheet catalogo_entita in data model L2"). Non è un documento di framework né una guida operativa: è il **tracciato dati vivo**, aggiornato dal team di analisi, con granularità a livello di singolo campo per singola entità.

Analizzata solo la struttura in questa sessione (2026-07-08), non il contenuto campo-per-campo delle ~140 entità (troppo per un ingest completo — vedi Note sotto).

## Struttura del file

Circa 230 fogli, divisi in tre categorie:

### 1. Fogli di riferimento/glossario (metadata del modello)

- **`Nomenclatura Campi`** — glossario dei prefissi campo (CD, DS, TP, DT, TS, EU, FL, NM, PC, PR, GN_) con definizione estesa e note d'uso. Sovrappone ma arricchisce [[naming-conventions]] (es. spiega che `GN_` per Variant "non dovrebbe servire in L2 ma solo su L1", che `PR_` come progressivo è preferibile solo se non in PK, altrimenti si preferisce `CD_`).
- **`Nomenclatura Frequenza Tabelle`** — suffissi di frequenza tabella.
- **`Nomenclatura SubjectArea Tabell[e]`** — elenco codici Subject Area con esempio di schema risultante (es. `ANA_CNT` → `L2_ANA_CNT.CONTROPARTE`). **Importante**: questa tassonomia usa codici (`ANA_CNT`, `ANA_COM`, `HR`, `CNT_VOC`, `CNT`, `DGT_ARI`, `DGT_FRP`, `DGT_TRC`, `GNS_PRV`, `GNS_RCV`, `PRD_CQS`, `PRD_PGM`, `PRD_ASS`, `PRD_CNS`, ...) diversi sia dall'elenco "area funzionale" del documento ufficiale L2 (`ANAGR_CONTROPARTE`, `ANTIFRODE`, ...) sia dai nomi cartella in `dbt_project.yml` (`ANAGR_CONTROPARTE`, `CARTE`, `SALDI`, `SWORD`, ...). **Terza tassonomia di naming per le aree L2**, non ancora riconciliata con le altre due — vedi nota in fondo.
- **`Catalogo Entità`** (149 righe, una per entità L2/L3) — il catalogo master. Colonne principali: `Nome Entità`, `Macro Area`, `Subject Area`, `ID_ENTITA`, `TP_ENTITA` (L2 o LT = layer tecnico/lookup), `DESCRIZIONE BREVE`, `DEFINIZIONE FUNZIONALE PERIMETRO`, `SORGENTI L1/L2 in JOIN`, `ENTITA DI INTERESSE IFRS9`, **`Regola Tecnica Perimetro (Nome tabella/e Main)`**, **`Regola Tecnica Perimetro (filtri/join)`** — contiene SQL vero e proprio (es. `SELECT * FROM PLPRAT UNION ALL SELECT * FROM CRCAR UNION ALL SELECT * FROM QSPRA`), `DIPENDENZA DA ALTRE ENTITA L2` (+ quali), `DIPENDENZA DA ALTRE AREE`, `STORICIZZAZIONE ENTITA FINALE E ARCHIVI SORGENTI` (es. `S4`, con elenco sorgenti L1 e relativo cluster: `[L1]PLPRAT -> B2`), `PROFONDITA STORICA`.
- **`Catalogo Categorie Campi`** (367 righe) — tassonomia delle categorie di campo per entità (es. per `PRATICA`: "Tempo", "Controparte", "Configurazione prodotto", "Attributo", "Stato pratica", "Società Veicolo"), usata per raggruppare i campi nei fogli di dettaglio entità (colonna `CATEGORIA CAMPO`).
- **`DataQualityInterna`** — foglio di supporto Excel (pieno di `#N/A`, con un menu a tendina per cambiare entità in cella A2) — probabile helper/dashboard di validazione interna, non un catalogo di dati statico.

### 2. Un foglio per entità (~140+)

Uno per ogni tabella L2/L3 (es. `ANAGRAFICA_CONTROPARTE`, `CARTA`, `CARTA_M`, `CONSUMO`, `PRATICA`, `VARIAZIONI_ANAGRAFICHE`...), con **un record per campo della tabella**. Colonne tipiche (con lievi variazioni tra entità):

| Colonna | Significato |
|---|---|
| `CATEGORIA CAMPO` | Raggruppamento semantico (da `Catalogo Categorie Campi`) |
| `NOME CAMPO` | Nome colonna Snowflake (naming convention `<prefisso>_<nome>`) |
| `DESCRIZIONE` | Descrizione funzionale del campo |
| `FLAG_PK` | `Y`/`N` — appartenenza alla PK dell'entità |
| `FORMATO`, `LENGTH`, `DECIMAL` | Data type e dimensioni |
| `MODULO`/`SORGENTE TABELLA OCS L1`, `SORGENTE CAMPI OCS L1` | Tracciabilità verso L1 (tabella e campo sorgente) |
| `STATO (CAMPO VALIDATO / IN VALIDAZIONE)` | Stato di validazione del campo, spesso per processo/richiesta (es. "Validato per IFRS9", "In validazione per Comitato") |
| `REGOLA FUNZIONALE` | Descrizione testuale della logica applicata |
| `CAMPO CALCOLATO` | `S`/`N` — se il valore deriva da calcolo anziché da mappatura diretta |
| `CAMPO DA SORGENTE NON MAIN` | `S`/`N` — se il campo viene da una tabella diversa dalla Main dell'entità |
| `REGOLA TECNICA` | SQL/logica tecnica effettiva (popolata solo se calcolato o da sorgente non-main) |
| `CHIAVI DI AGGANCIO` | Condizione di join verso la sorgente non-main |
| `DATI SENSIBILI` | `S`/`N`/`NA` — flag privacy (collegato concettualmente a [[data-masking]], ma qui è un flag dichiarativo nel data model, non l'implementazione tecnica del masking) |
| `AGGIUNTO PER ARRICCHIMENTO` | `S`/`N` — se il campo non viene dalla tabella main ma aggiunge valore |
| `NOTE` | Libere |

Questo è il livello di dettaglio più fine su come ogni singolo campo L2 viene costruito — più granulare di qualunque documento di framework o della guida sviluppo, che restano a livello di pattern/strategia generale.

## Uso pratico

- **Sviluppo modelli L2**: uno sviluppatore consulta il foglio dell'entità per sapere esattamente da dove viene ogni campo, se è calcolato, e con quale join — input diretto per scrivere il modello DBT.
- **Checklist pre-rilascio** ([[guida-sviluppo]] §5.4): si verifica che tracciato/ordine colonne e cluster di storicizzazione del modello sviluppato corrispondano a quanto scritto qui.
- **`Catalogo Entità`** funge da mappa delle dipendenze tra entità/aree, utile per capire l'ordine di sviluppo o l'impatto di una modifica.

## Rumore da ignorare

- Fogli con suffisso `_OLD` o prefisso `WIP`/`(WIP)` — versioni superate o non finalizzate.
- Note personali non destinate alla lettura: `appunti Lucia - non leggere`, `Foglio Tommi -non leggere`, `Appunti Tom Non Leggere`.
- 3-4 fogli (`VARIAZIONI_ANAGRAFICHE`, `VARIAZIONI_ANAGRAFICHE_DAY`, `CONTROPARTE_PRE_AT`, `CONTROPARTE_OLD`) hanno un range "usato" anomalo (~16.000+ colonne) — quasi certamente formattazione Excel accidentale estesa a colonne vuote, non dati reali. Da ignorare se si esporta programmaticamente il foglio (rischio di generare CSV enormi e vuoti).

## Incoerenza aperta (non risolta in questa sessione)

Il foglio `Nomenclatura SubjectArea Tabell[e]` definisce una **terza tassonomia di codici area** per L2, diversa sia dall'elenco "area funzionale" del documento ufficiale ([[naming-conventions]]) sia dai nomi cartella reali in `dbt_project.yml` ([[incoerenze-codice-vs-documentazione]] punto 4). Tre fonti, tre schemi di naming per lo stesso concetto — da chiarire con l'utente quale sia quello corrente/da seguire, o se rappresentano fasi diverse di un rename in corso.

## Collegato da
[[naming-conventions]], [[guida-sviluppo]], [[layer-l2]], [[layer-l3]], [[incoerenze-codice-vs-documentazione]]
