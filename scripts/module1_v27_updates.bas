' ==============================================================================
' Modul maker v2.7 - Aktualizované a opravené procedury pro Šťastný statek
' (Verze 2.7: finanční triggery, slevy v DB, jedinečný VS, tlačítko bezinfekčnosti,
'  oprava com.sun.star.lang.DisposedException bezpečným oddělením SQL ResultSets)
' ==============================================================================

FUNCTION GetBaseFolder() AS STRING
    DIM oDBDoc AS OBJECT
    DIM sURL AS STRING
    DIM nPos AS INTEGER, nNext AS INTEGER
    
    oDBDoc = GetDB()
    IF NOT ISNULL(oDBDoc) AND NOT ISEMPTY(oDBDoc) THEN
        IF oDBDoc.hasLocation() THEN
            sURL = oDBDoc.getLocation()
            nPos = 0
            nNext = InStr(1, sURL, "/")
            DO WHILE nNext > 0
                nPos = nNext
                nNext = InStr(nPos + 1, sURL, "/")
            LOOP
            IF nPos > 0 THEN
                GetBaseFolder = ConvertFromURL(Left(sURL, nPos))
                EXIT FUNCTION
            END IF
        END IF
    END IF
    MsgBox "UPOZORNĚNÍ: Nepodařilo se automaticky určit složku databáze z umístění souboru." & Chr(13) & _
           "Bude použita výchozí cesta projektu.", 48, "Cesta projektu"
    GetBaseFolder = "/home/wanbli/Moje_projekty/Evidence_taboru/Libre_Office_Base_presun/"
END FUNCTION

SUB VystavitZalohu(OPTIONAL oEvent AS OBJECT)
    VytvoritFakturuContext("ZALOHOVA", oEvent)
END SUB

SUB VystavitDoplatek(OPTIONAL oEvent AS OBJECT)
    VytvoritFakturuContext("DOPLATKOVA", oEvent)
END SUB

SUB VytvoritZalohovouFakturu(OPTIONAL oEvent AS OBJECT)
    VytvoritFakturuContext("ZALOHOVA", oEvent)
END SUB

SUB VytvoritDoplatkovouFakturu(OPTIONAL oEvent AS OBJECT)
    VytvoritFakturuContext("DOPLATKOVA", oEvent)
END SUB

SUB VytvoritCelkovouFakturu(OPTIONAL oEvent AS OBJECT)
    VytvoritFakturuContext("CELKOVA", oEvent)
END SUB

SUB VytvoritFakturu(sTypFaktury AS STRING)
    VytvoritFakturuContext(sTypFaktury, Nothing)
END SUB

