-- Singleton cleanup, independent of how many monitors host a widget.
local runtime = noctalia.getenv("XDG_RUNTIME_DIR")

function update()
    noctalia.setUpdateInterval(60000)
end

function onExit(_signal, reason)
    if reason ~= "disable" and reason ~= "uninstall" and reason ~= "shutdown" then return end
    -- Do not invoke plugin files: they may already be gone on uninstall.
    -- Serialize with an in-flight toggle, and detach so cleanup survives the VM.
    if runtime and runtime ~= "" then
        noctalia.runAsync({ "/usr/bin/flock", "--timeout", "10", runtime .. "/noctalia-sleep-guard.lock",
            "/usr/bin/systemctl", "--user", "stop", "noctalia-sleep-guard.service" })
    end
end
