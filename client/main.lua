-- Client-Seite des Schatzkarten-Skripts
-- ESX wird nun über fxmanifest.lua als shared_script geladen und sollte global verfügbar sein.
local currentTreasure = nil
local treasureBlip = nil
local treasureObject = nil

Citizen.CreateThread(function()
    local attempts = 0
    while (type(HUD) ~= 'table' or type(HUD.StartProgress) ~= 'function') and attempts < 100 do
        print("[Schatzkarte-Skript] Warte auf HUD (" .. attempts .. "/100)... HUD: " .. type(HUD) .. (type(HUD) == 'table' and (", HUD.StartProgress: " .. type(HUD.StartProgress)) or ""))
        Citizen.Wait(100) -- Warte 100ms zwischen den Prüfungen
        attempts = attempts + 1
    end
    if type(HUD) == 'table' and type(HUD.StartProgress) == 'function' then
        print("[Schatzkarte-Skript] HUD und HUD.StartProgress sind jetzt verfügbar nach " .. attempts .. " Versuchen.")
    else
        print("[Schatzkarte-Skript] FEHLER: HUD oder HUD.StartProgress nach " .. attempts .. " Versuchen immer noch nicht verfügbar! HUD: " .. type(HUD) .. (type(HUD) == 'table' and (", HUD.StartProgress: " .. type(HUD.StartProgress)) or ""))
        ESX.ShowNotification("Schatzkarten-Skript: Kritischer Ladefehler (HUD). Bitte Serverkonsole prüfen.", "error", 5000)
    end
end)

-- Funktion zum Starten der Schatzsuche
function StartTreasureHunt()
    if currentTreasure then
        ESX.ShowNotification("Du bist bereits auf einer Schatzsuche.")
        print("[Schatzkarte-Skript] StartTreasureHunt: Bereits eine Schatzsuche aktiv.")
        return
    end

    -- Schatzkarte aus Inventar entfernen (Versuch)
    print("[Schatzkarte-Skript] StartTreasureHunt: Triggere Server-Event 'schatzkarte:usedMap' zum Entfernen von Item: " .. Config.TreasureMapItem)
    TriggerServerEvent('schatzkarte:usedMap', Config.TreasureMapItem)
    -- Hinweis: Die Schatzsuche startet hier clientseitig sofort weiter.
    -- Eine robustere Lösung würde auf eine Bestätigung vom Server warten, dass das Item entfernt wurde.

    local locationData = GetRandomTreasureLocation() -- Zufälligen Ort auswählen

    if not locationData or not locationData.coords or not locationData.heading then
        ESX.ShowNotification("Fehler: Konnte keinen gültigen Schatzort finden oder Schatzort-Daten unvollständig.")
        print("[Schatzkarte-Skript] StartTreasureHunt: Fehler - GetRandomTreasureLocation gab nil zurück oder Schatzort-Daten unvollständig.")
        return
    end

    print("[Schatzkarte-Skript] StartTreasureHunt: Verwende Schatzort: " .. (locationData.name or "Unbenannter Ort") .. " an " .. tostring(locationData.coords))

    currentTreasure = {
        coords = locationData.coords,
        heading = locationData.heading,
        isDugUp = false, -- Wichtig: Für den vollen Prozess wieder auf false setzen
        isOpened = false
    }

    -- Blip erstellen
    if treasureBlip then RemoveBlip(treasureBlip) end
    treasureBlip = AddBlipForCoord(currentTreasure.coords.x, currentTreasure.coords.y, currentTreasure.coords.z)
    SetBlipSprite(treasureBlip, Config.Blip.sprite)
    SetBlipDisplay(treasureBlip, 4)
    SetBlipScale(treasureBlip, Config.Blip.scale)
    SetBlipColour(treasureBlip, Config.Blip.color)
    SetBlipAsShortRange(treasureBlip, Config.Blip.shortRange)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Blip.name)
    EndTextCommandSetBlipName(treasureBlip)

    -- Navigationspunkt setzen (Waypoint)
    SetNewWaypoint(currentTreasure.coords.x, currentTreasure.coords.y)

    -- Schatzkiste (vergraben) spawnen
    RequestModel(Config.ChestModels.buried) -- Verwendet jetzt prop_tool_box_05
    while not HasModelLoaded(Config.ChestModels.buried) do
        Wait(100)
    end

    -- Kiste spawnen (zuerst an den Zielkoordinaten, dann auf den Boden setzen, dann versenken)
    treasureObject = CreateObject(Config.ChestModels.buried, currentTreasure.coords.x, currentTreasure.coords.y, currentTreasure.coords.z, false, true, false)
    print("[Schatzkarte-Skript] StartTreasureHunt: Kiste initial erstellt mit Modell " .. Config.ChestModels.buried .. " bei " .. tostring(currentTreasure.coords))

    PlaceObjectOnGroundProperly(treasureObject)
    Wait(150) -- Etwas mehr Zeit geben, damit PlaceObjectOnGroundProperly sicher abgeschlossen ist

    local placedCoords = GetEntityCoords(treasureObject)
    local finalSpawnZ = placedCoords.z + Config.ChestSpawnOffsetZ -- Config.ChestSpawnOffsetZ ist negativ

    SetEntityCoords(treasureObject, placedCoords.x, placedCoords.y, finalSpawnZ, false, false, false, true)
    Wait(50) -- Kurze Pause, damit die neuen Coords angewendet werden

    currentTreasure.actualStartZ = GetEntityCoords(treasureObject).z -- Die tatsächlich versenkte Start-Z
    currentTreasure.targetZ = placedCoords.z -- Ziel ist die ursprüngliche Bodenhöhe vor dem Versenken

    print("[Schatzkarte-Skript] StartTreasureHunt: Kiste auf Boden platziert (Z: " .. placedCoords.z .. ") und dann versenkt auf Z: " .. currentTreasure.actualStartZ .. ". Ziel-Z für Heben: " .. currentTreasure.targetZ)

    SetEntityHeading(treasureObject, currentTreasure.heading)
    FreezeEntityPosition(treasureObject, true)

    -- currentTreasure.isDugUp bleibt false

    ESX.ShowNotification("Schatzsuche gestartet: " .. (locationData.name or "Unbenannter Ort"))
    print("[Schatzkarte-Skript] Schatzsuche gestartet für: " .. (locationData.name or "Unbenannter Ort"))

    -- Target für das Graben hinzufügen
    AddTargetToBuriedChest()
