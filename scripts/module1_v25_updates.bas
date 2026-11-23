' ==============================================================================
' Modul maker v2.5 - Aktualizované a opravené procedury pro Šťastný statek
' ==============================================================================

SUB VytvoritFakturu(sTypFaktury AS STRING)
    DIM oConn AS OBJECT
    DIM oSt AS OBJECT
    DIM oResult AS OBJECT
    DIM sSQL AS STRING
    DIM sLabel AS STRING
    DIM sIDPrih AS STRING
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
    DIM nIDFak AS LONG
    DIM bAno AS INTEGER
    DIM sIns AS STRING
    DIM sMsg AS STRING

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

    nIDPrih = VybratPrihlaskuSeznamu("Vystavit " & sLabel & " fakturu - vyberte přihlášku")
    IF nIDPrih <= 0 THEN EXIT SUB

    oSt = oConn.createStatement()

    ' Načtení údajů o přihlášce a akci (včetně data splatnosti zálohy a začátku akce)
    sSQL = "SELECT p.""Cena_Celkem"",a.""Zalohova_Castka"",p.""Variabilni_Symbol"",a.""Zalohova_Spl"",a.""Datum_Od"""
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
    sVS = oResult.getString(3)
    sZalohaSpl = ""
    sDatumOd = ""
    ON ERROR RESUME NEXT
    sZalohaSpl = DateFromSQL(oResult.getString(4))
    sDatumOd   = DateFromSQL(oResult.getString(5))
    ON ERROR GOTO 0

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
        IF nCountZal > 0 THEN
            bAno = MsgBox("UPOZORNĚNÍ: Pro přihlášku ID " & nIDPrih & " již existuje zálohová faktura č. " & sPosledniFakZal & Chr(13) & _
                          "(již vyfakturováno na zálohách: " & Format(dFakturovanoZal, "#,##0.00") & " Kč)." & Chr(13) & Chr(13) & _
                          "Přejete si přesto vystavit další zálohovou fakturu?", 36, "Možná duplicita zálohy")
            IF bAno <> 6 THEN EXIT SUB
        END IF
        dCastka = dZaloha
        ' Respektování termínu splatnosti z formuláře F4 (Akce.Zalohova_Spl)
        IF LEN(sZalohaSpl) >= 10 THEN
            sSpl = sZalohaSpl
        END IF

    ELSEIF sTypFaktury = "CELKOVA" THEN
        IF dFakturovanoCelk > 0 THEN
            bAno = MsgBox("UPOZORNĚNÍ: Pro přihlášku ID " & nIDPrih & " již existují faktury ve výši " & Format(dFakturovanoCelk, "#,##0.00") & " Kč." & Chr(13) & Chr(13) & _
                          "Přejete si přesto vystavit celkovou fakturu?", 36, "Možná duplicita faktury")
            IF bAno <> 6 THEN EXIT SUB
        END IF
        dCastka = dCelkem

    ELSE ' DOPLATKOVA
        IF nCountDop > 0 THEN
            bAno = MsgBox("UPOZORNĚNÍ: Pro přihlášku ID " & nIDPrih & " již existuje doplatková faktura č. " & sPosledniFakDop & "." & Chr(13) & Chr(13) & _
                          "Přejete si přesto vystavit další doplatkovou fakturu?", 36, "Možná duplicita doplatku")
            IF bAno <> 6 THEN EXIT SUB
        END IF
        ' Skutečný doplatek = celková cena mínus již dosud vyfakturované částky
        dCastka = dCelkem - dFakturovanoCelk
        IF dCastka <= 0 THEN
            bAno = MsgBox("Přihláška ID " & nIDPrih & " má již celou částku plně vyfakturovanou!" & Chr(13) & _
                          "(Cena: " & Format(dCelkem, "#,##0.00") & " Kč, již vyfakturováno: " & Format(dFakturovanoCelk, "#,##0.00") & " Kč, zbývá: 0 Kč)." & Chr(13) & Chr(13) & _
                          "Přejete si přesto vystavit další fakturu s vlastní částkou?", 36, "Plně vyfakturováno")
            IF bAno <> 6 THEN EXIT SUB
            dCastka = 0.0
        END IF
        ' Splatnost doplatku: standardně 14 dní před začátkem akce (pokud ještě nenastalo), jinak za 14 dní
        IF LEN(sDatumOd) >= 10 THEN
            DIM dTerminAkce AS DATE
            dTerminAkce = DateValue(sDatumOd)
            IF (dTerminAkce - 14) > Date THEN
                sSpl = Format(dTerminAkce - 14, "YYYY-MM-DD")
            END IF
        END IF
    END IF

    DIM sUserCastka AS STRING
    sUserCastka = InputBox("Potvrďte nebo upravte částku pro " & sLabel & " fakturu (Kč):", "Částka faktury", CStr(Int(dCastka)))
    IF sUserCastka = "" THEN EXIT SUB
    dCastka = VAL(Replace(sUserCastka, ",", "."))
    IF dCastka <= 0 THEN
        MsgBox "Neplatná částka.", 16, "Chyba"
        EXIT SUB
    END IF

    ' Bezpečné číslování faktur: nalezení maxima v daném roce namísto COUNT(*)
    sRok = Format(Year(Date), "0000")
    sSQL = "SELECT ""Cislo_Faktury"" FROM ""Faktury"" WHERE ""Cislo_Faktury"" LIKE '" & sRok & "-%' ORDER BY ""Cislo_Faktury"" DESC"
    oResult = oSt.executeQuery(sSQL)
    nNext = 1
    IF oResult.next() THEN
        DIM sMaxCislo AS STRING
        sMaxCislo = oResult.getString(1)
        DIM nPom AS INTEGER
        nPom = InStr(sMaxCislo, "-")
        IF nPom > 0 THEN
            nNext = VAL(Mid(sMaxCislo, nPom + 1)) + 1
        END IF
    END IF
    sCislo = sRok & "-" & Format(nNext, "0000")

    sIns = "INSERT INTO ""Faktury"""
    sIns = sIns & " (""ID_Prihlasky"",""Typ_Faktury"",""Cislo_Faktury"","
    sIns = sIns & """Castka"",""Castka_Zaplaceno"",""Datum_Vystaveni"",""Datum_Splatnosti"","
    sIns = sIns & """Uhrazeno"",""Variabilni_Symbol"")"
    sIns = sIns & " VALUES (" & nIDPrih & ",'" & sTypFaktury & "','" & sCislo & "',"
    sIns = sIns & Replace(Format(dCastka, "0.00"), ",", ".") & ",0,'" & sDnes & "','" & sSpl & "',0,'" & sVS & "')"
    oSt.executeUpdate(sIns)

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
    oResult = oSt.executeQuery("SELECT ""Cislo_Faktury"" FROM ""Faktury"" WHERE ""Cislo_Faktury"" LIKE '" & sRok & "-%' ORDER BY ""Cislo_Faktury"" DESC")
    nNext = 1
    IF oResult.next() THEN
        DIM sMaxCislo AS STRING
        sMaxCislo = oResult.getString(1)
        DIM nPom AS INTEGER
        nPom = InStr(sMaxCislo, "-")
        IF nPom > 0 THEN
            nNext = VAL(Mid(sMaxCislo, nPom + 1)) + 1
        END IF
    END IF

    MsgBox "Příští číslo faktury: " & sRok & "-" & Format(nNext, "0000"), 64, "Šťastný statek"
