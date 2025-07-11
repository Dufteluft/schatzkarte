-- Manifest für das Schatzkarten-Skript
fx_version 'cerulean'
game 'gta5'

author 'Dein Name'
description 'Schatzkarten-Skript mit oxtarget'
version '1.0.0'

-- Zu ladende Skriptdateien
shared_scripts {
    '@es_extended/imports.lua', -- ESX Import
    'config.lua' -- Konfigurationsdatei für Client und Server
}

client_scripts {
    'client/hud.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

-- Abhängigkeiten
dependencies {
    'es_extended', -- Stelle sicher, dass ESX vor diesem Skript geladen wird
    'ox_target'    -- ox_target wird ebenfalls benötigt
}

-- Lua54 aktivieren
lua54 'yes'
