-- Konfigurationsdatei für das Schatzkarten-Skript

Config = {}

-- [[ Schatzorte ]]
-- Definiere hier mögliche Schatzorte. Jeder Ort ist eine Tabelle mit 'name', 'coords' und 'heading'.
Config.TreasureLocations = {
    {
        name = "Test Mine Shaft",
        coords = vector3(-242.0855, 715.2376, 207.4135),
        heading = 228.5781
    },
    {
        name = "North Chumash",
        coords = vector3(-295.0295, 919.6934, 206.8909),
        heading = 178.4649
    }
    -- Füge weitere Orte hinzu
}

-- [[ Kisten Modelle ]]
-- Definiere hier die Modelle für die Schatzkisten
Config.ChestModels = {
    buried = `prop_tool_box_05`,
    dugUp = `prop_tool_box_05`   -- Vorerst dasselbe Modell, kann später angepasst werden, wenn es eine "geöffnete" Variante gibt
}
-- Wichtig: Stelle sicher, dass dieses Modell (`prop_tool_box_05`) auf deinem Server existiert.

-- [[ Partikel Effekte ]]
-- [[ Partikel Effekte ]] (Vorübergehend auskommentiert für Tests)
-- [[ Partikel Effekte ]]
Config.ParticleEffects = {
    digging = {
        dict = "core",
        name = "ent_amb_dirt_mound_dig",
        scale = 0.7, -- Wunsch des Benutzers
        offset = { x = 0.0, y = 0.0, z = -0.3 }
    }
}

-- [[ Kisten Spawn Offset ]]
-- Wie weit die Kiste unter die durch PlaceObjectOnGroundProperly ermittelte Z-Koordinate gedrückt werden soll.
-- Ein kleiner negativer Wert, z.B. -0.1 bis -0.3, je nach Kistengröße und gewünschter Tiefe.
Config.ChestSpawnOffsetZ = -0.15

-- [[ Belohnungen ]]
-- Definiere hier mögliche Belohnungen. Du kannst Items oder Geld hinzufügen.
-- Das Format hängt davon ab, wie dein Inventar- und Geldsystem funktioniert.
-- Beispiel für ESX:
-- Config.Rewards = {
--     {type = 'item', name = 'goldnugget', amount = math.random(1, 5), label = 'Goldnugget'},
--     {type = 'money', account = 'black_money', amount = math.random(500, 2000), label = 'Schwarzgeld'},
--     {type = 'item', name = 'lockpick', amount = math.random(1,3), label = 'Dietrich'}
-- }
-- Beispiel für QBCore:
-- Beispiel für ESX:
Config.Rewards = {
    {type = 'item', name = 'goldnugget', count = math.random(1, 3), label = 'Goldnugget'},
    {type = 'item', name = 'dia_box', count = 1, label = 'Diamantenkiste'},
    {type = 'item', name = 'schatzkarte', count = 1, label = 'Eine weitere Schatzkarte!'}, -- Beispiel für Schatzkarte als Belohnung
    {type = 'money', amount = math.random(500, 2500), label = 'Bargeld'},
    {type = 'account', account_name = 'black_money', amount = math.random(200, 1000), label = 'Schwarzgeld'},
}


-- [[ Schatzkarten Item ]]
-- Name des Items, das die Schatzsuche startet (muss in deinem Inventarsystem existieren)
Config.TreasureMapItem = "schatzkarte" -- Stelle sicher, dass dieses Item in deiner ESX Datenbank `items` Tabelle existiert.

-- Damit das Item das Event 'schatzkarte:startHunt' auslöst, wenn es benutzt wird,
-- musst du es in deinem ESX serverseitigen Item-Skript registrieren, z.B. so:
-- ESX.RegisterUsableItem('schatzkarte', function(source)
--     TriggerClientEvent('schatzkarte:startHunt', source)
-- end)
-- Stelle auch sicher, dass das Item in der `items` Tabelle deiner Datenbank eingetragen ist:
-- INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
-- ('schatzkarte', 'Schatzkarte', 1, 0, 1); -- weight, rare, can_remove anpassen

-- [[ oxtarget Optionen ]]
Config.OxTarget = {
    DigDistance = 2.0, -- Distanz, aus der die "Graben"-Option erscheint
    OpenDistance = 3.0 -- Testweise erhöht, um Distanzprobleme auszuschließen
}

-- [[ Animationen ]]
Config.Animations = {
    digging = {
        dict = "random@burial",
        anim = "a_burial",
        duration = 6000, -- Dauer ggf. anpassen
        prop = "prop_tool_shovel",
        propBone = 28422, -- SKEL_R_Hand (Rechte Hand)
        propOffsetX = 0.0,
        propOffsetY = 0.05, -- Leicht nach vorne/hinten in der Hand, anpassen
        propOffsetZ = 0.20, -- Dein Z-Offset, ggf. anpassen
        propRotX = 0.0,   -- Rotation um X-Achse, anpassen
        propRotY = 0.0,   -- Rotation um Y-Achse, anpassen
        propRotZ = 0.0    -- Rotation um Z-Achse (Griffausrichtung), anpassen
    },
    opening = {dict = "gestures@m@standing@casual", anim = "gesture_what_soft", duration = 2000}
}

-- [[ Fortschrittsbalken Texte ]]
Config.ProgressTexts = {
    digging = "Grabe Schatz aus...",
    opening = "Öffne Kiste..."
}

-- [[ Sonstiges ]]
Config.Blip = {
    sprite = 1, -- Blip Sprite (siehe FiveM Docs für IDs)
    color = 5,  -- Blip Farbe (siehe FiveM Docs für IDs)
    scale = 1.0,
    shortRange = true,
    name = "Schatzort"
}

-- Funktion zum Abrufen einer zufälligen Belohnung (Beispiel)
-- Du musst dies möglicherweise anpassen, je nachdem, wie du Belohnungen definierst
function GetRandomReward()
    if #Config.Rewards > 0 then
        return Config.Rewards[math.random(1, #Config.Rewards)]
    end
    return nil -- Keine Belohnungen konfiguriert
end

-- Funktion zum Abrufen eines Schatzortes (für spätere Erweiterungen, z.B. zufällig oder per ID)
-- Funktion zum Abrufen eines Schatzortes (kann optional bleiben für spezifische Aufrufe)
function GetTreasureLocation(index)
    index = index or 1
    if Config.TreasureLocations[index] then
        return Config.TreasureLocations[index]
    end
    print("WARNUNG: Schatzort mit Index " .. tostring(index) .. " nicht in Config.TreasureLocations gefunden.")
    if #Config.TreasureLocations > 0 then
        print("Verwende stattdessen den ersten verfügbaren Ort (falls vorhanden).")
        return Config.TreasureLocations[1]
    end
    return nil
end

-- Funktion zum Abrufen eines ZUFÄLLIGEN Schatzortes
function GetRandomTreasureLocation()
    if Config.TreasureLocations and #Config.TreasureLocations > 0 then
        local randomIndex = math.random(1, #Config.TreasureLocations)
        print("[Schatzkarte-Skript DEBUG] GetRandomTreasureLocation: Zufälliger Index " .. randomIndex .. " ausgewählt.")
        return Config.TreasureLocations[randomIndex]
    end
    print("[Schatzkarte-Skript DEBUG] GetRandomTreasureLocation: Keine Schatzorte in Config.TreasureLocations gefunden.")
    return nil -- Keine Orte konfiguriert
end

print("Schatzkarten-Skript: Konfiguration geladen")
