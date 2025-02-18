local opcodes = {

  -- Illegal Opcode: KIL (Implied)
  [0x02] = function(cpu)
    cpu.halted = true
    return 2
  end,

  -- ADC (Add with Carry)
  -- ADC Immediate
  [0x69] = function(cpu)
    local value = cpu:fetch()
    local carry = cpu.P & 0x01
    local A = cpu.A
    local sum = A + value + carry
    local result = sum & 0xFF
    if sum > 0xFF then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (value ~ result)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    return 2
  end,

  -- ADC Zero Page
  [0x65] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local sum = A + value + carry
    local result = sum & 0xFF
    if sum > 0xFF then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (value ~ result)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    return 3
  end,

  -- ADC Zero Page,X
  [0x75] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local sum = A + value + carry
    local result = sum & 0xFF
    if sum > 0xFF then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (value ~ result)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    return 4
  end,

  -- ADC Absolute
  [0x6D] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local sum = A + value + carry
    local result = sum & 0xFF
    if sum > 0xFF then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (value ~ result)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    return 4
  end,

  -- ADC Absolute,X
  [0x7D] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.X) & 0xFFFF
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local sum = A + value + carry
    local result = sum & 0xFF
    if sum > 0xFF then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (value ~ result)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then
      cycles = cycles + 1
    end
    return cycles
  end,

  -- ADC Absolute,Y
  [0x79] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local sum = A + value + carry
    local result = sum & 0xFF
    if sum > 0xFF then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (value ~ result)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then
      cycles = cycles + 1
    end
    return cycles
  end,

  -- ADC (Indirect,X)
  [0x61] = function(cpu)
    local zp = cpu:fetch()
    local ptr = (zp + cpu.X) & 0xFF
    local lo = cpu:read(ptr)
    local hi = cpu:read((ptr + 1) & 0xFF)
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local sum = A + value + carry
    local result = sum & 0xFF
    if sum > 0xFF then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (value ~ result)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    return 6
  end,

  -- ADC (Indirect),Y
  [0x71] = function(cpu)
    local zp = cpu:fetch()
    local lo = cpu:read(zp)
    local hi = cpu:read((zp + 1) & 0xFF)
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local sum = A + value + carry
    local result = sum & 0xFF
    if sum > 0xFF then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (value ~ result)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    local cycles = 5
    if (base & 0xFF00) ~= (addr & 0xFF00) then
      cycles = cycles + 1
    end
    return cycles
  end,

  -- AND (Logical AND)
  -- AND Immediate
  [0x29] = function(cpu)
    local value = cpu:fetch()
    cpu.A = cpu.A & value
    cpu:znupdate(cpu.A)
    return 2
  end,

  -- AND Zero Page
  [0x25] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    cpu.A = cpu.A & value
    cpu:znupdate(cpu.A)
    return 3
  end,

  -- AND Zero Page,X
  [0x35] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = cpu:read(addr)
    cpu.A = cpu.A & value
    cpu:znupdate(cpu.A)
    return 4
  end,

  -- AND Absolute
  [0x2D] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    cpu.A = cpu.A & value
    cpu:znupdate(cpu.A)
    return 4
  end,

  -- AND Absolute,X
  [0x3D] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.X) & 0xFFFF
    local value = cpu:read(addr)
    cpu.A = cpu.A & value
    cpu:znupdate(cpu.A)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then
      cycles = cycles + 1
    end
    return cycles
  end,

  -- AND Absolute,Y
  [0x39] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    cpu.A = cpu.A & value
    cpu:znupdate(cpu.A)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then
      cycles = cycles + 1
    end
    return cycles
  end,

  -- AND (Indirect,X)
  [0x21] = function(cpu)
    local zp = cpu:fetch()
    local ptr = (zp + cpu.X) & 0xFF
    local lo = cpu:read(ptr)
    local hi = cpu:read((ptr + 1) & 0xFF)
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    cpu.A = cpu.A & value
    cpu:znupdate(cpu.A)
    return 6
  end,

  -- AND (Indirect),Y
  [0x31] = function(cpu)
    local zp = cpu:fetch()
    local lo = cpu:read(zp)
    local hi = cpu:read((zp + 1) & 0xFF)
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    cpu.A = cpu.A & value
    cpu:znupdate(cpu.A)
    local cycles = 5
    if (base & 0xFF00) ~= (addr & 0xFF00) then
      cycles = cycles + 1
    end
    return cycles
  end,

  -- ASL (Arithmetic Shift Left)
  -- ASL Accumulator
  [0x0A] = function(cpu)
    local carry = (cpu.A & 0x80) ~= 0 and 1 or 0
    cpu.A = (cpu.A << 1) & 0xFF
    if carry == 1 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(cpu.A)
    return 2
  end,

  -- ASL Zero Page
  [0x06] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    local carry = (value & 0x80) ~= 0 and 1 or 0
    value = (value << 1) & 0xFF
    cpu:write(addr, value)
    if carry == 1 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 5
  end,

  -- ASL Zero Page,X
  [0x16] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = cpu:read(addr)
    local carry = (value & 0x80) ~= 0 and 1 or 0
    value = (value << 1) & 0xFF
    cpu:write(addr, value)
    if carry == 1 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 6
  end,

  -- ASL Absolute
  [0x0E] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local carry = (value & 0x80) ~= 0 and 1 or 0
    value = (value << 1) & 0xFF
    cpu:write(addr, value)
    if carry == 1 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 6
  end,

  -- ASL Absolute,X
  [0x1E] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = (lo + (hi << 8) + cpu.X) & 0xFFFF
    local value = cpu:read(addr)
    local carry = (value & 0x80) ~= 0 and 1 or 0
    value = (value << 1) & 0xFF
    cpu:write(addr, value)
    if carry == 1 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 7
  end,

  -- Branch Instructions
  -- BCC Relative (Branch if Carry Clear)
  [0x90] = function(cpu)
    local offset = cpu:fetch()
    if offset >= 0x80 then offset = offset - 0x100 end
    local cycles = 2
    if (cpu.P & 0x01) == 0 then
      local oldPC = cpu.PC
      cpu.PC = (cpu.PC + offset) & 0xFFFF
      cycles = cycles + 1
      if (oldPC & 0xFF00) ~= (cpu.PC & 0xFF00) then
        cycles = cycles + 1
      end
    end
    return cycles
  end,

  -- BCS Relative (Branch if Carry Set)
  [0xB0] = function(cpu)
    local offset = cpu:fetch()
    if offset >= 0x80 then offset = offset - 0x100 end
    local cycles = 2
    if (cpu.P & 0x01) ~= 0 then
      local oldPC = cpu.PC
      cpu.PC = (cpu.PC + offset) & 0xFFFF
      cycles = cycles + 1
      if (oldPC & 0xFF00) ~= (cpu.PC & 0xFF00) then
        cycles = cycles + 1
      end
    end
    return cycles
  end,

  -- BEQ Relative (Branch if Zero Set)
  [0xF0] = function(cpu)
    local offset = cpu:fetch()
    if offset >= 0x80 then offset = offset - 0x100 end
    local cycles = 2
    if (cpu.P & 0x02) ~= 0 then
      local oldPC = cpu.PC
      cpu.PC = (cpu.PC + offset) & 0xFFFF
      cycles = cycles + 1
      if (oldPC & 0xFF00) ~= (cpu.PC & 0xFF00) then
        cycles = cycles + 1
      end
    end
    return cycles
  end,

  -- BMI Relative (Branch if Negative)
  [0x30] = function(cpu)
    local offset = cpu:fetch()
    if offset >= 0x80 then offset = offset - 0x100 end
    local cycles = 2
    if (cpu.P & 0x80) ~= 0 then
      local oldPC = cpu.PC
      cpu.PC = (cpu.PC + offset) & 0xFFFF
      cycles = cycles + 1
      if (oldPC & 0xFF00) ~= (cpu.PC & 0xFF00) then
        cycles = cycles + 1
      end
    end
    return cycles
  end,

  -- BNE Relative (Branch if Zero Clear)
  [0xD0] = function(cpu)
    local offset = cpu:fetch()
    if offset >= 0x80 then offset = offset - 0x100 end
    local cycles = 2
    if (cpu.P & 0x02) == 0 then
      local oldPC = cpu.PC
      cpu.PC = (cpu.PC + offset) & 0xFFFF
      cycles = cycles + 1
      if (oldPC & 0xFF00) ~= (cpu.PC & 0xFF00) then
        cycles = cycles + 1
      end
    end
    return cycles
  end,

  -- BPL Relative (Branch if Negative Clear)
  [0x10] = function(cpu)
    local offset = cpu:fetch()
    if offset >= 0x80 then offset = offset - 0x100 end
    local cycles = 2
    if (cpu.P & 0x80) == 0 then
      local oldPC = cpu.PC
      cpu.PC = (cpu.PC + offset) & 0xFFFF
      cycles = cycles + 1
      if (oldPC & 0xFF00) ~= (cpu.PC & 0xFF00) then
        cycles = cycles + 1
      end
    end
    return cycles
  end,

  -- BVC Relative (Branch if Overflow Clear)
  [0x50] = function(cpu)
    local offset = cpu:fetch()
    if offset >= 0x80 then offset = offset - 0x100 end
    local cycles = 2
    if (cpu.P & 0x40) == 0 then
      local oldPC = cpu.PC
      cpu.PC = (cpu.PC + offset) & 0xFFFF
      cycles = cycles + 1
      if (oldPC & 0xFF00) ~= (cpu.PC & 0xFF00) then
        cycles = cycles + 1
      end
    end
    return cycles
  end,

  -- BVS Relative (Branch if Overflow Set)
  [0x70] = function(cpu)
    local offset = cpu:fetch()
    if offset >= 0x80 then offset = offset - 0x100 end
    local cycles = 2
    if (cpu.P & 0x40) ~= 0 then
      local oldPC = cpu.PC
      cpu.PC = (cpu.PC + offset) & 0xFFFF
      cycles = cycles + 1
      if (oldPC & 0xFF00) ~= (cpu.PC & 0xFF00) then
        cycles = cycles + 1
      end
    end
    return cycles
  end,

  -- BIT (Bit Test)
  -- BIT Zero Page
  [0x24] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    if (cpu.A & value) == 0 then
      cpu.P = cpu.P | 0x02
    else
      cpu.P = cpu.P & 0xFD
    end
    if (value & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x80
    else
      cpu.P = cpu.P & 0x7F
    end
    if (value & 0x40) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    return 3
  end,

  -- BIT Absolute
  [0x2C] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    if (cpu.A & value) == 0 then
      cpu.P = cpu.P | 0x02
    else
      cpu.P = cpu.P & 0xFD
    end
    if (value & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x80
    else
      cpu.P = cpu.P & 0x7F
    end
    if (value & 0x40) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    return 4
  end,

  -- BRK (Force Interrupt)
  [0x00] = function(cpu)
    cpu.PC = (cpu.PC + 1) & 0xFFFF
    local return_addr = cpu.PC
    cpu:push((return_addr >> 8) & 0xFF)
    cpu:push(return_addr & 0xFF)
    cpu:push(cpu.P | 0x30)
    cpu.P = cpu.P | 0x04
    local mem = cpu.memory
    cpu.PC = mem[0xFFFE] + (mem[0xFFFF] << 8)
    return 7
  end,

  -- Flag Instructions
  -- CLC (Clear Carry)
  [0x18] = function(cpu)
    cpu.P = cpu.P & 0xFE
    return 2
  end,

  -- CLD (Clear Decimal)
  [0xD8] = function(cpu)
    cpu.P = cpu.P & 0xF7
    return 2
  end,

  -- CLI (Clear Interrupt Disable)
  [0x58] = function(cpu)
    cpu.P = cpu.P & 0xFB
    return 2
  end,

  -- CLV (Clear Overflow)
  [0xB8] = function(cpu)
    cpu.P = cpu.P & 0xBF
    return 2
  end,

  -- CMP (Compare Accumulator)
  -- CMP Immediate
  [0xC9] = function(cpu)
    local value = cpu:fetch()
    local result = (cpu.A - value) & 0xFF
    if cpu.A >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 2
  end,

  -- CMP Zero Page
  [0xC5] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    local result = (cpu.A - value) & 0xFF
    if cpu.A >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 3
  end,

  -- CMP Zero Page,X
  [0xD5] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = cpu:read(addr)
    local result = (cpu.A - value) & 0xFF
    if cpu.A >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 4
  end,

  -- CMP Absolute
  [0xCD] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local result = (cpu.A - value) & 0xFF
    if cpu.A >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 4
  end,

  -- CMP Absolute,X
  [0xDD] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.X) & 0xFFFF
    local value = cpu:read(addr)
    local result = (cpu.A - value) & 0xFF
    if cpu.A >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then
      cycles = cycles + 1
    end
    return cycles
  end,

  -- CMP Absolute,Y
  [0xD9] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    local result = (cpu.A - value) & 0xFF
    if cpu.A >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then
      cycles = cycles + 1
    end
    return cycles
  end,

  -- CMP (Indirect,X)
  [0xC1] = function(cpu)
    local zp = cpu:fetch()
    local ptr = (zp + cpu.X) & 0xFF
    local lo = cpu:read(ptr)
    local hi = cpu:read((ptr + 1) & 0xFF)
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local result = (cpu.A - value) & 0xFF
    if cpu.A >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 6
  end,

  -- CMP (Indirect),Y
  [0xD1] = function(cpu)
    local zp = cpu:fetch()
    local lo = cpu:read(zp)
    local hi = cpu:read((zp + 1) & 0xFF)
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    local result = (cpu.A - value) & 0xFF
    if cpu.A >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    local cycles = 5
    if (base & 0xFF00) ~= (addr & 0xFF00) then
      cycles = cycles + 1
    end
    return cycles
  end,

  -- CPX (Compare X Register)
  -- CPX Immediate
  [0xE0] = function(cpu)
    local value = cpu:fetch()
    local result = (cpu.X - value) & 0xFF
    if cpu.X >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 2
  end,

  -- CPX Zero Page
  [0xE4] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    local result = (cpu.X - value) & 0xFF
    if cpu.X >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 3
  end,

  -- CPX Absolute
  [0xEC] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local result = (cpu.X - value) & 0xFF
    if cpu.X >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 4
  end,

  -- CPY (Compare Y Register)
  -- CPY Immediate
  [0xC0] = function(cpu)
    local value = cpu:fetch()
    local result = (cpu.Y - value) & 0xFF
    if cpu.Y >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 2
  end,

  -- CPY Zero Page
  [0xC4] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    local result = (cpu.Y - value) & 0xFF
    if cpu.Y >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 3
  end,

  -- CPY Absolute
  [0xCC] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local result = (cpu.Y - value) & 0xFF
    if cpu.Y >= value then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(result)
    return 4
  end,

  -- DEC (Decrement Memory)
  -- DEC Zero Page
  [0xC6] = function(cpu)
    local addr = cpu:fetch()
    local value = (cpu:read(addr) - 1) & 0xFF
    cpu:write(addr, value)
    cpu:znupdate(value)
    return 5
  end,

  -- DEC Zero Page,X
  [0xD6] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = (cpu:read(addr) - 1) & 0xFF
    cpu:write(addr, value)
    cpu:znupdate(value)
    return 6
  end,

  -- DEC Absolute
  [0xCE] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = (cpu:read(addr) - 1) & 0xFF
    cpu:write(addr, value)
    cpu:znupdate(value)
    return 6
  end,

  -- DEC Absolute,X
  [0xDE] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = (lo + (hi << 8) + cpu.X) & 0xFFFF
    local value = (cpu:read(addr) - 1) & 0xFF
    cpu:write(addr, value)
    cpu:znupdate(value)
    return 7
  end,

  -- DEX (Decrement X Register)
  [0xCA] = function(cpu)
    cpu.X = (cpu.X - 1) & 0xFF
    cpu:znupdate(cpu.X)
    return 2
  end,

  -- DEY (Decrement Y Register)
  [0x88] = function(cpu)
    cpu.Y = (cpu.Y - 1) & 0xFF
    cpu:znupdate(cpu.Y)
    return 2
  end,

  -- EOR (Exclusive OR)
  -- EOR Immediate
  [0x49] = function(cpu)
    local value = cpu:fetch()
    cpu.A = cpu.A ~ value
    cpu:znupdate(cpu.A)
    return 2
  end,

  -- EOR Zero Page
  [0x45] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    cpu.A = cpu.A ~ value
    cpu:znupdate(cpu.A)
    return 3
  end,

  -- EOR Zero Page,X
  [0x55] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = cpu:read(addr)
    cpu.A = cpu.A ~ value
    cpu:znupdate(cpu.A)
    return 4
  end,

  -- EOR Absolute
  [0x4D] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    cpu.A = cpu.A ~ value
    cpu:znupdate(cpu.A)
    return 4
  end,

  -- EOR Absolute,X
  [0x5D] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.X) & 0xFFFF
    local value = cpu:read(addr)
    cpu.A = cpu.A ~ value
    cpu:znupdate(cpu.A)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- EOR Absolute,Y
  [0x59] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    cpu.A = cpu.A ~ value
    cpu:znupdate(cpu.A)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- EOR (Indirect,X)
  [0x41] = function(cpu)
    local zp = cpu:fetch()
    local ptr = (zp + cpu.X) & 0xFF
    local lo = cpu:read(ptr)
    local hi = cpu:read((ptr + 1) & 0xFF)
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    cpu.A = cpu.A ~ value
    cpu:znupdate(cpu.A)
    return 6
  end,

  -- EOR (Indirect),Y
  [0x51] = function(cpu)
    local zp = cpu:fetch()
    local lo = cpu:read(zp)
    local hi = cpu:read((zp + 1) & 0xFF)
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    cpu.A = cpu.A ~ value
    cpu:znupdate(cpu.A)
    local cycles = 5
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- INC (Increment Memory)
  -- INC Zero Page
  [0xE6] = function(cpu)
    local addr = cpu:fetch()
    local value = (cpu:read(addr) + 1) & 0xFF
    cpu:write(addr, value)
    cpu:znupdate(value)
    return 5
  end,

  -- INC Zero Page,X
  [0xF6] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = (cpu:read(addr) + 1) & 0xFF
    cpu:write(addr, value)
    cpu:znupdate(value)
    return 6
  end,

  -- INC Absolute
  [0xEE] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = (cpu:read(addr) + 1) & 0xFF
    cpu:write(addr, value)
    cpu:znupdate(value)
    return 6
  end,

  -- INC Absolute,X
  [0xFE] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = (lo + (hi << 8) + cpu.X) & 0xFFFF
    local value = (cpu:read(addr) + 1) & 0xFF
    cpu:write(addr, value)
    cpu:znupdate(value)
    return 7
  end,

  -- INX (Increment X Register)
  [0xE8] = function(cpu)
    cpu.X = (cpu.X + 1) & 0xFF
    cpu:znupdate(cpu.X)
    return 2
  end,

  -- INY (Increment Y Register)
  [0xC8] = function(cpu)
    cpu.Y = (cpu.Y + 1) & 0xFF
    cpu:znupdate(cpu.Y)
    return 2
  end,

  -- JMP (Jump)
  -- JMP Absolute
  [0x4C] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    cpu.PC = lo + (hi << 8)
    return 3
  end,

  -- JMP Indirect (with 6502 page-boundary bug emulation)
  [0x6C] = function(cpu)
    local lo_addr = cpu:fetch()
    local hi_addr = cpu:fetch()
    local ptr = lo_addr + (hi_addr << 8)
    local lo = cpu:read(ptr)
    local hi
    if (ptr & 0xFF) == 0xFF then
      hi = cpu:read(ptr & 0xFF00)
    else
      hi = cpu:read(ptr + 1)
    end
    cpu.PC = lo + (hi << 8)
    return 5
  end,

  -- JSR (Jump to Subroutine)
  [0x20] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local return_addr = (cpu.PC - 1) & 0xFFFF
    cpu:push((return_addr >> 8) & 0xFF)
    cpu:push(return_addr & 0xFF)
    cpu.PC = addr
    return 6
  end,

  -- LDA (Load Accumulator)
  -- LDA Immediate
  [0xA9] = function(cpu)
    cpu.A = cpu:fetch()
    cpu:znupdate(cpu.A)
    return 2
  end,

  -- LDA Zero Page
  [0xA5] = function(cpu)
    local addr = cpu:fetch()
    cpu.A = cpu:read(addr)
    cpu:znupdate(cpu.A)
    return 3
  end,

  -- LDA Zero Page,X
  [0xB5] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    cpu.A = cpu:read(addr)
    cpu:znupdate(cpu.A)
    return 4
  end,

  -- LDA Absolute
  [0xAD] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    cpu.A = cpu:read(addr)
    cpu:znupdate(cpu.A)
    return 4
  end,

  -- LDA Absolute,X
  [0xBD] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.X) & 0xFFFF
    cpu.A = cpu:read(addr)
    cpu:znupdate(cpu.A)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- LDA Absolute,Y
  [0xB9] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    cpu.A = cpu:read(addr)
    cpu:znupdate(cpu.A)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- LDA (Indirect,X)
  [0xA1] = function(cpu)
    local zp = cpu:fetch()
    local ptr = (zp + cpu.X) & 0xFF
    local lo = cpu:read(ptr)
    local hi = cpu:read((ptr + 1) & 0xFF)
    local addr = lo + (hi << 8)
    cpu.A = cpu:read(addr)
    cpu:znupdate(cpu.A)
    return 6
  end,

  -- LDA (Indirect),Y
  [0xB1] = function(cpu)
    local zp = cpu:fetch()
    local lo = cpu:read(zp)
    local hi = cpu:read((zp + 1) & 0xFF)
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    cpu.A = cpu:read(addr)
    cpu:znupdate(cpu.A)
    local cycles = 5
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- LDX (Load X Register)
  -- LDX Immediate
  [0xA2] = function(cpu)
    cpu.X = cpu:fetch()
    cpu:znupdate(cpu.X)
    return 2
  end,

  -- LDX Zero Page
  [0xA6] = function(cpu)
    local addr = cpu:fetch()
    cpu.X = cpu:read(addr)
    cpu:znupdate(cpu.X)
    return 3
  end,

  -- LDX Zero Page,Y
  [0xB6] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.Y) & 0xFF
    cpu.X = cpu:read(addr)
    cpu:znupdate(cpu.X)
    return 4
  end,

  -- LDX Absolute
  [0xAE] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    cpu.X = cpu:read(addr)
    cpu:znupdate(cpu.X)
    return 4
  end,

  -- LDX Absolute,Y
  [0xBE] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    cpu.X = cpu:read(addr)
    cpu:znupdate(cpu.X)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- LDY (Load Y Register)
  -- LDY Immediate
  [0xA0] = function(cpu)
    cpu.Y = cpu:fetch()
    cpu:znupdate(cpu.Y)
    return 2
  end,

  -- LDY Zero Page
  [0xA4] = function(cpu)
    local addr = cpu:fetch()
    cpu.Y = cpu:read(addr)
    cpu:znupdate(cpu.Y)
    return 3
  end,

  -- LDY Zero Page,X
  [0xB4] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    cpu.Y = cpu:read(addr)
    cpu:znupdate(cpu.Y)
    return 4
  end,

  -- LDY Absolute
  [0xAC] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    cpu.Y = cpu:read(addr)
    cpu:znupdate(cpu.Y)
    return 4
  end,

  -- LDY Absolute,X
  [0xBC] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.X) & 0xFFFF
    cpu.Y = cpu:read(addr)
    cpu:znupdate(cpu.Y)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- LSR (Logical Shift Right)
  -- LSR Accumulator
  [0x4A] = function(cpu)
    local carry = cpu.A & 0x01
    cpu.A = (cpu.A >> 1) & 0xFF
    if carry ~= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(cpu.A)
    return 2
  end,

  -- LSR Zero Page
  [0x46] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    local carry = value & 0x01
    value = (value >> 1) & 0xFF
    cpu:write(addr, value)
    if carry ~= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 5
  end,

  -- LSR Zero Page,X
  [0x56] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = cpu:read(addr)
    local carry = value & 0x01
    value = (value >> 1) & 0xFF
    cpu:write(addr, value)
    if carry ~= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 6
  end,

  -- LSR Absolute
  [0x4E] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local carry = value & 0x01
    value = (value >> 1) & 0xFF
    cpu:write(addr, value)
    if carry ~= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 6
  end,

  -- LSR Absolute,X
  [0x5E] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = (lo + (hi << 8) + cpu.X) & 0xFFFF
    local value = cpu:read(addr)
    local carry = value & 0x01
    value = (value >> 1) & 0xFF
    cpu:write(addr, value)
    if carry ~= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 7
  end,

  -- NOP (No Operation)
  [0xEA] = function(cpu)
    return 2
  end,

  -- ORA (Logical Inclusive OR)
  -- ORA Immediate
  [0x09] = function(cpu)
    local value = cpu:fetch()
    cpu.A = cpu.A | value
    cpu:znupdate(cpu.A)
    return 2
  end,

  -- ORA Zero Page
  [0x05] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    cpu.A = cpu.A | value
    cpu:znupdate(cpu.A)
    return 3
  end,

  -- ORA Zero Page,X
  [0x15] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = cpu:read(addr)
    cpu.A = cpu.A | value
    cpu:znupdate(cpu.A)
    return 4
  end,

  -- ORA Absolute
  [0x0D] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    cpu.A = cpu.A | value
    cpu:znupdate(cpu.A)
    return 4
  end,

  -- ORA Absolute,X
  [0x1D] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.X) & 0xFFFF
    local value = cpu:read(addr)
    cpu.A = cpu.A | value
    cpu:znupdate(cpu.A)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- ORA Absolute,Y
  [0x19] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    cpu.A = cpu.A | value
    cpu:znupdate(cpu.A)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- ORA (Indirect,X)
  [0x01] = function(cpu)
    local zp = cpu:fetch()
    local ptr = (zp + cpu.X) & 0xFF
    local lo = cpu:read(ptr)
    local hi = cpu:read((ptr + 1) & 0xFF)
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    cpu.A = cpu.A | value
    cpu:znupdate(cpu.A)
    return 6
  end,

  -- ORA (Indirect),Y
  [0x11] = function(cpu)
    local zp = cpu:fetch()
    local lo = cpu:read(zp)
    local hi = cpu:read((zp + 1) & 0xFF)
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    cpu.A = cpu.A | value
    cpu:znupdate(cpu.A)
    local cycles = 5
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- PHA (Push Accumulator)
  [0x48] = function(cpu)
    cpu:push(cpu.A)
    return 3
  end,

  -- PHP (Push Processor Status)
  [0x08] = function(cpu)
    cpu:push(cpu.P | 0x10)
    return 3
  end,

  -- PLA (Pull Accumulator)
  [0x68] = function(cpu)
    cpu.A = cpu:pop()
    cpu:znupdate(cpu.A)
    return 4
  end,

  -- PLP (Pull Processor Status)
  [0x28] = function(cpu)
    cpu.P = (cpu:pop() & 0xEF) | 0x20
    return 4
  end,

  -- ROL (Rotate Left)
  -- ROL Accumulator
  [0x2A] = function(cpu)
    local carry_in = cpu.P & 0x01
    local new_carry = (cpu.A & 0x80) ~= 0 and 1 or 0
    cpu.A = ((cpu.A << 1) & 0xFF) | carry_in
    if new_carry == 1 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(cpu.A)
    return 2
  end,

  -- ROL Zero Page
  [0x26] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    local carry_in = cpu.P & 0x01
    local new_carry = (value & 0x80) ~= 0 and 1 or 0
    value = ((value << 1) & 0xFF) | carry_in
    cpu:write(addr, value)
    if new_carry == 1 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 5
  end,

  -- ROL Zero Page,X
  [0x36] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = cpu:read(addr)
    local carry_in = cpu.P & 0x01
    local new_carry = (value & 0x80) ~= 0 and 1 or 0
    value = ((value << 1) & 0xFF) | carry_in
    cpu:write(addr, value)
    if new_carry == 1 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 6
  end,

  -- ROL Absolute
  [0x2E] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local carry_in = cpu.P & 0x01
    local new_carry = (value & 0x80) ~= 0 and 1 or 0
    value = ((value << 1) & 0xFF) | carry_in
    cpu:write(addr, value)
    if new_carry == 1 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 6
  end,

  -- ROL Absolute,X
  [0x3E] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = (lo + (hi << 8) + cpu.X) & 0xFFFF
    local value = cpu:read(addr)
    local carry_in = cpu.P & 0x01
    local new_carry = (value & 0x80) ~= 0 and 1 or 0
    value = ((value << 1) & 0xFF) | carry_in
    cpu:write(addr, value)
    if new_carry == 1 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 7
  end,

  -- ROR (Rotate Right)
  -- ROR Accumulator
  [0x6A] = function(cpu)
    local carry_in = (cpu.P & 0x01) << 7
    local new_carry = cpu.A & 0x01
    cpu.A = (cpu.A >> 1) | carry_in
    if new_carry ~= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(cpu.A)
    return 2
  end,

  -- ROR Zero Page
  [0x66] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    local carry_in = (cpu.P & 0x01) << 7
    local new_carry = value & 0x01
    value = (value >> 1) | carry_in
    cpu:write(addr, value)
    if new_carry ~= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 5
  end,

  -- ROR Zero Page,X
  [0x76] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = cpu:read(addr)
    local carry_in = (cpu.P & 0x01) << 7
    local new_carry = value & 0x01
    value = (value >> 1) | carry_in
    cpu:write(addr, value)
    if new_carry ~= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 6
  end,

  -- ROR Absolute
  [0x6E] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local carry_in = (cpu.P & 0x01) << 7
    local new_carry = value & 0x01
    value = (value >> 1) | carry_in
    cpu:write(addr, value)
    if new_carry ~= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 6
  end,

  -- ROR Absolute,X
  [0x7E] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = (lo + (hi << 8) + cpu.X) & 0xFFFF
    local value = cpu:read(addr)
    local carry_in = (cpu.P & 0x01) << 7
    local new_carry = value & 0x01
    value = (value >> 1) | carry_in
    cpu:write(addr, value)
    if new_carry ~= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    cpu:znupdate(value)
    return 7
  end,

  -- RTI (Return from Interrupt)
  [0x40] = function(cpu)
    cpu.P = (cpu:pop() & 0xEF) | 0x20
    local lo = cpu:pop()
    local hi = cpu:pop()
    cpu.PC = lo + (hi << 8)
    return 6
  end,

  -- RTS (Return from Subroutine)
  [0x60] = function(cpu)
    local lo = cpu:pop()
    local hi = cpu:pop()
    cpu.PC = ((lo + (hi << 8)) + 1) & 0xFFFF
    return 6
  end,

  -- SBC (Subtract with Carry)
  -- SBC Immediate
  [0xE9] = function(cpu)
    local value = cpu:fetch()
    local carry = cpu.P & 0x01
    local A = cpu.A
    local diff = A - value - (1 - carry)
    local result = diff & 0xFF
    if diff >= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (A ~ value)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    return 2
  end,

  -- SBC Zero Page
  [0xE5] = function(cpu)
    local addr = cpu:fetch()
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local diff = A - value - (1 - carry)
    local result = diff & 0xFF
    if diff >= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (A ~ value)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    return 3
  end,

  -- SBC Zero Page,X
  [0xF5] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local diff = A - value - (1 - carry)
    local result = diff & 0xFF
    if diff >= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (A ~ value)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    return 4
  end,

  -- SBC Absolute
  [0xED] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local diff = A - value - (1 - carry)
    local result = diff & 0xFF
    if diff >= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (A ~ value)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    return 4
  end,

  -- SBC Absolute,X
  [0xFD] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.X) & 0xFFFF
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local diff = A - value - (1 - carry)
    local result = diff & 0xFF
    if diff >= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (A ~ value)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- SBC Absolute,Y
  [0xF9] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local diff = A - value - (1 - carry)
    local result = diff & 0xFF
    if diff >= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (A ~ value)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    local cycles = 4
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- SBC (Indirect,X)
  [0xE1] = function(cpu)
    local zp = cpu:fetch()
    local ptr = (zp + cpu.X) & 0xFF
    local lo = cpu:read(ptr)
    local hi = cpu:read((ptr + 1) & 0xFF)
    local addr = lo + (hi << 8)
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local diff = A - value - (1 - carry)
    local result = diff & 0xFF
    if diff >= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (A ~ value)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    return 6
  end,

  -- SBC (Indirect),Y
  [0xF1] = function(cpu)
    local zp = cpu:fetch()
    local lo = cpu:read(zp)
    local hi = cpu:read((zp + 1) & 0xFF)
    local base = lo + (hi << 8)
    local addr = (base + cpu.Y) & 0xFFFF
    local value = cpu:read(addr)
    local carry = cpu.P & 0x01
    local A = cpu.A
    local diff = A - value - (1 - carry)
    local result = diff & 0xFF
    if diff >= 0 then
      cpu.P = cpu.P | 0x01
    else
      cpu.P = cpu.P & 0xFE
    end
    if (((A ~ result) & (A ~ value)) & 0x80) ~= 0 then
      cpu.P = cpu.P | 0x40
    else
      cpu.P = cpu.P & 0xBF
    end
    cpu.A = result
    cpu:znupdate(result)
    local cycles = 5
    if (base & 0xFF00) ~= (addr & 0xFF00) then cycles = cycles + 1 end
    return cycles
  end,

  -- SEC (Set Carry)
  [0x38] = function(cpu)
    cpu.P = cpu.P | 0x01
    return 2
  end,

  -- SED (Set Decimal)
  [0xF8] = function(cpu)
    cpu.P = cpu.P | 0x08
    return 2
  end,

  -- SEI (Set Interrupt Disable)
  [0x78] = function(cpu)
    cpu.P = cpu.P | 0x04
    return 2
  end,

  -- STA (Store Accumulator)
  -- STA Zero Page
  [0x85] = function(cpu)
    local addr = cpu:fetch()
    cpu:write(addr, cpu.A)
    return 3
  end,

  -- STA Zero Page,X
  [0x95] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    cpu:write(addr, cpu.A)
    return 4
  end,

  -- STA Absolute
  [0x8D] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    cpu:write(addr, cpu.A)
    return 4
  end,

  -- STA Absolute,X
  [0x9D] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = (lo + (hi << 8) + cpu.X) & 0xFFFF
    cpu:write(addr, cpu.A)
    return 5
  end,

  -- STA Absolute,Y
  [0x99] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = (lo + (hi << 8) + cpu.Y) & 0xFFFF
    cpu:write(addr, cpu.A)
    return 5
  end,

  -- STA (Indirect,X)
  [0x81] = function(cpu)
    local zp = cpu:fetch()
    local ptr = (zp + cpu.X) & 0xFF
    local lo = cpu:read(ptr)
    local hi = cpu:read((ptr + 1) & 0xFF)
    local addr = lo + (hi << 8)
    cpu:write(addr, cpu.A)
    return 6
  end,

  -- STA (Indirect),Y
  [0x91] = function(cpu)
    local zp = cpu:fetch()
    local lo = cpu:read(zp)
    local hi = cpu:read((zp + 1) & 0xFF)
    local addr = (lo + (hi << 8) + cpu.Y) & 0xFFFF
    cpu:write(addr, cpu.A)
    return 6
  end,

  -- STX (Store X Register)
  -- STX Zero Page
  [0x86] = function(cpu)
    local addr = cpu:fetch()
    cpu:write(addr, cpu.X)
    return 3
  end,

  -- STX Zero Page,Y
  [0x96] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.Y) & 0xFF
    cpu:write(addr, cpu.X)
    return 4
  end,

  -- STX Absolute
  [0x8E] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    cpu:write(addr, cpu.X)
    return 4
  end,

  -- STY (Store Y Register)
  -- STY Zero Page
  [0x84] = function(cpu)
    local addr = cpu:fetch()
    cpu:write(addr, cpu.Y)
    return 3
  end,

  -- STY Zero Page,X
  [0x94] = function(cpu)
    local base = cpu:fetch()
    local addr = (base + cpu.X) & 0xFF
    cpu:write(addr, cpu.Y)
    return 4
  end,

  -- STY Absolute
  [0x8C] = function(cpu)
    local lo = cpu:fetch()
    local hi = cpu:fetch()
    local addr = lo + (hi << 8)
    cpu:write(addr, cpu.Y)
    return 4
  end,
}

