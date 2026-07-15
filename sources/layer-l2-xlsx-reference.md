---
title: "Agos X - Layer L2.xlsx (reference)"
type: source
tags: [layer/L2, reference, data-model]
updated: 2026-07-14
---

`raw/Agos X - Layer L2.xlsx` è il **data model / analisi tecnica L2** di Agos: non è stato ingerito foglio per foglio (troppo ampio — oltre 180 fogli), viene tenuto come **reference** per lookup mirati su una tabella/entità specifica. Questa pagina descrive cosa contiene e come consultarlo.

## Struttura del file

Fogli trasversali (nomenclatura e cataloghi, letti integralmente per costruire [[naming-convention-agos-x]] e questa pagina):

- **Nomenclatura Campi**: convenzione prefissi campo. `CD` Codice (NUMBER/VARCHAR), `DS` Descrizione (VARCHAR), `TP` Tipo (VARCHAR), `DT` Data (DATE), `TS` Data e Orario (TIMESTAMP), `EU` Importo in euro (NUMBER, 2 decimali), `FL` Indicatore Flag (VARCHAR, **rigorosamente "S" o "N"**), `NM` Quantità numerica (NUMBER), `PC` Percentuale (NUMBER), `PR` Progressivo (NUMBER), `GN_` Generico/VARIANT ("non dovrebbe servire in L2 ma solo su L1"). **Nota**: non compaiono `ID_` né `SK_`, che invece sono documentati nei due file docx come prefissi validi — vedi [[naming-convention-agos-x]].
- **Nomenclatura Frequenza Tabelle**: suffissi `_W`/`_M`/`_T`/`_Q`/`_S`/`_Y`/`_O`, nessun suffisso = giornaliera. Coerente con quanto in [[caricamento-layer-l2]].
- **Nomenclatura SubjectArea Tabell**: 29 subject area con codice a 3+3 lettere (es. `ANA_CNT` = Anagrafica Controparte, `PRD_CRT` = Carte, `ADP_SLD` = Saldi, `SDE_ANT` = Antifrode) e schema Snowflake risultante (es. `L2_ANA_CNT`). **Nota**: questi codici (es. `ANA_CNT`, `PRD_CRT`) non corrispondono 1:1 ai nomi di area funzionale citati nei docx (es. `ANAGR_CONTROPARTE`, `PRODOTTO`) né alle cartelle presenti in `raw/dwh-code/models/L2` (es. `ANAGR_CONTROPARTE`, `CARTE`) — sembrano due tassonomie diverse (sigle a 3+3 lettere vs. nomi estesi); da chiarire con il team se sono equivalenti o superate. Vedi [[inconsistenze]].
- **Catalogo Entità**: la tabella più densa e utile — una riga per entità L2/L3 con: Macro Area, Subject Area, ID_ENTITA, TP_ENTITA, descrizione, perimetro funzionale, sorgenti L1 in join, dipendenze da altre entità/aree, **regola tecnica di perimetro** (SQL/pseudo-SQL), **storicizzazione entità finale e cluster degli archivi sorgente** (es. `VARIAZIONI_ANAGRAFICHE`: sorgente main `CCANALOG` cluster **A1**, storicizzazione **S1**). Questo foglio è la fonte primaria per validare cluster/storicizzazione dei modelli reali — citato esplicitamente anche nella checklist pre-rilascio di [[guida-sviluppo]] ("Cluster tabelle sorgenti coerente con analisi tecnica — sheet catalogo_entita in data model L2").
- **Catalogo Categorie Campi**: raggruppamento dei campi di ogni entità in categorie semantiche (es. per `CONTROPARTE`: Identificativo, Tempo, Dati anagrafici personali/non personali, Dati Residenza, Dati Domicilio, Contatti, Dati Impiego). Utile per capire il perimetro informativo atteso di un'entità prima di leggerne il modello SQL.
- **DataQualityInterna**: non ancora letto in dettaglio (251 righe) — da consultare puntualmente in caso di query su regole di data quality specifiche.

Poi ci sono ~170 fogli, uno per tabella/entità (es. `ANAGRAFICA_CONTROPARTE`, `VARIAZIONI_ANAGRAFICHE`, `PRATICA`, `CARTA`, `SALDO_M`, ...), col tracciato campo-per-campo (nome, tipo, descrizione, categoria). Molti fogli sono marcati `_OLD` (versioni superate), `WIP`, o "non leggere" (appunti personali di membri del team, es. "appunti Lucia - non leggere", "Foglio Tommi -non leggere") — **da NON considerare come fonte affidabile**.

## Come usarlo

Per una query su un'entità specifica (es. "che campi ha ANAGRAFICA_CONTROPARTE secondo l'analisi tecnica"), aprire il file e consultare il foglio con quel nome esatto — non è stato ingerito nel wiki, quindi il contenuto puntuale dei singoli fogli non è ricercabile qui, solo la struttura generale documentata in questa pagina.

## Collegamenti

- [[naming-convention-agos-x]]
- [[caricamento-layer-l2]]
- [[guida-sviluppo]]
- [[inconsistenze]]
