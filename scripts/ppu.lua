local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
local structs = require("ffi_structs")
local ffi = structs.ffi
local ffi_fill = ffi.fill

local ppu = {}

local mapper
local vram = structs.vram
local palette = structs.palette
local oam = structs.oam
local nes_rgb = structs.nes_rgb
local framebuffer = structs.framebuffer
local palette_mirror = structs.palette_mirror
local bit_lut = structs.bit_lut
local nes_rgb_u32 = structs.nes_rgb_u32
local fb_u32 = structs.fb_u32

local ctrl, mask, status, oam_addr, data_buffer
local v, t, fine_x, w
local scanline
local frame_ready
local nmi_occurred, nmi_output

local chr_rom, chr_mask
local mirroring

local function mirror_nt_h(addr)
    return band(addr, 0x07FF)
end

local function mirror_nt_v(addr)
    local offset = band(addr, 0x0FFF)
    return offset < 0x0800 and band(offset, 0x03FF) or (0x0400 + band(offset, 0x03FF))
end

local mirror_nt = mirror_nt_h

function ppu.init(m)
    mapper = m
    ctrl, mask, status, oam_addr, data_buffer = 0, 0, 0, 0, 0
    v, t, fine_x, w = 0, 0, 0, 0
    scanline, frame_ready = 0, false
    nmi_occurred, nmi_output = false, false
    ffi_fill(vram, 2048, 0)
    ffi_fill(palette, 32, 0)
    ffi_fill(oam, 256, 0)

    chr_rom, chr_mask = m.get_chr_rom()
    mirroring = m.get_mirroring()
    mirror_nt = mirroring == 0 and mirror_nt_h or mirror_nt_v
end

local function ppu_read(addr)
    addr = band(addr, 0x3FFF)
    if addr < 0x2000 then
        return chr_rom[band(addr, chr_mask)]
    elseif addr < 0x3F00 then
        return vram[mirror_nt(addr)]
    else
        return palette[palette_mirror[band(addr, 0x1F)]]
    end
end

local function ppu_write(addr, val)
    addr = band(addr, 0x3FFF)
    if addr < 0x2000 then
        chr_rom[band(addr, chr_mask)] = val
    elseif addr < 0x3F00 then
        vram[mirror_nt(addr)] = val
    else
        palette[palette_mirror[band(addr, 0x1F)]] = val
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

local sp_line_pixel = ffi.new("uint8_t[256]")
local sp_line_pal = ffi.new("uint8_t[256]")
local sp_line_behind = ffi.new("bool[256]")
local sp_line_zero = ffi.new("bool[256]")
local bg_line_pixel = ffi.new("uint8_t[256]")
local bg_line_pal = ffi.new("uint8_t[256]")

