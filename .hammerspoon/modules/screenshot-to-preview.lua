-- ScreenShot to Clipboard
hs.hotkey.bind({"cmd", "alt"}, "V", function()
    hs.eventtap.keyStroke({"cmd", "shift", "ctrl"}, "4")

    local prevPasteChangeCount = hs.pasteboard.changeCount()
    local startTime = hs.timer.secondsSinceEpoch()

    hs.timer.doEvery(0.2, function(timer)
        local now = hs.timer.secondsSinceEpoch()
        -- give user time to select area
        if now - startTime < 1 then
            return
        end

        if hs.pasteboard.changeCount() ~= prevPasteChangeCount then
            local preview = hs.appfinder.appFromName("Preview")
            if preview then
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

