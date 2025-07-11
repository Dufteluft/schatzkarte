HUD = {}
HUD.ActiveProgressBars = {}

local screenW, screenH = GetActiveScreenResolution() -- Korrigierte Funktion für FiveM

-- Funktion zum Zeichnen von Text (vereinfacht)
local function DrawTxt(text, x, y, scale, font, color, alignment)
    SetTextFont(font or 0)
    SetTextScale(scale or 0.3, scale or 0.3)
    SetTextColour(color.r, color.g, color.b, color.a or 255)

    if alignment == "center" then
        SetTextCentre(true)
    elseif alignment == "right" then
        SetTextWrap(0.0, x)
        SetTextRightJustify(true)
    end

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
    SetTextCentre(false) -- Reset für andere UI-Elemente
    SetTextRightJustify(false) -- Reset
end

-- Startet eine nicht-blockierende Fortschrittsleiste
function HUD.StartProgress(name, label, duration, successCallback, cancelCallback)
    print("[Schatzkarte-HUD DEBUG] HUD.StartProgress aufgerufen für: " .. name .. ", Label: " .. label .. ", Dauer: " .. duration)
    if HUD.ActiveProgressBars[name] then
        print("[Schatzkarte-HUD DEBUG] Warnung: Fortschrittsbalken mit Namen '" .. name .. "' ist bereits aktiv. Stoppe alten.")
        HUD.StopProgress(name) -- Stoppt den alten Thread, falls vorhanden
    end

    local progressData = {
        label = label,
        duration = duration,
        startTime = GetGameTimer(),
        successCb = successCallback,
        cancelCb = cancelCallback or function() print("[Schatzkarte-HUD DEBUG] Fortschritt '" .. name .. "' abgebrochen (kein spezifischer cancelCb).") end,
        thread = nil
    }
    HUD.ActiveProgressBars[name] = progressData

    progressData.thread = Citizen.CreateThread(function()
        print("[Schatzkarte-HUD DEBUG] Thread für Progress '" .. name .. "' gestartet.")
        -- screenW und screenH sind jetzt global in dieser Datei verfügbar

        -- Position und Größe der Leiste (Beispiel: unten mittig)
        local barBgWidth = 0.2
        local barBgHeight = 0.035
        local barBgX = 0.5 - (barBgWidth / 2)
        local barBgY = 0.85

        local barColorBg = {r = 40, g = 40, b = 40, a = 180}
        local barColorFg = {r = 90, g = 160, b = 90, a = 200}
        local textColor = {r = 255, g = 255, b = 255, a = 255}
        local textScale = 0.35
        local textFont = 0

        while HUD.ActiveProgressBars[name] and HUD.ActiveProgressBars[name].startTime == progressData.startTime do
            local currentTime = GetGameTimer()
            local elapsedTime = currentTime - progressData.startTime
            local currentProgress = math.min(1.0, elapsedTime / progressData.duration)

            if currentProgress >= 1.0 then
                break -- Zeit abgelaufen, Schleife beenden
            end

            -- Hintergrund der Leiste
            DrawRect(barBgX + barBgWidth / 2, barBgY + barBgHeight / 2, barBgWidth, barBgHeight, barColorBg.r, barColorBg.g, barColorBg.b, barColorBg.a)
            -- Vordergrund (Fortschritt)
            local barFgWidth = barBgWidth * currentProgress
            DrawRect(barBgX + barFgWidth / 2, barBgY + barBgHeight / 2, barFgWidth, barBgHeight, barColorFg.r, barColorFg.g, barColorFg.b, barColorFg.a)
            -- Text
            DrawTxt(progressData.label, barBgX + barBgWidth / 2, barBgY + (barBgHeight / 2) - (textScale * 10 / screenH) - 0.004, textScale, textFont, textColor, "center")

            Citizen.Wait(0)
        end

        -- Nach der Schleife prüfen, ob der Progress noch aktiv sein soll (nicht durch HUD.StopProgress entfernt)
        if HUD.ActiveProgressBars[name] and HUD.ActiveProgressBars[name].startTime == progressData.startTime then
            if GetGameTimer() - progressData.startTime >= progressData.duration then
                print("[Schatzkarte-HUD DEBUG] Fortschritt '" .. name .. "' erfolgreich abgeschlossen.")
                if progressData.successCb then
                    progressData.successCb()
                end
            else
                -- Wurde gestoppt, aber cancelCb nicht explizit aufgerufen
                print("[Schatzkarte-HUD DEBUG] Fortschritt '" .. name .. "' implizit gestoppt/unterbrochen.")
                if progressData.cancelCb then
                    progressData.cancelCb() -- Rufe cancelCb auf, wenn der Thread endet, bevor die Zeit abgelaufen ist und nicht durch Erfolg
                end
            end
            HUD.ActiveProgressBars[name] = nil -- Aufräumen
        end
        print("[Schatzkarte-HUD DEBUG] Thread für Progress '" .. name .. "' beendet.")
    end)
end

function HUD.StopProgress(name, wasCancelled)
    wasCancelled = wasCancelled or false -- Standardmäßig nicht explizit als gecancelt markieren
    print("[Schatzkarte-HUD DEBUG] HUD.StopProgress aufgerufen für: " .. name)
    if HUD.ActiveProgressBars[name] then
        local progressData = HUD.ActiveProgressBars[name]
        HUD.ActiveProgressBars[name] = nil -- Stoppt den Loop im Thread, indem die Bedingung fehlschlägt

        -- Wenn es explizit abgebrochen wurde und einen cancelCallback hat
        if wasCancelled and progressData.cancelCb then
            print("[Schatzkarte-HUD DEBUG] Fortschritt '" .. name .. "' explizit abgebrochen, rufe cancelCb.")
            progressData.cancelCb()
        end
        -- Der Thread selbst wird beim nächsten Tick enden, da HUD.ActiveProgressBars[name] nil ist.
    else
        print("[Schatzkarte-HUD DEBUG] Warnung: Kein aktiver Fortschrittsbalken mit Namen '" .. name .. "' zum Stoppen gefunden.")
    end
end

print("Schatzkarten-Skript: hud.lua geladen")
print("[Schatzkarte-HUD] hud.lua vollständig geladen. HUD Tabelle initialisiert.")
