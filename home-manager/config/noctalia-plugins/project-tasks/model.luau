-- Plain Lua-compatible Luau: shared validation and transactional storage.
local M = {}
M.statuses = { "To Do", "In Progress", "Blocked", "Done" }
M.statusIds = { "todo", "doing", "blocked", "done" }

function M.trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.statusIndex(status)
    for i, value in ipairs(M.statusIds) do
        if value == status then return i - 1 end -- Noctalia selects are zero-based.
    end
    return nil
end

-- Optional local wall-clock deadlines: canonical "YYYY-MM-DDTHH:MM".
-- Keep this a string rather than a UTC timestamp so DST edits stay predictable.
local function clockParts(value)
    if type(value) ~= "string" then return nil end
    local year, month, day, hour, minute = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d)$")
    if not year then return nil end
    year, month, day, hour, minute = tonumber(year), tonumber(month), tonumber(day), tonumber(hour), tonumber(minute)
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if year < 1970 or year > 9999 or month < 1 or month > 12 or hour > 23 or minute > 59 then return nil end
    local leap = year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
    if day < 1 or day > days[month] + ((month == 2 and leap) and 1 or 0) then return nil end
    -- Pure calendar validation: identical in Lua/Luau, independent of timezone
    -- or later DST changes. The string remains a local wall-clock deadline.
    return string.format("%04d-%02d-%02dT%02d:%02d", year, month, day, hour, minute)
end

function M.validDeadline(value)
    if value == nil or value == "" then return true end
    return clockParts(value) ~= nil
end

function M.deadlineParts(value)
    if not M.validDeadline(value) or value == nil or value == "" then return "", "" end
    return value:sub(1, 10), value:sub(12)
end

function M.normalizeDeadline(date, time)
    date, time = M.trim(date or ""), M.trim(time or "")
    if date == "" and time == "" then return "" end
    if date == "" or time == "" then return nil, "Enter both a deadline date and time, or leave both blank." end
    local canonical = clockParts(date .. "T" .. time)
    if not canonical then return nil, "Use a real date as YYYY-MM-DD and a local time as HH:MM (24-hour)." end
    return canonical
end

function M.validUrl(url)
    if type(url) ~= "string" or #url > 4096 then return false end
    if url == "" then return true end
    if url:find("[%s%c]") then return false end
    return url:lower():match("^https?://[^/?#]+") ~= nil
end

local function integer(n)
    return type(n) == "number" and n >= 1 and n < 9007199254740991 and n % 1 == 0
end

local function textField(s, limit)
    return type(s) == "string" and #s <= limit and M.trim(s) ~= "" and not s:find("%c")
end

function M.validate(data)
    if type(data) ~= "table" or data.version ~= 1 or not integer(data.nextId)
        or type(data.tasks) ~= "table" then
        return nil, "Unsupported or invalid task file (expected version 1)."
    end
    local seen, count = {}, 0
    for key, task in pairs(data.tasks) do
        count = count + 1
        if not integer(key) or key > #data.tasks or type(task) ~= "table"
            or not integer(task.id) or task.id >= data.nextId or seen[task.id]
            or not textField(task.title, 240) or not textField(task.project, 80)
            or M.statusIndex(task.status) == nil or not M.validUrl(task.url)
            or not M.validDeadline(task.deadline) then
            return nil, "Invalid task data; the original file has not been changed."
        end
        seen[task.id] = true
    end
    if count ~= #data.tasks then return nil, "Tasks must be a contiguous list." end
    return data
end

function M.empty()
    return { version = 1, nextId = 1, tasks = {} }
end

function M.copy(data)
    local copy = { version = data.version, nextId = data.nextId, tasks = {} }
    for _, task in ipairs(data.tasks) do
        table.insert(copy.tasks, {
            id = task.id, title = task.title, project = task.project,
            status = task.status, url = task.url, deadline = task.deadline,
        })
    end
    return copy
end

function M.pending(data)
    local count = 0
    for _, task in ipairs(data.tasks) do
        if task.status ~= "done" then count = count + 1 end
    end
    return count
end

function M.projects(data)
    local names, seen = {}, {}
    for _, task in ipairs(data.tasks) do
        if not seen[task.project] then
            seen[task.project] = true
            table.insert(names, task.project)
        end
    end
    table.sort(names)
    return names
end

