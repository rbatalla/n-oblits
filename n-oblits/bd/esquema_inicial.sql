-- =====================================================================
-- N-Oblits — Esquema inicial (SQLite)
-- SCHEMA_VERSION = 0 · v0.1 · 2026-09-24
-- Un sol esquema per a l'escriptori (SQLite) i el mòbil (SQLite WASM, proposta).
-- Convencions (CONTEXT §2.1, §2.5, §5):
--   * id TEXT = UUID generat al dispositiu (fa de client_id; importacions idempotents).
--   * Columnes de sincronització a totes les taules sincronitzables:
--       creat_el, modificat_el (ISO 8601 UTC), modificat_a ('mobil'|'escriptori'),
--       esborrat (0/1, esborrat lògic; es purga després de sincronitzar).
--   * Dates de calendari: TEXT 'YYYY-MM-DD'. Imports: REAL a la moneda original.
--   * Imports en € i estats (dies, saldo, compensacions) NO es desen: es deriven (vistes).
--   * Llavors (seeds) de diccionaris amb id determinista ('cat-dinar'…) perquè
--     mòbil i escriptori no generin duplicats.
-- =====================================================================
PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- 1. Diccionaris
-- ---------------------------------------------------------------------
CREATE TABLE moneda (
  codi        TEXT PRIMARY KEY CHECK (length(codi) = 3),   -- ISO 4217: EUR, JPY…
  nom         TEXT NOT NULL,
  simbol      TEXT NOT NULL,
  decimals    INTEGER NOT NULL DEFAULT 2 CHECK (decimals BETWEEN 0 AND 3)
);

CREATE TABLE prioritat (                                     -- escala fixa i ordenada
  codi        TEXT PRIMARY KEY,
  nom         TEXT NOT NULL,
  ordre       INTEGER NOT NULL UNIQUE
);

CREATE TABLE pais (
  id TEXT PRIMARY KEY, nom TEXT NOT NULL, nom_normalitzat TEXT NOT NULL,
  moneda_codi TEXT REFERENCES moneda(codi) ON DELETE SET NULL,
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1))
);

CREATE TABLE categoria (
  id TEXT PRIMARY KEY, nom TEXT NOT NULL, nom_normalitzat TEXT NOT NULL,
  icona TEXT, ordre INTEGER NOT NULL DEFAULT 0, actiu INTEGER NOT NULL DEFAULT 1 CHECK (actiu IN (0,1)),
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1))
);

CREATE TABLE ubicacio (
  id TEXT PRIMARY KEY, nom TEXT NOT NULL, nom_normalitzat TEXT NOT NULL,
  icona TEXT, ordre INTEGER NOT NULL DEFAULT 0, actiu INTEGER NOT NULL DEFAULT 1 CHECK (actiu IN (0,1)),
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1))
);

CREATE TABLE persona (                                       -- global: es reutilitza entre viatges
  id TEXT PRIMARY KEY, nom TEXT NOT NULL, nom_normalitzat TEXT NOT NULL,
  es_propietaria INTEGER NOT NULL DEFAULT 0 CHECK (es_propietaria IN (0,1)),
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1))
);
-- Només una persona propietària (persona de referència de l'app)
CREATE UNIQUE INDEX ux_persona_propietaria ON persona(es_propietaria) WHERE es_propietaria = 1 AND esborrat = 0;

-- ---------------------------------------------------------------------
-- 2. Plantilles i conjunts (globals)
-- ---------------------------------------------------------------------
CREATE TABLE targeta_plantilla (
  id TEXT PRIMARY KEY, nom TEXT NOT NULL, nom_normalitzat TEXT NOT NULL,
  ubicacio_id TEXT REFERENCES ubicacio(id) ON DELETE SET NULL,
  prioritat_codi TEXT NOT NULL DEFAULT 'important' REFERENCES prioritat(codi),
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1))
);

CREATE TABLE plantilla (
  id TEXT PRIMARY KEY, nom TEXT NOT NULL, nom_normalitzat TEXT NOT NULL,
  tipus TEXT NOT NULL CHECK (tipus IN ('plantilla','conjunt')),
  descripcio TEXT,
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1))
);

