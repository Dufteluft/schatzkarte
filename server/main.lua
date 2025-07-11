-- Server-Seite des Schatzkarten-Skripts
-- ESX wird nun über fxmanifest.lua als shared_script geladen und sollte global verfügbar sein.

RegisterNetEvent('schatzkarte:giveReward', function()
    local src = source
    print("[Schatzkarte-Skript DEBUG][SERVER] Event 'schatzkarte:giveReward' empfangen von Quelle: " .. src)

    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then
        print("[Schatzkarte-Skript DEBUG][SERVER] FEHLER: xPlayer nicht gefunden für Quelle: " .. src)
        return
    end
    print("[Schatzkarte-Skript DEBUG][SERVER] xPlayer gefunden: " .. xPlayer.getName() .. " (Identifier: " .. xPlayer.identifier .. ")")

    local reward = GetRandomReward()

    if not reward then
        print("[Schatzkarte-Skript DEBUG][SERVER] Keine Belohnungen in Config.Rewards gefunden oder GetRandomReward() gab nil zurück.")
        TriggerClientEvent('esx:showNotification', src, "Leider war diese Kiste leer.")
        return
    end
    print("[Schatzkarte-Skript DEBUG][SERVER] Ausgewählte Belohnung für Spieler " .. xPlayer.getName() .. ":")
    print(json.encode(reward)) -- Gibt die gesamte Belohnungstabelle aus

    if reward.type == 'item' then
        local itemName = reward.name
        local itemCount = reward.count or reward.amount or 1
        print("[Schatzkarte-Skript DEBUG][SERVER] Versuche Item hinzuzufügen: Name=" .. itemName .. ", Anzahl=" .. itemCount)
        xPlayer.addInventoryItem(itemName, itemCount)
        print("[Schatzkarte-Skript DEBUG][SERVER] xPlayer.addInventoryItem aufgerufen.")
        local itemLabel = ESX.GetItemLabel(itemName) or itemName
        TriggerClientEvent('esx:showNotification', src, "Du hast " .. itemCount .. "x " .. itemLabel .. " gefunden!")
        print("[Schatzkarte-Skript DEBUG][SERVER] Item-Benachrichtigung an Client gesendet.")
    elseif reward.type == 'money' then
        local amount = reward.amount
        print("[Schatzkarte-Skript DEBUG][SERVER] Versuche Geld hinzuzufügen: Menge=" .. amount)
        xPlayer.addMoney(amount)
        print("[Schatzkarte-Skript DEBUG][SERVER] xPlayer.addMoney aufgerufen.")
        TriggerClientEvent('esx:showNotification', src, "Du hast " .. ESX.Math.GroupDigits(amount) .. "$ gefunden!")
        print("[Schatzkarte-Skript DEBUG][SERVER] Geld-Benachrichtigung an Client gesendet.")
    elseif reward.type == 'account' then
        local accountName = reward.account_name or 'bank'
        local amount = reward.amount
        print("[Schatzkarte-Skript DEBUG][SERVER] Versuche Kontogeld hinzuzufügen: Konto=" .. accountName .. ", Menge=" .. amount)
        xPlayer.addAccountMoney(accountName, amount)
        print("[Schatzkarte-Skript DEBUG][SERVER] xPlayer.addAccountMoney aufgerufen.")
        TriggerClientEvent('esx:showNotification', src, "Dir wurden " .. ESX.Math.GroupDigits(amount) .. "$ auf dein Konto '" .. accountName .. "' gutgeschrieben!")
        print("[Schatzkarte-Skript DEBUG][SERVER] Kontogeld-Benachrichtigung an Client gesendet.")
    elseif reward.type == 'placeholder' then
        local itemName = reward.name
        local itemCount = reward.count or reward.amount or 1
        print("[Schatzkarte-Skript DEBUG][SERVER] Versuche Placeholder-Item hinzuzufügen: Name=" .. itemName .. ", Anzahl=" .. itemCount)
        xPlayer.addInventoryItem(itemName, itemCount) -- Annahme: Placeholder ist ein Item
        print("[Schatzkarte-Skript DEBUG][SERVER] xPlayer.addInventoryItem für Placeholder aufgerufen.")
        TriggerClientEvent('esx:showNotification', src, "Du hast '" .. (reward.label or itemName) .. "' gefunden!")
        print("[Schatzkarte-Skript DEBUG][SERVER] Placeholder-Benachrichtigung an Client gesendet.")
    else
        print("[Schatzkarte-Skript DEBUG][SERVER] FEHLER: Unbekannter Belohnungstyp: " .. reward.type)
        TriggerClientEvent('esx:showNotification', src, "Fehler bei der Belohnungsvergabe (unbekannter Typ).")
    end
    print("[Schatzkarte-Skript DEBUG][SERVER] Event 'schatzkarte:giveReward' für Quelle " .. src .. " abgeschlossen.")
end)

RegisterNetEvent('schatzkarte:usedMap', function(itemName)
    local src = source
    print("[Schatzkarte-Skript DEBUG][SERVER] Event 'schatzkarte:usedMap' empfangen von Quelle: " .. src .. " für Item: " .. itemName)
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then
        print("[Schatzkarte-Skript DEBUG][SERVER] 'schatzkarte:usedMap' FEHLER: xPlayer nicht gefunden für Quelle: " .. src)
        return
    end

    if itemName and xPlayer.getInventoryItem(itemName) and xPlayer.getInventoryItem(itemName).count > 0 then
        xPlayer.removeInventoryItem(itemName, 1)
        print("[Schatzkarte-Skript DEBUG][SERVER] 'schatzkarte:usedMap': Item '" .. itemName .. "' von Spieler " .. xPlayer.getName() .. " entfernt.")
        -- Optional: TriggerClientEvent('esx:showNotification', src, "Schatzkarte verbraucht.")
    else
        print("[Schatzkarte-Skript DEBUG][SERVER] 'schatzkarte:usedMap': Item '" .. itemName .. "' nicht im Inventar von Spieler " .. xPlayer.getName() .. " gefunden oder Anzahl ist 0.")
        -- Hier könnte man dem Client signalisieren, dass die Karte nicht entfernt werden konnte und die Suche abbrechen,
        -- aber für die aktuelle einfache Implementierung lassen wir den Client weitermachen.
    end
end)

print("Schatzkarten-Skript: Server geladen und bereit für ESX Belohnungen und Item-Entfernung.")
