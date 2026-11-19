-- ============================================================
-- ŠŤASTNÝ STATEK – Testovací turnus 2027 a kompletní záznamy
-- Akce: "Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027"
-- 2 Praktikanti, 5 Dětí / Rodičů, 5 Přihlášek, 10 Faktur
-- LibreOffice Base / Firebird 3 (embedded)
-- ============================================================

-- 1. Založení nového táborového turnusu
INSERT INTO "Akce"
  ("Typ_Akce", "Nazev", "Datum_Od", "Datum_Do", "Kapacita", "Cena_Celkem", "Zalohova_Castka", "Zalohova_Spl", "Poznamka", "Aktivni")
VALUES
  ('LETNI_TABOR', 'Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027', '2027-06-27', '2027-07-02', 10, 5500.00, 2000.00, '2027-05-15', '1. turnus letního pobytového tábora 2027', 1);

-- 2. Testovací praktikanti (pokud již neexistují)
INSERT INTO "Praktikanti"
  ("Jmeno", "Prijmeni", "Datum_Narozeni", "Telefon", "Email", "Ulice_CP", "Mesto", "PSC", "Poznamka")
VALUES
  ('Klára', 'Dvořáková', '2006-04-12', '+420 775 111 222', 'klara.dvorakova@email.cz', 'Dlouhá 45', 'Liberec', '460 01', 'Zkušená instruktorka jezdectví');

INSERT INTO "Praktikanti"
  ("Jmeno", "Prijmeni", "Datum_Narozeni", "Telefon", "Email", "Ulice_CP", "Mesto", "PSC", "Poznamka")
VALUES
  ('Jan', 'Veselý', '2005-08-05', '+420 775 333 444', 'jan.vesely@email.cz', 'Polní 12', 'Česká Lípa', '470 01', 'Zdravotník tábora');

-- 3. Přiřazení 2 praktikantů k novému turnusu
INSERT INTO "Praktikanti_Akce" ("ID_Praktikanta", "ID_Akce")
SELECT p."ID_Praktikanta", a."ID_Akce"
FROM "Praktikanti" p, "Akce" a
WHERE p."Prijmeni" = 'Dvořáková' AND p."Jmeno" = 'Klára'
  AND a."Nazev" = 'Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027';

INSERT INTO "Praktikanti_Akce" ("ID_Praktikanta", "ID_Akce")
SELECT p."ID_Praktikanta", a."ID_Akce"
FROM "Praktikanti" p, "Akce" a
WHERE p."Prijmeni" = 'Veselý' AND p."Jmeno" = 'Jan'
  AND a."Nazev" = 'Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027';

-- 4. Rodiče (Zákazníci) pro 5 dětí
-- Poznámka: Pavel Novák (ID 1) již v databázi existuje, přidáváme další 4 rodiče
INSERT INTO "Zakaznici"
  ("Jmeno", "Prijmeni", "Telefon", "Email", "Ulice_CP", "Mesto", "PSC")
VALUES
  ('Jitka', 'Svobodová', '+420 603 222 333', 'svobodova@email.cz', 'Máchova 14', 'Liberec', '460 01');

INSERT INTO "Zakaznici"
  ("Jmeno", "Prijmeni", "Telefon", "Email", "Ulice_CP", "Mesto", "PSC")
VALUES
  ('Martin', 'Černý', '+420 604 333 444', 'cerny@email.cz', 'Horská 8', 'Česká Lípa', '470 01');

INSERT INTO "Zakaznici"
  ("Jmeno", "Prijmeni", "Telefon", "Email", "Ulice_CP", "Mesto", "PSC")
VALUES
  ('Lenka', 'Kučerová', '+420 605 444 555', 'kucerova@email.cz', 'Luční 25', 'Nový Bor', '473 01');

INSERT INTO "Zakaznici"
  ("Jmeno", "Prijmeni", "Telefon", "Email", "Ulice_CP", "Mesto", "PSC")
VALUES
  ('Tomáš', 'Procházka', '+420 606 555 666', 'prochazka@email.cz', 'Mírové nám. 3', 'Doksy', '472 01');

-- 5. Pět táborníků (Děti)
-- Dítě 1: Jakub Novák (rodič Pavel Novák, ID 1)
INSERT INTO "Deti"
  ("ID_Rodic", "Jmeno", "Prijmeni", "Datum_Narozeni", "Zdravotni_Pojistovna", "Cislo_Pojistky", "Urazove_Pojisteni", "Bezinfekcnost", "Zdravotni_Omezeni")