-- Contingut: cada fila és una targeta O una subplantilla (mai totes dues).
-- Una 'plantilla' només conté targetes; un 'conjunt' conté plantilles, conjunts i targetes.
-- El control de cicles es fa a l'app amb la consulta recursiva de MODEL_DADES.md §6
-- (SQLite no admet CTE dins de triggers).
CREATE TABLE plantilla_item (
  id TEXT PRIMARY KEY,
  plantilla_id    TEXT NOT NULL REFERENCES plantilla(id) ON DELETE CASCADE,
  targeta_id      TEXT REFERENCES targeta_plantilla(id) ON DELETE CASCADE,
  subplantilla_id TEXT REFERENCES plantilla(id) ON DELETE CASCADE,
  ordre INTEGER NOT NULL DEFAULT 0,
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1)),
  CHECK ((targeta_id IS NULL) <> (subplantilla_id IS NULL)),
  CHECK (subplantilla_id IS NULL OR subplantilla_id <> plantilla_id)
);
CREATE INDEX ix_plantilla_item_plantilla ON plantilla_item(plantilla_id);
CREATE INDEX ix_plantilla_item_targeta ON plantilla_item(targeta_id);
CREATE INDEX ix_plantilla_item_sub ON plantilla_item(subplantilla_id);

-- ---------------------------------------------------------------------
-- 3. Viatge, persones i grups
-- ---------------------------------------------------------------------
CREATE TABLE viatge (
  id TEXT PRIMARY KEY, nom TEXT NOT NULL,
  data_inici TEXT NOT NULL, data_fi TEXT NOT NULL,
  -- Monedes: EUR sempre + com a màxim 1 moneda local (màx. 2 per viatge, F1.3)
  moneda_local_codi TEXT REFERENCES moneda(codi),
  canvi_moneda_local REAL,                                   -- 1 € = X moneda local; fix per viatge (F1.4)
  temps_esperat TEXT CHECK (temps_esperat IN ('sol','nuvol','pluja','neu','variable')),
  temp_min REAL, temp_max REAL,
  repartiment_defecte TEXT NOT NULL DEFAULT 'persona' CHECK (repartiment_defecte IN ('persona','grup')),
  limit_diari_eur REAL,                                      -- desnormalitzat per al pressupost (proposta)
  objectius_bloquejats INTEGER NOT NULL DEFAULT 0 CHECK (objectius_bloquejats IN (0,1)),
  tancat INTEGER NOT NULL DEFAULT 0 CHECK (tancat IN (0,1)),
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1)),
  CHECK (data_fi >= data_inici),
  CHECK (moneda_local_codi IS NULL OR moneda_local_codi <> 'EUR'),
  CHECK ((moneda_local_codi IS NULL) = (canvi_moneda_local IS NULL)),
  CHECK (canvi_moneda_local IS NULL OR canvi_moneda_local > 0)
);

CREATE TABLE viatge_pais (
  viatge_id TEXT NOT NULL REFERENCES viatge(id) ON DELETE CASCADE,
  pais_id   TEXT NOT NULL REFERENCES pais(id) ON DELETE RESTRICT,
  ordre INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (viatge_id, pais_id)
);

CREATE TABLE grup (                                          -- grup familiar d'1..N persones, per viatge
  id TEXT PRIMARY KEY,
  viatge_id TEXT NOT NULL REFERENCES viatge(id) ON DELETE CASCADE,
  nom TEXT NOT NULL, ordre INTEGER NOT NULL DEFAULT 0,
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1))
);
CREATE INDEX ix_grup_viatge ON grup(viatge_id);

CREATE TABLE viatge_persona (                                -- pertinença: una persona, un grup per viatge
  id TEXT PRIMARY KEY,
  viatge_id  TEXT NOT NULL REFERENCES viatge(id) ON DELETE CASCADE,
  persona_id TEXT NOT NULL REFERENCES persona(id) ON DELETE RESTRICT,
  grup_id    TEXT NOT NULL REFERENCES grup(id) ON DELETE RESTRICT,
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1)),
  UNIQUE (viatge_id, persona_id)
);
CREATE INDEX ix_viatge_persona_grup ON viatge_persona(grup_id);
CREATE INDEX ix_viatge_persona_persona ON viatge_persona(persona_id);

