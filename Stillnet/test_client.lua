local m = stillnet:scan().back
local sid = tonumber(({...})[1] or os.getComputerID())

m:open(sid)

local kConf = config.load(".client.conf",true)
kConf.keywords_request = kConf.keywords_request or "conReq"
kConf.keywords_refresh = kConf.keywords_refresh or "conRefr"
kConf.keywords_ack = kConf.keywords_ack or "ack"
kConf.keywords_refuse = kConf.keywords_refuse or "refuse"
kConf.keywords_timeout = kConf.keywords_timeout or "timeout"
kConf.keywords_invalid = kConf.keywords_invalid or "invalid"
kConf.keywords_disconnect = kConf.keywords_disconnect or "disc"
kConf.modemBroadcastID = (kConf.modemBroadcastID or "65534")+0
config.save(".client.conf",kConf,true)

local session
local hid
m:transmit(sid,kConf.modemBroadcastID,{motive=kConf.keywords_request,os=os.getComputerID()})

local st = {m:receive(sid,nil,5)}
if type(st[1]) ~= "table" then
  error("No server available")
end
if st[1].motive then
  if st[1].motive == kConf.keywords_ack then
    session = st[1].session
    hid = st[2]
    print("Connected")
  elseif st[1].motive == kConf.keywords_refuse then
    error("refused.")
  end
end
ench.key = st[1].key
m:transmit(sid,hid,ench.enchtable{motive=kConf.keywords_refresh,os=os.getComputerID(),session=session})

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
    m:transmit(sid,hid,ench.enchtable{motive=kConf.keywords_refresh,os=1,session=session})
    print("Timeout.")
  end
end
