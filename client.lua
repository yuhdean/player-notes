local function showNotification(data)
    data.position = 'center-right'
    lib.notify(data)
end

local function openCreateNoteDialog()
    local input = lib.inputDialog('Create Note', {
        {
            type = 'input',
            label = 'Title',
            placeholder = 'Short note title',
            required = true,
            min = 3,
            max = 50
        },
        {
            type = 'textarea',
            label = 'Note',
            placeholder = 'Write your note here',
            required = true,
            min = 1,
            max = 500
        }
    })

    if not input then return end

    local success, message = lib.callback.await('player-notes:createNote', false, {
        title = input[1],
        body = input[2]
    })

    showNotification({
        title = success and 'Note Saved' or 'Note Failed',
        description = message,
        type = success and 'success' or 'error'
    })
end

local showNoteDetails

local function openNotesList()
    local notes = lib.callback.await('player-notes:getNotes', false)

    if not notes or #notes == 0 then
        showNotification({
            title = 'Notes',
            description = 'You do not have any saved notes yet.',
            type = 'inform'
        })

        return
    end

    local options = {}

    for i = 1, #notes do
        local note = notes[i]
        options[#options + 1] = {
            title = ('%s - %s'):format(note.createdAt, note.title),
            description = note.body,
            icon = 'note-sticky',
            onSelect = function()
                showNoteDetails(note)
            end
        }
    end

    lib.registerContext({
        id = 'player_notes_list',
        title = 'Your Notes',
        options = options
    })

    lib.showContext('player_notes_list')
end

local function confirmDeleteNote(note)
    local result = lib.alertDialog({
        header = 'Delete Note',
        content = ('Delete "%s"? This cannot be undone.'):format(note.title),
        centered = true,
        cancel = true,
        labels = {
            cancel = 'Cancel',
            confirm = 'Delete'
        }
    })

    if result ~= 'confirm' then
        showNoteDetails(note)
        return
    end

    local success, message = lib.callback.await('player-notes:deleteNote', false, note.id)

    showNotification({
        title = success and 'Note Deleted' or 'Delete Failed',
        description = message,
        type = success and 'success' or 'error'
    })

    if success then
        openNotesList()
    else
        showNoteDetails(note)
    end
end

local function openEditNoteDialog(note)
    local input = lib.inputDialog('Edit Note', {
        {
            type = 'input',
            label = 'Title',
            placeholder = 'Short note title',
            required = true,
            min = 3,
            max = 50,
            default = note.title
        },
        {
            type = 'textarea',
            label = 'Note',
            placeholder = 'Write your note here',
            required = true,
            min = 1,
            max = 500,
            default = note.body
        }
    })

    if not input then
        showNoteDetails(note)
        return
    end

    local success, message = lib.callback.await('player-notes:updateNote', false, {
        id = note.id,
        title = input[1],
        body = input[2]
    })

    showNotification({
        title = success and 'Note Updated' or 'Update Failed',
        description = message,
        type = success and 'success' or 'error'
    })

    if success then
        openNotesList()
    else
        showNoteDetails(note)
    end
end

showNoteDetails = function(note)
    lib.registerContext({
        id = 'player_notes_detail',
        title = note.title,
        menu = 'player_notes_list',
        options = {
            {
                title = 'Created',
                description = note.createdAt,
                readOnly = true
            },
            {
                title = 'Note',
                description = note.body,
                readOnly = true
            },
            {
                title = 'Edit Note',
                description = 'Change the title or body of this note.',
                icon = 'pen',
                onSelect = function()
                    openEditNoteDialog(note)
                end
            },
            {
                title = 'Delete Note',
                description = 'Remove this note after confirmation.',
                icon = 'trash',
                iconColor = '#c92a2a',
                onSelect = function()
                    confirmDeleteNote(note)
                end
            }
        }
    })

    lib.showContext('player_notes_detail')
end

RegisterCommand('note', function(_, args)
    if args[1] == 'create' then
        openCreateNoteDialog()
        return
    end

    if args[1] == 'list' then
        openNotesList()
        return
    end

    showNotification({
        title = 'Notes',
        description = 'Usage: /note create or /note list',
        type = 'inform'
    })
end, false)
