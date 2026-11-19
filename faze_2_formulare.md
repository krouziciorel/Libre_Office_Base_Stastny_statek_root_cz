# Fáze 2 – Formuláře pro správu dat

Tvoříme 5 formulářů v tomto pořadí (od nejjednodušších po složitější):

| # | Formulář | Popis |
|---|----------|-------|
| F1 | Nastavení firmy | Vaše firemní údaje (dodavatel na fakturách) |
| F2 | Zákazníci a děti | Hlavní adresář: rodiče + podformulář dětí |
| F3 | Praktikanti | Evidence praktikantů |
| F4 | Akce a turnusy | Přehled akcí + přiřazení praktikantů |
| F5+F6 | Přihlášky a faktury | Přihlášky s podformulářem faktur |

---

> [!IMPORTANT]
> **DŮLEŽITÁ UPOZORNĚNÍ PRO NASTAVOVÁNÍ LIST BOXŮ (ROZBALOVACÍCH SEZNAMŮ):**
> 
> 1. **Vázané pole (Bound column) je indexováno od 0!**
>    V LibreOffice Base se sloupce ve zdroji SQL dotazu číslují od nuly. 
>    - `0` = první sloupec (který se zobrazuje uživateli)
>    - `1` = druhý sloupec (který obsahuje ID a ukládá se do databáze)
>    - V návodu níže proto vždy nastavujte vlastnost **Vázané pole** na **1** (namísto původně uváděného 2).
> 
> 2. **SQL dotaz vkládejte jako JEDINÝ ŘÁDEK!**
>    Při vkládání SQL dotazu do pole vlastností **Zdroj seznamu (List source)** se ujistěte, že je dotaz zapsán na jednom řádku (bez zalomení řádků). Pokud do textového pole vlastností vložíte víceřádkový text, LibreOffice Base tiše zkopíruje pouze první řádek a zbytek (např. klauzule `FROM`, `WHERE`, `ORDER BY`) zahodí, což způsobí chybu syntaxe SQL při spuštění formuláře.

---

## F1 – Nastavení firmy (Dodavatele)

Tento formulář slouží k zadání Vašich firemních údajů, které se automaticky
tisknou na každé faktuře.

### Postup:
1. V levém panelu klikněte na **Formuláře**
2. Nahoře zvolte **Použít průvodce k vytvoření formuláře...**

**Průvodce – krok 1 (Výběr polí):**
- Tabulka/dotaz: vyberte **Tabulka: Dodavatele**
- Přehoďte do formuláře tato pole (dvojitou šipkou `>>`):
  `ID_Dodavatele`, `Nazev_Firmy`, `Jmeno`, `Prijmeni`, `ICO`, `DIC`,
  `Ulice_CP`, `Mesto`, `PSC`, `Telefon`, `Email`, `Web`,
  `Banka`, `Cislo_Uctu`, `IBAN`, `Logo_Cesta`
- Klikněte **Další**

**Průvodce – krok 2 (Podformulář):**
- Podformulář: **Ne** → Klikněte **Další** (přeskočte krok 3)

**Průvodce – krok 5 (Rozvržení):**
- Zvolte: **Sloupce – popisky zarovnány vlevo**
- Orientace: Výška
- Klikněte **Další**

**Průvodce – krok 6 (Vytvořit formulář):**
- Název: `F1 - Nastavení firmy`
- Volba: **Pracovat s formulářem**
- Klikněte **Dokončit**

Formulář se otevře s údaji Šťastného statku z testovacích dat. ✅

> [!TIP]
> Tento formulář budete potřebovat pouze jednou (pro zadání svých reálných
> údajů). Pokud chcete, můžete ho kdykoliv otevřít a aktualizovat IČO,
> číslo účtu, IBAN nebo logo.

---

## F2 – Zákazníci a děti ⭐ (nejdůležitější formulář)