CREATE TABLE temps_dia (                                     -- F3.2: tres franges per dia
  viatge_id TEXT NOT NULL REFERENCES viatge(id) ON DELETE CASCADE,
  data  TEXT NOT NULL,
  franja TEXT NOT NULL CHECK (franja IN ('mati','migdia','tarda')),
  temps TEXT NOT NULL CHECK (temps IN ('sol','nuvol','pluja','neu','variable')),
  modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  PRIMARY KEY (viatge_id, data, franja)
);

-- ---------------------------------------------------------------------
-- 4. Llistes i llista de control
-- ---------------------------------------------------------------------
CREATE TABLE llista (
  id TEXT PRIMARY KEY,
  viatge_id TEXT NOT NULL REFERENCES viatge(id) ON DELETE CASCADE,
  tipus TEXT NOT NULL CHECK (tipus IN ('control','despeses','objectius')),
  nom TEXT NOT NULL, ordre INTEGER NOT NULL DEFAULT 0,
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1))
);
CREATE INDEX ix_llista_viatge ON llista(viatge_id);

CREATE TABLE element_control (
  id TEXT PRIMARY KEY,
  llista_id TEXT NOT NULL REFERENCES llista(id) ON DELETE CASCADE,
  nom TEXT NOT NULL, nom_normalitzat TEXT NOT NULL,
  ubicacio_id TEXT REFERENCES ubicacio(id) ON DELETE SET NULL,
  prioritat_codi TEXT NOT NULL REFERENCES prioritat(codi),
  estat TEXT NOT NULL DEFAULT 'pendent' CHECK (estat IN ('ok','pendent','no_cal')),
  ordre INTEGER NOT NULL DEFAULT 0,                          -- ordre dins el bloc de prioritat
  targeta_origen_id TEXT REFERENCES targeta_plantilla(id) ON DELETE SET NULL,
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1))
);
CREATE INDEX ix_element_llista ON element_control(llista_id);
-- Idempotència (F5.7, F6.4): la mateixa targeta de plantilla només una vegada per llista
CREATE UNIQUE INDEX ux_element_targeta ON element_control(llista_id, targeta_origen_id) WHERE targeta_origen_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- 5. Metàl·lic (fons del grup de referència)
-- ---------------------------------------------------------------------
CREATE TABLE moviment_metallic (
  id TEXT PRIMARY KEY,
  viatge_id TEXT NOT NULL REFERENCES viatge(id) ON DELETE CASCADE,
  data TEXT NOT NULL, data_hora_real TEXT NOT NULL,
  tipus TEXT NOT NULL CHECK (tipus IN ('inicial','caixer','canvi','altres')),
  import REAL NOT NULL,                                      -- negatiu permès per a 'canvi' (moneda que surt)
  moneda_codi TEXT NOT NULL REFERENCES moneda(codi),
  persona_id TEXT REFERENCES persona(id) ON DELETE SET NULL, -- ha de ser del grup de referència (validació a l'app)
  nota TEXT,
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1))
);
CREATE INDEX ix_moviment_viatge ON moviment_metallic(viatge_id);

