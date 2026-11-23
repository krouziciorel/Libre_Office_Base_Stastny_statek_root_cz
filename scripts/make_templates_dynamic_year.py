#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Skript pro nastavení dynamického roku v záhlaví šablon přihlášek (LT, DV, PT)
a napojení makra PrihlaskaZID na pole PRIHL_ROK dle termínu akce (Datum_Od).
"""

import os
import sys
import zipfile
import shutil
import tempfile
import xml.etree.ElementTree as ET

TEMPLATES_CONFIG = [
    ('Přihláška_LT.odt',
     'Závazná přihláška na letní tábor 20<ns7:span ns7:style-name="T1">2</ns7:span><ns7:span ns7:style-name="T2">6</ns7:span> na Šťastném statku',
     'Závazná přihláška na letní tábor <ns7:user-field-get ns7:name="PRIHL_ROK">2027</ns7:user-field-get> na Šťastném statku',
     '<ns7:user-field-decl ns0:value-type="string" ns0:string-value="2027" ns7:name="PRIHL_ROK" />'),
    ('Přihláška_DV.odt',
     'Závazná přihláška na <ns7:span ns7:style-name="T1">dětský</ns7:span><ns7:span ns7:style-name="T2"> víkend</ns7:span> 20<ns7:span ns7:style-name="T3">2</ns7:span><ns7:span ns7:style-name="T4">6</ns7:span> na Šťastném statku',
     'Závazná přihláška na <ns7:span ns7:style-name="T1">dětský</ns7:span><ns7:span ns7:style-name="T2"> víkend</ns7:span> <ns7:user-field-get ns7:name="PRIHL_ROK">2027</ns7:user-field-get> na Šťastném statku',
     '<ns7:user-field-decl value-type="string" ns7:name="PRIHL_ROK" string-value="2027" />\n  '),
    ('Přihláška_PT.odt',
     'Závazná přihláška na podzimní prázdniny 20</ns7:span><ns7:span ns7:style-name="T2">2</ns7:span><ns7:span ns7:style-name="T3">6</ns7:span><ns7:span ns7:style-name="T1"> na Šťastném statku',
     'Závazná přihláška na podzimní prázdniny </ns7:span><ns7:user-field-get ns7:name="PRIHL_ROK">2027</ns7:user-field-get><ns7:span ns7:style-name="T1"> na Šťastném statku',
     '<ns7:user-field-decl value-type="string" ns7:name="PRIHL_ROK" string-value="2027" />\n  ')
]

def patch_template(odt_path, title_target, title_repl, decl_decl):
    print(f"  Upravuji šablonu: {odt_path}")
    if not os.path.exists(odt_path):
        print(f"    CHYBA: Soubor {odt_path} neexistuje!")
        return False
    
    tmp_dir = tempfile.mkdtemp(prefix="odt_patch_")
    try:
        with zipfile.ZipFile(odt_path, 'r') as z_in:
            z_in.extractall(tmp_dir)
            
        cx_path = os.path.join(tmp_dir, "content.xml")
        with open(cx_path, "r", encoding="utf-8") as f:
            cx = f.read()

        if title_target not in cx:
            if 'PRIHL_ROK' in cx:
                print(f"    Šablona {os.path.basename(odt_path)} již pole PRIHL_ROK obsahuje.")
                return True
            else:
                print(f"    VAROVÁNÍ: Cílový text pro název v {odt_path} nebyl nalezen!")
                return False

        # Vložení deklarace pole
        if '<ns7:user-field-decls>' in cx:
            cx = cx.replace('<ns7:user-field-decls>', '<ns7:user-field-decls>' + decl_decl)
        else:
            first_decl = '<ns7:user-field-decl'
            cx = cx.replace(first_decl, decl_decl + first_decl, 1)

        # Nahrazení fixního roku dynamickým polem
        cx = cx.replace(title_target, title_repl)

        # Kontrola validity XML
        ET.fromstring(cx.encode('utf-8'))

        with open(cx_path, "w", encoding="utf-8") as f:
            f.write(cx)

        # Přepakování archivu
        new_odt_tmp = odt_path + ".tmp"
        with zipfile.ZipFile(new_odt_tmp, 'w', compression=zipfile.ZIP_DEFLATED) as z_out:
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

        shutil.move(new_odt_tmp, odt_path)
        print(f"    ✓ Šablona {os.path.basename(odt_path)} úspěšně upravena s dynamickým polem PRIHL_ROK.")
        return True
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

def patch_odb_macro(odb_path):
    print(f"\n  Upravuji makro PrihlaskaZID v: {odb_path}")
    if not os.path.exists(odb_path):
        print(f"    CHYBA: Soubor {odb_path} neexistuje!")
        return False

    tmp_dir = tempfile.mkdtemp(prefix="odb_macro_")
    try:
        with zipfile.ZipFile(odb_path, 'r') as z_in:
            z_in.extractall(tmp_dir)

        m1_path = os.path.join(tmp_dir, "Basic", "Standard", "Module1.xml")
        with open(m1_path, "r", encoding="utf-8") as f:
            m1 = f.read()

        target = 'SetUF oDoc, "PRIHL_AKCE_TERMIN",     sTermin'
        repl = """SetUF oDoc, "PRIHL_AKCE_TERMIN",     sTermin
    DIM sRokAkce AS STRING
    IF LEN(Trim(sDatumOd)) >= 4 THEN
        sRokAkce = Left(Trim(sDatumOd), 4)
    ELSE
        sRokAkce = Format(Year(Date), "0000")
    END IF
    SetUF oDoc, "PRIHL_ROK",              sRokAkce"""

        if target in m1:
            m1 = m1.replace(target, repl)
            print("    ✓ Kód pro dynamický rok PRIHL_ROK vložen do PrihlaskaZID.")
        elif 'SetUF oDoc, "PRIHL_ROK"' in m1:
            print("    Makro PrihlaskaZID již pole PRIHL_ROK nastavuje.")
        else:
            print("    VAROVÁNÍ: target v Module1.xml nenalezen!")
            return False

        with open(m1_path, "w", encoding="utf-8") as f:
            f.write(m1)

        # Přepakování archivu
        new_odb_tmp = odb_path + ".tmp"
        with zipfile.ZipFile(new_odb_tmp, 'w', compression=zipfile.ZIP_DEFLATED) as z_out:
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
        print(f"    ✓ Databáze {os.path.basename(odb_path)} úspěšně zabalena a uložena.")
        return True
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

if __name__ == "__main__":
    base_dirs = [
        "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base",
        "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun"
    ]

    for b in base_dirs:
        print(f"\n=======================================================")
        print(f"Aktualizace adresáře: {b}")
        print(f"=======================================================")
        sablony_dir = os.path.join(b, "Sablony")
        for fname, target, repl, decl in TEMPLATES_CONFIG:
            fpath = os.path.join(sablony_dir, fname)
            patch_template(fpath, target, repl, decl)

    # Aktualizace maker v obou ODB
    patch_odb_macro("/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base/Šťastný_statek.odb")
    patch_odb_macro("/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun/Stastny_statek.odb")

    print("\nÚSPĚCH: Šablony i makra byla úspěšně aktualizována pro dynamický rok!")
