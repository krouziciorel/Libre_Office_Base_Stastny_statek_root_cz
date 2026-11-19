# Analýza: LibreOffice Base Report Builder pro Šťastný statek

> [!IMPORTANT]
> Tato analýza je založena na **přímém prozkoumání obou .odb souborů** (XRechnung_V2608_008.odb i Šťastný_statek.odb), jejich XML struktur a schématu databáze.

---

## 1. Co jsem skutečně zjistil v XRechnung_V2608_008.odb

### 1.1 Ověřená fakta – skutečné objekty Report Builderu

XRechnung_V2608_008 **skutečně obsahuje 7 sestav** registrovaných jako objekty `db:reports` v `content.xml`:

| Název reportu | Adresář | Datový zdroj (view) | Výstupní MIME type |
|---|---|---|---|
| `rpt_Rechnungsausgang_Writer` | `reports/Obj1` | `viw_BerichtRechnungsausgang` | `application/vnd.oasis.opendocument.text` (**Writer**) |
| `rpt_Kontostand_Writer` | `reports/Obj21` | `viw_Kontostand` | `application/vnd.oasis.opendocument.text` (**Writer**) |
| `rpt_Kontostand` | `reports/Obj41` | `viw_Kontostand` | `application/vnd.oasis.opendocument.spreadsheet` (**Calc**) |
| `rpt_Kontostand_Steuer` | `reports/Obj42` | `viw_Kontostand` | `application/vnd.oasis.opendocument.spreadsheet` (**Calc**) |
| `rpt_Lieferung` | `reports/Obj31` | `viw_BerichtLieferung` | (Writer) |
| `rpt_Lieferungseingang` | `reports/Obj71` | `viw_BerichtLieferungseingang` | (Writer) |
| `rpt_Rechnungsausgang` | `reports/Obj51` | `viw_BerichtRechnungsausgang` | `application/vnd.oasis.opendocument.spreadsheet` (**Calc**) |

### 1.2 Klíčový mechanismus – jeden datový zdroj, dva výstupní formáty

Toto je **nejdůležitější zjištění**, potvrzené přímou analýzou XML:

```xml
<!-- rpt_Rechnungsausgang_Writer (Obj1/content.xml) -->
<office:report
    rpt:command-type="table"
    rpt:command="viw_BerichtRechnungsausgang"
    office:mimetype="application/vnd.oasis.opendocument.text"
    office:caption="rpt_Rechnungsausgang_Writer">

<!-- rpt_Rechnungsausgang (Obj51/content.xml) -->
<office:report
    rpt:command-type="table"
    rpt:command="viw_BerichtRechnungsausgang"
    office:mimetype="application/vnd.oasis.opendocument.spreadsheet"
    office:caption="rpt_Rechnungsausgang">
```

**Oba reporty čtou identický view `viw_BerichtRechnungsausgang`.** Jediný rozdíl je atribut `office:mimetype`. LibreOffice při spuštění reportu tento atribut respektuje a otevře výsledek buď ve Writeru (ODT), nebo v Calcu (ODS).

Stejný vzor platí pro `rpt_Kontostand` / `rpt_Kontostand_Writer` – oba čtou `viw_Kontostand`.

### 1.3 Jak je report fyzicky uložen v .odb

Report je ve skutečnosti **vnořený LibreOffice dokument** uložený jako podadresář uvnitř .odb (ZIP) archivu:

```
XRechnung_V2608_008.odb  (ZIP archiv)
 ├── content.xml          ← registrace reportů v db:reports
 ├── reports/
 │    ├── Obj1/           ← rpt_Rechnungsausgang_Writer
 │    │    ├── content.xml  ← layout reportu + rpt:command + office:mimetype
 │    │    ├── styles.xml
 │    │    ├── settings.xml
 │    │    ├── meta.xml
 │    │    └── ObjectReplacements/report  (binární náhled)
 │    ├── Obj51/          ← rpt_Rechnungsausgang (Calc)
 │    └── ...
 └── forms/
      └── ...
```

---

## 2. Technická realita Report Builderu – příležitosti i omezení

