# Systém evidence a fakturace táborů – Šťastný statek

Komplexní databázový a evidenční systém postavený na LibreOffice Base (vestavěný Firebird), LibreOffice Calc a Pythonu.

## 📁 Struktura projektu

- `Stastny_statek.odb` – Hlavní databázový soubor (tabulky, formuláře, dotazy, Basic makra)
- `Sablony/` – Šablony pro generování zálohových a doplatkových faktur v LibreOffice Calc (`.ods`)
- `Dokumenty/` – Vygenerované faktury (ODS, PDF), exporty sestav a QR kódy
- `scripts/` – Python skripty pro generování QR kódů plateb (SPAYD standard) a testovacích faktur
- `SQL/` – SQL dotazy a struktury pohledů
- `schema.sql` – Kompletní DDL schéma databáze
- `zalohovat.sh` – Skript pro zálohování celého systému do složky `ZAL/`
- `uzivatelska_dokumentace.md` – Uživatelská příručka a postup práce pro obsluhu
- `programatorska_dokumentace.md` – Technická dokumentace pro vývojáře a správce

## 📖 Dokumentace

Podrobné informace naleznete v přiložených dokumentech:
- [Uživatelská dokumentace](uzivatelska_dokumentace.md)
- [Programátorská a administrátorská dokumentace](programatorska_dokumentace.md)
