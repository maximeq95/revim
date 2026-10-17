--- @sync entry
-- `<Enter>`, like a left click: a folder is entered, a file is opened. yazi has
-- `enter` and `open`, but no command doing one or the other, and `open` on a
-- folder would hand it to the `edit` opener — the editor next door.
return {
  entry = function()
    local hovered = cx.active.current.hovered
    if hovered then
      -- Not `--hovered`: a file opens the selection, as plain `open` does.
      ya.emit(hovered.cha.is_dir and "enter" or "open", {})
    end
  end,
}
