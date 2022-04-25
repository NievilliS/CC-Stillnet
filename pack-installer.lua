local tArgs = {...}

if #tArgs < 1 then
  error"usage: path"
end

local p = shell.resolve(tArgs[1])

if not fs.exists(p) then
  error"no such file"
end

local file = fs.open(p,"r")
local sline = file.readLine()
local selFile = {close=function()end}

while sline do
  if sline:match("^\000\001\002[%w]") then
    local path = sline:gsub("^\000\001\002","")
    selFile.close()
    selFile = fs.open("./Stillnet/"..path,"w")
    selFile.write("--"..path.."")
  else
    selFile.write("\n")
    selFile.write(sline)
  end
  sline = file.readLine()
end

selFile.close()
file.close()
