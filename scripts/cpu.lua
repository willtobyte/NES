local bit = require("bit")
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local lshift, rshift = bit.lshift, bit.rshift
local structs = require("ffi_structs")

local cpu = {}

local a, x, y, sp, pc
local status
local bus
local bus_read, bus_write, bus_get_dma_cycles

local ram = structs.ram
local prg_rom
local prg_mask
local nz_flags = structs.nz_flags
local signed_offset = structs.signed_offset

local FLAG_C = 0x01
local FLAG_Z = 0x02
local FLAG_I = 0x04
local FLAG_D = 0x08
local FLAG_B = 0x10
local FLAG_U = 0x20
local FLAG_V = 0x40
local FLAG_N = 0x80

local FLAG_NZ_CLEAR = 0x7D
local FLAG_CNZ_CLEAR = 0x7C
local FLAG_CVNZ_CLEAR = 0x3C

local function push(value)
    bus_write(0x0100 + sp, value)
    sp = band(sp - 1, 0xFF)
end

local function pull()
    sp = band(sp + 1, 0xFF)
    return bus_read(0x0100 + sp)
end

local function read_code(addr)
    return prg_rom[band(addr, prg_mask)]
end

local op = {}

for i = 0, 255 do
    op[i] = function() return 2 end
end

op[0x00] = function()
    pc = band(pc + 1, 0xFFFF)
    push(rshift(pc, 8))
    push(band(pc, 0xFF))
    push(bor(status, FLAG_B, FLAG_U))
    status = bor(status, FLAG_I)
    pc = bor(bus_read(0xFFFE), lshift(bus_read(0xFFFF), 8))
    return 7
end

op[0x01] = function()
    local base = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    a = bor(a, bus_read(bor(lo, lshift(hi, 8))))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 6
end

