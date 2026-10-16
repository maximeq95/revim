-- Mouse, like a VSCode explorer: a left click opens a file or enters a folder,
-- a right click anywhere goes up (the one-column layout has no parent column).
function Entity:click(event, up)
  if up or not event.is_left then
    return
  end
  ya.emit("reveal", { self._file.url })
  ya.emit(self._file.cha.is_dir and "enter" or "open", {})
end

local current_click = Current.click
function Current:click(event, up)
  if not event.is_right then
    return current_click(self, event, up)
  end
  if not up then
    ya.emit("leave", {})
  end
end
