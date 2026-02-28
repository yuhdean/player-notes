fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'player-notes'
author 'YuhDean'
description 'A simple player notes system for FiveM servers.'
version '1.1.0'

dependencies {
    'ox_lib'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client.lua'
server_script 'server.lua'
