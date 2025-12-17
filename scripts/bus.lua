local bit = bit or bit32
local band, bor, lshift = bit.band, bit.bor, bit.lshift

local bus = {}

local ram = {}
for i = 0, 0x07FF do ram[i] = 0 end

local mapper
local ppu
local input

function bus.connect(m, p, i)
    mapper = m
    ppu = p
    input = i
end

function bus.read(addr)
    addr = band(addr, 0xFFFF)

    if addr < 0x2000 then
        return ram[band(addr, 0x07FF)]
    elseif addr < 0x4000 then
        return ppu.register_read(band(addr, 7))
    elseif addr == 0x4016 then
        return input.read(0)
    elseif addr == 0x4017 then
        return input.read(1)
    elseif addr < 0x4020 then
        return 0
    else
        return mapper.prg_read(addr)
    end
end

function bus.write(addr, value)
    addr = band(addr, 0xFFFF)
    value = band(value, 0xFF)

    if addr < 0x2000 then
        ram[band(addr, 0x07FF)] = value
    elseif addr < 0x4000 then
        ppu.register_write(band(addr, 7), value)
    elseif addr == 0x4014 then
        bus.oam_dma(value)
    elseif addr == 0x4016 then
        input.strobe(value)
    elseif addr < 0x4020 then
        return
    else
        mapper.prg_write(addr, value)
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

local dma_cycles = 0

function bus.oam_dma(page)
    local base = lshift(page, 8)
    local oam_addr = ppu.get_oam_addr()
    for i = 0, 255 do
        local data = bus.read(base + i)
        ppu.oam_write(band(oam_addr + i, 0xFF), data)
    end
    dma_cycles = 513
end

function bus.get_dma_cycles()
    local c = dma_cycles
    dma_cycles = 0
    return c
end

return bus
