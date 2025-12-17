local mapper = require("mapper")
local bus = require("bus")
local cpu = require("cpu")
local ppu = require("ppu")
local input = require("input")

local CYCLES_PER_FRAME = 29781

local scene = {}

function scene.on_enter()
    local rom_file = io.open("donkeykong.nes", "rb")
    if not rom_file then
        error("Could not find donkeykong.nes")
    end

    local rom_data = rom_file:read("*a")
    rom_file:close()

    mapper.load(rom_data)
    ppu.init(mapper)
    bus.connect(mapper, ppu, input)
    cpu.init(bus)
    cpu.reset()
end

function scene.on_loop()
    input.poll(keyboard)

    local cycles = 0
    while cycles < CYCLES_PER_FRAME do
        local cpu_cycles = cpu.step()

        for _ = 1, cpu_cycles * 3 do
            ppu.step()
        end

        if ppu.nmi_pending() then
            ppu.clear_nmi()
            cpu.nmi()
        end

        cycles = cycles + cpu_cycles
    end

    canvas.pixels = ppu.get_framebuffer()
end

sentinel(scene, "emulator")

return scene
