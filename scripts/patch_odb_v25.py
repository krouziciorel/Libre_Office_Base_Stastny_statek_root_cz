#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Aplikace oprav verze 2.5 do databázového souboru Šťastný_statek.odb a Stastny_statek.odb.
"""

import os
import sys
import zipfile
import shutil
import tempfile

def xml_escape(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

def patch_odb(odb_path):
    print(f"\n==========================================")
    print(f"Zpracovávám: {odb_path}")
    print(f"==========================================")
    if not os.path.exists(odb_path):
        print(f"CHYBA: Soubor {odb_path} neexistuje!")
        return False

    tmp_dir = tempfile.mkdtemp(prefix="odb_patch_")
    try:
        # Rozbalení archivu
        with zipfile.ZipFile(odb_path, 'r') as z_in:
            z_in.extractall(tmp_dir)

        # ----------------------------------------------------------------------
        # 1. Patch Basic/Standard/Module1.xml
        # ----------------------------------------------------------------------
        m1_path = os.path.join(tmp_dir, "Basic", "Standard", "Module1.xml")
        with open(m1_path, "r", encoding="utf-8") as f:
            m1 = f.read()

        # Načteme aktualizovaný kód z module1_v25_updates.bas
        bas_path = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base/scripts/module1_v25_updates.bas"
        with open(bas_path, "r", encoding="utf-8") as f:
            bas_content = f.read()

        # Rozdělíme na jednotlivé subroutiny
        def extract_sub(code, sub_name):
            start = code.find(f"SUB {sub_name}(")
            if start == -1:
                start = code.find(f"SUB {sub_name}()")
            end = code.find("END SUB", start) + 7
            return code[start:end]

        new_vf = xml_escape(extract_sub(bas_content, "VytvoritFakturu"))
        new_gcf = xml_escape(extract_sub(bas_content, "GenerovatCisloFaktury"))
        new_ob = xml_escape(extract_sub(bas_content, "OznacitBezinfekcnost"))
        new_zd = xml_escape(extract_sub(bas_content, "ZalohovatData"))

        # Nahrazení VytvoritFakturu v m1
        start = m1.find("SUB VytvoritFakturu(")
        end = m1.find("END SUB", start) + 7
        m1 = m1[:start] + new_vf + m1[end:]
        print("  ✓ VytvoritFakturu aktualizována.")

        # Nahrazení GenerovatCisloFaktury v m1
        start = m1.find("SUB GenerovatCisloFaktury()")
        end = m1.find("END SUB", start) + 7
        m1 = m1[:start] + new_gcf + m1[end:]
        print("  ✓ GenerovatCisloFaktury aktualizována.")

        # Nahrazení OznacitBezinfekcnost v m1
        start = m1.find("SUB OznacitBezinfekcnost()")
        end = m1.find("END SUB", start) + 7
        m1 = m1[:start] + new_ob + m1[end:]
        print("  ✓ OznacitBezinfekcnost aktualizována.")

        # Nahrazení ZalohovatData v m1
        start = m1.find("SUB ZalohovatData()")
        end = m1.find("END SUB", start) + 7
        m1 = m1[:start] + new_zd + m1[end:]
        print("  ✓ ZalohovatData aktualizována.")

        # Bezpečný JOIN na Dodavatele v PrihlaskaZID
        m1 = m1.replace(
            'sF5 = " CROSS JOIN " &amp; Chr(34) &amp; "Dodavatele" &amp; Chr(34) &amp; " dd WHERE p." &amp; Chr(34) &amp; "ID_Prihlasky" &amp; Chr(34) &amp; "=" &amp; nIDPrih',
            'sF5 = " LEFT JOIN " &amp; Chr(34) &amp; "Dodavatele" &amp; Chr(34) &amp; " dd ON dd." &amp; Chr(34) &amp; "ID_Dodavatele" &amp; Chr(34) &amp; "=1 WHERE p." &amp; Chr(34) &amp; "ID_Prihlasky" &amp; Chr(34) &amp; "=" &amp; nIDPrih'
        )

        # Bezpečný JOIN na Dodavatele ve FakturaZID
        m1 = m1.replace(
            'jF = " CROSS JOIN " &amp; Chr(34) &amp; "Dodavatele" &amp; Chr(34) &amp; " dd WHERE f." &amp; Chr(34) &amp; "ID_Faktury" &amp; Chr(34) &amp; "=" &amp; nIDFak',
            'jF = " LEFT JOIN " &amp; Chr(34) &amp; "Dodavatele" &amp; Chr(34) &amp; " dd ON dd." &amp; Chr(34) &amp; "ID_Dodavatele" &amp; Chr(34) &amp; "=1 WHERE f." &amp; Chr(34) &amp; "ID_Faktury" &amp; Chr(34) &amp; "=" &amp; nIDFak'
        )

        # Unikátní soubor QR a kontrola existence ve FakturaZID
        m1 = m1.replace(
            'sQrPath = GetBaseFolder() &amp; "Dokumenty/qr_faktura.png"',
            'sQrPath = GetBaseFolder() &amp; "Dokumenty/qr_faktura_" &amp; sCislo &amp; ".png"'
        )

        # Nahrazení ověření QR tvaru ve FakturaZID
        old_shape_check = """        ON ERROR RESUME NEXT
        Shell("python3", 0, sParamQR, TRUE)
        ON ERROR GOTO 0
        
        ' Popisek v buňce
        oSheet.getCellByPosition(1, 42).setString("QR platba")
        
        ' Aktualizace tvaru QR_Platba na listu
        oDrawPage = oSheet.getDrawPage()
        bQrFound = FALSE
        FOR iShp = 0 TO oDrawPage.getCount() - 1
            oShape = oDrawPage.getByIndex(iShp)
            IF oShape.getName() = "QR_Platba" THEN
                oShape.GraphicURL = ConvertToURL(sQrPath)
                bQrFound = TRUE
                EXIT FOR
            END IF
        NEXT iShp"""

        new_shape_check = """        DIM nRetQR AS LONG
        nRetQR = Shell("python3", 0, sParamQR, TRUE)
        
        ' Popisek v buňce
        oSheet.getCellByPosition(1, 42).setString("QR platba")
        
        ' Aktualizace tvaru QR_Platba na listu s ověřením existence souboru
        IF FileExists(sQrPath) THEN
            oDrawPage = oSheet.getDrawPage()
            bQrFound = FALSE
            FOR iShp = 0 TO oDrawPage.getCount() - 1
                oShape = oDrawPage.getByIndex(iShp)
                IF oShape.getName() = "QR_Platba" THEN
                    oShape.GraphicURL = ConvertToURL(sQrPath)
                    bQrFound = TRUE
                    EXIT FOR
                END IF
            NEXT iShp
        ELSE
            MsgBox "Upozornění: QR kód pro fakturu " &amp; sCislo &amp; " se nepodařilo vygenerovat (" &amp; sQrPath &amp; ")." &amp; Chr(13) &amp; "Zkontrolujte skript " &amp; sScriptQR, 48, "QR platba"
        END IF"""

        if old_shape_check in m1:
            m1 = m1.replace(old_shape_check, new_shape_check)
            print("  ✓ QR blok ve FakturaZID aktualizován na unikátní soubor a kontrolu.")
        else:
            print("  VAROVÁNÍ: old_shape_check nebyl nalezen doslovně!")

        # Aktualizace hlavičky verze
        m1 = m1.replace(
            "Stastny Statek - Modul maker v2.4",
            "Stastny Statek - Modul maker v2.5 (ochrana duplicit faktur, bezinfekčnost, bezpečné číslování)"
        )

        with open(m1_path, "w", encoding="utf-8") as f:
            f.write(m1)

        # ----------------------------------------------------------------------
        # 2. Patch content.xml (SQL dotazy)
        # ----------------------------------------------------------------------
        cx_path = os.path.join(tmp_dir, "content.xml")
        with open(cx_path, "r", encoding="utf-8") as f:
            cx = f.read()

        # Q3_Seznam_Ucastniku: vyloučení NAHRADNIK
        cx = cx.replace(
            'db:name="Q3_Seznam_Ucastniku" db:command="SELECT &quot;Akce&quot;.&quot;Nazev&quot; AS &quot;Nazev_Akce&quot;, &quot;Akce&quot;.&quot;Datum_Od&quot;, &quot;Akce&quot;.&quot;Datum_Do&quot;, &quot;Deti&quot;.&quot;Prijmeni&quot; AS &quot;Dite_Prijmeni&quot;, &quot;Deti&quot;.&quot;Jmeno&quot; AS &quot;Dite_Jmeno&quot;, &quot;Deti&quot;.&quot;Datum_Narozeni&quot;, &quot;Zakaznici&quot;.&quot;Prijmeni&quot; AS &quot;Rodic_Prijmeni&quot;, &quot;Zakaznici&quot;.&quot;Jmeno&quot; AS &quot;Rodic_Jmeno&quot;, &quot;Zakaznici&quot;.&quot;Telefon&quot; AS &quot;Rodic_Telefon&quot;, &quot;Zakaznici&quot;.&quot;Email&quot; AS &quot;Rodic_Email&quot;, &quot;Prihlasky&quot;.&quot;Stav&quot; FROM &quot;Prihlasky&quot; JOIN &quot;Akce&quot; ON &quot;Prihlasky&quot;.&quot;ID_Akce&quot; = &quot;Akce&quot;.&quot;ID_Akce&quot; JOIN &quot;Deti&quot; ON &quot;Prihlasky&quot;.&quot;ID_Ditete&quot; = &quot;Deti&quot;.&quot;ID_Ditete&quot; JOIN &quot;Zakaznici&quot; ON &quot;Prihlasky&quot;.&quot;ID_Zakaznika&quot; = &quot;Zakaznici&quot;.&quot;ID_Zakaznika&quot; WHERE &quot;Prihlasky&quot;.&quot;Stav&quot; &lt;&gt; &apos;STORNO&apos; ORDER BY &quot;Akce&quot;.&quot;Nazev&quot;, &quot;Deti&quot;.&quot;Prijmeni&quot;, &quot;Deti&quot;.&quot;Jmeno&quot;"',
            'db:name="Q3_Seznam_Ucastniku" db:command="SELECT &quot;Akce&quot;.&quot;Nazev&quot; AS &quot;Nazev_Akce&quot;, &quot;Akce&quot;.&quot;Datum_Od&quot;, &quot;Akce&quot;.&quot;Datum_Do&quot;, &quot;Deti&quot;.&quot;Prijmeni&quot; AS &quot;Dite_Prijmeni&quot;, &quot;Deti&quot;.&quot;Jmeno&quot; AS &quot;Dite_Jmeno&quot;, &quot;Deti&quot;.&quot;Datum_Narozeni&quot;, &quot;Zakaznici&quot;.&quot;Prijmeni&quot; AS &quot;Rodic_Prijmeni&quot;, &quot;Zakaznici&quot;.&quot;Jmeno&quot; AS &quot;Rodic_Jmeno&quot;, &quot;Zakaznici&quot;.&quot;Telefon&quot; AS &quot;Rodic_Telefon&quot;, &quot;Zakaznici&quot;.&quot;Email&quot; AS &quot;Rodic_Email&quot;, &quot;Prihlasky&quot;.&quot;Stav&quot; FROM &quot;Prihlasky&quot; JOIN &quot;Akce&quot; ON &quot;Prihlasky&quot;.&quot;ID_Akce&quot; = &quot;Akce&quot;.&quot;ID_Akce&quot; JOIN &quot;Deti&quot; ON &quot;Prihlasky&quot;.&quot;ID_Ditete&quot; = &quot;Deti&quot;.&quot;ID_Ditete&quot; JOIN &quot;Zakaznici&quot; ON &quot;Prihlasky&quot;.&quot;ID_Zakaznika&quot; = &quot;Zakaznici&quot;.&quot;ID_Zakaznika&quot; WHERE &quot;Prihlasky&quot;.&quot;Stav&quot; NOT IN (&apos;STORNO&apos;, &apos;NAHRADNIK&apos;) ORDER BY &quot;Akce&quot;.&quot;Nazev&quot;, &quot;Deti&quot;.&quot;Prijmeni&quot;, &quot;Deti&quot;.&quot;Jmeno&quot;"'
        )

        # Q4_Kooperativa: vyloučení NAHRADNIK
        cx = cx.replace(
            'WHERE (&quot;Deti&quot;.&quot;Urazove_Pojisteni&quot; = 0 OR &quot;Deti&quot;.&quot;Urazove_Pojisteni&quot; IS NULL) AND &quot;Prihlasky&quot;.&quot;Stav&quot; &lt;&gt; &apos;STORNO&apos; AND (&quot;Filtr&quot;.&quot;ID_Akce&quot; IS NULL OR &quot;Akce&quot;.&quot;ID_Akce&quot; = &quot;Filtr&quot;.&quot;ID_Akce&quot;)',
            'WHERE (&quot;Deti&quot;.&quot;Urazove_Pojisteni&quot; = 0 OR &quot;Deti&quot;.&quot;Urazove_Pojisteni&quot; IS NULL) AND &quot;Prihlasky&quot;.&quot;Stav&quot; NOT IN (&apos;STORNO&apos;, &apos;NAHRADNIK&apos;) AND (&quot;Filtr&quot;.&quot;ID_Akce&quot; IS NULL OR &quot;Akce&quot;.&quot;ID_Akce&quot; = &quot;Filtr&quot;.&quot;ID_Akce&quot;)'
        )

        # Q5_Bez_Bezinfekcnosti: vyhodnocení jak Prihlasky, tak Deti
        cx = cx.replace(
            'WHERE (&quot;Prihlasky&quot;.&quot;Bezinfekcnost&quot; = 0 OR &quot;Prihlasky&quot;.&quot;Bezinfekcnost&quot; IS NULL) AND &quot;Prihlasky&quot;.&quot;Stav&quot; NOT IN (&apos;STORNO&apos;, &apos;NAHRADNIK&apos;)',
            'WHERE (COALESCE(&quot;Prihlasky&quot;.&quot;Bezinfekcnost&quot;, 0) = 0 AND COALESCE(&quot;Deti&quot;.&quot;Bezinfekcnost&quot;, 0) = 0) AND &quot;Prihlasky&quot;.&quot;Stav&quot; NOT IN (&apos;STORNO&apos;, &apos;NAHRADNIK&apos;)'
        )

        # Q9_Rodice_Dle_Turnusu: vyloučení NAHRADNIK
        cx = cx.replace(
            'db:name="Q9_Rodice_Dle_Turnusu" db:command="SELECT DISTINCT &quot;Akce&quot;.&quot;Nazev&quot; AS &quot;Nazev_Akce&quot;, &quot;Akce&quot;.&quot;Datum_Od&quot;, &quot;Akce&quot;.&quot;Datum_Do&quot;, &quot;Zakaznici&quot;.&quot;Prijmeni&quot;, &quot;Zakaznici&quot;.&quot;Jmeno&quot;, &quot;Zakaznici&quot;.&quot;Email&quot;, &quot;Zakaznici&quot;.&quot;Telefon&quot;, &quot;Zakaznici&quot;.&quot;Ulice_CP&quot;, &quot;Zakaznici&quot;.&quot;Mesto&quot;, &quot;Zakaznici&quot;.&quot;PSC&quot; FROM &quot;Prihlasky&quot; JOIN &quot;Akce&quot; ON &quot;Prihlasky&quot;.&quot;ID_Akce&quot; = &quot;Akce&quot;.&quot;ID_Akce&quot; JOIN &quot;Zakaznici&quot; ON &quot;Prihlasky&quot;.&quot;ID_Zakaznika&quot; = &quot;Zakaznici&quot;.&quot;ID_Zakaznika&quot; WHERE &quot;Prihlasky&quot;.&quot;Stav&quot; &lt;&gt; &apos;STORNO&apos; ORDER BY &quot;Akce&quot;.&quot;Datum_Od&quot;, &quot;Akce&quot;.&quot;Nazev&quot;, &quot;Zakaznici&quot;.&quot;Prijmeni&quot;"',
            'db:name="Q9_Rodice_Dle_Turnusu" db:command="SELECT DISTINCT &quot;Akce&quot;.&quot;Nazev&quot; AS &quot;Nazev_Akce&quot;, &quot;Akce&quot;.&quot;Datum_Od&quot;, &quot;Akce&quot;.&quot;Datum_Do&quot;, &quot;Zakaznici&quot;.&quot;Prijmeni&quot;, &quot;Zakaznici&quot;.&quot;Jmeno&quot;, &quot;Zakaznici&quot;.&quot;Email&quot;, &quot;Zakaznici&quot;.&quot;Telefon&quot;, &quot;Zakaznici&quot;.&quot;Ulice_CP&quot;, &quot;Zakaznici&quot;.&quot;Mesto&quot;, &quot;Zakaznici&quot;.&quot;PSC&quot; FROM &quot;Prihlasky&quot; JOIN &quot;Akce&quot; ON &quot;Prihlasky&quot;.&quot;ID_Akce&quot; = &quot;Akce&quot;.&quot;ID_Akce&quot; JOIN &quot;Zakaznici&quot; ON &quot;Prihlasky&quot;.&quot;ID_Zakaznika&quot; = &quot;Zakaznici&quot;.&quot;ID_Zakaznika&quot; WHERE &quot;Prihlasky&quot;.&quot;Stav&quot; NOT IN (&apos;STORNO&apos;, &apos;NAHRADNIK&apos;) ORDER BY &quot;Akce&quot;.&quot;Datum_Od&quot;, &quot;Akce&quot;.&quot;Nazev&quot;, &quot;Zakaznici&quot;.&quot;Prijmeni&quot;"'
        )

        with open(cx_path, "w", encoding="utf-8") as f:
            f.write(cx)
        print("  ✓ Dotazy v content.xml byly aktualizovány.")

        # Zabalení zpět do archivu ODB
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
    p1 = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base/Šťastný_statek.odb"
    p2 = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun/Stastny_statek.odb"
    
    ok1 = patch_odb(p1)
    ok2 = patch_odb(p2)
    
    if ok1 and ok2:
        print("\nÚSPĚCH: Obě databáze byly opraveny a synchronizovány!")
    else:
        print("\nCHYBA: Některá databáze nebyla opravena!")
        sys.exit(1)