-- ---------------------------------------------------------------------
-- 6. Despeses i repartiment
-- ---------------------------------------------------------------------
CREATE TABLE despesa (
  id TEXT PRIMARY KEY,
  viatge_id TEXT NOT NULL REFERENCES viatge(id) ON DELETE CASCADE,
  llista_id TEXT REFERENCES llista(id) ON DELETE SET NULL,
  data TEXT NOT NULL,                                        -- dia imputat (per defecte, avui)
  data_hora_real TEXT NOT NULL,                              -- moment real de l'esdeveniment (CONTEXT §2.2)
  concepte TEXT NOT NULL,
  categoria_id TEXT REFERENCES categoria(id) ON DELETE RESTRICT,
  moneda_codi TEXT NOT NULL REFERENCES moneda(codi),
  preu_persona REAL,                                         -- F7.4 (opcional)
  n_persones INTEGER CHECK (n_persones IS NULL OR n_persones > 0),
  import_total REAL NOT NULL CHECK (import_total >= 0),      -- = preu_persona × n_persones si n'hi ha
  pagador_persona_id TEXT NOT NULL REFERENCES persona(id) ON DELETE RESTRICT,
  mitja TEXT NOT NULL CHECK (mitja IN ('metallic','targeta')),
  imputacio TEXT NOT NULL CHECK (imputacio IN ('general','grup','personal')),
  grup_imputat_id TEXT REFERENCES grup(id) ON DELETE RESTRICT,
  repartiment TEXT CHECK (repartiment IN ('persona','grup','adhoc')),
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1)),
  CHECK ((imputacio = 'grup') = (grup_imputat_id IS NOT NULL)),
  CHECK ((imputacio = 'general') = (repartiment IS NOT NULL)),
  CHECK ((preu_persona IS NULL) = (n_persones IS NULL))
);
CREATE INDEX ix_despesa_viatge_data ON despesa(viatge_id, data);
CREATE INDEX ix_despesa_categoria ON despesa(categoria_id);
CREATE INDEX ix_despesa_pagador ON despesa(pagador_persona_id);
CREATE INDEX ix_despesa_grup ON despesa(grup_imputat_id);

-- Repartiment ad hoc (F7.10): parts per grup O per persona; la suma = import_total (validació a l'app)
CREATE TABLE despesa_part (
  id TEXT PRIMARY KEY,
  despesa_id TEXT NOT NULL REFERENCES despesa(id) ON DELETE CASCADE,
  grup_id    TEXT REFERENCES grup(id) ON DELETE RESTRICT,
  persona_id TEXT REFERENCES persona(id) ON DELETE RESTRICT,
  import REAL NOT NULL CHECK (import >= 0),                  -- en la moneda de la despesa
  nota TEXT,
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1)),
  CHECK ((grup_id IS NULL) <> (persona_id IS NULL))
);
CREATE INDEX ix_part_despesa ON despesa_part(despesa_id);

-- ---------------------------------------------------------------------
-- 7. Objectius
-- ---------------------------------------------------------------------
CREATE TABLE objectiu (
  id TEXT PRIMARY KEY,
  llista_id TEXT NOT NULL REFERENCES llista(id) ON DELETE CASCADE,
  tipus TEXT NOT NULL CHECK (tipus IN ('veure','limit_diari','limit_categoria')),
  nom TEXT NOT NULL,
  fet INTEGER NOT NULL DEFAULT 0 CHECK (fet IN (0,1)),       -- només per a 'veure'
  limit_eur REAL CHECK (limit_eur IS NULL OR limit_eur > 0),
  categoria_id TEXT REFERENCES categoria(id) ON DELETE RESTRICT,
  ordre INTEGER NOT NULL DEFAULT 0,
  creat_el TEXT NOT NULL, modificat_el TEXT NOT NULL,
  modificat_a TEXT NOT NULL CHECK (modificat_a IN ('mobil','escriptori')),
  esborrat INTEGER NOT NULL DEFAULT 0 CHECK (esborrat IN (0,1)),
  CHECK ((tipus = 'veure') = (limit_eur IS NULL)),
  CHECK ((tipus = 'limit_categoria') = (categoria_id IS NOT NULL))
);
CREATE INDEX ix_objectiu_llista ON objectiu(llista_id);

-- ---------------------------------------------------------------------
-- 8. Sistema: configuració, auditoria, sincronització, versions
-- ---------------------------------------------------------------------
CREATE TABLE configuracio (clau TEXT PRIMARY KEY, valor TEXT);

CREATE TABLE registre_canvi (                                -- CONTEXT §5
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  taula TEXT NOT NULL, registre_id TEXT NOT NULL, camp TEXT,
  valor_anterior TEXT, valor_nou TEXT,
  data_esdeveniment TEXT NOT NULL,                           -- data real, no la d'importació
  dispositiu TEXT NOT NULL CHECK (dispositiu IN ('mobil','escriptori'))
);
CREATE INDEX ix_registre_taula ON registre_canvi(taula, registre_id);

