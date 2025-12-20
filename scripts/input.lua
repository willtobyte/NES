local bit = require("bit")
local band, bor, rshift = bit.band, bit.bor, bit.rshift

local input = {}

local buttons = 0
local index = 0
local strobe_mode = 0

local BTN_A      = 0x01
local BTN_B      = 0x02
local BTN_SELECT = 0x04
local BTN_START  = 0x08
local BTN_UP     = 0x10
local BTN_DOWN   = 0x20
local BTN_LEFT   = 0x40
local BTN_RIGHT  = 0x80

function input.poll(kb)
    local b = 0
    if kb.z then b = bor(b, BTN_A) end
    if kb.x then b = bor(b, BTN_B) end
    if kb.space then b = bor(b, BTN_SELECT) end
    if kb.enter then b = bor(b, BTN_START) end
    if kb.up then b = bor(b, BTN_UP) end
    if kb.down then b = bor(b, BTN_DOWN) end
    if kb.left then b = bor(b, BTN_LEFT) end
    if kb.right then b = bor(b, BTN_RIGHT) end
    buttons = b
end

function input.strobe(value)
    strobe_mode = band(value, 1)
    if strobe_mode == 1 then
        index = 0
    end
end

function input.read(port)
    if port == 0 then
        if index > 7 then
            return 1
        end
        local value = band(rshift(buttons, index), 1)
        if strobe_mode == 0 then
            index = index + 1
        end
        return bor(value, 0x40)
    end
    return 0x40
end

return input
