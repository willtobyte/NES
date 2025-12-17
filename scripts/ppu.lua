local bit = bit or bit32
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
local char, concat = string.char, table.concat

local ppu = {}

local mapper

local vram = {}
local palette = {}
local oam = {}
local secondary_oam = {}

for i = 0, 2047 do vram[i] = 0 end
for i = 0, 31 do palette[i] = 0 end
for i = 0, 255 do oam[i] = 0 end
for i = 0, 31 do secondary_oam[i] = 0 end

local ctrl = 0
local mask = 0
local status = 0
local oam_addr = 0
local data_buffer = 0

local v = 0
local t = 0
local fine_x = 0
local w = 0

local scanline = 0
local cycle = 0
local frame = 0

local nmi_occurred = false
local nmi_output = false
local sprite_zero_hit = false
local sprite_overflow = false

local sprite_count = 0
local sprite_patterns = {}
local sprite_positions = {}
local sprite_priorities = {}
local sprite_indexes = {}

for i = 0, 7 do
    sprite_patterns[i] = 0
    sprite_positions[i] = 0
    sprite_priorities[i] = 0
    sprite_indexes[i] = 0
end

local nes_palette = {
    [0x00] = {0x62, 0x62, 0x62}, [0x01] = {0x00, 0x1F, 0xB2}, [0x02] = {0x24, 0x04, 0xC8}, [0x03] = {0x52, 0x00, 0xB2},
    [0x04] = {0x73, 0x00, 0x76}, [0x05] = {0x80, 0x00, 0x24}, [0x06] = {0x73, 0x0B, 0x00}, [0x07] = {0x52, 0x28, 0x00},
    [0x08] = {0x24, 0x44, 0x00}, [0x09] = {0x00, 0x57, 0x00}, [0x0A] = {0x00, 0x5C, 0x00}, [0x0B] = {0x00, 0x53, 0x24},
    [0x0C] = {0x00, 0x3C, 0x76}, [0x0D] = {0x00, 0x00, 0x00}, [0x0E] = {0x00, 0x00, 0x00}, [0x0F] = {0x00, 0x00, 0x00},
    [0x10] = {0xAB, 0xAB, 0xAB}, [0x11] = {0x0D, 0x57, 0xFF}, [0x12] = {0x4B, 0x30, 0xFF}, [0x13] = {0x8A, 0x13, 0xFF},
    [0x14] = {0xBC, 0x08, 0xD6}, [0x15] = {0xD2, 0x12, 0x69}, [0x16] = {0xC7, 0x2E, 0x00}, [0x17] = {0x9D, 0x54, 0x00},
    [0x18] = {0x60, 0x7B, 0x00}, [0x19] = {0x20, 0x98, 0x00}, [0x1A] = {0x00, 0xA3, 0x00}, [0x1B] = {0x00, 0x99, 0x42},
    [0x1C] = {0x00, 0x7D, 0xB4}, [0x1D] = {0x00, 0x00, 0x00}, [0x1E] = {0x00, 0x00, 0x00}, [0x1F] = {0x00, 0x00, 0x00},
    [0x20] = {0xFF, 0xFF, 0xFF}, [0x21] = {0x53, 0xAE, 0xFF}, [0x22] = {0x90, 0x85, 0xFF}, [0x23] = {0xD3, 0x65, 0xFF},
    [0x24] = {0xFF, 0x57, 0xFF}, [0x25] = {0xFF, 0x5D, 0xCF}, [0x26] = {0xFF, 0x77, 0x57}, [0x27] = {0xFA, 0x9E, 0x00},
    [0x28] = {0xBD, 0xC7, 0x00}, [0x29] = {0x7A, 0xE7, 0x00}, [0x2A] = {0x43, 0xF6, 0x11}, [0x2B] = {0x26, 0xEF, 0x7E},
    [0x2C] = {0x2C, 0xD5, 0xF6}, [0x2D] = {0x4E, 0x4E, 0x4E}, [0x2E] = {0x00, 0x00, 0x00}, [0x2F] = {0x00, 0x00, 0x00},
    [0x30] = {0xFF, 0xFF, 0xFF}, [0x31] = {0xB6, 0xE1, 0xFF}, [0x32] = {0xCE, 0xD1, 0xFF}, [0x33] = {0xE9, 0xC3, 0xFF},
    [0x34] = {0xFF, 0xBC, 0xFF}, [0x35] = {0xFF, 0xBD, 0xF4}, [0x36] = {0xFF, 0xC6, 0xC3}, [0x37] = {0xFF, 0xD5, 0x9A},
    [0x38] = {0xE9, 0xE6, 0x81}, [0x39] = {0xCE, 0xF4, 0x81}, [0x3A] = {0xB6, 0xFB, 0x9A}, [0x3B] = {0xA9, 0xFA, 0xC3},
    [0x3C] = {0xA9, 0xF0, 0xF4}, [0x3D] = {0xB8, 0xB8, 0xB8}, [0x3E] = {0x00, 0x00, 0x00}, [0x3F] = {0x00, 0x00, 0x00}
}