CREATE TABLE sync_estat (                                    -- p. ex. darrera_pujada, darrera_baixada
  clau TEXT PRIMARY KEY, valor TEXT NOT NULL
);

CREATE TABLE versio (
  codi TEXT PRIMARY KEY,                                     -- 'v0.1'
  estat TEXT NOT NULL CHECK (estat IN ('curs','fet','previst')),
  schema_version INTEGER NOT NULL,
  data_tancament TEXT
);
CREATE TABLE versio_canvi (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  versio_codi TEXT NOT NULL REFERENCES versio(codi) ON DELETE CASCADE,
  categoria TEXT NOT NULL CHECK (categoria IN ('NOU','MILLORA','ARQ','BD','BUG','IA')),
  descripcio TEXT NOT NULL,
  fet INTEGER NOT NULL DEFAULT 0 CHECK (fet IN (0,1))
);

-- ---------------------------------------------------------------------
-- 9. Vistes derivades (mateix càlcul a mòbil i escriptori)
-- ---------------------------------------------------------------------
-- Grup de referència = grup del viatge on és la persona propietària
CREATE VIEW v_grup_referencia AS
SELECT vp.viatge_id, vp.grup_id
FROM viatge_persona vp JOIN persona p ON p.id = vp.persona_id
WHERE p.es_propietaria = 1 AND p.esborrat = 0 AND vp.esborrat = 0;

-- Despesa amb import en € (canvi fix del viatge) i grup del pagador
CREATE VIEW v_despesa AS
SELECT d.*,
       CASE WHEN d.moneda_codi = 'EUR' THEN d.import_total
            ELSE d.import_total / v.canvi_moneda_local END AS import_eur,
       CASE WHEN d.moneda_codi = 'EUR' THEN 1.0
            ELSE 1.0 / v.canvi_moneda_local END AS factor_eur,
       vp.grup_id AS grup_pagador_id,
       CASE WHEN vp.grup_id = gr.grup_id THEN 1 ELSE 0 END AS pagador_es_referencia
FROM despesa d
JOIN viatge v ON v.id = d.viatge_id
LEFT JOIN viatge_persona vp ON vp.viatge_id = d.viatge_id AND vp.persona_id = d.pagador_persona_id AND vp.esborrat = 0
LEFT JOIN v_grup_referencia gr ON gr.viatge_id = d.viatge_id
WHERE d.esborrat = 0;

-- Saldo de metàl·lic per moneda (F8.5): moviments − pagaments en metàl·lic del grup de referència
CREATE VIEW v_saldo_metallic AS
SELECT viatge_id, moneda_codi, SUM(import) AS saldo FROM (
  SELECT viatge_id, moneda_codi, import FROM moviment_metallic WHERE esborrat = 0
  UNION ALL
  SELECT viatge_id, moneda_codi, -import_total FROM v_despesa
  WHERE mitja = 'metallic' AND pagador_es_referencia = 1
) GROUP BY viatge_id, moneda_codi;

-- Quota de cada grup en cada despesa computable (F9): en €
CREATE VIEW v_quota_grup AS
WITH np AS (SELECT viatge_id, COUNT(*) AS n FROM viatge_persona WHERE esborrat = 0 GROUP BY viatge_id),
     ng AS (SELECT viatge_id, COUNT(*) AS n FROM grup WHERE esborrat = 0 GROUP BY viatge_id),
     npg AS (SELECT grup_id, COUNT(*) AS n FROM viatge_persona WHERE esborrat = 0 GROUP BY grup_id)
