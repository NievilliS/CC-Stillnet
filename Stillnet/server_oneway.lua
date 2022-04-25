--Format:
--To Encrypt:

ench.k_enc = ""
ench.k_dec = ""

--Encrypt order:
--xor,mul,sub,div,add,mul,xor,mul
--Decrypt order:
--div,xor,div,sub,mul,add,div,xor

function ench.genL8()
    local s = ""
    for i = 1,8 do
        s = s..string.char(math.random(1,255)) --dont wanna have a divide by zero thingy
    end
    return s
end

local function d(val)
    return math.sin(val) < 0.3
end

function ench.OW_encrypt(s)
    local n = {}
    for k,v in pairs(string.tca(ench.k_enc)) do
        n[k] = v:byte()
    end
    
    local out = {}
    for k,v in pairs(string.tca(s)) do
        local t = v:byte()
        if d(n[1]) then t = bit.bxor(t, n[1]) end
        if d(n[2]) then t = t * n[2] end
        if d(n[3]) then t = t - n[3] end
        if d(n[4]) then t = t / n[4] end
        if d(n[5]) then t = t + n[5] end
        if d(n[6]) then t = t * n[6] end
        if d(n[7]) then t = bit.bxor(t, n[7]) end
        if d(n[8]) then t = t * n[8] end
        out[k] = t
    end
    
    return out
end

function ench.OW_decrypt(s)
    local n = {}
    for k,v in pairs(string.tca(ench.k_dec)) do
        n[k] = v:byte()
    end
	
	local out = ""
    for k,v in pairs(s) do
        local t = v
        if d(n[1]) then t = t / n[1] end
        if d(n[2]) then t = bit.bxor(t, n[2]) end
        if d(n[3]) then t = t / n[3] end
        if d(n[4]) then t = t - n[4] end
        if d(n[5]) then t = t * n[5] end
        if d(n[6]) then t = t + n[6] end
        if d(n[7]) then t = t / n[7] end
        if d(n[8]) then t = bit.bxor(t, n[8]) end
        out = out .. string.char(t)
    end
    
    return out
end
