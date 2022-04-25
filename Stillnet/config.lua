--config.lua

--Config API
_G.config = {}

function config.save(path, tDat, forceOverwrite)
  if type(path) ~= "string" then
    error"require string [, boolean]"
  end
  if fs.exists(shell.resolve(path)) then
    if not forceOverwrite then
      error"path already contains config! call with param 3 being true to force overwrite"
    end
  end
  
  local file = fs.open(path,"w")
  local sDat = ""
  for k,v in pairs(tDat) do
    sDat = sDat..k..":"..v.."\n"
  end
  sDat = sDat:gsub("\n$","")
  file.write(sDat)
  file.close()
  return true
end

function config.append(path,cname,cval)
  if type(path) ~= "string" or type(cname) ~= "string" or not ({string=1,number=1})[type(cval)] then
    error"require path, string, string/number"
  end
  if not cname:match"^[%w_-.]+$" then
    error("invalid character in param 2: \""..cname:match("[^%w_-.]").."\"")
  end
  
  local tDat = config.load(path,true)
  tDat[cname] = cval
  config.save(path,tDat,true)
end

function config.load(path,nullable)
  if type(path) ~= "string" then
    error"require string"
  end
  if not fs.exists(shell.resolve(path)) then
    if nullable then
      return {}
    end
    error"no such file, or set param 2 to true to return {}"
  end
  
  local tDat = {}
  local file = fs.open(path,"r")
  local sLine = file.readLine()
  while sLine do
    table.insert(tDat, sLine)
    sLine = file.readLine()
  end
  file.close()
  
  for i = 1, #tDat do
    local ind = tDat[i]:match"^([%w_-.]+)%:"
    if ind then
      tDat[ind] = tDat[i]:match"[^:]+$"
    end
    tDat[i] = nil
  end
  
  return tDat
end
