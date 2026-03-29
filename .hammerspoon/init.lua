-- Call Screenshot To Preview
hs.hotkey.bind({"cmd", "alt"}, "P", function()
    hs.eventtap.keyStroke({"cmd", "shift", "ctrl"}, "4")

    local before = hs.pasteboard.changeCount()
    local startTime = hs.timer.secondsSinceEpoch()

    hs.timer.doEvery(0.2, function(timer)
        local now = hs.timer.secondsSinceEpoch()
        -- give user time to select area
        if now - startTime < 1 then
            return
        end

        if hs.pasteboard.changeCount() ~= before then
            local preview = hs.appfinder.appFromName("Preview")
            if preview then
                hs.alert.show("Opening Screenshot timeout")
                preview:selectMenuItem({"File", "New from Clipboard"})
            end
            timer:stop()            
            return
        end

        if now - startTime > 10 then
            timer:stop()
            hs.alert.show("Screenshot timeout")
        end
    end)
    
end)

hs.hotkey.bind({"cmd", "alt"}, "Q", function()
    hs.osascript.applescript([[
        tell application "Shortcuts Events"
            run shortcut "Screenshot To Preview"
        end tell
    ]])
end)

-- Auto-reload

function reloadConfig(files)
    local doReload = false
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
end

myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

hs.alert.show("Config loaded")