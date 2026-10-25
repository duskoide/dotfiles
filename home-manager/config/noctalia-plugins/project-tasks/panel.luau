-- Project Tasks: this panel owns writes; the bar only reads the saved model.
local model = require("./model.luau")
local storage = model.storage(noctalia)
local data, loadError
local projectFilter = nil -- nil means all projects
local editor, errorText, deleteId = nil, nil, nil
local editorRevision = 0
local render

local function publish()
    noctalia.state.set("pending", model.pending(data))
end

local function commit(candidate, err)
    if not candidate then errorText = err; render(); return false end
    local ok, saveErr = storage.save(candidate)
    if not ok then errorText = saveErr; render(); return false end
    data, errorText = candidate, nil
    publish()
    return true
end

local function startEditor(task)
    editorRevision = editorRevision + 1
    local deadlineDate, deadlineTime = model.deadlineParts(task and task.deadline)
    editor = {
        id = task and task.id or nil,
        title = task and task.title or "",
        project = task and task.project or projectFilter or "Inbox",
        status = task and task.status or "todo",
        url = task and task.url or "",
        deadlineDate = deadlineDate,
        deadlineTime = deadlineTime,
    }
    errorText, deleteId = nil, nil
    render()
end

local function saveEditor()
    local candidate, err = model.upsert(data, editor.id, editor)
    if commit(candidate, err) then
        -- Keep a newly created/moved task visible after saving.
        if projectFilter then projectFilter = model.trim(editor.project); if projectFilter == "" then projectFilter = "Inbox" end end
        editor = nil
        render()
    end
end

local function setStatus(task, index)
    local status = model.statusIds[(tonumber(index) or -1) + 1]
    if not status then return end
    local draft = { title = task.title, project = task.project, url = task.url, deadline = task.deadline, status = status }
    local candidate, err = model.upsert(data, task.id, draft)
    if commit(candidate, err) then render() end
end

local function openLink(url)
    if url == "" or not model.validUrl(url) then return end
    -- Never interpolate a user URL into a shell command.
    local accepted = noctalia.runAsync({ "xdg-open", url }, function(result)
        if result.exitCode ~= 0 or result.timedOut then
            noctalia.notify("Project Tasks", "Could not open the task link in your browser.")
        end
    end)
    if accepted then panel.close()
    else errorText = "Could not start xdg-open. Is it installed?"; render() end
end

local function field(label, props)
    return ui.column({ align = "stretch", gap = 4 }, {
        ui.label({ text = label, color = "on_surface_variant" }),
        ui.input(props),
    })
end

local function editorTree()
    -- Inputs are uncontrolled. Fresh keys seed a new editor; stable keys retain
    -- what the user typed while a validation error or status change re-renders.
    local prefix = "editor-" .. editorRevision .. "-"
    local current = editor
    return ui.column({ key = prefix .. "form", align = "stretch", gap = 12 }, {
        ui.label({ text = current.id and "Edit task" or "New task", fontWeight = "bold" }),
        field("Title", {
            key = prefix .. "title", value = current.title, placeholder = "What needs doing?", focus = true,
            onChange = function(value) current.title = value end,
            onSubmit = function(value) current.title = value; saveEditor() end,
        }),
        field("Project (type a name to create one)", {
            key = prefix .. "project", value = current.project, placeholder = "Inbox",
            onChange = function(value) current.project = value end,
        }),
        ui.column({ align = "stretch", gap = 4 }, {
            ui.label({ text = "Status", color = "on_surface_variant" }),
            ui.select({ key = prefix .. "status", options = model.statuses,
                selectedIndex = model.statusIndex(current.status),
                onChange = function(index)
                    current.status = model.statusIds[(tonumber(index) or -1) + 1] or current.status
                end,
            }),
        }),
        ui.column({ align = "stretch", gap = 4 }, {
            ui.label({ text = "Deadline (local time, optional)", color = "on_surface_variant" }),
            ui.row({ gap = 8, align = "center" }, {
                ui.input({
                    key = prefix .. "deadline-date", value = current.deadlineDate, placeholder = "YYYY-MM-DD", width = 240,
                    onChange = function(value) current.deadlineDate = value end,
                }),
                ui.input({
                    key = prefix .. "deadline-time", value = current.deadlineTime, placeholder = "HH:MM (24h)", width = 200,
                    onChange = function(value) current.deadlineTime = value end,
                    onSubmit = function(value) current.deadlineTime = value; saveEditor() end,
                }),
            }),
        }),
        field("Task / document URL (optional)", {
            key = prefix .. "url", value = current.url, placeholder = "https://docs.google.com/…",
            onChange = function(value) current.url = value end,
            onSubmit = function(value) current.url = value; saveEditor() end,
        }),
        ui.label({ text = "Links open in your browser. Status is tracked locally, not synced.", color = "on_surface_variant" }),
        ui.row({ gap = 8 }, {
            ui.button({ key = "save-task", text = "Save task", glyph = "check", variant = "primary", onClick = saveEditor }),
            ui.button({ key = "cancel-edit", text = "Cancel", onClick = function() editor, errorText = nil, nil; render() end }),
        }),
    })
end

