# [NOM APP] — Context del projecte

> **Última actualització:** [DATA] — v0.1 en curs.
> Migracions aplicades: **cap** · `SCHEMA_VERSION=0`.
> Aquest document és l'**única font de context** del projecte. S'ha de pujar a cada sessió, juntament amb `MODEL_DADES.md` (quan existeixi).
> **Origen:** plantilla derivada de les regles generalitzables del `CONTEXT.md` de LEXAI (sessió 2026-09-13). S'hi han descartat les regles específiques de llibres, de PyQt5 i de macOS Catalina.

**Convenció d'aquest document:**
- `[A DEFINIR]` vol dir que la decisió encara no està presa.
- `(condicional: PWA)` marca una regla que només és vàlida si l'app es construeix com a PWA.
- `(proposta)` marca l'aplicació suggerida d'un patró general a aquest domini, pendent de validar.

---

## Índex

0. Com treballem
   - Procés de tancament de versió
1. Què és l'app
2. Restriccions tècniques (CRÍTIC)
3. Criteris de disseny
4. Regles de negoci
5. Base de dades
6. Mapa de fitxers
7. Historial de versions
8. Roadmap i backlog

---

## 0. Com treballem

### A l'inici de cada sessió
1. Confirmar que es disposa d'aquest `CONTEXT.md`. Si falta, demanar-lo.
2. Revisar el §8 (backlog) i proposar per on començar si l'usuari no ho indica.
3. **No demanar noms de fitxers:** consultar el §6.

### Principis permanents
- **Idioma:** tota la feina, la comunicació i els resultats (documents, UI i codi) són en **català**, per defecte i de moment.
- **Primer els bugs, després les funcionalitats**, dins la versió activa.
- **Mai** es modifica la base de dades directament: tot canvi d'esquema o de dades va per **migració numerada**.
- **Lliurament:** només els fitxers canviats, **sencers** i verificats sintàcticament abans de lliurar.
- **Fitxers sencers:** demanar sempre fitxers concrets complets (nom segons el §6), mai funcions soltes.
- **Fitxer original sense canvis:** si el fitxer pujat és l'original i no la sortida de la sessió, cal reaplicar tots els canvis pendents abans de lliurar.
- **Categories:** els `[BUG]` van a la versió activa; els `[NOU]`, `[MILLORA]`, `[ARQ]`, `[BD]` i `[IA]` van al roadmap o al backlog.
- **Símbols de llista (uniformes a tot el document):** `✅` = fet (dins una versió tancada) · `☐` = pendent. No s'hi fa servir cap altre símbol; la prioritat o el tipus s'indiquen en text entre parèntesis.
- **Gestor de tasques extern:** [A DEFINIR] (eina i llistes sobre les quals s'actua).
- **Comunicació:** respostes concises i executives que diguin què s'ha fet, què cal verificar i què falta, sense explicacions llargues.
- **Dubtes:** ser concís no vol dir no preguntar; els dubtes es plantegen sempre.

### Procés de tancament de versió
1. **`CONTEXT.md`:** actualitzar la capçalera, el §7 i el §8.
2. **Migració de tancament:** registrar la versió i els seus canvis a la BD, actualitzar el roadmap i incrementar `SCHEMA_VERSION`.
3. **Esquema inicial:** reflectir-hi l'esquema consolidat. S'ha de fer a partir d'un bolcat real de l'esquema, no reconstruint-lo a mà.
4. **Roadmap a la BD:** la versió tancada passa a `'fet'` i la nova a `'curs'`.
5. **Verificació:** la versió que mostra l'app ha de coincidir amb la versió `'fet'` més recent del roadmap i amb la versió actual de la BD. *(A LEXAI, un tancament documentat però no migrat va fer que l'app continués mostrant la versió anterior.)*
6. **Còpia de seguretat** de la BD abans d'aplicar la migració.

---

## 1. Què és l'app

Aplicació **mòbil** per controlar un viatge, organitzada en tres mòduls:
1. **Checklist previ:** activitats o tasques que cal verificar abans de viatjar.
2. **Despeses del viatge:** previstes i reals.
3. **Objectius del viatge:** fites definides per al viatge i el seu grau de compliment.