Hlavní adresář: horní část = zákazník/rodič, dolní část = jeho děti.

### Postup:
1. V levém panelu klikněte na **Formuláře**
2. Nahoře zvolte **Použít průvodce k vytvoření formuláře...**

**Průvodce – krok 1 (Výběr polí hlavního formuláře):**
- Tabulka/dotaz: vyberte **Tabulka: Zakaznici**
- Přehoďte tato pole v pořadí:
  `Jmeno`, `Prijmeni`, `Telefon`, `Email`,
  `Ulice_CP`, `Mesto`, `PSC`, `ICO`, `DIC`, `Poznamka`
  *(pole `ID_Zakaznika` přeskočte – generuje se automaticky)*
- Klikněte **Další**

**Průvodce – krok 2 (Podformulář):**
- Zaškrtněte: **Přidat podformulář** ✅
- Vyberte: **Podformulář založený na existující relaci**
- V seznamu relací označte: **Deti** (nebo FK_Deti_Rodic)
- Klikněte **Další**

**Průvodce – krok 3 (Pole podformuláře):**
- Přehoďte tato pole dítěte (v tomto pořadí):
  `Jmeno`, `Prijmeni`, `Datum_Narozeni`,
  `Zdravotni_Pojistovna`, `Cislo_Pojistky`,
  `Urazove_Pojisteni`, `Zdravotni_Omezeni`,
  `Bezinfekcnost`, `Datum_Bezinf`, `Poznamka`
  *(pole `ID_Ditete` a `ID_Rodic` přeskočte)*
- Klikněte **Další**

**Průvodce – krok 4 (Způsob zadávání dat):**
- Ponechte výchozí nastavení
- Klikněte **Další**

**Průvodce – krok 5 (Rozvržení):**
- Hlavní formulář: **Sloupce – popisky zarovnány vlevo**
- Podformulář (děti): **Jako sešit dat** (tabulkové zobrazení)
- Orientace: Výška
- Klikněte **Další**

**Průvodce – krok 6 (Vytvořit formulář):**
- Název: `F2 - Zákazníci a děti`
- Volba: **Pracovat s formulářem**
- Klikněte **Dokončit**

### Ověření:
Po otevření formuláře uvidíte Pavla Nováka (zákazník č. 1). Dole v tabulce
by se měl zobrazit **Adam Novák** (jeho dítě). Přepínáním pomocí šipek
v navigační liště (dole) přejdete na Hanu Batelkovou – dole uvidíte Terezu. ✅

> [!IMPORTANT]
> Pole `Urazove_Pojisteni` a `Bezinfekcnost` zobrazují hodnoty 0/1.
> V pozdější fázi je nahradíme zaškrtávacími poli (checkbox) – to uděláme
> při úpravě formuláře v návrhovém zobrazení.

---

## F3 – Praktikanti

### Postup:
1. Průvodce → **Tabulka: Praktikanti**
2. Přehoďte všechna pole kromě `ID_Praktikanta`:
   `Jmeno`, `Prijmeni`, `Datum_Narozeni`, `Telefon`, `Email`,
   `Ulice_CP`, `Mesto`, `PSC`, `Poznamka`
3. Žádný podformulář
4. Rozvržení: **Sloupce – popisky zarovnány vlevo**
5. Název: `F3 - Praktikanti`
6. **Dokončit**

---

## F4 – Akce a turnusy (s přiřazením praktikantů)

### Postup:
1. Průvodce → **Tabulka: Akce**
2. Přehoďte tato pole:
   `Typ_Akce`, `Nazev`, `Datum_Od`, `Datum_Do`, `Kapacita`,
   `Cena_Celkem`, `Zalohova_Castka`, `Zalohova_Spl`,
   `Poznamka`, `Aktivni`
3. **Přidat podformulář** → relace: **Praktikanti_Akce**

**Pole podformuláře Praktikanti_Akce:**
- Přehoďte: `ID_Praktikanta`
- Klikněte **Další**

