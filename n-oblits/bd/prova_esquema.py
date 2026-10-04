"""N-Oblits — Prova de l'esquema inicial amb les dades d'exemple de les pantalles.
Executar: python3 prova_esquema.py   (crea una BD en memòria; no toca cap fitxer)"""
import sqlite3, uuid, os
T = '2026-10-06T10:00:00Z'
AQUI = os.path.dirname(os.path.abspath(__file__))
db = sqlite3.connect(':memory:')
db.execute('PRAGMA foreign_keys = ON')
db.executescript(open(os.path.join(AQUI, 'esquema_inicial.sql'), encoding='utf-8').read())
assert db.execute('PRAGMA foreign_keys').fetchone()[0] == 1
S = dict(creat_el=T, modificat_el=T, modificat_a='mobil')
def ins(taula, **c):
    c.setdefault('id', str(uuid.uuid4())); c.update({k: v for k, v in S.items() if k not in c})
    db.execute(f"INSERT INTO {taula} ({','.join(c)}) VALUES ({','.join('?'*len(c))})", list(c.values()))
    return c['id']

# Persones i viatge
ramon = ins('persona', nom='Ramon', nom_normalitzat='ramon', es_propietaria=1)
p2 = ins('persona', nom='Persona 2', nom_normalitzat='persona 2')
p3 = ins('persona', nom='Persona 3', nom_normalitzat='persona 3')
v = ins('viatge', nom='Japó', data_inici='2026-10-03', data_fi='2026-10-15', moneda_local_codi='JPY',
        canvi_moneda_local=162.5, temps_esperat='sol', temp_min=18, temp_max=26, limit_diari_eur=100)
gA = ins('grup', viatge_id=v, nom='Grup A', ordre=1); gB = ins('grup', viatge_id=v, nom='Grup B', ordre=2)
for p, g in [(ramon, gA), (p2, gA), (p3, gB)]: ins('viatge_persona', viatge_id=v, persona_id=p, grup_id=g)
ld = ins('llista', viatge_id=v, tipus='despeses', nom='Despeses')

# Metàl·lic del grup de referència
ins('moviment_metallic', viatge_id=v, data='2026-10-03', data_hora_real=T, tipus='inicial', **{'import': 40000}, moneda_codi='JPY', persona_id=ramon)
ins('moviment_metallic', viatge_id=v, data='2026-10-03', data_hora_real=T, tipus='inicial', **{'import': 100}, moneda_codi='EUR', persona_id=ramon)
ins('moviment_metallic', viatge_id=v, data='2026-10-05', data_hora_real=T, tipus='caixer', **{'import': 20000}, moneda_codi='JPY', persona_id=ramon)

P = {'Ramon': ramon, 'Persona 2': p2, 'Persona 3': p3}; G = {'Grup A': gA, 'Grup B': gB}
CAT = {'dinar': 'cat-dinar', 'sopar': 'cat-sopar', 'compra': 'cat-compra', 'excursio': 'cat-excursio'}
E = [  # dia, cat, concepte, pp, pers, total, moneda, paga, mitjà, imputació, repartiment
('03','compra','Compra aeroport',None,None,12.50,'EUR','Ramon','targeta','personal',None),
('03','sopar','Sopar arribada',None,None,7200,'JPY','Ramon','targeta','general','persona'),
('03','compra','Supermercat',None,None,2300,'JPY','Persona 3','metallic','general','grup'),
('04','dinar','Dinar',1100,3,3300,'JPY','Persona 2','metallic','general','persona'),
('04','excursio','Excursió',2500,3,7500,'JPY','Ramon','targeta','general','persona'),
('04','sopar','Sopar (amb vi)',None,None,9000,'JPY','Persona 3','targeta','general',{'Grup A':6000,'Grup B':3000}),
('05','dinar','Dinar',1300,3,3900,'JPY','Ramon','metallic','general','persona'),
('05','excursio','Museu',1000,2,2000,'JPY','Ramon','metallic','Grup A',None),
('05','sopar','Sopar',None,None,7800,'JPY','Persona 3','targeta','general','grup'),
('06','dinar','Dinar',1200,3,3600,'JPY','Ramon','metallic','general','persona'),
('06','compra','Records',None,None,4500,'JPY','Persona 3','targeta','personal',None),
('06','excursio','Excursió',1500,3,4500,'JPY','Persona 2','metallic','general','persona'),
]
for dia, cat, con, pp, n, tot, mon, paga, mitja, imp, rep in E:
    grup = G.get(imp)
    d = ins('despesa', viatge_id=v, llista_id=ld, data=f'2026-10-{dia}', data_hora_real=T, concepte=con,
            categoria_id=CAT[cat], moneda_codi=mon, preu_persona=pp, n_persones=n, import_total=tot,
            pagador_persona_id=P[paga], mitja=mitja, imputacio='grup' if grup else imp,
            grup_imputat_id=grup, repartiment=('adhoc' if isinstance(rep, dict) else rep))
    if isinstance(rep, dict):
        for g, imp_ in rep.items(): ins('despesa_part', despesa_id=d, grup_id=G[g], **{'import': imp_})