SUB VytvoritFakturuContext(sTypFaktury AS STRING, OPTIONAL oEvent AS OBJECT)
    DIM oConn AS OBJECT
    DIM oSt AS OBJECT
    DIM oResult AS OBJECT
    DIM sSQL AS STRING
    DIM sLabel AS STRING
    DIM nIDPrih AS LONG
    DIM dCelkem AS DOUBLE
    DIM dZaloha AS DOUBLE
    DIM dCastka AS DOUBLE
    DIM sVS AS STRING
    DIM sRok AS STRING
    DIM nNext AS INTEGER
    DIM sCislo AS STRING
    DIM sDnes AS STRING
    DIM sSpl AS STRING
    DIM sZalohaSpl AS STRING
    DIM sDatumOd AS STRING
    DIM sStavPrih AS STRING
    DIM nIDFak AS LONG
    DIM bAno AS INTEGER
    DIM sIns AS STRING
    DIM sMsg AS STRING
    DIM oForm AS OBJECT

    DIM sExSQL AS STRING
    DIM oStEx AS OBJECT
    DIM oExRes AS OBJECT
    DIM nCountZal AS INTEGER, nCountDop AS INTEGER, nCountCelk AS INTEGER
    DIM dFakturovanoZal AS DOUBLE, dFakturovanoCelk AS DOUBLE
    DIM sPosledniFakZal AS STRING, sPosledniFakDop AS STRING, sPosledniFakCelk AS STRING

    oConn = GetConn()
    IF ISNULL(oConn) OR ISEMPTY(oConn) THEN EXIT SUB

    IF sTypFaktury = "ZALOHOVA" THEN
        sLabel = "zálohovou"
    ELSEIF sTypFaktury = "CELKOVA" THEN
        sLabel = "celkovou"
    ELSE
        sLabel = "doplatkovou"
    END IF

    ' 1. Získání ID přihlášky z kontextu formuláře F5
    nIDPrih = 0
    IF NOT IsMissing(oEvent) AND NOT IsNull(oEvent) THEN
        ON ERROR RESUME NEXT
        oForm = oEvent.Source.Model.Parent
        IF NOT IsNull(oForm) THEN
            IF oForm.Columns.hasByName("ID_Prihlasky") THEN
                nIDPrih = oForm.Columns.getByName("ID_Prihlasky").getLong()
            END IF
        END IF
        ON ERROR GOTO 0
    END IF

    ' 2. Pokud přihláška nebyla určena z formuláře, otevřeme výběrový dialog
    IF nIDPrih <= 0 THEN
        nIDPrih = VybratPrihlaskuSeznamu("Vystavit " & sLabel & " fakturu - vyberte přihlášku")
    END IF
    IF nIDPrih <= 0 THEN EXIT SUB

    oSt = oConn.createStatement()

    ' Načtení údajů o přihlášce a akci
    sSQL = "SELECT p.""Cena_Celkem"",a.""Zalohova_Castka"",p.""Variabilni_Symbol"",a.""Zalohova_Spl"",a.""Datum_Od"",p.""Stav"""
    sSQL = sSQL & " FROM ""Prihlasky"" p"
    sSQL = sSQL & " JOIN ""Akce"" a ON p.""ID_Akce""=a.""ID_Akce"""
    sSQL = sSQL & " WHERE p.""ID_Prihlasky""=" & nIDPrih
    oResult = oSt.executeQuery(sSQL)
    IF NOT oResult.next() THEN
        MsgBox "Přihláška ID " & nIDPrih & " neexistuje.", 16, "Chyba"
        oResult.close()
        oSt.close()
        EXIT SUB
    END IF

    dCelkem = oResult.getDouble(1)
    dZaloha = oResult.getDouble(2)
    sVS = Trim(oResult.getString(3))
    sZalohaSpl = ""
    sDatumOd = ""
    ON ERROR RESUME NEXT
    sZalohaSpl = DateFromSQL(oResult.getString(4))
    sDatumOd   = DateFromSQL(oResult.getString(5))
    sStavPrih  = Trim(UCase(oResult.getString(6)))
    ON ERROR GOTO 0
    oResult.close()
    oSt.close()

    ' Kontrola stavu přihlášky: náhradníkům a stornovaným nelze vystavovat faktury
    IF sStavPrih = "NAHRADNIK" THEN
        MsgBox "CHYBA: Přihláška ID " & nIDPrih & " je ve stavu 'NAHRADNIK'." & Chr(13) & _
               "Náhradníkům nelze vystavovat faktury před potvrzením účasti (stav 'POTVRZEN').", 16, "Nelze fakturovat náhradníka"
        EXIT SUB
    END IF
    IF sStavPrih = "STORNO" THEN
        MsgBox "CHYBA: Přihláška ID " & nIDPrih & " je stornována. Stornované přihlášky nelze fakturovat.", 16, "Storno"
        EXIT SUB
    END IF

    ' Kontrola délky variabilního symbolu (ČBA / SPAYD max 10 číslic)
    IF LEN(sVS) > 10 OR LEN(sVS) = 0 THEN
        MsgBox "CHYBA: Neplatný variabilní symbol '" & sVS & "'." & Chr(13) & _
               "Standard ČBA (SPAYD / X-VS) vyžaduje číselný symbol o délce maximálně 10 číslic." & Chr(13) & _
               "Zkontrolujte variabilní symbol na přihlášce.", 16, "Neplatný variabilní symbol"
        EXIT SUB
    END IF

    ' Kontrola stávajících vystavených faktur k této přihlášce (samostatný Statement)
    nCountZal = 0
    nCountDop = 0
    nCountCelk = 0
    dFakturovanoZal = 0.0
    dFakturovanoCelk = 0.0
    sPosledniFakZal = ""
    sPosledniFakDop = ""
    sPosledniFakCelk = ""

    oStEx = oConn.createStatement()
    sExSQL = "SELECT ""Typ_Faktury"", ""Cislo_Faktury"", ""Castka"" FROM ""Faktury"" WHERE ""ID_Prihlasky""=" & nIDPrih
    oExRes = oStEx.executeQuery(sExSQL)
    DO WHILE oExRes.next()
        DIM sTF AS STRING, sCF AS STRING, dCF AS DOUBLE
        sTF = oExRes.getString(1)
        sCF = oExRes.getString(2)
        dCF = oExRes.getDouble(3)
        dFakturovanoCelk = dFakturovanoCelk + dCF
        IF sTF = "ZALOHOVA" THEN
            nCountZal = nCountZal + 1
            dFakturovanoZal = dFakturovanoZal + dCF
            sPosledniFakZal = sCF
        ELSEIF sTF = "DOPLATKOVA" THEN
            nCountDop = nCountDop + 1
            sPosledniFakDop = sCF
        ELSEIF sTF = "CELKOVA" THEN
            nCountCelk = nCountCelk + 1
            sPosledniFakCelk = sCF
        END IF
    LOOP
    oExRes.close()
    oStEx.close()

    sDnes = Format(Date, "YYYY-MM-DD")
    sSpl  = Format(Date + 14, "YYYY-MM-DD")

    IF sTypFaktury = "ZALOHOVA" THEN
        IF nCountZal > 0 THEN
            MsgBox "CHYBA: Pro přihlášku ID " & nIDPrih & " již zálohová faktura existuje (" & sPosledniFakZal & " ve výši " & Format(dFakturovanoZal, "#,##0.00") & " Kč)." & Chr(13) & _
                   "Vystavení duplicitní zálohové faktury je zakázáno.", 16, "Duplicita zálohy"
            EXIT SUB
        END IF
        IF nCountCelk > 0 THEN
            MsgBox "CHYBA: K této přihlášce již byla vystavena celková faktura (" & sPosledniFakCelk & "). Zálohu nelze vystavit.", 16, "Nelze vystavit zálohu"
            EXIT SUB
        END IF
        IF nCountDop > 0 THEN
            MsgBox "CHYBA: K této přihlášce již byla vystavena doplatková faktura (" & sPosledniFakDop & "). Zálohu již nelze dodatečně vystavit.", 16, "Nelze vystavit zálohu po doplatku"
            EXIT SUB
        END IF
        IF dZaloha <= 0 THEN
            MsgBox "CHYBA: Akce nemá stanovenu částku zálohy.", 16, "Chybí záloha"
            EXIT SUB
        END IF
        IF dZaloha >= dCelkem THEN
            dCastka = dCelkem
        ELSE
            dCastka = dZaloha
        END IF
        IF LEN(sZalohaSpl) >= 10 THEN
            sSpl = sZalohaSpl
        END IF

    ELSEIF sTypFaktury = "CELKOVA" THEN
        IF dFakturovanoCelk > 0 THEN
            MsgBox "CHYBA: Pro přihlášku ID " & nIDPrih & " již existují vystavené faktury ve výši " & Format(dFakturovanoCelk, "#,##0.00") & " Kč." & Chr(13) & _
                   "Celkovou fakturu nelze kombinovat s již vystavenou zálohou či doplatkem.", 16, "Nelze vystavit celkovou fakturu"
            EXIT SUB
        END IF
        IF dCelkem <= 0 THEN
            MsgBox "CHYBA: Přihláška má nulovou nebo neplatnou celkovou cenu.", 16, "Chyba ceny"
            EXIT SUB
        END IF
        dCastka = dCelkem

    ELSE ' DOPLATKOVA
        IF nCountDop > 0 THEN
            MsgBox "CHYBA: Pro přihlášku ID " & nIDPrih & " již doplatková faktura existuje (" & sPosledniFakDop & ")." & Chr(13) & _
                   "Vystavení duplicitního doplatku je zakázáno.", 16, "Duplicita doplatku"
            EXIT SUB
        END IF
        IF nCountCelk > 0 THEN
            MsgBox "CHYBA: K této přihlášce již byla vystavena celková faktura (" & sPosledniFakCelk & "). Doplatek nelze vystavit.", 16, "Nelze vystavit doplatek"
            EXIT SUB
        END IF
        IF (dCelkem - dFakturovanoCelk) <= 0 THEN
            MsgBox "CHYBA: Celková cena objednávky (" & Format(dCelkem, "#,##0.00") & " Kč) je již plně pokryta vystavenými fakturami (" & Format(dFakturovanoCelk, "#,##0.00") & " Kč)." & Chr(13) & _
                   "Částka k dofakturování je 0 Kč.", 16, "Doplatek nelze vystavit"
            EXIT SUB
        END IF
        dCastka = dCelkem - dFakturovanoCelk

        ' Splatnost doplatku: 14 dní před začátkem akce, jinak za 14 dní
        IF LEN(sDatumOd) >= 10 THEN
            DIM dDatumOdVal AS DATE
            ON ERROR RESUME NEXT
            dDatumOdVal = CDate(sDatumOd)
            IF dDatumOdVal - Date > 14 THEN
                sSpl = Format(dDatumOdVal - 14, "YYYY-MM-DD")
            ELSE
                sSpl = Format(Date + 14, "YYYY-MM-DD")
            END IF
            ON ERROR GOTO 0
        END IF
    END IF

    ' Číslování faktur: formát FAK-RRRR-NNN
    sRok = Format(Year(Date), "0000")
    DIM oStNum AS OBJECT, oResNum AS OBJECT
    oStNum = oConn.createStatement()
    sSQL = "SELECT MAX(""Cislo_Faktury"") FROM ""Faktury"" WHERE ""Cislo_Faktury"" LIKE 'FAK-" & sRok & "-%'"
    oResNum = oStNum.executeQuery(sSQL)
    nNext = 1
    IF oResNum.next() THEN
        DIM sMaxCislo AS STRING
        sMaxCislo = oResNum.getString(1)
        IF LEN(sMaxCislo) >= 12 THEN
            nNext = VAL(Mid(sMaxCislo, 10)) + 1
        END IF
    END IF
    oResNum.close()
    oStNum.close()
    sCislo = "FAK-" & sRok & "-" & Format(nNext, "000")

    DIM oStIns AS OBJECT
    oStIns = oConn.createStatement()
    sIns = "INSERT INTO ""Faktury"""
    sIns = sIns & " (""ID_Prihlasky"",""Typ_Faktury"",""Cislo_Faktury"","
    sIns = sIns & """Castka"",""Castka_Zaplaceno"",""Datum_Vystaveni"",""Datum_Splatnosti"","
    sIns = sIns & """Uhrazeno"",""Variabilni_Symbol"")"
    sIns = sIns & " VALUES (" & nIDPrih & ",'" & sTypFaktury & "','" & sCislo & "',"
    sIns = sIns & Replace(Format(dCastka, "0.00"), ",", ".") & ",0,'" & sDnes & "','" & sSpl & "',0,'" & sVS & "')"
    oStIns.executeUpdate(sIns)
    oStIns.close()

    ' Automatický reload podformuláře Faktury ve formuláři F5
    IF NOT IsMissing(oEvent) AND NOT IsNull(oEvent) THEN
        ON ERROR RESUME NEXT
        IF NOT IsNull(oForm) THEN
            IF oForm.hasByName("SubForm") THEN
                oForm.getByName("SubForm").reload()
            END IF
        END IF
        ON ERROR GOTO 0
    END IF

    DIM oStGetID AS OBJECT, oResGetID AS OBJECT
    oStGetID = oConn.createStatement()
    sSQL = "SELECT ""ID_Faktury"" FROM ""Faktury"" WHERE ""Cislo_Faktury""='" & sCislo & "'"
    oResGetID = oStGetID.executeQuery(sSQL)
    nIDFak = 0
    IF oResGetID.next() THEN nIDFak = oResGetID.getLong(1)
    oResGetID.close()
    oStGetID.close()

    sMsg = "Faktura " & sCislo & " (" & Format(dCastka,"#,##0.00") & " Kč) byla úspěšně vytvořena!"
    sMsg = sMsg & Chr(13) & "Datum splatnosti: " & sSpl
    sMsg = sMsg & Chr(13) & Chr(13) & "Chcete ji ihned otevřít v Calcu?"
    bAno = MsgBox(sMsg, 36, "Šťastný statek")
    IF bAno = 6 AND nIDFak > 0 THEN
        FakturaZID(nIDFak)
    END IF
END SUB

SUB GenerovatCisloFaktury()
    DIM oConn AS OBJECT
    DIM oSt AS OBJECT
    DIM oResult AS OBJECT
    DIM sRok AS STRING
    DIM nNext AS INTEGER

    oConn = GetConn()
    IF ISNULL(oConn) OR ISEMPTY(oConn) THEN EXIT SUB

    sRok = Format(Year(Date), "0000")
    oSt = oConn.createStatement()
    oResult = oSt.executeQuery("SELECT MAX(""Cislo_Faktury"") FROM ""Faktury"" WHERE ""Cislo_Faktury"" LIKE 'FAK-" & sRok & "-%'")
    nNext = 1
    IF oResult.next() THEN
        DIM sMaxCislo AS STRING
        sMaxCislo = oResult.getString(1)
        IF LEN(sMaxCislo) >= 12 THEN
            nNext = VAL(Mid(sMaxCislo, 10)) + 1
        END IF
    END IF
    oResult.close()
    oSt.close()

    MsgBox "Příští číslo faktury: FAK-" & sRok & "-" & Format(nNext, "000"), 64, "Šťastný statek"
