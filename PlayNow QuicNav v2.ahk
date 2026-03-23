#Requires AutoHotkey v2.0 
#warn all, off
#SingleInstance Force
SetTitleMatchMode 2

; ==============================================================================
; SEKCJA 0: INICJALIZACJA I IKONA
; ==============================================================================
global FolderProjektu := A_ScriptDir
global FolderData := FolderProjektu "\Data"
global FolderLoga := FolderData "\Loga"

try {
    TraySetIcon(FolderLoga . "\PlayNow QuickNav.ico")
} catch {
}

; ==============================================================================
; SEKCJA 1: KONFIGURACJA GLOBALNA
; ==============================================================================
global NazwaProjektu := "Play Now QuickNav"
global FolderProjektu := ZnajdzFolderQuickNav()
global FolderData := FolderProjektu "\Data"
global FolderLoga := FolderData "\Loga"
global EpgPlik := FolderData "\epg.xml"
global Indeks := 1             
global StartWidoku := 1        
global MaxSlotow := 30         
global MyGui := 0              
global EpgGui := 0             
global OpisGui := 0            
global Przyciski := []         
global EPG_Cache := Map()
global TrybNav := "Lista"      
global WyborEPG := 1           
global OpisSegmenty := []
global MaxLiniiOpisu := 20
global StartLiniiOpisu := 1
global PelnaTrescOpisu := []

if !DirExist(FolderData)
    DirCreate(FolderData)
if !DirExist(FolderLoga)
    DirCreate(FolderLoga)

; ==============================================================================
; SEKCJA 3: DEFINICJA GRUPY PRZEGLĄDAREK
; ==============================================================================
GroupAdd "Obslugiwane", "ahk_exe brave.exe"
GroupAdd "Obslugiwane", "ahk_exe chrome.exe"
GroupAdd "Obslugiwane", "ahk_exe msedge.exe"
GroupAdd "Obslugiwane", "ahk_exe opera.exe"

; ==============================================================================
; SEKCJA 4: BIBLIOTEKA KANAŁÓW
; ==============================================================================
global Kanaly := [
    ["TVP 1", 8499963, "TVP 1"], ["TVP 2", 8499964, "TVP 2"], ["TVN", 8529876, "TVN"],
    ["Polsat", 9817820, "Polsat"], ["TV 4", 26558451, "TV 4"], ["Puls", 7033022, "TV Puls"],
    ["TTV", 20183305, "TTV"], ["Metro", 20183300, "METRO"], ["Puls 2", 7033023, "Puls 2"],
    ["TV 6", 20183324, "TV 6"], ["Polsat Sport 1", 20183318, "Polsat Sport 1"], ["Travel Channel", 20183304, "Travel Channel"],
    ["TVN Fabuła", 20183307, "TVN Fabuła"], ["Polsat Sport 2", 20183319, "Polsat Sport 2"], ["VOX TV", 20183325, "Vox Music TV"],
    ["Polsat News 2", 20183313, "Polsat News 2"], ["Wydarzenia 24", 20183323, "Wydarzenia 24"], ["Polsat Play", 20183314, "Polsat Play"],
    ["Super Polsat", 20183322, "Super Polsat"], ["Zoom TV", 2380751, "ZOOM TV"], ["TVN Turbo", 20183309, "TVN Turbo"],
    ["Comedy Central", 22, "Comedy Central"], ["Paramount Network", 38023, "Paramount Channel"], ["AXN", 33, "AXN"],
    ["AXN Black", 9234615, "AXN Black"], ["Ale Kino+", 13532285, "Ale Kino+"], ["Stopklatka", 2476979, "Stopklatka TV"],
    ["FX", 3239191, "FX"], ["National Geographic", 3239192, "National Geographic Channel"], ["Discovery", 20183289, "Discovery Channel"],
    ["JimJam", 4, "Polsat JimJam"], ["Cartoon Network", 36018, "Cartoon Network"], 
    ["Disney XD", 4231073, "Disney XD"], ["4kids", 3452690, "Disney Junior"], 
    ["Eska TV", 20286605, "Eska TV"], ["Eska TV Extra", 20286606, "Eska TV Extra"],
    ["Eska Rock", 27935898, "Eska Rock TV"], ["Vox Music TV", 27936293, "Vox Music TV"], ["RMF", 30492410, "RMF FM"]
]

