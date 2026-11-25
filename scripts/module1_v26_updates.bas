' ==============================================================================
' Modul maker v2.6 - Aktualizované a opravené procedury pro Šťastný statek
' ==============================================================================

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

    ' Proměnné pro kontrolu již vystavených faktur k přihlášce (ochrana před duplicitami)
    DIM sExSQL AS STRING
    DIM oExRes AS OBJECT
    DIM nCountZal AS INTEGER, nCountDop AS INTEGER, nCountCelk AS INTEGER
    DIM dFakturovanoZal AS DOUBLE, dFakturovanoCelk AS DOUBLE
    DIM sPosledniFakZal AS STRING, sPosledniFakDop AS STRING

    oConn = GetConn()
    IF ISNULL(oConn) OR ISEMPTY(oConn) THEN EXIT SUB

    IF sTypFaktury = "ZALOHOVA" THEN
        sLabel = "zálohovou"
    ELSEIF sTypFaktury = "CELKOVA" THEN
        sLabel = "celkovou"
    ELSE
        sLabel = "doplatkovou"
    END IF

    ' 1. Pokus o získání ID přihlášky z aktuálního kontextu formuláře F5
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

    ' 2. Pokud není přihláška vybrána z formuláře, otevřeme výběrový dialog
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

    ' Kontrola délky variabilního symbolu (bankovní standard max 10 číslic)
    IF LEN(sVS) > 10 THEN
        MsgBox "CHYBA: Variabilní symbol '" & sVS & "' má délku " & LEN(sVS) & " číslic." & Chr(13) & _
               "Bankovní standard ČR (SPAYD / X-VS) povoluje maximálně 10 číslic." & Chr(13) & _
               "Opravte variabilní symbol na kartě přihlášky (doporučeno: 8 číslic DDMMRRRR) před vystavením faktury.", 16, "Neplatný variabilní symbol"
        EXIT SUB
    END IF

    ' Kontrola stávajících vystavených faktur k této přihlášce
    nCountZal = 0
    nCountDop = 0
    nCountCelk = 0
    dFakturovanoZal = 0.0
    dFakturovanoCelk = 0.0
    sPosledniFakZal = ""
    sPosledniFakDop = ""

    sExSQL = "SELECT ""Typ_Faktury"", ""Cislo_Faktury"", ""Castka"" FROM ""Faktury"" WHERE ""ID_Prihlasky""=" & nIDPrih
    oExRes = oSt.executeQuery(sExSQL)
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
        END IF
    LOOP

    sDnes = Format(Date, "YYYY-MM-DD")
    sSpl  = Format(Date + 14, "YYYY-MM-DD")

    IF sTypFaktury = "ZALOHOVA" THEN
        ' Striktní zákaz duplicitní zálohy
        IF nCountZal > 0 THEN
            MsgBox "CHYBA: Pro přihlášku ID " & nIDPrih & " již zálohová faktura existuje (" & sPosledniFakZal & " ve výši " & Format(dFakturovanoZal, "#,##0.00") & " Kč)." & Chr(13) & _
                   "Vystavení duplicitní zálohové faktury je zakázáno.", 16, "Duplicita zálohy"
            EXIT SUB
        END IF
        IF nCountCelk > 0 THEN
            MsgBox "CHYBA: K této přihlášce již byla vystavena celková faktura. Zálohu nelze vystavit.", 16, "Nelze vystavit zálohu"
            EXIT SUB
        END IF
        dCastka = dZaloha
        ' Respektování termínu splatnosti z formuláře F4 (Akce.Zalohova_Spl)
        IF LEN(sZalohaSpl) >= 10 THEN
            sSpl = sZalohaSpl
        END IF

    ELSEIF sTypFaktury = "CELKOVA" THEN
        ' Striktní zákaz celkové faktury, pokud už existují doklady
        IF dFakturovanoCelk > 0 THEN
            MsgBox "CHYBA: Pro přihlášku ID " & nIDPrih & " již existují vystavené faktury ve výši " & Format(dFakturovanoCelk, "#,##0.00") & " Kč." & Chr(13) & _
                   "Celkovou fakturu nelze kombinovat s již vystavenou zálohou či doplatkem.", 16, "Nelze vystavit celkovou fakturu"
            EXIT SUB
        END IF
        dCastka = dCelkem

    ELSE ' DOPLATKOVA
        ' Striktní zákaz duplicitního doplatku
        IF nCountDop > 0 THEN
            MsgBox "CHYBA: Pro přihlášku ID " & nIDPrih & " již doplatková faktura existuje (" & sPosledniFakDop & ")." & Chr(13) & _
                   "Vystavení duplicitního doplatku je zakázáno.", 16, "Duplicita doplatku"
            EXIT SUB
        END IF
        IF (dCelkem - dFakturovanoCelk) <= 0 THEN
            MsgBox "CHYBA: Celková cena pobytu (" & Format(dCelkem, "#,##0.00") & " Kč) je již plně pokryta vystavenými fakturami (" & Format(dFakturovanoCelk, "#,##0.00") & " Kč)." & Chr(13) & _
                   "Žádná částka k vyfakturování nezbývá.", 16, "Doplatek nelze vystavit"
            EXIT SUB
        END IF
        dCastka = dCelkem - dFakturovanoCelk

        ' Splatnost doplatku: 14 dní před začátkem akce (pokud do akce zbývá > 14 dní), jinak za 14 dní
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

    ' Bezpečné číslování faktur: nalezení maxima v daném roce formátu FAK-RRRR-NNN
    sRok = Format(Year(Date), "0000")
    sSQL = "SELECT MAX(""Cislo_Faktury"") FROM ""Faktury"" WHERE ""Cislo_Faktury"" LIKE 'FAK-" & sRok & "-%'"
    oResult = oSt.executeQuery(sSQL)
    nNext = 1
    IF oResult.next() THEN
        DIM sMaxCislo AS STRING
        sMaxCislo = oResult.getString(1)
        IF LEN(sMaxCislo) >= 12 THEN
            DIM sNumPart AS STRING
            sNumPart = Mid(sMaxCislo, 10)
            nNext = VAL(sNumPart) + 1
        END IF
    END IF
    sCislo = "FAK-" & sRok & "-" & Format(nNext, "000")

    sIns = "INSERT INTO ""Faktury"""
    sIns = sIns & " (""ID_Prihlasky"",""Typ_Faktury"",""Cislo_Faktury"","
    sIns = sIns & """Castka"",""Castka_Zaplaceno"",""Datum_Vystaveni"",""Datum_Splatnosti"","
    sIns = sIns & """Uhrazeno"",""Variabilni_Symbol"")"
    sIns = sIns & " VALUES (" & nIDPrih & ",'" & sTypFaktury & "','" & sCislo & "',"
    sIns = sIns & Replace(Format(dCastka, "0.00"), ",", ".") & ",0,'" & sDnes & "','" & sSpl & "',0,'" & sVS & "')"
    oSt.executeUpdate(sIns)

    ' Automatický reload podformuláře Faktury ve formuláři F5, pokud je otevřen
    IF NOT IsMissing(oEvent) AND NOT IsNull(oEvent) THEN
        ON ERROR RESUME NEXT
        IF NOT IsNull(oForm) THEN
            IF oForm.hasByName("SubForm") THEN
                oForm.getByName("SubForm").reload()
            END IF
        END IF
        ON ERROR GOTO 0
    END IF

    sSQL = "SELECT ""ID_Faktury"" FROM ""Faktury"""
    sSQL = sSQL & " WHERE ""Cislo_Faktury""='" & sCislo & "'"
    oResult = oSt.executeQuery(sSQL)
    nIDFak = 0
    IF oResult.next() THEN nIDFak = oResult.getLong(1)

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
    
    ' Pro fakturaci vylučujeme STORNO i NAHRADNIK; pro tisk vylučujeme STORNO
    IF InStr(LCase(sTitle), "faktur") > 0 OR InStr(LCase(sTitle), "vystavit") > 0 THEN
        sSQL = sSQL & " WHERE p." & Chr(34) & "Stav" & Chr(34) & " NOT IN ('STORNO', 'NAHRADNIK')"
    ELSE
        sSQL = sSQL & " WHERE p." & Chr(34) & "Stav" & Chr(34) & " <> 'STORNO'"
    END IF

    IF InStr(LCase(sTitle), "k tisku") > 0 OR (InStr(LCase(sTitle), "prihlask") > 0 AND InStr(LCase(sTitle), "faktur") = 0) THEN
        sSQL = sSQL & " AND a." & Chr(34) & "Typ_Akce" & Chr(34) & " NOT IN ('BALICEK_1D', 'BALICEK_2D', 'VYJIZDKA')"
    END IF
    sSQL = sSQL & " ORDER BY a." & Chr(34) & "Datum_Od" & Chr(34) & " DESC"
    sSQL = sSQL & ", z." & Chr(34) & "Prijmeni" & Chr(34)

    ON ERROR RESUME NEXT
    oRes = oSt.executeQuery(sSQL)
    ON ERROR GOTO 0
    IF ISNULL(oRes) OR ISEMPTY(oRes) THEN
        MsgBox "Chyba při načítání přihlášek.", 16, "Chyba"
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

    IF nCount = 0 THEN
        MsgBox "Žádné vyhovující přihlášky nebyly nalezeny.", 48, sTitle
        VybratPrihlaskuSeznamu = 0
        EXIT FUNCTION
    END IF

    ' Build dialog
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
    ' Pokus o načtení ID přihlášky z aktuálního formuláře F5
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

    ' Bezinfekčnost je vázána na konkrétní přihlášku / turnus!
    oSt.executeUpdate("UPDATE ""Prihlasky"" SET ""Bezinfekcnost""=1,""Datum_Bezinf""='" & sDnes & "' WHERE ""ID_Prihlasky""=" & nID)

    ' Datum na kartě dítěte zaznamenáváme jako informativní datum posledního odevzdání
    IF nIDDitete > 0 THEN
        oSt.executeUpdate("UPDATE ""Deti"" SET ""Datum_Bezinf""='" & sDnes & "' WHERE ""ID_Ditete""=" & nIDDitete)
    END IF

    ' Reload formuláře, pokud je otevřen
    IF NOT IsNull(oForm) THEN
        ON ERROR RESUME NEXT
        oForm.reload()
        ON ERROR GOTO 0
    END IF

    MsgBox "Bezinfekčnost pro přihlášku ID " & nID & " byla úspěšně označena dne " & sDnes & ".", 64, "Šťastný statek"
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