END SUB

SUB TisknoutPrihlaskuPDF(OPTIONAL oEvent AS OBJECT)
    DIM nID AS LONG
    DIM oForm AS OBJECT
    nID = 0
    IF NOT IsMissing(oEvent) AND NOT IsNull(oEvent) THEN
        ON ERROR RESUME NEXT
        oForm = oEvent.Source.Model.Parent
        IF NOT IsNull(oForm) THEN
            IF oForm.Columns.hasByName("ID_Prihlasky") THEN
                nID = oForm.Columns.getByName("ID_Prihlasky").getLong()
            END IF
        END IF
        ON ERROR GOTO 0
    END IF
    IF nID <= 0 THEN
        nID = VybratPrihlaskuSeznamu("Vyberte přihlášku k tisku")
    END IF
    IF nID <= 0 THEN EXIT SUB
    PrihlaskaZID(nID)
END SUB

SUB TisknoutFakturuPDF(OPTIONAL oEvent AS OBJECT)
    DIM nID AS LONG
    DIM oForm AS OBJECT, oSubForm AS OBJECT
    nID = 0
    IF NOT IsMissing(oEvent) AND NOT IsNull(oEvent) THEN
        ON ERROR RESUME NEXT
        oForm = oEvent.Source.Model.Parent
        IF NOT IsNull(oForm) THEN
            IF oForm.hasByName("SubForm") THEN
                oSubForm = oForm.getByName("SubForm")
                IF oSubForm.Columns.hasByName("ID_Faktury") THEN
                    nID = oSubForm.Columns.getByName("ID_Faktury").getLong()
                END IF
            END IF
        END IF
        ON ERROR GOTO 0
    END IF
    IF nID <= 0 THEN
        nID = VybratFakturuSeznamu("Vyberte fakturu k tisku")
    END IF
    IF nID <= 0 THEN EXIT SUB
    FakturaZID(nID)
END SUB

FUNCTION VybratPrihlaskuSeznamu(sTitle AS STRING) AS LONG
    DIM oConn AS OBJECT
    DIM oSt AS OBJECT
    DIM oRes AS OBJECT
    DIM sSQL AS STRING
    DIM aLabels(200) AS STRING
    DIM aIDs(200) AS LONG
    DIM nCount AS INTEGER
    DIM oDlgModel AS OBJECT
    DIM oDlg AS OBJECT
    DIM oLBModel AS OBJECT
    DIM oBtnOKM AS OBJECT
    DIM oBtnCM AS OBJECT
    DIM oLB AS OBJECT
    DIM oToolkit AS OBJECT
    DIM nDlgRes AS INTEGER
    DIM nSel AS INTEGER
    DIM nResult AS LONG
    DIM i AS INTEGER
    DIM sZakJm AS STRING
    DIM sDiteJm AS STRING

    oConn = GetConn()
    IF ISNULL(oConn) OR ISEMPTY(oConn) THEN
        VybratPrihlaskuSeznamu = 0
        EXIT FUNCTION
    END IF

    oSt = oConn.createStatement()
    sSQL = "SELECT p." & Chr(34) & "ID_Prihlasky" & Chr(34)
    sSQL = sSQL & ",z." & Chr(34) & "Prijmeni" & Chr(34)
    sSQL = sSQL & ",z." & Chr(34) & "Jmeno" & Chr(34)
    sSQL = sSQL & ",d." & Chr(34) & "Prijmeni" & Chr(34)
    sSQL = sSQL & ",d." & Chr(34) & "Jmeno" & Chr(34)
    sSQL = sSQL & ",a." & Chr(34) & "Nazev" & Chr(34)
    sSQL = sSQL & ",a." & Chr(34) & "Datum_Od" & Chr(34)
    sSQL = sSQL & " FROM " & Chr(34) & "Prihlasky" & Chr(34) & " p"
    sSQL = sSQL & " JOIN " & Chr(34) & "Zakaznici" & Chr(34) & " z"
    sSQL = sSQL & " ON p." & Chr(34) & "ID_Zakaznika" & Chr(34) & "=z." & Chr(34) & "ID_Zakaznika" & Chr(34)
    sSQL = sSQL & " JOIN " & Chr(34) & "Akce" & Chr(34) & " a"
    sSQL = sSQL & " ON p." & Chr(34) & "ID_Akce" & Chr(34) & "=a." & Chr(34) & "ID_Akce" & Chr(34)
    sSQL = sSQL & " LEFT JOIN " & Chr(34) & "Deti" & Chr(34) & " d"
    sSQL = sSQL & " ON p." & Chr(34) & "ID_Ditete" & Chr(34) & "=d." & Chr(34) & "ID_Ditete" & Chr(34)
    
    IF InStr(LCase(sTitle), "faktur") > 0 OR InStr(LCase(sTitle), "vystavit") > 0 THEN
        sSQL = sSQL & " WHERE p." & Chr(34) & "Stav" & Chr(34) & " NOT IN ('STORNO', 'NAHRADNIK')"
    ELSE
        sSQL = sSQL & " WHERE p." & Chr(34) & "Stav" & Chr(34) & " <> 'STORNO'"
    END IF

    IF InStr(LCase(sTitle), "k tisku") > 0 OR (InStr(LCase(sTitle), "prihlask") > 0 AND InStr(LCase(sTitle), "faktur") = 0) THEN
        sSQL = sSQL & " AND a." & Chr(34) & "Typ_Akce" & Chr(34) & " NOT IN ('BALICEK', 'BALICEK_1D', 'BALICEK_2D', 'VYJIZDKA')"
    END IF
    sSQL = sSQL & " ORDER BY a." & Chr(34) & "Datum_Od" & Chr(34) & " DESC"
    sSQL = sSQL & ", z." & Chr(34) & "Prijmeni" & Chr(34)

    ON ERROR RESUME NEXT
    oRes = oSt.executeQuery(sSQL)
    ON ERROR GOTO 0
    IF ISNULL(oRes) OR ISEMPTY(oRes) THEN
        MsgBox "Chyba při načítání přihlášek.", 16, "Chyba"
        oSt.close()
        VybratPrihlaskuSeznamu = 0
        EXIT FUNCTION
    END IF

    nCount = 0
    DO WHILE oRes.next()
        IF nCount > 200 THEN EXIT DO
        sZakJm = oRes.getString(2) & " " & oRes.getString(3)
        sDiteJm = oRes.getString(4)
        IF LEN(sDiteJm) > 0 THEN
            sDiteJm = " / " & sDiteJm & " " & oRes.getString(5)
        END IF
        aLabels(nCount) = sZakJm & sDiteJm & " | " & oRes.getString(6) & " (" & DateFromSQL(oRes.getString(7)) & ")"
        aIDs(nCount) = oRes.getLong(1)
        nCount = nCount + 1
    LOOP
    oRes.close()
    oSt.close()

    IF nCount = 0 THEN
        MsgBox "Žádné vyhovující přihlášky nebyly nalezeny.", 48, sTitle
        VybratPrihlaskuSeznamu = 0
        EXIT FUNCTION
    END IF

    oDlgModel = CreateUnoService("com.sun.star.awt.UnoControlDialogModel")
    oDlgModel.Width = 280
    oDlgModel.Height = 185
    oDlgModel.Title = sTitle
    oDlgModel.Moveable = TRUE

    oLBModel = oDlgModel.createInstance("com.sun.star.awt.UnoControlListBoxModel")
    oLBModel.PositionX = 6
    oLBModel.PositionY = 6
    oLBModel.Width = 268
    oLBModel.Height = 152
    oLBModel.MultiSelection = FALSE
    oDlgModel.insertByName("lb1", oLBModel)

    oBtnOKM = oDlgModel.createInstance("com.sun.star.awt.UnoControlButtonModel")
    oBtnOKM.PositionX = 150
    oBtnOKM.PositionY = 163
    oBtnOKM.Width = 60
    oBtnOKM.Height = 16
    oBtnOKM.Label = "Vybrat"
    oBtnOKM.DefaultButton = TRUE
    oBtnOKM.PushButtonType = 1
    oDlgModel.insertByName("btnOK", oBtnOKM)

    oBtnCM = oDlgModel.createInstance("com.sun.star.awt.UnoControlButtonModel")
    oBtnCM.PositionX = 216
    oBtnCM.PositionY = 163
    oBtnCM.Width = 60
    oBtnCM.Height = 16
    oBtnCM.Label = "Zrušit"
    oBtnCM.PushButtonType = 2
    oDlgModel.insertByName("btnCancel", oBtnCM)

    oDlg = CreateUnoService("com.sun.star.awt.UnoControlDialog")
    oDlg.setModel(oDlgModel)

    oToolkit = CreateUnoService("com.sun.star.awt.Toolkit")
    oDlg.createPeer(oToolkit, Nothing)

    oLB = oDlg.getControl("lb1")
    FOR i = 0 TO nCount - 1
        oLB.addItem(aLabels(i), i)
    NEXT i
    oLB.selectItemPos(0, TRUE)

    nDlgRes = oDlg.execute()
    nResult = 0
    IF nDlgRes = 1 THEN
        nSel = oLB.getSelectedItemPos()
        IF nSel >= 0 THEN
            IF nSel < nCount THEN
                nResult = aIDs(nSel)
            END IF
        END IF
    END IF

    oDlg.dispose()
    VybratPrihlaskuSeznamu = nResult