local row_pixels = {}
local rows = {}
for i = 1, 256 do row_pixels[i] = "\0\0\0\255" end
for i = 1, 240 do rows[i] = "" end

function ppu.init(m)
    mapper = m
    ctrl = 0
    mask = 0
    status = 0
    oam_addr = 0
    data_buffer = 0
    v = 0
    t = 0
    fine_x = 0
    w = 0
    scanline = 0
    cycle = 0
    frame = 0
    nmi_occurred = false
    nmi_output = false
    sprite_zero_hit = false
    sprite_overflow = false
end

local function ppu_read(addr)
    addr = band(addr, 0x3FFF)
    if addr < 0x2000 then
        return mapper.chr_read(addr)
    elseif addr < 0x3F00 then
        local mirrored = mapper.mirror_nametable(addr)
        return vram[mirrored]
    else
        local pal_addr = band(addr, 0x1F)
        if pal_addr == 0x10 or pal_addr == 0x14 or pal_addr == 0x18 or pal_addr == 0x1C then
            pal_addr = pal_addr - 0x10
        end
        return palette[pal_addr]
    end
end

local function ppu_write(addr, value)
    addr = band(addr, 0x3FFF)
    if addr < 0x2000 then
        mapper.chr_write(addr, value)
    elseif addr < 0x3F00 then
        local mirrored = mapper.mirror_nametable(addr)
        vram[mirrored] = value
    else
        local pal_addr = band(addr, 0x1F)
        if pal_addr == 0x10 or pal_addr == 0x14 or pal_addr == 0x18 or pal_addr == 0x1C then
            pal_addr = pal_addr - 0x10
        end
        palette[pal_addr] = value
    end
end

function ppu.register_read(reg)
    local result = 0
    if reg == 2 then
        result = band(status, 0xE0)
        status = band(status, 0x7F)
        nmi_occurred = false
        w = 0
    elseif reg == 4 then
        result = oam[oam_addr]
    elseif reg == 7 then
        result = data_buffer
        data_buffer = ppu_read(v)
        if v >= 0x3F00 then
            result = data_buffer
            data_buffer = ppu_read(v - 0x1000)
        end
        local inc = band(ctrl, 0x04) ~= 0 and 32 or 1
        v = band(v + inc, 0x7FFF)
    end
    return result
end

function ppu.register_write(reg, value)
    if reg == 0 then
        ctrl = value
        nmi_output = band(ctrl, 0x80) ~= 0
        t = bor(band(t, 0x73FF), lshift(band(value, 0x03), 10))
    elseif reg == 1 then
        mask = value
    elseif reg == 3 then
        oam_addr = value
    elseif reg == 4 then
        oam[oam_addr] = value
        oam_addr = band(oam_addr + 1, 0xFF)
    elseif reg == 5 then
        if w == 0 then
            t = bor(band(t, 0x7FE0), rshift(value, 3))
            fine_x = band(value, 0x07)
            w = 1
        else
            t = bor(band(t, 0x0C1F), lshift(band(value, 0x07), 12), lshift(band(value, 0xF8), 2))
            w = 0
        end
    elseif reg == 6 then
        if w == 0 then
            t = bor(band(t, 0x00FF), lshift(band(value, 0x3F), 8))
            w = 1
        else
            t = bor(band(t, 0x7F00), value)
            v = t
            w = 0
        end
    elseif reg == 7 then
        ppu_write(v, value)
        local inc = band(ctrl, 0x04) ~= 0 and 32 or 1
        v = band(v + inc, 0x7FFF)
    end
