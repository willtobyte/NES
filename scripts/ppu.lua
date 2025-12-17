local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
local char, concat = string.char, table.concat

local ppu = {}

local mapper
local vram = {}
local palette = {}
local oam = {}

for i = 0, 2047 do vram[i] = 0 end
for i = 0, 31 do palette[i] = 0 end
for i = 0, 255 do oam[i] = 0 end

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
local frame_ready = false

local nmi_occurred = false
local nmi_output = false

local nes_rgb = {}
local raw_palette = {
    0x626262, 0x001FB2, 0x2404C8, 0x5200B2, 0x730076, 0x800024, 0x730B00, 0x522800,
    0x244400, 0x005700, 0x005C00, 0x005324, 0x003C76, 0x000000, 0x000000, 0x000000,
    0xABABAB, 0x0D57FF, 0x4B30FF, 0x8A13FF, 0xBC08D6, 0xD21269, 0xC72E00, 0x9D5400,
    0x607B00, 0x209800, 0x00A300, 0x009942, 0x007DB4, 0x000000, 0x000000, 0x000000,
    0xFFFFFF, 0x53AEFF, 0x9085FF, 0xD365FF, 0xFF57FF, 0xFF5DCF, 0xFF7757, 0xFA9E00,
    0xBDC700, 0x7AE700, 0x43F611, 0x26EF7E, 0x2CD5F6, 0x4E4E4E, 0x000000, 0x000000,
    0xFFFFFF, 0xB6E1FF, 0xCED1FF, 0xE9C3FF, 0xFFBCFF, 0xFFBDF4, 0xFFC6C3, 0xFFD59A,
    0xE9E681, 0xCEF481, 0xB6FB9A, 0xA9FAC3, 0xA9F0F4, 0xB8B8B8, 0x000000, 0x000000
}
for i = 0, 63 do
    local c = raw_palette[i + 1]
    nes_rgb[i] = char(band(rshift(c, 16), 0xFF), band(rshift(c, 8), 0xFF), band(c, 0xFF), 255)
end
local black = char(0, 0, 0, 255)

local row_pixels = {}
local rows = {}
for i = 1, 256 do row_pixels[i] = black end
for i = 1, 240 do rows[i] = "" end

function ppu.init(m)
    mapper = m
    ctrl, mask, status, oam_addr, data_buffer = 0, 0, 0, 0, 0
    v, t, fine_x, w = 0, 0, 0, 0
    scanline, frame_ready = 0, false
    nmi_occurred, nmi_output = false, false
end

local function ppu_read(addr)
    addr = band(addr, 0x3FFF)
    if addr < 0x2000 then
        return mapper.chr_read(addr)
    elseif addr < 0x3F00 then
        return vram[mapper.mirror_nametable(addr)]
    else
        local pa = band(addr, 0x1F)
        if pa == 0x10 or pa == 0x14 or pa == 0x18 or pa == 0x1C then pa = pa - 0x10 end
        return palette[pa]
    end
end

local function ppu_write(addr, val)
    addr = band(addr, 0x3FFF)
    if addr < 0x2000 then
        mapper.chr_write(addr, val)
    elseif addr < 0x3F00 then
        vram[mapper.mirror_nametable(addr)] = val
    else
        local pa = band(addr, 0x1F)
        if pa == 0x10 or pa == 0x14 or pa == 0x18 or pa == 0x1C then pa = pa - 0x10 end
        palette[pa] = val
    end
end

function ppu.register_read(reg)
    if reg == 2 then
        local r = band(status, 0xE0)
        status = band(status, 0x7F)
        nmi_occurred = false
        w = 0
        return r
    elseif reg == 4 then
        return oam[oam_addr]
    elseif reg == 7 then
        local r = data_buffer
        data_buffer = ppu_read(v)
        if v >= 0x3F00 then r = data_buffer; data_buffer = ppu_read(v - 0x1000) end
        v = band(v + (band(ctrl, 0x04) ~= 0 and 32 or 1), 0x7FFF)
        return r
    end
    return 0
end

function ppu.register_write(reg, val)
    if reg == 0 then
        ctrl = val
        nmi_output = band(ctrl, 0x80) ~= 0
        t = bor(band(t, 0x73FF), lshift(band(val, 0x03), 10))
    elseif reg == 1 then
        mask = val
    elseif reg == 3 then
        oam_addr = val
    elseif reg == 4 then
        oam[oam_addr] = val
        oam_addr = band(oam_addr + 1, 0xFF)
    elseif reg == 5 then
        if w == 0 then
            t = bor(band(t, 0x7FE0), rshift(val, 3))
            fine_x = band(val, 0x07)
            w = 1
        else
            t = bor(band(t, 0x0C1F), lshift(band(val, 0x07), 12), lshift(band(val, 0xF8), 2))
            w = 0
        end
    elseif reg == 6 then
        if w == 0 then
            t = bor(band(t, 0x00FF), lshift(band(val, 0x3F), 8))
            w = 1
        else
            t = bor(band(t, 0x7F00), val)
            v = t
            w = 0
        end
    elseif reg == 7 then
        ppu_write(v, val)
        v = band(v + (band(ctrl, 0x04) ~= 0 and 32 or 1), 0x7FFF)
    end
end

function ppu.get_oam_addr() return oam_addr end
function ppu.oam_write(addr, val) oam[addr] = val end

