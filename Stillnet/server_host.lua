--#### Server Hosting
_G.gstream = {}

--Load Configuration
local tConf = config.load(".server.conf",true)
tConf.sessionFormat = tConf.sessionFormat or "char"
tConf.sID = (tConf.sID or os.getComputerID())+0
tConf.reqTimeout = (tConf.reqTimeout or 1)+0
tConf.timeout = (tConf.timeout or 10)+0
tConf.deleteTime = (tConf.deleteTime or 5)+0
tConf.doEnch = (tConf.doEnch or 1)+0

local kConf = config.load(".client.conf",true)
kConf.keywords_request = kConf.keywords_request or "conReq"
kConf.keywords_refresh = kConf.keywords_refresh or "conRefr"
kConf.keywords_ack = kConf.keywords_ack or "ack"
kConf.keywords_refuse = kConf.keywords_refuse or "refuse"
kConf.keywords_timeout = kConf.keywords_timeout or "timeout"
kConf.keywords_invalid = kConf.keywords_invalid or "invalid"
kConf.keywords_disconnect = kConf.keywords_disconnect or "disc"
kConf.modemBroadcastID = (kConf.modemBroadcastID or "65534")+0

config.save(".server.conf",tConf,true)
config.save(".client.conf",kConf,true)

--Internal memory chache to save about a user
local serverChache = {
  connected = {},
  timeout = {},
  delete = {},
  session = {}
}

--Encryption
local hostkey = "                "
if tConf.doEnch then
  ench.key = hostkey
  ench.gkey()
  hostkey = ench.key
  serverChache.keys = {}
end

--Open desired modem
local tArgs = {...}
local server
if not tArgs[2] and not tConf.modemDir then
  for _,v in pairs(peripheral.getNames()) do
    if peripheral.getType(v) == "modem" then
      server = stillnet:new{name=v,modem=peripheral.wrap(v)}
      if server.modem.isWireless() then
        break
      end
    end
  end
else
  server = stillnet:scan()[tArgs[2] or tConf.modemDir]
end

if not server then error"No modem found!"end

--Generator
local function generateSession()
  if tConf.sessionFormat == "char" then
    local sess = ""
    for i = 0, math.random(8,16) do
      sess = sess .. string.char(math.random(64,254))
    end
    return sess
  elseif tConf.sessionFormat == "1" then
    return 1
  end
end

