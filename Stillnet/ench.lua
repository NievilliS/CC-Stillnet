_G.ench = {}
ench.key = "12345678"

--Ench order:
--Xor, Add, Xor, Sub, Or, Div, Xor, Index Behavior (magic)

local function magic(n,m)
  n = (m*m+n) % 256
  n = bit.bxor(m,n)
  return (n+n*n+m+m) % 256
end

local function doThis(ind,mag)
  return math.sin(ind*mag+1) > 0.3
end

function string.tca(self)
  local out = {}
  for i = 1, #self do
    out[i] = self:sub(i,i)
  end
  return out
end

function string.act(da)
  local out = ""
  for _,v in pairs(da) do
    out = out..v
  end
  return out
end

local function getN(i)
  return ench.key:sub(i,i):byte()
end

function ench.ench(x,notsw)
  local tp = {}
  for i,v in pairs(string.tca(x)) do
    local n = v:byte()
    for I = 1, #ench.key-1 do
      if doThis(I+i,getN(#ench.key)+I+i*i) then
        local a = magic(i*i+I, getN(I))
        n = bit.bxor(a,n)
      end
    end
    tp[#tp+1] = string.char(n)
  end
  --[[if not notsw then
  for I = 1, #tp-1 do
    if doThis(I*I+#x, getN(#ench.key)*I+I+#x+2) then
      local tmp = tp[I]
      tp[I] = tp[I+1]
      tp[I+1] = tmp
    end
  end end--]]
  return string.act(tp)
end

function ench.gkey()
  local a = {}
  for i = 1, #ench.key do
    a[i] = string.char(math.random(0,255))
  end
  ench.key = string.act(a)
end

function ench.enchnumber(n)
  --convert number into string bitwise and return new number
  local tmp = ""
  --index 0 is lsb
  repeat
    local x = n % 256
    n = n - x
    n = n / 256
    
    tmp = tmp .. string.char(x)
    --print(string.char(x))
  until n == 0
  
  tmp = ench.ench(tmp,true)
  local out = 0
  for i = 1, #tmp do
    out = out * 256
    out = out + tmp:sub(i,i):byte()
  end
  return out
end

function ench.enchtable(t)
  --proc:
  local output = {}
  for k,v in pairs(t) do
    local k_new
    local v_new
    --K
    if type(k) == "number" then
      if k < 65536 then
        k_new = ench.enchnumber(k)
      else
        k_new = k
      end
    elseif type(k) == "string" then
      k_new = ench.ench(k)
    else
      k_new = k
    end
    
    --V
    if type(v) == "number" then
      if v < 65536 then
        v_new = ench.enchnumber(v)
      else
        v_new = v
      end  
    elseif type(v) == "string" then
      v_new = ench.ench(v)
    elseif type(v) == "table" then
      v_new = ench.enchtable(v)
    else
      v_new = v
    end
    
    output[k_new] = v_new
  end
  
  return output
end
