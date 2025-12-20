local bit = require("bit")
local band, bor, rshift = bit.band, bit.bor, bit.rshift
local byte = string.byte
local structs = require("ffi_structs")
local ffi_copy, ffi_fill = structs.copy, structs.fill

local mapper = {}

local prg_rom, chr_rom
local prg_size, chr_size
local prg_mask, chr_mask
local mirroring

function mapper.load(data)
    local h1, h2, h3, h4 = byte(data, 1, 4)
    if h1 ~= 0x4E or h2 ~= 0x45 or h3 ~= 0x53 or h4 ~= 0x1A then
        error("Invalid iNES header")
    end

    local prg_banks = byte(data, 5)
    local chr_banks = byte(data, 6)
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

    prg_size = prg_banks * 16384
    prg_mask = prg_banks == 1 and 0x3FFF or 0x7FFF
    chr_size = chr_banks * 8192
    if chr_size == 0 then chr_size = 8192 end

    prg_rom, chr_rom = structs.alloc_rom(prg_size, chr_size)
    chr_mask = chr_size - 1

    structs.set_prg_mask(prg_mask)

    ffi_copy(prg_rom, data:sub(offset, offset + prg_size - 1), prg_size)

    if chr_banks > 0 then
        local chr_offset = offset + prg_size
        ffi_copy(chr_rom, data:sub(chr_offset, chr_offset + chr_size - 1), chr_size)
    else
        ffi_fill(chr_rom, chr_size, 0)
    end

    return {
        prg_banks = prg_banks,
        chr_banks = chr_banks,
        mirroring = mirroring
    }
end

function mapper.prg_read(addr)
    return prg_rom[band(addr, prg_mask)]
end

function mapper.prg_write(addr, value) end

function mapper.chr_read(addr)
    return chr_rom[band(addr, chr_mask)]
end

function mapper.chr_write(addr, value)
    chr_rom[band(addr, chr_mask)] = value
end

function mapper.get_chr_rom()
    return chr_rom, chr_mask
end

function mapper.get_mirroring()
    return mirroring
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
