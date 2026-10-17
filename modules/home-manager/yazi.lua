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

-- The path in the header, as a breadcrumb: a left click on one of its folders
-- changes to it, the way clicking a folder in the list enters it. The preset
-- header draws the path as a single span, so `cwd` is rebuilt as one span per
-- folder, each remembering the column range it was drawn at (`_crumbs`).
local function width(s) return ui.Line(s):width() end

-- `{ text, target }` per folder, root first: what to draw (the readable path,
-- `~` included) and where it leads (the real path, which `cd` takes).
local function crumbs_of(cwd)
  local real = tostring(cwd)
  local shown = ya.readable_path(real)
  local crumbs, tail
  if shown:sub(1, 1) == "~" then
    -- `ya.readable_path` only replaces the home prefix with `~`: what follows
    -- is the real path's own tail, byte for byte.
    tail = shown:sub(2)
    crumbs = { { text = "~", target = real:sub(1, #real - #tail) } }
  elseif shown:sub(1, 1) == "/" then
    tail = shown
    crumbs = { { text = "/", target = "/" } }
  else
    return nil -- a search or virtual filesystem URL: not a path to walk up
  end

  local target = crumbs[1].target == "/" and "" or crumbs[1].target
  for name in tail:gmatch("[^/]+") do
    target = target .. "/" .. name
    -- The root is its own separator; every other folder carries one.
    local sep = (#crumbs == 1 and crumbs[1].text == "/") and "" or "/"
    crumbs[#crumbs + 1] = { text = sep .. name, target = target }
  end
  return crumbs
end

local header_cwd = Header.cwd
Header._crumbs = {} -- on the class, as `Tabs._offsets` is: clicks come to another instance

function Header:cwd()
  -- Emptied in place, so that the instance built for the click still sees it.
  for i = #self._crumbs, 1, -1 do
    self._crumbs[i] = nil
  end

  local max = self._area.w - self._right_width
  local crumbs = max > 0 and not self._current.cwd.is_search and crumbs_of(self._current.cwd)
  if not crumbs then
    return header_cwd(self)
  end

  local flags = self:flags()
  local total = width(flags)
  for _, c in ipairs(crumbs) do
    total = total + width(c.text)
  end

  -- What does not fit is dropped from the left, as the preset truncates there:
  -- the current folder is the one that matters. `…` stands for the rest.
  local first = 1
  while first < #crumbs and total + (first > 1 and 1 or 0) > max do
    total = total - width(crumbs[first].text)
    first = first + 1
  end
  if total + (first > 1 and 1 or 0) > max then
    return header_cwd(self) -- narrower than the current folder's own name
  end

  local spans, x = {}, self._area.x
  if first > 1 then
    spans[1] = "…"
    x = x + 1
  end
  for i = first, #crumbs do
    local w = width(crumbs[i].text)
    spans[#spans + 1] = crumbs[i].text
    self._crumbs[#self._crumbs + 1] = { from = x, till = x + w, target = crumbs[i].target }
    x = x + w
  end
  spans[#spans + 1] = flags
  return ui.Line(spans):style(th.mgr.cwd)
end

-- Mouse events
function Header:click(event, up)
  if up then
    return
  elseif event.is_right then
    return ya.emit("leave", {}) -- as in the list: a right click goes up
  elseif not event.is_left then
    return
  end
  for _, c in ipairs(self._crumbs) do
    if event.x >= c.from and event.x < c.till then
      ya.emit("cd", { c.target, raw = true })
      return
    end
  end
end
