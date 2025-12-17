local mapper = require("mapper")
local bus = require("bus")
local cpu = require("cpu")
local ppu = require("ppu")
local input = require("input")

local CYCLES_PER_SCANLINE = 114
local SCANLINES_PER_FRAME = 262

local scene = {}

function scene.on_enter()
    local f  = io.open("donkeykong.nes", "rb")

    local data = f:read("*a")
    f:close()

    mapper.load(data)
    ppu.init(mapper)
    bus.connect(mapper, ppu, input)
    cpu.init(bus)
    cpu.reset()
end

function scene.on_loop()
    input.poll(keyboard)

    for _ = 1, SCANLINES_PER_FRAME do
        local cycles = 0
        while cycles < CYCLES_PER_SCANLINE do
            cycles = cycles + cpu.step()
        end

        if ppu.run_scanline() then
            cpu.nmi()
        end
    end

    canvas.pixels = ppu.get_framebuffer()
end

sentinel(scene, "emulator")

return scene
