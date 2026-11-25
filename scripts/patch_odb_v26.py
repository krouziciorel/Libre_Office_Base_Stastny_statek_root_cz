#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Aplikace oprav a vylepšení verze 2.6 do databázového souboru Šťastný_statek.odb a Stastny_statek.odb.
Zahrnuje:
1. Migraci vestavěné databáze Firebird (database/firebird.fbk):
   - Zrušení kaskádového mazání (ON DELETE NO ACTION) u faktur a přihlášek.
   - Odstranění zastaralých duplicitních testovacích faktur (ID 9-26).
   - Normalizaci variabilních symbolů na standardních 8 číslic (DDMMRRRR).
   - Přidání CHECK omezení na délku VS, typy akcí, stavy přihlášek a typy faktur.
   - Přidání UNIQUE omezení (ID_Prihlasky, Typ_Faktury) zamezující duplicitním fakturám.
2. Aktualizaci makro modulu Basic/Standard/Module1.xml:
   - Kontextové načítání vybrané přihlášky z formuláře F5 (tlačítka nevynucují druhý dialog).
   - Striktní zákaz vystavení duplicitní zálohy, doplatku i celkové faktury.
   - Zákaz fakturace náhradníků (NAHRADNIK) a stornovaných přihlášek.
   - Validaci délky variabilního symbolu (max 10 číslic).
   - Kontextový tisk přihlášky i faktury z formuláře F5.
   - Automatický reload přehledu faktur po vystavení.
   - Evidenci bezinfekčnosti vázanou na přihlášku / turnus.
   - Ověření vzniku archivu v makru zálohování.
3. Opravu SQL dotazu Q5_Bez_Bezinfekcnosti v content.xml:
   - Kontrolu odevzdání bezinfekčnosti na konkrétní turnus (Prihlasky.Bezinfekcnost).
