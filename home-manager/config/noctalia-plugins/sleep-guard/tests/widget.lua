-- nvim --headless -u NONE -l home-manager/config/noctalia-plugins/sleep-guard/tests/widget.lua
local root = "home-manager/config/noctalia-plugins/sleep-guard/"
local captured, pending, args, notices = {}, nil, nil, {}
local accepted = true
local host = {
    pluginDir = function() return "/plugin path" end,
    getenv = function() return "/run/user/1000" end,
    setUpdateInterval = function(n) captured.interval = n end,
    runAsync = function(argv, cb) args, pending = argv, cb; return accepted end,
    notify = function(title, body) table.insert(notices, {title, body}) end,
    json = { decode = function(s) local ok,v=pcall(vim.json.decode,s);if ok then return v end end },
}
local bar = {}
for _, field in ipairs({"Text", "Tooltip", "Glyph", "Color", "GlyphColor"}) do
    bar["set" .. field] = function(value) captured[field] = value end
end
local env = setmetatable({noctalia=host,barWidget=bar},{__index=_G})
setfenv(assert(loadfile(root.."widget.luau")),env)()
assert(captured.Text=="Guard !")
env.update()
assert(captured.interval==5000)
assert(vim.deep_equal(args,{"python3","/plugin path/guard.py","status"}))
pending({stdout='{"state":"off"}',exitCode=0})
assert(captured.Text=="Guard OFF")
env.onClick();assert(captured.Text=="Guard …");assert(args[3]=="toggle")
local callback=pending
env.onClick();assert(pending==callback) -- suppress overlapping work in this VM
pending({stdout='{"state":"on","pid":123}',exitCode=0})
assert(captured.Text=="Guard ON" and captured.Color=="primary")
assert(captured.Tooltip:find("Display blanking"))
env.update();assert(captured.Text=="Guard ON") -- polls do not flash busy labels
pending({stdout='{"state":"error","error":"No permission"}',exitCode=1})
assert(captured.Text=="Guard !" and captured.Tooltip:find("No permission"))
env.onIpc("off");pending({stdout='{"state":"off"}',exitCode=0});assert(captured.Text=="Guard OFF")
env.onIpc("invalid");assert(args[3]=="off")
accepted=false;env.onClick();assert(captured.Text=="Guard !")
accepted=true;env.onClick();pending({stdout="garbage",exitCode=1});assert(captured.Text=="Guard !")
print("PASS: widget status, toggles, busy/error handling, argv and no poll flicker")
local lifecycle=setmetatable({noctalia=host},{__index=_G})
setfenv(assert(loadfile(root.."lifecycle.luau")),lifecycle)()
args=nil;lifecycle.onExit(0,"reload");assert(args==nil)
for _,reason in ipairs({"disable","uninstall","shutdown"}) do
    lifecycle.onExit(0,reason)
    assert(args[1]=="/usr/bin/flock" and args[4]=="/run/user/1000/noctalia-sleep-guard.lock")
    assert(args[5]=="/usr/bin/systemctl" and args[7]=="stop" and args[8]=="noctalia-sleep-guard.service")
    assert(pending==nil) -- detached cleanup, no helper script or callback
end
print("PASS: singleton cleanup survives uninstall, preserves reload, serializes with toggles")