### 2.1 Co Report Builder umí dobře

| Schopnost | Popis |
|---|---|
| **Skupiny (groups)** | Řádky lze seskupovat např. podle turnusu, roku, typu akce |
| **Agregace** | Součty, průměry, počty v záhlaví/zápatí skupiny |
| **Podmíněné formátování** | Podmínky přímo v designéru |
| **Výstup Writer (ODT)** | `office:mimetype=".../text"` – dokument Writeru |
| **Výstup Calc (ODS)** | `office:mimetype=".../spreadsheet"` – sešit Calcu |
| **Vnořené dokumenty** | Layout je plnohodnotný LO dokument uvnitř .odb |
| **Filtr z makra** | Lze předat SQL WHERE podmínku přes UNO API (`FilterString`) |

### 2.2 Omezení, která musíte znát

> [!WARNING]
> Tato omezení jsou klíčová pro rozhodnutí o architektuře.

| Omezení | Dopad na Šťastný statek |
|---|---|
| **Vyžaduje Javu** | Report Builder bez JRE nefunguje. Je to potvrzená závislost – bez JRE uvidíte prázdný .odb bez možnosti otvírat/editovat reporty. |
| **Žádné interaktivní dialogy** | Report Builder sám o sobě nemá dialog pro výběr turnusu. Bez makra nelze snadno filtrovat na konkrétní akci. |
| **Složitý layout faktury** | Faktury mají specifický vzhled (logo, adresa, položky, součty DPH). Layout v Report Builderu je pracný pro takovéto nelineární dokumenty. Vaše stávající Calc šablony to zvládají lépe. |
| **Jeden řádek = jeden záznam** | Report Builder generuje jeden výstupní řádek (buňku/odstavec) na jeden řádek z dotazu. Pro faktury s hlavičkou + řádky položek + patičkou je potřeba složité seskupování. |
| **Žádné podmíněné stránkování na zákazníka** | Chcete-li tisk přihlášky jako individuální dokument pro každého táborníka (každý na vlastní stránce), musíte použít skupinování s "page break" nastavením – to jde, ale je pracné. |
| **Editace layoutu v IDE** | Designér reportu je součástí LO Base GUI. Nelze editovat bez otevřeného LO Base s funkční Javou. |

---

## 3. Analýza vašich konkrétních potřeb vůči Report Builderu

### ✅ = Report Builder je vhodný | ⚠️ = jde to, ale s rezervami | ❌ = nedoporučuji

### 3.1 Sestavy (přehledové výstupy)

| Potřeba | Doporučení | Zdůvodnění |
|---|---|---|
| **Seznam táborníků pro turnusy** | ✅ **Vhodné** | Přesně tento případ Report Builder zvládá výborně. Jeden dotaz `Q3_Seznam_Ucastniku` → filtr dle ID_Akce → výstup Calc nebo Writer. |
| **Sestava pro pojišťovnu Kooperativa** | ✅ **Vhodné** | Dotaz `Q4_Kooperativa` (účastníci LT bez úrazového pojištění) je přesně ten typ plochého přehledu, pro který je Report Builder ideální. |
| **Sestava chybějící bezinfekčnost** | ✅ **Vhodné** | Dtto – `Q5_Bez_Bezinfekcnosti`. |
| **Přehled příjmů** | ✅ **Vhodné** | `Q8_Prehled_Prijmu` s agregacemi – Report Builder umí skupiny a součty. |
| **Obsazenost akce** | ✅ **Vhodné** | Jednoduchý souhrnný přehled. |
| **Náhradníci na akce** | ✅ **Vhodné** | Filtr na `Stav = 'NAHRADNIK'` v dotazu. |

### 3.2 Přihlášky (individuální dokumenty)

| Potřeba | Doporučení | Zdůvodnění |
|---|---|---|
| **Přihlášky do Writeru** | ⚠️ **Podmíněně** | Technicky jde (viz XRechnung `rpt_Rechnungsausgang_Writer`). Ale přihláška je formulářový dokument s volnými bloky textu, logem, podpisovými řádky. Report Builder pracuje s fixní mřížkou buněk/odstavců. Vaše stávající `.odt` šablony s makrem jsou pro tento případ **flexibilnější**. |

