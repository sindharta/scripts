-- Core modules (keep as-is)
require("modules.auto-reload-config")
require("modules.copy-selected-file-folder")
require("modules.screenshot-to-preview")


------------------------------------------------------------
-- Plugin loader (auto-load ~/.hammerspoon/plugins/*)
------------------------------------------------------------
local function loadLuaFiles(dir)
    local realDir = hs.fs.pathToAbsolute(dir)

    if not realDir then
        print("Invalid plugin dir:", dir)
        return
    end

    print("Loading plugins from:", realDir)

    for file in hs.fs.dir(realDir) do
        if file and file:sub(-4) == ".lua" then
            local fullPath = realDir .. "/" .. file

            print("Loading file:", fullPath)

            local ok, err = pcall(dofile, fullPath)

            if not ok then
                print("ERROR in", fullPath, err)
            end
        end
    end
end

loadLuaFiles(os.getenv("HOME") .. "/.hammerspoon/plugins/tcg")