local MOS6502 = {}
MOS6502.__index = MOS6502

function MOS6502.new()
  local self = setmetatable({}, MOS6502)
  self.A = 0       -- Accumulator
  self.X = 0       -- X Register
  self.Y = 0       -- Y Register
  self.SP = 0xFD   -- Stack Pointer
  self.PC = 0x0000 -- Program Counter
  self.P = 0x24    -- Processor Status
  self.cycles = 0  -- Cycle count
  self.halted = false

  self.memory = {}
  for i = 0, 0xFFFF do
    self.memory[i] = 0
  end

  return self
end

function MOS6502:read(addr)
  return self.memory[addr]
end

function MOS6502:write(addr, value)
  self.memory[addr] = value & 0xFF
end

function MOS6502:fetch()
  local pc = self.PC
  local byte = self.memory[pc]
  self.PC = (pc + 1) & 0xFFFF
  return byte
end

function MOS6502:znupdate(value)
  if value == 0 then
    self.P = self.P | 0x02
  else
    self.P = self.P & 0xFD
  end
  if (value & 0x80) ~= 0 then
    self.P = self.P | 0x80
  else
    self.P = self.P & 0x7F
  end
end

function MOS6502:step()
  local opcode = self:fetch()
  local op = opcodes[opcode]
  if op then
    self.cycles = self.cycles + op(self)
    return
  end
  error(string.format("opcode 0x%02X not implemented.", opcode))
