--test_client.lua

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
config.save(".client.conf",kConf,true)

--Open desired modem
local tArgs = {...}
local m
if not tArgs[2] and not kConf.modemDir then
  for _,v in pairs(peripheral.getNames()) do
    if peripheral.getType(v) == "modem" then
      m = stillnet:new{name=v,modem=peripheral.wrap(v)}
      if m.modem.isWireless() then
        break
      end
    end
  end
else
  m = stillnet:scan()[tArgs[2] or kConf.modemDir]
end

local sid = tonumber(({...})[1] or os.getComputerID())

m:open(sid)

local session
local public_key
local restrict
local hid
m:transmit(sid,kConf.modemBroadcastID,{motive=kConf.keywords_request,os=os.getComputerID()})

local function generateSession(restrict)
	local out = ""
	for i = 1, math.random(8,16) do
		local h = math.random(1,#restrict)
		out = out .. restrict:sub(h,h)
	end
	return out
end

local st = {m:receive(sid,nil,5)}
if type(st[1]) ~= "table" then
  error("No server available")
end
if st[1].motive then
  if st[1].motive == kConf.keywords_ack then
    public_key = st[1].public_key
	restrict = st[1].restrict
    hid = st[2]
    print("Connecting")
	
	session = generateSession(restrict)
	local enchSession = ench.hellmanEnch(public_key, session)
	
	m:transmit(sid,hid,{motive=kConf.keywords_session_t,os=os.getComputerID(),session=enchSession})
------------------------------------------------------------
	local st = {m:receive(sid,hid,5)}
	if type(st[1]) ~= "table" then
		error("No server available")
	end
	
	ench.key = session
	st[1] = ench.enchtable(st[1])
	
	if st[1].motive then
		if st[1].motive == kConf.keywords_ack then
			if st[1].session ~= session then
				error("session error")
			end
			m:transmit(sid,hid,ench.enchtable{motive=kConf.keywords_refresh,os=os.getComputerID(),session=session})
			print("Connected!")
		else
			error("error")
		end
	else
		error("error")
	end
	
  elseif st[1].motive == kConf.keywords_refuse then
    error("refused.")
  end
end

local function send(t)
	m:transmit(sid,hid,ench.enchtable(t))
end

parallel.waitForAny(function()
while true do
  local msg = m:receive(sid,hid)
  msg = ench.enchtable(msg)
  if msg.motive == kConf.keywords_disconnect then
    print"Disconnected."
	m:close(sid)
    return
  end
  if msg.motive == kConf.keywords_ack then
    --print("Ack.")
  end
  if msg.motive == kConf.keywords_timeout then
    ench.key = msg.key
    send{motive=kConf.keywords_refresh,os=os.getComputerID(),session=session}
    --print("Timeout.")
  end
  if msg.motive == kConf.keywords_hasname then
    if msg.result then
	  print"Name exists!"
	else
	  print"Name does not exist."
	end
  end
  if msg.motive == kConf.keywords_setname then
    if msg.result == kConf.setname_ae then
	  print"Can't choose this name as it already exists."
	else
	  print"Name changed!"
	end
  end
  if msg.motive == kConf.keywords_forward then
    if msg.result == kConf.forward_ack then
	  local name = msg.from or "server itself"
	  print("Acknowledged forward by "..name.." with "..tostring(msg.packet))
	elseif msg.result == kConf.forward_deny then
	  local name = msg.from or "server itself"
	  print("Forward denied by "..name.." with "..tostring(msg.packet))
	elseif msg.result == kConf.forward_noname then
	  print"Cannot forward without a name!"
	elseif msg.result == kConf.forward_notarget then
	  print"This target does not exist!"
	elseif msg.result == kConf.forward_request then
	  print(msg.from.." has requested with "..tostring(msg.packet))
	elseif msg.result == kConf.forward_respond then
	  print(msg.from.." has responded with "..tostring(msg.packet))
	else
	  print"Invalid forward received"
	end
  end
end
end,function()
while true do
  local e = read()
  if e:match"^q" then
    send{motive=kConf.keywords_disconnect,os=os.getComputerID(),session=session}
  end
  if e:match"^h .+" then
    send{motive=kConf.keywords_hasname,os=os.getComputerID(),session=session,name=e:match("^h (.+)")}
  end
  if e:match"^s " then
    send{motive=kConf.keywords_setname,os=os.getComputerID(),session=session,name=e:match("^s (.+)")}
  end
  if e:match"^f [^ ]+ [^ ]+ .+" then
    local name = e:match"^f ([^ ]+)"
	local packet_string = e:match"^f [^ ]+ [^ ]+ (.+)"
	local ftype = e:match"^f [^ ]+ ([^ ]+)"
	if not kConf["forward_"..ftype] then
	  print"No such type!"
	else
	  send{motive=kConf.keywords_forward,os=os.getComputerID(),session=session,name=name,packet=packet_string,result=kConf["forward_"..ftype]}
	end
  elseif e:match"^f" then
    print"Usage:\n f <name> <packet_string> <type>"
  end
end
end)
