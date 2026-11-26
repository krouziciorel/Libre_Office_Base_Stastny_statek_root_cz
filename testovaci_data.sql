-- ============================================================
-- ŠŤASTNÝ STATEK – ukázková testovací data (Verze 2.7)
-- Vkládejte po blocích v: Nástroje → SQL
-- ============================================================

-- ── DODAVATEL ────────────────────────────────────────────────
INSERT INTO "Dodavatele"
  ("Nazev_Firmy","Jmeno","Prijmeni","ICO","DIC",
   "Ulice_CP","Mesto","PSC","Telefon","Email","Web",
   "Banka","Cislo_Uctu","IBAN","Logo_Cesta")
VALUES
  ('Šťastný statek s.r.o.','Jana','Šťastná','12345678','CZ12345678',
   'Provodín 42','Provodín','471 61','+420 777 123 456',
   'info@stastnystatek.cz','www.stastnystatek.cz',
   'Česká spořitelna','1234567890/0800',
   'CZ65 0800 0000 0012 3456 7890',
   'Sablony/logo.png');

-- ── ZÁKAZNÍCI (RODIČE A DOSPĚLÍ KLIENTI) ─────────────────────
INSERT INTO "Zakaznici" ("Jmeno","Prijmeni","Telefon","Email","Ulice_CP","Mesto","PSC")
VALUES ('Petr','Novák','+420 601 111 222','petr.novak@email.cz','Květinová 5','Česká Lípa','470 01');

INSERT INTO "Zakaznici" ("Jmeno","Prijmeni","Telefon","Email","Ulice_CP","Mesto","PSC")
VALUES ('Martina','Batelková','+420 602 333 444','martina.batelkova@seznam.cz','Lipová 12','Nový Bor','473 01');

INSERT INTO "Zakaznici" ("Jmeno","Prijmeni","Telefon","Email","Ulice_CP","Mesto","PSC")
VALUES ('Karel','Brázda','+420 603 555 666','karel.brazda@centrum.cz','Lesní 8','Mimoň','471 24');

INSERT INTO "Zakaznici" ("Jmeno","Prijmeni","Telefon","Email","Ulice_CP","Mesto","PSC")
VALUES ('Lukáš','Horák','+420 604 777 888','lukas.horak@gmail.com','Sluneční 3','Doksy','472 01');

INSERT INTO "Zakaznici" ("Jmeno","Prijmeni","Telefon","Email","Ulice_CP","Mesto","PSC")
VALUES ('Petra','Krejčová','+420 605 999 000','krejcova.petra@seznam.cz','Nádražní 15','Zákupy','471 23');

-- ── DĚTI ─────────────────────────────────────────────────────
INSERT INTO "Deti"
  ("ID_Rodic","Jmeno","Prijmeni","Datum_Narozeni",
   "Zdravotni_Pojistovna","Cislo_Pojistky","Urazove_Pojisteni",
   "Zdravotni_Omezeni","Bezinfekcnost","Datum_Bezinf","Poznamka")
VALUES
  (1,'Adam','Novák','2016-05-14',
   'VZP (111)','1605141234',0,
   'Alergie na pyl trav',1,'2026-06-20',
   'Plavec: plavec. Lékařské potvrzení odevzdáno.');

INSERT INTO "Deti"
  ("ID_Rodic","Jmeno","Prijmeni","Datum_Narozeni",
   "Zdravotni_Pojistovna","Cislo_Pojistky","Urazove_Pojisteni",
   "Zdravotni_Omezeni","Bezinfekcnost","Datum_Bezinf","Poznamka")
VALUES
  (2,'Tereza','Batelková','2014-04-22',
   'OZP (207)','1454225678',1,
   'Žádná zdravotní omezení',1,'2026-06-15',
   'Plavec: částečný plavec. Vlastní úrazové pojištění.');

INSERT INTO "Deti"
  ("ID_Rodic","Jmeno","Prijmeni","Datum_Narozeni",
   "Zdravotni_Pojistovna","Cislo_Pojistky","Urazove_Pojisteni",
   "Zdravotni_Omezeni","Bezinfekcnost","Datum_Bezinf","Poznamka")
