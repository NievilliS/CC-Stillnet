--base.lua

--Check version
local vurl = "https://raw.githubusercontent.com/NievilliS/CC-Stillnet/master/Stillnet/version"
local httpinst = http.get(vurl)
if httpinst then
  local ver = httpinst.readAll()
  httpinst.close()
end

local file = fs.open("./Stillnet/version","r")
local tver = file.readLine()
file.close()

if ver then
  if tonumber(ver) > tonumber(tver) then
    print"New Stillnet version available!\nRun Stillnet/update.lua to update"
    sleep(3) --Sleep to make it annoying to wait
  end
end

--Load Libraries
shell.run"Stillnet/config.lua"
shell.run"Stillnet/ench.lua"

--Global init
_G.stillnet = {}
stillnet._version = tver
local dt = {}
stillnet.broadcast_id = rednet.CHANNEL_BROADCAST
stillnet.repeat_id = rednet.CHANNEL_REPEAT
stillnet.default_id = stillnet.broadcast_id
stillnet.broadcast_enable = true

--New stillnet instance
function stillnet:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

--Returns surrounding modems and their wrap envs
function stillnet:scan()
  local rt = {}
  for _,name in pairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      rt[name] = self:new{name=name,modem=peripheral.wrap(name)}
      rt[name]:setDefaultID(os.getComputerID())
    end
  end
  return rt
end

--Assign Peripheral do object
function stillnet:assign(modem,name)
  modem = modem or self.modem
  name = name or self.name
  self.modem = modem
  self.name = name
end

--Default id
function stillnet:setDefaultID(id)
  self.default_id = id or stillnet.default_id
end

--Broadcast enable/disable
function stillnet:allowBroadcast(state)
  state = state or self.broadcast_enable
end

--Opens channel to ID
function stillnet:open(id)
  id = id or self.default_id
  if self.modem.isOpen(id) then
    return false
  end
  self.modem.open(id)
  return true
end

--Closes channel ID
function stillnet:close(id)
  id = id or self.default_id
  if self.modem.isOpen(id) then
    self.modem.close(id)
    return true
  end
  return false
end

--Transmit raw package
function stillnet:transmit(id, dest,msg)
  dest = dest or self.broadcast_id
  id = id or self.default_id
  self.modem.transmit(dest, id, msg)
end

--Broadcast raw package (you will have to open broadcast channel yourself)
function stillnet:broadcast(msg, id)
  id = id or self.broadcast_id
  self:transmit(id, nil, msg)
end

--Wait for raw package
function stillnet:receive(sid, id, timeout)
  local timer
  if timeout then
    timer = os.startTimer(timeout)
  end
  
  while true do
    local e = {os.pullEvent()}
    
    if e[1] == "timer" then
      if e[2] == timer then
        return nil
      end
    end
    
    if e[1] == "modem_message" and e[2] == self.name then
      if not sid or e[3] == sid then
        if (not id or e[4] == id) and e[4] ~= self.broadcast_id then
          return e[5], e[4], e[2], e[3], e[6]
        end
      end
      if self.broadcast_enable and e[3] == self.broadcast_id then
        if e[4] == self.broadcast_id then
          return e[5], e[4], e[2], e[3], e[6]
        end
      end
    end
  end
end
