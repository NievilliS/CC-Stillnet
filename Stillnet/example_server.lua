--server_host.lua

--#### Server Hosting
_G.gstream = {}
local tArgs = {...}

--Load Configuration
local tConf = config.load(".server.conf",true)
tConf.sessionFormat = tConf.sessionFormat or "char"
tConf.sID = (tArgs[1] or tConf.sID or os.getComputerID())+0
tConf.reqTimeout = (tConf.reqTimeout or 1)+0
tConf.timeout = (tConf.timeout or 10)+0
tConf.deleteTime = (tConf.deleteTime or 5)+0
tConf.doEnch = (tConf.doEnch or 1)+0
tConf.msg_IDCON = tConf.msg_IDCON or "#lime#ID Connected<col><br> sn-id<col> <id><br> os-id<col> <os>"
tConf.msg_UDISC = tConf.msg_UDISC or "#green#ID Disconnected<col><br> sn-id<col> <id>"
tConf.msg_HASN = tConf.msg_HASN or "#orange#<q><sname><q> (<sid>) asked for <q><name><q> (<id>)"
tConf.msg_SETN_ae = tConf.msg_SETN_ae or "#red#ID <id> ae-bad setname attempt as <q><name><q>"
tConf.msg_SETN_success = tConf.msg_SETN_success or "#yellow#ID <id> setname as <q><name><q>"
tConf.msg_FWRD_noname = tConf.msg_FWRD_noname or "#red#ID <id> bad forward without own name"
tConf.msg_FWRD_notarget = tConf.msg_FWRD_notarget or "#red#ID <sname> (<id>) bad forward trying at <q><name><q>"
tConf.msg_FORWARD = tConf.msg_FORWARD or "#orange#<q><sname><q> (<sid>) forwarding to <q><name><q> (<id>) with <res>"
tConf.msg_DELTRIG = tConf.msg_DELTRIG or "#purple#<id> timed out, disconnected"
tConf.msg_do_gray = (tConf.msg_do_gray or "false") == "true"
tConf.msg_REFR = tConf.msg_REFR or "#gray#<id> refreshed"
tConf.msg_TIMO = tConf.msg_TIMO or "#gray#<id> timeout trigger"
tConf.msg_do_fwrd_res = (tConf.msg_do_fwrd_res or "false") == "true"

local kConf = config.load(".client.conf",true)
kConf.keywords_request = kConf.keywords_request or "conReq"
kConf.keywords_refresh = kConf.keywords_refresh or "conRefr"
kConf.keywords_session_t = kConf.keywords_session_t or "sessionTransfer"
kConf.keywords_ack = kConf.keywords_ack or "ack"
kConf.keywords_refuse = kConf.keywords_refuse or "refuse"
kConf.keywords_timeout = kConf.keywords_timeout or "timeout"
kConf.keywords_invalid = kConf.keywords_invalid or "invalid"
kConf.keywords_disconnect = kConf.keywords_disconnect or "disc"
kConf.keywords_forward = kConf.keywords_forward or "forward"
kConf.keywords_setname = kConf.keywords_setname or "setname"
kConf.keywords_hasname = kConf.keywords_hasname or "hasname"
kConf.setname_ae = kConf.setname_ae or "setn_ae"
kConf.setname_success = kConf.setname_success or "setn_sc"
kConf.forward_noname = kConf.forward_noname or "fwrd_nil"
kConf.forward_ack = kConf.forward_ack or "fwrd_ack"
kConf.forward_deny = kConf.forward_deny or "fwrd_dny"
kConf.forward_respond = kConf.forward_respond or "fwrd_res"
kConf.forward_request = kConf.forward_request or "fwrd_req"
kConf.forward_notarget = kConf.forward_notarget or "fwrd_ntg"
kConf.modemBroadcastID = (kConf.modemBroadcastID or "65534")+0

config.save(".server.conf",tConf,true)
config.save(".client.conf",kConf,true)

--Internal memory chache to save about a user
local serverChache = {
  connected = {},
  timeout = {},
  delete = {},
  session = {},
  names = {},
  names_inv = {}
}

term.clear()
term.setCursorPos(1,1)

--Encryption
local hostKeys = {}
if tConf.doEnch then
  serverChache.keys = {}
  print"Generating keys..."
  hostKeys.private, hostKeys.public, hostKeys.available = ench.hellmanFullGen()
end