END FUNCTION

SUB PrihlaskaZID(nIDPrih AS LONG)
    DIM oConn AS OBJECT, oSt AS OBJECT, oResult AS OBJECT, sSQL AS STRING
    DIM s1 AS STRING, s2 AS STRING, s3 AS STRING, s4 AS STRING, s5 AS STRING
    DIM s6 AS STRING, s7 AS STRING, s8 AS STRING, s9 AS STRING, s10 AS STRING
    DIM sF1 AS STRING, sF2 AS STRING, sF3 AS STRING, sF4 AS STRING, sF5 AS STRING
    DIM oDoc AS OBJECT
    DIM sJm AS STRING, sPoj AS STRING, sZdr AS STRING
    DIM sTermin AS STRING, sRodicJm AS STRING, sRodicPrijmeni AS STRING, sRodicJmeno AS STRING
    DIM sRodicTel AS STRING, sRodicEmail AS STRING
    DIM sDatumOd AS STRING, sDatumDo AS STRING
    DIM sNotes AS STRING, sDnes AS STRING
    DIM bIsMother AS BOOLEAN
    DIM sMatkaJm AS STRING, sMatkaTel AS STRING
    DIM sOtecJm AS STRING, sOtecTel AS STRING
    DIM sPlavecP AS STRING, sPlavecC AS STRING, sPlavecN AS STRING
    DIM sPlatbaH AS STRING, sPlatbaU AS STRING, sPlatbaS AS STRING
    DIM sMsg AS STRING

    oConn = GetConn()
    IF ISNULL(oConn) OR ISEMPTY(oConn) THEN EXIT SUB
    oSt = oConn.createStatement()

    s1 = "SELECT p." & Chr(34) & "ID_Prihlasky" & Chr(34) & ",p." & Chr(34) & "Datum_Prihlasky" & Chr(34) & ",p." & Chr(34) & "Stav" & Chr(34) & ","
    s2 = "p." & Chr(34) & "Variabilni_Symbol" & Chr(34) & ",p." & Chr(34) & "Cena_Celkem" & Chr(34) & ","
    s3 = "a." & Chr(34) & "Nazev" & Chr(34) & ",a." & Chr(34) & "Typ_Akce" & Chr(34) & ",a." & Chr(34) & "Datum_Od" & Chr(34) & ",a." & Chr(34) & "Datum_Do" & Chr(34) & ",a." & Chr(34) & "Zalohova_Castka" & Chr(34) & ","
    s4 = "z." & Chr(34) & "Jmeno" & Chr(34) & ",z." & Chr(34) & "Prijmeni" & Chr(34) & ",z." & Chr(34) & "Ulice_CP" & Chr(34) & ",z." & Chr(34) & "Mesto" & Chr(34) & ","
    s5 = "z." & Chr(34) & "PSC" & Chr(34) & ",z." & Chr(34) & "Telefon" & Chr(34) & ",z." & Chr(34) & "Email" & Chr(34) & ","
    s6 = "d." & Chr(34) & "Jmeno" & Chr(34) & ",d." & Chr(34) & "Prijmeni" & Chr(34) & ",d." & Chr(34) & "Datum_Narozeni" & Chr(34) & ","
    s7 = "d." & Chr(34) & "Zdravotni_Pojistovna" & Chr(34) & ",d." & Chr(34) & "Cislo_Pojistky" & Chr(34) & ",d." & Chr(34) & "Zdravotni_Omezeni" & Chr(34) & ","
    s8 = "dd." & Chr(34) & "Nazev_Firmy" & Chr(34) & ",dd." & Chr(34) & "Ulice_CP" & Chr(34) & ",dd." & Chr(34) & "Mesto" & Chr(34) & ",dd." & Chr(34) & "ICO" & Chr(34) & ","
    s9 = "dd." & Chr(34) & "Telefon" & Chr(34) & ",dd." & Chr(34) & "Email" & Chr(34) & ","
    s10 = "p." & Chr(34) & "Poznamka" & Chr(34) & ",z." & Chr(34) & "Poznamka" & Chr(34) & ",d." & Chr(34) & "Poznamka" & Chr(34) & ",d." & Chr(34) & "Plavec" & Chr(34) & ",p." & Chr(34) & "Zpusob_Platby" & Chr(34) & ",p." & Chr(34) & "ID_Ditete" & Chr(34) & ",a." & Chr(34) & "Cena_Celkem" & Chr(34)
    sF1 = " FROM " & Chr(34) & "Prihlasky" & Chr(34) & " p"
    sF2 = " JOIN " & Chr(34) & "Akce" & Chr(34) & " a ON p." & Chr(34) & "ID_Akce" & Chr(34) & "=a." & Chr(34) & "ID_Akce" & Chr(34)
    sF3 = " JOIN " & Chr(34) & "Zakaznici" & Chr(34) & " z ON p." & Chr(34) & "ID_Zakaznika" & Chr(34) & "=z." & Chr(34) & "ID_Zakaznika" & Chr(34)
    sF4 = " LEFT JOIN " & Chr(34) & "Deti" & Chr(34) & " d ON p." & Chr(34) & "ID_Ditete" & Chr(34) & "=d." & Chr(34) & "ID_Ditete" & Chr(34)
    sF5 = " LEFT JOIN " & Chr(34) & "Dodavatele" & Chr(34) & " dd ON dd." & Chr(34) & "ID_Dodavatele" & Chr(34) & "=1 WHERE p." & Chr(34) & "ID_Prihlasky" & Chr(34) & "=" & nIDPrih

    sSQL = s1 & s2 & s3 & s4 & s5 & s6 & s7 & s8 & s9 & s10
    sSQL = sSQL & sF1 & sF2 & sF3 & sF4 & sF5

    oResult = oSt.executeQuery(sSQL)
    IF NOT oResult.next() THEN
        MsgBox "Přihláška ID " & nIDPrih & " nebyla nalezena.", 16, "Chyba"
        oResult.close()
        oSt.close()
        EXIT SUB
    END IF

    ' --- Načtení všech hodnot do lokálních proměnných IHNED po executeQuery ---
    DIM sPrihVS AS STRING, dPrihCena AS DOUBLE
    DIM sAkceNazev AS STRING, sTypAkcePrih AS STRING, sAkceDatumOd AS STRING, sAkceDatumDo AS STRING, dAkceZaloha AS DOUBLE
    DIM sZakJmeno AS STRING, sZakPrijmeni AS STRING, sZakUlice AS STRING, sZakMesto AS STRING, sZakPSC AS STRING, sZakTel AS STRING, sZakEmail AS STRING
    DIM sDiteJmeno AS STRING, sDitePrijmeni AS STRING, sDiteNarozeniRaw AS STRING, sDitePojistovna AS STRING, sDiteCisloPoj AS STRING, sDiteOmezeni AS STRING
    DIM sDodNazev AS STRING, sDodUlice AS STRING, sDodMesto AS STRING, sDodICO AS STRING, sDodTel AS STRING, sDodEmail AS STRING
    DIM sPrihPozn AS STRING, sZakPozn AS STRING, sDitePozn AS STRING, sDbPlavec AS STRING, sDbPlatba AS STRING
    DIM nIDDitetePrih AS LONG, dAkceCena AS DOUBLE

    sPrihVS = oResult.getString(4)
    dPrihCena = oResult.getDouble(5)
    sAkceNazev = oResult.getString(6)
    sTypAkcePrih = UCase(Trim(oResult.getString(7)))
    sAkceDatumOd = oResult.getString(8)
    sAkceDatumDo = oResult.getString(9)
    dAkceZaloha = oResult.getDouble(10)
    sZakJmeno = Trim(oResult.getString(11))
    sZakPrijmeni = Trim(oResult.getString(12))
    sZakUlice = oResult.getString(13)
    sZakMesto = oResult.getString(14)
    sZakPSC = oResult.getString(15)
    sZakTel = oResult.getString(16)
    sZakEmail = oResult.getString(17)
    sDiteJmeno = Trim(oResult.getString(18))
    sDitePrijmeni = Trim(oResult.getString(19))
    sDiteNarozeniRaw = oResult.getString(20)
    sDitePojistovna = oResult.getString(21)
    sDiteCisloPoj = oResult.getString(22)
    sDiteOmezeni = oResult.getString(23)
    sDodNazev = oResult.getString(24)
    sDodUlice = oResult.getString(25)
    sDodMesto = oResult.getString(26)
    sDodICO = oResult.getString(27)
    sDodTel = oResult.getString(28)
    sDodEmail = oResult.getString(29)
    sPrihPozn = oResult.getString(30)
    sZakPozn = oResult.getString(31)
    sDitePozn = oResult.getString(32)
    sDbPlavec = UCase(Trim(oResult.getString(33)))
    sDbPlatba = UCase(Trim(oResult.getString(34)))
    nIDDitetePrih = oResult.getLong(35)
    dAkceCena = oResult.getDouble(36)

    ' Uzavření oResult a oSt - zamezí com.sun.star.lang.DisposedException
    oResult.close()
    oSt.close()

    IF sTypAkcePrih = "BALICEK" OR sTypAkcePrih = "BALICEK_1D" OR sTypAkcePrih = "BALICEK_2D" OR sTypAkcePrih = "VYJIZDKA" THEN
        MsgBox "Pro balíčky u koní a vyjížďky na koni se přihlášky nevystavují (vystavují se pouze faktury).", 64, "Informace"
        EXIT SUB
    END IF

    DIM sSablonaP AS STRING
    IF InStr(sTypAkcePrih, "PODZIM") > 0 OR sTypAkcePrih = "PP" OR sTypAkcePrih = "PT" THEN
        sSablonaP = "Přihláška_PT.odt"
    ELSEIF InStr(sTypAkcePrih, "VIKEND") > 0 OR sTypAkcePrih = "DV" THEN
        sSablonaP = "Přihláška_DV.odt"
    ELSE
        sSablonaP = "Přihláška_LT.odt"
    END IF
    oDoc = OpenTemplate(sSablonaP)
    IF ISNULL(oDoc) OR ISEMPTY(oDoc) THEN
        oDoc = OpenTemplate("Přihláška_LT.odt")
    END IF
    IF ISNULL(oDoc) OR ISEMPTY(oDoc) THEN
        MsgBox "Nelze otevřít šablonu přihlášky (" & sSablonaP & ").", 16, "Chyba"
        EXIT SUB
    END IF

    sJm = sDiteJmeno & " " & sDitePrijmeni
    IF TRIM(sJm) = "" THEN sJm = sZakJmeno & " " & sZakPrijmeni

    sPoj = sDitePojistovna
    IF sPoj = "" THEN sPoj = "(nezadáno)"

    sZdr = sDiteOmezeni
    IF sZdr = "" THEN sZdr = "žádné"

    sDatumOd = sAkceDatumOd
    sDatumDo = sAkceDatumDo
    IF LEN(TRIM(sDatumDo)) >= 10 AND sDatumDo <> sDatumOd THEN
        sTermin = DateFromSQL(sDatumOd) & " – " & DateFromSQL(sDatumDo)
    ELSE
        sTermin = DateFromSQL(sDatumOd)
    END IF

    sRodicJmeno = sZakJmeno
    sRodicPrijmeni = sZakPrijmeni
    sRodicJm = sRodicJmeno & " " & sRodicPrijmeni
    sRodicTel = sZakTel
    sRodicEmail = sZakEmail

    sNotes = UCase(Trim(sDiteOmezeni & " " & sPrihPozn & " " & sZakPozn & " " & sDitePozn))

    ' Rozpoznání matka vs otec
    bIsMother = FALSE
    IF Right(LCase(sRodicPrijmeni), 3) = "ová" OR Right(LCase(sRodicPrijmeni), 1) = "á" THEN
        bIsMother = TRUE
    ELSE
        DIM sLastChar AS STRING
        sLastChar = Right(LCase(sRodicJmeno), 1)
        IF sLastChar = "a" OR sLastChar = "e" OR sLastChar = "i" THEN
            bIsMother = TRUE
        END IF
    END IF

    sMatkaJm = ""
    sMatkaTel = ""
    sOtecJm = ""
    sOtecTel = ""

    IF bIsMother THEN
        sMatkaJm = sRodicJm
        sMatkaTel = sRodicTel
    ELSE
        sOtecJm = sRodicJm
        sOtecTel = sRodicTel
    END IF

    ' Plavecké schopnosti dítěte (nevolíme částečného plavce automaticky, pokud není zadán)
    sPlavecP = "☐"
    sPlavecC = "☐"
    sPlavecN = "☐"
    IF InStr(sDbPlavec, "NEPLAVEC") > 0 OR InStr(sNotes, "NEPLAVEC") > 0 THEN
        sPlavecN = "☒"
    ELSEIF InStr(sDbPlavec, "ČÁSTEČ") > 0 OR InStr(sDbPlavec, "CASTEC") > 0 OR InStr(sNotes, "ČÁSTEČ") > 0 OR InStr(sNotes, "CASTEC") > 0 THEN
        sPlavecC = "☒"
    ELSEIF InStr(sDbPlavec, "PLAVEC") > 0 OR InStr(sNotes, "PLAVEC") > 0 THEN
        sPlavecP = "☒"
    END IF

    ' Způsob platby doplatku
    sPlatbaH = "☐"
    sPlatbaU = "☐"
    sPlatbaS = "☐"
    IF InStr(sDbPlatba, "HOTOV") > 0 OR InStr(sNotes, "HOTOV") > 0 THEN
        sPlatbaH = "☒"
    ELSEIF InStr(sDbPlatba, "SLOŽEN") > 0 OR InStr(sDbPlatba, "SLOZEN") > 0 OR InStr(sNotes, "SLOŽEN") > 0 OR InStr(sNotes, "SLOZEN") > 0 THEN
        sPlatbaS = "☒"
    ELSEIF InStr(sDbPlatba, "PREVOD") > 0 OR InStr(sDbPlatba, "PŘEVOD") > 0 OR InStr(sDbPlatba, "UCET") > 0 OR InStr(sDbPlatba, "ÚČET") > 0 OR InStr(sNotes, "PREVOD") > 0 OR InStr(sNotes, "PŘEVOD") > 0 THEN
        sPlatbaU = "☒"
    ELSE
        IF sSablonaP = "Přihláška_PT.odt" THEN
            sPlatbaH = "☒"
        ELSE
            sPlatbaU = "☒"
        END IF
    END IF

    sDnes = Format(Now, "d. m. yyyy")
    DIM bStavajiciZakaznik AS BOOLEAN
    DIM sZakaznikN AS STRING, sZakaznikS AS STRING
    DIM sCenaNova AS STRING, sCenaSleva AS STRING
    DIM sCenaVysledna AS STRING
    DIM dSleva AS DOUBLE, sDuvodSlevy AS STRING, dVyslednaCena AS DOUBLE

    IF dAkceCena <= 0 THEN dAkceCena = dPrihCena

    IF dAkceCena <= 0 THEN
        MsgBox "CHYBA: Akce nemá stanovenu cenu pobytu. Nastavte cenu ve formuláři F4.", 16, "Chybí cena"
        EXIT SUB
    END IF

    ' Kontrola stávajícího zákazníka z historie (opakovaná účast na táboře přináší slevu 200 Kč na letní tábor)
    bStavajiciZakaznik = FALSE
    IF nIDDitetePrih > 0 THEN
        DIM oStHist AS OBJECT, oResHist AS OBJECT, sSqlHist AS STRING
        oStHist = oConn.createStatement()
        sSqlHist = "SELECT COUNT(*) FROM " & Chr(34) & "Prihlasky" & Chr(34) & " p2 " & _
                   "JOIN " & Chr(34) & "Akce" & Chr(34) & " a2 ON p2." & Chr(34) & "ID_Akce" & Chr(34) & "=a2." & Chr(34) & "ID_Akce" & Chr(34) & " " & _
                   "WHERE p2." & Chr(34) & "ID_Ditete" & Chr(34) & "=" & nIDDitetePrih & " " & _
                   "AND p2." & Chr(34) & "ID_Prihlasky" & Chr(34) & "<>" & nIDPrih & " " & _
                   "AND p2." & Chr(34) & "Stav" & Chr(34) & " = 'POTVRZEN' " & _
                   "AND a2." & Chr(34) & "Typ_Akce" & Chr(34) & " IN ('LETNI_TABOR','DETSKY_VIKEND','PODZIMNI_PRAZDNINY')"
        ON ERROR RESUME NEXT
        oResHist = oStHist.executeQuery(sSqlHist)
        IF NOT ISNULL(oResHist) AND NOT ISEMPTY(oResHist) THEN
            IF oResHist.next() THEN
                IF oResHist.getInt(1) > 0 THEN
                    bStavajiciZakaznik = TRUE
                END IF
            END IF
            oResHist.close()
        END IF
        oStHist.close()
        ON ERROR GOTO 0
    END IF

    sCenaNova = Format(dAkceCena, "#,##0") & " Kč"
    sCenaSleva = Format(dAkceCena - 200, "#,##0") & " Kč"

    IF bStavajiciZakaznik AND sSablonaP = "Přihláška_LT.odt" THEN
        sZakaznikN = "☐"
        sZakaznikS = "☒"
        sCenaVysledna = sCenaSleva
        dSleva = 200.00
        sDuvodSlevy = "Sleva 200 Kč pro stávajícího zákazníka"
        dVyslednaCena = dAkceCena - dSleva
    ELSE
        sZakaznikN = "☒"
        sZakaznikS = "☐"
        sCenaVysledna = sCenaNova
        dSleva = 0.00
        sDuvodSlevy = ""
        dVyslednaCena = dAkceCena
    END IF

    ' Uložení základní ceny, slevy a konečné ceny do databáze Prihlasky (samostatný Statement)
    DIM oStUpd AS OBJECT
    oStUpd = oConn.createStatement()
    DIM sUpdPrih AS STRING
    sUpdPrih = "UPDATE ""Prihlasky"" SET ""Cena_Zakladni""=" & Replace(Format(dAkceCena, "0.00"), ",", ".") & _
               ", ""Sleva""=" & Replace(Format(dSleva, "0.00"), ",", ".") & _
               ", ""Cena_Celkem""=" & Replace(Format(dVyslednaCena, "0.00"), ",", ".")
    IF LEN(sDuvodSlevy) > 0 THEN
        sUpdPrih = sUpdPrih & ", ""Duvod_Slevy""='" & sDuvodSlevy & "'"
    ELSE
        sUpdPrih = sUpdPrih & ", ""Duvod_Slevy""=NULL"
    END IF
    sUpdPrih = sUpdPrih & " WHERE ""ID_Prihlasky""=" & nIDPrih
    ON ERROR RESUME NEXT
    oStUpd.executeUpdate(sUpdPrih)
    oStUpd.close()
    ON ERROR GOTO 0

    ' Nastavení UserFields v dokumentu pomocí lokálních proměnných
    SetUF oDoc, "PRIHL_DITE_JMENO",      sJm
    SetUF oDoc, "PRIHL_DITE_NAROZENI",   DateFromSQL(sDiteNarozeniRaw)
    SetUF oDoc, "PRIHL_DITE_ADRESA",     sZakUlice & ", " & sZakPSC & " " & sZakMesto
    SetUF oDoc, "PRIHL_DITE_POJISTOVNA", sPoj
    SetUF oDoc, "PRIHL_DITE_ZDRAVOTNI",  sZdr
    SetUF oDoc, "PRIHL_RODIC_JMENO",     sRodicJm
    SetUF oDoc, "PRIHL_RODIC_TEL",       sRodicTel
    SetUF oDoc, "PRIHL_RODIC_EMAIL",     sRodicEmail
    SetUF oDoc, "PRIHL_MATKA_JMENO",     sMatkaJm
    SetUF oDoc, "PRIHL_MATKA_TEL",       sMatkaTel
    SetUF oDoc, "PRIHL_OTEC_JMENO",      sOtecJm
    SetUF oDoc, "PRIHL_OTEC_TEL",        sOtecTel
    SetUF oDoc, "PRIHL_PLAVEC_P",        sPlavecP
    SetUF oDoc, "PRIHL_PLAVEC_C",        sPlavecC
    SetUF oDoc, "PRIHL_PLAVEC_N",        sPlavecN
    SetUF oDoc, "PRIHL_PLATBA_H",        sPlatbaH
    SetUF oDoc, "PRIHL_PLATBA_U",        sPlatbaU
    SetUF oDoc, "PRIHL_PLATBA_S",        sPlatbaS
    SetUF oDoc, "PRIHL_TERMIN",          sTermin
    SetUF oDoc, "PRIHL_CENA",            sCenaVysledna
    SetUF oDoc, "PRIHL_CENA_NOVA",       sCenaNova
    SetUF oDoc, "PRIHL_CENA_SLEVA",      sCenaSleva
    SetUF oDoc, "PRIHL_ZAKAZNIK_N",      sZakaznikN
    SetUF oDoc, "PRIHL_ZAKAZNIK_S",      sZakaznikS
    SetUF oDoc, "PRIHL_DATUM_VYSTAVENI", sDnes
    SetUF oDoc, "PRIHL_VS",              sPrihVS
    SetUF oDoc, "DODAVATEL_NAZEV",       sDodNazev
    SetUF oDoc, "DODAVATEL_ADRESA",      sDodUlice & ", " & sDodMesto
    SetUF oDoc, "DODAVATEL_ICO",         sDodICO
    SetUF oDoc, "DODAVATEL_TEL",         sDodTel
    SetUF oDoc, "DODAVATEL_EMAIL",       sDodEmail

    RefreshDocument(oDoc)
    oDoc.setModified(FALSE)

    sMsg = "Přihláška pro " & sJm & " (" & sTermin & ") byla úspěšně připravena."
    IF bStavajiciZakaznik AND sSablonaP = "Přihláška_LT.odt" THEN
        sMsg = sMsg & Chr(13) & "Byla uplatněna sleva 200 Kč pro stávajícího zákazníka (cena: " & sCenaVysledna & ")."
    END IF
    MsgBox sMsg, 64, "Šťastný statek"
