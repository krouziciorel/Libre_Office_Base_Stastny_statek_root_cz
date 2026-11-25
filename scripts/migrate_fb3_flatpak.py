#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Migrace embedded Firebird 3.0 databáze pro LibreOffice Base s verzí zálohy 10 (Firebird 3.0 compatible).
Tento skript běží uvnitř flatpak prostředí LibreOffice s knihovnou libfbclient.so.2 (Firebird 3.0.14).
"""

import os
import sys
import zipfile
import shutil
import tempfile
import fdb
from fdb import services

# Načtení Firebird 3.0 embedded API
fdb.load_api('/app/libreoffice/program/libfbclient.so.2')

def run_migration():
    base_dir = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun"
    fbk_base = os.path.join(base_dir, "scripts", "firebird_v10_base.fbk")
    work_dir = os.path.join(base_dir, ".fb3_migration")
    if os.path.exists(work_dir):
        shutil.rmtree(work_dir)
    os.makedirs(work_dir, exist_ok=True)

    fdb_path = os.path.join(work_dir, "stastny3.fdb")
    fbk_out = os.path.join(work_dir, "firebird.fbk")

    print("1. Obnova Firebird 3.0 databáze z výchozího fbk verze 10...")
    svc = services.connect(user='sysdba', password='masterkey')
    print("   Server verze:", svc.get_server_version())
    svc.restore(fbk_base, fdb_path, replace=True)
    for _ in svc.readlines(): pass
    svc.wait()
    print("   ✓ Obnova dokončena. Velikost FDB:", os.path.getsize(fdb_path))

    print("2. Aplikace SQL migrací (integritní pravidla, FK, UNIQUE, CHECK, normalizace VS)...")
    conn = fdb.connect(database=fdb_path, user='sysdba', password='masterkey')
    cur = conn.cursor()

    # Odstranění starých testovacích duplicitních faktur (ID 9-26)
    cur.execute('DELETE FROM "Faktury" WHERE "ID_Faktury" BETWEEN 9 AND 26')

    # Oprava stavu přihlášky 1 na POTVRZEN (vyjížďka má vystaven doklad FAK-2026-001)
    cur.execute('UPDATE "Prihlasky" SET "Stav" = \'POTVRZEN\' WHERE "ID_Prihlasky" = 1')

    # Normalizace variabilních symbolů na 8 číslic (DDMM + RRRR)
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

    # Cizí klíče NO ACTION (ochrana před kaskádovým smazáním)
    cur.execute('ALTER TABLE "Faktury" DROP CONSTRAINT "FK_Fakt_Prih"')
    cur.execute('ALTER TABLE "Faktury" ADD CONSTRAINT "FK_Fakt_Prih" FOREIGN KEY ("ID_Prihlasky") REFERENCES "Prihlasky" ("ID_Prihlasky") ON DELETE NO ACTION')

    cur.execute('ALTER TABLE "Prihlasky" DROP CONSTRAINT "FK_Prih_Akce"')
    cur.execute('ALTER TABLE "Prihlasky" ADD CONSTRAINT "FK_Prih_Akce" FOREIGN KEY ("ID_Akce") REFERENCES "Akce" ("ID_Akce") ON DELETE NO ACTION')

    cur.execute('ALTER TABLE "Prihlasky" DROP CONSTRAINT "FK_Prih_Zak"')
    cur.execute('ALTER TABLE "Prihlasky" ADD CONSTRAINT "FK_Prih_Zak" FOREIGN KEY ("ID_Zakaznika") REFERENCES "Zakaznici" ("ID_Zakaznika") ON DELETE NO ACTION')

    # UNIQUE omezení
    cur.execute('ALTER TABLE "Faktury" ADD CONSTRAINT "UQ_FAKT_PRIH_TYP" UNIQUE ("ID_Prihlasky", "Typ_Faktury")')

    # CHECK omezení
    cur.execute('ALTER TABLE "Prihlasky" ADD CONSTRAINT "CHK_PRIH_VS" CHECK (CHAR_LENGTH("Variabilni_Symbol") <= 10)')
    cur.execute('ALTER TABLE "Faktury" ADD CONSTRAINT "CHK_FAKT_VS" CHECK (CHAR_LENGTH("Variabilni_Symbol") <= 10)')
    cur.execute('''ALTER TABLE "Akce" ADD CONSTRAINT "CHK_AKCE_TYP"
        CHECK ("Typ_Akce" IN ('LETNI_TABOR', 'DETSKY_VIKEND', 'PODZIMNI_PRAZDNINY', 'VYJIZDKA', 'BALICEK', 'BALICEK_1D', 'BALICEK_2D'))''')
    cur.execute('''ALTER TABLE "Prihlasky" ADD CONSTRAINT "CHK_PRIH_STAV"
        CHECK ("Stav" IN ('POTVRZEN', 'NAHRADNIK', 'STORNO', 'PRIHLASEN'))''')
    cur.execute('''ALTER TABLE "Faktury" ADD CONSTRAINT "CHK_FAKT_TYP"
        CHECK ("Typ_Faktury" IN ('ZALOHOVA', 'DOPLATKOVA', 'CELKOVA'))''')

    conn.commit()
    conn.close()
    print("   ✓ SQL úpravy úspěšně provedeny.")

    print("3. Vytvoření Firebird 3.0 kompatibilní zálohy (backup version 10)...")
    svc.backup(fdb_path, fbk_out)
    for _ in svc.readlines(): pass
    svc.wait()
    print("   ✓ Záloha dokončena. Velikost FBK:", os.path.getsize(fbk_out))

    with open(fbk_out, 'rb') as f:
        hdr = f.read(50)
    b_ver = hdr[3]
    print(f"   ✓ Ověření verze fbk hlavičky: {b_ver} (očekáváno: 10)")
    if b_ver != 10:
        print("CHYBA: Verze zálohy není 10!")
        sys.exit(1)

    # 4. Aktualizace FBK v obou ODB souborech
    targets = [
        "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun/Stastny_statek.odb",
        "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base/Šťastný_statek.odb"
    ]

    for odb_path in targets:
        print(f"4. Aktualizace FBK v {odb_path}...")
        tmp_odb = odb_path + ".v10.tmp"
        with zipfile.ZipFile(odb_path, 'r') as z_in:
            with zipfile.ZipFile(tmp_odb, 'w', compression=zipfile.ZIP_DEFLATED) as z_out:
                for item in z_in.infolist():
                    if item.filename == "mimetype":
                        z_out.writestr(item, z_in.read(item.filename), compress_type=zipfile.ZIP_STORED)
                    elif item.filename == "database/firebird.fbk":
                        with open(fbk_out, 'rb') as fbkf:
                            z_out.writestr(item, fbkf.read(), compress_type=zipfile.ZIP_DEFLATED)
                    else:
                        z_out.writestr(item, z_in.read(item.filename), compress_type=zipfile.ZIP_DEFLATED)
        shutil.move(tmp_odb, odb_path)
        print(f"   ✓ {odb_path} úspěšně aktualizován s FBK verze 10.")

    # Synchronizace ZAL/latest
    latest_zal = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun/ZAL/latest/Stastny_statek.odb"
    shutil.copyfile(targets[0], latest_zal)
    print(f"   ✓ Synchronizována záloha v {latest_zal}.")

    shutil.rmtree(work_dir, ignore_errors=True)
    print("\nÚSPĚCH: Obě databáze mají vestavěný Firebird 3 s verzí zálohy 10 kompatibilní s LibreOffice Base!")

if __name__ == "__main__":
    run_migration()