4. Rozvržení hlavního formuláře: **Sloupce – popisky zarovnány vlevo**
5. Rozvržení podformuláře: **Jako sešit dat**
6. Název: `F4 - Akce a turnusy`
7. **Dokončit**

> [!NOTE]
> Podformulář praktikantů zatím ukazuje pouze ID praktikanta. V dalším kroku
> (úprava návrhu formuláře) nahradíme toto číslo rozbalovacím seznamem
> (List Box) se jménem praktikanta.

### Úprava podformuláře – rozbalovací seznam praktikantů:

1. V levém panelu klikněte pravým tlačítkem na `F4 - Akce a turnusy`
   → **Upravit**
2. Klikněte do oblasti podformuláře na pole s `ID_Praktikanta`
3. Klikněte na pole **pravým tlačítkem** → **Nahradit ovládací prvek** →
   **List Box**
4. Klikněte pravým tlačítkem na nový List Box → **Vlastnosti ovládacího prvku**
5. Záložka **Data**:
   - Typ zdroje seznamu: **SQL**
   - Zdroj seznamu: `SELECT "Jmeno" || ' ' || "Prijmeni", "ID_Praktikanta" FROM "Praktikanti" ORDER BY "Prijmeni"`
   - Vázané pole: **1** (druhý sloupec = ID, indexováno od 0)
6. Záložka **Obecné** → Rozevírací seznam: **Ano**
7. Zavřít vlastnosti → uložit formulář

---

## F5 + F6 – Přihlášky a faktury ⭐

Nejsložitější formulář: hlavní část = přihláška, dolní část = faktury
k přihlášce.

### Postup:
1. Průvodce → **Tabulka: Prihlasky**
2. Přehoďte pole přihlášky:
   `ID_Akce`, `ID_Zakaznika`, `ID_Ditete`,
   `Datum_Prihlasky`, `Stav`, `Variabilni_Symbol`,
   `Cena_Celkem`, `Poznamka`
3. **Přidat podformulář** → relace: **Faktury** (nebo FK_Fakt_Prih)

**Pole podformuláře Faktury:**
- Přehoďte: `Typ_Faktury`, `Cislo_Faktury`, `Castka`,
  `Castka_Zaplaceno`, `Datum_Vystaveni`, `Datum_Splatnosti`,
  `Datum_Zaplaceno`, `Uhrazeno`, `Variabilni_Symbol`, `Poznamka`

4. Rozvržení hlavního formuláře: **Sloupce – popisky zarovnány vlevo**
5. Rozvržení podformuláře: **Jako sešit dat**
6. Název: `F5 - Přihlášky a faktury`
7. **Dokončit**

### Úprava – rozbalovací seznam pro výběr akce, zákazníka a dítěte:

Po dokončení průvodce otevřete formulář v úpravách (pravé tlačítko →
**Upravit**) a nahraďte tři číselná pole (`ID_Akce`, `ID_Zakaznika`,
`ID_Ditete`) rozbalovacími seznamy:

**ID_Akce → List Box „Akce":**
```sql
SELECT "Nazev" || ' (' || "Typ_Akce" || ')', "ID_Akce"
FROM "Akce"
WHERE "Aktivni" = 1
ORDER BY "Datum_Od" DESC
```
Vázané pole: **1** (vkládejte dotaz bez zalomení řádků jako jeden řádek: `SELECT "Nazev" || ' (' || "Typ_Akce" || ')', "ID_Akce" FROM "Akce" WHERE "Aktivni" = 1 ORDER BY "Datum_Od" DESC`)

**ID_Zakaznika → List Box „Zákazník (rodič)":**
```sql
SELECT "Prijmeni" || ' ' || "Jmeno", "ID_Zakaznika"
FROM "Zakaznici"
ORDER BY "Prijmeni"
```
Vázané pole: **1** (vkládejte dotaz bez zalomení řádků: `SELECT "Prijmeni" || ' ' || "Jmeno", "ID_Zakaznika" FROM "Zakaznici" ORDER BY "Prijmeni"`)