--Open desired modem
local server
if not tArgs[2] and not kConf.modemDir then
  for _,v in pairs(peripheral.getNames()) do
    if peripheral.getType(v) == "modem" then
      server = stillnet:new{name=v,modem=peripheral.wrap(v)}
      if server.modem.isWireless() then
        break
      end
    end
  end
else
  server = stillnet:scan()[tArgs[2] or kConf.modemDir]
end

if not server then error"No modem found!"end

--Generator
local function generateKey()
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
  
  --Receive encrypted session and key
  if raw[1].motive == kConf.keywords_session_t and serverChache.connected[raw[2]] then
    if raw[4] == tConf.sID
	  and raw[1].os == serverChache.connected[raw[2]] then
	  if serverChache.delete[raw[2]] then
	    return {motive=kConf.keywords_session_t,id=raw[2],os=raw[1].os,sessionEnch=raw[1].session}
	  end
	  return {motive=kConf.keywords_invalid}
	end
    return {motive=kConf.keywords_invalid}
  end
  
  if tConf.doEnch then
	--Any point below requires encryption if enabled
	if not serverChache.keys[raw[2]] then
		return {motive=kConf.keywords_invalid}
	end
	ench.key = serverChache.keys[raw[2]]
	raw[1] = ench.enchtable(raw[1])
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
  
  --Hasname check, serverChache.names[name] != nil bounces back to client
  if raw[1].motive == kConf.keywords_hasname and serverChache.connected[raw[2]] then
    if raw[4] == tConf.sID
	  and raw[1].os == serverChache.connected[raw[2]]
	  and raw[1].session == serverChache.session[raw[2]] then
	    return {motive=kConf.keywords_hasname,id=raw[2],session=serverChache.session[raw[2]],name=raw[1].name}
	end
  end
  
  --Setname, or rather, give alias that other clients have to use when forwarding packets (making it required for intercommunication)
  if raw[1].motive == kConf.keywords_setname and serverChache.connected[raw[2]] then
    if raw[4] == tConf.sID
	  and raw[1].os == serverChache.connected[raw[2]]
	  and raw[1].session == serverChache.session[raw[2]] then
	    return {motive=kConf.keywords_setname,id=raw[2],session=serverChache.session[raw[2]],name=raw[1].name}
	end
  end
  
  --Forwards a packet to the name's ID
  if raw[1].motive == kConf.keywords_forward and serverChache.connected[raw[2]] then
    if raw[4] == tConf.sID
	  and raw[1].os == serverChache.connected[raw[2]]
	  and raw[1].session == serverChache.session[raw[2]]
	  and raw[1].packet and raw[1].name and raw[1].result then
	    return {motive=kConf.keywords_forward,id=raw[2],session=serverChache.session[raw[2]],name=raw[1].name,packet=raw[1].packet,result=raw[1].result}
	end
  end
  
  return {motive=kConf.keywords_invalid}
end

--Shorter transmit fct
local function send(sid,id,msg)
	if tConf.doEnch and serverChache.keys[id] then
		ench.key = serverChache.keys[id]
		server:transmit(sid,id,ench.enchtable(msg))
	else
		server:transmit(sid,id,msg)
	end
end

local std_st_gsubs = {br="\n", q="\"", col=":"}
local function streamtool(t)
  local txt = t[1]
  for k,v in pairs(t) do
    txt = txt:gsub("<"..tostring(k)..">", tostring(v))
  end
  for k,v in pairs(std_st_gsubs) do
    txt = txt:gsub("<"..tostring(k)..">", tostring(v))
  end
  pushStream(txt)
end

