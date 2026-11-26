#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Aplikace oprav a vylepšení verze 2.7 do databázového souboru Šťastný_statek.odb a Stastny_statek.odb.
Zahrnuje:
1. Migraci vestavěné databáze Firebird 3.0:
   - Rozšíření tabulky Prihlasky o sloupce Cena_Zakladni, Sleva, Duvod_Slevy.
   - Normalizaci variabilních symbolů na unikátní 10místné symboly formátu RRRR + 6místné ID.
   - Přidání unikátního indexu UQ_PRIH_VS na Prihlasky.Variabilni_Symbol.
   - Opravu historických platebních záznamů (Uhrazeno, Castka_Zaplaceno, Datum_Zaplaceno).
   - CHECK omezení na nezáporné částky, kapacity a data akcí.
   - Databázový trigger TRG_CHECK_FAKTURY vynucující striktní finanční pravidla.
   - Databázový trigger TRG_CHECK_PRIHLASKY zamezující duplicitním registracím dětí.
2. Aktualizaci makro modulu Basic/Standard/Module1.xml:
   - Kontextové ovládání fakturace a bezinfekčnosti.
   - Zápis slev a konečných cen přímo do databáze.
   - Podporu pro typ akce BALICEK.
   - Nezkreslování plaveckých schopností.
   - Bezpečné generování QR plateb a normalizaci IBAN.
3. Doplnění tlačítka 'Označit bezinfekčnost' do formuláře F5 (forms/Obj51/content.xml).
4. Opravu SQL dotazů v content.xml:
   - Q3 a Q4: pouze potvrzení účastníci (Stav = 'POTVRZEN').
   - Q6 a Q7: zohlednění částečných plateb a výpočet zbývající částky k úhradě.