**ID_Ditete → List Box „Dítě (volitelné)“:**
```sql
SELECT "Deti"."Prijmeni" || ' ' || "Deti"."Jmeno" || ' (rodič: ' || "Zakaznici"."Prijmeni" || ' ' || "Zakaznici"."Jmeno" || ')', "Deti"."ID_Ditete"
FROM "Deti"
JOIN "Zakaznici" ON "Deti"."ID_Rodic" = "Zakaznici"."ID_Zakaznika"
ORDER BY "Deti"."Prijmeni"
```
Vázané pole: **1**, Rozevírací seznam: **Ano** (vkládejte dotaz bez zalomení řádků: `SELECT "Deti"."Prijmeni" || ' ' || "Deti"."Jmeno" || ' (rodič: ' || "Zakaznici"."Prijmeni" || ' ' || "Zakaznici"."Jmeno" || ')', "Deti"."ID_Ditete" FROM "Deti" JOIN "Zakaznici" ON "Deti"."ID_Rodic" = "Zakaznici"."ID_Zakaznika" ORDER BY "Deti"."Prijmeni"`)

---

## F7 – Dokumenty (podformulář v F2 a F3)

Tento podformulář slouží k evidování souborů a dokumentů (např. naskenovaná přihláška, bezinfekčnost, lékařský posudek, průkaz pojištěnce) u dětí i praktikantů. Dokumenty jsou uloženy na disku a v databázi evidujeme pouze cestu k nim.

### A. Přidání dokumentů k dětem (ve formuláři F2)

1. V hlavním okně Base klikněte pravým tlačítkem na `F2 - Zákazníci a děti` → **Upravit** (Designové zobrazení).
2. Na panelu nástrojů klikněte na ikonu **Navigátor formuláře** (Form Navigator - obvykle ikona se složkami a kompasem na spodní nebo boční liště).
3. V okně Navigátoru najděte hlavní formulář `MainForm` a rozklikněte jej. Pod ním uvidíte podformulář `SubForm` (ten odpovídá tabulce dětí).
4. Klikněte pravým tlačítkem na **`SubForm`** → **Nový → Formulář**. Pojmenujte tento nový pod-podformulář jako **`Dokumenty_Ditete`**.
5. Klikněte pravým tlačítkem na **`Dokumenty_Ditete`** → **Vlastnosti** (Properties):
   - Záložka **Data**:
     - Typ obsahu: **SQL příkaz**
     - Zdroj dat: `SELECT * FROM "Dokumenty" WHERE "Typ_Osoby" = 'DITE'`
     - Propojit od (Link Master Fields): `ID_Ditete`
     - Propojit do (Link Detail Fields): `ID_Osoby`
     - Povolit přidání/úpravy/mazání: **Ano**
   - Zavřete okno vlastností.

#### Vytvoření tabulkového rozvržení dokumentů:
1. Na levém panelu nástrojů klikněte na prvek **Sešit dat** (Table Control / Tabulkové zobrazení).
2. Nakreslete obdélník v dolní části formuláře (např. vedle nebo pod tabulku dětí).
3. Spustí se průvodce elementem. Ujistěte se, že jako zdrojový formulář je vybrán `Dokumenty_Ditete`.
4. Přehoďte do tabulky tato pole: `Typ_Dokumentu`, `Nazev`, `Cesta_Souboru`, `Datum_Vlozeni`, `Poznamka` a dokončete průvodce.
5. Upravte sloupec **Typ_Dokumentu** na rozbalovací seznam:
   - Klikněte pravým tlačítkem na záhlaví sloupce `Typ_Dokumentu` v nové tabulce → **Nahradit za → Seznam** (List Box).
   - Klikněte na něj znovu pravým tlačítkem → **Sloupec...** (Properties).
   - Záložka **Data**:
     - Typ zdroje seznamu: **Seznam hodnot** (Valuelist)
     - Zdroj seznamu: zadejte na samostatné řádky (stisknutím Shift+Enter):
       `PRIHLASKA`
       `LEKAR`
       `BEZINFEKCNOST`
       `POJISTOVNA`
       `ZDRAVOT_OMEZENI`
       `JINE`
     - Vázané pole: **0**
   - Zavřete vlastnosti sloupce.