end

-- Beispiel: Event oder Befehl zum Starten der Schatzsuche (muss von deinem Inventarsystem ausgelöst werden)
-- Annahme: Dein Inventarsystem triggert dieses Event, wenn das Item Config.TreasureMapItem (jetzt 'schatzkarte') benutzt wird.
RegisterNetEvent('schatzkarte:startHunt', StartTreasureHunt)

-- Zum Testen per Befehl (später entfernen oder sichern)
RegisterCommand('startschatz', function()
    StartTreasureHunt()
end, false)


-- Funktion zum Hinzufügen der oxtarget-Zone zur vergrabenen Kiste (Platzhalter)
-- Funktion zum Hinzufügen der oxtarget-Zone zur vergrabenen Kiste
function AddTargetToBuriedChest()
    if not DoesEntityExist(treasureObject) then
        print("[Schatzkarte-Skript] FEHLER AddTargetToBuriedChest: treasureObject (ID: " .. tostring(treasureObject) .. ") existiert NICHT beim Versuch, Target hinzuzufügen.")
        return
    end
    if currentTreasure.isDugUp then
        print("[Schatzkarte-Skript] FEHLER AddTargetToBuriedChest: Kiste ist bereits als ausgegraben markiert.")
        return
    end

    local modelHash = GetEntityModel(treasureObject)
    print("[Schatzkarte-Skript] AddTargetToBuriedChest: Versuche Target für Entity ID " .. tostring(treasureObject) .. " (Modell: " .. tostring(modelHash) .. ") hinzuzufügen an Coords: " .. tostring(GetEntityCoords(treasureObject)))

    exports.ox_target:addLocalEntity(treasureObject, {
        {
            name = 'schatzkarte:dig_chest',
            label = 'Graben',
            icon = 'fas fa-shovel',
            distance = Config.OxTarget.DigDistance,
            onSelect = function(data)
                print("[Schatzkarte-Skript] ox_target: onSelect 'Graben' ausgelöst für Entity " .. tostring(data.entity))
                DigUpChest()
            end,
            canInteract = function(entity, distance, data)
                local treasureStillExists = DoesEntityExist(treasureObject)
                local notDugYet = not currentTreasure.isDugUp
                local can = treasureStillExists and notDugYet

                if not can and treasureStillExists then -- Nur loggen, wenn die Kiste noch da ist, aber Interaktion fehlschlägt
                     print("[Schatzkarte-Skript] ox_target: canInteract 'Graben' ist FALSE. Kiste existent? " .. tostring(treasureStillExists) .. ". Nicht ausgegraben? " .. tostring(notDugYet))
                end
                return can
            end,
        }
    })
    print("[Schatzkarte-Skript] ox_target:addLocalEntity für vergrabene Kiste (Entity ID: " .. tostring(treasureObject) .. ") aufgerufen.")