end

function MOS6502:push(val)
  local sp = self.SP
  self:write(0x0100 + sp, val)
  self.SP = (sp - 1) & 0xFF
end

function MOS6502:pop()
  self.SP = (self.SP + 1) & 0xFF
  return self:read(0x0100 + self.SP)
end

function MOS6502:reset()
  local mem = self.memory
  self.PC = mem[0xFFFC] + (mem[0xFFFD] << 8)
  self.SP = 0xFD
  self.P = 0x24
end

function MOS6502:irq()
  local p = self.P
  if (p & 0x04) == 0 then
    local pc = self.PC
    self:push((pc >> 8) & 0xFF)
    self:push(pc & 0xFF)
    self:push((p & 0xEF) | 0x20)
    self.P = p | 0x04
    local mem = self.memory
    self.PC = mem[0xFFFE] + (mem[0xFFFF] << 8)
    self.cycles = self.cycles + 7
  end
end

function MOS6502:nmi()
  local p = self.P
  local pc = self.PC
  self:push((pc >> 8) & 0xFF)
  self:push(pc & 0xFF)
  self:push((p & 0xEF) | 0x20)
  self.P = p | 0x04
  local mem = self.memory
  self.PC = mem[0xFFFA] + (mem[0xFFFB] << 8)
  self.cycles = self.cycles + 8
end

return MOS6502