pushStream"#yellow#Launched"
--Runtime
parallel.waitForAny(
--Receival Runtime
function() while true do
  local d = parse{server:receive()}
  
  --Connection request via broadcast
  if d.motive == kConf.keywords_request then
    server:transmit(tConf.sID,d.id,{motive=kConf.keywords_ack,public_key=hostKeys.public,doEnch=tConf.doEnch,restrict=hostKeys.available})
    serverChache.connected[d.id] = d.os
    serverChache.delete[d.id] = os.startTimer(tConf.reqTimeout)
	streamtool{tConf.msg_IDCON, id=d.id, os=d.os}
  end
  
  --Client gives session
  if d.motive == kConf.keywords_session_t then
	serverChache.session[d.id] = ench.hellmanDench(hostKeys.private, d.sessionEnch)
	serverChache.keys[d.id] = serverChache.session[d.id]
	send(tConf.sID,d.id,{motive=kConf.keywords_ack,session=serverChache.session[d.id]})
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
	streamtool{tConf.msg_REFR, id=d.id}
  end
  
  --Disconnect
  if d.motive == kConf.keywords_disconnect then
    send(tConf.sID,d.id,{motive=kConf.keywords_disconnect,session=d.session})
	serverChache.connected[d.id] = nil
	serverChache.timeout[d.id] = nil
	serverChache.session[d.id] = nil
	serverChache.delete[d.id] = nil
	if serverChache.names_inv[d.id] then
	    serverChache.names[serverChache.names_inv[d.id]] = nil
		serverChache.names_inv[d.id] = nil
	  end
	streamtool{tConf.msg_UDISC, id=d.id}
  end
  
  --Has name check, return true or false, but not 
  if d.motive == kConf.keywords_hasname then
    send(tConf.sID,d.id,{motive=kConf.keywords_hasname,session=d.session,result=serverChache.names[d.name] ~= nil})
	streamtool{tConf.msg_HASN, sname=serverChache.names_inv[d.id], sid=d.id, name=d.name, id=serverChache.names[d.name]}
  end
  
  --First checks if the name already exists, then applies it, clears if d.name = nil
  if d.motive == kConf.keywords_setname then
    if d.name and serverChache.names[d.name] then
	  send(tConf.sID,d.id,{motive=kConf.keywords_setname,session=d.session,result=kConf.setname_ae})
	  streamtool{tConf.msg_SETN_ae, id=d.id, name=d.name}
	else
	  if serverChache.names_inv[d.id] then
	    serverChache.names[serverChache.names_inv[d.id]] = nil
	  end
	  serverChache.names_inv[d.id] = d.name
	  if d.name then
	    serverChache.names[d.name] = d.id
	  end
	  send(tConf.sID,d.id,{motive=kConf.keywords_setname,session=d.session,result=kConf.setname_success})
	  streamtool{tConf.msg_SETN_success, id=d.id, name=d.name}
	end
  end
  
  --Packet transmission
  if d.motive == kConf.keywords_forward then
    if not serverChache.names_inv[d.id] then
	  send(tConf.sID,d.id,{motive=kConf.keywords_forward,session=d.session,result=kConf.forward_noname})
	  streamtool{tConf.msg_FWRD_noname, id=d.id}
	elseif not serverChache.names[d.name] then
	  send(tConf.sID,d.id,{motive=kConf.keywords_forward,session=d.session,result=kConf.forward_notarget})
	  streamtool{tConf.msg_FWRD_notarget, id=d.id, sname=serverChache.names_inv[d.id], name=d.name}
	else
	  send(tConf.sID,d.id,{motive=kConf.keywords_forward,session=d.session,result=kConf.forward_ack})
	  send(tConf.sID,serverChache.names[d.name],{motive=kConf.keywords_forward,session=serverChache.session[serverChache.names[d.name]],packet=d.packet,from=serverChache.names_inv[d.id],to=d.name,result=d.result})
	  if tConf.msg_do_fwrd_res or not d.result == kConf.forward_respond then
	    streamtool{tConf.msg_FORWARD, sname=serverChache.names_inv[d.id], sid=d.id, name=d.name, id=serverChache.names[d.name], res=d.result}
	  end
	end
  end
  
end end,

--Timer Runtime
function() while true do
  local e,t = os.pullEvent("timer")
  
  for k,v in pairs(serverChache.timeout) do
    if v == t then
	  local nk = generateKey()
	  pushStream(tConf.msg_TIMO:gsub("<id>",tostring(k)))
	  send(tConf.sID,k,{motive=kConf.keywords_timeout,session=serverChache.session[k],key=nk})
	  serverChache.keys[k] = nk
	  serverChache.delete[k] = os.startTimer(tConf.deleteTime)
	end
  end
  
  local delind = {}
  for k,v in pairs(serverChache.delete) do
	if v == t then
	  pushStream(tConf.msg_DELTRIG:gsub("<id>",tostring(k)))
	  send(tConf.sID,k,{motive=kConf.keywords_disconnect,session=serverChache.session[k]})
	  serverChache.connected[k] = nil
	  serverChache.timeout[k] = nil
	  serverChache.session[k] = nil
	  if serverChache.names_inv[k] then
	    serverChache.names[serverChache.names_inv[k]] = nil
		serverChache.names_inv[k] = nil
	  end
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
		if tConf.msg_do_gray or not gstream[#gstream]:match"^#gray#" then
			print(({gstream[#gstream]:gsub("^#[^#]+#","")})[1])
		end
		gstream[#gstream] = nil
	end
end end
)