"""

import os
import sys
import zipfile
import shutil
import tempfile
import xml.sax.saxutils as saxutils
import fdb
from fdb import services

fdb.load_api('/app/libreoffice/program/libfbclient.so.2')

def xml_escape(text):
    return saxutils.escape(text, {'"': '&quot;', "'": '&apos;'})

def migrate_firebird(fbk_path, work_dir):
    fdb_path = os.path.join(work_dir, "db.fdb")
    fbk_out = os.path.join(work_dir, "firebird.fbk")

    svc = services.connect(user='sysdba', password='masterkey')
    print("   Obnova Firebird 3.0 z fbk...")
    svc.restore(fbk_path, fdb_path, replace=True)
    for _ in svc.readlines(): pass
    svc.wait()

    conn = fdb.connect(database=fdb_path, user='sysdba', password='masterkey')
    cur = conn.cursor()

    print("   Aplikace SQL změn a integrity...")
    try:
        cur.execute('ALTER TRIGGER TRG_CHECK_FAKTURY INACTIVE')
        conn.commit()
    except Exception:
        pass
    try:
        cur.execute('ALTER TRIGGER TRG_CHECK_PRIHLASKY INACTIVE')
        conn.commit()
    except Exception:
        pass

    # 1. Nové sloupce pro slevy
    try:
        cur.execute('ALTER TABLE "Prihlasky" ADD "Cena_Zakladni" DECIMAL(10,2)')
    except Exception as e:
        print("   Note Cena_Zakladni:", e)
    try:
        cur.execute('ALTER TABLE "Prihlasky" ADD "Sleva" DECIMAL(10,2) DEFAULT 0')
    except Exception as e:
        print("   Note Sleva:", e)
    try:
        cur.execute('ALTER TABLE "Prihlasky" ADD "Duvod_Slevy" VARCHAR(200)')
    except Exception as e:
        print("   Note Duvod_Slevy:", e)
    conn.commit()

    # 2. Oprava dat přihlášky 1 a faktury 1
    cur.execute('''
        UPDATE "Prihlasky"
        SET "ID_Akce" = 1,
            "ID_Zakaznika" = 4,
            "ID_Ditete" = NULL,
            "Stav" = 'POTVRZEN',
            "Cena_Celkem" = 800.00,
            "Cena_Zakladni" = 800.00,
            "Sleva" = 0.00,
            "Duvod_Slevy" = NULL,
            "Variabilni_Symbol" = '2026000001'
        WHERE "ID_Prihlasky" = 1
    ''')

    cur.execute('''
        UPDATE "Faktury"
        SET "Typ_Faktury" = 'CELKOVA',
            "Castka" = 800.00,
            "Castka_Zaplaceno" = 800.00,
            "Uhrazeno" = 1,
            "Datum_Zaplaceno" = '2026-06-25',
            "Variabilni_Symbol" = '2026000001'
        WHERE "ID_Faktury" = 1
    ''')

    # Nastavení Cena_Zakladni pro ostatní přihlášky
    cur.execute('''
        UPDATE "Prihlasky"
        SET "Cena_Zakladni" = "Cena_Celkem",
            "Sleva" = 0.00
        WHERE "Cena_Zakladni" IS NULL
    ''')

    # 3. Normalizace variabilních symbolů na unikátní 10místné symboly
    vs_map = {
        1: '2026000001',
        2: '2026000002',
        3: '2026000003',
        4: '2026000004',
        5: '2026000005',
        6: '2027000006',
        7: '2027000007',
        8: '2027000008',
        9: '2027000009',
        10: '2027000010'
    }
    for pid, vs in vs_map.items():
        cur.execute('UPDATE "Prihlasky" SET "Variabilni_Symbol" = ? WHERE "ID_Prihlasky" = ?', (vs, pid))
        cur.execute('UPDATE "Faktury" SET "Variabilni_Symbol" = ? WHERE "ID_Prihlasky" = ?', (vs, pid))

    # 4. Oprava stavu plateb ve Faktury
    cur.execute('''
        UPDATE "Faktury"
        SET "Castka_Zaplaceno" = 1000.00,
            "Datum_Zaplaceno" = '2026-06-28'
        WHERE "ID_Faktury" = 4
    ''')

    cur.execute('''
        UPDATE "Faktury"
        SET "Castka_Zaplaceno" = 3000.00,
            "Datum_Zaplaceno" = '2026-06-25'
        WHERE "ID_Faktury" = 6
    ''')

    cur.execute('''
        UPDATE "Faktury"
        SET "Datum_Zaplaceno" = '2027-01-20'
        WHERE "ID_Faktury" BETWEEN 27 AND 31
    ''')
    conn.commit()

    # 5. UNIQUE omezení na Variabilni_Symbol
    try:
        cur.execute('ALTER TABLE "Prihlasky" ADD CONSTRAINT "UQ_PRIH_VS" UNIQUE ("Variabilni_Symbol")')
        conn.commit()
        print("   ✓ UNIQUE UQ_PRIH_VS přidáno.")
    except Exception as e:
        print("   Note UQ_PRIH_VS:", e)

    # 6. CHECK omezení
    checks = [
        ('ALTER TABLE "Faktury" ADD CONSTRAINT "CHK_FAKT_CASTKA" CHECK ("Castka" > 0)', 'CHK_FAKT_CASTKA'),
        ('ALTER TABLE "Faktury" ADD CONSTRAINT "CHK_FAKT_ZAPLACENO" CHECK ("Castka_Zaplaceno" >= 0 AND "Castka_Zaplaceno" <= "Castka")', 'CHK_FAKT_ZAPLACENO'),
        ('ALTER TABLE "Akce" ADD CONSTRAINT "CHK_AKCE_CENA" CHECK ("Cena_Celkem" >= 0)', 'CHK_AKCE_CENA'),
        ('ALTER TABLE "Akce" ADD CONSTRAINT "CHK_AKCE_ZALOHA" CHECK ("Zalohova_Castka" >= 0 AND ("Cena_Celkem" IS NULL OR "Zalohova_Castka" <= "Cena_Celkem"))', 'CHK_AKCE_ZALOHA'),
        ('ALTER TABLE "Akce" ADD CONSTRAINT "CHK_AKCE_KAPACITA" CHECK ("Kapacita" > 0)', 'CHK_AKCE_KAPACITA'),
        ('ALTER TABLE "Akce" ADD CONSTRAINT "CHK_AKCE_DATUM" CHECK ("Datum_Do" IS NULL OR "Datum_Do" >= "Datum_Od")', 'CHK_AKCE_DATUM'),
        ('ALTER TABLE "Prihlasky" ADD CONSTRAINT "CHK_PRIH_CENA" CHECK ("Cena_Celkem" >= 0)', 'CHK_PRIH_CENA')
    ]
    for chk_sql, name in checks:
        try:
            cur.execute(chk_sql)
            conn.commit()
            print(f"   ✓ {name} přidáno.")
        except Exception as e:
            print(f"   Note {name}:", e)

    # 7. Výjimky
    try:
        cur.execute("CREATE EXCEPTION EX_FIN_INTEGRITA 'Chyba financni integrity'")
        conn.commit()
    except Exception as e:
        pass

    try:
        cur.execute("CREATE EXCEPTION EX_PRIH_INTEGRITA 'Chyba integrity prihlasky'")
        conn.commit()
    except Exception as e:
        pass

    # 8. Triggery
    trg_faktury = '''
    CREATE OR ALTER TRIGGER TRG_CHECK_FAKTURY FOR "Faktury"
    ACTIVE BEFORE INSERT OR UPDATE POSITION 0
    AS
    DECLARE VARIABLE v_cena DECIMAL(10,2);
    DECLARE VARIABLE v_sum DECIMAL(10,2);
    DECLARE VARIABLE v_zaloha INT;
    DECLARE VARIABLE v_doplatek INT;
    DECLARE VARIABLE v_celkova INT;
    BEGIN
        IF (NEW."Castka" <= 0) THEN
            EXCEPTION EX_FIN_INTEGRITA 'Castka faktury musi byt kladna!';

        SELECT "Cena_Celkem" FROM "Prihlasky" WHERE "ID_Prihlasky" = NEW."ID_Prihlasky"
        INTO :v_cena;

        SELECT
            COUNT(CASE WHEN "Typ_Faktury" = 'ZALOHOVA' THEN 1 END),
            COUNT(CASE WHEN "Typ_Faktury" = 'DOPLATKOVA' THEN 1 END),
            COUNT(CASE WHEN "Typ_Faktury" = 'CELKOVA' THEN 1 END),
            COALESCE(SUM("Castka"), 0)
        FROM "Faktury"
        WHERE "ID_Prihlasky" = NEW."ID_Prihlasky"
          AND "ID_Faktury" <> COALESCE(NEW."ID_Faktury", -1)
        INTO :v_zaloha, :v_doplatek, :v_celkova, :v_sum;

        IF ((INSERTING OR (UPDATING AND OLD."Typ_Faktury" <> NEW."Typ_Faktury")) AND NEW."Typ_Faktury" = 'CELKOVA' AND (:v_zaloha > 0 OR :v_doplatek > 0)) THEN
            EXCEPTION EX_FIN_INTEGRITA 'Nelze vytvorit celkovou fakturu - jiz existuje zalohova nebo doplatkova faktura!';

        IF ((INSERTING OR (UPDATING AND OLD."Typ_Faktury" <> NEW."Typ_Faktury")) AND NEW."Typ_Faktury" IN ('ZALOHOVA', 'DOPLATKOVA') AND :v_celkova > 0) THEN
            EXCEPTION EX_FIN_INTEGRITA 'Nelze vytvorit zalohu/doplatek - jiz existuje celkova faktura!';

        IF ((INSERTING OR (UPDATING AND OLD."Typ_Faktury" <> NEW."Typ_Faktury")) AND NEW."Typ_Faktury" = 'ZALOHOVA' AND :v_doplatek > 0) THEN
            EXCEPTION EX_FIN_INTEGRITA 'Nelze vystavit zalohovou fakturu po jiz vystavene doplatkove fakture!';

        IF (v_cena IS NOT NULL AND (:v_sum + NEW."Castka" > v_cena)) THEN
            EXCEPTION EX_FIN_INTEGRITA 'Soucet faktur prekracuje celkovou cenu prihlasky!';

        IF (NEW."Uhrazeno" = 1) THEN
        BEGIN
            IF (NEW."Datum_Zaplaceno" IS NULL) THEN
                NEW."Datum_Zaplaceno" = CURRENT_DATE;
            IF (NEW."Castka_Zaplaceno" < NEW."Castka") THEN
                NEW."Castka_Zaplaceno" = NEW."Castka";
        END
    END
    '''
    cur.execute(trg_faktury)
    conn.commit()
    print("   ✓ Trigger TRG_CHECK_FAKTURY vytvořen.")

    trg_prihlasky = '''
    CREATE OR ALTER TRIGGER TRG_CHECK_PRIHLASKY FOR "Prihlasky"
    ACTIVE BEFORE INSERT OR UPDATE POSITION 0
    AS
    DECLARE VARIABLE v_dup_count INT;
    BEGIN
        IF (NEW."ID_Ditete" IS NOT NULL AND NEW."Stav" <> 'STORNO') THEN
        BEGIN
            SELECT COUNT(*) FROM "Prihlasky"
            WHERE "ID_Akce" = NEW."ID_Akce"
              AND "ID_Ditete" = NEW."ID_Ditete"
              AND "Stav" <> 'STORNO'
              AND "ID_Prihlasky" <> COALESCE(NEW."ID_Prihlasky", -1)
            INTO :v_dup_count;

            IF (:v_dup_count > 0) THEN
                EXCEPTION EX_PRIH_INTEGRITA 'Dite jiz ma na tuto akci aktivni prihlasku!';
        END
    END
    '''
    cur.execute(trg_prihlasky)
    conn.commit()
    print("   ✓ Trigger TRG_CHECK_PRIHLASKY vytvořen.")

    conn.close()

    print("   Zálohování do FBK (verze 10)...")
    svc.backup(fdb_path, fbk_out)
    for _ in svc.readlines(): pass
    svc.wait()

    with open(fbk_out, 'rb') as f:
        hdr = f.read(50)
    b_ver = hdr[3]
    if b_ver != 10:
        raise RuntimeError(f"Chyba: Vytvořená záloha má verzi {b_ver}, očekáváno 10!")
    print("   ✓ FBK záloha verze 10 ověřena.")
    return fbk_out

def patch_f5_form(content_xml):
    # 1. Přidání definice tlačítka do <office:forms>
    btn_def = (
        '<form:button form:name="btnBezinfekcnost" form:control-implementation="ooo:com.sun.star.form.component.CommandButton" '
        'xml:id="control39" form:id="control39" form:label="Označit bezinfekčnost" office:target-frame="" '
        'form:delay-for-repeat="PT0.050000000S" form:image-position="center">'
        '<form:properties><form:property form:property-name="DefaultControl" office:value-type="string" office:string-value="com.sun.star.form.control.CommandButton"/></form:properties>'
        '<office:event-listeners><script:event-listener script:language="ooo:script" script:event-name="form:performaction" '
        'xlink:href="vnd.sun.star.script:Standard.Module1.OznacitBezinfekcnost?language=Basic&amp;location=document" xlink:type="simple"/>'
        '</office:event-listeners></form:button>'
    )
    if 'form:name="btnBezinfekcnost"' not in content_xml:
        pos = content_xml.find('</form:form></office:forms>')
        if pos != -1:
            content_xml = content_xml[:pos] + btn_def + content_xml[pos:]
            print("   ✓ Přidána definice tlačítka btnBezinfekcnost do F5.")

    # 2. Úprava draw controls (zmenšení původních tlačítek na 4.8cm a přidání pátého)
    old_c25 = '<draw:control text:anchor-type="paragraph" draw:z-index="9" draw:name="Ovládací prvek 1" draw:style-name="gr8" draw:text-style-name="P4" svg:width="5.5cm" svg:height="1.001cm" svg:x="1cm" svg:y="12.2cm" draw:control="control25"/>'
    new_c25 = '<draw:control text:anchor-type="paragraph" draw:z-index="9" draw:name="Ovládací prvek 1" draw:style-name="gr8" draw:text-style-name="P4" svg:width="4.8cm" svg:height="1.001cm" svg:x="1.0cm" svg:y="12.2cm" draw:control="control25"/>'

    old_c26 = '<draw:control text:anchor-type="paragraph" draw:z-index="10" draw:name="Ovládací prvek 2" draw:style-name="gr8" draw:text-style-name="P4" svg:width="5.5cm" svg:height="1.001cm" svg:x="7.0cm" svg:y="12.2cm" draw:control="control26"/>'
    new_c26 = '<draw:control text:anchor-type="paragraph" draw:z-index="10" draw:name="Ovládací prvek 2" draw:style-name="gr8" draw:text-style-name="P4" svg:width="4.8cm" svg:height="1.001cm" svg:x="6.1cm" svg:y="12.2cm" draw:control="control26"/>'

    old_c27 = '<draw:control text:anchor-type="paragraph" draw:z-index="11" draw:name="Ovládací prvek 3" draw:style-name="gr8" draw:text-style-name="P4" svg:width="6.0cm" svg:height="1.001cm" svg:x="13.0cm" svg:y="12.2cm" draw:control="control27"/>'
    new_c27 = '<draw:control text:anchor-type="paragraph" draw:z-index="11" draw:name="Ovládací prvek 3" draw:style-name="gr8" draw:text-style-name="P4" svg:width="4.8cm" svg:height="1.001cm" svg:x="11.2cm" svg:y="12.2cm" draw:control="control27"/>'

    old_c28 = '<draw:control text:anchor-type="paragraph" draw:z-index="12" draw:name="Ovládací prvek 4" draw:style-name="gr8" draw:text-style-name="P4" svg:width="6.3cm" svg:height="1.001cm" svg:x="19.5cm" svg:y="12.2cm" draw:control="control28"/>'
    new_c28 = (
        '<draw:control text:anchor-type="paragraph" draw:z-index="12" draw:name="Ovládací prvek 4" draw:style-name="gr8" draw:text-style-name="P4" svg:width="4.8cm" svg:height="1.001cm" svg:x="16.3cm" svg:y="12.2cm" draw:control="control28"/>\n'
        '<draw:control text:anchor-type="paragraph" draw:z-index="13" draw:name="Ovládací prvek 5" draw:style-name="gr8" draw:text-style-name="P4" svg:width="4.8cm" svg:height="1.001cm" svg:x="21.4cm" svg:y="12.2cm" draw:control="control39"/>'
    )

    if old_c25 in content_xml: content_xml = content_xml.replace(old_c25, new_c25)
    if old_c26 in content_xml: content_xml = content_xml.replace(old_c26, new_c26)
    if old_c27 in content_xml: content_xml = content_xml.replace(old_c27, new_c27)
    if old_c28 in content_xml:
        content_xml = content_xml.replace(old_c28, new_c28)
        print("   ✓ Přidán draw shape pro control39 (Označit bezinfekčnost) do F5.")

    return content_xml

def patch_content_queries(cx):
    # Q3_Seznam_Ucastniku: pouze POTVRZEN
    q3_old = 'WHERE "Prihlasky"."Stav" NOT IN (\'STORNO\', \'NAHRADNIK\') ORDER BY "Akce"."Nazev"'
    q3_new = 'WHERE "Prihlasky"."Stav" = \'POTVRZEN\' ORDER BY "Akce"."Nazev"'
    if q3_old in cx:
        cx = cx.replace(q3_old, q3_new)
        print("   ✓ Q3_Seznam_Ucastniku upraven na POTVRZEN.")

    # Q4_Kooperativa: pouze POTVRZEN
    q4_old = 'AND "Prihlasky"."Stav" NOT IN (\'STORNO\', \'NAHRADNIK\') AND ("Filtr"."ID_Akce" IS NULL'
    q4_new = 'AND "Prihlasky"."Stav" = \'POTVRZEN\' AND ("Filtr"."ID_Akce" IS NULL'
    if q4_old in cx:
        cx = cx.replace(q4_old, q4_new)
        print("   ✓ Q4_Kooperativa upraven na POTVRZEN.")

    # Q6_Nezaplacene_Zalohy: zbývající částka
    q6_old = 'SELECT "Faktury"."Cislo_Faktury", "Faktury"."Castka", "Faktury"."Datum_Vystaveni", "Faktury"."Datum_Splatnosti", "Zakaznici"."Prijmeni" AS "Zakaznik_Prijmeni", "Zakaznici"."Jmeno" AS "Zakaznik_Jmeno", "Zakaznici"."Telefon", "Zakaznici"."Email", "Akce"."Nazev" AS "Nazev_Akce" FROM "Faktury" JOIN "Prihlasky" ON "Faktury"."ID_Prihlasky" = "Prihlasky"."ID_Prihlasky" JOIN "Zakaznici" ON "Prihlasky"."ID_Zakaznika" = "Zakaznici"."ID_Zakaznika" JOIN "Akce" ON "Prihlasky"."ID_Akce" = "Akce"."ID_Akce" WHERE "Faktury"."Typ_Faktury" = \'ZALOHOVA\' AND ("Faktury"."Uhrazeno" = 0 OR "Faktury"."Uhrazeno" IS NULL) ORDER BY "Faktury"."Datum_Splatnosti"'
    q6_new = 'SELECT "Faktury"."Cislo_Faktury", "Faktury"."Castka", "Faktury"."Castka_Zaplaceno", ("Faktury"."Castka" - COALESCE("Faktury"."Castka_Zaplaceno", 0)) AS "Zbyva_Uhradit", "Faktury"."Datum_Vystaveni", "Faktury"."Datum_Splatnosti", "Zakaznici"."Prijmeni" AS "Zakaznik_Prijmeni", "Zakaznici"."Jmeno" AS "Zakaznik_Jmeno", "Zakaznici"."Telefon", "Zakaznici"."Email", "Akce"."Nazev" AS "Nazev_Akce" FROM "Faktury" JOIN "Prihlasky" ON "Faktury"."ID_Prihlasky" = "Prihlasky"."ID_Prihlasky" JOIN "Zakaznici" ON "Prihlasky"."ID_Zakaznika" = "Zakaznici"."ID_Zakaznika" JOIN "Akce" ON "Prihlasky"."ID_Akce" = "Akce"."ID_Akce" WHERE "Faktury"."Typ_Faktury" = \'ZALOHOVA\' AND ("Faktury"."Uhrazeno" = 0 OR "Faktury"."Uhrazeno" IS NULL) AND ("Faktury"."Castka" - COALESCE("Faktury"."Castka_Zaplaceno", 0)) > 0 ORDER BY "Faktury"."Datum_Splatnosti"'
    if q6_old in cx:
        cx = cx.replace(q6_old, q6_new)
        print("   ✓ Q6_Nezaplacene_Zalohy upraven na zbývající částku.")

    # Q7_Nezaplacene_Doplatky: zbývající částka
    q7_old = 'SELECT "Faktury"."Cislo_Faktury", "Faktury"."Castka", "Faktury"."Datum_Vystaveni", "Faktury"."Datum_Splatnosti", "Zakaznici"."Prijmeni" AS "Zakaznik_Prijmeni", "Zakaznici"."Jmeno" AS "Zakaznik_Jmeno", "Zakaznici"."Telefon", "Zakaznici"."Email", "Akce"."Nazev" AS "Nazev_Akce" FROM "Faktury" JOIN "Prihlasky" ON "Faktury"."ID_Prihlasky" = "Prihlasky"."ID_Prihlasky" JOIN "Zakaznici" ON "Prihlasky"."ID_Zakaznika" = "Zakaznici"."ID_Zakaznika" JOIN "Akce" ON "Prihlasky"."ID_Akce" = "Akce"."ID_Akce" WHERE "Faktury"."Typ_Faktury" = \'DOPLATKOVA\' AND ("Faktury"."Uhrazeno" = 0 OR "Faktury"."Uhrazeno" IS NULL) ORDER BY "Faktury"."Datum_Splatnosti"'
    q7_new = 'SELECT "Faktury"."Cislo_Faktury", "Faktury"."Castka", "Faktury"."Castka_Zaplaceno", ("Faktury"."Castka" - COALESCE("Faktury"."Castka_Zaplaceno", 0)) AS "Zbyva_Uhradit", "Faktury"."Datum_Vystaveni", "Faktury"."Datum_Splatnosti", "Zakaznici"."Prijmeni" AS "Zakaznik_Prijmeni", "Zakaznici"."Jmeno" AS "Zakaznik_Jmeno", "Zakaznici"."Telefon", "Zakaznici"."Email", "Akce"."Nazev" AS "Nazev_Akce" FROM "Faktury" JOIN "Prihlasky" ON "Faktury"."ID_Prihlasky" = "Prihlasky"."ID_Prihlasky" JOIN "Zakaznici" ON "Prihlasky"."ID_Zakaznika" = "Zakaznici"."ID_Zakaznika" JOIN "Akce" ON "Prihlasky"."ID_Akce" = "Akce"."ID_Akce" WHERE "Faktury"."Typ_Faktury" = \'DOPLATKOVA\' AND ("Faktury"."Uhrazeno" = 0 OR "Faktury"."Uhrazeno" IS NULL) AND ("Faktury"."Castka" - COALESCE("Faktury"."Castka_Zaplaceno", 0)) > 0 ORDER BY "Faktury"."Datum_Splatnosti"'
    if q7_old in cx:
        cx = cx.replace(q7_old, q7_new)
        print("   ✓ Q7_Nezaplacene_Doplatky upraven na zbývající částku.")

    return cx

def patch_odb_file(odb_path, bas_updates_path):
    print(f"\nZpracovávám: {odb_path}")
    tmp_dir = tempfile.mkdtemp(prefix="odb_patch_v27_")
    try:
        with zipfile.ZipFile(odb_path, 'r') as z:
            z.extractall(tmp_dir)

        # 1. Firebird migrace
        fbk_path = os.path.join(tmp_dir, "database", "firebird.fbk")
        if os.path.exists(fbk_path):
            fb_work = os.path.join(tmp_dir, "fb_work")
            os.makedirs(fb_work, exist_ok=True)
            new_fbk = migrate_firebird(fbk_path, fb_work)
            shutil.copyfile(new_fbk, fbk_path)
            shutil.rmtree(fb_work, ignore_errors=True)

        # 2. Patch Basic maker
        m1_path = os.path.join(tmp_dir, "Basic", "Standard", "Module1.xml")
        with open(m1_path, 'r', encoding='utf-8') as f:
            m1 = f.read()

        with open(bas_updates_path, 'r', encoding='utf-8') as f:
            bas_content = f.read()

        sub_names_to_remove = [
            "GetBaseFolder", "VystavitZalohu", "VystavitDoplatek", "VytvoritCelkovouFakturu",
            "VytvoritZalohovouFakturu", "VytvoritDoplatkovouFakturu", "VytvoritFakturu",
            "VytvoritFakturuContext", "GenerovatCisloFaktury", "TisknoutPrihlaskuPDF",
            "TisknoutFakturuPDF", "VybratPrihlaskuSeznamu", "PrihlaskaZID", "FakturaZID",
            "OznacitBezinfekcnost", "ZalohovatData"
        ]

        for sname in sub_names_to_remove:
            for prefix in [f"SUB {sname}", f"FUNCTION {sname}"]:
                pos = m1.find(prefix)
                while pos != -1:
                    end_sub = m1.find("END SUB", pos)
                    end_fn = m1.find("END FUNCTION", pos)
                    end_pos = -1
                    if end_sub != -1 and (end_fn == -1 or end_sub < end_fn):
                        end_pos = end_sub + 7
                    elif end_fn != -1:
                        end_pos = end_fn + 12
                    
                    if end_pos != -1:
                        m1 = m1[:pos] + m1[end_pos:]
                    else:
                        break
                    pos = m1.find(prefix)

        insert_idx = m1.rfind("</script:module>")
        if insert_idx == -1:
            insert_idx = m1.rfind("</")
        if insert_idx != -1:
            m1 = m1[:insert_idx] + "\n\n" + xml_escape(bas_content) + "\n" + m1[insert_idx:]
            print("   ✓ Basic makra úspěšně aktualizována na verzi 2.7.")

        m1 = m1.replace("v2.6", "v2.7").replace("v2.5", "v2.7").replace("v2.4", "v2.7")
        with open(m1_path, 'w', encoding='utf-8') as f:
            f.write(m1)

        # 3. Patch formuláře F5 (forms/Obj51/content.xml)
        f5_path = os.path.join(tmp_dir, "forms", "Obj51", "content.xml")
        if os.path.exists(f5_path):
            with open(f5_path, 'r', encoding='utf-8') as f:
                f5_content = f.read()
            f5_content = patch_f5_form(f5_content)
            with open(f5_path, 'w', encoding='utf-8') as f:
                f.write(f5_content)

        # 4. Patch SQL dotazů v content.xml
        cx_path = os.path.join(tmp_dir, "content.xml")
        if os.path.exists(cx_path):
            with open(cx_path, 'r', encoding='utf-8') as f:
                cx_content = f.read()
            cx_content = patch_content_queries(cx_content)
            with open(cx_path, 'w', encoding='utf-8') as f:
                f.write(cx_content)

        # 5. Zabalení zpět do ODB (mimetype nekomprimovaný)
        tmp_odb = odb_path + ".v27.tmp"
        with zipfile.ZipFile(tmp_odb, 'w', compression=zipfile.ZIP_DEFLATED) as z_out:
            # 1. mimetype bez komprese
            mt_path = os.path.join(tmp_dir, "mimetype")
            if os.path.exists(mt_path):
                z_out.write(mt_path, "mimetype", compress_type=zipfile.ZIP_STORED)

            for root, dirs, files in os.walk(tmp_dir):
                for file in files:
                    full_p = os.path.join(root, file)
                    rel_p = os.path.relpath(full_p, tmp_dir)
                    if rel_p == "mimetype":
                        continue
                    z_out.write(full_p, rel_p, compress_type=zipfile.ZIP_DEFLATED)

        shutil.move(tmp_odb, odb_path)
        print(f"   ✓ Soubor {odb_path} úspěšně aktualizován na verzi 2.7.")

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

def main():
    base_dir = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun"
    bas_updates = os.path.join(base_dir, "scripts", "module1_v27_updates.bas")

    targets = [
        os.path.join(base_dir, "Stastny_statek.odb"),
        "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base/Šťastný_statek.odb"
    ]

    for t in targets:
        if os.path.exists(t):
            patch_odb_file(t, bas_updates)

    latest_zal = os.path.join(base_dir, "ZAL", "latest", "Stastny_statek.odb")
    if os.path.exists(targets[0]):
        shutil.copyfile(targets[0], latest_zal)
        print(f"\n✓ Synchronizována záloha do {latest_zal}")

    print("\nÚSPĚCH: Verze 2.7 byla kompletně aplikována na všechny databáze!")

if __name__ == "__main__":
    main()
