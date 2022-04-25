_G.primes = {}
local function isprime(n)
    if n == 2 then
        return true
    end
    for i = 2, n-1 do
        if n % i == 0 then
            return false
        end
    end
    return true
end
local function getPrimesN(nmax)
    for i = 2, nmax do
        if isprime(i) then primes[#primes+1] = i end
    end
end
getPrimesN(1000)

function _G.factorSeperation(n)
    local out = {}
    while n > 1 do
        for _,v in pairs(primes) do
            if n % v == 0 then
                out[v] = (out[v] or 0)+1
                n = n/v
            end
            if v > n then
                break
            end
        end
    end
    return out
end

function _G.phi_fct(n)
    local x = 1
    for k,v in pairs(factorSeperation(n)) do
        x = x * math.pow(k,v-1) * (v-1)
    end
    return x
end

function _G.fullRSA()
    local e = primes[math.random(10,#primes)]
    local p
    local q
    local N
    local log2 = math.log(2)
    while true do
        local i1 = math.random(4,#primes)
        local i2 = i1 + math.random(0,9)-4
        p = primes[i1]
        q = primes[i2]
        
        --local range = math.abs(math.log(p)-math.log(q))/log2
        
        --if range > 0.1 and range < 30 then
            if e % p == 0 and e % q == 0 and p ~= q then
            sleep()
            N = p*q
            if N >= 255 then
                break
            end end
        --end
    end
    
    local phiN = (p-1)*(q-1)
    local d
    local k
    
    for D = 1, 100 do
        for K = 1, 100 do
            if e*D - K*phiN == 1 then
                d = D
                k = K
                break
            end
        end
        sleep()
        print(D)
    end
    
    return {e=e,p=p,q=q,N=N,phiN=phiN,d=d,k=k}
end
