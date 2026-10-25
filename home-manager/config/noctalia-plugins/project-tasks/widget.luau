local model = require("./model.luau")
local storage = model.storage(noctalia)

local function display(count, err)
    barWidget.setGlyph("list-check")
    barWidget.setText(count and ("Tasks " .. count) or "Tasks !")
    barWidget.setTooltip(err or (count .. " unfinished tasks · click to open"))
end

-- Startup count must not depend on the panel ever having been opened.
local data, err = storage.load()
if data then display(model.pending(data)) else display(nil, err) end
noctalia.state.watch("pending", function(count) display(count) end)

function update()
    -- No polling or disk writes: panel commits publish the count immediately.
    noctalia.setUpdateInterval(60000)
end
