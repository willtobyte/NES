local ffi = require("ffi")
local bit = require("bit")
local rshift, band, bor, lshift = bit.rshift, bit.band, bit.bor, bit.lshift

ffi.cdef[[
    typedef struct {
        uint8_t r, g, b, a;
    } pixel_t;
]]

local M = {}

M.ffi = ffi

M.ram = ffi.new("uint8_t[2048]")
M.vram = ffi.new("uint8_t[2048]")
M.oam = ffi.new("uint8_t[256]")
M.palette = ffi.new("uint8_t[32]")
M.prg_rom = nil
M.chr_rom = nil

M.framebuffer = ffi.new("pixel_t[240][256]")

M.nes_rgb = ffi.new("pixel_t[64]")
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
M.nes_rgb_u32 = ffi.new("uint32_t[64]")
for i = 0, 63 do
    local c = raw_palette[i + 1]
    local r = rshift(c, 16)
    local g = band(rshift(c, 8), 0xFF)
    local b = band(c, 0xFF)
    M.nes_rgb[i].r = r
    M.nes_rgb[i].g = g
    M.nes_rgb[i].b = b
    M.nes_rgb[i].a = 255
    M.nes_rgb_u32[i] = bor(r, lshift(g, 8), lshift(b, 16), lshift(255, 24))
end

M.nz_flags = ffi.new("uint8_t[256]")
for i = 0, 255 do
    local f = 0
    if i == 0 then f = 0x02 end
    if band(i, 0x80) ~= 0 then f = bor(f, 0x80) end
    M.nz_flags[i] = f
end

M.signed_offset = ffi.new("int8_t[256]")
for i = 0, 255 do
    M.signed_offset[i] = i < 128 and i or (i - 256)
end

M.bit_lut = ffi.new("uint8_t[256][256][8]")
for low = 0, 255 do
    for high = 0, 255 do
        for b = 0, 7 do
            local l = band(rshift(low, 7 - b), 1)
            local h = band(rshift(high, 7 - b), 1)
            M.bit_lut[low][high][b] = bor(l, lshift(h, 1))
        end
    end
end

M.fb_u32 = ffi.cast("uint32_t*", M.framebuffer)

M.page_cross = ffi.new("uint8_t[256]")
local page_cross_opcodes = {
    0x11, 0x19, 0x1D, 0x31, 0x39, 0x3D, 0x51, 0x59, 0x5D,
    0x71, 0x79, 0x7D, 0xB1, 0xB9, 0xBD, 0xBE, 0xBC,
    0xD1, 0xD9, 0xDD, 0xF1, 0xF9, 0xFD
}
for _, op in ipairs(page_cross_opcodes) do
    M.page_cross[op] = 1
end

M.palette_mirror = ffi.new("uint8_t[32]")
for i = 0, 31 do
    local pa = i
    if pa == 0x10 or pa == 0x14 or pa == 0x18 or pa == 0x1C then pa = pa - 0x10 end
    M.palette_mirror[i] = pa
end

M.copy = ffi.copy
M.fill = ffi.fill
M.cast = ffi.cast
M.string = ffi.string
M.sizeof = ffi.sizeof
M.new = ffi.new

function M.alloc_rom(prg_size, chr_size)
    M.prg_rom = ffi.new("uint8_t[?]", prg_size)
    M.chr_rom = ffi.new("uint8_t[?]", chr_size)
    return M.prg_rom, M.chr_rom
end

M.prg_mask = 0
function M.set_prg_mask(mask)
    M.prg_mask = mask
end

return M
