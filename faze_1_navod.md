# Fáze 1 – Vložení tabulek a testovacích dat do LO Base

## Příprava

Otevřete soubor [`Šťastný_statek.odb`](file:///home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base/Šťastný_statek.odb)
v LibreOffice Base.

Soubory ke zkopírování jsou připraveny:
- [`schema.sql`](file:///home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base/schema.sql) – 9 tabulek
- [`testovaci_data.sql`](file:///home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base/testovaci_data.sql) – testovací záznamy

---

## Krok 1 – Vložení tabulek (schema.sql)

Otevřete v LO Base: **Nástroje → SQL...**

Otevřete vedle `schema.sql` v textovém editoru. Pak **vkládejte každý blok zvlášť** – vždy:
1. zkopírujte blok (bez řádku s pomlčkami `-- BLOK x`)
2. vložte do okna SQL
3. klikněte **Provést**
4. ve stavovém řádku se zobrazí: *„Příkaz se úspěšně provedl"*
5. obsah okna smažte a vložte další blok

### Pořadí bloků (nutno dodržet kvůli cizím klíčům):

| # | Tabulka | Závisí na |
|---|---------|-----------|
| 1 | `Dodavatele` | – |
| 2 | `Zakaznici` | – |
| 3 | `Deti` | Zakaznici |
| 4 | `Praktikanti` | – |
| 5 | `Akce` | – |
| 6 | `Praktikanti_Akce` | Praktikanti, Akce |
| 7 | `Prihlasky` | Akce, Zakaznici, Deti |
| 8 | `Faktury` | Prihlasky |
| 9 | `Dokumenty` | Prihlasky |

Po vložení všech 9 bloků: **Zobrazit → Obnovit tabulky**

V levém panelu byste měl vidět 9 tabulek. ✅

---

## Krok 2 – Vložení testovacích dat (testovaci_data.sql)

Stejným způsobem vkládejte v `Nástroje → SQL` každý `INSERT INTO ...` zvlášť.

Pořadí vkládání (nutno dodržet):
1. `Dodavatele` (1 záznam)
2. `Zakaznici` (5 záznamů)
3. `Deti` (3 záznamy)
4. `Praktikanti` (2 záznamy)
5. `Akce` (5 záznamů)
6. `Praktikanti_Akce` (3 záznamy)
7. `Prihlasky` (5 záznamů)
8. `Faktury` (8 záznamů)
9. `Dokumenty` (2 záznamy)

---

## Přehled testovacích dat

### Zákazníci / rodiče
| ID | Jméno | Příjmení | Role |
|----|-------|----------|------|
| 1 | Pavel | Novák | Rodič Adama |
| 2 | Hana | Batelková | Rodič Terezy |
| 3 | Tomáš | Brázdův | Rodič Markéty |
| 4 | Lukáš | Horák | Dospělý – vyjížďka |
| 5 | Petra | Krejčová | Dospělý – balíček |

### Děti
| ID | Jméno | Příjmení | Nar. | Rodič (ID) | Pojištění |
|----|-------|----------|------|-----------|-----------|
| 1 | Adam | Novák | 14. 5. 2012 | 1 | ✅ |
| 2 | Tereza | Batelková | 22. 4. 2010 | 2 | ❌ → v seznamu Kooperativa |
| 3 | Markéta | Brázdová | 3. 9. 2011 | 3 | ✅ |

### Přihlášky a variabilní symboly
| Přihláška | Akce | Zákazník | Dítě | Var. symbol |
|-----------|------|----------|------|-------------|
| 1 | Vyjížďka | Horák | – | 00012026 |
| 2 | Balíček 1D | Krejčová | – | 00022026 |
| 3 | Dětský víkend | Novák | Adam (14.05.2012) | **140520122026** |
| 4 | Letní tábor | Batelková | Tereza (22.04.2010) | **220420102026** |
| 5 | Podzimní prázd. | Brázdův | Markéta (03.09.2011) | **030920112026** |

> [!NOTE]
> Variabilní symbol pro dětské akce: `DDMMYYYY` (datum nar. dítěte) + `YYYY` (rok přihlášení).
> Pro vyjížďky/balíčky (bez dítěte): pořadové číslo + rok (bude upřesněno makrem M1).

### Faktury
| # | Typ | Faktura č. | Částka | Uhrazeno |
|---|-----|-----------|--------|---------|
| 1 | Doplatková | FAK-2026-001 | 800 Kč | ❌ |
| 2 | Zálohová | FAK-2026-002 | 1 000 Kč | ❌ |
| 3 | Doplatková | FAK-2026-003 | 1 500 Kč | ❌ |
| 4 | Zálohová | FAK-2026-004 | 1 000 Kč | ✅ |
| 5 | Doplatková | FAK-2026-005 | 2 200 Kč | ❌ |
| 6 | Zálohová | FAK-2026-006 | 3 000 Kč | ✅ |
| 7 | Doplatková | FAK-2026-007 | 6 800 Kč | ❌ |
| 8 | Zálohová | FAK-2026-008 | 1 500 Kč | ❌ |

---

## Co ověřit po vložení dat

Spusťte tyto dotazy v **Nástroje → SQL** pro ověření:

```sql
SELECT COUNT(*) FROM "Zakaznici"
```
→ má vrátit **5**

```sql
SELECT COUNT(*) FROM "Faktury"
```
→ má vrátit **8**

```sql
SELECT "Jmeno", "Prijmeni", "Datum_Narozeni"
FROM "Deti"
WHERE "Urazove_Pojisteni" = 0
```
→ má vrátit **Tereza Batelková** (chybí pojištění → půjde do seznamu Kooperativa)

---

## Adresářová struktura pro dokumenty

Prosím vytvořte ručně tuto strukturu složek (budou do ní ukládány soubory):

```
/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base/
├── Dokumenty/
│   ├── Deti/
│   │   ├── Novak_Adam/
│   │   ├── Batelkova_Tereza/
│   │   └── Brazdova_Marketa/
│   ├── Praktikanti/
│   │   ├── Mala_Eliska/
│   │   └── Vesely_Ondrej/
│   └── Faktury/
├── Sablony/
└── SQL/
```

---

## Po úspěšném vložení

Jakmile budou tabulky a data v pořádku, přejdeme na **Fázi 2: Formuláře**.

Začneme formulářem **F2 – Zákazníci a děti** (hlavní formulář + podformulář dětí),
který bude sloužit jako ústřední vstupní bod pro správu osob.