end

-- Funktion zum Ausgraben der Kiste
function DigUpChest()
    print("[Schatzkarte-Skript DEBUG] DigUpChest: Funktion gestartet. Entity: " .. tostring(treasureObject) .. ", isDugUp: " .. tostring(currentTreasure.isDugUp))
    if not DoesEntityExist(treasureObject) or currentTreasure.isDugUp then
        print("[Schatzkarte-Skript DEBUG] DigUpChest: Kiste existiert nicht oder ist bereits ausgegraben. Funktion wird beendet.")
        return
    end

    local playerPed = PlayerPedId()
    local particleFx = nil -- Bleibt nil, da Partikel auskommentiert sind
    local propEntity = nil -- Für die Schaufel

    -- Prop Handling
    local animConfig = Config.Animations.digging
    if animConfig.prop then
        RequestModel(GetHashKey(animConfig.prop))
        print("[Schatzkarte-Skript DEBUG] DigUpChest: Prop-Modell angefordert: " .. animConfig.prop)
        local propLoadAttempts = 0
        while not HasModelLoaded(GetHashKey(animConfig.prop)) do
            Wait(50)
            propLoadAttempts = propLoadAttempts + 1
            if propLoadAttempts > 100 then -- Timeout für Prop-Laden
                print("[Schatzkarte-Skript DEBUG] DigUpChest: Laden des Prop-Modells '" .. animConfig.prop .. "' dauert zu lange!")
                break -- Fahre ohne Prop fort oder breche hier ganz ab, je nach Anforderung
            end
        end
        if HasModelLoaded(GetHashKey(animConfig.prop)) then
            print("[Schatzkarte-Skript DEBUG] DigUpChest: Prop-Modell geladen: " .. animConfig.prop)
            local playerCoords = GetEntityCoords(playerPed) -- Ungefähre Position, da es eh attacht wird
            propEntity = CreateObject(GetHashKey(animConfig.prop), playerCoords.x, playerCoords.y, playerCoords.z, true, false, false)
            print("[Schatzkarte-Skript DEBUG] DigUpChest: Prop-Entity erstellt: " .. tostring(propEntity))
            AttachEntityToEntity(propEntity, playerPed, GetPedBoneIndex(playerPed, animConfig.propBone),
                                animConfig.propOffsetX, animConfig.propOffsetY, animConfig.propOffsetZ,
                                animConfig.propRotX, animConfig.propRotY, animConfig.propRotZ,
                                true, true, false, true, 2, true)
            print("[Schatzkarte-Skript DEBUG] DigUpChest: Prop an Spieler an Knochen " .. animConfig.propBone .. " angefügt.")
        else
            print("[Schatzkarte-Skript DEBUG] DigUpChest: Prop-Modell konnte nicht geladen werden, fahre ohne Prop fort.")
        end
    end

    -- Partikel-Effekt starten (TEMPORÄR AUSKOMMENTIERT FÜR DEBUGGING)
    print("[Schatzkarte-Skript DEBUG] DigUpChest: Partikel-Block ist weiterhin auskommentiert für diesen Test.")

    -- Animation abspielen
    RequestAnimDict(animConfig.dict)
    print("[Schatzkarte-Skript DEBUG] DigUpChest: AnimDict angefordert: " .. animConfig.dict)
    local animLoadAttempts = 0
    while not HasAnimDictLoaded(animConfig.dict) do
        Wait(100)
        animLoadAttempts = animLoadAttempts + 1
        if animLoadAttempts > 100 then
            print("[Schatzkarte-Skript DEBUG] DigUpChest: Laden des AnimDicts '" .. animConfig.dict .. "' dauert zu lange! Breche ab.")
            ESX.ShowNotification("Fehler beim Starten der Grabe-Animation (Timeout).")
            if propEntity then DetachEntity(propEntity, false, false); DeleteEntity(propEntity); print("[Schatzkarte-Skript DEBUG] DigUpChest: Prop bei Anim-Timeout entfernt.") end
            return
        end
    end
    print("[Schatzkarte-Skript DEBUG] DigUpChest: AnimDict geladen nach " .. animLoadAttempts .. " Versuchen: " .. animConfig.dict)

    print("[Schatzkarte-Skript DEBUG] DigUpChest: Versuche TaskPlayAnim zu starten mit Anim: " .. animConfig.anim)
    TaskPlayAnim(playerPed, animConfig.dict, animConfig.anim, 8.0, -8.0, animConfig.duration, 1, 0, false, false, false)
    print("[Schatzkarte-Skript DEBUG] DigUpChest: TaskPlayAnim ausgeführt.")
    ESX.ShowNotification("Du gräbst nach dem Schatz...")
    print("[Schatzkarte-Skript] DigUpChest: Grabe Kiste aus...")

    -- Partikel-Effekt starten (wieder einkommentiert)
    if Config.ParticleEffects and Config.ParticleEffects.digging then
        local ptfx = Config.ParticleEffects.digging
        RequestNamedPtfxAsset(ptfx.dict)
        print("[Schatzkarte-Skript DEBUG] DigUpChest: PtfxAsset angefordert: " .. ptfx.dict)
        local ptfxLoadAttempts = 0
        while not HasNamedPtfxAssetLoaded(ptfx.dict) do
            Wait(50)
            ptfxLoadAttempts = ptfxLoadAttempts + 1
            if ptfxLoadAttempts > 60 then print("[Schatzkarte-Skript DEBUG] DigUpChest: Laden des PtfxAsset '"..ptfx.dict.."' dauert zu lange!"); break end
        end
        if HasNamedPtfxAssetLoaded(ptfx.dict) then
            print("[Schatzkarte-Skript DEBUG] DigUpChest: PtfxAsset geladen: " .. ptfx.dict)
            particleFx = StartParticleFxLoopedOnEntity(ptfx.name, treasureObject, ptfx.offset.x, ptfx.offset.y, ptfx.offset.z, 0.0, 0.0, 0.0, ptfx.scale, false, false, false)
            print("[Schatzkarte-Skript DEBUG] DigUpChest: StartParticleFxLoopedOnEntity aufgerufen. Partikel-Handle: " .. tostring(particleFx))
        else
            print("[Schatzkarte-Skript DEBUG] DigUpChest: PtfxAsset NICHT geladen: " .. ptfx.dict)
        end
    else
        print("[Schatzkarte-Skript DEBUG] DigUpChest: Keine Partikeleffekte für 'digging' konfiguriert.")
    end

    local progressOptions = {
        entityToAnimate = treasureObject,
        targetCoordZ = currentTreasure.targetZ
    }

    -- Spieleranimation starten
    TaskPlayAnim(playerPed, animConfig.dict, animConfig.anim, 8.0, -8.0, -1, 1, 0, false, false, false) -- Loopende Animation, wird durch ClearPedTasks gestoppt
    print("[Schatzkarte-Skript DEBUG] DigUpChest: TaskPlayAnim für Graben gestartet (looping).")

    print("[Schatzkarte-Skript DEBUG] Vor Aufruf von HUD.StartProgress in DigUpChest.")
    print("[Schatzkarte-Skript DEBUG] Typ von HUD: " .. type(HUD))
    if type(HUD) == 'table' then
        print("[Schatzkarte-Skript DEBUG] Typ von HUD.StartProgress: " .. type(HUD.StartProgress))
    else
        print("[Schatzkarte-Skript DEBUG] HUD ist beim Aufruf keine Tabelle!")
    end
    HUD.StartProgress('schatzkarte_digging', Config.ProgressTexts.digging, animConfig.duration,
        function() -- successCallback
            print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD SuccessCallback: Gestartet.")
            ClearPedTasks(playerPed)
            print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD SuccessCallback: ClearPedTasks aufgerufen.")

            if propEntity then
                print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD SuccessCallback: Entferne Prop-Entity: " .. tostring(propEntity))
                DetachEntity(propEntity, false, false)
                DeleteEntity(propEntity)
                SetModelAsNoLongerNeeded(GetHashKey(animConfig.prop))
                propEntity = nil
            end

            if particleFx then
                print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD SuccessCallback: Stoppe Partikeleffekt " .. tostring(particleFx))
                StopParticleFxLooped(particleFx, false)
            end

            if not DoesEntityExist(treasureObject) then
                print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD SuccessCallback: Kiste existiert nicht mehr.")
                return
            end

            print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD SuccessCallback: Kiste (Entity: " .. tostring(treasureObject) .. ") wird auf finaler Position Z: " .. tostring(currentTreasure.targetZ) .. " fixiert.")
            FreezeEntityPosition(treasureObject, true)

            currentTreasure.isDugUp = true
            print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD SuccessCallback: currentTreasure.isDugUp auf true gesetzt.")
            ESX.ShowNotification("Du hast die Kiste ausgegraben!")
            print("[Schatzkarte-Skript] DigUpChest - HUD SuccessCallback: Kiste als ausgegraben markiert.")

            print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD SuccessCallback: Entferne altes 'Graben'-Target.")
            exports.ox_target:removeLocalEntity(treasureObject)
            Wait(50)

            print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD SuccessCallback: Rufe AddTargetToDugUpChest auf.")
            AddTargetToDugUpChest()
            print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD SuccessCallback: Abgeschlossen.")
        end,
        function() -- cancelCallback
            print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD CancelCallback: Gestartet (Graben abgebrochen).")
            ClearPedTasks(playerPed)
            if propEntity then
                DetachEntity(propEntity, false, false)
                DeleteEntity(propEntity)
                SetModelAsNoLongerNeeded(GetHashKey(animConfig.prop))
                propEntity = nil
                print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD CancelCallback: Prop entfernt.")
            end
            if particleFx then
                StopParticleFxLooped(particleFx, false)
                print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD CancelCallback: Partikel gestoppt.")
            end
            ESX.ShowNotification("Graben abgebrochen.", "error")
            -- Hier könnte man auch das treasureObject wieder löschen/zurücksetzen, falls gewünscht
            print("[Schatzkarte-Skript DEBUG] DigUpChest - HUD CancelCallback: Abgeschlossen.")
        end
    )
