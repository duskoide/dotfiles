-- Run from the repository root: nvim --headless -u NONE -l <this-file>
local root = os.getenv("PROJECT_TASKS_TEST_ROOT") or "home-manager/config/noctalia-plugins/project-tasks/"
local model = assert(loadfile(root .. "model.luau"))()
local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err), 0) end
    passed = passed + 1
    print("ok " .. passed .. " - " .. name)
end
local function equal(a, b) assert(vim.deep_equal(a, b), vim.inspect(a) .. " ~= " .. vim.inspect(b)) end
local function draft(status, url)
    return { title = "Write proposal", project = "Website", status = status or "todo", url = url or "" }
end
local PATH = "/mock/tasks.json"
local function mock()
    local files, calls, watches = {}, {}, {}
    local failure = {}
    local host = {
        pluginDataDir = function() return "/mock" end,
        fileExists = function(path) return files[path] ~= nil end,
        readFile = function(path)
            if failure.read or not files[path] then return nil, "cannot open file" end
            return files[path]
        end,
        listDir = function()
            if failure.list then return nil, "cannot list directory" end
            local names = {}
            for path in pairs(files) do table.insert(names, path:match("[^/]+$")) end
            return names
        end,
        writeFile = function(path, contents)
            if failure.write and path:find(failure.write, 1, true) then return false, "disk full" end
            files[path] = contents
            return true
        end,
        renameFile = function(from, to)
            if failure.rename then return false, "rename failed" end
            files[to], files[from] = files[from], nil
            return true
        end,
        json = {
            decode = function(raw)
                local ok, value = pcall(vim.json.decode, raw)
                if ok then return value end
                return nil, tostring(value)
            end,
            encode = function(value)
                if failure.encode then return nil, "encode failed" end
                return vim.json.encode(value)
            end,
        },
        state = {
            set = function(key, value) calls[key] = value; if watches[key] then watches[key](value) end end,
            watch = function(key, fn) watches[key] = fn end,
        },
        runAsync = function(argv, cb)
            calls.argv = argv
            if failure.launch then return false end
            cb({exitCode=0})
            return true
        end,
        notify = function(...) calls.notification = {...} end,
        setUpdateInterval = function(n) calls.interval = n end,
    }
    return host, files, failure, calls
end