END SUB

SUB FakturaZID(nIDFak AS LONG)
    DIM oConn AS OBJECT, oSt AS OBJECT, oResult AS OBJECT, sSQL AS STRING
    DIM fA AS STRING, fB AS STRING, fC AS STRING, fD AS STRING, fE AS STRING, fF AS STRING
    DIM fG AS STRING, fH AS STRING, fI AS STRING, fJ AS STRING
    DIM jA AS STRING, jB AS STRING, jC AS STRING, jD AS STRING, jE AS STRING, jF AS STRING
    DIM oDoc AS OBJECT, oSheet AS OBJECT
    DIM dC AS DOUBLE, sTyp AS STRING, sCislo AS STRING, sVS AS STRING
    DIM sDnes AS STRING, sSpl AS STRING, sTermin AS STRING
    DIM sSablona AS STRING, sPopis AS STRING, sFormaUhrady AS STRING
    DIM sHeaderTitle AS STRING
    DIM sMsg AS STRING

    oConn = GetConn()
    IF ISNULL(oConn) OR ISEMPTY(oConn) THEN EXIT SUB
    oSt = oConn.createStatement()

    fA = "SELECT f." & Chr(34) & "ID_Faktury" & Chr(34) & ",f." & Chr(34) & "Cislo_Faktury" & Chr(34) & ",f." & Chr(34) & "Typ_Faktury" & Chr(34) & ","
    fB = "f." & Chr(34) & "Castka" & Chr(34) & ",f." & Chr(34) & "Variabilni_Symbol" & Chr(34) & ","
    fC = "f." & Chr(34) & "Datum_Vystaveni" & Chr(34) & ",f." & Chr(34) & "Datum_Splatnosti" & Chr(34) & ","
    fD = "z." & Chr(34) & "Jmeno" & Chr(34) & ",z." & Chr(34) & "Prijmeni" & Chr(34) & ",z." & Chr(34) & "Ulice_CP" & Chr(34) & ","
    fE = "z." & Chr(34) & "Mesto" & Chr(34) & ",z." & Chr(34) & "PSC" & Chr(34) & ",z." & Chr(34) & "ICO" & Chr(34) & ",z." & Chr(34) & "DIC" & Chr(34) & ","
    fF = "d." & Chr(34) & "Jmeno" & Chr(34) & ",d." & Chr(34) & "Prijmeni" & Chr(34) & ","
    fG = "a." & Chr(34) & "Nazev" & Chr(34) & ",a." & Chr(34) & "Datum_Od" & Chr(34) & ",a." & Chr(34) & "Datum_Do" & Chr(34) & ","
    fH = "dd." & Chr(34) & "Nazev_Firmy" & Chr(34) & ",dd." & Chr(34) & "Ulice_CP" & Chr(34) & ",dd." & Chr(34) & "Mesto" & Chr(34) & ",dd." & Chr(34) & "PSC" & Chr(34) & ","
    fI = "dd." & Chr(34) & "ICO" & Chr(34) & ",dd." & Chr(34) & "DIC" & Chr(34) & ",dd." & Chr(34) & "Banka" & Chr(34) & ",dd." & Chr(34) & "Cislo_Uctu" & Chr(34) & ","
    fJ = "dd." & Chr(34) & "IBAN" & Chr(34) & ",dd." & Chr(34) & "Telefon" & Chr(34) & ",dd." & Chr(34) & "Email" & Chr(34) & ",a." & Chr(34) & "Typ_Akce" & Chr(34) & ",p." & Chr(34) & "Zpusob_Platby" & Chr(34)

    jA = " FROM " & Chr(34) & "Faktury" & Chr(34) & " f"
    jB = " JOIN " & Chr(34) & "Prihlasky" & Chr(34) & " p ON f." & Chr(34) & "ID_Prihlasky" & Chr(34) & "=p." & Chr(34) & "ID_Prihlasky" & Chr(34)
    jC = " JOIN " & Chr(34) & "Akce" & Chr(34) & " a ON p." & Chr(34) & "ID_Akce" & Chr(34) & "=a." & Chr(34) & "ID_Akce" & Chr(34)
    jD = " JOIN " & Chr(34) & "Zakaznici" & Chr(34) & " z ON p." & Chr(34) & "ID_Zakaznika" & Chr(34) & "=z." & Chr(34) & "ID_Zakaznika" & Chr(34)
    jE = " LEFT JOIN " & Chr(34) & "Deti" & Chr(34) & " d ON p." & Chr(34) & "ID_Ditete" & Chr(34) & "=d." & Chr(34) & "ID_Ditete" & Chr(34)
    jF = " LEFT JOIN " & Chr(34) & "Dodavatele" & Chr(34) & " dd ON dd." & Chr(34) & "ID_Dodavatele" & Chr(34) & "=1 WHERE f." & Chr(34) & "ID_Faktury" & Chr(34) & "=" & nIDFak

    sSQL = fA & fB & fC & fD & fE & fF & fG & fH & fI & fJ
    sSQL = sSQL & jA & jB & jC & jD & jE & jF

    oResult = oSt.executeQuery(sSQL)
    IF NOT oResult.next() THEN
        MsgBox "Faktura ID " & nIDFak & " nebyla nalezena.", 16, "Chyba"
        oResult.close()
        oSt.close()
        EXIT SUB
    END IF

    ' --- Načtení všech hodnot do lokálních proměnných IHNED po executeQuery ---
    DIM sZakJm AS STRING, sZakPrijm AS STRING, sZakUl AS STRING, sZakMe AS STRING, sZakPscCode AS STRING
    DIM sZakIcoVal AS STRING, sZakDicVal AS STRING
    DIM sDiteJmVal AS STRING, sDitePrijmVal AS STRING
    DIM sAkceNazevVal AS STRING, sDatOd AS STRING, sDatDo AS STRING
    DIM sDodNazevVal AS STRING, sDodUlVal AS STRING, sDodMeVal AS STRING, sDodPscVal AS STRING
    DIM sDodIcoVal AS STRING, sDodDicVal AS STRING, sDodBankaVal AS STRING, sDodUcetVal AS STRING
    DIM sDodIbanVal AS STRING, sDodTelVal AS STRING, sDodEmailVal AS STRING
    DIM sAkceTypVal AS STRING, sPrihPlatbaVal AS STRING

    sCislo = oResult.getString(2)
    sTyp = oResult.getString(3)
    dC = oResult.getDouble(4)
    sVS = oResult.getString(5)
    sDnes = DateFromSQL(oResult.getString(6))
    sSpl = DateFromSQL(oResult.getString(7))
    sZakJm = oResult.getString(8)
    sZakPrijm = oResult.getString(9)
    sZakUl = oResult.getString(10)
    sZakMe = oResult.getString(11)
    sZakPscCode = oResult.getString(12)
    sZakIcoVal = oResult.getString(13)
    sZakDicVal = oResult.getString(14)
    sDiteJmVal = oResult.getString(15)
    sDitePrijmVal = oResult.getString(16)
    sAkceNazevVal = oResult.getString(17)
    sDatOd = DateFromSQL(oResult.getString(18))
    sDatDo = DateFromSQL(oResult.getString(19))
    sDodNazevVal = oResult.getString(20)
    sDodUlVal = oResult.getString(21)
    sDodMeVal = oResult.getString(22)
    sDodPscVal = oResult.getString(23)
    sDodIcoVal = oResult.getString(24)
    sDodDicVal = oResult.getString(25)
    sDodBankaVal = oResult.getString(26)
    sDodUcetVal = oResult.getString(27)
    sDodIbanVal = oResult.getString(28)
    sDodTelVal = oResult.getString(29)
    sDodEmailVal = oResult.getString(30)
    sAkceTypVal = oResult.getString(31)
    sPrihPlatbaVal = oResult.getString(32)

    oResult.close()
    oSt.close()

    IF LEN(TRIM(sDatDo)) >= 10 AND sDatDo <> sDatOd THEN
        sTermin = sDatOd & " – " & sDatDo
    ELSE
        sTermin = sDatOd
    END IF

    IF sTyp = "ZALOHOVA" THEN
        sHeaderTitle = "ZÁLOHOVÁ FAKTURA"
        sPopis = "Záloha na " & sAkceNazevVal & " (termín: " & sTermin & ")"
        IF LEN(sDiteJmVal) > 0 THEN
            sPopis = sPopis & " – účastník: " & sDiteJmVal & " " & sDitePrijmVal
        END IF
    ELSEIF sTyp = "CELKOVA" THEN
        sHeaderTitle = "FAKTURA – DAŇOVÝ DOKLAD"
        sPopis = "Fakturujeme Vám: " & sAkceNazevVal & " (termín: " & sTermin & ")"
        IF LEN(sDiteJmVal) > 0 THEN
            sPopis = sPopis & " – účastník: " & sDiteJmVal & " " & sDitePrijmVal
        END IF
    ELSE
        sHeaderTitle = "DOPLATKOVÁ FAKTURA"
        sPopis = "Doplatek na " & sAkceNazevVal & " (termín: " & sTermin & ")"
        IF LEN(sDiteJmVal) > 0 THEN
            sPopis = sPopis & " – účastník: " & sDiteJmVal & " " & sDitePrijmVal
        END IF
    END IF

    sFormaUhrady = "převodem na účet"
    IF InStr(UCase(sPrihPlatbaVal), "HOTOV") > 0 THEN
        sFormaUhrady = "v hotovosti"
    END IF

    sSablona = "Faktura_vzor.ods"
    oDoc = OpenTemplate(sSablona)
    IF ISNULL(oDoc) OR ISEMPTY(oDoc) THEN
        sSablona = "Faktura_vzor.odt"
        oDoc = OpenTemplate(sSablona)
    END IF
    IF ISNULL(oDoc) OR ISEMPTY(oDoc) THEN
        MsgBox "Nelze otevřít šablonu faktury.", 16, "Chyba"
        EXIT SUB
    END IF

    IF Right(sSablona, 3) = "ods" THEN
        oSheet = oDoc.getSheets().getByIndex(0)
        oSheet.getCellByPosition(1, 1).setString(sHeaderTitle)
        oSheet.getCellByPosition(8, 1).setString(sCislo)

        oSheet.getCellByPosition(1, 4).setString(sDodNazevVal)
        oSheet.getCellByPosition(1, 5).setString(sDodUlVal)
        oSheet.getCellByPosition(1, 6).setString(sDodPscVal & " " & sDodMeVal)
        oSheet.getCellByPosition(1, 7).setString("IČ: " & sDodIcoVal & "   DIČ: " & sDodDicVal)
        oSheet.getCellByPosition(1, 8).setString("Tel: " & sDodTelVal & "   E-mail: " & sDodEmailVal)

        oSheet.getCellByPosition(1, 11).setString(sDodBankaVal)
        oSheet.getCellByPosition(1, 12).setString(sDodUcetVal)
        oSheet.getCellByPosition(1, 13).setString(sDodIbanVal)

        oSheet.getCellByPosition(5, 4).setString(sZakJm & " " & sZakPrijm)
        oSheet.getCellByPosition(5, 5).setString(sZakUl)
        oSheet.getCellByPosition(5, 6).setString(sZakPscCode & " " & sZakMe)
        IF LEN(sZakIcoVal) > 0 THEN
            oSheet.getCellByPosition(5, 7).setString("IČ: " & sZakIcoVal & "   DIČ: " & sZakDicVal)
        END IF

        oSheet.getCellByPosition(8, 14).setString(sVS)
        oSheet.getCellByPosition(8, 15).setString(sSpl)
        oSheet.getCellByPosition(8, 16).setString(sFormaUhrady)
        oSheet.getCellByPosition(8, 17).setString(sDnes)
        oSheet.getCellByPosition(8, 18).setString(sDnes)
        oSheet.getCellByPosition(8, 19).setString(sDnes)

        oSheet.getCellByPosition(1, 21).setString(sPopis)
        oSheet.getCellByPosition(5, 35).setValue(dC)
        oSheet.getCellByPosition(8, 35).setValue(dC)
        oSheet.getCellByPosition(5, 38).setValue(dC)
        oSheet.getCellByPosition(8, 38).setValue(dC)
        oSheet.getCellByPosition(1, 40).setString("V Provodíně " & sDnes)
        oSheet.getCellByPosition(8, 44).setValue(dC)

        ' --- Generování a vložení QR kódu pro QR platbu (ČBA / SPAYD standard) ---
        DIM sIBAN AS STRING, sDitePrijmeni AS STRING
        DIM sQrPath AS STRING, sScriptQR AS STRING, sParamQR AS STRING
        DIM oDrawPage AS OBJECT, oShape AS OBJECT, iShp AS INTEGER
        DIM bQrFound AS BOOLEAN
        
        sIBAN = Replace(Replace(sDodIbanVal, " ", ""), "-", "")
        sDitePrijmeni = sDitePrijmVal
        IF LEN(sDitePrijmeni) = 0 THEN sDitePrijmeni = sZakPrijm
        
        sScriptQR = GetBaseFolder() & "scripts/generate_qr.py"
        sQrPath = GetBaseFolder() & "Dokumenty/qr_faktura_" & sCislo & ".png"

        IF FileExists(sQrPath) THEN
            ON ERROR RESUME NEXT
            Kill sQrPath
            ON ERROR GOTO 0
        END IF
        
        sParamQR = sScriptQR & " --iban " & Chr(34) & sIBAN & Chr(34) & _
                   " --amount " & Replace(Format(dC, "0.00"), ",", ".") & _
                   " --vs " & Chr(34) & sVS & Chr(34) & _
                   " --msg " & Chr(34) & sCislo & " " & sDitePrijmeni & Chr(34) & _
                   " --output " & Chr(34) & sQrPath & Chr(34)
                   
        DIM nRetQR AS LONG
        nRetQR = Shell("python3", 0, sParamQR, TRUE)
        
        oSheet.getCellByPosition(1, 42).setString("QR platba")
        
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

            IF NOT bQrFound THEN
                DIM oQrPoint AS NEW com.sun.star.awt.Point
                DIM oQrSize AS NEW com.sun.star.awt.Size
                oShape = oDoc.createInstance("com.sun.star.drawing.GraphicObjectShape")
                oShape.setName("QR_Platba")
                oQrPoint.X = 2200
                oQrPoint.Y = 21500
                oQrSize.Width = 3400
                oQrSize.Height = 3400
                oShape.setPosition(oQrPoint)
                oShape.setSize(oQrSize)
                oShape.GraphicURL = ConvertToURL(sQrPath)
                oDrawPage.add(oShape)
            END IF
        ELSE
            MsgBox "Upozornění: QR kód pro fakturu " & sCislo & " se nepodařilo vygenerovat (" & sQrPath & ")." & Chr(13) & "Zkontrolujte skript " & sScriptQR, 48, "QR platba"
        END IF

        oDoc.setModified(FALSE)
    ELSE
        SetUF oDoc, "FAK_CISLO",      sCislo
        SetUF oDoc, "FAK_TYP",        sTyp
        SetUF oDoc, "FAK_DATUM_VYS",  sDnes
        SetUF oDoc, "FAK_SPLATNOST",  sSpl
        SetUF oDoc, "FAK_VS",         sVS
        SetUF oDoc, "FAK_CASTKA",     Format(dC, "#,##0.00") & " Kč"
        SetUF oDoc, "ZAK_JMENO",      sZakJm
        SetUF oDoc, "ZAK_PRIJMENI",   sZakPrijm
        SetUF oDoc, "ZAK_ULICE",      sZakUl
        SetUF oDoc, "ZAK_MESTO",      sZakMe
        SetUF oDoc, "ZAK_PSC",        sZakPscCode
        SetUF oDoc, "FAK_POPIS",       sPopis
        SetUF oDoc, "DOD_NAZEV",      sDodNazevVal
        SetUF oDoc, "DOD_ULICE",      sDodUlVal
        SetUF oDoc, "DOD_MESTO",      sDodMeVal
        SetUF oDoc, "DOD_PSC",        sDodPscVal
        SetUF oDoc, "DOD_ICO",        sDodIcoVal
        SetUF oDoc, "DOD_DIC",        sDodDicVal
        SetUF oDoc, "DOD_BANKA",      sDodBankaVal
        SetUF oDoc, "DOD_UCET",       sDodUcetVal
        SetUF oDoc, "DOD_IBAN",       sDodIbanVal
        SetUF oDoc, "FAK_FORMA_UHRADY", sFormaUhrady
        SetUF oDoc, "FAK_TERMIN",     sTermin
        RefreshDocument(oDoc)
        oDoc.setModified(FALSE)
    END IF

    MsgBox "Faktura " & sCislo & " (" & Format(dC, "#,##0.00") & " Kč) byla úspěšně otevřena.", 64, "Šťastný statek"