SELECT z."ID_Zakaznika", 'Jakub', 'Novák', '2015-03-15', 'VZP', '111222333', 1, 1, 'Bez omezení'
FROM "Zakaznici" z WHERE z."Prijmeni" = 'Novák' AND z."Jmeno" = 'Pavel';

-- Dítě 2: Matěj Svoboda (rodič Jitka Svobodová)
INSERT INTO "Deti"
  ("ID_Rodic", "Jmeno", "Prijmeni", "Datum_Narozeni", "Zdravotni_Pojistovna", "Cislo_Pojistky", "Urazove_Pojisteni", "Bezinfekcnost", "Zdravotni_Omezeni")
SELECT z."ID_Zakaznika", 'Matěj', 'Svoboda', '2014-08-20', 'OZP', '222333444', 1, 1, 'Bez omezení'
FROM "Zakaznici" z WHERE z."Prijmeni" = 'Svobodová' AND z."Jmeno" = 'Jitka';

-- Dítě 3: Aneta Černá (rodič Martin Černý)
INSERT INTO "Deti"
  ("ID_Rodic", "Jmeno", "Prijmeni", "Datum_Narozeni", "Zdravotni_Pojistovna", "Cislo_Pojistky", "Urazove_Pojisteni", "Bezinfekcnost", "Zdravotni_Omezeni")
SELECT z."ID_Zakaznika", 'Aneta', 'Černá', '2016-11-10', 'ZPMV', '333444555', 0, 0, 'Alergie na pyl a prach'
FROM "Zakaznici" z WHERE z."Prijmeni" = 'Černý' AND z."Jmeno" = 'Martin';

-- Dítě 4: Filip Kučera (rodič Lenka Kučerová)
INSERT INTO "Deti"
  ("ID_Rodic", "Jmeno", "Prijmeni", "Datum_Narozeni", "Zdravotni_Pojistovna", "Cislo_Pojistky", "Urazove_Pojisteni", "Bezinfekcnost", "Zdravotni_Omezeni")
SELECT z."ID_Zakaznika", 'Filip', 'Kučera', '2013-05-05', 'ČPZP', '444555666', 1, 1, 'Bez omezení'
FROM "Zakaznici" z WHERE z."Prijmeni" = 'Kučerová' AND z."Jmeno" = 'Lenka';

-- Dítě 5: Sofie Procházková (rodič Tomáš Procházka)
INSERT INTO "Deti"
  ("ID_Rodic", "Jmeno", "Prijmeni", "Datum_Narozeni", "Zdravotni_Pojistovna", "Cislo_Pojistky", "Urazove_Pojisteni", "Bezinfekcnost", "Zdravotni_Omezeni")
SELECT z."ID_Zakaznika", 'Sofie', 'Procházková', '2015-01-25', 'VZP', '555666777', 1, 1, 'Bez omezení'
FROM "Zakaznici" z WHERE z."Prijmeni" = 'Procházka' AND z."Jmeno" = 'Tomáš';

-- 6. Pět přihlášek pro táborníky k turnusu
-- Variabilní symbol: Datum narození (DDMMYYYY) + rok turnusu (2027)
INSERT INTO "Prihlasky"
  ("ID_Akce", "ID_Zakaznika", "ID_Ditete", "Datum_Prihlasky", "Stav", "Variabilni_Symbol", "Cena_Celkem", "Poznamka")
SELECT a."ID_Akce", z."ID_Zakaznika", d."ID_Ditete", '2027-01-15', 'POTVRZEN', '150320152027', 5500.00, 'Zájem o pokročilejší jízdu na koni'
FROM "Akce" a, "Zakaznici" z, "Deti" d
WHERE a."Nazev" = 'Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027'
  AND z."Prijmeni" = 'Novák' AND z."Jmeno" = 'Pavel'
  AND d."Prijmeni" = 'Novák' AND d."Jmeno" = 'Jakub';

INSERT INTO "Prihlasky"
  ("ID_Akce", "ID_Zakaznika", "ID_Ditete", "Datum_Prihlasky", "Stav", "Variabilni_Symbol", "Cena_Celkem", "Poznamka")
SELECT a."ID_Akce", z."ID_Zakaznika", d."ID_Ditete", '2027-01-16', 'POTVRZEN', '200820142027', 5500.00, 'Přijede společně s kamarádem'
FROM "Akce" a, "Zakaznici" z, "Deti" d
WHERE a."Nazev" = 'Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027'
  AND z."Prijmeni" = 'Svobodová' AND z."Jmeno" = 'Jitka'
  AND d."Prijmeni" = 'Svoboda' AND d."Jmeno" = 'Matěj';

INSERT INTO "Prihlasky"
  ("ID_Akce", "ID_Zakaznika", "ID_Ditete", "Datum_Prihlasky", "Stav", "Variabilni_Symbol", "Cena_Celkem", "Poznamka")
