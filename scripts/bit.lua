local bit = bit or bit32

if not bit then
    local mask = 0xFFFFFFFF
    bit = {
        band = function(a, b) return (a & b) & mask end,
        bor = function(a, b) return (a | b) & mask end,
        bxor = function(a, b) return (a ~ b) & mask end,
        bnot = function(a) return (~a) & mask end,
        lshift = function(a, b) return (a << b) & mask end,
        rshift = function(a, b) return (a >> b) & mask end,
    }
end

return bit