VALUES
  (3,'Markéta','Brázdová','2017-09-03',
   'VoZP (201)','1759039012',0,
   'Astma – nosí inhalátor s sebou',0,NULL,
   'Plavec: neplavec. Bezinfekčnost dosud neodevzdána.');

-- ── PRAKTIKANTI ──────────────────────────────────────────────
INSERT INTO "Praktikanti"
  ("Jmeno","Prijmeni","Datum_Narozeni","Telefon","Email","Ulice_CP","Mesto","PSC","Poznamka")
VALUES
  ('Eliška','Králová','2006-03-15','+420 721 111 222',
   'eliska.kralova@email.cz','Dlouhá 45','Česká Lípa','470 01',
   'Zkušená jezdkyně, 3. rok jako praktikantka');

INSERT INTO "Praktikanti"
  ("Jmeno","Prijmeni","Datum_Narozeni","Telefon","Email","Ulice_CP","Mesto","PSC","Poznamka")
VALUES
  ('Matěj','Dvořák','2005-08-20','+420 722 333 444',
   'matej.dvorak@seznam.cz','Krátká 3','Nový Bor','473 01',
   'Kurz první pomoci ČČK, licence instruktora jezdectví');

INSERT INTO "Praktikanti"
  ("Jmeno","Prijmeni","Datum_Narozeni","Telefon","Email","Ulice_CP","Mesto","PSC","Poznamka")
VALUES
  ('Anna','Benešová','2007-01-10','+420 723 555 666',
   'anna.benesova@centrum.cz','Polní 18','Mimoň','471 24',
   'První rok, asistence u koní');

INSERT INTO "Praktikanti"
  ("Jmeno","Prijmeni","Datum_Narozeni","Telefon","Email","Ulice_CP","Mesto","PSC","Poznamka")
VALUES
  ('Tomáš','Černý','2004-11-05','+420 724 777 888',
   'tomas.cerny@gmail.com','Luční 7','Doksy','472 01',
   'Zdravotník zotavovacích akcí, student pedagogické fakulty');

-- ── AKCE ─────────────────────────────────────────────────────
INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Datum_Do","Kapacita",
   "Cena_Celkem","Zalohova_Castka","Zalohova_Spl","Poznamka","Aktivni")
VALUES
  ('VYJIZDKA','Individuální vyjížďka – 2 hodiny',
   '2026-07-05','2026-07-05',2,
   800.00,0.00,NULL,
   'Vyjížďka do okolí Provodína s průvodcem. Platba celá najednou.',1);

INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Datum_Do","Kapacita",
   "Cena_Celkem","Zalohova_Castka","Zalohova_Spl","Poznamka","Aktivni")
VALUES
  ('BALICEK','Víkendový balíček pro dospělé',
   '2026-08-15','2026-08-16',6,
   2500.00,1000.00,'2026-07-15',
   '2 dny ježdění + ubytování. Záloha 1000 Kč splatná do měsíce před akcí.',1);

INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Datum_Do","Kapacita",
   "Cena_Celkem","Zalohova_Castka","Zalohova_Spl","Poznamka","Aktivni")
VALUES
  ('DETSKY_VIKEND','Dětský víkend u koní – červenec 2026',
   '2026-07-18','2026-07-19',10,
   3200.00,1000.00,'2026-06-30',
   'Sobota–neděle, pro děti 6–15 let. Záloha 1000 Kč.',1);

INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Datum_Do","Kapacita",
   "Cena_Celkem","Zalohova_Castka","Zalohova_Spl","Poznamka","Aktivni")
VALUES
  ('LETNI_TABOR','Letní tábor u koní – 1. turnus 2026',
   '2026-07-26','2026-08-01',15,
   9800.00,3000.00,'2026-05-31',
   '7 dní s koňmi, ubytování, strava 5x denně. Záloha 3000 Kč do konce května.',1);

INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Datum_Do","Kapacita",
   "Cena_Celkem","Zalohova_Castka","Zalohova_Spl","Poznamka","Aktivni")
