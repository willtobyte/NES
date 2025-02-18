---@diagnostic disable: undefined-global, undefined-field, lowercase-global
local MOS6502 = require("MOS6502")
-- local PPU = require("PPU")

local cpu = MOS6502.new()
-- local picturecpu = PPU.new(characterdata)

local output = ""

local ports = {
  [0xD010] = function(letter)
    output = output .. string.char(letter)
  end
}

cpu.write = function(self, location, letter)
  self.memory[location] = letter & 0xFF
  if ports[location] then
    ports[location](letter)
  end
end

local romimage = read("blobs/rom.nes")
if string.char(romimage[1], romimage[2], romimage[3], romimage[4]) ~= "NES\26" then
  error("Invalid NES ROM header.")
end

local programbanks = romimage[5]
local characterbanks = romimage[6]
local programsize = programbanks * 16384
local charactersize = characterbanks * 8192
local flag = romimage[7]
local trainer = 0
if (flag & 0x04) ~= 0 then
  trainer = 512
end

local offset = 16 + trainer
local programdata = {}
for index = 0, programsize - 1 do
  programdata[index + 1] = romimage[offset + index]
end

local characterdata = nil
if characterbanks > 0 then
  local chroffset = offset + programsize
  characterdata = {}
  for index = 0, charactersize - 1 do
    characterdata[index + 1] = romimage[chroffset + index]
  end
end

local startaddress = 0x8000
if programbanks == 1 then
  for index = 1, #programdata do
    local byte = programdata[index]
    cpu.memory[startaddress + index - 1] = byte
    cpu.memory[0xC000 + index - 1] = byte
  end
elseif programbanks >= 2 then
  for index = 1, 16384 do
    cpu.memory[startaddress + index - 1] = programdata[index]
  end
  for index = 16385, 32768 do
    cpu.memory[0xC000 + index - 16385] = programdata[index]
  end
else
  error("No PRG ROM banks found.")
end

cpu.memory[0xFFFC] = startaddress & 0xFF
cpu.memory[0xFFFD] = (startaddress >> 8) & 0xFF

function setup()
  engine = EngineFactory.new()
      :with_title("MOS6502")
      :with_width(256)
      :with_height(240)
      :with_scale(4.0)
      :with_fullscreen(false)
      :create()

  -- local renderer = engine:renderer()

  cpu:reset()
  -- picturecpu:reset(renderer)
end

function loop()
  if cpu.halted then
    return
  end

  cpu:step()
  -- for count = 1, 3 do
  --   picturecpu:step()
  -- end

  -- Screen dimensions
  local width = 256
  local height = 240
  local squaresize = 50

  -- Calculate the start and end of the red square
  local centerx = math.floor(width / 2)
  local centery = math.floor(height / 2)
  local redstartx = centerx - math.floor(squaresize / 2) + 1
  local redendx = redstartx + squaresize - 1
  local redstarty = centery - math.floor(squaresize / 2) + 1
  local redendy = redstarty + squaresize - 1

  -- Prepare pixels as binary strings in ARGB8888 format
  local blackpixel = string.pack("I4", 0xFF000000)
  local redpixel = string.pack("I4", 0xFFFF0000)

  -- Build the rows of the buffer optimally
  local rows = {}
  for line = 1, height do
    if line >= redstarty and line <= redendy then
      local leftcount = redstartx - 1
      local redcount = squaresize
      local rightcount = width - redendx
      rows[line] = string.rep(blackpixel, leftcount)
          .. string.rep(redpixel, redcount)
          .. string.rep(blackpixel, rightcount)
    else
      rows[line] = string.rep(blackpixel, width)
    end
  end

  local pixeldata = table.concat(rows)
  engine:canvas().pixels = pixeldata
end

function run()
  engine:run()
end
