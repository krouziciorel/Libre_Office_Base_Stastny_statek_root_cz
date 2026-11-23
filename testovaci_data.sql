-- ============================================================
-- ŠŤASTNÝ STATEK – testovací data
-- LibreOffice Base 26.2 / Firebird 3 (embedded)
--
-- DŮLEŽITÉ: Vkládejte každý INSERT zvlášť (jeden po druhém)!
-- Pořadí: Dodavatele → Zakaznici → Deti → Praktikanti →
--         Akce → Praktikanti_Akce → Prihlasky → Faktury → Dokumenty
-- ============================================================

-- ── DODAVATEL (Vaše firma) ───────────────────────────────────
INSERT INTO "Dodavatele"
  ("Nazev_Firmy","Jmeno","Prijmeni","ICO","Ulice_CP","Mesto","PSC",
   "Telefon","Email","Web","Banka","Cislo_Uctu","IBAN")
VALUES
  ('Luděk Šťastný - Šťastný statek','Luděk','Šťastný','74461028',
   'Provodín 211','Provodín','470 01',
   '+420 777 123 456','info@stastnystatek.cz','www.stastnystatek.cz',
   'Česká spořitelna','1652608083/0800',
   'CZ65 0800 0000 0016 5260 8083')

-- ── ZÁKAZNÍCI / RODIČE ──────────────────────────────────────
INSERT INTO "Zakaznici"
  ("Jmeno","Prijmeni","Telefon","Email","Ulice_CP","Mesto","PSC")
VALUES ('Pavel','Novák','+420 602 111 222','novak@email.cz',
        'Lipová 5','Praha 4','140 00')

INSERT INTO "Zakaznici"
  ("Jmeno","Prijmeni","Telefon","Email","Ulice_CP","Mesto","PSC")
VALUES ('Hana','Batelková','+420 603 333 444','batelkova@email.cz',
        'Březinova 18','Brno','602 00')

INSERT INTO "Zakaznici"
  ("Jmeno","Prijmeni","Telefon","Email","Ulice_CP","Mesto","PSC")
VALUES ('Tomáš','Brázdův','+420 604 555 666','brazduv@email.cz',
        'Polní 3','Olomouc','779 00')

-- zákazník bez dítěte – vyjížďka (dospělý)
INSERT INTO "Zakaznici"
  ("Jmeno","Prijmeni","Telefon","Email","Ulice_CP","Mesto","PSC")
VALUES ('Lukáš','Horák','+420 605 777 888','horak@email.cz',
        'Nádražní 22','Plzeň','301 00')

-- zákazník balíček (dospělý/rodina)
INSERT INTO "Zakaznici"
  ("Jmeno","Prijmeni","Telefon","Email","Ulice_CP","Mesto","PSC")
VALUES ('Petra','Krejčová','+420 606 999 000','krejcova@email.cz',
        'Zahradní 7','České Budějovice','370 01')

-- ── DĚTI ────────────────────────────────────────────────────
-- Dítě Novákových (ID_Rodic=1 → Pavel Novák)
INSERT INTO "Deti"
  ("ID_Rodic","Jmeno","Prijmeni","Datum_Narozeni",
   "Zdravotni_Pojistovna","Cislo_Pojistky",
   "Urazove_Pojisteni","Bezinfekcnost")
VALUES (1,'Adam','Novák','2012-05-14',
        'VZP','111222333',1,0)

-- Dítě Batelkové (ID_Rodic=2 → Hana Batelková)
INSERT INTO "Deti"
  ("ID_Rodic","Jmeno","Prijmeni","Datum_Narozeni",
   "Zdravotni_Pojistovna","Cislo_Pojistky",
   "Urazove_Pojisteni","Bezinfekcnost")
VALUES (2,'Tereza','Batelková','2010-04-22',
        'ČPZP','444555666',0,1)

-- Dítě Brázdova (ID_Rodic=3 → Tomáš Brázdův)
INSERT INTO "Deti"
  ("ID_Rodic","Jmeno","Prijmeni","Datum_Narozeni",
   "Zdravotni_Pojistovna","Cislo_Pojistky",
   "Urazove_Pojisteni","Bezinfekcnost","Zdravotni_Omezeni")
VALUES (3,'Markéta','Brázdová','2011-09-03',
        'VZP','777888999',1,0,
        'Alergie na prach, nemůže jezdit na dostihy')