#### Automatické nastavování Typu osoby (skryté pole):
Musíme zajistit, aby se při přidání nového dokumentu automaticky uložila hodnota `DITE` do sloupce `Typ_Osoby`.
1. V okně **Navigátoru formuláře** klikněte pravým tlačítkem na **`Dokumenty_Ditete`** → **Nový → Skrytý ovládací prvek**.
2. Pojmenujte ho jako `txtTypOsoby`.
3. Klikněte na něj pravým tlačítkem → **Vlastnosti**:
   - Záložka **Obecné**:
     - Výchozí hodnota (Default value): `DITE`
   - Záložka **Data**:
     - Datové pole (Data field): `Typ_Osoby`
   - Zavřete vlastnosti.

Uložte formulář F2 a zavřete jej. ✅

---

### B. Přidání dokumentů k praktikantům (ve formuláři F3)

Postup je velmi podobný, ale dokumenty se vážou přímo na praktikanta.

1. Pravým tlačítkem klikněte na `F3 - Praktikanti` → **Upravit**.
2. Otevřete **Navigátor formuláře**.
3. Klikněte pravým tlačítkem na **`MainForm`** (odpovídá tabulce `Praktikanti`) → **Nový → Formulář**. Pojmenujte jej jako **`Dokumenty_Praktikanta`**.
4. Klikněte pravým tlačítkem na **`Dokumenty_Praktikanta`** → **Vlastnosti**:
   - Záložka **Data**:
     - Typ obsahu: **SQL příkaz**
     - Zdroj dat: `SELECT * FROM "Dokumenty" WHERE "Typ_Osoby" = 'PRAKTIKANT'`
     - Propojit od (Link Master Fields): `ID_Praktikanta`
     - Propojit do (Link Detail Fields): `ID_Osoby`
5. Vytvořte pod tabulku praktikanta prvek **Sešit dat** (Table Control) pro `Dokumenty_Praktikanta` s poli: `Typ_Dokumentu`, `Nazev`, `Cesta_Souboru`, `Datum_Vlozeni`, `Poznamka`.
6. Nahraďte sloupec `Typ_Dokumentu` za **Seznam** (List Box) se stejnými hodnotami.
7. V Navigátoru klikněte pravým tlačítkem na **`Dokumenty_Praktikanta`** → **Nový → Skrytý ovládací prvek**:
   - Název: `txtTypOsoby`
   - Výchozí hodnota: `PRAKTIKANT`
   - Datové pole: `Typ_Osoby`

Uložte formulář F3 a zavřete jej. ✅

---

## Ověření po dokončení všech formulářů

Otevřete **F5 - Přihlášky a faktury** a ověřte:

1. V rozbalovacím seznamu Akce vidíte 5 akcí ✅
2. Přepínáním přihlášek (šipky dole) vidíte různé zákazníky ✅
3. U přihlášky č. 3 (Dětský víkend) se dole v tabulce faktur zobrazují
   dvě faktury: záloha (FAK-2026-004) a doplatek (FAK-2026-005) ✅
4. U přihlášky č. 1 (Vyjížďka) – dole je jen jedna faktura ✅

---

## Jakmile formuláře fungují → dejte vědět

Přejdeme na **Fázi 3 – Dotazy** (Q1–Q10), které připraví data pro
tiskové formuláře přihlášek a faktur.