end

function ppu.get_oam_addr()
    return oam_addr
end

function ppu.oam_write(addr, value)
    oam[addr] = value
end

local function increment_x()
    if band(v, 0x001F) == 31 then
        v = band(v, 0x7FE0)
        v = bxor(v, 0x0400)
    else
        v = v + 1
    end
end

local function increment_y()
    if band(v, 0x7000) ~= 0x7000 then
        v = v + 0x1000
    else
        v = band(v, 0x0FFF)
        local coarse_y = band(rshift(v, 5), 0x1F)
        if coarse_y == 29 then
            coarse_y = 0
            v = bxor(v, 0x0800)
        elseif coarse_y == 31 then
            coarse_y = 0
        else
            coarse_y = coarse_y + 1
        end
        v = bor(band(v, 0x7C1F), lshift(coarse_y, 5))
    end
end

local function copy_x()
    v = bor(band(v, 0x7BE0), band(t, 0x041F))
end

local function copy_y()
    v = bor(band(v, 0x041F), band(t, 0x7BE0))
end

local function rendering_enabled()
    return band(mask, 0x18) ~= 0
end

local function get_background_pixel()
    if band(mask, 0x08) == 0 then return 0 end
    if cycle <= 8 and band(mask, 0x02) == 0 then return 0 end

    local tile_x = band(v, 0x001F)
    local tile_y = band(rshift(v, 5), 0x001F)
    local fine_y = band(rshift(v, 12), 0x07)
    local nt_select = band(rshift(v, 10), 0x03)

    local nt_addr = 0x2000 + lshift(nt_select, 10) + tile_y * 32 + tile_x
    local tile = ppu_read(nt_addr)

    local pattern_base = band(ctrl, 0x10) ~= 0 and 0x1000 or 0
    local pattern_addr = pattern_base + tile * 16 + fine_y
    local low = ppu_read(pattern_addr)
    local high = ppu_read(pattern_addr + 8)

    local pixel_x = 7 - band(fine_x + (cycle - 1), 7)
    local pixel = bor(band(rshift(low, pixel_x), 1), lshift(band(rshift(high, pixel_x), 1), 1))

    if pixel == 0 then return 0 end

    local attr_addr = 0x23C0 + lshift(nt_select, 10) + lshift(rshift(tile_y, 2), 3) + rshift(tile_x, 2)
    local attr = ppu_read(attr_addr)
    local shift = bor(band(tile_x, 2), lshift(band(tile_y, 2), 1))
    local pal_idx = band(rshift(attr, shift), 3)

    return palette[pal_idx * 4 + pixel]
end

local function evaluate_sprites()
    sprite_count = 0
    local sprite_height = band(ctrl, 0x20) ~= 0 and 16 or 8

    for i = 0, 63 do
        local y = oam[i * 4]
        local row = scanline - y
        if row >= 0 and row < sprite_height then
            if sprite_count < 8 then
                secondary_oam[sprite_count * 4] = y
                secondary_oam[sprite_count * 4 + 1] = oam[i * 4 + 1]
                secondary_oam[sprite_count * 4 + 2] = oam[i * 4 + 2]
                secondary_oam[sprite_count * 4 + 3] = oam[i * 4 + 3]
                sprite_indexes[sprite_count] = i
                sprite_count = sprite_count + 1
            else
                sprite_overflow = true
                break
            end
        end
    end
end

local function fetch_sprites()
    local sprite_height = band(ctrl, 0x20) ~= 0 and 16 or 8

    for i = 0, sprite_count - 1 do
        local y = secondary_oam[i * 4]
        local tile = secondary_oam[i * 4 + 1]
        local attr = secondary_oam[i * 4 + 2]
        local x = secondary_oam[i * 4 + 3]

        local row = scanline - y
        if band(attr, 0x80) ~= 0 then
            row = sprite_height - 1 - row
        end

        local pattern_base
        if sprite_height == 8 then
            pattern_base = band(ctrl, 0x08) ~= 0 and 0x1000 or 0
        else
            pattern_base = band(tile, 1) ~= 0 and 0x1000 or 0
            tile = band(tile, 0xFE)
            if row >= 8 then
                tile = tile + 1
                row = row - 8
            end
        end

        local addr = pattern_base + tile * 16 + row
        local low = ppu_read(addr)
        local high = ppu_read(addr + 8)

        if band(attr, 0x40) ~= 0 then
            low = bor(band(low, 0xF0) / 16, band(low, 0x0F) * 16)
            low = bor(band(low, 0xCC) / 4, band(low, 0x33) * 4)
            low = bor(band(low, 0xAA) / 2, band(low, 0x55) * 2)
            high = bor(band(high, 0xF0) / 16, band(high, 0x0F) * 16)
            high = bor(band(high, 0xCC) / 4, band(high, 0x33) * 4)
            high = bor(band(high, 0xAA) / 2, band(high, 0x55) * 2)
        end

        sprite_patterns[i] = bor(low, lshift(high, 8))
        sprite_positions[i] = x
        sprite_priorities[i] = band(attr, 0x20) ~= 0
    end
