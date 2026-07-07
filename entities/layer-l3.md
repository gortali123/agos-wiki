---
title: Layer L3
type: entity
tags: [layer/L3]
updated: 2026-07-07
---

Layer organizzato per **processo** (schema `L3_<processo>`), a valle di L2. Il documento ufficiale L2/L3 tratta L3 solo marginalmente (naming, alberatura condivisa con L2); il dettaglio implementativo delle storicizzazioni L3 è documentato quasi esclusivamente nella [[guida-sviluppo]].

## Storicizzazione

Previste S2 (append giornaliero), S3 (append mensile) e S4 (insert_overwrite), analoghe a L2 ma con blocco incrementale che dipende dal tipo di storicizzazione della tabella main L2 (S3 → filtro su `DT_OSSERVAZIONE`; S1 → filtro su intervallo `TS_INIZIO_VALIDITA`/`TS_FINE_VALIDITA`).

In aggiunta, la guida sviluppo introduce **S5 — "SCD2 mensile"**, confermata come implementazione reale e stabile (esiste come macro `scd2_foto_mensile` in [[dwh-code]]) ma non ancora presente nel documento di framework L2/L3 — da aggiungere, vedi [[todo-allineamento-documentazione]]. Storicizzazione a granularità mensile basata sulla "foto di fine mese" di ogni chiave, con confronto hash del payload per evitare la proliferazione di versioni ridondanti. Vedi [[storicizzazione-l3-s5]] per il dettaglio completo (macro, parametri, esempio numerico).

Nel testo della guida sviluppo compaiono anche dei punti esplicitamente aperti ("S1 non previsto?" per L3), non ancora risolti.

## Naming convention

Tabelle: `L3: <tipo_oggetto>_<nome_tabella>_<frequenza>` (vedi [[naming-conventions]] per i codici frequenza e tipo oggetto, condivisi con L2).

## Collegato da
[[agosx-caricamento-l2]], [[guida-sviluppo]], [[layer-l2]], [[storicizzazione-l3-s5]]
