# Log

## [2026-07-15] lint
Lint completo della wiki: nessun orfano, nessuna contraddizione tra pagine, nessuna staleness rilevata vs `raw/dwh-code/` (spot-check su l2-carte, l2-provvigioni-rappel, cancellazioni-fl-deleted, macro citate), nessuna incongruenza skill-vs-codice (develop-l2/develop-l3/dm-reader coerenti col codice vendorizzato). Tutte le 11 voci di [[inconsistenze]] confermate ancora valide (nessuna risolta). Individuati 2 concetti ricorrenti senza pagina propria: creata [[query-tag-monitoring]] (estratta da storicizzazione-l2-s1-s4, linkata da l2-carte/l2-provvigioni-rappel) e [[lastmodifieddata]] (consolidata da caricamento-layer-l2/macro-catalogo-dbt/cancellazioni-fl-deleted). Discusso e adottato il pattern di tracking incongruenze: pagina unica `queries/inconsistenze.md` (rinominata da `inconsistenze-doc-vs-codice.md`) con tabella riassuntiva a 3 colonne Codice/Skill/Doc in cima e dettaglio narrativo sotto (12 voci, inclusa la verifica skill-vs-codice); voci non cancellate ma marcate risolte con data quando superate. Aggiornati tutti i wikilink nella wiki al nuovo nome pagina.

## [2026-07-15] develop | pulizia develop/ dopo sync raw/dwh-code
Utente ha risincronizzato `raw/dwh-code/` dalla repo live. Verificati gli 11 file presenti in `develop/`: 9 risultavano identici alla versione ora in `raw/dwh-code/` (portati upstream), i restanti 2 (`cnt_campagna.sql`, `variazioni_anagrafiche.sql`) avevano fix diverse/più complete rispetto a quanto proposto in `develop/`. Confermato dall'utente: eliminati tutti gli 11 file e le directory vuote sotto `develop/`.

## [2026-07-14] ingest | Caricamento layer L0-L1
Ingerito `raw/Agos X - Caricamento layer L0-L1.docx`. Creata pagina sources/caricamento-layer-l0-l1.md e concetti collegati (storicizzazione L1, cancellazioni, naming, cobol-parsing).

## [2026-07-14] ingest | Caricamento layer L2
Ingerito `raw/Agos X - Caricamento layer L2.docx`. Creata pagina sources/caricamento-layer-l2.md e concetti collegati (storicizzazione L2 S1-S4, progressivo, data masking, naming).

## [2026-07-14] ingest | Guida Sviluppo
Ingerito `raw/guida_sviluppo.docx`. Creata pagina sources/guida-sviluppo.md, incluso pattern S5 (scd2_foto_mensile) e variante S1 senza PK propria.

## [2026-07-14] ingest | Agos X - Layer L2.xlsx (reference, non ingest completo)
Su decisione utente, la xlsx (~180 fogli) non è stata ingerita foglio per foglio: creata sources/layer-l2-xlsx-reference.md che ne descrive la struttura (nomenclature, Catalogo Entità, Catalogo Categorie Campi) da consultare puntualmente in query future.

## [2026-07-14] lint | Cross-check documentazione vs codice raw/dwh-code
Lanciati 3 agenti di ricerca in parallelo su raw/dwh-code/ (macros; models/L2; models/L0-L1/snapshots/templates/tests). Scritte 13 pagine entities/ (repo + 4 layer + 12 aree L2), 8 pagine concepts/ (macro-catalogo-dbt, storicizzazione L1/L2/L3, cancellazioni, naming-convention, progressivo, data-masking, cobol-parsing). Filata queries/inconsistenze-doc-vs-codice.md con 11 inconsistenze verificate (query_tag mancante/errato, doppio meccanismo cancellazioni, FL_ values S/N vs Y/N, prefissi campo divergenti, dbt_artifacts non presente, nomi test custom diversi, macro remove_datamask/decode_overpunch non trovate come documentate, doppia implementazione S1, sentinelle DATE/TIMESTAMP miste, bug minori nel codice).