END SUB

SUB OznacitBezinfekcnost(OPTIONAL oEvent AS OBJECT)
    DIM sID AS STRING
    DIM nID AS LONG
    DIM oConn AS OBJECT
    DIM oSt AS OBJECT
    DIM sDnes AS STRING
    DIM oForm AS OBJECT
    DIM nIDDitete AS LONG
    DIM oRes AS OBJECT

    nID = 0
    ' 1. Pokus o načtení ID přihlášky z aktuálního formuláře F5
    IF NOT IsMissing(oEvent) AND NOT IsNull(oEvent) THEN
        ON ERROR RESUME NEXT
        oForm = oEvent.Source.Model.Parent
        IF NOT IsNull(oForm) THEN
            IF oForm.Columns.hasByName("ID_Prihlasky") THEN
                nID = oForm.Columns.getByName("ID_Prihlasky").getLong()
            END IF
        END IF
        ON ERROR GOTO 0
    END IF

    ' 2. Pokud ID nebylo získáno z formuláře, dotážeme se uživatele
    IF nID <= 0 THEN
        sID = InputBox("Zadejte ID přihlášky (z formuláře F5 nebo F4):", "Označit bezinfekčnost pro turnus", "")
        IF sID = "" THEN EXIT SUB
        nID = VAL(sID)
    END IF

    IF nID <= 0 THEN
        MsgBox "Neplatné ID přihlášky.", 16, "Chyba"
        EXIT SUB
    END IF

    oConn = GetConn()
    IF ISNULL(oConn) OR ISEMPTY(oConn) THEN EXIT SUB
    oSt = oConn.createStatement()
    sDnes = Format(Date, "YYYY-MM-DD")

    ' Zjištění dítěte z přihlášky
    nIDDitete = 0
    oRes = oSt.executeQuery("SELECT ""ID_Ditete"" FROM ""Prihlasky"" WHERE ""ID_Prihlasky""=" & nID)
    IF oRes.next() THEN
        nIDDitete = oRes.getLong(1)
    END IF
    oRes.close()

    ' Bezinfekčnost je vázána na konkrétní přihlášku / turnus!
    oSt.executeUpdate("UPDATE ""Prihlasky"" SET ""Bezinfekcnost""=1,""Datum_Bezinf""='" & sDnes & "' WHERE ""ID_Prihlasky""=" & nID)

    ' Datum na kartě dítěte zaznamenáváme jako informativní datum posledního odevzdání
    IF nIDDitete > 0 THEN
        oSt.executeUpdate("UPDATE ""Deti"" SET ""Datum_Bezinf""='" & sDnes & "' WHERE ""ID_Ditete""=" & nIDDitete)
    END IF
    oSt.close()

    ' Reload formuláře, pokud je otevřen
    IF NOT IsNull(oForm) THEN
        ON ERROR RESUME NEXT
        oForm.reload()
        ON ERROR GOTO 0
    END IF

    MsgBox "Bezinfekčnost pro přihlášku ID " & nID & " byla úspěšně označena dne " & DateFromSQL(sDnes) & ".", 64, "Šťastný statek"
