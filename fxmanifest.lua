fx_version 'cerulean'
game 'gta5'

author 'SimpleDevelopments'
description 'Simple911 v2 - modern standalone-first emergency call and dispatch system'
version '1.0'

ui_page 'web/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_script 'server/versioncheck.js'
server_script 'server/discord.lua'
server_script 'server/main.lua'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}
