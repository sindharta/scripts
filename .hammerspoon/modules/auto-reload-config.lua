------------------------------------------------------------
-- Auto Reload
------------------------------------------------------------

local watchers = {}

function reloadConfig(files)
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            hs.reload()
            return
        end
    end
end

local function addWatcher(path)
    local watcher = hs.pathwatcher.new(path, reloadConfig)
    watcher:start()
    table.insert(watchers, watcher)
    print("Watching: " .. path)
end

local home = os.getenv("HOME")
local hammerspoonDir = home .. "/.hammerspoon"

-- Watch the main Hammerspoon directory
addWatcher(hammerspoonDir)

-- Watch symlink targets under ~/.hammerspoon/plugins
local pluginDir = os.getenv("HOME") .. "/.hammerspoon/plugins"

for file in hs.fs.dir(pluginDir) do
    if file ~= "." and file ~= ".." then
        local fullPath = pluginDir .. "/" .. file
        local target = hs.fs.pathToAbsolute(fullPath)

        if target and hs.fs.attributes(target, "mode") == "directory" then
            print("Watching:", target)

            local watcher = hs.pathwatcher.new(target, reloadConfig)
            watcher:start()

            table.insert(watchers, watcher)
        end
    end
end

hs.notify.new({
    title = "Hammerspoon",
    informativeText = "Config loaded"
}):send()