test("statuses use zero-based native select indices", function()
    for i, status in ipairs(model.statusIds) do equal(model.statusIndex(status), i - 1) end
    assert(model.statusIndex("invalid") == nil)
end)
test("URL allowlist rejects executable schemes and controls", function()
    for _, url in ipairs({"javascript:alert(1)", "file:///tmp/x", "https://", "--help", "https://a b", "https://x" .. string.char(10)}) do
        assert(not model.validUrl(url), url)
    end
    for _, url in ipairs({"", "https://docs.google.com/document/d/abc", "HTTP://example.com/?a=1&b=2", "https://example.com/?q=$(touch-test)"}) do assert(model.validUrl(url)) end
end)
test("upsert is immutable and normalizes fields", function()
    local a = model.empty()
    local b = assert(model.upsert(a, nil, {title="  New task  ",project=" ",status="todo",url="  https://example.com  "}))
    equal(#a.tasks, 0); equal(b.nextId, 2)
    equal(b.tasks[1], {id=1,title="New task",project="Inbox",status="todo",url="https://example.com",deadline=""})
    local c = assert(model.upsert(b, 1, draft("done")))
    equal(b.tasks[1].status,"todo"); equal(model.pending(c),0)
    equal(#assert(model.remove(c,1)).tasks,0)
end)
test("deadline validates real local dates, normalizes and survives edits", function()
    local d = draft()
    d.deadlineDate, d.deadlineTime = "2027-02-28", "09:05"
    local a = assert(model.upsert(model.empty(), nil, d))
    equal(a.tasks[1].deadline, "2027-02-28T09:05")
    equal({model.deadlineParts(a.tasks[1].deadline)}, {"2027-02-28", "09:05"})
    local b = assert(model.upsert(a, 1, draft("doing")))
    equal(b.tasks[1].deadline, "2027-02-28T09:05")
    d.deadlineDate, d.deadlineTime = "", ""
    equal(assert(model.upsert(a, 1, d)).tasks[1].deadline, "")
end)
test("leap-day rules and legacy tasks without deadlines", function()
    for _, value in ipairs({{"2028-02-29", true}, {"2000-02-29", true}, {"2100-02-29", false}}) do
        local d = draft(); d.deadlineDate, d.deadlineTime = value[1], "12:00"
        equal(not not model.upsert(model.empty(), nil, d), value[2])
    end
    local legacy = assert(model.upsert(model.empty(), nil, draft()))
    legacy.tasks[1].deadline = nil
    assert(model.validate(legacy))
    equal(assert(model.upsert(legacy, 1, draft("done"))).tasks[1].deadline, "")
end)
test("invalid or partial deadlines are rejected without changing existing tasks", function()
    for _, value in ipairs({{"2027-02-29","12:00"},{"2027-13-01","12:00"},{"2027-01-01","24:00"},
        {"2027-01-01","12:60"},{"2027-01-01","12"},{"01/02/2027","12:00"},{"2027-01-01",""},{"","12:00"}}) do
        local d = draft(); d.deadlineDate, d.deadlineTime = value[1], value[2]
        assert(not model.upsert(model.empty(), nil, d), table.concat(value, " "))
    end
    local d = assert(model.upsert(model.empty(), nil, draft()))
    d.tasks[1].deadline = "not-a-date"; assert(not model.validate(d))
    d.tasks[1].deadline = 123; assert(not model.validate(d))
end)
test("invalid titles, statuses, URLs and missing IDs reject", function()
    local d = draft(); d.title = " "
    assert(not model.upsert(model.empty(),nil,d))
    d = draft("invalid"); assert(not model.upsert(model.empty(),nil,d))
    assert(not model.upsert(model.empty(),nil,draft("todo","javascript:x")))
    assert(not model.upsert(model.empty(),5,draft()))
end)
test("projects deduplicate and sort; blocked is unfinished", function()
    local d = assert(model.upsert(model.empty(),nil,draft("blocked")))
    d = assert(model.upsert(d,nil,draft("done")))
    local x=draft();x.project="Alpha";d=assert(model.upsert(d,nil,x))
    equal(model.projects(d),{"Alpha","Website"}); equal(model.pending(d),2)
end)
test("schema rejects unknown version, invalid IDs, holes and duplicate IDs", function()
    assert(not model.validate({version=2,nextId=1,tasks={}}))
    local d=assert(model.upsert(model.empty(),nil,draft()))
    d.tasks[2]=vim.deepcopy(d.tasks[1]);assert(not model.validate(d))
    d.tasks[1]=nil;assert(not model.validate(d))
end)
test("first-run native-style missing-file error initializes safely", function()
    local h,f = mock();local s=model.storage(h)
    assert(not s.save(model.empty()))
    local d=assert(s.load());equal(#d.tasks,0)
    assert(s.save(assert(model.upsert(d,nil,draft()))));assert(f[PATH])
end)
test("unreadable existing file and inaccessible directory do not initialize", function()
    local h,f,fail=mock();f[PATH]="important";fail.read=true
    local s=model.storage(h);assert(not s.load());assert(not s.save(model.empty()));equal(f[PATH],"important")
    f[PATH]=nil;fail.list=true;assert(not s.load())
end)
test("corrupt and future-version files refuse overwrite", function()
    for _, raw in ipairs({"broken",'{"version":2,"nextId":1,"tasks":[]}'}) do
        local h,f=mock();f[PATH]=raw;local s=model.storage(h)
        assert(not s.load());assert(not s.save(model.empty()));equal(f[PATH],raw)
    end
end)
test("save backup and empty-list reload", function()
    local h,f=mock();local s=model.storage(h);local d=assert(s.load())
    d=assert(model.upsert(d,nil,draft()));assert(s.save(d));local first=f[PATH]
    local second=assert(model.upsert(d,1,draft("done")));assert(s.save(second))
    equal(f[PATH..".bak"],first);equal(model.pending(assert(s.load())),0)
    assert(s.save(assert(model.remove(second,1))));equal(#assert(s.load()).tasks,0)
end)
test("external change leaves main file and backup intact", function()
    local h,f=mock();local s=model.storage(h);assert(s.load());assert(s.save(model.empty()))
    f[PATH..".bak"]="backup";f[PATH]="external"
    assert(not s.save(model.empty()));equal(f[PATH],"external");equal(f[PATH..".bak"],"backup")
end)
test("write, backup, encode and rename failures keep committed file", function()
    for _, kind in ipairs({"write", "backup", "encode", "rename"}) do
        local h,f,fail=mock();local s=model.storage(h);assert(s.load());assert(s.save(model.empty()));local original=f[PATH]
        if kind=="write" then fail.write=".tmp" elseif kind=="backup" then fail.write=".bak" else fail[kind]=true end
        assert(not s.save(assert(model.upsert(model.empty(),nil,draft()))));equal(f[PATH],original)
    end
end)

test("oversized serialization is refused before writing", function()
    local h,f = mock(); local s=model.storage(h); assert(s.load())
    h.json.encode = function() return string.rep("x", 4 * 1024 * 1024 + 1) end
    assert(not s.save(model.empty())); assert(not f[PATH])
end)

local function panelHost()
    local h,files,fail,calls=mock()
    local tree,closed
    local ui=setmetatable({}, {__index=function(_,kind)
        return function(props,children) return {kind=kind,props=props or {},children=children or {}} end
    end})
    local env=setmetatable({noctalia=h,ui=ui,panel={render=function(t)tree=t end,close=function()closed=true end},require=function()return model end},{__index=_G})
    assert(setfenv(assert(loadfile(root.."panel.luau")),env))()
    local function node(key,t)
        t=t or tree
        if t.props.key==key then return t end
        for _,c in ipairs(t.children) do local n=node(key,c);if n then return n end end
    end
    local function findText(target,t)
        t=t or tree
        if t.props.text==target then return t end
        for _,c in ipairs(t.children) do local n=findText(target,c);if n then return n end end
    end
    local function act(key,callback,value)
        local n=assert(node(key),"Missing node "..key)
        assert(n.props[callback],"Missing callback "..callback)(value)
    end
    return {env=env,host=h,files=files,fail=fail,calls=calls,node=node,act=act,findText=findText,closed=function()return closed end}
end

test("panel add, status, edit, project filter, safe URL and delete callbacks",function()
    local p=panelHost();p.env.onOpen();equal(p.calls.pending,0)
    p.act("new-task","onClick")
    p.act("editor-1-title","onChange","Design homepage")
    p.act("editor-1-project","onChange","Website")
    p.act("editor-1-url","onChange","https://example.com/?x=1&y=$(safe)")
    p.act("editor-1-deadline-date","onChange","2027-12-31")
    p.act("editor-1-deadline-time","onChange","18:45")
    p.act("editor-1-status","onChange","1")
    p.act("save-task","onClick")
    equal(p.calls.pending,1);equal(p.node("task-1-status").props.selectedIndex,1)
    equal(vim.json.decode(p.files[PATH]).tasks[1].deadline,"2027-12-31T18:45")
    assert(p.findText("Due 2027-12-31 18:45"))
    p.act("task-1-status","onChange","3");equal(p.calls.pending,0)
    equal(vim.json.decode(p.files[PATH]).tasks[1].deadline,"2027-12-31T18:45")
    p.act("project-filter","onChange","1");equal(p.node("project-filter").props.selectedIndex,1)
    p.act("task-1-edit","onClick")
    equal(p.node("editor-2-deadline-date").props.value,"2027-12-31")
    equal(p.node("editor-2-deadline-time").props.value,"18:45")
    p.act("editor-2-title","onChange","Updated");p.act("save-task","onClick")
    equal(vim.json.decode(p.files[PATH]).tasks[1].title,"Updated")
    p.act("task-1-link","onClick");equal(p.calls.argv,{"xdg-open","https://example.com/?x=1&y=$(safe)"});assert(p.closed())
    p.env.onOpen();assert(p.node("task-1-edit"))
    local legacy=vim.json.decode(p.files[PATH]);legacy.tasks[1].deadline=nil
    p.files[PATH]=vim.json.encode(legacy);p.env.onOpen();assert(p.node("task-1-edit"))
    p.act("task-1-delete","onClick");equal(#vim.json.decode(p.files[PATH]).tasks,1)
    p.act("confirm-delete","onClick");equal(#vim.json.decode(p.files[PATH]).tasks,0)
end)
test("panel validation keeps draft; cancel creates no tasks",function()
    local p=panelHost();p.env.onOpen();p.act("new-task","onClick");p.act("save-task","onClick")
    assert(p.node("editor-1-title"));assert(not p.files[PATH])
    p.act("editor-1-title","onChange","Keep this draft")
    p.act("editor-1-deadline-date","onChange","2027-02-29");p.act("save-task","onClick")
    assert(p.node("editor-1-deadline-date"));assert(not p.files[PATH])
    p.act("editor-1-title","onChange","")
    -- A complete but impossible date must surface the validation error, keep the draft.
    p.act("editor-1-title","onChange","A draft")
    p.act("editor-1-deadline-date","onChange","2027-02-29");p.act("editor-1-deadline-time","onChange","10:00")
    p.act("save-task","onClick");assert(not p.files[PATH]);assert(p.findText("Use a real date as YYYY-MM-DD and a local time as HH:MM (24-hour)."))
    p.act("editor-1-deadline-date","onChange","");p.act("editor-1-deadline-time","onChange","")
    p.env.onClose();p.env.onOpen()
    assert(p.node("editor-1-title"));p.act("cancel-edit","onClick");assert(not p.files[PATH])
end)
test("panel disk failure leaves prior data/count and draft intact",function()
    local p=panelHost();p.env.onOpen();p.act("new-task","onClick");p.act("editor-1-title","onChange","New")
    p.fail.rename=true;p.act("save-task","onClick")
    assert(p.node("editor-1-title"));equal(p.calls.pending,0);assert(not p.files[PATH])
end)
test("bar initializes without panel and reacts to pending state",function()
    local h,f,_,calls=mock();f[PATH]=vim.json.encode(assert(model.upsert(model.empty(),nil,draft())))
    local env=setmetatable({noctalia=h,require=function()return model end,barWidget={
        setGlyph=function(g)calls.glyph=g end,setText=function(s)calls.text=s end,setTooltip=function(s)calls.tooltip=s end,
    }},{__index=_G})
    setfenv(assert(loadfile(root.."widget.luau")),env)();equal(calls.text,"Tasks 1")
    h.state.set("pending",0);equal(calls.text,"Tasks 0");env.update();equal(calls.interval,60000)
end)
print("PASS: " .. passed .. " tests")
