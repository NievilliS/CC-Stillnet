--SSH Protocol consists of writing screen, writing files executing native commands
_G.ssh = {}
local ssh.sConf = config.load(".ssh.conf", true)
ssh.sConf.x_write = ssh.sConf.x_write or "write"
ssh.sConf.x_scp = ssh.sConf.x_scp or "scp"
ssh.sConf.x_stc = ssh.sConf.x_stc or "stc"
ssh.sConf.x_sbc = ssh.sConf.x_sbc or "sbc"
ssh.sConf.x_event = ssh.sConf.x_event or "event"
ssh.sConf.x_invoke = ssh.sConf.x_invoke or "invoke"
config.save(".ssh.conf", ssh.sConf, true)
local kConf = config.load(".client.conf", false)

local ssh.scConf = config.load(".ssh.client.conf", true)

config.save(".ssh.client.conf", ssh.scConf, true)

_G.ssh.confirm_function = function()
  if not ssh.scConf.password then error"Require ssh user in .ssh.client.conf !" end
end

ssh.key = {
  request = "RQ_ssh_connection1.0",
  request_f = "Deny",
  request_a = "Accept",
  connect_pw = "ConnectPW;"
}

ssh.executor = function(result, packet)
  if result == kConf.forward_request and packet.c == ssh.key.request then
    return true
  end
end

ssh.sshname = ""

ssh.tSSHEnv = {
  print = function(...)
	local t = {...}
	local s = t[1]
	for i = 2, #t do
		s = s .. " " .. t[i]
	end
	client.m:transmit(client.sid,client.hid,ench.enchtable{motive=kConf.transmit_respond,os=os.getComputerID(),session=client.session,name=ssh.sshname,packet={c=ssh.sConf.x_write,d=s.."\n"}})
  end,
  term = {
    write = function(...)
	  local t = {...}
	  local s = t[1]
	  for i = 2, #t do
	  	s = s .. " " .. t[i]
	  end
	  client.m:transmit(client.sid,client.hid,ench.enchtable{motive=kConf.transmit_respond,os=os.getComputerID(),session=client.session,name=ssh.sshname,packet={c=ssh.sConf.x_write,d=s}})
    end,
    setCursorPos = function(x,y)
	  client.m:transmit(client.sid,client.hid,ench.enchtable{motive=kConf.transmit_respond,os=os.getComputerID(),session=client.session,name=ssh.sshname,packet={c=ssh.sConf.x_scp,d={x,y}}})
	end,
	setTextColor = function(col)
	  client.m:transmit(client.sid,client.hid,ench.enchtable{motive=kConf.transmit_respond,os=os.getComputerID(),session=client.session,name=ssh.sshname,packet={c=ssh.sConf.x_stc,d={col}}})
	end,
	setBackgroundColor = function(col)
	  client.m:transmit(client.sid,client.hid,ench.enchtable{motive=kConf.transmit_respond,os=os.getComputerID(),session=client.session,name=ssh.sshname,packet={c=ssh.sConf.x_sbc,d={col}}})
	end,
  }
}