--Pastebin URL: http://pastebin.com/NRz3nxru

local hPack = http.get"https://raw.githubusercontent.com/NievilliS/CC-Stillnet/master/stillnet.pack"
local hInst = http.get"https://raw.githubusercontent.com/NievilliS/CC-Stillnet/master/pack-installer.lua"

if not hPack or not hInst then
  error"Could not get stillnet packs!"
end

local fPack = fs.open("stillnet.pack","w")
local fInst = fs.open("pack-installer.lua","w")

fPack.write(hPack.readAll())
fInst.write(hInst.readAll())

fPack.close()
fInst.close()
hPack.close()
hInst.close()

print"Got files"

shell.run"pack-installer.lua stillnet.pack"

print"Installed"

local dat = "shell.run'./Stillnet/base.lua'"

if fs.exists("startup.lua") then
  local file = fs.open("startup.lua","r")
  dat = dat.."\n\n"..file.readAll()
  file.close()
  
  print"Startup exists, insert as first line"
end

local file = fs.open("startup.lua","w")
file.write(dat)
file.close()

print"Startup overwritten\nRebooting..."
sleep(3)
os.reboot()