VALUES
  ('PODZIMNI_PRAZDNINY','Podzimní prázdniny u koní 2026',
   '2026-10-28','2026-10-31',8,
   4500.00,1500.00,'2026-09-30',
   '4 dny podzimních prázdnin pro děti. Záloha 1500 Kč.',1);

INSERT INTO "Akce"
  ("Typ_Akce","Nazev","Datum_Od","Datum_Do","Kapacita",
   "Cena_Celkem","Zalohova_Castka","Zalohova_Spl","Poznamka","Aktivni")
VALUES
  ('LETNI_TABOR','Letní tábor u koní 1 turnus 27. 6. - 2. 7. 2027',
   '2027-06-27','2027-07-02',15,
   5500.00,2000.00,'2027-04-30',
   'Hlavní letní tábor 2027. Záloha 2000 Kč.',1);

-- ── PRAKTIKANTI NA AKCÍCH ────────────────────────────────────
INSERT INTO "Praktikanti_Akce" ("ID_Praktikanta","ID_Akce") VALUES (1,4);
INSERT INTO "Praktikanti_Akce" ("ID_Praktikanta","ID_Akce") VALUES (2,4);
INSERT INTO "Praktikanti_Akce" ("ID_Praktikanta","ID_Akce") VALUES (3,3);
INSERT INTO "Praktikanti_Akce" ("ID_Praktikanta","ID_Akce") VALUES (4,5);
INSERT INTO "Praktikanti_Akce" ("ID_Praktikanta","ID_Akce") VALUES (1,6);

-- ── PŘIHLÁŠKY ────────────────────────────────────────────────
-- Vyjížďka – Lukáš Horák (ID_Akce=1, ID_Zakaznika=4)
INSERT INTO "Prihlasky"
  ("ID_Akce","ID_Zakaznika","ID_Ditete","Datum_Prihlasky",
   "Stav","Variabilni_Symbol","Cena_Zakladni","Sleva","Cena_Celkem")
VALUES (1,4,NULL,'2026-06-20','POTVRZEN','2026000001',800.00,0.00,800.00);

-- Balíček – Petra Krejčová (ID_Akce=2, ID_Zakaznika=5)
INSERT INTO "Prihlasky"
  ("ID_Akce","ID_Zakaznika","ID_Ditete","Datum_Prihlasky",
   "Stav","Variabilni_Symbol","Cena_Zakladni","Sleva","Cena_Celkem")
VALUES (2,5,NULL,'2026-06-21','POTVRZEN','2026000002',2500.00,0.00,2500.00);

-- Dětský víkend – Adam Novák (ID_Akce=3, ID_Zakaznika=1, ID_Ditete=1)
INSERT INTO "Prihlasky"
  ("ID_Akce","ID_Zakaznika","ID_Ditete","Datum_Prihlasky",
   "Stav","Variabilni_Symbol","Cena_Zakladni","Sleva","Cena_Celkem","Bezinfekcnost","Datum_Bezinf")
VALUES (3,1,1,'2026-06-20','POTVRZEN','2026000003',3200.00,0.00,3200.00,1,'2026-06-20');

-- Letní tábor – Tereza Batelková (ID_Akce=4, ID_Zakaznika=2, ID_Ditete=2)
INSERT INTO "Prihlasky"
  ("ID_Akce","ID_Zakaznika","ID_Ditete","Datum_Prihlasky",
   "Stav","Variabilni_Symbol","Cena_Zakladni","Sleva","Cena_Celkem","Bezinfekcnost","Datum_Bezinf")
VALUES (4,2,2,'2026-06-15','POTVRZEN','2026000004',9800.00,0.00,9800.00,1,'2026-06-15');

-- Podzimní prázdniny – Markéta Brázdová (ID_Akce=5, ID_Zakaznika=3, ID_Ditete=3)
INSERT INTO "Prihlasky"
  ("ID_Akce","ID_Zakaznika","ID_Ditete","Datum_Prihlasky",
   "Stav","Variabilni_Symbol","Cena_Zakladni","Sleva","Cena_Celkem")