-- general · per persona
SELECT d.id AS despesa_id, d.viatge_id, g.id AS grup_id, d.import_eur * npg.n / np.n AS quota_eur
FROM v_despesa d JOIN grup g ON g.viatge_id = d.viatge_id AND g.esborrat = 0
JOIN npg ON npg.grup_id = g.id JOIN np ON np.viatge_id = d.viatge_id
WHERE d.imputacio = 'general' AND d.repartiment = 'persona'
UNION ALL
-- general · per grup
SELECT d.id, d.viatge_id, g.id, d.import_eur / ng.n
FROM v_despesa d JOIN grup g ON g.viatge_id = d.viatge_id AND g.esborrat = 0
JOIN ng ON ng.viatge_id = d.viatge_id
WHERE d.imputacio = 'general' AND d.repartiment = 'grup'
UNION ALL
-- general · ad hoc (parts per grup o per persona → grup de la persona)
SELECT d.id, d.viatge_id, COALESCE(p.grup_id, vp.grup_id), p.import * d.factor_eur
FROM v_despesa d JOIN despesa_part p ON p.despesa_id = d.id AND p.esborrat = 0
LEFT JOIN viatge_persona vp ON vp.viatge_id = d.viatge_id AND vp.persona_id = p.persona_id AND vp.esborrat = 0
WHERE d.imputacio = 'general' AND d.repartiment = 'adhoc'
UNION ALL
-- grup familiar
SELECT d.id, d.viatge_id, d.grup_imputat_id, d.import_eur
FROM v_despesa d WHERE d.imputacio = 'grup';

-- Compensació per grup (F9.1): pagat, li correspon i saldo (+ a rebre / − a pagar)
CREATE VIEW v_compensacio AS
SELECT g.viatge_id, g.id AS grup_id, g.nom,
       COALESCE((SELECT SUM(import_eur) FROM v_despesa d
                 WHERE d.viatge_id = g.viatge_id AND d.grup_pagador_id = g.id
                   AND d.imputacio <> 'personal'), 0) AS pagat_eur,
       COALESCE((SELECT SUM(quota_eur) FROM v_quota_grup q WHERE q.grup_id = g.id), 0) AS correspon_eur
FROM grup g WHERE g.esborrat = 0;

-- Despesa per dia (F10.4, F11.1) — inclou les personals (F11.4)
CREATE VIEW v_despesa_dia AS
SELECT viatge_id, data, SUM(import_eur) AS total_eur FROM v_despesa GROUP BY viatge_id, data;

-- ---------------------------------------------------------------------
-- 10. Llavors
-- ---------------------------------------------------------------------
INSERT INTO moneda (codi, nom, simbol, decimals) VALUES
  ('EUR','Euro','€',2), ('JPY','Ien japonès','¥',0), ('USD','Dòlar EUA','$',2), ('GBP','Lliura esterlina','£',2);

INSERT INTO prioritat (codi, nom, ordre) VALUES
  ('imprescindible','Imprescindible',1), ('important','Important',2),
  ('valorable','Valorable',3), ('si_es_pot','Si es pot',4);

INSERT INTO categoria (id, nom, nom_normalitzat, icona, ordre, creat_el, modificat_el, modificat_a) VALUES
  ('cat-dinar','Dinar','dinar','food',1,'2026-09-24T00:00:00Z','2026-09-24T00:00:00Z','escriptori'),
  ('cat-sopar','Sopar','sopar','moon',2,'2026-09-24T00:00:00Z','2026-09-24T00:00:00Z','escriptori'),
  ('cat-compra','Compra','compra','cart',3,'2026-09-24T00:00:00Z','2026-09-24T00:00:00Z','escriptori'),
  ('cat-excursio','Excursió','excursio','mount',4,'2026-09-24T00:00:00Z','2026-09-24T00:00:00Z','escriptori');

INSERT INTO ubicacio (id, nom, nom_normalitzat, icona, ordre, creat_el, modificat_el, modificat_a) VALUES
  ('ubi-maleta','Maleta','maleta','suitcase',1,'2026-09-24T00:00:00Z','2026-09-24T00:00:00Z','escriptori'),
  ('ubi-bossa-ma','Bossa de mà','bossa de ma','bag',2,'2026-09-24T00:00:00Z','2026-09-24T00:00:00Z','escriptori');

INSERT INTO versio (codi, estat, schema_version) VALUES ('v0.1','curs',0);
INSERT INTO configuracio (clau, valor) VALUES ('schema_version','0');