--Stream
local function pushStream(txt)
	for i = 1, #txt do
		gstream[#txt-i] = gstream[#txt-i-1]
	end
	gstream[1] = txt
end

--Open server modem
server:open(tConf.sID)
server:open(kConf.modemBroadcastID)
server.broadcast_id = kConf.modemBroadcastID
server:allowBroadcast(true)

--Parse raw messages into context
local function parse(raw)
  if type(raw[1]) ~= "table" then
    return {motive=kConf.keywords_invalid}
  end
  
  --Connection request, requires client to broadcast with set ID
  if raw[1].motive == kConf.keywords_request then
    if raw[2] ~= kConf.modemBroadcastID and
      raw[2] ~= tConf.sID and
      raw[4] == kConf.modemBroadcastID and
      type(raw[1].os) == "number" then
	  if serverChache.connected[raw[2]] then
	    return {motive=kConf.keywords_refuse,id=raw[2]}
	  end
      return {motive=kConf.keywords_request,id=raw[2],os=raw[1].os}
    end
  end
  
  if tConf.doEnch then
	--Any point below requires encryption if enabled
	if not serverChache.keys[raw[2]] then
		return {motive=kConf.keywords_invalid}
	end
	ench.key = serverChache.keys[raw[2]]
	raw[1] = ench.enchtable(raw[1])
	ench.key = hostkey
  end
  
  --Connection refresh, disconnect if gotten invalidly
  if raw[1].motive == kConf.keywords_refresh and serverChache.connected[raw[2]] then
    if raw[4] == tConf.sID
	  and raw[1].os == serverChache.connected[raw[2]]
	  and raw[1].session == serverChache.session[raw[2]] then
	  if serverChache.delete[raw[2]] then
	    return {motive=kConf.keywords_refresh,id=raw[2],session=serverChache.session[raw[2]]}
	  end
	  return {motive=kConf.keywords_disconnect,id=raw[2],session=serverChache.session[raw[2]]}
	end
  end
  
  --Disconnect from client
  if raw[1].motive == kConf.keywords_disconnect and serverChache.connected[raw[2]] then
	if raw[4] == tConf.sID
	  and raw[1].os == serverChache.connected[raw[2]]
	  and raw[1].session == serverChache.session[raw[2]] then
		return {motive=kConf.keywords_disconnect,id=raw[2],session=serverChache.session[raw[2]]}
	  end
  end
  
  return {motive=kConf.keywords_invalid}
end

--Shorter transmit fct
local function send(sid,id,msg)
	if tConf.doEnch and serverChache.keys[id] then
		ench.key = serverChache.keys[id]
		server:transmit(sid,id,ench.enchtable(msg))
		ench.key = hostkey
	else
		server:transmit(sid,id,msg)
	end
end

pushStream"#yellow#Launched"
--Runtime
parallel.waitForAny(
--Receival Runtime
function() while true do
  local d = parse{server:receive()}
  
  --Connection request via broadcast
  if d.motive == kConf.keywords_request then
    local session = generateSession()
    server:transmit(tConf.sID,d.id,{motive=kConf.keywords_ack,session=session,doEnch=tConf.doEnch,key=session})
	pushStream("#lime#ID Connected:\n sn-id: "..d.id.."\n os-id: "..d.os.."\n sess.: "..session)
    
    serverChache.connected[d.id] = d.os
    serverChache.delete[d.id] = os.startTimer(tConf.reqTimeout)
    serverChache.session[d.id] = session
	serverChache.keys[d.id] = session
  end
  
  --Connection refuse
  if d.motive == kConf.keywords_refuse then
    server:transmit(tConf.sID,d.id,{motive=kConf.keywords_refuse})
  end
  
  --Connection refresh
  if d.motive == kConf.keywords_refresh then
	serverChache.delete[d.id] = nil
	serverChache.timeout[d.id] = os.startTimer(tConf.timeout)
	send(tConf.sID,d.id,{motive=kConf.keywords_ack,session=d.session})
	pushStream("#gray#ID Refreshed:\n sn-id: "..d.id)
  end
  
  --Disconnect
  if d.motive == kConf.keywords_disconnect then
    send(tConf.sID,d.id,{motive=kConf.keywords_disconnect,session=d.session})
	serverChache.connected[d.id] = nil
	serverChache.timeout[d.id] = nil
	serverChache.session[d.id] = nil
	serverChache.delete[d.id] = nil
	pushStream("#yellow#ID Disconnected:\n sn-id: "..d.id.."\n sess.: "..d.session)
  end
  
end end,

--Timer Runtime
function() while true do
  local e,t = os.pullEvent("timer")
  
  for k,v in pairs(serverChache.timeout) do
    if v == t then
	  local nk = generateSession()
	  pushStream("#gray#Timeout trig:\n sn-id: "..k)
	  send(tConf.sID,k,{motive=kConf.keywords_timeout,session=serverChache.session[k],key=nk})
	  serverChache.keys[k] = nk
	  serverChache.delete[k] = os.startTimer(tConf.deleteTime)
	end
  end
  
  local delind = {}
  for k,v in pairs(serverChache.delete) do
	if v == t then
	  pushStream("#red#Delete trig:\n sn-id: "..k)
	  send(tConf.sID,k,{motive=kConf.keywords_disconnect,session=serverChache.session[k]})
	  serverChache.connected[k] = nil
	  serverChache.timeout[k] = nil
	  serverChache.session[k] = nil
	  table.insert(delind, k)
	end
  end
  
  for _,k in pairs(delind) do serverChache.delete[k] = nil end
end end,

--Stream runtime
function() while true do
	sleep(1)
	while #gstream > 0 do
		term.setTextColor(1)
  local x = gstream[#gstream]:match"^#([^#]+)#"
		if x then
			term.setTextColor(colors[x])
		end
		print(({gstream[#gstream]:gsub("^#[^#]+#","")})[1])
		gstream[#gstream] = nil
	end
end end
)
