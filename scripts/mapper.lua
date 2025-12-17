local bit = bit or bit32
local band, bor, rshift, lshift = bit.band, bit.bor, bit.rshift, bit.lshift
local byte = string.byte

local mapper = {}

local prg_rom
local chr_rom
local prg_banks
local chr_banks
local mirroring

function mapper.load(data)
    local h1, h2, h3, h4 = byte(data, 1, 4)
    if h1 ~= 0x4E or h2 ~= 0x45 or h3 ~= 0x53 or h4 ~= 0x1A then
        error("Invalid iNES header")
    end

    prg_banks = byte(data, 5)
    chr_banks = byte(data, 6)
    local flags6 = byte(data, 7)
    local flags7 = byte(data, 8)

    local mapper_id = bor(rshift(band(flags6, 0xF0), 4), band(flags7, 0xF0))
    if mapper_id ~= 0 then
        error("Only NROM (mapper 0) supported")
    end

    mirroring = band(flags6, 1)
    local has_trainer = band(flags6, 4) ~= 0

    local offset = 17
    if has_trainer then offset = offset + 512 end

    local prg_size = prg_banks * 16384
    prg_rom = {}
    for i = 0, prg_size - 1 do
        prg_rom[i] = byte(data, offset + i)
    end
    offset = offset + prg_size

    local chr_size = chr_banks * 8192
    chr_rom = {}
    if chr_size == 0 then
        chr_size = 8192
        for i = 0, chr_size - 1 do
            chr_rom[i] = 0
        end
    else
        for i = 0, chr_size - 1 do
            chr_rom[i] = byte(data, offset + i)
        end
    end

    return {
        prg_banks = prg_banks,
        chr_banks = chr_banks,
        mirroring = mirroring
    }
end

function mapper.prg_read(addr)
    local offset
    if prg_banks == 1 then
        offset = band(addr, 0x3FFF)
    else
        offset = band(addr, 0x7FFF)
    end
    return prg_rom[offset] or 0
end

function mapper.prg_write(addr, value)
end

function mapper.chr_read(addr)
    return chr_rom[band(addr, 0x1FFF)] or 0
end

function mapper.chr_write(addr, value)
    if chr_banks == 0 then
        chr_rom[band(addr, 0x1FFF)] = value
    end
end

function mapper.mirror_nametable(addr)
    local offset = band(addr, 0x0FFF)
    if mirroring == 0 then
        return band(offset, 0x07FF)
    else
        if offset < 0x0800 then
            return band(offset, 0x03FF)
        else
            return 0x0400 + band(offset, 0x03FF)
        end
    end
end

return mapper
