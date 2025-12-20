local bit = require("bit")
local band, bor, lshift = bit.band, bit.bor, bit.lshift
local structs = require("ffi_structs")

local bus = {}

local ram = structs.ram
local oam = structs.oam
local mapper, ppu, input
local mapper_prg_read, mapper_prg_write
local ppu_register_read, ppu_register_write, ppu_get_oam_addr
local input_read, input_strobe
local dma_cycles = 0

function bus.connect(m, p, i)
    mapper = m
    ppu = p
    input = i
    mapper_prg_read = m.prg_read
    mapper_prg_write = m.prg_write
    ppu_register_read = p.register_read
    ppu_register_write = p.register_write
    ppu_get_oam_addr = p.get_oam_addr
    input_read = i.read
    input_strobe = i.strobe
end

function bus.read(addr)
    if addr < 0x2000 then
        return ram[band(addr, 0x07FF)]
    elseif addr < 0x4000 then
        return ppu_register_read(band(addr, 7))
    elseif addr == 0x4016 then
        return input_read(0)
    elseif addr == 0x4017 then
        return input_read(1)
    elseif addr < 0x4020 then
        return 0
    else
        return mapper_prg_read(addr)
    end
end

function bus.write(addr, value)
    value = band(value, 0xFF)
    if addr < 0x2000 then
        ram[band(addr, 0x07FF)] = value
    elseif addr < 0x4000 then
        ppu_register_write(band(addr, 7), value)
    elseif addr == 0x4014 then
        bus.oam_dma(value)
    elseif addr == 0x4016 then
        input_strobe(value)
    elseif addr >= 0x4020 then
        mapper_prg_write(addr, value)
    end
end

function bus.read16(addr)
    local lo = bus.read(addr)
    local hi = bus.read(addr + 1)
    return bor(lo, lshift(hi, 8))
end

function bus.read16_wrap(addr)
    local lo = bus.read(addr)
    local hi_addr = band(addr, 0xFF00) + band(addr + 1, 0x00FF)
    local hi = bus.read(hi_addr)
    return bor(lo, lshift(hi, 8))
end

function bus.oam_dma(page)
    local base = lshift(page, 8)
    local oam_addr = ppu_get_oam_addr()
    for i = 0, 255 do
        oam[band(oam_addr + i, 0xFF)] = bus.read(base + i)
    end
    dma_cycles = 513
end

function bus.read_code(addr)
    return mapper_prg_read(addr)
end

function bus.get_dma_cycles()
    local c = dma_cycles
    dma_cycles = 0
    return c
end

return bus
