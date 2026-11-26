#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generator testovacích dokumentů pro turnus:
"Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027"
Generuje:
 - 5x Přihláška (ODT + PDF)
 - 5x Zálohová faktura (ODS + PDF)
 - 5x Doplatková faktura (ODS + PDF)
 - 1x Kompletní přehled turnusu (ODT + PDF)
"""

import os
import re
import sys
import zipfile
import generate_qr
import subprocess

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SABLONY_DIR = os.path.join(BASE_DIR, "Sablony")
DOK_DIR = os.path.join(BASE_DIR, "Dokumenty")

PRIHLASKY_OUT = os.path.join(DOK_DIR, "Prihlasky")
FAKTURY_OUT = os.path.join(DOK_DIR, "Faktury")
PREHLED_OUT = os.path.join(DOK_DIR, "Prehledy_turnusu")

os.makedirs(PRIHLASKY_OUT, exist_ok=True)
os.makedirs(FAKTURY_OUT, exist_ok=True)
os.makedirs(PREHLED_OUT, exist_ok=True)

# 1. Definice turnusu
TURNUS = {
    "nazev": "Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027",
    "termin": "27. 06. 2027 – 02. 07. 2027",
    "datum_od": "27. 06. 2027",
    "datum_do": "02. 07. 2027",
    "kapacita": 10,
    "cena_celkem": "5 500 Kč",
    "zaloha": "2 000 Kč",
    "doplatek": "3 500 Kč",
    "cena_celkem_num": 5500.00,
    "zaloha_num": 2000.00,
    "doplatek_num": 3500.00,
}

# 2. Definice 2 praktikantů
PRAKTIKANTI = [
    {
        "jmeno": "Klára",
        "prijmeni": "Dvořáková",
        "narozeni": "12. 04. 2006",
        "telefon": "+420 775 111 222",
        "email": "klara.dvorakova@email.cz",
        "adresa": "Dlouhá 45, 460 01 Liberec",
        "role": "Instruktorka jezdectví, oddílová vedoucí",
    },
    {
        "jmeno": "Jan",
        "prijmeni": "Veselý",
        "narozeni": "05. 08. 2005",
        "telefon": "+420 775 333 444",
        "email": "jan.vesely@email.cz",
        "adresa": "Polní 12, 470 01 Česká Lípa",
        "role": "Táborový zdravotník, technické zabezpečení",
    },
]

# 3. Definice 5 táborníků a rodičů
TABORNICI = [
    {
        "dite_jmeno": "Jakub",
        "dite_prijmeni": "Novák",
        "dite_cele": "Jakub Novák",
        "dite_nar": "15. 03. 2015",
        "pojistovna": "VZP",
        "cislo_pojistky": "111222333",
        "zdravotni": "Bez omezení",
        "rodic_jmeno": "Pavel",
        "rodic_prijmeni": "Novák",
        "rodic_cele": "Pavel Novák",
        "rodic_tel": "+420 602 111 222",
        "rodic_email": "novak@email.cz",
        "ulice": "Lipová 5",
        "mesto": "Praha 4",
        "psc": "140 00",
        "vs": "2027000006",
        "fak_zaloha": "FAK-2027-001",
        "fak_doplatek": "FAK-2027-006",
        "stav": "POTVRZEN",
        "is_mother": False,
    },
    {
        "dite_jmeno": "Matěj",
        "dite_prijmeni": "Svoboda",
        "dite_cele": "Matěj Svoboda",
        "dite_nar": "20. 08. 2014",
        "pojistovna": "OZP",
        "cislo_pojistky": "222333444",
        "zdravotni": "Bez omezení",
        "rodic_jmeno": "Jitka",
        "rodic_prijmeni": "Svobodová",
        "rodic_cele": "Jitka Svobodová",
        "rodic_tel": "+420 603 222 333",
        "rodic_email": "svobodova@email.cz",
        "ulice": "Máchova 14",
        "mesto": "Liberec",
        "psc": "460 01",
        "vs": "2027000007",
        "fak_zaloha": "FAK-2027-002",
        "fak_doplatek": "FAK-2027-007",
        "stav": "POTVRZEN",
        "is_mother": True,
    },
    {
        "dite_jmeno": "Aneta",
        "dite_prijmeni": "Černá",
        "dite_cele": "Aneta Černá",
        "dite_nar": "10. 11. 2016",
        "pojistovna": "ZPMV",
        "cislo_pojistky": "333444555",
        "zdravotni": "Alergie na pyl a prach",
        "rodic_jmeno": "Martin",
        "rodic_prijmeni": "Černý",
        "rodic_cele": "Martin Černý",
        "rodic_tel": "+420 604 333 444",
        "rodic_email": "cerny@email.cz",
        "ulice": "Horská 8",
        "mesto": "Česká Lípa",
        "psc": "470 01",
        "vs": "2027000008",
        "fak_zaloha": "FAK-2027-003",
        "fak_doplatek": "FAK-2027-008",
        "stav": "POTVRZEN",
        "is_mother": False,
    },
    {
        "dite_jmeno": "Filip",
        "dite_prijmeni": "Kučera",
        "dite_cele": "Filip Kučera",
        "dite_nar": "05. 05. 2013",
        "pojistovna": "ČPZP",
        "cislo_pojistky": "444555666",
        "zdravotni": "Bez omezení",
        "rodic_jmeno": "Lenka",
        "rodic_prijmeni": "Kučerová",
        "rodic_cele": "Lenka Kučerová",
        "rodic_tel": "+420 605 444 555",
        "rodic_email": "kucerova@email.cz",
        "ulice": "Luční 25",
        "mesto": "Nový Bor",
        "psc": "473 01",
        "vs": "2027000009",
        "fak_zaloha": "FAK-2027-004",
        "fak_doplatek": "FAK-2027-009",
        "stav": "POTVRZEN",
        "is_mother": True,
    },
    {
        "dite_jmeno": "Sofie",
        "dite_prijmeni": "Procházková",
        "dite_cele": "Sofie Procházková",
        "dite_nar": "25. 01. 2015",
        "pojistovna": "VZP",
        "cislo_pojistky": "555666777",
        "zdravotni": "Bez omezení",
        "rodic_jmeno": "Tomáš",
        "rodic_prijmeni": "Procházka",
        "rodic_cele": "Tomáš Procházka",
        "rodic_tel": "+420 606 555 666",
        "rodic_email": "prochazka@email.cz",
        "ulice": "Mírové nám. 3",
        "mesto": "Doksy",
        "psc": "472 01",
        "vs": "2027000010",
        "fak_zaloha": "FAK-2027-005",
        "fak_doplatek": "FAK-2027-010",
        "stav": "POTVRZEN",
        "is_mother": False,
    },
]

def convert_to_pdf(input_file, outdir):
    """Převede ODT nebo ODS do PDF pomocí LibreOffice headless v flatpaku."""
    cmd = [
        "flatpak", "run", "org.libreoffice.LibreOffice",
        "--headless", "--convert-to", "pdf",
        "--outdir", outdir,
        input_file
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def generate_prihlaska(child):
    """Vygeneruje ODT a PDF přihlášky z šablony Sablony/Přihláška_LT.odt."""
    tpl = os.path.join(SABLONY_DIR, "Přihláška_LT.odt")
    out_name = f"Prihlaska_{child['dite_prijmeni']}_{child['dite_jmeno']}_LT2027"
    out_odt = os.path.join(PRIHLASKY_OUT, f"{out_name}.odt")
    
    adresa_full = f"{child['ulice']}, {child['psc']} {child['mesto']}"
    poj_full = f"{child['pojistovna']} (č. {child['cislo_pojistky']})"
    
    fields = {
        "PRIHL_DITE_JMENO": child["dite_cele"],
        "PRIHL_DITE_NAROZENI": child["dite_nar"],
        "PRIHL_DITE_ADRESA": adresa_full,
        "PRIHL_DITE_POJISTOVNA": poj_full,
        "PRIHL_DITE_ZDRAVOTNI": child["zdravotni"],
        "PRIHL_RODIC_JMENO": child["rodic_cele"],
        "PRIHL_RODIC_TEL": child["rodic_tel"],
        "PRIHL_RODIC_EMAIL": child["rodic_email"],
        "PRIHL_MATKA_JMENO": child["rodic_cele"] if child["is_mother"] else "",
        "PRIHL_MATKA_TEL": child["rodic_tel"] if child["is_mother"] else "",
        "PRIHL_OTEC_JMENO": child["rodic_cele"] if not child["is_mother"] else "",
        "PRIHL_OTEC_TEL": child["rodic_tel"] if not child["is_mother"] else "",
        "PRIHL_PLAVEC_P": "☒",
        "PRIHL_PLAVEC_C": "☐",
        "PRIHL_PLAVEC_N": "☐",
        "PRIHL_PLATBA_H": "☐",
        "PRIHL_PLATBA_U": "☒",
        "PRIHL_PLATBA_S": "☐",
        "PRIHL_DATUM_DNES": "15. 1. 2027",
        "PRIHL_AKCE_NAZEV": TURNUS["nazev"],
        "PRIHL_AKCE_TERMIN": TURNUS["termin"],
        "PRIHL_ROK": "2027",
        "PRIHL_ZAKAZNIK_N": "☒",
        "PRIHL_ZAKAZNIK_S": "☐",
        "PRIHL_CENA_NOVA": TURNUS["cena_celkem"],
        "PRIHL_CENA_SLEVA": "5 300 Kč",
        "PRIHL_CENA": TURNUS["cena_celkem"],
        "PRIHL_ZALOHA": TURNUS["zaloha"],
        "PRIHL_VS": child["vs"],
        "PRIHL_DATUM": "15. 1. 2027",
    }
    
    with zipfile.ZipFile(tpl, "r") as zin, zipfile.ZipFile(out_odt, "w") as zout:
        for item in zin.infolist():
            if item.filename == "Pictures/QR_Platba.png":
                continue # Přeskočíme starý QR obrázek, nový zapíšeme na konci
            data = zin.read(item.filename)
            if item.filename == "content.xml":
                xml = data.decode("utf-8")
                for k, v in fields.items():
                    # aktualizace deklarace hodnoty
                    xml = re.sub(
                        r'(:string-value=)"[^"]*"(\s+[^>]*:name="' + re.escape(k) + r'")',
                        r'\1"' + v + r'"\2',
                        xml
                    )
                    # aktualizace textu v get tagu
                    xml = re.sub(
                        r'(<([a-zA-Z0-9_]+):user-field-get [^>]*:name="' + re.escape(k) + r'"[^>]*)(?:\/>|>[^<]*<\/\2:user-field-get>)',
                        r'\1>' + v + r'</\2:user-field-get>',
                        xml
                    )
                data = xml.encode("utf-8")
            zout.writestr(item, data)
            
    convert_to_pdf(out_odt, PRIHLASKY_OUT)
    print(f"  [OK] Přihláška: {out_name}.pdf")

def generate_faktura(child, typ="ZALOHOVA"):
    """Vygeneruje ODS a PDF zálohové nebo doplatkové faktury včetně QR platby (SPAYD)."""
    is_zaloha = (typ == "ZALOHOVA")
    tpl_file = "Aktualni_zalohova_faktura_LT.ods" if is_zaloha else "Aktualni_doplatkova_faktura_LT.ods"
    tpl = os.path.join(SABLONY_DIR, tpl_file)
    
    cislo_fak = child["fak_zaloha"] if is_zaloha else child["fak_doplatek"]
    out_name = f"Faktura_{cislo_fak}_{'Zaloha' if is_zaloha else 'Doplatek'}_{child['dite_prijmeni']}"
    out_ods = os.path.join(FAKTURY_OUT, f"{out_name}.ods")
    
    castka_str = "2 000,00 Kč" if is_zaloha else "3 500,00 Kč"
    castka_val = "2000" if is_zaloha else "3500"
    castka_num = 2000.0 if is_zaloha else 3500.0
    splatnost = "15. 2. 2027" if is_zaloha else "15. 6. 2027"
    vystaveni = "15. 1. 2027" if is_zaloha else "15. 5. 2027"
    popis = (
        f"Fakturujeme Vám zálohovou platbu za letní pobytový tábor u koní v termínu {TURNUS['termin']}."
        if is_zaloha else
        f"Fakturujeme Vám doplatek za letní pobytový tábor u koní v termínu {TURNUS['termin']}."
    )
    forma_uhrady = "převodem" if is_zaloha else "hotovost"
    
    # Generování QR kódu SPAYD pro platbu
    iban = "CZ65 0800 0000 0016 5260 8083"
    msg = f"{cislo_fak} {child['dite_prijmeni']}"
    spayd_str = generate_qr.build_spayd(iban, castka_num, child["vs"], msg)
    qr_tmp = os.path.join(FAKTURY_OUT, f"_temp_qr_{cislo_fak}.png")
    generate_qr.generate_qr(spayd_str, qr_tmp, scale=6)
    with open(qr_tmp, "rb") as qrf:
        qr_bytes = qrf.read()
    try:
        os.remove(qr_tmp)
    except OSError:
        pass

    # Rámec pro QR kód v ODS
    qr_frame = (
        '<draw:frame table:end-cell-address="Faktura.D53" table:end-x="0.100cm" table:end-y="0.100cm" '
        'draw:z-index="2" draw:name="QR_Platba" draw:style-name="gr1" draw:text-style-name="P1" '
        'svg:width="3.400cm" svg:height="3.400cm" svg:x="0.100cm" svg:y="0.100cm">'
        '<draw:image xlink:href="Pictures/QR_Platba.png" xlink:type="simple" xlink:show="embed" xlink:actuate="onLoad" draw:mime-type="image/png">'
        '<text:p/></draw:image></draw:frame>'
    )
    
    with zipfile.ZipFile(tpl, "r") as zin, zipfile.ZipFile(out_ods, "w") as zout:
        for item in zin.infolist():
            if item.filename == "Pictures/QR_Platba.png":
                continue # Přeskočíme starý QR obrázek, nový zapíšeme na konci
            data = zin.read(item.filename)
            if item.filename == "META-INF/manifest.xml":
                manifest = data.decode("utf-8")
                qr_entry = '<manifest:file-entry manifest:full-path="Pictures/QR_Platba.png" manifest:media-type="image/png"/>'
                if "Pictures/QR_Platba.png" not in manifest:
                    manifest = manifest.replace("</manifest:manifest>", f"{qr_entry}</manifest:manifest>")
                data = manifest.encode("utf-8")
            elif item.filename == "content.xml":
                xml = data.decode("utf-8")
                
                # Náhrada čísla faktury
                xml = xml.replace("22052001-2025", cislo_fak)
                # Náhrada variabilního symbolu
                xml = xml.replace("220525", child["vs"])
                # Náhrada jména zákazníka
                xml = xml.replace("Iva Batelková", child["rodic_cele"]).replace("Iva Betelková", child["rodic_cele"])
                # Náhrada adresy
                xml = xml.replace("U trati", child["ulice"])
                xml = xml.replace("280 02", child["psc"])
                xml = xml.replace("Kolín", child["mesto"])
                # Náhrada termínu a popisu
                old_desc_z = "Fakturujeme Vám zálohovou platbu za letní pobytový tábor u koní v termínu 9. 8. - 14. 8. 2025"
                old_desc_d = "Fakturujeme Vám zbylou platbu za letní pobytový tábor u koní v termínu 9. 8. - 14. 8. 2025"
                xml = xml.replace(old_desc_z, popis).replace(old_desc_d, popis)
                # Náhrada splatnosti a vystavení
                xml = xml.replace("6. 2. 2025", splatnost).replace("9. 8. 2025", splatnost)
                xml = xml.replace("23. 1. 2025", vystaveni)
                # Náhrada částek
                old_amount = "1\xa0000,00 Kč" if is_zaloha else "2\xa0700,00 Kč"
                old_amount_clean = "1 000,00 Kč" if is_zaloha else "2 700,00 Kč"
                xml = xml.replace(old_amount, castka_str).replace(old_amount_clean, castka_str)
                xml = re.sub(r'office:value="1000"', f'office:value="{castka_val}"', xml)
                xml = re.sub(r'office:value="2700"', f'office:value="{castka_val}"', xml)
                # Forma úhrady
                if not is_zaloha:
                    xml = xml.replace("hotovost", forma_uhrady)
                
                # Vložení nápisu "QR platba" do řádku 43
                target_r43 = '<table:table-row table:style-name="ro2"><table:table-cell table:style-name="ce3"/><table:table-cell table:style-name="ce11"/>'
                repl_r43 = '<table:table-row table:style-name="ro2"><table:table-cell table:style-name="ce3"/><table:table-cell table:style-name="ce11"><text:p text:style-name="P2">QR platba</text:p></table:table-cell>'
                if target_r43 in xml:
                    xml = xml.replace(target_r43, repl_r43, 1)

                # Vložení QR kódu do řádku 44 buňky 1
                target_c1 = '<table:table-cell table:style-name="ce11"/><table:table-cell table:style-name="ce11"><draw:frame'
                repl_c1 = f'<table:table-cell table:style-name="ce11">{qr_frame}</table:table-cell><table:table-cell table:style-name="ce11"><draw:frame'
                if target_c1 in xml:
                    xml = xml.replace(target_c1, repl_c1, 1)
                
                data = xml.encode("utf-8")
            zout.writestr(item, data)
        # Zápis obrázku QR kódu
        zout.writestr("Pictures/QR_Platba.png", qr_bytes)
            
    convert_to_pdf(out_ods, FAKTURY_OUT)
    print(f"  [OK] Faktura s QR platbou ({'záloha' if is_zaloha else 'doplatek'}): {out_name}.pdf")

def generate_turnus_overview():
    """Vygeneruje souhrnný přehled turnusu (Writer ODT + PDF) s hlavičkou, termínem, praktikanty a táborníky."""
    out_name = "Prehled_turnusu_Letni_tabor_2027"
    out_odt = os.path.join(PREHLED_OUT, f"{out_name}.odt")
    
    # Použijeme šablonu Přihláška_LT.odt jako čistou bázi s nastavenými styly a fonty
    tpl = os.path.join(SABLONY_DIR, "Přihláška_LT.odt")
    
    rows_prak_xml = ""
    for i, p in enumerate(PRAKTIKANTI, 1):
        rows_prak_xml += f"""
        <table:table-row>
            <table:table-cell office:value-type="string"><text:p>{i}. {p['jmeno']} {p['prijmeni']}</text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{p['narozeni']}</text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{p['telefon']}</text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{p['email']}</text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{p['role']}</text:p></table:table-cell>
        </table:table-row>
        """

    rows_tab_xml = ""
    for i, t in enumerate(TABORNICI, 1):
        rows_tab_xml += f"""
        <table:table-row>
            <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">{i}. {t['dite_cele']}</text:span></text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{t['dite_nar']}</text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{t['rodic_cele']}</text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{t['rodic_tel']}</text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{t['zdravotni']}</text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{t['stav']}</text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{t['vs']}</text:p></table:table-cell>
        </table:table-row>
        """

    content_body = f"""
    <text:p text:style-name="Title">ŠŤASTNÝ STATEK – PŘEHLED TÁBOROVÉHO TURNUSU</text:p>
    <text:p text:style-name="Subtitle">{TURNUS['nazev']}</text:p>
    <text:p text:style-name="Standard"></text:p>
    
    <table:table table:name="InfoTabulka">
        <table:table-column table:number-columns-repeated="2"/>
        <table:table-row>
            <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Termín turnusu:</text:span></text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>{TURNUS['termin']}</text:p></table:table-cell>
        </table:table-row>
        <table:table-row>
            <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Typ akce:</text:span></text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>Letní tábor u koní (pobytový)</text:p></table:table-cell>
        </table:table-row>
        <table:table-row>
            <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Kapacita a obsazenost:</text:span></text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>Celkem {TURNUS['kapacita']} míst | Přihlášeno: {len(TABORNICI)} dětí | Volných: {TURNUS['kapacita'] - len(TABORNICI)} míst</text:p></table:table-cell>
        </table:table-row>
        <table:table-row>
            <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Cena a záloha:</text:span></text:p></table:table-cell>
            <table:table-cell office:value-type="string"><text:p>Cena: {TURNUS['cena_celkem']} | Záloha: {TURNUS['zaloha']} | Doplatek: {TURNUS['doplatek']}</text:p></table:table-cell>
        </table:table-row>
    </table:table>
    
    <text:p text:style-name="Heading_20_1">1. PŘIŘAZENÍ PRAKTIKANTI A INSTRUKTOŘI TURNUSU ({len(PRAKTIKANTI)})</text:p>
    <table:table table:name="PraktikantiTabulka">
        <table:table-column table:number-columns-repeated="5"/>
        <table:table-header-rows>
            <table:table-row>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Jméno a příjmení</text:span></text:p></table:table-cell>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Datum nar.</text:span></text:p></table:table-cell>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Telefon</text:span></text:p></table:table-cell>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">E-mail</text:span></text:p></table:table-cell>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Role na táboře</text:span></text:p></table:table-cell>
            </table:table-row>
        </table:table-header-rows>
        {rows_prak_xml}
    </table:table>
    
    <text:p text:style-name="Heading_20_1">2. SEZNAM PŘIHLÁŠENÝCH TÁBORNÍKŮ ({len(TABORNICI)})</text:p>
    <table:table table:name="TaborniciTabulka">
        <table:table-column table:number-columns-repeated="7"/>
        <table:table-header-rows>
            <table:table-row>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Táborník (Dítě)</text:span></text:p></table:table-cell>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Datum nar.</text:span></text:p></table:table-cell>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Zákonný zástupce</text:span></text:p></table:table-cell>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Telefon</text:span></text:p></table:table-cell>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Zdravotní poznámka</text:span></text:p></table:table-cell>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Stav</text:span></text:p></table:table-cell>
                <table:table-cell office:value-type="string"><text:p><text:span text:style-name="T_Bold">Var. symbol</text:span></text:p></table:table-cell>
            </table:table-row>
        </table:table-header-rows>
        {rows_tab_xml}
    </table:table>
    
    <text:p text:style-name="Standard"></text:p>
    <text:p text:style-name="Standard">Přehled vygenerován dne 15. 1. 2027 – Šťastný statek, Provodín 211.</text:p>
    """

    with zipfile.ZipFile(tpl, "r") as zin, zipfile.ZipFile(out_odt, "w") as zout:
        for item in zin.infolist():
            if item.filename == "Pictures/QR_Platba.png":
                continue # Přeskočíme starý QR obrázek, nový zapíšeme na konci
            data = zin.read(item.filename)
            if item.filename == "content.xml":
                xml = data.decode("utf-8")
                xml = xml.replace('<ns0:document-content ', '<ns0:document-content xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" ')
                body_match = re.search(r'(<ns0:body>\s*<ns0:text[^>]*>).*?(<\/ns0:text>\s*<\/ns0:body>)', xml, re.DOTALL)
                if body_match:
                    xml = xml[:body_match.start(1)] + body_match.group(1) + content_body + body_match.group(2) + xml[body_match.end(2):]
                data = xml.encode("utf-8")
            zout.writestr(item, data)
            
    convert_to_pdf(out_odt, PREHLED_OUT)
    print(f"  [OK] Přehled turnusu: {out_name}.pdf")

def main():
    print("=" * 60)
    print("Generování testovací sady pro turnus:")
    print(f"  {TURNUS['nazev']}")
    print("=" * 60)
    
    print("\n1. Generování přihlášek (5 dětí):")
    for ch in TABORNICI:
        generate_prihlaska(ch)
        
    print("\n2. Generování zálohových faktur (5 faktur):")
    for ch in TABORNICI:
        generate_faktura(ch, typ="ZALOHOVA")
        
    print("\n3. Generování doplatkových faktur (5 faktur):")
    for ch in TABORNICI:
        generate_faktura(ch, typ="DOPLATKOVA")
        
    print("\n4. Generování souhrnného přehledu turnusu (termín, 2 praktikanti, 5 táborníků):")
    generate_turnus_overview()
    
    print("\n" + "=" * 60)
    print("Všechny dokumenty byly úspěšně vygenerovány!")
    print("=" * 60)

if __name__ == "__main__":
    main()