; ==============================================================================
; SEKCJA 5: AGENT ŁADOWANIA EPG
; ==============================================================================
ZaladujEPG(*) 
{
    global EPG_Cache, Kanaly, EpgPlik, FolderLoga
    if !FileExist(EpgPlik) 
        return
    try Txt := FileRead(EpgPlik, "UTF-8")
    catch {
        SetTimer(ZaladujEPG, -2000)
        return
    }
    Teraz := A_Now
    for _, k in Kanaly 
    {
        ID := k[3]
        EPG_Cache[ID] := ["Brak danych", "---", "---", "Brak danych", "---", "---", FolderLoga "\" ID ".png", "Brak opisu", "", "", "Brak opisu"]
        Pos := 1
        while (Pos := InStr(Txt, 'channel="' ID '"', , Pos)) 
        {
            StartBloku := InStr(Txt, "<programme ", , Pos, -1)
            if (!StartBloku) {
                Pos += 1
                continue
            }
            if RegExMatch(SubStr(Txt, StartBloku, 150), 'start="(\d{14}).*?stop="(\d{14})', &mTime)
            {
                if (mTime[1] <= Teraz && mTime[2] > Teraz) 
                {
                    KoniecBloku := InStr(Txt, "</programme>", , StartBloku)
                    Blok := SubStr(Txt, StartBloku, KoniecBloku - StartBloku + 12)
                    if RegExMatch(Blok, 'i)<title[^>]*>(.*?)</title>', &mT)
                        EPG_Cache[ID][1] := mT[1]
                    EPG_Cache[ID][2] := mTime[1]
                    EPG_Cache[ID][3] := mTime[2]
                    if RegExMatch(Blok, 's)<desc[^>]*>(.*?)</desc>', &mD)
                        EPG_Cache[ID][8] := mD[1]
                    NextStartPos := InStr(Txt, "<programme ", , KoniecBloku)
                    if (NextStartPos) 
                    {
                        if RegExMatch(SubStr(Txt, NextStartPos, 150), 'start="(\d{14}).*?stop="(\d{14})', &mNextTime)
                        {
                            EPG_Cache[ID][5] := mNextTime[1]
                            EPG_Cache[ID][6] := mNextTime[2]
                            NextEndPos := InStr(Txt, "</programme>", , NextStartPos)
                            NextBlok := SubStr(Txt, NextStartPos, NextEndPos - NextStartPos + 12)
                            if RegExMatch(NextBlok, 'i)<title[^>]*>(.*?)</title>', &mTN)
                                EPG_Cache[ID][4] := mTN[1]
                            if RegExMatch(NextBlok, 's)<desc[^>]*>(.*?)</desc>', &mDN)
                                EPG_Cache[ID][11] := mDN[1]
                        }
                    }
                    break
                }
            }
            Pos := InStr(Txt, "</programme>", , Pos) + 1
        }
    }
}

; ==============================================================================
; SEKCJA 6: AGENT SYNCHRONIZACJI
; ==============================================================================
SetTimer(SynchronizujZPrzegladarka, 2000)
SynchronizujZPrzegladarka(*) 
{
    global Indeks, Kanaly
    if WinActive("ahk_exe brave.exe") 
    {
        Tytul := WinGetTitle("A")
        for i, k in Kanaly 
        {
            if InStr(Tytul, k[1]) && Indeks != i 
            {
                Indeks := i
                PokazEpg() 
                break
            }
        }
    }
}

; ==============================================================================
; SEKCJA 7: INTERFEJS - PILOT
; ==============================================================================
PokazPilota()
{
    global MyGui, Przyciski, StartWidoku, MaxSlotow, EPG_Cache, TrybNav
    
    AutoZamknijWszystko()
    TrybNav := "Lista"
    
    if (EPG_Cache.Count == 0)
        ZaladujEPG()

    MonitorGetWorkArea(1, &L, &T, &R, &B)
    MyGui := Gui("-Caption +AlwaysOnTop +ToolWindow", "PilotPlay")
    MyGui.BackColor := "0A0015"
    MyGui.SetFont("s10 w800 c4B0082")
    MyGui.Add("Text", "x20 y10 w300", "LISTA KANAŁÓW")

    Przyciski := []
    Loop MaxSlotow 
    {
        bg := MyGui.Add("Text", "x25 y+1 w300 h18 Background1E1E2E")
        MyGui.SetFont("s8 cWhite w600")
        txt := MyGui.Add("Text", "xp+10 yp wp-10 h18 Left +0x0200 +BackgroundTrans", "")
        bg.OnEvent("Click", PrzelaczZListyKlik)
        txt.OnEvent("Click", PrzelaczZListyKlik)
        Przyciski.Push({bg: bg, txt: txt})
    }
    OnMessage(0x020A, ObslugaKolka) 
    WykonajOdswiezenieListy()
    MyGui.Show("w350 h630 x" (R-360) " y10")
    PokazEpg()
    
    SetTimer(AutoZamknijWszystko, -10000)
}

PrzelaczZListyKlik(GuiCtrlObj, *) 
{
    global StartWidoku, Przyciski
    Loop Przyciski.Length {
        if (Przyciski[A_Index].bg == GuiCtrlObj || Przyciski[A_Index].txt == GuiCtrlObj) {
            Przelacz(StartWidoku + A_Index - 1)
            break
        }
    }
}

; ==============================================================================
; SEKCJA 8: LOGIKA PRZEWIJANIA (BEZ WYMUSZANIA ODSWIEŻANIA EPG)
; ==============================================================================
PrzewinListy(Kierunek) 
{
    global Indeks, Kanaly, TrybNav, WyborEPG
    if (TrybNav = "EPG") 
    {
        WyborEPG := (Kierunek = "Down") ? 2 : 1
        UpdateEpgContent(EPG_Cache[Kanaly[Indeks][3]]) ; Tylko aktualizacja treści, nie mruga całym oknem
        return
    }
    
    if (Kierunek = "Down")
        Indeks := (Indeks >= Kanaly.Length ? 1 : Indeks + 1)
    else
        Indeks := (Indeks <= 1 ? Kanaly.Length : Indeks - 1)
    
    WykonajOdswiezenieListy()
    UpdateEpgContent(EPG_Cache[Kanaly[Indeks][3]]) ; Tylko aktualizacja treści
    SetTimer(AutoZamknijWszystko, -10000)
}

; ==============================================================================
; SEKCJA 9: INTERFEJS - EPG OSD
; ==============================================================================
OtworzOpisTeraz(*) {
    global WyborEPG := 1
    PokazPelnyOpis()
}

OtworzOpisNast(*) {
    global WyborEPG := 2
    PokazPelnyOpis()
}

PokazEpg() 
{
    global EpgGui, TrybNav, WyborEPG, Indeks, Kanaly, EPG_Cache, FolderLoga
    
    ID := Kanaly[Indeks][3]
    D := EPG_Cache.Has(ID) ? EPG_Cache[ID] : ["Załaduj EPG", "---", "---", "Brak danych", "---", "---", FolderLoga "\" ID ".png"]
    MonitorGetWorkArea(1, &L, &T, &R, &B)

    if (EpgGui is Gui) {
        UpdateEpgContent(D)
        SetTimer(AutoZamknijWszystko, -10000)
        return
    }

    EpgGui := Gui("-Caption +AlwaysOnTop +ToolWindow", "PotwierdzenieEPG")
    EpgGui.BackColor := "0A0015"
    WinSetTransparent(240, EpgGui)
    
    if FileExist(D[7])
        EpgGui.Add("Picture", "x20 y25 w120 h-1 +BackgroundTrans vLogoPic", D[7])
    
    EpgGui.SetFont("s11 cFF00FF w800", "Segoe UI")
    EpgGui.Add("Text", "x160 y15 w300 vKanalNazwa", Kanaly[Indeks][1])
    EpgGui.SetFont("s11 cWhite w800")
    EpgGui.Add("Text", "x930 y15 w100 Right vClockTxt", FormatTime(, "HH:mm:ss"))
    
    BgTeraz := (TrybNav = "EPG" && WyborEPG = 1) ? "Background330044" : "BackgroundTrans"
    EpgGui.SetFont("s16 cWhite w700")
    EpgGui.Add("Text", "x160 y40 w870 h35 +0x0200 vTytulTeraz " BgTeraz, D[1])
    EpgGui.Add("Text", "x160 y40 w870 h35 +BackgroundTrans").OnEvent("Click", OtworzOpisTeraz)

    T_Start := (D[2] != "---") ? SubStr(D[2], 9, 2) ":" SubStr(D[2], 11, 2) : "--:--"
    T_Stop  := (D[3] != "---") ? SubStr(D[3], 9, 2) ":" SubStr(D[3], 11, 2) : "--:--"
    EpgGui.SetFont("s10 cWhite w600")
    EpgGui.Add("Text", "x160 y80 w100 vCzasTeraz", T_Start " - " T_Stop)
    
    EpgGui.Add("Progress", "x270 y83 w640 h8 Background1E1E2E c4B0082 vProgBar", 0)
    EpgGui.SetFont("s9 cWhite w600")
    EpgGui.Add("Text", "x920 y78 w110 Right vTimeTxt", "0m 0s")
    
    BgNast := (TrybNav = "EPG" && WyborEPG = 2) ? "Background330044" : "BackgroundTrans"
    EpgGui.SetFont("s10 c888888 w400")
    NextT_Start := (D[5] != "---") ? SubStr(D[5], 9, 2) ":" SubStr(D[5], 11, 2) : "--:--"
    NextT_Stop  := (D[6] != "---") ? SubStr(D[6], 9, 2) ":" SubStr(D[6], 11, 2) : "--:--"
    EpgGui.Add("Text", "x160 y105 w870 h25 +0x0200 vTytulNast " BgNast, "Następnie: " D[4] " (" NextT_Start " - " NextT_Stop ")")
    EpgGui.Add("Text", "x160 y105 w870 h25 +BackgroundTrans").OnEvent("Click", OtworzOpisNast)

    EpgGui.Show("w1050 h150 x20 y" (B - 190) " NoActivate")
    
    SetTimer(AktualizujPasek, 1000)
    SetTimer(AutoZamknijWszystko, -10000)
}

UpdateEpgContent(D) {
    global EpgGui, TrybNav, WyborEPG, Indeks, Kanaly
    if !(EpgGui is Gui)
        return
    try {
        ; Twardy reset tła - czyścimy oba, zanim zapalimy jeden
        EpgGui["TytulTeraz"].Opt("BackgroundTrans")
        EpgGui["TytulNast"].Opt("BackgroundTrans")
        
        EpgGui["KanalNazwa"].Value := Kanaly[Indeks][1]
        EpgGui["TytulTeraz"].Value := D[1]
        
        if (TrybNav = "EPG" && WyborEPG = 1)
            EpgGui["TytulTeraz"].Opt("Background330044")
            
        T_Start := (D[2] != "---") ? SubStr(D[2], 9, 2) ":" SubStr(D[2], 11, 2) : "--:--"
        T_Stop  := (D[3] != "---") ? SubStr(D[3], 9, 2) ":" SubStr(D[3], 11, 2) : "--:--"
        EpgGui["CzasTeraz"].Value := T_Start " - " T_Stop
        
        NextT_Start := (D[5] != "---") ? SubStr(D[5], 9, 2) ":" SubStr(D[5], 11, 2) : "--:--"
        NextT_Stop  := (D[6] != "---") ? SubStr(D[6], 9, 2) ":" SubStr(D[6], 11, 2) : "--:--"
        EpgGui["TytulNast"].Value := "Następnie: " D[4] " (" NextT_Start " - " NextT_Stop ")"
        
        if (TrybNav = "EPG" && WyborEPG = 2)
            EpgGui["TytulNast"].Opt("Background330044")
            
        if FileExist(D[7])
            EpgGui["LogoPic"].Value := D[7]
            
        ; Wymuszamy przerysowanie, żeby tła nie "zostawały"
        EpgGui["TytulTeraz"].Redraw()
        EpgGui["TytulNast"].Redraw()
    }
}

; ==============================================================================
; SEKCJA 11: SYSTEM RUCHU + AGENT STRAŻNIK URL (WERSJA NIEZAWODNA)
; ==============================================================================

; FUNKCJA AGENTA - Sprawdza czy jesteś fizycznie na stronie Play Now
AgentStraznik() {
    if !WinActive("ahk_exe brave.exe") && !WinActive("ahk_exe chrome.exe")
        return false
    
    try {
        ; Pobieramy tekst z paska adresu (klasyczny sposób dla Brave/Chrome)
        Tytul := WinGetTitle("A")
        ; Sprawdzamy czy w tytule lub adresie jest fraza kluczowa
        if InStr(Tytul, "PLAY NOW") || InStr(Tytul, "playnow")
            return true
    }
    return false
}

#HotIf AgentStraznik() ; Od teraz WSZYSTKO poniżej pilnuje Agent

; --- TRYB MENU (Gdy Pilot, EPG lub Opis istnieją) ---
#HotIf AgentStraznik() && (WinExist("PilotPlay") || WinExist("PotwierdzenieEPG") || WinExist("OpisProgramu"))

$Up:: PrzewinListy("Up")
$Down:: PrzewinListy("Down")
$WheelUp:: {
    if WinActive("OpisProgramu")
        PrzewinOpis("Up")
    else
        PrzewinListy("Up")
}
$WheelDown:: {
    if WinActive("OpisProgramu")
        PrzewinOpis("Down")
    else
        PrzewinListy("Down")
}

$Left:: {
    if WinExist("OpisProgramu")
        return ; Blokada w opisie
    global TrybNav := "EPG", WyborEPG := 1
    WykonajOdswiezenieListy()
    PokazEpg()
}
$Right:: {
    if WinExist("OpisProgramu")
        return ; Blokada w opisie
    global TrybNav := "Lista"
    WykonajOdswiezenieListy()
    PokazEpg()
}

$Enter:: {
    if WinExist("OpisProgramu") {
        AutoZamknijWszystko()
    } else {
        global TrybNav, Indeks
        if (TrybNav = "Lista") {
            Przelacz(Indeks)
        } else {
            AutoZamknijWszystko() 
            Sleep(100)
            PokazPelnyOpis()
        }
    }
}

$Esc:: AutoZamknijWszystko()

; --- TRYB OGLĄDANIA (Gdy menu są zamknięte) ---
#HotIf AgentStraznik() && !WinExist("PilotPlay") && !WinExist("PotwierdzenieEPG") && !WinExist("OpisProgramu")

$Left:: Przelacz(Indeks <= 1 ? Kanaly.Length : Indeks - 1)
$Right:: Przelacz(Indeks >= Kanaly.Length ? 1 : Indeks + 1)
~RShift:: PokazPilota()
$,:: PokazEpg()

#HotIf ; Koniec strażnika

; ==============================================================================
; SEKCJA 12: ODŚWIEŻANIE LISTY (FIX NA "DUCHY" PODŚWIETLENIA)
; ==============================================================================
WykonajOdswiezenieListy() 
{
    global Indeks, StartWidoku, MaxSlotow, Kanaly, Przyciski, TrybNav, MyGui
    if !(MyGui is Gui)
        return
        
    if (Indeks < StartWidoku)
        StartWidoku := Indeks
    else if (Indeks >= StartWidoku + MaxSlotow)
        StartWidoku := Indeks - MaxSlotow + 1
        
    Loop MaxSlotow 
    {
        AktualnyK := StartWidoku + A_Index - 1
        try { 
            if (AktualnyK <= Kanaly.Length) {
                Przyciski[A_Index].txt.Value := Kanaly[AktualnyK][1]
                Przyciski[A_Index].bg.Visible := True
                Przyciski[A_Index].txt.Visible := True
                
                ; Kolor tła: tylko jeśli jesteśmy w trybie Listy, dajemy mocny fiolet
                ; Jeśli jesteśmy w trybie EPG, lista jest "szara/ciemna", żeby było widać gdzie jest focus
                Kolor := (AktualnyK = Indeks) ? (TrybNav = "Lista" ? "4B0082" : "1A1A2B") : "1E1E2E"
                Przyciski[A_Index].bg.Opt("Background" Kolor)
            } else {
                Przyciski[A_Index].bg.Visible := False
                Przyciski[A_Index].txt.Visible := False
            }
            Przyciski[A_Index].txt.Redraw()
        }
    }
}

; ==============================================================================
; SEKCJA 13: ZAMYKANIE I RESET (BEZKOMPROMISOWE)
; ==============================================================================
AutoZamknijWszystko(*) 
{
    global MyGui, EpgGui, OpisGui, TrybNav
    
    ; Stopujemy wszystkie timery odświeżania
    SetTimer(AktualizujPasek, 0)
    SetTimer(AutoZamknijWszystko, 0)
    
    ; Reset do stanu bazowego
    TrybNav := "Lista"
    
    ; Brutalne niszczenie okien
    if (MyGui is Gui) {
        try MyGui.Destroy()
        MyGui := 0 
    }
    if (EpgGui is Gui) {
        try EpgGui.Destroy()
        EpgGui := 0 
    }
    if (OpisGui is Gui) {
        try OpisGui.Destroy()
        OpisGui := 0
    }
    
    ; Powrót Focusu na stronę, żeby klawisze w ogóle działały
    if WinExist("ahk_exe brave.exe") {
        WinActivate("ahk_exe brave.exe")
        ControlFocus "Intermediate D3D Window1", "ahk_exe brave.exe"
    }
}

; ==============================================================================
; SEKCJA 15: PRZEŁĄCZANIE Z WYMUSZENIEM FOCUSU
; ==============================================================================
Przelacz(nr, *) 
{
    global Kanaly, Indeks
    if (nr < 1 || nr > Kanaly.Length)
        return
    Indeks := nr
    ID_Kanalu := Kanaly[nr][2]
    if WinExist("ahk_exe brave.exe") {
        WinActivate("ahk_exe brave.exe")
        Style := WinGetStyle("A")
        IsFullscreen := !(Style & 0x00C00000)
        if (IsFullscreen) {
            Send("{F11}")
            Sleep(600)    
        }
        Send("^l")
        Sleep(200)
        Send("https://www.playnow.pl/ogladaj/kanal/" ID_Kanalu "{Enter}")
        if (IsFullscreen) {
            Sleep(1500)
            Send("{F11}")
            Sleep(500)
            ; KLUCZOWE: Wymuszenie Focusu na oknie Brave'a po powrocie do Fullscreena
            WinActivate("ahk_exe brave.exe")
            ControlFocus("Intermediate D3D Window1", "ahk_exe brave.exe") 
        }
    }
    AutoZamknijWszystko()
}

; ==============================================================================
; SEKCJA 16-18: FUNKCJE POMOCNICZE
; ==============================================================================
AktualizujPasek(*) {
    global EpgGui, EPG_Cache, Kanaly, Indeks
    if !(EpgGui is Gui)
        return
    ID := Kanaly[Indeks][3]
    if !EPG_Cache.Has(ID)
        return
    D := EPG_Cache[ID], Teraz := A_Now, Start := D[2], Stop := D[3]
    if (Start = "---" || Stop = "---")
        return
    Total := DateDiff(Stop, Start, "Seconds"), Done := DateDiff(Teraz, Start, "Seconds")
    try {
        EpgGui["ProgBar"].Value := (Done / Total) * 100
        Pozostalo := DateDiff(Stop, Teraz, "Minutes")
        EpgGui["TimeTxt"].Value := Pozostalo "m " Mod(DateDiff(Stop, Teraz, "Seconds"), 60) "s"
        EpgGui["ClockTxt"].Value := FormatTime(, "HH:mm:ss")
    }
}

ZnajdzFolderQuickNav() {
    DyskList := "EDCDEFGHIJKLMNOPQRSTUVWXYZ"
    Loop Parse, DyskList {
        Sciezka := A_LoopField ":\Play Now QuickNav"
        if DirExist(Sciezka)
            return Sciezka
    }
    return A_ScriptDir 
}

AktualizujEPG_Agent(*) {
    global EpgPlik
    LinkEPG := "https://epg.ovh/pltv.xml"
    try {
        Download(LinkEPG, EpgPlik)
        ZaladujEPG()
    }
}

PokazPelnyOpis() 
{
    global OpisGui, Indeks, WyborEPG, EPG_Cache, OpisSegmenty, PelnaTrescOpisu, StartLiniiOpisu, MaxLiniiOpisu, Kanaly, TrybNav
    ID := Kanaly[Indeks][3]
    if (!EPG_Cache.Has(ID))
        return
    TrybNav := "Opis"
    D := EPG_Cache[ID], Tytul := (WyborEPG = 1) ? D[1] : D[4], SurowyOpis := (WyborEPG = 1) ? D[8] : D[11]
    PelnaTrescOpisu := []
    Loop Parse, SurowyOpis, "`n", "`r" {
        Line := A_LoopField
        while (StrLen(Line) > 80) {
            PelnaTrescOpisu.Push(SubStr(Line, 1, 80))
            Line := SubStr(Line, 81)
        }
        PelnaTrescOpisu.Push(Line)
    }
    StartLiniiOpisu := 1
    OpisGui := Gui("-Caption +AlwaysOnTop +ToolWindow", "OpisProgramu")
    OpisGui.BackColor := "0A0015"
    WinSetTransparent(225, OpisGui)
    OpisGui.SetFont("s18 c4B0082 w800", "Segoe UI")
    OpisGui.Add("Text", "x20 y15 w760 Center", Tytul)
    OpisSegmenty := []
    OpisGui.SetFont("s12 cWhite w500", "Segoe UI")
    Loop MaxLiniiOpisu {
        bg := OpisGui.Add("Text", "x40 y" (60 + (A_Index * 22)) " w720 h22 Background1E1E2E")
        txt := OpisGui.Add("Text", "xp+5 yp wp-10 h22 BackgroundTrans", "")
        OpisSegmenty.Push({bg: bg, txt: txt})
    }
    OdswiezWidokOpisu()
    OpisGui.Show("w800 h550 x50 y100")
    SetTimer(AutoZamknijWszystko, -30000)
}

PrzewinOpis(Kierunek) {
    global StartLiniiOpisu, PelnaTrescOpisu, MaxLiniiOpisu
    if (Kierunek = "Down") {
        if (StartLiniiOpisu + MaxLiniiOpisu <= PelnaTrescOpisu.Length)
            StartLiniiOpisu += 1
    } else {
        if (StartLiniiOpisu > 1)
            StartLiniiOpisu -= 1
    }
    OdswiezWidokOpisu()
}

OdswiezWidokOpisu() {
    global OpisSegmenty, PelnaTrescOpisu, StartLiniiOpisu, MaxLiniiOpisu
    Loop MaxLiniiOpisu {
        Aktualna := StartLiniiOpisu + A_Index - 1
        if (Aktualna <= PelnaTrescOpisu.Length) {
            OpisSegmenty[A_Index].txt.Value := PelnaTrescOpisu[Aktualna]
            OpisSegmenty[A_Index].bg.Visible := True
            OpisSegmenty[A_Index].txt.Visible := True
        } else {
            OpisSegmenty[A_Index].bg.Visible := False
            OpisSegmenty[A_Index].txt.Visible := False
        }
    }
}

ObslugaKolka(wParam, lParam, msg, hwnd) {
    global MyGui, OpisGui, EpgGui
    Kierunek := (wParam > 0) ? "Up" : "Down"
    if (MyGui is Gui && hwnd = MyGui.Hwnd) {
        PrzewinListy(Kierunek)
        return 0
    }
    if (OpisGui is Gui && hwnd = OpisGui.Hwnd) {
        PrzewinOpis(Kierunek)
        return 0
    }
    ; Kółko na okienku EPG też powinno przewijać listę kanałów
    if (EpgGui is Gui && hwnd = EpgGui.Hwnd) {
        PrzewinListy(Kierunek)
        return 0
    }
}

AktualizujEPG_Agent()
SetTimer(AktualizujEPG_Agent, 3600000) 
ZaladujEPG()