- **Usuari(s):** [A DEFINIR]
- **Idioma de la UI i del codi:** **català** (per defecte, de moment)
- **Stack / plataforma (PWA, nativa o híbrida):** [A DEFINIR]
- **Persistència local i sincronització:** [A DEFINIR]
- **Repositori / desplegament:** [A DEFINIR]

---

## 2. Restriccions tècniques (CRÍTIC)

### 2.1 Dades i persistència
- **Classificar i filtrar per ID, no per text.** Les funcions de minúscules o de comparació de text no sempre gestionen bé els accents.
- **Tipar explícitament els resultats agregats.** Per exemple, `MAX()` sobre una columna de text retorna un string.
- **SQLite (si s'utilitza):**
  - Les claus foranes estan desactivades per defecte (`PRAGMA foreign_keys`) i s'han d'activar.
  - No existeix `ALTER COLUMN`: per canviar una columna cal recrear la taula.
- **Estats derivats (p. ex. "fet"):** s'han de calcular amb `EXISTS`, no amb un `JOIN` directe. El `JOIN` duplica files quan hi ha diversos registres relacionats.
- **En vincular una entitat filla al seu pare, cal sincronitzar sempre els camps relacionats.** S'ha de sobreescriure el valor previ en lloc de suposar que ja era correcte.

### 2.2 Dates i càlculs
- **Provar els càlculs d'"inici de setmana o període" quan la data ja cau en el dia objectiu.** A LEXAI, una fórmula amb aquest cas límit va doblar la finestra fins a 14 dies.
- **Les estimacions basades en una data introduïda a mà són fràgils.** Un error humà en aquella data dispara la projecció: a LEXAI es va arribar a estimar una data de fi l'any 2073.
  - Si hi ha menys de 2 registres propis, cal usar una **mitjana històrica o de grup** que no depengui de dates manuals.
  - El resultat s'ha de **marcar com a estimació** (p. ex. `*` en gris, amb una nota explicativa).
- **Registrar la data i hora reals de l'esdeveniment**, no les del moment d'importació o sincronització. A LEXAI, un esdeveniment que travessava mitjanit es va comptar en dos dies diferents.

### 2.3 Estat de la interfície
- **No confiar en els esdeveniments de canvi per aplicar l'estat inicial.** Si el valor inicial coincideix amb el valor per defecte, l'esdeveniment no es dispara. Cal cridar el handler manualment un cop connectat.
- **Controls que disparen l'esdeveniment de canvi en assignar-los un valor per codi:** cal bloquejar l'esdeveniment durant l'assignació.
- **No reconstruir la vista dins el mateix esdeveniment que l'origina**, ni obrir dos modals seguits de manera síncrona. Cal diferir l'execució al cicle següent.
- **No posicionar diàlegs manualment en mostrar-se**, perquè la geometria pot no estar consolidada encara. Cal usar el centrat natiu.
- **Els desplegables de catàleg recarreguen les dades en obrir-se** i preserven la selecció actual.

### 2.4 Mòbil / PWA (condicional: PWA)
- **El Service Worker només ha de cachejar l'"shell"** de l'app. **Mai** les peticions de dades o de l'API de sincronització: si ho fa, "actualitzar" serveix sempre la primera versió baixada.
- **Versionar els recursos** (`app.js?v=X`, `styles.css?v=X`) per evitar còpies antigues a la memòria cau HTTP.
- **Wake Lock** mentre hi hagi un procés actiu amb temporitzador. Cal tornar-lo a demanar en tornar a l'app si el sistema l'ha revocat.
- **Àudio:** desbloquejar l'`AudioContext` amb un gest de l'usuari abans de necessitar-lo.
- **L'edició en línia no ha de fer perdre el focus del teclat.** No s'ha de re-renderitzar l'input que s'està editant.

### 2.5 Sincronització (si n'hi ha)
- **Una cua de sincronització per tipus d'entitat**, independents entre si. Un tipus de dada no ha de generar registres falsos en un altre.
- **Deduplicació per `client_id`** generat al dispositiu, de manera que les importacions siguin **idempotents**.
- **Buidar la cua remota després d'importar-la.** Si no es pot buidar, la deduplicació evita duplicats.
- **Cada pas de la sincronització ha d'anar aïllat** (try/except per pas). Un error d'importació mai no ha de bloquejar la pujada ni els altres passos.
- **Actualització optimista:** persistir en local immediatament i sincronitzar després.
- **Credencials i tokens fora de les carpetes sincronitzades.** El token d'escriptura només es desa al dispositiu que el necessita.
- **"Forçar actualització" ha de retornar un resultat real:** si hi havia versió nova o no.

---

## 3. Criteris de disseny

### 3.1 Visual
- **Tema:** [A DEFINIR] (LEXAI fa servir tema fosc amb accent `#FF8C42`).
- **Paleta centralitzada** en un únic fitxer o diccionari de configuració.
- **Color específic per a valors calculats o estimats**, diferent del dels valors reals (a LEXAI, groc `#F5C518`).
- **Mida de font mínima: 15px.**
- **Diàlegs propis i estandarditzats** (confirmar, avisar, demanar text) mitjançant helpers comuns. Mai els natius del sistema sense estil.

### 3.2 Estructura de pantalles
- **Mai scroll horitzontal**, tampoc en popups ni desplegables: cal truncar amb salt de línia (word-wrap).
- **Popups i desplegables amb marges interns** d'almenys 6–8px i espai entre línies d'almenys 4–6px, perquè títol i subtítol no quedin enganxats.
- **Botons d'acció de vista o de diàleg sempre a dalt.**
- **Targetes compactes:** les accions secundàries van com a icones rodones dins la línia, no en una fila pròpia.
- **Resum fix** amb comptadors per estat (p. ex. pendents / en curs / fets / total).

### 3.3 Controls al mòbil
- **No fer servir `<select>` natiu** (condicional: web/PWA). Obre un desplegable amb estil de sistema que no es pot personalitzar; cal usar **xips de selecció única**.
- **Inputs numèrics amb `appearance:none`** i botons `+`/`−` rodons alineats a la mateixa línia.
- **Definir explícitament `background`, `border` i `color` a tots els inputs.** A LEXAI, un input sense aquests estils es veia blanc.
- **Dreceres d'increment** (p. ex. "+10") als modals numèrics.

### 3.4 Llistes i files
- **Botons de fila sempre iguals** a totes les files: mateix conjunt, mateix ordre i mateixa mida.
  - Els que no apliquen es **desactiven**, mai s'ometen.
  - Si cal, se substitueixen per una etiqueta d'estat dins la mateixa casella d'amplada fixa.
- **Reordenar segons la posició visible** (mateix `ORDER BY` que la vista, amb l'ID com a desempat) i **renumerar 1..N** abans d'intercanviar. Això resisteix valors duplicats o buits.
- **Inserir en una posició ocupada desplaça +1 les posteriors**, processant de la més alta a la més baixa.
- **Derivar l'ordre d'un criteri objectiu** (data, prioritat) sempre que es pugui, en lloc de demanar un número a mà.
- **Altes encadenades ("Desar i següent"):** refrescar la vista de fons després de cada pas, no al final, i arrossegar els valors comuns al registre següent.

### 3.5 Fluxos
- **Als punts de control, preguntar sempre de manera explícita** ("Finalitzar" o "Ampliar/Continuar"). Mai no s'ha de continuar en silenci.
- **"Cancel·lat" és un estat diferent de "parcial"**, i cancel·lar conserva el progrés ja registrat.
- **Les accions irreversibles o de bloqueig demanen confirmació.**
- **Progrés real per procés** a les operacions llargues (còpia de seguretat, sincronització): cada procés passa de "pendent" a correcte o error a mesura que s'executa.

---

## 4. Regles de negoci

### 4.1 Patrons generals (derivats de LEXAI)
- **Estimat vs. real:** un import pot ser estimat (flag `estimat=1`).
  - Si no s'introdueix, s'omple automàticament amb la mitjana històrica o, si no n'hi ha, amb un valor objectiu per defecte.
  - Es mostra amb el color de "calculat".
  - En registrar l'import real, `estimat=0`.
  - Els totals inclouen els estimats, identificats com a tals.
- **Tancament de període:** un període tancat no admet altes noves ni moviments d'entrada o de sortida. Reobrir-lo demana confirmació, i es mostra l'indicador 🔒.
- **Bloqueig d'objectius:** amb els objectius bloquejats, qualsevol modificació demana confirmació en desar. Botó 🔒/🔓.
- **Escala de prioritat ordenada** (a LEXAI: Imprescindible, Obligat, Interès, Opcional, Movible, Revisable, Evitable). L'ordre manual respecta sempre el bloc de prioritat.
- **Afegir a una llista és idempotent:** si l'element ja hi és, es mostra "Ja afegit" desactivat.
- **Abans de crear un registre, cal cercar per semblança** (normalitzant accents, puntuació i ordre de paraules) per evitar duplicats.
- **La llista de períodes inclou sempre el període actual**, encara que no tingui registres.
- **Les estimacions i projeccions es recalculen en local just després de cada acció**, sense esperar a sincronitzar.

### 4.2 Aplicació als mòduls (proposta, a validar)
- **Checklist previ:**
  - Escala de prioritat per tasca.
  - Resum amb comptadors per estat.
  - Ordre manual robust (§3.4).
  - Estat "fet" derivat i sense duplicats.
  - Botons de fila fixos, desactivats quan la tasca està completada.
- **Despeses:**
  - Previst (estimat) vs. real segons el §4.1.
  - **Tancament del viatge** com a tancament de període.
  - Data real de la despesa (§2.2).
  - Deduplicació abans de crear.
- **Objectius:**
  - Bloqueig amb confirmació.
  - % de compliment.
  - Projeccions amb recurs a la mitjana històrica, marcades com a estimació quan hi ha poques dades (§2.2).
- **Entitats, estats i camps concrets:** [A DEFINIR] a `MODEL_DADES.md`.

---

## 5. Base de dades

- **Motor:** [A DEFINIR].
- **Còpia de seguretat:** abans de cada migració de tancament. Si és SQLite en mode WAL, cal fer `PRAGMA wal_checkpoint(FULL)` abans de copiar.
- **`SCHEMA_VERSION = 0`**

### Sistema de migracions
| Capa | Fitxer | Cobertura |
|---|---|---|
| Esquema inicial | [A DEFINIR] | BD nova |
| Migracions | [A DEFINIR] | Mig. 001– |

- Les migracions són **numerades i idempotents**, i s'apliquen automàticament en obrir l'app.
- El registre de versions i canvis es desa **a la mateixa BD** (taules `versio` i `versio_canvi`), igual que el roadmap.

### Registre de canvis
- Taula d'auditoria amb l'artefacte afectat, el camp i la **data real de l'esdeveniment**.
- També serveix per deduplicar importacions (`client_id`).

### Integritat referencial
- ☐ Activar les claus foranes des de la primera versió.
- ☐ Definir `ON DELETE` i índexs sobre les FK a l'esquema inicial.

---

## 6. Mapa de fitxers

```
[A DEFINIR]
```

---

## 7. Historial de versions

### v0.1 — En curs (des de [DATA])
*Encara sense canvis. Backlog al §8.*

---

## 8. Roadmap i backlog

### v0.1
- ☐ [ARQ] Definir stack, plataforma i persistència (§1)
- ☐ [BD] Definir el model de dades (`MODEL_DADES.md`) i l'esquema inicial
- ☐ [NOU] Mòdul Checklist previ
- ☐ [NOU] Mòdul Despeses
- ☐ [NOU] Mòdul Objectius

### Backlog sense versió
*(Idees i deute tècnic sense versió assignada.)*

---

## Annex — Traçabilitat amb LEXAI

| Bloc d'aquest document | Origen al CONTEXT.md de LEXAI |
|---|---|
| §0 Com treballem, tancament de versió | §0, §⭐ Procés de tancament |
| §2.1–2.3 Dades, dates, estat de la UI | §2 Restriccions tècniques, lliçons d'interfície |
| §2.4–2.5 PWA i sincronització | §6 (nota LEXAI Mòbil), §7 v3.0.2 / v4.0 / v4.1 |
| §3 Criteris de disseny | §3, §2 lliçons, §7 v2.2 / v3.0.2 / v4.0 |
| §4.1 Patrons de negoci | §4, §5 (mig. 084–086), §7 v2.2 / v3.0.2 |
| §5 Base de dades | §5 |

**Descartat per ser específic de LEXAI:**
- Regles de macOS Catalina i PyQt5.
- Rutes locals i Trello.
- Mapa de fitxers de LEXAI.
- Regles de llibres (gèneres, sagues, premis, TBR, pomodoros).

*Fi del document.*