local function taskTree(task)
    local id = "task-" .. task.id
    local color = ({ todo = "on_surface_variant", doing = "primary", blocked = "error", done = "tertiary" })[task.status]
    local hasDeadline = task.deadline ~= nil and task.deadline ~= ""
    local children = {
        ui.row({ key = id, gap = 8, align = "center" }, {
            ui.column({ width = 350, align = "stretch", gap = 3 }, {
                ui.label({ text = task.title, maxWidth = 350, color = "on_surface", fontWeight = "medium" }),
                ui.label({ text = task.project .. " · " .. model.statuses[model.statusIndex(task.status) + 1], color = color, maxWidth = 350 }),
                -- Own line so a long project name cannot truncate the deadline.
                hasDeadline and ui.label({ text = "Due " .. task.deadline:sub(1, 10) .. " " .. task.deadline:sub(12),
                    color = "on_surface_variant", maxWidth = 350 }) or nil,
            }),
            ui.select({ key = id .. "-status", options = model.statuses, width = 155,
                selectedIndex = model.statusIndex(task.status),
                onChange = function(index) setStatus(task, index) end,
            }),
            ui.button({ key = id .. "-link", glyph = "external-link", width = 36, variant = "ghost",
                tooltip = task.url ~= "" and task.url or "No link — edit this task to add one",
                enabled = task.url ~= "", onClick = function() openLink(task.url) end,
            }),
            ui.button({ key = id .. "-edit", glyph = "pencil", width = 36, variant = "ghost",
                tooltip = "Edit task", onClick = function() startEditor(task) end,
            }),
            ui.button({ key = id .. "-delete", glyph = "trash", width = 36, variant = "ghost",
                tooltip = "Delete task", onClick = function() deleteId = task.id; errorText = nil; render() end,
            }),
        }),
    }
    if deleteId == task.id then
        table.insert(children, ui.row({ key = id .. "-confirm", gap = 8 }, {
            ui.label({ text = "Delete this task?", flexGrow = 1, color = "error" }),
            ui.button({ key = "confirm-delete", text = "Delete", variant = "destructive", onClick = function()
                local candidate, err = model.remove(data, task.id)
                if commit(candidate, err) then deleteId = nil; render() end
            end }),
            ui.button({ text = "Cancel", onClick = function() deleteId = nil; render() end }),
        }))
    end
    return ui.column({ key = id .. "-container", align = "stretch", gap = 6, paddingV = 6 }, children)
end

render = function()
    local header = {
        ui.label({ text = "Project Tasks", fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
        ui.button({ glyph = "x", tooltip = "Close (unsaved draft is kept until reload)", onClick = function() panel.close() end }),
    }
    local root = { ui.row({ align = "center", gap = 8 }, header) }
    if loadError then
        table.insert(root, ui.label({ text = loadError, color = "error", maxWidth = 680 }))
        table.insert(root, ui.label({ text = "Editing is disabled to protect your data. Fix or restore tasks.json, then reopen this panel.", maxWidth = 680 }))
    else
        if errorText then table.insert(root, ui.label({ text = errorText, color = "error", maxWidth = 680 })) end
        if editor then
            table.insert(root, ui.scroll({ flexGrow = 1, align = "stretch", gap = 12 }, { editorTree() }))
        else
            local projects = model.projects(data)
            local options, selected = { "All projects" }, 0
            for i, project in ipairs(projects) do
                table.insert(options, project)
                if project == projectFilter then selected = i end
            end
            if selected == 0 then projectFilter = nil end
            table.insert(root, ui.row({ gap = 8, align = "center" }, {
                ui.select({ key = "project-filter", options = options, selectedIndex = selected, flexGrow = 1,
                    onChange = function(index) projectFilter = projects[tonumber(index) or 0]; deleteId = nil; render() end,
                }),
                ui.button({ key = "new-task", text = "New task", glyph = "plus", variant = "primary", onClick = function() startEditor(nil) end }),
            }))
            local rows = {}
            -- Project headings make the all-projects view a grouped list.
            for _, project in ipairs(projects) do
                if not projectFilter or projectFilter == project then
                    table.insert(rows, ui.label({ key = "project-" .. project, text = project, fontWeight = "bold", color = "primary", maxWidth = 680 }))
                    for _, task in ipairs(data.tasks) do
                        if task.project == project then table.insert(rows, taskTree(task)) end
                    end
                end
            end
            if #rows == 0 then
                table.insert(rows, ui.label({ text = "No tasks yet. Add a task and give it a project name.", color = "on_surface_variant", maxWidth = 680 }))
            end
            table.insert(root, ui.scroll({ key = "task-list", flexGrow = 1, align = "stretch", gap = 6 }, rows))
            table.insert(root, ui.label({ text = model.pending(data) .. " unfinished · " .. #data.tasks .. " total", color = "on_surface_variant" }))
        end
    end
    panel.render(ui.column({ flexGrow = 1, align = "stretch", gap = 12 }, root))
end

function onOpen()
    data, loadError = storage.load()
    errorText, deleteId = nil, nil
    if data then publish() end
    render()
end

function onClose()
    -- Committed changes are already durable. Keep an unsaved draft in memory
    -- for an accidental Escape; Cancel explicitly discards it.
end
