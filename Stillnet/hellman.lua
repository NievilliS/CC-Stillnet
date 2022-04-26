local function hta(h)
  local out = {}
  for i = 1,8 do
    out[i] = h:sub(i):byte()
  end
  if #h > 8 then
    out.n = h:sub(9):byte()
    out.m = h:sub(10):byte()
  end
  return out
end

local function ath(a)
  local out = ""
  for i = 1,8 do
    out = out .. string.char(a[i])
  end
  if a.m then
    out = out .. string.char(a.n)..string.char(a.m)
  end
  return out
end

local function sort(a)
  for j = 1, #a do
    for i = 1, #a-j do
      if a[i] > a[i+1] then
        local t = a[i+1]
        a[i+1] = a[i]
        a[i] = t
      end
    end
  end
  return a
end

local function isPrime(n)
  for i = 3, n-1 do
    if n % i == 0 then
      return false
    end
  end
  return true
end

local function getN(n,m)
  for i = 1, 1000000 do
    if (n*i) % m == 1 then
      return i
    end
  end
  return -1
end

function ench.hellmanPrivate()
  local out = {}
  for i = 1, 8 do
    out[i] = math.random(1,100)
  end
  
  for i = 1,8 do
    for j = 1,8 do
      if i ~= j and out[i] == out[j] then
        return ench.hellmanPrivate()
      end
    end
  end
  
  out = sort(out)
  out.n = math.random(15,200)
  repeat
    out.m = math.random(50,255)
  until isPrime(out.m)
  
  --N
  if getN(out.n,out.m) == -1 then
    return ench.hellmanPrivate()
  end
  
  return ath(out)
end

function ench.hellmanPublic(priv)
  local out = {}
  priv = hta(priv)
  for i = 1, 8 do
    out[i] = (priv[i]*priv.n) % priv.m
  end
  return ath(out)
end

function ench.hellmanEnch(publ,dat)
  publ = hta(publ)
  local ndat = {}
  for i = 1, #dat do
    ndat[i] = dat:sub(i):byte()
  end
  
  local out = {}
  for k,v in pairs(ndat) do
    for i = 1, 8 do
      out[k] = (out[k] or 0) + math.floor(v / 128) * publ[i]
      v = (v * 2) % 256
    end
  end
  return out
end

function ench.hellmanDench(priv,dat)
  priv = hta(priv)
  local N = getN(priv.n,priv.m)
  
  for i = 1, #dat do
    dat[i] = (dat[i]*N) % priv.m
    --print(dat[i])
  end
  
  local out = {}
  for k,v in pairs(dat) do
    out[k] = 0
    for i = 0, 7 do
      if priv[8-i] <= v then
        --print("i "..i)
        out[k] = out[k] + 2^i
        --print("out now "..out[k])
        v = v - priv[8-i]
        --print("prv "..priv[8-i])
      end
    end
    
    if v ~= 0 then
      error("Wrong key")
    end
  end
  
  local x = ""
  for k,v in pairs(out) do
    x = x .. string.char(v)
  end
  
  return x
end

function ench.hellmanFullGen(l)
	local a = ench.hellmanPrivate()
local b = ench.hellmanPublic(a)

local func = {}
for i = 0, 255 do pcall(function()
  if string.char(i) == ench.hellmanDench(a, ench.hellmanEnch(b, string.char(i))) then
    func[#func+1] = i
  end end)
end

if #func < 70 then
	l = (l or 0)+1
	if l % 20 == 0 then
		sleep()
	end
	return ench.hellmanFullGen(l)
end

local c = ""
for v,k in pairs(func) do
	c = c .. string.char(k)
end

return a,b,c
end

function ench.hellmanGenerateWithin(c,len)
	local out = ""
	for _ = 1, len do
		out = out .. c:sub(math.random(1,#c))
	end
end