op[0x05] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    a = bor(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 3
end

op[0x06] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local new_c = band(m, 0x80) ~= 0 and FLAG_C or 0
    m = band(lshift(m, 1), 0xFF)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 5
end

op[0x08] = function()
    push(bor(status, FLAG_B, FLAG_U))
    return 3
end

op[0x09] = function()
    a = bor(a, read_code(pc))
    pc = band(pc + 1, 0xFFFF)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 2
end

op[0x0A] = function()
    local new_c = band(a, 0x80) ~= 0 and FLAG_C or 0
    a = band(lshift(a, 1), 0xFF)
    status = bor(band(status, 0x3C), new_c, nz_flags[a])
    return 2
end

op[0x0D] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    a = bor(a, bus_read(bor(lo, lshift(hi, 8))))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4
end

op[0x0E] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = bor(lo, lshift(hi, 8))
    local m = bus_read(addr)
    local new_c = band(m, 0x80) ~= 0 and FLAG_C or 0
    m = band(lshift(m, 1), 0xFF)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 6
end

op[0x10] = function()
    local offset = signed_offset[read_code(pc)]
    pc = band(pc + 1, 0xFFFF)
    if band(status, FLAG_N) == 0 then
        local target = band(pc + offset, 0xFFFF)
        local extra = band(pc, 0xFF00) ~= band(target, 0xFF00) and 2 or 1
        pc = target
        return 2 + extra
    end
    return 2
end

op[0x11] = function()
    local base = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local addr = bor(lo, lshift(hi, 8))
    local final = band(addr + y, 0xFFFF)
    local extra = band(addr, 0xFF00) ~= band(final, 0xFF00) and 1 or 0
    a = bor(a, bus_read(final))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 5 + extra
end

op[0x15] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    a = bor(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4
end

op[0x16] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local new_c = band(m, 0x80) ~= 0 and FLAG_C or 0
    m = band(lshift(m, 1), 0xFF)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 6
end

op[0x18] = function()
    status = band(status, 0xFE)
    return 2
end

op[0x19] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + y, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    a = bor(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4 + extra
end

op[0x1D] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + x, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    a = bor(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4 + extra
end

op[0x1E] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = band(bor(lo, lshift(hi, 8)) + x, 0xFFFF)
    local m = bus_read(addr)
    local new_c = band(m, 0x80) ~= 0 and FLAG_C or 0
    m = band(lshift(m, 1), 0xFF)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 7
end

op[0x20] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    local ret = band(pc + 1, 0xFFFF)
    push(rshift(ret, 8))
    push(band(ret, 0xFF))
    pc = bor(lo, lshift(hi, 8))
    return 6
end

op[0x21] = function()
    local base = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    a = band(a, bus_read(bor(lo, lshift(hi, 8))))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 6
end

op[0x24] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local f = band(status, 0x3D)
    if band(a, m) == 0 then f = bor(f, FLAG_Z) end
    if band(m, 0x40) ~= 0 then f = bor(f, FLAG_V) end
    if band(m, 0x80) ~= 0 then f = bor(f, FLAG_N) end
    status = f
    return 3
end

op[0x25] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    a = band(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 3
end

op[0x26] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local c = band(status, FLAG_C)
    local new_c = band(m, 0x80) ~= 0 and FLAG_C or 0
    m = band(bor(lshift(m, 1), c), 0xFF)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 5
end

op[0x28] = function()
    status = bor(band(pull(), 0xEF), FLAG_U)
    return 4
end

op[0x29] = function()
    a = band(a, read_code(pc))
    pc = band(pc + 1, 0xFFFF)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 2
end

op[0x2A] = function()
    local c = band(status, FLAG_C)
    local new_c = band(a, 0x80) ~= 0 and FLAG_C or 0
    a = band(bor(lshift(a, 1), c), 0xFF)
    status = bor(band(status, 0x3C), new_c, nz_flags[a])
    return 2
end

op[0x2C] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local m = bus_read(bor(lo, lshift(hi, 8)))
    local f = band(status, 0x3D)
    if band(a, m) == 0 then f = bor(f, FLAG_Z) end
    if band(m, 0x40) ~= 0 then f = bor(f, FLAG_V) end
    if band(m, 0x80) ~= 0 then f = bor(f, FLAG_N) end
    status = f
    return 4
end

op[0x2D] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    a = band(a, bus_read(bor(lo, lshift(hi, 8))))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4
end

op[0x2E] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = bor(lo, lshift(hi, 8))
    local m = bus_read(addr)
    local c = band(status, FLAG_C)
    local new_c = band(m, 0x80) ~= 0 and FLAG_C or 0
    m = band(bor(lshift(m, 1), c), 0xFF)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 6
end

op[0x30] = function()
    local offset = signed_offset[read_code(pc)]
    pc = band(pc + 1, 0xFFFF)
    if band(status, FLAG_N) ~= 0 then
        local target = band(pc + offset, 0xFFFF)
        local extra = band(pc, 0xFF00) ~= band(target, 0xFF00) and 2 or 1
        pc = target
        return 2 + extra
    end
    return 2
end

op[0x31] = function()
    local base = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local addr = bor(lo, lshift(hi, 8))
    local final = band(addr + y, 0xFFFF)
    local extra = band(addr, 0xFF00) ~= band(final, 0xFF00) and 1 or 0
    a = band(a, bus_read(final))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 5 + extra
end

op[0x35] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    a = band(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4
end

op[0x36] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local c = band(status, FLAG_C)
    local new_c = band(m, 0x80) ~= 0 and FLAG_C or 0
    m = band(bor(lshift(m, 1), c), 0xFF)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 6
end

op[0x38] = function()
    status = bor(status, FLAG_C)
    return 2
end

op[0x39] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + y, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    a = band(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4 + extra
end

op[0x3D] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + x, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    a = band(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4 + extra
end

op[0x3E] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = band(bor(lo, lshift(hi, 8)) + x, 0xFFFF)
    local m = bus_read(addr)
    local c = band(status, FLAG_C)
    local new_c = band(m, 0x80) ~= 0 and FLAG_C or 0
    m = band(bor(lshift(m, 1), c), 0xFF)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 7
end

op[0x40] = function()
    status = bor(band(pull(), 0xEF), FLAG_U)
    local lo = pull()
    local hi = pull()
    pc = bor(lo, lshift(hi, 8))
    return 6
end

op[0x41] = function()
    local base = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    a = bxor(a, bus_read(bor(lo, lshift(hi, 8))))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 6
end

op[0x45] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    a = bxor(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 3
end

op[0x46] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local new_c = band(m, 0x01) ~= 0 and FLAG_C or 0
    m = rshift(m, 1)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 5
end

op[0x48] = function()
    push(a)
    return 3
end

op[0x49] = function()
    a = bxor(a, read_code(pc))
    pc = band(pc + 1, 0xFFFF)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 2
end

op[0x4A] = function()
    local new_c = band(a, 0x01) ~= 0 and FLAG_C or 0
    a = rshift(a, 1)
    status = bor(band(status, 0x3C), new_c, nz_flags[a])
    return 2
end

op[0x4C] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = bor(lo, lshift(hi, 8))
    return 3
end

op[0x4D] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    a = bxor(a, bus_read(bor(lo, lshift(hi, 8))))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4
end

op[0x4E] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = bor(lo, lshift(hi, 8))
    local m = bus_read(addr)
    local new_c = band(m, 0x01) ~= 0 and FLAG_C or 0
    m = rshift(m, 1)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 6
end

op[0x50] = function()
    local offset = signed_offset[read_code(pc)]
    pc = band(pc + 1, 0xFFFF)
    if band(status, FLAG_V) == 0 then
        local target = band(pc + offset, 0xFFFF)
        local extra = band(pc, 0xFF00) ~= band(target, 0xFF00) and 2 or 1
        pc = target
        return 2 + extra
    end
    return 2
end

op[0x51] = function()
    local base = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local addr = bor(lo, lshift(hi, 8))
    local final = band(addr + y, 0xFFFF)
    local extra = band(addr, 0xFF00) ~= band(final, 0xFF00) and 1 or 0
    a = bxor(a, bus_read(final))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 5 + extra
end

op[0x55] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    a = bxor(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4
end

op[0x56] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local new_c = band(m, 0x01) ~= 0 and FLAG_C or 0
    m = rshift(m, 1)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 6
end

op[0x58] = function()
    status = band(status, 0xFB)
    return 2
end

op[0x59] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + y, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    a = bxor(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4 + extra
end

op[0x5D] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + x, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    a = bxor(a, bus_read(addr))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4 + extra
end

op[0x5E] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = band(bor(lo, lshift(hi, 8)) + x, 0xFFFF)
    local m = bus_read(addr)
    local new_c = band(m, 0x01) ~= 0 and FLAG_C or 0
    m = rshift(m, 1)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 7
end

op[0x60] = function()
    local lo = pull()
    local hi = pull()
    pc = band(bor(lo, lshift(hi, 8)) + 1, 0xFFFF)
    return 6
end

op[0x61] = function()
    local base = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local m = bus_read(bor(lo, lshift(hi, 8)))
    local c = band(status, FLAG_C)
    local sum = a + m + c
    local result = band(sum, 0xFF)
    local f = sum > 255 and FLAG_C or 0
    if band(bxor(a, result), bxor(m, result), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 6
end

op[0x65] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local c = band(status, FLAG_C)
    local sum = a + m + c
    local result = band(sum, 0xFF)
    local f = sum > 255 and FLAG_C or 0
    if band(bxor(a, result), bxor(m, result), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 3
end

op[0x66] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local c = band(status, FLAG_C) ~= 0 and 0x80 or 0
    local new_c = band(m, 0x01) ~= 0 and FLAG_C or 0
    m = bor(rshift(m, 1), c)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 5
end

op[0x68] = function()
    a = pull()
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4
end

op[0x69] = function()
    local m = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local c = band(status, FLAG_C)
    local sum = a + m + c
    local result = band(sum, 0xFF)
    local f = sum > 255 and FLAG_C or 0
    if band(bxor(a, result), bxor(m, result), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 2
end

op[0x6A] = function()
    local c = band(status, FLAG_C) ~= 0 and 0x80 or 0
    local new_c = band(a, 0x01) ~= 0 and FLAG_C or 0
    a = bor(rshift(a, 1), c)
    status = bor(band(status, 0x3C), new_c, nz_flags[a])
    return 2
end

op[0x6C] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    local ptr = bor(lo, lshift(hi, 8))
    local plo = bus_read(ptr)
    local phi = bus_read(bor(band(ptr, 0xFF00), band(ptr + 1, 0x00FF)))
    pc = bor(plo, lshift(phi, 8))
    return 5
end

op[0x6D] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local m = bus_read(bor(lo, lshift(hi, 8)))
    local c = band(status, FLAG_C)
    local sum = a + m + c
    local result = band(sum, 0xFF)
    local f = sum > 255 and FLAG_C or 0
    if band(bxor(a, result), bxor(m, result), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 4
end

op[0x6E] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = bor(lo, lshift(hi, 8))
    local m = bus_read(addr)
    local c = band(status, FLAG_C) ~= 0 and 0x80 or 0
    local new_c = band(m, 0x01) ~= 0 and FLAG_C or 0
    m = bor(rshift(m, 1), c)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 6
end

op[0x70] = function()
    local offset = signed_offset[read_code(pc)]
    pc = band(pc + 1, 0xFFFF)
    if band(status, FLAG_V) ~= 0 then
        local target = band(pc + offset, 0xFFFF)
        local extra = band(pc, 0xFF00) ~= band(target, 0xFF00) and 2 or 1
        pc = target
        return 2 + extra
    end
    return 2
end

op[0x71] = function()
    local base = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local addr = bor(lo, lshift(hi, 8))
    local final = band(addr + y, 0xFFFF)
    local extra = band(addr, 0xFF00) ~= band(final, 0xFF00) and 1 or 0
    local m = bus_read(final)
    local c = band(status, FLAG_C)
    local sum = a + m + c
    local result = band(sum, 0xFF)
    local f = sum > 255 and FLAG_C or 0
    if band(bxor(a, result), bxor(m, result), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 5 + extra
end

op[0x75] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local c = band(status, FLAG_C)
    local sum = a + m + c
    local result = band(sum, 0xFF)
    local f = sum > 255 and FLAG_C or 0
    if band(bxor(a, result), bxor(m, result), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 4
end

op[0x76] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local c = band(status, FLAG_C) ~= 0 and 0x80 or 0
    local new_c = band(m, 0x01) ~= 0 and FLAG_C or 0
    m = bor(rshift(m, 1), c)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 6
end

op[0x78] = function()
    status = bor(status, FLAG_I)
    return 2
end

op[0x79] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + y, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    local m = bus_read(addr)
    local c = band(status, FLAG_C)
    local sum = a + m + c
    local result = band(sum, 0xFF)
    local f = sum > 255 and FLAG_C or 0
    if band(bxor(a, result), bxor(m, result), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 4 + extra
end

op[0x7D] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + x, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    local m = bus_read(addr)
    local c = band(status, FLAG_C)
    local sum = a + m + c
    local result = band(sum, 0xFF)
    local f = sum > 255 and FLAG_C or 0
    if band(bxor(a, result), bxor(m, result), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 4 + extra
end

op[0x7E] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = band(bor(lo, lshift(hi, 8)) + x, 0xFFFF)
    local m = bus_read(addr)
    local c = band(status, FLAG_C) ~= 0 and 0x80 or 0
    local new_c = band(m, 0x01) ~= 0 and FLAG_C or 0
    m = bor(rshift(m, 1), c)
    bus_write(addr, m)
    status = bor(band(status, 0x3C), new_c, nz_flags[m])
    return 7
end

op[0x81] = function()
    local base = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    bus_write(bor(lo, lshift(hi, 8)), a)
    return 6
end

op[0x84] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    bus_write(addr, y)
    return 3
end

op[0x85] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    bus_write(addr, a)
    return 3
end

op[0x86] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    bus_write(addr, x)
    return 3
end

op[0x88] = function()
    y = band(y - 1, 0xFF)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[y])
    return 2
end

op[0x8A] = function()
    a = x
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 2
end

op[0x8C] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    bus_write(bor(lo, lshift(hi, 8)), y)
    return 4
end

op[0x8D] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    bus_write(bor(lo, lshift(hi, 8)), a)
    return 4
end

op[0x8E] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    bus_write(bor(lo, lshift(hi, 8)), x)
    return 4
end

op[0x90] = function()
    local offset = signed_offset[read_code(pc)]
    pc = band(pc + 1, 0xFFFF)
    if band(status, FLAG_C) == 0 then
        local target = band(pc + offset, 0xFFFF)
        local extra = band(pc, 0xFF00) ~= band(target, 0xFF00) and 2 or 1
        pc = target
        return 2 + extra
    end
    return 2
end

op[0x91] = function()
    local base = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local addr = band(bor(lo, lshift(hi, 8)) + y, 0xFFFF)
    bus_write(addr, a)
    return 6
end

op[0x94] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    bus_write(addr, y)
    return 4
end

op[0x95] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    bus_write(addr, a)
    return 4
end

op[0x96] = function()
    local addr = band(read_code(pc) + y, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    bus_write(addr, x)
    return 4
end

op[0x98] = function()
    a = y
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 2
end

op[0x99] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = band(bor(lo, lshift(hi, 8)) + y, 0xFFFF)
    bus_write(addr, a)
    return 5
end

op[0x9A] = function()
    sp = x
    return 2
end

op[0x9D] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = band(bor(lo, lshift(hi, 8)) + x, 0xFFFF)
    bus_write(addr, a)
    return 5
end

op[0xA0] = function()
    y = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[y])
    return 2
end

op[0xA1] = function()
    local base = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    a = bus_read(bor(lo, lshift(hi, 8)))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 6
end

op[0xA2] = function()
    x = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[x])
    return 2
end

op[0xA4] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    y = bus_read(addr)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[y])
    return 3
end

op[0xA5] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    a = bus_read(addr)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 3
end

op[0xA6] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    x = bus_read(addr)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[x])
    return 3
end

op[0xA8] = function()
    y = a
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[y])
    return 2
end

op[0xA9] = function()
    a = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 2
end

op[0xAA] = function()
    x = a
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[x])
    return 2
end

op[0xAC] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    y = bus_read(bor(lo, lshift(hi, 8)))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[y])
    return 4
end

op[0xAD] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    a = bus_read(bor(lo, lshift(hi, 8)))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4
end

op[0xAE] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    x = bus_read(bor(lo, lshift(hi, 8)))
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[x])
    return 4
end

op[0xB0] = function()
    local offset = signed_offset[read_code(pc)]
    pc = band(pc + 1, 0xFFFF)
    if band(status, FLAG_C) ~= 0 then
        local target = band(pc + offset, 0xFFFF)
        local extra = band(pc, 0xFF00) ~= band(target, 0xFF00) and 2 or 1
        pc = target
        return 2 + extra
    end
    return 2
end

op[0xB1] = function()
    local base = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local addr = bor(lo, lshift(hi, 8))
    local final = band(addr + y, 0xFFFF)
    local extra = band(addr, 0xFF00) ~= band(final, 0xFF00) and 1 or 0
    a = bus_read(final)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 5 + extra
end

op[0xB4] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    y = bus_read(addr)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[y])
    return 4
end

op[0xB5] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    a = bus_read(addr)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4
end

op[0xB6] = function()
    local addr = band(read_code(pc) + y, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    x = bus_read(addr)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[x])
    return 4
end

op[0xB8] = function()
    status = band(status, 0xBF)
    return 2
end

op[0xB9] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + y, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    a = bus_read(addr)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4 + extra
end

op[0xBA] = function()
    x = sp
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[x])
    return 2
end

op[0xBC] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + x, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    y = bus_read(addr)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[y])
    return 4 + extra
end

op[0xBD] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + x, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    a = bus_read(addr)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[a])
    return 4 + extra
end

op[0xBE] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + y, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    x = bus_read(addr)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[x])
    return 4 + extra
end

op[0xC0] = function()
    local m = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local result = band(y - m, 0xFF)
    local f = y >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 2
end

op[0xC1] = function()
    local base = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local m = bus_read(bor(lo, lshift(hi, 8)))
    local result = band(a - m, 0xFF)
    local f = a >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 6
end

op[0xC4] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local result = band(y - m, 0xFF)
    local f = y >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 3
end

op[0xC5] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local result = band(a - m, 0xFF)
    local f = a >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 3
end

op[0xC6] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = band(bus_read(addr) - 1, 0xFF)
    bus_write(addr, m)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[m])
    return 5
end

op[0xC8] = function()
    y = band(y + 1, 0xFF)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[y])
    return 2
end

op[0xC9] = function()
    local m = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local result = band(a - m, 0xFF)
    local f = a >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 2
end

op[0xCA] = function()
    x = band(x - 1, 0xFF)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[x])
    return 2
end

op[0xCC] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local m = bus_read(bor(lo, lshift(hi, 8)))
    local result = band(y - m, 0xFF)
    local f = y >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 4
end

op[0xCD] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local m = bus_read(bor(lo, lshift(hi, 8)))
    local result = band(a - m, 0xFF)
    local f = a >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 4
end

op[0xCE] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = bor(lo, lshift(hi, 8))
    local m = band(bus_read(addr) - 1, 0xFF)
    bus_write(addr, m)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[m])
    return 6
end

op[0xD0] = function()
    local offset = signed_offset[read_code(pc)]
    pc = band(pc + 1, 0xFFFF)
    if band(status, FLAG_Z) == 0 then
        local target = band(pc + offset, 0xFFFF)
        local extra = band(pc, 0xFF00) ~= band(target, 0xFF00) and 2 or 1
        pc = target
        return 2 + extra
    end
    return 2
end

op[0xD1] = function()
    local base = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local addr = bor(lo, lshift(hi, 8))
    local final = band(addr + y, 0xFFFF)
    local extra = band(addr, 0xFF00) ~= band(final, 0xFF00) and 1 or 0
    local m = bus_read(final)
    local result = band(a - m, 0xFF)
    local f = a >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 5 + extra
end

op[0xD5] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local result = band(a - m, 0xFF)
    local f = a >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 4
end

op[0xD6] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local m = band(bus_read(addr) - 1, 0xFF)
    bus_write(addr, m)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[m])
    return 6
end

op[0xD8] = function()
    status = band(status, 0xF7)
    return 2
end

op[0xD9] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + y, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    local m = bus_read(addr)
    local result = band(a - m, 0xFF)
    local f = a >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 4 + extra
end

op[0xDD] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + x, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    local m = bus_read(addr)
    local result = band(a - m, 0xFF)
    local f = a >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 4 + extra
end

op[0xDE] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = band(bor(lo, lshift(hi, 8)) + x, 0xFFFF)
    local m = band(bus_read(addr) - 1, 0xFF)
    bus_write(addr, m)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[m])
    return 7