-- ── PRAKTIKANTI ─────────────────────────────────────────────
INSERT INTO "Praktikanti"
  ("Jmeno","Prijmeni","Datum_Narozeni","Telefon","Email")
VALUES ('Eliška','Malá','2005-03-10','+420 608 111 222','eliska.mala@email.cz')

INSERT INTO "Praktikanti"
  ("Jmeno","Prijmeni","Datum_Narozeni","Telefon","Email")
VALUES ('Ondřej','Veselý','2004-11-25','+420 609 333 444','ondrej.vesely@email.cz')

-- ── AKCE ────────────────────────────────────────────────────
-- Vyjížďka (dospělý, bez přihlášky – jen faktura)
INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Cena_Celkem","Aktivni")
VALUES ('VYJIZDKA','Vyjížďka na koni – červenec 2026',
        '2026-07-15',800.00,1)

-- Balíček 1 den
INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Cena_Celkem","Zalohova_Castka","Zalohova_Spl","Aktivni")
VALUES ('BALICEK_1D','Balíček u koní 1 den – srpen 2026',
        '2026-08-10',2500.00,1000.00,'2026-07-10',1)

-- Dětský víkend – turnus 1
INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Datum_Do","Kapacita",
   "Cena_Celkem","Zalohova_Castka","Zalohova_Spl","Aktivni")
VALUES ('DETSKY_VIKEND','Dětský víkend – turnus 1 (12.–14. 9. 2026)',
        '2026-09-12','2026-09-14',15,
        3200.00,1000.00,'2026-08-01',1)

-- Letní tábor – turnus 1
INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Datum_Do","Kapacita",
   "Cena_Celkem","Zalohova_Castka","Zalohova_Spl","Aktivni")
VALUES ('LETNI_TABOR','Letní tábor – turnus 1 (1.–14. 7. 2026)',
        '2026-07-01','2026-07-14',20,
        9800.00,3000.00,'2026-05-01',1)

-- Podzimní prázdniny
INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Datum_Do","Kapacita",
   "Cena_Celkem","Zalohova_Castka","Zalohova_Spl","Aktivni")
VALUES ('PODZIMNI_PRAZDNINY','Podzimní prázdniny 2026 (26.–30. 10.)',
        '2026-10-26','2026-10-30',12,
        4500.00,1500.00,'2026-09-15',1)

-- ── PRAKTIKANTI ↔ AKCE ──────────────────────────────────────
-- Eliška a Ondřej na Dětský víkend (ID_Akce=3)
INSERT INTO "Praktikanti_Akce" ("ID_Praktikanta","ID_Akce") VALUES (1,3)
INSERT INTO "Praktikanti_Akce" ("ID_Praktikanta","ID_Akce") VALUES (2,3)

-- Eliška na Letní tábor (ID_Akce=4)
INSERT INTO "Praktikanti_Akce" ("ID_Praktikanta","ID_Akce") VALUES (1,4)

-- ── PŘIHLÁŠKY ────────────────────────────────────────────────
-- Vyjížďka – Lukáš Horák (bez dítěte, ID_Akce=1, ID_Zakaznika=4)
-- Variabilní symbol pro dospělého: pořadí + rok (není rč dítěte)
INSERT INTO "Prihlasky"
  ("ID_Akce","ID_Zakaznika","ID_Ditete","Datum_Prihlasky",
   "Stav","Variabilni_Symbol","Cena_Celkem")
VALUES (1,4,NULL,'2026-06-20','POTVRZEN','00012026',800.00)

-- Balíček – Petra Krejčová (bez dítěte, ID_Akce=2, ID_Zakaznika=5)
INSERT INTO "Prihlasky"
  ("ID_Akce","ID_Zakaznika","ID_Ditete","Datum_Prihlasky",
   "Stav","Variabilni_Symbol","Cena_Celkem")
VALUES (2,5,NULL,'2026-06-21','POTVRZEN','00022026',2500.00)

-- Dětský víkend – Adam Novák (ID_Akce=3, ID_Zakaznika=1, ID_Ditete=1)
-- Variabilní symbol: DDMMRRRR (nar. 14.05. + turnus 2026 = 14052026, 8 číslic pro SPAYD)
INSERT INTO "Prihlasky"
  ("ID_Akce","ID_Zakaznika","ID_Ditete","Datum_Prihlasky",
   "Stav","Variabilni_Symbol","Cena_Celkem")
