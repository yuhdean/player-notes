local playerNotes = {}
local useOxMySQL = Config.UseOxMySQL == true
local oxmysqlReady = false

local function loadOxMySQL()
    if not useOxMySQL then
        return false
    end

    if GetResourceState('oxmysql') ~= 'started' then
        print('[player-notes] Config.UseOxMySQL is enabled, but oxmysql is not started. Falling back to memory storage.')
        useOxMySQL = false
        return false
    end

    oxmysqlReady = true

    exports.oxmysql:query_async([[
        CREATE TABLE IF NOT EXISTS player_notes (
            id INT NOT NULL AUTO_INCREMENT,
            player_license VARCHAR(64) NOT NULL,
            title VARCHAR(50) NOT NULL,
            body TEXT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_player_license (player_license),
            INDEX idx_created_at (created_at)
        )
    ]])

    print('[player-notes] Using oxmysql persistence.')
    return true
end

local function getPlayerLicense(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 8) == 'license:' then
            return identifier
        end
    end
end

local function trim(value)
    return value and value:match('^%s*(.-)%s*$') or nil
end

local function validateNotePayload(payload)
    local title = trim(payload and payload.title)
    local body = trim(payload and payload.body)

    if not title or #title < 3 then
        return nil, nil, 'Title must be at least 3 characters.'
    end

    if #title > 50 then
        return nil, nil, 'Title cannot be longer than 50 characters.'
    end

    if not body or #body < 1 then
        return nil, nil, 'Note text cannot be empty.'
    end

    if #body > 500 then
        return nil, nil, 'Note text cannot be longer than 500 characters.'
    end

    return title, body
end

local function getStoredNotes(license)
    if useOxMySQL and oxmysqlReady then
        local notes = exports.oxmysql:query_async(
            [[
                SELECT id, title, body, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS createdAt
                FROM player_notes
                WHERE player_license = ?
                ORDER BY created_at DESC, id DESC
            ]],
            { license }
        )

        return notes or {}
    end

    return playerNotes[license] or {}
end

local function deleteStoredNote(license, noteId)
    if useOxMySQL and oxmysqlReady then
        local affectedRows = exports.oxmysql:update_async(
            'DELETE FROM player_notes WHERE id = ? AND player_license = ?',
            { noteId, license }
        )

        return affectedRows and affectedRows > 0
    end

    local notes = playerNotes[license]
    if not notes then
        return false
    end

    for i = 1, #notes do
        if notes[i].id == noteId then
            table.remove(notes, i)
            return true
        end
    end

    return false
end

local function updateStoredNote(license, noteId, title, body)
    if useOxMySQL and oxmysqlReady then
        local affectedRows = exports.oxmysql:update_async(
            'UPDATE player_notes SET title = ?, body = ? WHERE id = ? AND player_license = ?',
            { title, body, noteId, license }
        )

        return affectedRows and affectedRows > 0
    end

    local notes = playerNotes[license]
    if not notes then
        return false
    end

    for i = 1, #notes do
        if notes[i].id == noteId then
            notes[i].title = title
            notes[i].body = body
            return true
        end
    end

    return false
end

CreateThread(function()
    if not loadOxMySQL() then
        print('[player-notes] Using temporary in-memory storage.')
    end
end)

lib.callback.register('player-notes:createNote', function(source, payload)
    local license = getPlayerLicense(source)

    if not license then
        return false, 'No valid license identifier was found for your player.'
    end

    local title, body, validationError = validateNotePayload(payload)
    if validationError then
        return false, validationError
    end

    if useOxMySQL and oxmysqlReady then
        local insertedId = exports.oxmysql:insert_async(
            'INSERT INTO player_notes (player_license, title, body) VALUES (?, ?, ?)',
            { license, title, body }
        )

        if not insertedId then
            return false, 'The note could not be saved to the database.'
        end

        return true, 'Note saved.'
    end

    playerNotes[license] = playerNotes[license] or {}
    playerNotes[license][#playerNotes[license] + 1] = {
        id = #playerNotes[license] + 1,
        title = title,
        body = body,
        createdAt = os.date('%Y-%m-%d %H:%M:%S')
    }

    return true, 'Note saved in memory until the next server restart.'
end)

lib.callback.register('player-notes:getNotes', function(source)
    local license = getPlayerLicense(source)
    if not license then
        return {}
    end

    return getStoredNotes(license)
end)

lib.callback.register('player-notes:deleteNote', function(source, noteId)
    local license = getPlayerLicense(source)
    if not license then
        return false, 'No valid license identifier was found for your player.'
    end

    noteId = tonumber(noteId)
    if not noteId then
        return false, 'Invalid note id.'
    end

    if not deleteStoredNote(license, noteId) then
        return false, 'The note could not be deleted.'
    end

    if useOxMySQL and oxmysqlReady then
        return true, 'The note was deleted from your database.'
    end

    return true, 'The note was deleted from memory.'
end)

lib.callback.register('player-notes:updateNote', function(source, payload)
    local license = getPlayerLicense(source)
    if not license then
        return false, 'No valid license identifier was found for your player.'
    end

    local noteId = tonumber(payload and payload.id)
    if not noteId then
        return false, 'Invalid note id.'
    end

    local title, body, validationError = validateNotePayload(payload)
    if validationError then
        return false, validationError
    end

    if not updateStoredNote(license, noteId, title, body) then
        return false, 'The note could not be updated.'
    end

    if useOxMySQL and oxmysqlReady then
        return true, 'The note was updated in your database.'
    end

    return true, 'The note was updated in memory.'
end)

exports('getPlayerNotes', function(source)
    local license = getPlayerLicense(source)
    if not license then return {} end

    return getStoredNotes(license)
end)
