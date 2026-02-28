# player-notes
A simple notes creation / viewing system for your FiveM server

## Dependencies
- [ox_lib](https://github.com/overextended/ox_lib/releases)
- [oxmysql](https://github.com/overextended/oxmysql/releases) (Optional)

## Installation
- Download [player-notes](https://github.com/yuhdean/player-notes/releases)
- Unzip the file
- Drag and drop the folder into your server resources
- Ensure the folder in your server.cfg
- Done!

## Notes
- This script supports OxMySQL, but the support is turned off by default. Without OxMySQL, the notes will delete for all players upon restart. To turn on MySQL support, change the "Config.UseOxMySQL" value to true in the config.lua file.
