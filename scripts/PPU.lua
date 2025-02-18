local SCREEN_WIDTH = 256
local SCREEN_HEIGHT = 240

local PPU = {}
PPU.__index = PPU

function PPU.new(characterrom)
  local self = setmetatable({}, PPU)
  self.cycle = 0x0
  self.line = 0x0
  self.frame = 0x0
  self.control = 0x0
  self.mask = 0x0
  self.status = 0x0
  self.latch = false
  self.horizontalscroll = 0x0
  self.verticalscroll = 0x0
  self.pointer = 0x0
  self.temporary = 0x0
  self.readbuffer = 0x0
  self.objectattributeaddress = 0x0

  self.objectattribute = {}
  for index = 1, 0x100 do
    self.objectattribute[index] = 0x0
  end

  self.videoram = {}
  for index = 1, 0x4000 do
    self.videoram[index] = 0x0
  end

  -- Cria um buffer de pixels como tabela com tamanho fixo
  self.pixelbuffer = {}
  for i = 1, SCREEN_WIDTH * SCREEN_HEIGHT do
    self.pixelbuffer[i] = 0xFF000000
  end

  self.characterrom = {}
  if characterrom then
    for index = 1, #characterrom do
      self.characterrom[index] = characterrom[index]
    end
  else
    for index = 1, 0x2000 do
      self.characterrom[index] = 0x0
    end
  end

  return self
end

function PPU:read(register)
  local regindex = register & 0x7
  if regindex == 0x2 then
    local value = self.status
    self.status = self.status & 0x7F
    self.latch = false
    return value
  elseif regindex == 0x4 then
    return self.objectattribute[(self.objectattributeaddress % 0x100) + 1]
  elseif regindex == 0x7 then
    local value
    if self.pointer < 0x3F00 then
      value = self.readbuffer
      self.readbuffer = self.videoram[(self.pointer % #self.videoram) + 1]
    else
      value = self.videoram[(self.pointer % #self.videoram) + 1]
    end
    local increment = ((self.control & 0x04) ~= 0) and 0x20 or 0x1
    self.pointer = (self.pointer + increment) % 0x4000
    return value
  end
  return 0x0
end

function PPU:write(register, value)
  local regindex = register & 0x7
  if regindex == 0x0 then
    self.control = value
    self.temporary = (self.temporary & 0xF3FF) | ((value & 0x03) << 10)
  elseif regindex == 0x1 then
    self.mask = value
  elseif regindex == 0x3 then
    self.objectattributeaddress = value
  elseif regindex == 0x4 then
    self.objectattribute[(self.objectattributeaddress % 0x100) + 1] = value
    self.objectattributeaddress = (self.objectattributeaddress + 1) % 0x100
  elseif regindex == 0x5 then
    if not self.latch then
      self.horizontalscroll = value
      self.latch = true
    else
      self.verticalscroll = value
      self.latch = false
    end
  elseif regindex == 0x6 then
    if not self.latch then
      self.temporary = (value << 8) | (self.temporary & 0x00FF)
      self.latch = true
    else
      self.temporary = (self.temporary & 0xFF00) | value
      self.pointer = self.temporary
      self.latch = false
    end
  elseif regindex == 0x7 then
    self.videoram[(self.pointer % #self.videoram) + 1] = value
    local increment = ((self.control & 0x04) ~= 0) and 0x20 or 0x1
    self.pointer = (self.pointer + increment) % 0x4000
  end
end

function PPU:step()
  if self.line < SCREEN_HEIGHT and self.cycle >= 1 and self.cycle <= SCREEN_WIDTH then
    local pixelx = self.cycle - 1
    local pixely = self.line
    local tilex = math.floor(pixelx / 8)
    local tiley = math.floor(pixely / 8)
    local totaltile = math.floor(#self.characterrom / 16)
    local tileindex = (tiley * 32 + tilex) % totaltile
    local offset = tileindex * 16
    local row = pixely % 8
    local planezero = self.characterrom[offset + row + 1]
    local planeone = self.characterrom[offset + 8 + row + 1]
    local shift = 7 - (pixelx % 8)
    local bitzero = (planezero >> shift) & 0x1
    local bitone = (planeone >> shift) & 0x1
    local color = (bitone << 1) | bitzero
    local gray = color * 0x55
    local pixel = 0xFF000000 | (gray << 16) | (gray << 8) | gray
    local index = pixely * SCREEN_WIDTH + pixelx + 1
    self.pixelbuffer[index] = pixel
  end

  self.cycle = self.cycle + 1
  if self.cycle > 0x154 then
    self.cycle = 0
    self.line = self.line + 1
    if self.line == 0xF1 then
      self.status = self.status | 0x80
    end
    if self.line > 0x105 then
      self.line = 0
      self.status = self.status & 0x7F
      self.frame = self.frame + 1
    end
  end

  -- Conversão otimizada do buffer de pixels para uma string binária em blocos
  local pixelCount = SCREEN_WIDTH * SCREEN_HEIGHT
  local chunks = {}
  local CHUNK_SIZE = 1024 -- Ajuste esse valor se necessário

  for i = 1, pixelCount, CHUNK_SIZE do
    local count = math.min(CHUNK_SIZE, pixelCount - i + 1)
    local fmt
    if count == 1 then
      fmt = "<I4"
    else
      fmt = "<" .. count .. "I4"
    end
    chunks[#chunks + 1] = string.pack(fmt, table.unpack(self.pixelbuffer, i, i + count - 1))
  end

  self.renderer.pixels = table.concat(chunks)
end

function PPU:reset(renderer)
  self.cycle = 0
  self.line = 0
  self.frame = 0
  self.control = 0
  self.mask = 0
  self.status = 0
  self.latch = false
  self.horizontalscroll = 0
  self.verticalscroll = 0
  self.pointer = 0
  self.temporary = 0
  self.readbuffer = 0
  self.objectattributeaddress = 0

  rawset(self, "renderer", renderer)

  for index = 1, 0x100 do
    self.objectattribute[index] = 0
  end

  for index = 1, 0x4000 do
    self.videoram[index] = 0
  end

  for i = 1, SCREEN_WIDTH * SCREEN_HEIGHT do
    self.pixelbuffer[i] = 0xFF000000
  end
end

return PPU