> [!TIP]
> Přihlášky jako individuální ODT dokument generovaný makrem + Writer šablona je **lepší řešení** než Report Builder. Šablona může mít přesný grafický layout s logem a podpisovými řádky. Report Builder toto neumí snadno.

### 3.3 Faktury

| Potřeba | Doporučení | Zdůvodnění |
|---|---|---|
| **Zálohová faktura** | ❌ **Nedoporučuji Report Builder** | Faktura má složitý layout: záhlaví s adresou + bankovními údaji, tabulka položek (jen 1–2 řádky), patičková součtová sekce, QR kód. Toto je obtížné v Report Builder designéru. Vaše stávající Calc šablony + makro toto zvládají výborně. |
| **Doplatková faktura** | ❌ **Nedoporučuji Report Builder** | Stejný důvod jako u zálohové faktury. |

> [!NOTE]
> XRechnung používá Report Builder pro faktury, protože jeho faktura má **tabulkový charakter** – seznam výstupních dokladů, ne individuální fakturační dokument. Vaše faktura je individuální dokument pro jednoho zákazníka.

### 3.4 Ostatní potřeby

| Potřeba | Doporučení | Zdůvodnění |
|---|---|---|
| **14-denní upozornění rodičů** | ❌ **Nesouvisí s Report Builder** | Toto je e-mailová nebo tisknutelná rozesílka. Report Builder vygeneruje seznam, ale **odeslání e-mailu** nebo tisk adresátů musí řešit makro nebo externí nástroj. Report Builder samo o sobě není poštovní systém. |
| **Evidence náhradníků** | ❌ **Nesouvisí s Report Builder** | Toto je evidenční záležitost (sloupec `Stav = 'NAHRADNIK'` v `Prihlasky`). Report Builder může vytvořit sestavu náhradníků, ale samotná evidence probíhá přes formulář. |
| **Evidence praktikantů** | ❌ **Nesouvisí s Report Builder** | Dtto – evidence probíhá přes formuláře, ne reporty. |

---

## 4. Doporučená architektura pro Šťastný statek

Na základě analýzy navrhuji tento hybridní přístup:

```
ŠŤASTNÝ STATEK – výstupní vrstva
│
├── REPORT BUILDER (Base)
│    ├── S3: rpt_SeznamUcastniku_Calc → seznam táborníků → ODS
│    ├── S4: rpt_SeznamUcastniku_Writer → seznam táborníků → ODT  
│    ├── S6: rpt_Kooperativa → seznam pro pojišťovnu → ODS/ODT
│    ├── S7: rpt_BezBezinfekcnosti → chybějící doklady → ODS
│    ├── S8: rpt_NezaplaceneZalohy → přehled dluhů → ODS
│    ├── S9: rpt_PrehledPrijmu → přehled příjmů → ODS
│    └── S10: rpt_Nahradnici → seznam náhradníků → ODS
│
├── MAKRO + WRITER ŠABLONA
│    ├── M5: TisknoutPrihlaskuPDF() → Prihlaska.odt → PDF
│    └── (zachovat stávající přístup – flexibilnější layout)
│
└── MAKRO + CALC ŠABLONA
     ├── M2: VytvoritZalohovou() → Aktualni_zalohova_faktura_LT.ods
     └── M3: VytvoritDoplatkovou() → Aktualni_doplatkova_faktura_LT.ods
```

### Klíčový bod: filtrování reportu dle turnusu

Standardní Report Builder nemá dialog pro výběr turnusu. Řešení:

```basic
' Makro pro spuštění reportu se zadaným filtrem
Sub SpustitSeznamTaborniku(nIdAkce As Long)
    Dim oDoc As Object
    Dim oReports As Object
    Dim oReport As Object
    
    oDoc = ThisComponent
    oReports = oDoc.getReportDocuments()
    oReport = oReports.getByName("rpt_SeznamUcastniku_Calc")
    
    ' Nastaveni filtru pred spustenim
    oReport.FilterString = """ID_Akce"" = " & nIdAkce
    
    ' Spusteni reportu
    Dim oController As Object
    oController = oDoc.getCurrentController()
    oController.openReport(oReport)
End Sub
```