q = lambda sql, *a: db.execute(sql, a).fetchall()
# 1. Saldo de metàl·lic (pantalla 03): 40.000 + 20.000 − 17.300 = 42.700 ¥
saldo = dict(q('SELECT moneda_codi, saldo FROM v_saldo_metallic WHERE viatge_id=?', v))
assert saldo == {'EUR': 100.0, 'JPY': 42700.0}, saldo
# 2. Compensacions (pantalla 12): Grup A paga 6,46 € al Grup B
comp = {n: (round(p, 2), round(c, 2)) for n, p, c in q('SELECT nom, pagat_eur, correspon_eur FROM v_compensacio WHERE viatge_id=?', v)}
assert comp == {'Grup A': (196.92, 203.38), 'Grup B': (117.54, 111.08)}, comp
# 3. Despesa per dia (pantalla 14)
dies = {d: round(t, 2) for d, t in q('SELECT data, total_eur FROM v_despesa_dia WHERE viatge_id=?', v)}
assert dies == {'2026-10-03': 70.96, '2026-10-04': 121.85, '2026-10-05': 84.31, '2026-10-06': 77.54}, dies
# 4. Idempotència: la mateixa targeta de plantilla dues vegades a la mateixa llista → error
lc = ins('llista', viatge_id=v, tipus='control', nom='Control')
tp = ins('targeta_plantilla', nom='Passaport', nom_normalitzat='passaport', ubicacio_id='ubi-maleta', prioritat_codi='imprescindible')
ins('element_control', llista_id=lc, nom='Passaport', nom_normalitzat='passaport', prioritat_codi='imprescindible', targeta_origen_id=tp)
try:
    ins('element_control', llista_id=lc, nom='Passaport', nom_normalitzat='passaport', prioritat_codi='imprescindible', targeta_origen_id=tp); raise SystemExit('FALLA idempotència')
except sqlite3.IntegrityError: pass
# 5. Control de cicles (MODEL_DADES §6): A conté B; afegir B → A ha de detectar cicle
cA = ins('plantilla', nom='Viatge estiu', nom_normalitzat='viatge estiu', tipus='conjunt')
cB = ins('plantilla', nom='Documentació', nom_normalitzat='documentacio', tipus='conjunt')
ins('plantilla_item', plantilla_id=cA, subplantilla_id=cB)
CICLE = '''WITH RECURSIVE desc(id) AS (SELECT ? UNION SELECT pi.subplantilla_id FROM plantilla_item pi
           JOIN desc ON pi.plantilla_id = desc.id WHERE pi.subplantilla_id IS NOT NULL AND pi.esborrat = 0)
           SELECT EXISTS(SELECT 1 FROM desc WHERE id = ?)'''
assert q(CICLE, cA, cB)[0][0] == 1          # afegir cA dins cB crearia un cicle → rebutjar
assert q(CICLE, cB, cA)[0][0] == 0          # afegir cB dins cA (ja hi és) no és cicle
# 7. Expansió d'un conjunt: targetes úniques encara que surtin a diverses subplantilles (F6.4)
tD = ins('targeta_plantilla', nom='DNI', nom_normalitzat='dni', prioritat_codi='imprescindible')
ins('plantilla_item', plantilla_id=cB, targeta_id=tp); ins('plantilla_item', plantilla_id=cB, targeta_id=tD)
ins('plantilla_item', plantilla_id=cA, targeta_id=tp)          # Passaport també directe al conjunt A
EXPANDIR = '''WITH RECURSIVE arbre(id) AS (SELECT ? UNION SELECT pi.subplantilla_id FROM plantilla_item pi
           JOIN arbre a ON pi.plantilla_id = a.id WHERE pi.subplantilla_id IS NOT NULL AND pi.esborrat = 0)
           SELECT DISTINCT t.nom FROM arbre a JOIN plantilla_item pi ON pi.plantilla_id = a.id
           AND pi.targeta_id IS NOT NULL AND pi.esborrat = 0
           JOIN targeta_plantilla t ON t.id = pi.targeta_id AND t.esborrat = 0 ORDER BY t.nom'''
assert [r[0] for r in q(EXPANDIR, cA)] == ['DNI', 'Passaport']
# 6. Restriccions: màx. 2 monedes / canvi obligatori amb moneda local
try:
    ins('viatge', nom='X', data_inici='2026-01-01', data_fi='2026-01-02', moneda_local_codi='JPY'); raise SystemExit('FALLA canvi')
except sqlite3.IntegrityError: pass
print('OK — totes les proves superades')
print('  Saldo metàl·lic:', saldo)
print('  Compensacions:', comp)
print('  Despesa per dia:', dies)
