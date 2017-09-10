fs.setCWD("/home/")

local ox = os.exit
os.exit = function() error("Nope") end
if not riko4 then riko4 = {} end
riko4.exit = ox

local config = dofile("/shellcfg.lua")
table.insert(config.path, ".")

local w, h = gpu.width, gpu.height

local write = write

local fl = math.floor

local function round(n, p)
  return math.floor(n / p) * p
end

local function split(str)
  local tab = {}
  for word in str:gmatch("%S+") do
    tab[#tab + 1] = word
  end
  return tab
end

local oldPrint = print

local pureHistory = {}
local pureHistoryPoint = 1

shell = {}
local shell = shell
shell.config = config

local lineHistory = {{{"rikoOS 1.0"}, {13}}}

local function insLine(t, c)
  table.insert(lineHistory[#lineHistory][1], t)
  table.insert(lineHistory[#lineHistory][2], c)
end

local historyPoint = 2
local lineOffset = 0
local c = 4
function shell.pushOutput(msg, ...)
  msg = tostring(msg)
  local ar = {...}
  for k,v in ipairs(ar) do
    msg = msg .. "  " .. tostring(v)
  end
  insLine(msg, 16)
  lineHistory[#lineHistory + 1] = {{}, {}}
  historyPoint = #lineHistory + 1
  if historyPoint - lineOffset >= h / 8 - 1 then
    lineOffset = fl(historyPoint - (h / 8 - 2))
  end
  shell.redraw(true)
end

function shell.writeOutputC(msg, c, rd)
  msg = tostring(msg)

  while msg:find("\n") do
    local pos = msg:find("\n")
    local fsub = msg:sub(1, pos - 1)
    insLine(fsub, c or 16)
    msg = msg:sub(pos + 1)
    lineHistory[#lineHistory + 1] = {{}, {}}
    historyPoint = #lineHistory + 1
    if historyPoint - lineOffset >= h / 8 - 1 then
      lineOffset = fl(historyPoint - (h / 8 - 2))
    end
  end
  insLine(msg, c or 16)
  _ = rd and shell.redraw(true) or 1
end


function shell.tabulate(...)
  local tAll = {...}

  local w = (gpu.width - 4) / 7
  local nMaxLen = w / 7
  for n, t in ipairs(tAll) do
    if type(t) == "table" then
      for n, sItem in pairs(t) do
        nMaxLen = math.max(string.len( sItem ) + 1, nMaxLen)
      end
    end
  end
  local nCols = math.floor(w / nMaxLen)
  local nLines = 0

  local cx = 0

  local function newLine()
    shell.writeOutputC("\n", nil, false)
    cx = 0
    nLines = nLines + 1
  end

  local cc = nil
  local function drawCols(_t)
    local nCol = 1
    for n, s in ipairs(_t) do
      if nCol > nCols then
        nCol = 1
        newLine()
      end

      shell.writeOutputC((" "):rep(((nCol - 1) * nMaxLen) - cx) .. s, cc, false)
      cx = ((nCol - 1) * nMaxLen) + #s

      nCol = nCol + 1
    end
  end
  for n, t in ipairs(tAll) do
    if type(t) == "table" then
      if #t > 0 then
        drawCols(t)
        if n < #tAll then
          shell.writeOutputC("\n", nil, false)
        end
      end
    elseif type(t) == "number" then
      cc = t
    end
  end
end

local prefix = "> "
local str = ""

local lastP = 0

local lastf = 0
local fps = 60

local mouseX, mouseY = -5, -5

function shell.redraw(swap)
  swap = (swap == nil) and swap or true -- explicitness is necessary

  gpu.clear()

  local ctime = os.clock()
  local delta = ctime - lastf
  lastf = ctime
  fps = fps + (1 / delta - fps)*0.01

  for i = math.max(lineOffset, 1), #lineHistory do
    local cpos = 2
	if lineHistory[i] then
      for j = 1, #lineHistory[i][1] do
        write(tostring(lineHistory[i][1][j]), cpos, (i - 1 - lineOffset)*8 + 2, lineHistory[i][2][j])
        cpos = cpos + #tostring(lineHistory[i][1][j])*7
      end
	end
  end

  gpu.drawRectangle(0, h - 10, w, 10, 6)
  write("FPS: " .. tostring(round(fps, 0.01)), 2, h - 9)

  gpu.drawRectangle(mouseX, mouseY, 2, 1, 7)
  gpu.drawRectangle(mouseX, mouseY, 1, 2, 7)

  if swap then
    gpu.swap()
  end
end

local lastRun = ""
function shell.getRunningProgram()
  return lastRun:match("(.+)%.lua")
end

function shell.clear()
  lineHistory = {}

  historyPoint = 1
  lineOffset = 0
end

local function getprefix()
  local wd = fs.getCWD()
  wd = wd:gsub("\\", "/")

  if wd:sub(#wd) == "/" then
    wd = wd:sub(1, #wd - 1)
  end

  if wd:sub(1, 1) ~= "/" then
    wd = "/" .. wd
  end

  return wd
end

local function update()
  lineHistory[historyPoint] = {
    {getprefix(), prefix, str,
    (math.floor((os.clock() * 2 - lastP) % 2) == 0 and "_" or "")},
    {13, 10, 16, 16}
  }

  shell.redraw()
end

local fullscreen = false
local function processEvent(e, ...)
  local args = {...}
  local p1, p2 = args[1], args[2]
  if e == "char" then
    str = str .. p1
    lastP = os.clock() * 2
  elseif e == "mouseMoved" then
    mouseX, mouseY = p1, p2
  elseif e == "key" then
    if p1 == "f11" then
      fullscreen = not fullscreen
      gpu.setFullscreen(fullscreen)
    elseif p1 == "backspace" then
      str = str:sub(1, #str - 1)
      lastP = os.clock() * 2
    elseif p1 == "up" then
      pureHistoryPoint = pureHistoryPoint - 1
      if pureHistoryPoint < 1 then
        pureHistoryPoint = 1
      else
        str = pureHistory[pureHistoryPoint]
      end
    elseif p1 == "down" then
      pureHistoryPoint = pureHistoryPoint + 1
      if pureHistoryPoint > #pureHistory then
        pureHistoryPoint = #pureHistory + 1
        str = ""
      else
        str = pureHistory[pureHistoryPoint]
      end
    elseif p1 == "return" then
      if not str:match("%S+") then
        lineHistory[historyPoint][1][4] = "" -- Remove the "_" if it is there
        historyPoint = historyPoint + 1
        str = ""
      else
        lineHistory[historyPoint][1][4] = "" -- Remove the "_" if it is there
        pureHistoryPoint = #pureHistory + 2
        pureHistory[pureHistoryPoint - 1] = str

        local startPoint = historyPoint

        lineHistory[#lineHistory + 1] = {{}, {}}
        historyPoint = historyPoint + 1
        local cfunc, oer
        lastRun = str

        local got = true
        for pref = 1, #config.path do
          local s, er = pcall(function() cfunc, oer = loadfile(config.path[pref] .. "/" .. str:match("%S+")..".lua") end)
          if not s then
            c = 7
            if er then
              er = er:sub(er:find("%:") + 1)
              er = er:sub(er:find("%:") + 2)
              shell.pushOutput("Error: " .. tostring(er))
            else
              shell.pushOutput("Error: Unknown error")
            end

            got = false
            break
          else
            if cfunc then
              local cc = coroutine.create(cfunc)
              local splitStr = split(str)
              table.remove(splitStr, 1)
              local ev = splitStr or {}
              local upfunc = table.unpack and table.unpack or unpack
              while coroutine.status(cc) ~= "dead" do
                local su, eru = coroutine.resume(cc, upfunc(ev))
                if not su then
                  print(eru)
                end
                ev = {coroutine.yield()}
              end
              --cc = nil
              collectgarbage("collect")

              print = oldPrint

              historyPoint = #lineHistory + 1

              got = false
              break
            elseif oer then
              print("Wow " .. oer)
            end
          end
        end

        if got then
          c = 7
          shell.writeOutputC("Unknown program `" .. str:match("%S+") .. "'\n", 8)
          historyPoint = #lineHistory + 1
        end

        str = ""
      end

      if historyPoint - lineOffset >= h / 8 - 1 then
        lineOffset = fl(historyPoint - (h / 8 - 2))
      end
    end
  end
end

local eventQueue = {}
local last = os.clock()
while true do
  while os.clock() - last < (1 / 60) do
    while true do
      local e, p1, p2, p3, p4 = coroutine.yield()
      if not e then break end
      table.insert(eventQueue, {e, p1, p2, p3, p4})
    end

    while #eventQueue > 0 do
      processEvent(unpack(eventQueue[1]))
      table.remove(eventQueue, 1)
    end
  end
  last = os.clock()
  update()
end