end

local function get_sprite_pixel()
    if band(mask, 0x10) == 0 then return 0, 0, false end
    if cycle <= 8 and band(mask, 0x04) == 0 then return 0, 0, false end

    local x = cycle - 1
    for i = 0, sprite_count - 1 do
        local offset = x - sprite_positions[i]
        if offset >= 0 and offset < 8 then
            local pattern = sprite_patterns[i]
            local pixel = bor(band(rshift(pattern, 7 - offset), 1), lshift(band(rshift(pattern, 15 - offset), 1), 1))
            if pixel ~= 0 then
                local attr = secondary_oam[i * 4 + 2]
                local pal_idx = band(attr, 3) + 4
                local color = palette[pal_idx * 4 + pixel]
                local priority = not sprite_priorities[i]
                local is_sprite_zero = sprite_indexes[i] == 0
                return color, priority, is_sprite_zero
            end
        end
    end

    return 0, false, false
end

local function render_pixel()
    local x = cycle
    local bg_color = get_background_pixel()
    local bg_opaque = bg_color ~= 0

    local sp_color, sp_priority, sp_zero = get_sprite_pixel()
    local sp_opaque = sp_color ~= 0

    if sp_zero and bg_opaque and sp_opaque and x < 256 and cycle > 1 then
        if not sprite_zero_hit then
            sprite_zero_hit = true
            status = bor(status, 0x40)
        end
    end

    local color
    if not bg_opaque and not sp_opaque then
        color = palette[0]
    elseif bg_opaque and not sp_opaque then
        color = bg_color
    elseif not bg_opaque and sp_opaque then
        color = sp_color
    elseif sp_priority then
        color = sp_color
    else
        color = bg_color
    end

    local rgb = nes_palette[band(color, 0x3F)]
    if rgb then
        row_pixels[x] = char(rgb[1], rgb[2], rgb[3], 255)
    else
        row_pixels[x] = "\0\0\0\255"
    end
end

function ppu.step()
    if rendering_enabled() then
        if scanline < 240 then
            if cycle >= 1 and cycle <= 256 then
                render_pixel()
            end
            if cycle == 256 then
                increment_y()
            end
            if cycle == 257 then
                copy_x()
                evaluate_sprites()
                fetch_sprites()
            end
            if cycle >= 321 and cycle <= 336 then
                if band(cycle, 7) == 1 then
                    increment_x()
                end
            end
            if cycle >= 1 and cycle <= 256 then
                if band(cycle, 7) == 0 then
                    increment_x()
                end
            end
        end

        if scanline == 261 then
            if cycle >= 280 and cycle <= 304 then
                copy_y()
            end
        end
    end

    if scanline == 241 and cycle == 1 then
        status = bor(status, 0x80)
        nmi_occurred = true
    end

    if scanline == 261 and cycle == 1 then
        status = band(status, 0x1F)
        nmi_occurred = false
        sprite_zero_hit = false
        sprite_overflow = false
    end

    cycle = cycle + 1
    if cycle > 340 then
        if scanline < 240 then
            rows[scanline + 1] = concat(row_pixels)
        end
        cycle = 0
        scanline = scanline + 1
        if scanline > 261 then
            scanline = 0
            frame = frame + 1
        end
    end
end

function ppu.nmi_pending()
    return nmi_occurred and nmi_output
end

function ppu.clear_nmi()
    nmi_occurred = false
end

function ppu.get_framebuffer()
    return concat(rows)
end

return ppu