end

-- Funktion zum Hinzufügen der oxtarget-Zone zur ausgegrabenen Kiste
function AddTargetToDugUpChest()
    print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest: Funktion aufgerufen. treasureObject: " .. tostring(treasureObject))
    if not DoesEntityExist(treasureObject) then
        print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest: FEHLER - treasureObject (ID: " .. tostring(treasureObject) .. ") existiert NICHT.")
        return
    end
    if not currentTreasure or type(currentTreasure) ~= "table" then
        print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest: FEHLER - currentTreasure ist nil oder keine Tabelle.")
        return
    end
    print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest: currentTreasure.isDugUp = " .. tostring(currentTreasure.isDugUp) .. ", currentTreasure.isOpened = " .. tostring(currentTreasure.isOpened))

    if not currentTreasure.isDugUp then
         print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest: FEHLER - Kiste ist NICHT als ausgegraben markiert (isDugUp ist false).")
        return
    end
    if currentTreasure.isOpened then
        print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest: FEHLER - Kiste ist bereits als geöffnet markiert.")
        return
    end

    print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest: Versuche Öffnen-Target für Entity ID " .. tostring(treasureObject) .. " (Modell: " .. GetEntityModel(treasureObject) .. ")")

    print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest: Entferne möglicherweise vorhandene alte Targets für Entity: " .. tostring(treasureObject))
    exports.ox_target:removeLocalEntity(treasureObject) -- Versuchen, alle Targets für diese Entität zu löschen
    Wait(50) -- Kurze Pause geben, damit ox_target die Änderung verarbeiten kann

    exports.ox_target:addLocalEntity(treasureObject, {
        {
            name = 'schatzkarte:open_chest',
            label = 'Öffnen',
            icon = 'fas fa-box-open',
            distance = Config.OxTarget.OpenDistance, -- Jetzt 3.0 oder höher
            onSelect = function(data)
                print("[Schatzkarte-Skript DEBUG] ox_target: onSelect 'Öffnen' ausgelöst für Entity " .. tostring(data.entity))
                OpenChest()
            end,
            canInteract = function(entity, distance, data)
                print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest - canInteract: Aufgerufen. Entity: " .. tostring(entity) .. ", treasureObject: " .. tostring(treasureObject))
                if not currentTreasure or type(currentTreasure) ~= "table" then
                    print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest - canInteract: FEHLER - currentTreasure ist nil oder keine Tabelle.")
                    return false
                end
                local treasureStillExists = DoesEntityExist(treasureObject)
                local isMarkedAsDugUp = currentTreasure.isDugUp
                local notOpenedYet = not currentTreasure.isOpened
                local can = treasureStillExists and isMarkedAsDugUp and notOpenedYet
                print("[Schatzkarte-Skript DEBUG] AddTargetToDugUpChest - canInteract: Kiste existent? " .. tostring(treasureStillExists) .. ". Ausgegraben? " .. tostring(isMarkedAsDugUp) .. ". Nicht geöffnet? " .. tostring(notOpenedYet) .. ". Ergebnis: " .. tostring(can))
                return can
            end,
            debug = true -- Debug-Modus von ox_target für diese Option aktivieren
        }
    })
    print("[Schatzkarte-Skript DEBUG] ox_target:addLocalEntity für 'Öffnen' (Entity ID: " .. tostring(treasureObject) .. ") aufgerufen.")