VALUES (5,3,3,'2026-06-22','PRIHLASEN','2026000005',4500.00,0.00,4500.00);

-- ── FAKTURY ─────────────────────────────────────────────────
-- Vyjížďka – Lukáš Horák (jednorázová celková faktura, plně uhrazeno)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka","Castka_Zaplaceno",
   "Datum_Vystaveni","Datum_Splatnosti","Datum_Zaplaceno","Uhrazeno","Variabilni_Symbol")
VALUES (1,'CELKOVA','FAK-2026-001',800.00,800.00,
        '2026-06-20','2026-07-04','2026-06-25',1,'2026000001');

-- Balíček záloha – Petra Krejčová
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka","Castka_Zaplaceno",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (2,'ZALOHOVA','FAK-2026-002',1000.00,0.00,
        '2026-06-21','2026-07-10',0,'2026000002');

-- Balíček doplatek – Petra Krejčová
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka","Castka_Zaplaceno",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (2,'DOPLATKOVA','FAK-2026-003',1500.00,0.00,
        '2026-06-21','2026-08-10',0,'2026000002');

-- Záloha – Dětský víkend, Adam Novák (uhrazeno)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka","Castka_Zaplaceno",
   "Datum_Vystaveni","Datum_Splatnosti","Datum_Zaplaceno","Uhrazeno","Variabilni_Symbol")
VALUES (3,'ZALOHOVA','FAK-2026-004',1000.00,1000.00,
        '2026-06-20','2026-08-01','2026-06-28',1,'2026000003');

-- Doplatek – Dětský víkend, Adam Novák (částečná platba 1000 Kč z 2200 Kč)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka","Castka_Zaplaceno",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (3,'DOPLATKOVA','FAK-2026-005',2200.00,1000.00,
        '2026-08-15','2026-09-05',0,'2026000003');

-- Záloha – Letní tábor, Tereza Batelková (uhrazeno)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka","Castka_Zaplaceno",
   "Datum_Vystaveni","Datum_Splatnosti","Datum_Zaplaceno","Uhrazeno","Variabilni_Symbol")
VALUES (4,'ZALOHOVA','FAK-2026-006',3000.00,3000.00,
        '2026-06-15','2026-05-01','2026-06-25',1,'2026000004');

-- Doplatek – Letní tábor, Tereza Batelková (částečná platba 3000 Kč ze 6800 Kč)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka","Castka_Zaplaceno",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (4,'DOPLATKOVA','FAK-2026-007',6800.00,3000.00,
        '2026-06-20','2026-06-30',0,'2026000004');

-- Záloha – Podzimní prázdniny, Markéta Brázdová (neuhrazeno)
INSERT INTO "Faktury"
  ("ID_Prihlasky","Typ_Faktury","Cislo_Faktury","Castka","Castka_Zaplaceno",
   "Datum_Vystaveni","Datum_Splatnosti","Uhrazeno","Variabilni_Symbol")
VALUES (5,'ZALOHOVA','FAK-2026-008',1500.00,0.00,
        '2026-06-22','2026-09-15',0,'2026000005');

-- ── DOKUMENTY ────────────────────────────────────────────────
INSERT INTO "Dokumenty"
  ("Typ_Osoby","ID_Osoby","ID_Prihlasky","Typ_Dokumentu",
   "Nazev","Cesta_Souboru","Datum_Vlozeni")
VALUES ('DITE',1,3,'LEKAR',
        'Lékařské potvrzení – Adam Novák',
        'Dokumenty/Deti/Novak_Adam/lekar_2026.pdf','2026-06-20');

INSERT INTO "Dokumenty"
  ("Typ_Osoby","ID_Osoby","ID_Prihlasky","Typ_Dokumentu",
   "Nazev","Cesta_Souboru","Datum_Vlozeni")
VALUES ('DITE',2,4,'BEZINFEKCNOST',
        'Bezinfekčnost – Tereza Batelková',
        'Dokumenty/Deti/Batelkova_Tereza/bezinf_LT2026.pdf','2026-06-15');