SELECT a."ID_Akce", z."ID_Zakaznika", d."ID_Ditete", '2027-01-18', 'POTVRZEN', '101120162027', 5500.00, 'Nutno podávat antihistaminika dle potřeby'
FROM "Akce" a, "Zakaznici" z, "Deti" d
WHERE a."Nazev" = 'Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027'
  AND z."Prijmeni" = 'Černý' AND z."Jmeno" = 'Martin'
  AND d."Prijmeni" = 'Černá' AND d."Jmeno" = 'Aneta';

INSERT INTO "Prihlasky"
  ("ID_Akce", "ID_Zakaznika", "ID_Ditete", "Datum_Prihlasky", "Stav", "Variabilni_Symbol", "Cena_Celkem", "Poznamka")
SELECT a."ID_Akce", z."ID_Zakaznika", d."ID_Ditete", '2027-01-20', 'POTVRZEN', '050520132027', 5500.00, 'Standardní přihláška'
FROM "Akce" a, "Zakaznici" z, "Deti" d
WHERE a."Nazev" = 'Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027'
  AND z."Prijmeni" = 'Kučerová' AND z."Jmeno" = 'Lenka'
  AND d."Prijmeni" = 'Kučera' AND d."Jmeno" = 'Filip';

INSERT INTO "Prihlasky"
  ("ID_Akce", "ID_Zakaznika", "ID_Ditete", "Datum_Prihlasky", "Stav", "Variabilni_Symbol", "Cena_Celkem", "Poznamka")
SELECT a."ID_Akce", z."ID_Zakaznika", d."ID_Ditete", '2027-01-22', 'POTVRZEN', '250120152027', 5500.00, 'Zájem o péči o koně'
FROM "Akce" a, "Zakaznici" z, "Deti" d
WHERE a."Nazev" = 'Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027'
  AND z."Prijmeni" = 'Procházka' AND z."Jmeno" = 'Tomáš'
  AND d."Prijmeni" = 'Procházková' AND d."Jmeno" = 'Sofie';

-- 7. Pět zálohových faktur (po 2 000 Kč)
INSERT INTO "Faktury"
  ("ID_Prihlasky", "Typ_Faktury", "Cislo_Faktury", "Castka", "Castka_Zaplaceno", "Datum_Vystaveni", "Datum_Splatnosti", "Uhrazeno", "Variabilni_Symbol")
SELECT p."ID_Prihlasky", 'ZALOHOVA', 'FAK-2027-001', 2000.00, 2000.00, '2027-01-15', '2027-02-15', 1, p."Variabilni_Symbol"
FROM "Prihlasky" p JOIN "Deti" d ON p."ID_Ditete" = d."ID_Ditete"
WHERE d."Prijmeni" = 'Novák' AND d."Jmeno" = 'Jakub';

INSERT INTO "Faktury"
  ("ID_Prihlasky", "Typ_Faktury", "Cislo_Faktury", "Castka", "Castka_Zaplaceno", "Datum_Vystaveni", "Datum_Splatnosti", "Uhrazeno", "Variabilni_Symbol")
SELECT p."ID_Prihlasky", 'ZALOHOVA', 'FAK-2027-002', 2000.00, 2000.00, '2027-01-16', '2027-02-16', 1, p."Variabilni_Symbol"
FROM "Prihlasky" p JOIN "Deti" d ON p."ID_Ditete" = d."ID_Ditete"
WHERE d."Prijmeni" = 'Svoboda' AND d."Jmeno" = 'Matěj';

INSERT INTO "Faktury"
  ("ID_Prihlasky", "Typ_Faktury", "Cislo_Faktury", "Castka", "Castka_Zaplaceno", "Datum_Vystaveni", "Datum_Splatnosti", "Uhrazeno", "Variabilni_Symbol")
SELECT p."ID_Prihlasky", 'ZALOHOVA', 'FAK-2027-003', 2000.00, 2000.00, '2027-01-18', '2027-02-18', 1, p."Variabilni_Symbol"
FROM "Prihlasky" p JOIN "Deti" d ON p."ID_Ditete" = d."ID_Ditete"
WHERE d."Prijmeni" = 'Černá' AND d."Jmeno" = 'Aneta';

INSERT INTO "Faktury"
  ("ID_Prihlasky", "Typ_Faktury", "Cislo_Faktury", "Castka", "Castka_Zaplaceno", "Datum_Vystaveni", "Datum_Splatnosti", "Uhrazeno", "Variabilni_Symbol")
