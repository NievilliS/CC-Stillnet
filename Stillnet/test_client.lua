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

while true do
  local msg = m:receive(sid,hid)
  
  for k,v in pairs(msg) do
    print(tostring(k).." = "..tostring(v))
  end
  
  msg = ench.enchtable(msg)
  if msg.motive == kConf.keywords_disconnect then
    print("Disconnected.")
    return
  end
  if msg.motive == kConf.keywords_ack then
    print("Ack.")
  end
  if msg.motive == kConf.keywords_timeout then
    ench.key = msg.key
    print(tostring(msg.key))
    m:transmit(sid,hid,ench.enchtable{motive=kConf.keywords_refresh,os=os.getComputerID(),session=session})
    print("Timeout.")
  end
end