VALUES (3,1,1,'2026-06-20','POTVRZEN','14052026',3200.00)

-- Letní tábor – Tereza Batelková (ID_Akce=4, ID_Zakaznika=2, ID_Ditete=2)
-- Variabilní symbol: DDMMRRRR (nar. 22.04. + turnus 2026 = 22042026, 8 číslic pro SPAYD)
INSERT INTO "Prihlasky"
  ("ID_Akce","ID_Zakaznika","ID_Ditete","Datum_Prihlasky",
   "Stav","Variabilni_Symbol","Cena_Celkem")
VALUES (4,2,2,'2026-06-15','POTVRZEN','22042026',9800.00)

-- Podzimní prázdniny – Markéta Brázdová (ID_Akce=5, ID_Zakaznika=3, ID_Ditete=3)
-- Variabilní symbol: DDMMRRRR (nar. 03.09. + turnus 2026 = 03092026, 8 číslic pro SPAYD)
INSERT INTO "Prihlasky"
  ("ID_Akce","ID_Zakaznika","ID_Ditete","Datum_Prihlasky",
   "Stav","Variabilni_Symbol","Cena_Celkem")
VALUES (5,3,3,'2026-06-22','PRIHLASEN','03092026',4500.00)

-- ── FAKTURY ─────────────────────────────────────────────────
-- Faktura za vyjížďku – Lukáš Horák (ID_Prihlasky=1)
-- Pro vyjížďky jde o JEDINOU fakturu (bez zálohy – podle praxe)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (1,'DOPLATKOVA','FAK-2026-001',800.00,
        '2026-06-20','2026-07-15',0,'00012026')

-- Faktura za balíček – záloha Petra Krejčová (ID_Prihlasky=2)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (2,'ZALOHOVA','FAK-2026-002',1000.00,
        '2026-06-21','2026-07-10',0,'00022026')

-- Faktura za balíček – doplatek Petra Krejčová (ID_Prihlasky=2)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (2,'DOPLATKOVA','FAK-2026-003',1500.00,
        '2026-06-21','2026-08-10',0,'00022026')

-- Záloha – Dětský víkend, Adam Novák (ID_Prihlasky=3)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (3,'ZALOHOVA','FAK-2026-004',1000.00,
        '2026-06-20','2026-08-01',1,'14052026')

-- Doplatek – Dětský víkend, Adam Novák (ID_Prihlasky=3)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka","Castka_Zaplaceno",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (3,'DOPLATKOVA','FAK-2026-005',2200.00,1000.00,
        '2026-08-15','2026-09-05',0,'14052026')

-- Záloha – Letní tábor, Tereza Batelková (ID_Prihlasky=4)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (4,'ZALOHOVA','FAK-2026-006',3000.00,
        '2026-06-15','2026-05-01',1,'22042026')

-- Doplatek – Letní tábor, Tereza Batelková (ID_Prihlasky=4)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka","Castka_Zaplaceno",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (4,'DOPLATKOVA','FAK-2026-007',6800.00,3000.00,
        '2026-06-20','2026-06-30',0,'22042026')

-- Záloha – Podzimní prázdniny, Markéta Brázdová (ID_Prihlasky=5)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (5,'ZALOHOVA','FAK-2026-008',1500.00,
        '2026-06-22','2026-09-15',0,'03092026')

-- ── DOKUMENTY ────────────────────────────────────────────────
-- Oskenovaný lékař pro Adama Nováka (ID_Osoby=1, DITE)
INSERT INTO "Dokumenty"
  ("Typ_Osoby","ID_Osoby","ID_Prihlasky","Typ_Dokumentu",
   "Nazev","Cesta_Souboru","Datum_Vlozeni")
VALUES ('DITE',1,3,'LEKAR',
        'Lékařské potvrzení – Adam Novák',
        'Dokumenty/Deti/Novak_Adam/lekar_2026.pdf','2026-06-20')

-- Bezinfekčnost pro Terezu Batelkovou (ID_Osoby=2, DITE)
INSERT INTO "Dokumenty"
  ("Typ_Osoby","ID_Osoby","ID_Prihlasky","Typ_Dokumentu",
   "Nazev","Cesta_Souboru","Datum_Vlozeni")
VALUES ('DITE',2,4,'BEZINFEKCNOST',
        'Bezinfekčnost – Tereza Batelková',
        'Dokumenty/Deti/Batelkova_Tereza/bezinf_LT2026.pdf','2026-06-15')