SELECT p."ID_Prihlasky", 'ZALOHOVA', 'FAK-2027-004', 2000.00, 2000.00, '2027-01-20', '2027-02-20', 1, p."Variabilni_Symbol"
FROM "Prihlasky" p JOIN "Deti" d ON p."ID_Ditete" = d."ID_Ditete"
WHERE d."Prijmeni" = 'Kučera' AND d."Jmeno" = 'Filip';

INSERT INTO "Faktury"
  ("ID_Prihlasky", "Typ_Faktury", "Cislo_Faktury", "Castka", "Castka_Zaplaceno", "Datum_Vystaveni", "Datum_Splatnosti", "Uhrazeno", "Variabilni_Symbol")
SELECT p."ID_Prihlasky", 'ZALOHOVA', 'FAK-2027-005', 2000.00, 2000.00, '2027-01-22', '2027-02-22', 1, p."Variabilni_Symbol"
FROM "Prihlasky" p JOIN "Deti" d ON p."ID_Ditete" = d."ID_Ditete"
WHERE d."Prijmeni" = 'Procházková' AND d."Jmeno" = 'Sofie';

-- 8. Pět doplatkových faktur (po 3 500 Kč)
INSERT INTO "Faktury"
  ("ID_Prihlasky", "Typ_Faktury", "Cislo_Faktury", "Castka", "Castka_Zaplaceno", "Datum_Vystaveni", "Datum_Splatnosti", "Uhrazeno", "Variabilni_Symbol")
SELECT p."ID_Prihlasky", 'DOPLATKOVA', 'FAK-2027-006', 3500.00, 0.00, '2027-05-15', '2027-06-15', 0, p."Variabilni_Symbol"
FROM "Prihlasky" p JOIN "Deti" d ON p."ID_Ditete" = d."ID_Ditete"
WHERE d."Prijmeni" = 'Novák' AND d."Jmeno" = 'Jakub';

INSERT INTO "Faktury"
  ("ID_Prihlasky", "Typ_Faktury", "Cislo_Faktury", "Castka", "Castka_Zaplaceno", "Datum_Vystaveni", "Datum_Splatnosti", "Uhrazeno", "Variabilni_Symbol")
SELECT p."ID_Prihlasky", 'DOPLATKOVA', 'FAK-2027-007', 3500.00, 0.00, '2027-05-15', '2027-06-15', 0, p."Variabilni_Symbol"
FROM "Prihlasky" p JOIN "Deti" d ON p."ID_Ditete" = d."ID_Ditete"
WHERE d."Prijmeni" = 'Svoboda' AND d."Jmeno" = 'Matěj';

INSERT INTO "Faktury"
  ("ID_Prihlasky", "Typ_Faktury", "Cislo_Faktury", "Castka", "Castka_Zaplaceno", "Datum_Vystaveni", "Datum_Splatnosti", "Uhrazeno", "Variabilni_Symbol")
SELECT p."ID_Prihlasky", 'DOPLATKOVA', 'FAK-2027-008', 3500.00, 0.00, '2027-05-15', '2027-06-15', 0, p."Variabilni_Symbol"
FROM "Prihlasky" p JOIN "Deti" d ON p."ID_Ditete" = d."ID_Ditete"
WHERE d."Prijmeni" = 'Černá' AND d."Jmeno" = 'Aneta';

INSERT INTO "Faktury"
  ("ID_Prihlasky", "Typ_Faktury", "Cislo_Faktury", "Castka", "Castka_Zaplaceno", "Datum_Vystaveni", "Datum_Splatnosti", "Uhrazeno", "Variabilni_Symbol")
SELECT p."ID_Prihlasky", 'DOPLATKOVA', 'FAK-2027-009', 3500.00, 0.00, '2027-05-15', '2027-06-15', 0, p."Variabilni_Symbol"
FROM "Prihlasky" p JOIN "Deti" d ON p."ID_Ditete" = d."ID_Ditete"
WHERE d."Prijmeni" = 'Kučera' AND d."Jmeno" = 'Filip';

INSERT INTO "Faktury"
  ("ID_Prihlasky", "Typ_Faktury", "Cislo_Faktury", "Castka", "Castka_Zaplaceno", "Datum_Vystaveni", "Datum_Splatnosti", "Uhrazeno", "Variabilni_Symbol")
SELECT p."ID_Prihlasky", 'DOPLATKOVA', 'FAK-2027-010', 3500.00, 0.00, '2027-05-15', '2027-06-15', 0, p."Variabilni_Symbol"
FROM "Prihlasky" p JOIN "Deti" d ON p."ID_Ditete" = d."ID_Ditete"
WHERE d."Prijmeni" = 'Procházková' AND d."Jmeno" = 'Sofie';
