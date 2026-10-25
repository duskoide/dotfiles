-- Real inhibitor state, not a cosmetic/persisted ON flag.
local busy = false
local changing = false
local state = "unknown"
local lastError = "Checking systemd inhibitor…"
local helper = noctalia.pluginDir() .. "/guard.py"

local function render()
    local on = state == "on"
    barWidget.setGlyph(on and "shield-lock" or "shield")
    barWidget.setText(changing and "Guard …" or (on and "Guard ON" or (state == "off" and "Guard OFF" or "Guard !")))
    barWidget.setColor(on and "primary" or (state == "off" and "on_surface_variant" or "error"))
    barWidget.setGlyphColor(on and "primary" or (state == "off" and "on_surface_variant" or "error"))
    local message = on and "Sleep blocked (including lid close). Display blanking and locking still work. Click to turn off."
        or (state == "off" and "Sleep Guard off. Click to block normal sleep and lid-close suspend."
        or lastError)
    barWidget.setTooltip(message .. string.char(10) .. "Forced/root sleep can bypass this. Recovery: systemctl --user stop noctalia-sleep-guard.service")
end

local function run(action)
    if busy then return end
    busy = true
    changing = action ~= "status"
    if changing then render() end
    local accepted = noctalia.runAsync({ "python3", helper, action }, function(result)
        busy, changing = false, false
        local decoded = noctalia.json.decode(result.stdout or "")
        if type(decoded) == "table" and (decoded.state == "on" or decoded.state == "off") and result.exitCode == 0 and not result.timedOut then
            state, lastError = decoded.state, ""
        else
            state = "error"
            lastError = (type(decoded) == "table" and type(decoded.error) == "string" and decoded.error) or "Cannot check Sleep Guard. Verify python3 and systemd are available."
            if action ~= "status" then noctalia.notify("Sleep Guard", lastError) end
        end
        render()
    end)
    if not accepted then
        busy, changing, state, lastError = false, false, "error", "Could not launch the Sleep Guard helper."
        render()
    end
end

function update()
    noctalia.setUpdateInterval(5000)
    run("status")
end

function onClick()
    run("toggle")
end

function onIpc(event)
    if event == "on" or event == "off" or event == "toggle" or event == "status" then run(event) end
end

render()