-- Returns a NEW model. The caller adopts it only after a successful disk write.
function M.upsert(data, id, draft)
    local title = M.trim(draft.title or "")
    local project = M.trim(draft.project or "")
    local url = M.trim(draft.url or "")
    local deadline, deadlineErr
    if draft.deadlineDate ~= nil or draft.deadlineTime ~= nil then
        deadline, deadlineErr = M.normalizeDeadline(draft.deadlineDate, draft.deadlineTime)
    elseif draft.deadline ~= nil then
        if not M.validDeadline(draft.deadline) then return nil, "Invalid saved deadline; edit the task to fix it." end
        deadline = draft.deadline
    end
    if project == "" then project = "Inbox" end
    if not textField(title, 240) then return nil, "Enter a title (1–240 bytes, no control characters)." end
    if not textField(project, 80) then return nil, "Enter a project name (up to 80 bytes)." end
    if deadlineErr then return nil, deadlineErr end
    if not M.validUrl(url) then return nil, "Use a full http:// or https:// URL without spaces, or leave it blank." end
    if M.statusIndex(draft.status) == nil then return nil, "Choose a valid status." end
    local copy = M.copy(data)
    local task
    if id then
        for _, item in ipairs(copy.tasks) do
            if item.id == id then task = item; break end
        end
        if not task then return nil, "Task no longer exists. Reopen the panel." end
    else
        task = { id = copy.nextId }
        copy.nextId = copy.nextId + 1
        table.insert(copy.tasks, task)
    end
    task.title, task.project, task.status, task.url = title, project, draft.status, url
    task.deadline = deadline or task.deadline or ""
    return M.validate(copy)
end

function M.remove(data, id)
    local copy = M.copy(data)
    for i, task in ipairs(copy.tasks) do
        if task.id == id then table.remove(copy.tasks, i); return copy end
    end
    return nil, "Task no longer exists."
end

-- The panel is the only writer. Other entries load read-only or watch its count.
-- A malformed/unreadable file never becomes an empty writable model.
function M.storage(host)
    local dir, dirErr = host.pluginDataDir()
    local path = dir and (dir .. "/tasks.json") or nil
    local original, loaded = nil, false
    local S = { path = path }

    local function readCurrent()
        local raw, err = host.readFile(path)
        if raw ~= nil then return raw end
        -- v5.3 uses "cannot open file" for both missing and unreadable files.
        -- Only an accessible parent listing can prove that the file is absent.
        local files, listErr = host.listDir(dir)
        if type(files) ~= "table" then return nil, listErr or err or "Cannot list data directory." end
        for _, name in ipairs(files) do
            if name == "tasks.json" then return nil, err or "Cannot read tasks.json." end
        end
        return nil
    end

    function S.load()
        loaded = false
        if not path then return nil, dirErr or "Cannot access the plugin data directory." end
        local raw, err = readCurrent()
        if raw == nil then
            -- Only a genuinely absent file is a new list; permission failures
            -- or a directory at this path must not be treated as empty data.
            if err ~= nil then
                return nil, "Cannot read tasks: " .. tostring(err)
            end
            original, loaded = nil, true
            return M.empty()
        end
        if #raw > 4 * 1024 * 1024 then return nil, "Task file exceeds the 4 MiB safety limit." end
        local decoded, decodeErr = host.json.decode(raw)
        if decoded == nil then return nil, "Cannot decode tasks: " .. tostring(decodeErr) end
        local data, validationErr = M.validate(decoded)
        if not data then return nil, validationErr end
        original, loaded = raw, true
        return data
    end

    function S.save(data)
        if not loaded then return false, "Task file was not loaded safely; refusing to overwrite it." end
        local valid, validationErr = M.validate(data)
        if not valid then return false, validationErr end
        local raw, readErr = readCurrent()
        if raw ~= original or readErr ~= nil then
            return false, "Task file changed or became unreadable. Reopen the panel before saving."
        end
        local encoded, encodeErr = host.json.encode(data, true)
        if not encoded then return false, "Cannot encode tasks: " .. tostring(encodeErr) end
        if #encoded > 4 * 1024 * 1024 then return false, "Task file would exceed the 4 MiB safety limit." end
        -- Keep one last-known-good copy; never copy malformed input over it.
        if original ~= nil then
            local backupOk, backupErr = host.writeFile(path .. ".bak", original)
            if not backupOk then return false, "Cannot back up tasks: " .. tostring(backupErr) end
        end
        local ok, err = host.writeFile(path .. ".tmp", encoded)
        if not ok then return false, "Cannot write tasks: " .. tostring(err) end
        ok, err = host.renameFile(path .. ".tmp", path)
        if not ok then return false, "Cannot replace tasks: " .. tostring(err) end
        original = encoded
        return true
    end

    return S
end

return M