end

-- Funktion zum Öffnen der Kiste
function OpenChest()
    print("[Schatzkarte-Skript DEBUG] OpenChest: Funktion aufgerufen. treasureObject: " .. tostring(treasureObject))
    if not DoesEntityExist(treasureObject) then
        print("[Schatzkarte-Skript DEBUG] OpenChest: FEHLER - treasureObject (ID: " .. tostring(treasureObject) .. ") existiert NICHT.")
        return
    end
     if not currentTreasure or type(currentTreasure) ~= "table" then
        print("[Schatzkarte-Skript DEBUG] OpenChest: FEHLER - currentTreasure ist nil oder keine Tabelle.")
        return
    end
    print("[Schatzkarte-Skript DEBUG] OpenChest: currentTreasure.isDugUp = " .. tostring(currentTreasure.isDugUp) .. ", currentTreasure.isOpened = " .. tostring(currentTreasure.isOpened))

    if not currentTreasure.isDugUp then
        print("[Schatzkarte-Skript DEBUG] OpenChest: FEHLER - Kiste ist nicht als ausgegraben markiert.")
        return
    end
    if currentTreasure.isOpened then
        print("[Schatzkarte-Skript DEBUG] OpenChest: FEHLER - Kiste bereits geöffnet.")
        return
    end

    print("[Schatzkarte-Skript DEBUG] OpenChest: Bedingungen erfüllt, fahre fort mit Öffnen für Entity ID " .. tostring(treasureObject))

    local playerPed = PlayerPedId()
    local openingAnimConfig = Config.Animations.opening

    print("[Schatzkarte-Skript DEBUG] OpenChest: Bedingungen erfüllt, fahre fort mit Öffnen für Entity ID " .. tostring(treasureObject))

    -- Animation abspielen (optional)
    if openingAnimConfig and openingAnimConfig.dict and openingAnimConfig.anim then
        print("[Schatzkarte-Skript DEBUG] OpenChest: Starte Öffnen-Animation: " .. openingAnimConfig.dict .. ", " .. openingAnimConfig.anim)
        RequestAnimDict(openingAnimConfig.dict)
        local animLoadAttempts = 0
        local animDictLoaded = false
        while not HasAnimDictLoaded(openingAnimConfig.dict) do
            Wait(50) -- Kürzere Wartezeit für schnellere Reaktion bei kleinen Dicts
            animLoadAttempts = animLoadAttempts + 1
            if animLoadAttempts > 30 then -- Timeout nach 1.5 Sekunden für kleine Gesten-Animation
                print("[Schatzkarte-Skript DEBUG] OpenChest: Laden des AnimDicts '" .. openingAnimConfig.dict .. "' für Öffnen dauert zu lange! Überspringe Animationsteil.")
                break
            end
        end
        if HasAnimDictLoaded(openingAnimConfig.dict) then
            animDictLoaded = true
            print("[Schatzkarte-Skript DEBUG] OpenChest: AnimDict '" .. openingAnimConfig.dict .. "' geladen.")
        end

        if animDictLoaded then
            TaskPlayAnim(playerPed, openingAnimConfig.dict, openingAnimConfig.anim, 8.0, -8.0, -1, 0, 0, false, false, false) -- -1 für Loop/bis abgebrochen
            print("[Schatzkarte-Skript DEBUG] OpenChest: TaskPlayAnim für Öffnen gestartet.")
        else
            print("[Schatzkarte-Skript DEBUG] OpenChest: AnimDict für Öffnen nicht geladen, Animation wird nicht abgespielt.")
        end
    else
        print("[Schatzkarte-Skript DEBUG] OpenChest: Keine Öffnen-Animation konfiguriert oder Konfiguration unvollständig.")
    end

    -- Spieleranimation starten (wenn geladen)
    if animDictLoaded then
        TaskPlayAnim(playerPed, openingAnimConfig.dict, openingAnimConfig.anim, 8.0, -8.0, -1, 0, 0, false, false, false)
        print("[Schatzkarte-Skript DEBUG] OpenChest: TaskPlayAnim für Öffnen gestartet (looping).")
    end

    print("[Schatzkarte-Skript DEBUG] Vor Aufruf von HUD.StartProgress in OpenChest.")
    print("[Schatzkarte-Skript DEBUG] Typ von HUD: " .. type(HUD))
    if type(HUD) == 'table' then
        print("[Schatzkarte-Skript DEBUG] Typ von HUD.StartProgress: " .. type(HUD.StartProgress))
    else
        print("[Schatzkarte-Skript DEBUG] HUD ist beim Aufruf keine Tabelle!")
    end
    HUD.StartProgress('schatzkarte_opening', Config.ProgressTexts.opening, openingAnimConfig.duration or 2000,
        function() -- successCallback
            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Gestartet.")
            ClearPedTasks(playerPed)
            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: ClearPedTasks aufgerufen.")

            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Triggere Server-Event 'schatzkarte:giveReward'.")
            TriggerServerEvent('schatzkarte:giveReward')
            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Server-Event 'schatzkarte:giveReward' getriggert.")

            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Setze currentTreasure.isOpened auf true.")
            currentTreasure.isOpened = true
            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: currentTreasure.isOpened ist jetzt " .. tostring(currentTreasure.isOpened))

            if DoesEntityExist(treasureObject) then
                print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Kiste existiert, entferne ox_target für Entity ID " .. tostring(treasureObject))
                exports.ox_target:removeLocalEntity(treasureObject)
                print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: ox_target entfernt. Lösche Entity ID " .. tostring(treasureObject))
                DeleteEntity(treasureObject)
                print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Entity gelöscht.")
                treasureObject = nil
            else
                print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Kiste existiert NICHT mehr, als sie entfernt werden sollte.")
            end

            if treasureBlip then
                print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Entferne Blip.")
                RemoveBlip(treasureBlip)
                treasureBlip = nil
                print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Blip entfernt.")
            else
                print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Kein Blip zum Entfernen vorhanden.")
            end

            ESX.ShowNotification("Schatz erhalten!")
            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Clientseitige 'Schatz erhalten!' Benachrichtigung angezeigt.")

            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Setze currentTreasure zurück (nil).")
            currentTreasure = nil
            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: currentTreasure ist jetzt " .. tostring(currentTreasure) .. ". Funktion beendet.")
            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD SuccessCallback: Abgeschlossen.")
        end,
        function() -- cancelCallback
            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD CancelCallback: Gestartet (Öffnen abgebrochen).")
            ClearPedTasks(playerPed)
            ESX.ShowNotification("Öffnen abgebrochen.", "error")
            print("[Schatzkarte-Skript DEBUG] OpenChest - HUD CancelCallback: Abgeschlossen.")
        end
    )
end

-- Die Funktion DisplayBlockingProgressText wurde entfernt und durch client/hud.lua ersetzt.

print("Schatzkarten-Skript: Client geladen und bereit.")
