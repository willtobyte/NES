---@diagnostic disable: undefined-global, undefined-field, lowercase-global
local MOS6502 = require("MOS6502")

local cpu = MOS6502.new()

local buffer = ""

local ports = {
  [0xD010] = function(value)
    buffer = buffer .. string.char(value)
  end
}

cpu.write = function(self, address, value)
  self.memory[address] = value & 0xFF
  if ports[address] then ports[address](value) end
end

local rom = read("blobs/rom.nes")
if string.char(rom[1], rom[2], rom[3], rom[4]) ~= "NES\26" then error("Invalid NES ROM header.") end

local banks = rom[5]
local size = banks * 16384
local flag = rom[7]
local trainer = 0
if (flag & 0x04) ~= 0 then trainer = 512 end

local offset = 16 + trainer
local program = {}
for i = 0, size - 1 do
  program[i + 1] = rom[offset + i]
end

local address = 0x8000
if banks == 1 then
  for i = 1, #program do
    local byte = program[i]
    cpu.memory[address + i - 1] = byte
    cpu.memory[0xC000 + i - 1] = byte
  end
elseif banks >= 2 then
  for i = 1, 16384 do
    cpu.memory[address + i - 1] = program[i]
  end
  for i = 16385, 32768 do
    cpu.memory[0xC000 + i - 16385] = program[i]
  end
else
  error("No PRG ROM banks found.")
end

cpu.memory[0xFFFC] = address & 0xFF
cpu.memory[0xFFFD] = (address >> 8) & 0xFF

function setup()
  engine = EngineFactory.new()
      :with_title("MOS6502")
      :with_width(1920)
      :with_height(1080)
      :with_scale(3.0)
      :with_gravity(9.8)
      :with_fullscreen(false)
      :create()

  cpu:reset()
end

function loop()
  if cpu.halted then
    return
  end

  cpu:step()
end

function run()
  engine:run()
end