END SUB

SUB OznacitBezinfekcnost()
    DIM sID AS STRING
    DIM nID AS LONG
    DIM oConn AS OBJECT
    DIM oSt AS OBJECT
    DIM sDnes AS STRING

    sID = InputBox("ID dítěte (z formuláře F2 nebo F5):", "Označit bezinfekčnost", "")
    IF sID = "" THEN EXIT SUB
    nID = VAL(sID)
    IF nID <= 0 THEN
        MsgBox "Neplatné ID dítěte.", 16, "Chyba"
        EXIT SUB
    END IF

    oConn = GetConn()
    IF ISNULL(oConn) OR ISEMPTY(oConn) THEN EXIT SUB
    oSt = oConn.createStatement()
    sDnes = Format(Date, "YYYY-MM-DD")
    ' Aktualizace v evidenci dítěte i na všech aktivních přihláškách daného dítěte
    oSt.executeUpdate("UPDATE ""Deti"" SET ""Bezinfekcnost""=1,""Datum_Bezinf""='" & sDnes & "' WHERE ""ID_Ditete""=" & nID)
    oSt.executeUpdate("UPDATE ""Prihlasky"" SET ""Bezinfekcnost""=1,""Datum_Bezinf""='" & sDnes & "' WHERE ""ID_Ditete""=" & nID & " AND ""Stav"" NOT IN ('STORNO')")
    MsgBox "Bezinfekčnost dítěte ID " & nID & " byla úspěšně označena dne " & sDnes & " (v evidenci dětí i na přihláškách).", 64, "Šťastný statek"
END SUB

SUB ZalohovatData()
    DIM sBaseDir AS STRING, sBashScript AS STRING, sStamp AS STRING
    DIM sTargetFile AS STRING, sSrc AS STRING
    sBaseDir = GetBaseFolder()
    sBashScript = sBaseDir & "zalohovat.sh"

    ON ERROR GOTO ErrZal
    IF FileExists(sBashScript) THEN
        Shell("bash", 0, Chr(34) & sBashScript & Chr(34), TRUE)
        MsgBox "Kompletní záloha projektu (ZIP archiv v adresáři ZAL/) byla úspěšně vytvořena.", 64, "Zálohování – Šťastný statek"
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