---

## 5. Porovnání: Report Builder vs. stávající makro přístup

| Kritérium | Report Builder | Makro + šablona |
|---|---|---|
| **Přehledové sestavy** | ✅ Přirozené, grafické IDE | ⚠️ Složitější kód |
| **Individuální faktura** | ⚠️ Pracné, omezené | ✅ Flexibilní šablona |
| **Individuální přihláška** | ⚠️ Omezený layout | ✅ Plný layout v ODT |
| **Podmíněný filtr (výběr turnusu)** | ⚠️ Vyžaduje makro | ✅ Přirozené |
| **Závislost na Javě** | ❌ Vyžaduje JRE | ✅ Bez Javy |
| **Editace layoutu** | ✅ Vizuální IDE | ⚠️ Ruční editace šablony |
| **Skupiny a součty** | ✅ Vestavěné | ⚠️ Programové |
| **Export PDF** | ✅ Přímý | ✅ Přes makro |

---

## 6. Závěr a doporučení

### Co doporučuji převzít z XRechnung

1. **Princip** – jeden SQL dotaz, dva reporty (Calc i Writer)
2. **Mechanismus registrace reportu** v `db:reports` sekci `content.xml`
3. **Atribut `office:mimetype`** jako přepínač výstupního formátu
4. **Vzor pojmenování**: `rpt_NazevSestavy` pro Calc, `rpt_NazevSestavy_Writer` pro Writer

### Co nedoporučuji měnit

1. **Faktury** – stávající Calc šablony + makra jsou lepší
2. **Přihlášky** – stávající Writer šablony + makra jsou flexibilnější
3. **Základní evidenci** – formuláře F1–F6 fungují, není důvod měnit

### Podmínka realizace

> [!CAUTION]
> **Java (JRE) je bezpodmínečně nutná** pro Report Builder. Bez funkčního JRE nelze reporty ani otevřít, ani spustit. Ověřte, zda máte na svém systému nainstalované JRE a zda ho LibreOffice detekuje (`Nástroje → Možnosti → LibreOffice → Java`).

### Doporučený první krok

Vytvořte **jeden testovací report** `rpt_SeznamUcastniku` napojený na `Q3_Seznam_Ucastniku` s výstupem do Calcu. Pokud tento report funguje (vyžaduje Javu!), pak je potvrzeno, že architektura Report Builderu bude fungovat pro vaše přehledové sestavy.

---

## 7. Mapování vašich potřeb na konkrétní reporty

| Vaše potřeba | Typ výstupu | Doporučená technologie | Název objektu |
|---|---|---|---|
| Seznam táborníků pro turnusy | Calc nebo Writer | ✅ Report Builder | `rpt_SeznamUcastniku_Calc` / `rpt_SeznamUcastniku_Writer` |
| Přihlášky DV/LT/PP | PDF přes Writer | ✅ Makro + ODT šablona | `TisknoutPrihlaskuPDF()` |
| Zálohová faktura | PDF přes Calc | ✅ Makro + ODS šablona | `VytvoritZalohovou()` |
| Doplatková faktura | PDF přes Calc | ✅ Makro + ODS šablona | `VytvoritDoplatkovou()` |
| Náhradníci | Calc | ✅ Report Builder | `rpt_Nahradnici` |
| Seznam pro pojišťovnu | Calc | ✅ Report Builder | `rpt_Kooperativa` |
| Chybějící bezinfekčnost | Calc | ✅ Report Builder | `rpt_BezBezinfekcnosti` |
| Nezaplacené zálohy | Calc | ✅ Report Builder | `rpt_NezaplaceneZalohy` |
| Přehled příjmů | Calc | ✅ Report Builder | `rpt_PrehledPrijmu` |
| 14-denní upozornění rodičů | E-mail nebo tisk | ✅ Makro + Report Builder (seznam) | `rpt_Upozorneni_Rodice` |