local function render_scanline(y)
    if band(mask, 0x18) == 0 then
        local bg = nes_rgb[palette[0]] or black
        for x = 1, 256 do row_pixels[x] = bg end
        rows[y + 1] = concat(row_pixels)
        return
    end

    local show_bg = band(mask, 0x08) ~= 0
    local show_sp = band(mask, 0x10) ~= 0
    local bg_left = band(mask, 0x02) ~= 0
    local sp_left = band(mask, 0x04) ~= 0

    local tile_y = band(rshift(v, 5), 0x1F)
    local fine_y = band(rshift(v, 12), 0x07)
    local nt_select = band(rshift(v, 10), 0x03)
    local tile_x = band(v, 0x1F)
    local pattern_base = band(ctrl, 0x10) ~= 0 and 0x1000 or 0
    local sp_pattern_base = band(ctrl, 0x08) ~= 0 and 0x1000 or 0
    local sprite_height = band(ctrl, 0x20) ~= 0 and 16 or 8

    local sprites = {}
    local sprite_count = 0
    if show_sp then
        for i = 0, 63 do
            local sy = oam[i * 4]
            local row = y - sy
            if row >= 0 and row < sprite_height and sprite_count < 8 then
                local tile = oam[i * 4 + 1]
                local attr = oam[i * 4 + 2]
                local sx = oam[i * 4 + 3]
                local flip_v = band(attr, 0x80) ~= 0
                local flip_h = band(attr, 0x40) ~= 0
                local behind = band(attr, 0x20) ~= 0
                local pal_idx = band(attr, 3) + 4

                local r = flip_v and (sprite_height - 1 - row) or row
                local pb, ti = sp_pattern_base, tile
                if sprite_height == 16 then
                    pb = band(tile, 1) ~= 0 and 0x1000 or 0
                    ti = band(tile, 0xFE)
                    if r >= 8 then ti, r = ti + 1, r - 8 end
                end

                local addr = pb + ti * 16 + r
                local low, high = ppu_read(addr), ppu_read(addr + 8)

                sprite_count = sprite_count + 1
                sprites[sprite_count] = {sx, low, high, flip_h, behind, pal_idx, i == 0}
            end
        end
    end

    local bg_color = palette[0]
    for px = 0, 255 do
        local x = px + 1
        local bg_pixel, bg_pal = 0, 0

        if show_bg and (px >= 8 or bg_left) then
            local tx = tile_x + rshift(px + fine_x, 3)
            local nt = nt_select
            if tx >= 32 then tx, nt = tx - 32, bxor(nt, 1) end

            local nt_addr = 0x2000 + lshift(nt, 10) + tile_y * 32 + tx
            local tile = ppu_read(nt_addr)
            local pa = pattern_base + tile * 16 + fine_y
            local low, high = ppu_read(pa), ppu_read(pa + 8)

            local bit_pos = 7 - band(px + fine_x, 7)
            bg_pixel = bor(band(rshift(low, bit_pos), 1), lshift(band(rshift(high, bit_pos), 1), 1))

            if bg_pixel ~= 0 then
                local attr_addr = 0x23C0 + lshift(nt, 10) + lshift(rshift(tile_y, 2), 3) + rshift(tx, 2)
                local attr = ppu_read(attr_addr)
                local shift = bor(band(tx, 2), lshift(band(tile_y, 2), 1))
                bg_pal = band(rshift(attr, shift), 3)
            end
        end

        local sp_pixel, sp_pal, sp_behind, sp_zero = 0, 0, false, false
        if show_sp and (px >= 8 or sp_left) then
            for si = 1, sprite_count do
                local sp = sprites[si]
                local offset = px - sp[1]
                if offset >= 0 and offset < 8 then
                    local bit_pos = sp[4] and offset or (7 - offset)
                    local pix = bor(band(rshift(sp[2], bit_pos), 1), lshift(band(rshift(sp[3], bit_pos), 1), 1))
                    if pix ~= 0 then
                        sp_pixel, sp_pal, sp_behind, sp_zero = pix, sp[6], sp[5], sp[7]
                        break
                    end
                end
            end
        end

        local final_color
        if bg_pixel == 0 and sp_pixel == 0 then
            final_color = bg_color
        elseif bg_pixel == 0 then
            final_color = palette[sp_pal * 4 + sp_pixel]
        elseif sp_pixel == 0 then
            final_color = palette[bg_pal * 4 + bg_pixel]
        else
            if sp_zero and px < 255 then status = bor(status, 0x40) end
            final_color = sp_behind and palette[bg_pal * 4 + bg_pixel] or palette[sp_pal * 4 + sp_pixel]
        end

        row_pixels[x] = nes_rgb[band(final_color, 0x3F)] or black
    end

    rows[y + 1] = concat(row_pixels)

    if band(v, 0x7000) ~= 0x7000 then
        v = v + 0x1000
    else
        v = band(v, 0x0FFF)
        local cy = band(rshift(v, 5), 0x1F)
        if cy == 29 then cy, v = 0, bxor(v, 0x0800)
        elseif cy == 31 then cy = 0
        else cy = cy + 1 end
        v = bor(band(v, 0x7C1F), lshift(cy, 5))
    end
    v = bor(band(v, 0x7BE0), band(t, 0x041F))
end

function ppu.run_scanline()
    if scanline < 240 then
        render_scanline(scanline)
    elseif scanline == 241 then
        status = bor(status, 0x80)
        nmi_occurred = true
    elseif scanline == 261 then
        status = band(status, 0x1F)
        nmi_occurred = false
        if band(mask, 0x18) ~= 0 then
            v = bor(band(v, 0x041F), band(t, 0x7BE0))
        end
    end

    scanline = scanline + 1
    if scanline > 261 then
        scanline = 0
        frame_ready = true
    end

    return scanline == 242 and nmi_output
end

function ppu.nmi_pending() return nmi_occurred and nmi_output end
function ppu.clear_nmi() nmi_occurred = false end
function ppu.get_framebuffer() return concat(rows) end
function ppu.frame_complete() local r = frame_ready; frame_ready = false; return r end

return ppu
