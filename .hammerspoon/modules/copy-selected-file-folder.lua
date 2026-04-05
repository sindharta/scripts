local copySelectedPathHotkey = { "ctrl", "alt", "cmd" }
local copySelectedPathKey = "P"

local function runAppleScript(script)
  local ok, result, errorMessage = hs.osascript.applescript(script)
  if not ok then
    return nil, errorMessage
  end

  return result
end

local function copySelectedFinderItemPath()
  local script = [[
    tell application "Finder"
      if not (exists Finder window 1) then
        return ""
      end if

      set selectedItems to selection
      if (count of selectedItems) is 0 then
        return ""
      end if

      set posixPaths to {}
      repeat with selectedItem in selectedItems
        set end of posixPaths to POSIX path of (selectedItem as alias)
      end repeat

      return posixPaths as string
    end tell
  ]]

  local selectedPaths, errorMessage = runAppleScript(script)
  if not selectedPaths then
    hs.notify.new({
      title = "Copy Path",
      informativeText = "Finder selection could not be read: " .. tostring(errorMessage),
    }):send()
    return
  end

  if selectedPaths == "" then
    hs.notify.new({
      title = "Copy Path",
      informativeText = "Select a file or folder in Finder first.",
    }):send()
    return
  end

  hs.pasteboard.setContents(selectedPaths)
  hs.notify.new({
    title = "Copy Path",
    informativeText = "Copied selected Finder path to the clipboard.",
  }):send()
end

hs.hotkey.bind(copySelectedPathHotkey, copySelectedPathKey, copySelectedFinderItemPath)