local function render_scanline(y)
    local mask_val = mask

    if band(mask_val, 0x18) == 0 then
        local color_u32 = nes_rgb_u32[palette[0]]
        local base = y * 256
        for px = 0, 255 do
            fb_u32[base + px] = color_u32
        end
        return
    end

    local show_bg = band(mask_val, 0x08) ~= 0
    local show_sp = band(mask_val, 0x10) ~= 0
    local bg_left = band(mask_val, 0x02) ~= 0
    local sp_left = band(mask_val, 0x04) ~= 0

    local v_val = v
    local tile_y = band(rshift(v_val, 5), 0x1F)
    local fine_y_val = band(rshift(v_val, 12), 0x07)
    local nt_select = band(rshift(v_val, 10), 0x03)
    local tile_x_start = band(v_val, 0x1F)
    local ctrl_val = ctrl
    local pattern_base = band(ctrl_val, 0x10) ~= 0 and 0x1000 or 0
    local sp_pattern_base = band(ctrl_val, 0x08) ~= 0 and 0x1000 or 0
    local sprite_height = band(ctrl_val, 0x20) ~= 0 and 16 or 8

    local has_sprites = false
    if show_sp then
        ffi_fill(sp_line_pixel, 256, 0)
        local cm = chr_mask
        local sp_count = 0
        for i = 0, 63 do
            local base = i * 4
            local sy = oam[base]
            local row = y - sy
            if row >= 0 and row < sprite_height then
                sp_count = sp_count + 1
                if sp_count <= 8 then
                    local tile = oam[base + 1]
                    local attr = oam[base + 2]
                    local sx = oam[base + 3]
                    local flip_v = band(attr, 0x80) ~= 0
                    local flip_h = band(attr, 0x40) ~= 0
                    local behind = band(attr, 0x20) ~= 0
                    local pal_val = band(attr, 3) + 4
                    local is_zero = i == 0

                    local r = flip_v and (sprite_height - 1 - row) or row
                    local pb, ti = sp_pattern_base, tile
                    if sprite_height == 16 then
                        pb = band(tile, 1) ~= 0 and 0x1000 or 0
                        ti = band(tile, 0xFE)
                        if r >= 8 then ti, r = ti + 1, r - 8 end
                    end

                    local addr = pb + ti * 16 + r
                    local low = chr_rom[band(addr, cm)]
                    local high = chr_rom[band(addr + 8, cm)]

                    local pixels = bit_lut[low][high]
                    for b = 0, 7 do
                        local px = sx + b
                        if px < 256 and sp_line_pixel[px] == 0 then
                            local pix = pixels[flip_h and (7 - b) or b]
                            if pix ~= 0 then
                                sp_line_pixel[px] = pix
                                sp_line_pal[px] = pal_val
                                sp_line_behind[px] = behind
                                sp_line_zero[px] = is_zero
                                has_sprites = true
                            end
                        end
                    end
                end
            end
        end
    end

    local bg_color = palette[0]
    local bg_start = bg_left and 0 or 8
    local sp_start = sp_left and 0 or 8

    if show_bg then
        ffi_fill(bg_line_pixel, 256, 0)
        local fx = fine_x
        local num_tiles = fx == 0 and 32 or 33
        local tile_y_32 = tile_y * 32
        local attr_row = lshift(rshift(tile_y, 2), 3)
        local attr_y_shift = lshift(band(tile_y, 2), 1)
        local cm = chr_mask

        for ti = 0, num_tiles do
            local tx = tile_x_start + ti
            local nt = nt_select
            while tx >= 32 do tx, nt = tx - 32, bxor(nt, 1) end

            local nt_off = mirror_nt(0x2000 + lshift(nt, 10) + tile_y_32 + tx)
            local tile = vram[nt_off]
            local pa = pattern_base + tile * 16 + fine_y_val
            local low = chr_rom[band(pa, cm)]
            local high = chr_rom[band(pa + 8, cm)]

            local attr_off = mirror_nt(0x23C0 + lshift(nt, 10) + attr_row + rshift(tx, 2))
            local attr_val = vram[attr_off]
            local shift = bor(band(tx, 2), attr_y_shift)
            local pal_idx = band(rshift(attr_val, shift), 3)

            local base_px = ti * 8 - fx
            local pixels = bit_lut[low][high]
            for b = 0, 7 do
                local px = base_px + b
                if px >= bg_start and px < 256 then
                    local pix = pixels[b]
                    if pix ~= 0 then
                        bg_line_pixel[px] = pix
                        bg_line_pal[px] = pal_idx
                    end
                end
            end
        end
    else
        ffi_fill(bg_line_pixel, 256, 0)
    end

    local fb_base = y * 256
    for px = 0, 255 do
        local bg_pixel = bg_line_pixel[px]
        local sp_pixel = has_sprites and px >= sp_start and sp_line_pixel[px] or 0

        local final_color
        if bg_pixel == 0 and sp_pixel == 0 then
            final_color = bg_color
        elseif bg_pixel == 0 then
            final_color = palette[sp_line_pal[px] * 4 + sp_pixel]
        elseif sp_pixel == 0 then
            final_color = palette[bg_line_pal[px] * 4 + bg_pixel]
        else
            if sp_line_zero[px] and px < 255 then status = bor(status, 0x40) end
            final_color = sp_line_behind[px] and palette[bg_line_pal[px] * 4 + bg_pixel] or palette[sp_line_pal[px] * 4 + sp_pixel]
        end

        fb_u32[fb_base + px] = nes_rgb_u32[band(final_color, 0x3F)]
    end

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

function ppu.get_framebuffer()
    return structs.string(framebuffer, 240 * 256 * 4)
end

function ppu.frame_complete()
    local r = frame_ready
    frame_ready = false
    return r
end

return ppu
