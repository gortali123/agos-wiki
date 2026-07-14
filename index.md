# Index

## Entities

- [Repo dwh-x-dbt](entities/repo-dwh-x-dbt.md) — progetto DBT unico, struttura reale vendorizzata
- [Layer L0](entities/layer-l0.md)
- [Layer L1](entities/layer-l1.md)
- [Layer L2](entities/layer-l2.md)
- [Layer L3](entities/layer-l3.md)
- [L2 ANAGR_CONTROPARTE](entities/l2-anagr-controparte.md) — area più documentata, VARIAZIONI_ANAGRAFICHE
- [L2 ANTIFRODE](entities/l2-antifrode.md)
- [L2 ASSICURAZIONI](entities/l2-assicurazioni.md)
- [L2 CARTE](entities/l2-carte.md) — query_tag schema mismatch sistematico
- [L2 GESTIONE_CREDITI](entities/l2-gestione-crediti.md)
- [L2 ONBOARDING](entities/l2-onboarding.md) — wfl_istanza usa is_incremental_S1
- [L2 PRODOTTO](entities/l2-prodotto.md)
- [L2 PRODOTTO_M](entities/l2-prodotto-m.md)
- [L2 PROVVIGIONI_RAPPEL](entities/l2-provvigioni-rappel.md) — query_tag disattivato/errato
- [L2 RISCHI_ADEMPIMENTI](entities/l2-rischi-adempimenti.md)
- [L2 SALDI](entities/l2-saldi.md)
- [L2 SWORD](entities/l2-sword.md) — unico a leggere da XML

## Concepts

- [Catalogo macro DBT](concepts/macro-catalogo-dbt.md) — inventario completo macro raw/dwh-code/macros
- [Storicizzazione L1: cluster A/B/C](concepts/storicizzazione-l1-cluster-a-b-c.md)
- [Storicizzazione L2: pattern S1-S4](concepts/storicizzazione-l2-s1-s4.md)
- [Storicizzazione L3: S2-S4 e S5](concepts/storicizzazione-l3.md)
- [Cancellazioni logiche e FL_DELETED](concepts/cancellazioni-fl-deleted.md)
- [Naming convention Agos X](concepts/naming-convention-agos-x.md) — schemi/tabelle/campi, divergenze tra fonti
- [PROGRESSIVO_PK e PROGRESSIVO_CONTROPARTE](concepts/progressivo-pk-e-progressivo-controparte.md)
- [Data masking Agos X](concepts/data-masking-agos-x.md)
- [Parsing COBOL](concepts/cobol-parsing.md)

## Sources

- [Caricamento layer L0-L1](sources/caricamento-layer-l0-l1.md)
- [Caricamento layer L2](sources/caricamento-layer-l2.md)
- [Guida Sviluppo](sources/guida-sviluppo.md)
- [Agos X - Layer L2.xlsx (reference)](sources/layer-l2-xlsx-reference.md) — non ingerito foglio per foglio, solo struttura

## Queries

- [Inconsistenze tra documentazione e codice](queries/inconsistenze-doc-vs-codice.md) — 11 inconsistenze verificate, ordinate per impatto

## Develop

(nessuna voce ancora)