end

op[0xE0] = function()
    local m = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local result = band(x - m, 0xFF)
    local f = x >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 2
end

op[0xE1] = function()
    local base = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local m = bus_read(bor(lo, lshift(hi, 8)))
    local c = band(status, FLAG_C) ~= 0 and 0 or 1
    local diff = a - m - c
    local result = band(diff, 0xFF)
    local f = diff >= 0 and FLAG_C or 0
    if band(bxor(a, result), bxor(a, m), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 6
end

op[0xE4] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local result = band(x - m, 0xFF)
    local f = x >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 3
end

op[0xE5] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local c = band(status, FLAG_C) ~= 0 and 0 or 1
    local diff = a - m - c
    local result = band(diff, 0xFF)
    local f = diff >= 0 and FLAG_C or 0
    if band(bxor(a, result), bxor(a, m), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 3
end

op[0xE6] = function()
    local addr = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local m = band(bus_read(addr) + 1, 0xFF)
    bus_write(addr, m)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[m])
    return 5
end

op[0xE8] = function()
    x = band(x + 1, 0xFF)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[x])
    return 2
end

op[0xE9] = function()
    local m = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local c = band(status, FLAG_C) ~= 0 and 0 or 1
    local diff = a - m - c
    local result = band(diff, 0xFF)
    local f = diff >= 0 and FLAG_C or 0
    if band(bxor(a, result), bxor(a, m), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 2
end

op[0xEA] = function()
    return 2
end

op[0xEC] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local m = bus_read(bor(lo, lshift(hi, 8)))
    local result = band(x - m, 0xFF)
    local f = x >= m and FLAG_C or 0
    status = bor(band(status, 0x0C), f, nz_flags[result])
    return 4
end

op[0xED] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local m = bus_read(bor(lo, lshift(hi, 8)))
    local c = band(status, FLAG_C) ~= 0 and 0 or 1
    local diff = a - m - c
    local result = band(diff, 0xFF)
    local f = diff >= 0 and FLAG_C or 0
    if band(bxor(a, result), bxor(a, m), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 4
end

op[0xEE] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = bor(lo, lshift(hi, 8))
    local m = band(bus_read(addr) + 1, 0xFF)
    bus_write(addr, m)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[m])
    return 6
end

op[0xF0] = function()
    local offset = signed_offset[read_code(pc)]
    pc = band(pc + 1, 0xFFFF)
    if band(status, FLAG_Z) ~= 0 then
        local target = band(pc + offset, 0xFFFF)
        local extra = band(pc, 0xFF00) ~= band(target, 0xFF00) and 2 or 1
        pc = target
        return 2 + extra
    end
    return 2
end

op[0xF1] = function()
    local base = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    local lo = bus_read(base)
    local hi = bus_read(band(base + 1, 0xFF))
    local addr = bor(lo, lshift(hi, 8))
    local final = band(addr + y, 0xFFFF)
    local extra = band(addr, 0xFF00) ~= band(final, 0xFF00) and 1 or 0
    local m = bus_read(final)
    local c = band(status, FLAG_C) ~= 0 and 0 or 1
    local diff = a - m - c
    local result = band(diff, 0xFF)
    local f = diff >= 0 and FLAG_C or 0
    if band(bxor(a, result), bxor(a, m), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 5 + extra
end

op[0xF5] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local m = bus_read(addr)
    local c = band(status, FLAG_C) ~= 0 and 0 or 1
    local diff = a - m - c
    local result = band(diff, 0xFF)
    local f = diff >= 0 and FLAG_C or 0
    if band(bxor(a, result), bxor(a, m), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 4
end

op[0xF6] = function()
    local addr = band(read_code(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
    local m = band(bus_read(addr) + 1, 0xFF)
    bus_write(addr, m)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[m])
    return 6
end

op[0xF8] = function()
    status = bor(status, FLAG_D)
    return 2
end

op[0xF9] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + y, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    local m = bus_read(addr)
    local c = band(status, FLAG_C) ~= 0 and 0 or 1
    local diff = a - m - c
    local result = band(diff, 0xFF)
    local f = diff >= 0 and FLAG_C or 0
    if band(bxor(a, result), bxor(a, m), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 4 + extra
end

op[0xFD] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local base = bor(lo, lshift(hi, 8))
    local addr = band(base + x, 0xFFFF)
    local extra = band(base, 0xFF00) ~= band(addr, 0xFF00) and 1 or 0
    local m = bus_read(addr)
    local c = band(status, FLAG_C) ~= 0 and 0 or 1
    local diff = a - m - c
    local result = band(diff, 0xFF)
    local f = diff >= 0 and FLAG_C or 0
    if band(bxor(a, result), bxor(a, m), 0x80) ~= 0 then f = bor(f, FLAG_V) end
    status = bor(band(status, 0x0C), f, nz_flags[result])
    a = result
    return 4 + extra
end

op[0xFE] = function()
    local lo = read_code(pc)
    local hi = read_code(pc + 1)
    pc = band(pc + 2, 0xFFFF)
    local addr = band(bor(lo, lshift(hi, 8)) + x, 0xFFFF)
    local m = band(bus_read(addr) + 1, 0xFF)
    bus_write(addr, m)
    status = bor(band(status, FLAG_NZ_CLEAR), nz_flags[m])
    return 7
end

function cpu.init(b)
    bus = b
    bus_read = b.read
    bus_write = b.write
    bus_get_dma_cycles = b.get_dma_cycles
    prg_rom = structs.prg_rom
    prg_mask = structs.prg_mask
    a, x, y = 0, 0, 0
    sp = 0xFD
    status = bor(FLAG_U, FLAG_I)
    pc = bor(bus_read(0xFFFC), lshift(bus_read(0xFFFD), 8))
end

function cpu.reset()
    sp = band(sp - 3, 0xFF)
    status = bor(status, FLAG_I)
    pc = bor(bus_read(0xFFFC), lshift(bus_read(0xFFFD), 8))
end

function cpu.nmi()
    push(rshift(pc, 8))
    push(band(pc, 0xFF))
    push(band(status, bxor(0xFF, FLAG_B)))
    status = bor(status, FLAG_I)
    pc = bor(bus_read(0xFFFA), lshift(bus_read(0xFFFB), 8))
end

function cpu.irq()
    if band(status, FLAG_I) == 0 then
        push(rshift(pc, 8))
        push(band(pc, 0xFF))
        push(band(status, bxor(0xFF, FLAG_B)))
        status = bor(status, FLAG_I)
        pc = bor(bus_read(0xFFFE), lshift(bus_read(0xFFFF), 8))
    end
end

function cpu.step()
    local opcode = read_code(pc)
    pc = band(pc + 1, 0xFFFF)
    return op[opcode]() + bus_get_dma_cycles()
end

function cpu.get_pc()
    return pc
end

return cpu