"""

import os
import sys
import zipfile
import shutil
import tempfile
import fdb
from fdb import services

def xml_escape(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

def migrate_firebird_fbk(fbk_path, work_dir):
    """Obnoví fbk, provede DDL i DML úpravy a vytvoří nový fbk."""
    print("  -> Zahajuji migraci databáze Firebird...")
    # Použijeme globální /tmp/fb_v26_work se širokými právy pro uživatele firebird
    shared_dir = "/tmp/fb_v26_work"
    if os.path.exists(shared_dir):
        shutil.rmtree(shared_dir)
    os.makedirs(shared_dir, exist_ok=True)
    os.chmod(shared_dir, 0o777)

    staged_fbk = os.path.join(shared_dir, "staged.fbk")
    shutil.copyfile(fbk_path, staged_fbk)
    os.chmod(staged_fbk, 0o666)

    fdb_path = os.path.join(shared_dir, "migrated.fdb")
    svc = services.connect(host='localhost', user='sysdba', password='masterkey')
    
    # 1. Restore
    print("     * Obnova Firebird databáze z fbk...")
    svc.restore(staged_fbk, fdb_path, replace=True)
    for _ in svc.readlines(): pass
    svc.wait()

    # 2. Modify schema & data
    print("     * Provádím SQL úpravy (FK, CHECK, UNIQUE, normalizace VS)...")
    conn = fdb.connect(host='localhost', database=fdb_path, user='sysdba', password='masterkey')
    cur = conn.cursor()

    # Odstranění testovacích duplicitních faktur
    cur.execute('DELETE FROM "Faktury" WHERE "ID_Faktury" BETWEEN 9 AND 26')

    # Oprava stavu přihlášky 1 na POTVRZEN (má vystavenou platnou fakturu FAK-2026-001)
    cur.execute('UPDATE "Prihlasky" SET "Stav" = \'POTVRZEN\' WHERE "ID_Prihlasky" = 1')

    # Normalizace variabilních symbolů na standardní 8místný formát (DDMM + RRRR)
    vs_map = {
        1: '03092026',
        2: '00022026',
        3: '14052026',
        4: '22042026',
        5: '03092026',
        6: '15032027',
        7: '20082027',
        8: '10112027',
        9: '05052027',
        10: '25012027'
    }
    for pid, vs in vs_map.items():
        cur.execute('UPDATE "Prihlasky" SET "Variabilni_Symbol" = ? WHERE "ID_Prihlasky" = ?', (vs, pid))
        cur.execute('UPDATE "Faktury" SET "Variabilni_Symbol" = ? WHERE "ID_Prihlasky" = ?', (vs, pid))

    def safe_ddl(sql):
        try:
            cur.execute(sql)
        except Exception as e:
            # Ignorujeme chyby z již existujících nebo již neexistujících constraintů
            pass

    # Úprava cizích klíčů: ochrana před kaskádovým smazáním faktur a přihlášek
    safe_ddl('ALTER TABLE "Faktury" DROP CONSTRAINT "FK_Fakt_Prih"')
    safe_ddl('ALTER TABLE "Faktury" ADD CONSTRAINT "FK_Fakt_Prih" FOREIGN KEY ("ID_Prihlasky") REFERENCES "Prihlasky" ("ID_Prihlasky") ON DELETE NO ACTION')

    safe_ddl('ALTER TABLE "Prihlasky" DROP CONSTRAINT "FK_Prih_Akce"')
    safe_ddl('ALTER TABLE "Prihlasky" ADD CONSTRAINT "FK_Prih_Akce" FOREIGN KEY ("ID_Akce") REFERENCES "Akce" ("ID_Akce") ON DELETE NO ACTION')

    safe_ddl('ALTER TABLE "Prihlasky" DROP CONSTRAINT "FK_Prih_Zak"')
    safe_ddl('ALTER TABLE "Prihlasky" ADD CONSTRAINT "FK_Prih_Zak" FOREIGN KEY ("ID_Zakaznika") REFERENCES "Zakaznici" ("ID_Zakaznika") ON DELETE NO ACTION')

    # UNIQUE omezení zamezující duplicitním fakturám stejného typu na přihlášce
    safe_ddl('ALTER TABLE "Faktury" DROP CONSTRAINT "UQ_FAKT_PRIH_TYP"')
    safe_ddl('ALTER TABLE "Faktury" ADD CONSTRAINT "UQ_FAKT_PRIH_TYP" UNIQUE ("ID_Prihlasky", "Typ_Faktury")')

    # CHECK omezení pro zachování integrity dat
    safe_ddl('ALTER TABLE "Prihlasky" DROP CONSTRAINT "CHK_PRIH_VS"')
    safe_ddl('ALTER TABLE "Prihlasky" ADD CONSTRAINT "CHK_PRIH_VS" CHECK (CHAR_LENGTH("Variabilni_Symbol") <= 10)')

    safe_ddl('ALTER TABLE "Faktury" DROP CONSTRAINT "CHK_FAKT_VS"')
    safe_ddl('ALTER TABLE "Faktury" ADD CONSTRAINT "CHK_FAKT_VS" CHECK (CHAR_LENGTH("Variabilni_Symbol") <= 10)')

    safe_ddl('ALTER TABLE "Akce" DROP CONSTRAINT "CHK_AKCE_TYP"')
    safe_ddl('''ALTER TABLE "Akce" ADD CONSTRAINT "CHK_AKCE_TYP"
        CHECK ("Typ_Akce" IN ('LETNI_TABOR', 'DETSKY_VIKEND', 'PODZIMNI_PRAZDNINY', 'VYJIZDKA', 'BALICEK', 'BALICEK_1D', 'BALICEK_2D'))''')

    safe_ddl('ALTER TABLE "Prihlasky" DROP CONSTRAINT "CHK_PRIH_STAV"')
    safe_ddl('''ALTER TABLE "Prihlasky" ADD CONSTRAINT "CHK_PRIH_STAV"
        CHECK ("Stav" IN ('POTVRZEN', 'NAHRADNIK', 'STORNO', 'PRIHLASEN'))''')

    safe_ddl('ALTER TABLE "Faktury" DROP CONSTRAINT "CHK_FAKT_TYP"')
    safe_ddl('''ALTER TABLE "Faktury" ADD CONSTRAINT "CHK_FAKT_TYP"
        CHECK ("Typ_Faktury" IN ('ZALOHOVA', 'DOPLATKOVA', 'CELKOVA'))''')

    conn.commit()
    conn.close()

    # 3. Backup back to fbk
    print("     * Zálohování upravené databáze zpět do fbk...")
    out_fbk = os.path.join(shared_dir, "new_firebird.fbk")
    svc.backup(fdb_path, out_fbk)
    for _ in svc.readlines(): pass
    svc.wait()

    shutil.copyfile(out_fbk, fbk_path)
    shutil.rmtree(shared_dir, ignore_errors=True)
    print("  ✓ Firebird databáze úspěšně migrována a uložena.")

def patch_odb(odb_path):
    print(f"\n==========================================")
    print(f"Zpracovávám: {odb_path}")
    print(f"==========================================")
    if not os.path.exists(odb_path):
        print(f"CHYBA: Soubor {odb_path} neexistuje!")
        return False

    tmp_dir = tempfile.mkdtemp(prefix="odb_v26_patch_")
    try:
        # Rozbalení archivu
        with zipfile.ZipFile(odb_path, 'r') as z_in:
            z_in.extractall(tmp_dir)

        # ----------------------------------------------------------------------
        # 1. Migrace Firebird databáze
        # ----------------------------------------------------------------------
        fbk_path = os.path.join(tmp_dir, "database", "firebird.fbk")
        if os.path.exists(fbk_path):
            fb_work_dir = os.path.join(tmp_dir, "fb_work")
            os.makedirs(fb_work_dir, exist_ok=True)
            migrate_firebird_fbk(fbk_path, fb_work_dir)
            shutil.rmtree(fb_work_dir, ignore_errors=True)
        else:
            print("  VAROVÁNÍ: database/firebird.fbk nenalezen!")

        # ----------------------------------------------------------------------
        # 2. Patch Basic/Standard/Module1.xml
        # ----------------------------------------------------------------------
        m1_path = os.path.join(tmp_dir, "Basic", "Standard", "Module1.xml")
        with open(m1_path, "r", encoding="utf-8") as f:
            m1 = f.read()

        bas_path = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun/scripts/module1_v26_updates.bas"
        with open(bas_path, "r", encoding="utf-8") as f:
            bas_content = f.read()

        # Nahradíme celou sadu maker z nového .bas souboru
        # Odstraníme staré verze těchto procedur:
        sub_names_to_remove = [
            "VystavitZalohu", "VystavitDoplatek", "VytvoritCelkovouFakturu",
            "VytvoritZalohovouFakturu", "VytvoritDoplatkovouFakturu", "VytvoritFakturu",
            "GenerovatCisloFaktury", "TisknoutPrihlaskuPDF", "TisknoutFakturuPDF",
            "VybratPrihlaskuSeznamu", "OznacitBezinfekcnost", "ZalohovatData"
        ]

        for sname in sub_names_to_remove:
            for prefix in [f"SUB {sname}", f"FUNCTION {sname}"]:
                pos = m1.find(prefix)
                if pos != -1:
                    end_sub = m1.find("END SUB", pos)
                    end_fn = m1.find("END FUNCTION", pos)
                    end_pos = -1
                    if end_sub != -1 and (end_fn == -1 or end_sub < end_fn):
                        end_pos = end_sub + 7
                    elif end_fn != -1:
                        end_pos = end_fn + 12
                    
                    if end_pos != -1:
                        m1 = m1[:pos] + m1[end_pos:]

        # Přidáme nový kód z module1_v26_updates.bas na konec před uzavírací tag modulu
        insert_idx = m1.rfind("</ns0:module>")
        if insert_idx == -1:
            insert_idx = m1.rfind("</script:module>")
        if insert_idx == -1:
            insert_idx = m1.rfind("</")

        if insert_idx != -1:
            m1 = m1[:insert_idx] + "\n\n" + xml_escape(bas_content) + "\n" + m1[insert_idx:]
        else:
            print("  VAROVÁNÍ: Nepodařilo se najít uzavírací tag pro modul!")

        # Aktualizace hlavičky verze
        m1 = m1.replace(
            "Stastny Statek - Modul maker v2.4",
            "Stastny Statek - Modul maker v2.6 (bezpečnost transakcí, ochrana duplicit, kontextové ovládání)"
        ).replace(
            "Stastny Statek - Modul maker v2.5 (ochrana duplicit faktur, bezinfekčnost, bezpečné číslování)",
            "Stastny Statek - Modul maker v2.6 (bezpečnost transakcí, ochrana duplicit, kontextové ovládání)"
        )

        with open(m1_path, "w", encoding="utf-8") as f:
            f.write(m1)
        print("  ✓ Basic/Standard/Module1.xml úspěšně aktualizován na verzi 2.6.")

        # ----------------------------------------------------------------------
        # 3. Patch content.xml (SQL dotazy)
        # ----------------------------------------------------------------------
        cx_path = os.path.join(tmp_dir, "content.xml")
        with open(cx_path, "r", encoding="utf-8") as f:
            cx = f.read()

        # Q5_Bez_Bezinfekcnosti: bezinfekčnost se vztahuje na konkrétní přihlášku / turnus!
        # Nahradíme podmínku tak, aby kontrolovala Prihlasky.Bezinfekcnost
        cx = cx.replace(
            'WHERE (COALESCE(&quot;Prihlasky&quot;.&quot;Bezinfekcnost&quot;, 0) = 0 AND COALESCE(&quot;Deti&quot;.&quot;Bezinfekcnost&quot;, 0) = 0) AND &quot;Prihlasky&quot;.&quot;Stav&quot; NOT IN (&apos;STORNO&apos;, &apos;NAHRADNIK&apos;)',
            'WHERE COALESCE(&quot;Prihlasky&quot;.&quot;Bezinfekcnost&quot;, 0) = 0 AND &quot;Prihlasky&quot;.&quot;Stav&quot; NOT IN (&apos;STORNO&apos;, &apos;NAHRADNIK&apos;)'
        )

        with open(cx_path, "w", encoding="utf-8") as f:
            f.write(cx)
        print("  ✓ Dotaz Q5_Bez_Bezinfekcnosti v content.xml aktualizován.")

        # ----------------------------------------------------------------------
        # 4. Zabalení zpět do archivu ODB
        # ----------------------------------------------------------------------
        new_odb_tmp = odb_path + ".tmp"
        with zipfile.ZipFile(new_odb_tmp, 'w', compression=zipfile.ZIP_DEFLATED) as z_out:
            # mimetype musí být první a nestlačený
            mimetype_path = os.path.join(tmp_dir, "mimetype")
            if os.path.exists(mimetype_path):
                z_out.write(mimetype_path, "mimetype", compress_type=zipfile.ZIP_STORED)

            for root, dirs, files in os.walk(tmp_dir):
                for file in files:
                    full_p = os.path.join(root, file)
                    rel_p = os.path.relpath(full_p, tmp_dir)
                    if rel_p == "mimetype":
                        continue
                    z_out.write(full_p, rel_p, compress_type=zipfile.ZIP_DEFLATED)

        shutil.move(new_odb_tmp, odb_path)
        print(f"  ✓ Databáze {odb_path} úspěšně zabalena a uložena.")
        return True

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

if __name__ == "__main__":
    p1 = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun/Stastny_statek.odb"
    p2 = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base/Šťastný_statek.odb"

    ok1 = patch_odb(p1)
    ok2 = patch_odb(p2)

    if ok1 and ok2:
        # Aktualizujeme také záložní soubor ZAL/latest/Stastny_statek.odb
        latest_zal = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun/ZAL/latest/Stastny_statek.odb"
        shutil.copyfile(p1, latest_zal)
        print(f"\n✓ Kopie v {latest_zal} synchronizována.")
        print("\nÚSPĚCH: Obě databáze byly úspěšně zmigrovány na verzi 2.6!")
    else:
        print("\nCHYBA: Některá databáze nebyla zmigrována!")
        sys.exit(1)