END SUB

SUB ZalohovatData()
    DIM sBaseDir AS STRING, sBashScript AS STRING, sStamp AS STRING
    DIM sTargetFile AS STRING, sSrc AS STRING, sLatestFile AS STRING
    sBaseDir = GetBaseFolder()
    sBashScript = sBaseDir & "zalohovat.sh"

    ON ERROR GOTO ErrZal
    IF FileExists(sBashScript) THEN
        Shell("bash", 0, Chr(34) & sBashScript & Chr(34), TRUE)
        sLatestFile = sBaseDir & "ZAL/latest/Stastny_statek.odb"
        IF NOT FileExists(sLatestFile) THEN sLatestFile = sBaseDir & "ZAL/latest/Šťastný_statek.odb"
        IF FileExists(sLatestFile) THEN
            MsgBox "Kompletní záloha projektu (ZIP archiv v adresáři ZAL/ i kopie v ZAL/latest/) byla úspěšně vytvořena a ověřena.", 64, "Zálohování – Šťastný statek"
        ELSE
            MsgBox "Zálohovací skript doběhl, zkontrolujte složku ZAL/.", 64, "Zálohování – Šťastný statek"
        END IF
        EXIT SUB
    END IF

    sStamp = Format(Now, "YYYY-MM-DD_hh-mm-ss")
    sTargetFile = sBaseDir & "ZAL/Šťastný_statek_" & sStamp & ".odb"
    sSrc = sBaseDir & "Šťastný_statek.odb"
    IF NOT FileExists(sSrc) THEN sSrc = sBaseDir & "Stastny_statek.odb"
    FileCopy sSrc, sTargetFile
    MsgBox "Rychlá záloha databáze byla úspěšně vytvořena:" & Chr(13) & sTargetFile, 64, "Zálohování – Šťastný statek"
    EXIT SUB

ErrZal:
    MsgBox "Chyba při zálohování: " & Error$, 16, "Chyba zálohování"
END SUB
