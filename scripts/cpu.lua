local bit = bit or bit32
local band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
local lshift, rshift = bit.lshift, bit.rshift

local cpu = {}

local a, x, y, sp, pc
local status
local cycles
local bus

local FLAG_C = 0x01
local FLAG_Z = 0x02
local FLAG_I = 0x04
local FLAG_D = 0x08
local FLAG_B = 0x10
local FLAG_U = 0x20
local FLAG_V = 0x40
local FLAG_N = 0x80

local function set_flag(flag, cond)
    if cond then
        status = bor(status, flag)
    else
        status = band(status, bxor(0xFF, flag))
    end
end

local function get_flag(flag)
    return band(status, flag) ~= 0
end

local function set_zn(value)
    set_flag(FLAG_Z, value == 0)
    set_flag(FLAG_N, band(value, 0x80) ~= 0)
    return value
end

local function push(value)
    bus.write(0x0100 + sp, value)
    sp = band(sp - 1, 0xFF)
end

local function pull()
    sp = band(sp + 1, 0xFF)
    return bus.read(0x0100 + sp)
end

local function push16(value)
    push(rshift(value, 8))
    push(band(value, 0xFF))
end

local function pull16()
    local lo = pull()
    local hi = pull()
    return bor(lo, lshift(hi, 8))
end

local addr_mode
local addr_value
local page_crossed

local function imp() end
local function acc() end

local function imm()
    addr_value = pc
    pc = band(pc + 1, 0xFFFF)
end

local function zp()
    addr_value = bus.read(pc)
    pc = band(pc + 1, 0xFFFF)
end

local function zpx()
    addr_value = band(bus.read(pc) + x, 0xFF)
    pc = band(pc + 1, 0xFFFF)
end

local function zpy()
    addr_value = band(bus.read(pc) + y, 0xFF)
    pc = band(pc + 1, 0xFFFF)
end

local function abs()
    addr_value = bus.read16(pc)
    pc = band(pc + 2, 0xFFFF)
end

local function abx()
    local base = bus.read16(pc)
    addr_value = band(base + x, 0xFFFF)
    page_crossed = band(base, 0xFF00) ~= band(addr_value, 0xFF00)
    pc = band(pc + 2, 0xFFFF)
end

local function aby()
    local base = bus.read16(pc)
    addr_value = band(base + y, 0xFFFF)
    page_crossed = band(base, 0xFF00) ~= band(addr_value, 0xFF00)
    pc = band(pc + 2, 0xFFFF)
end

local function ind()
    local ptr = bus.read16(pc)
    addr_value = bus.read16_wrap(ptr)
    pc = band(pc + 2, 0xFFFF)
end

local function izx()
    local base = band(bus.read(pc) + x, 0xFF)
    local lo = bus.read(base)
    local hi = bus.read(band(base + 1, 0xFF))
    addr_value = bor(lo, lshift(hi, 8))
    pc = band(pc + 1, 0xFFFF)
end

local function izy()
    local base = bus.read(pc)
    local lo = bus.read(base)
    local hi = bus.read(band(base + 1, 0xFF))
    local addr = bor(lo, lshift(hi, 8))
    addr_value = band(addr + y, 0xFFFF)
    page_crossed = band(addr, 0xFF00) ~= band(addr_value, 0xFF00)
    pc = band(pc + 1, 0xFFFF)
end

local function rel()
    local offset = bus.read(pc)
    pc = band(pc + 1, 0xFFFF)
    if offset >= 128 then
        offset = offset - 256
    end
    addr_value = band(pc + offset, 0xFFFF)
end

local function read_op()
    return bus.read(addr_value)
end

local function write_op(v)
    bus.write(addr_value, v)
end

local function adc()
    local m = read_op()
    local c = get_flag(FLAG_C) and 1 or 0
    local sum = a + m + c
    set_flag(FLAG_C, sum > 255)
    set_flag(FLAG_V, band(bxor(a, sum), bxor(m, sum), 0x80) ~= 0)
    a = set_zn(band(sum, 0xFF))
end

local function op_and()
    a = set_zn(band(a, read_op()))
end

local function asl_a()
    set_flag(FLAG_C, band(a, 0x80) ~= 0)
    a = set_zn(band(lshift(a, 1), 0xFF))
end

local function asl()
    local m = read_op()
    set_flag(FLAG_C, band(m, 0x80) ~= 0)
    write_op(set_zn(band(lshift(m, 1), 0xFF)))
end

local function branch(cond)
    if cond then
        cycles = cycles + 1
        if band(pc, 0xFF00) ~= band(addr_value, 0xFF00) then
            cycles = cycles + 1
        end
        pc = addr_value
    end
end

local function bcc() branch(not get_flag(FLAG_C)) end
local function bcs() branch(get_flag(FLAG_C)) end
local function beq() branch(get_flag(FLAG_Z)) end
local function bmi() branch(get_flag(FLAG_N)) end
local function bne() branch(not get_flag(FLAG_Z)) end
local function bpl() branch(not get_flag(FLAG_N)) end
local function bvc() branch(not get_flag(FLAG_V)) end
local function bvs() branch(get_flag(FLAG_V)) end

local function op_bit()
    local m = read_op()
    set_flag(FLAG_Z, band(a, m) == 0)
    set_flag(FLAG_V, band(m, 0x40) ~= 0)
    set_flag(FLAG_N, band(m, 0x80) ~= 0)
end

local function brk()
    pc = band(pc + 1, 0xFFFF)
    push16(pc)
    push(bor(status, FLAG_B, FLAG_U))
    set_flag(FLAG_I, true)
    pc = bus.read16(0xFFFE)
end

local function clc() set_flag(FLAG_C, false) end
local function cld() set_flag(FLAG_D, false) end
local function cli() set_flag(FLAG_I, false) end
local function clv() set_flag(FLAG_V, false) end

local function cmp()
    local m = read_op()
    set_flag(FLAG_C, a >= m)
    set_zn(band(a - m, 0xFF))
end

local function cpx()
    local m = read_op()
    set_flag(FLAG_C, x >= m)
    set_zn(band(x - m, 0xFF))
end

local function cpy()
    local m = read_op()
    set_flag(FLAG_C, y >= m)
    set_zn(band(y - m, 0xFF))
end

local function dec()
    write_op(set_zn(band(read_op() - 1, 0xFF)))
end

local function dex()
    x = set_zn(band(x - 1, 0xFF))
end

local function dey()
    y = set_zn(band(y - 1, 0xFF))
end

local function eor()
    a = set_zn(bxor(a, read_op()))
end

local function inc()
    write_op(set_zn(band(read_op() + 1, 0xFF)))
end

local function inx()
    x = set_zn(band(x + 1, 0xFF))
end

local function iny()
    y = set_zn(band(y + 1, 0xFF))
end

local function jmp()
    pc = addr_value
end

local function jsr()
    push16(band(pc - 1, 0xFFFF))
    pc = addr_value
end

local function lda()
    a = set_zn(read_op())
end

local function ldx()
    x = set_zn(read_op())
end

local function ldy()
    y = set_zn(read_op())
end

local function lsr_a()
    set_flag(FLAG_C, band(a, 0x01) ~= 0)
    a = set_zn(rshift(a, 1))
end

local function lsr()
    local m = read_op()
    set_flag(FLAG_C, band(m, 0x01) ~= 0)
    write_op(set_zn(rshift(m, 1)))
end

local function nop() end

local function ora()
    a = set_zn(bor(a, read_op()))
end

local function pha()
    push(a)
end

local function php()
    push(bor(status, FLAG_B, FLAG_U))
end

local function pla()
    a = set_zn(pull())
end

local function plp()
    status = bor(band(pull(), 0xEF), FLAG_U)
end

local function rol_a()
    local c = get_flag(FLAG_C) and 1 or 0
    set_flag(FLAG_C, band(a, 0x80) ~= 0)
    a = set_zn(band(bor(lshift(a, 1), c), 0xFF))
end

local function rol()
    local m = read_op()
    local c = get_flag(FLAG_C) and 1 or 0
    set_flag(FLAG_C, band(m, 0x80) ~= 0)
    write_op(set_zn(band(bor(lshift(m, 1), c), 0xFF)))
end

local function ror_a()
    local c = get_flag(FLAG_C) and 0x80 or 0
    set_flag(FLAG_C, band(a, 0x01) ~= 0)
    a = set_zn(bor(rshift(a, 1), c))
end

local function ror()
    local m = read_op()
    local c = get_flag(FLAG_C) and 0x80 or 0
    set_flag(FLAG_C, band(m, 0x01) ~= 0)
    write_op(set_zn(bor(rshift(m, 1), c)))
end

local function rti()
    status = bor(band(pull(), 0xEF), FLAG_U)
    pc = pull16()
end

local function rts()
    pc = band(pull16() + 1, 0xFFFF)
end

local function sbc()
    local m = read_op()
    local c = get_flag(FLAG_C) and 0 or 1
    local diff = a - m - c
    set_flag(FLAG_C, diff >= 0)
    set_flag(FLAG_V, band(bxor(a, diff), bxor(a, m), 0x80) ~= 0)
    a = set_zn(band(diff, 0xFF))
end

local function sec() set_flag(FLAG_C, true) end
local function sed() set_flag(FLAG_D, true) end
local function sei() set_flag(FLAG_I, true) end

local function sta()
    write_op(a)
end

local function stx()
    write_op(x)
end

local function sty()
    write_op(y)
end

local function tax()
    x = set_zn(a)
end

local function tay()
    y = set_zn(a)
end

local function tsx()
    x = set_zn(sp)
end

local function txa()
    a = set_zn(x)
end

local function txs()
    sp = x
end

local function tya()
    a = set_zn(y)
end

local function ill()
end

local opcodes = {
    [0x00] = {brk, imp, 7}, [0x01] = {ora, izx, 6}, [0x05] = {ora, zp, 3},
    [0x06] = {asl, zp, 5}, [0x08] = {php, imp, 3}, [0x09] = {ora, imm, 2},
    [0x0A] = {asl_a, acc, 2}, [0x0D] = {ora, abs, 4}, [0x0E] = {asl, abs, 6},
    [0x10] = {bpl, rel, 2}, [0x11] = {ora, izy, 5}, [0x15] = {ora, zpx, 4},
    [0x16] = {asl, zpx, 6}, [0x18] = {clc, imp, 2}, [0x19] = {ora, aby, 4},
    [0x1D] = {ora, abx, 4}, [0x1E] = {asl, abx, 7},
    [0x20] = {jsr, abs, 6}, [0x21] = {op_and, izx, 6}, [0x24] = {op_bit, zp, 3},
    [0x25] = {op_and, zp, 3}, [0x26] = {rol, zp, 5}, [0x28] = {plp, imp, 4},
    [0x29] = {op_and, imm, 2}, [0x2A] = {rol_a, acc, 2}, [0x2C] = {op_bit, abs, 4},
    [0x2D] = {op_and, abs, 4}, [0x2E] = {rol, abs, 6},
    [0x30] = {bmi, rel, 2}, [0x31] = {op_and, izy, 5}, [0x35] = {op_and, zpx, 4},
    [0x36] = {rol, zpx, 6}, [0x38] = {sec, imp, 2}, [0x39] = {op_and, aby, 4},
    [0x3D] = {op_and, abx, 4}, [0x3E] = {rol, abx, 7},
    [0x40] = {rti, imp, 6}, [0x41] = {eor, izx, 6}, [0x45] = {eor, zp, 3},
    [0x46] = {lsr, zp, 5}, [0x48] = {pha, imp, 3}, [0x49] = {eor, imm, 2},
    [0x4A] = {lsr_a, acc, 2}, [0x4C] = {jmp, abs, 3}, [0x4D] = {eor, abs, 4},
    [0x4E] = {lsr, abs, 6},
    [0x50] = {bvc, rel, 2}, [0x51] = {eor, izy, 5}, [0x55] = {eor, zpx, 4},
    [0x56] = {lsr, zpx, 6}, [0x58] = {cli, imp, 2}, [0x59] = {eor, aby, 4},
    [0x5D] = {eor, abx, 4}, [0x5E] = {lsr, abx, 7},
    [0x60] = {rts, imp, 6}, [0x61] = {adc, izx, 6}, [0x65] = {adc, zp, 3},
    [0x66] = {ror, zp, 5}, [0x68] = {pla, imp, 4}, [0x69] = {adc, imm, 2},
    [0x6A] = {ror_a, acc, 2}, [0x6C] = {jmp, ind, 5}, [0x6D] = {adc, abs, 4},
    [0x6E] = {ror, abs, 6},
    [0x70] = {bvs, rel, 2}, [0x71] = {adc, izy, 5}, [0x75] = {adc, zpx, 4},
    [0x76] = {ror, zpx, 6}, [0x78] = {sei, imp, 2}, [0x79] = {adc, aby, 4},
    [0x7D] = {adc, abx, 4}, [0x7E] = {ror, abx, 7},
    [0x81] = {sta, izx, 6}, [0x84] = {sty, zp, 3}, [0x85] = {sta, zp, 3},
    [0x86] = {stx, zp, 3}, [0x88] = {dey, imp, 2}, [0x8A] = {txa, imp, 2},
    [0x8C] = {sty, abs, 4}, [0x8D] = {sta, abs, 4}, [0x8E] = {stx, abs, 4},
    [0x90] = {bcc, rel, 2}, [0x91] = {sta, izy, 6}, [0x94] = {sty, zpx, 4},
    [0x95] = {sta, zpx, 4}, [0x96] = {stx, zpy, 4}, [0x98] = {tya, imp, 2},
    [0x99] = {sta, aby, 5}, [0x9A] = {txs, imp, 2}, [0x9D] = {sta, abx, 5},
    [0xA0] = {ldy, imm, 2}, [0xA1] = {lda, izx, 6}, [0xA2] = {ldx, imm, 2},
    [0xA4] = {ldy, zp, 3}, [0xA5] = {lda, zp, 3}, [0xA6] = {ldx, zp, 3},
    [0xA8] = {tay, imp, 2}, [0xA9] = {lda, imm, 2}, [0xAA] = {tax, imp, 2},
    [0xAC] = {ldy, abs, 4}, [0xAD] = {lda, abs, 4}, [0xAE] = {ldx, abs, 4},
    [0xB0] = {bcs, rel, 2}, [0xB1] = {lda, izy, 5}, [0xB4] = {ldy, zpx, 4},
    [0xB5] = {lda, zpx, 4}, [0xB6] = {ldx, zpy, 4}, [0xB8] = {clv, imp, 2},
    [0xB9] = {lda, aby, 4}, [0xBA] = {tsx, imp, 2}, [0xBC] = {ldy, abx, 4},
    [0xBD] = {lda, abx, 4}, [0xBE] = {ldx, aby, 4},
    [0xC0] = {cpy, imm, 2}, [0xC1] = {cmp, izx, 6}, [0xC4] = {cpy, zp, 3},
    [0xC5] = {cmp, zp, 3}, [0xC6] = {dec, zp, 5}, [0xC8] = {iny, imp, 2},
    [0xC9] = {cmp, imm, 2}, [0xCA] = {dex, imp, 2}, [0xCC] = {cpy, abs, 4},
    [0xCD] = {cmp, abs, 4}, [0xCE] = {dec, abs, 6},
    [0xD0] = {bne, rel, 2}, [0xD1] = {cmp, izy, 5}, [0xD5] = {cmp, zpx, 4},
    [0xD6] = {dec, zpx, 6}, [0xD8] = {cld, imp, 2}, [0xD9] = {cmp, aby, 4},
    [0xDD] = {cmp, abx, 4}, [0xDE] = {dec, abx, 7},
    [0xE0] = {cpx, imm, 2}, [0xE1] = {sbc, izx, 6}, [0xE4] = {cpx, zp, 3},
    [0xE5] = {sbc, zp, 3}, [0xE6] = {inc, zp, 5}, [0xE8] = {inx, imp, 2},
    [0xE9] = {sbc, imm, 2}, [0xEA] = {nop, imp, 2}, [0xEC] = {cpx, abs, 4},
    [0xED] = {sbc, abs, 4}, [0xEE] = {inc, abs, 6},
    [0xF0] = {beq, rel, 2}, [0xF1] = {sbc, izy, 5}, [0xF5] = {sbc, zpx, 4},
    [0xF6] = {inc, zpx, 6}, [0xF8] = {sed, imp, 2}, [0xF9] = {sbc, aby, 4},
    [0xFD] = {sbc, abx, 4}, [0xFE] = {inc, abx, 7}
}

for i = 0, 255 do
    if not opcodes[i] then
        opcodes[i] = {ill, imp, 2}
    end
end

function cpu.init(b)
    bus = b
    a = 0
    x = 0
    y = 0
    sp = 0xFD
    status = bor(FLAG_U, FLAG_I)
    pc = bus.read16(0xFFFC)
    cycles = 0
end

function cpu.reset()
    sp = band(sp - 3, 0xFF)
    set_flag(FLAG_I, true)
    pc = bus.read16(0xFFFC)
end

function cpu.nmi()
    push16(pc)
    push(band(status, bxor(0xFF, FLAG_B)))
    set_flag(FLAG_I, true)
    pc = bus.read16(0xFFFA)
    cycles = cycles + 7
end

function cpu.irq()
    if not get_flag(FLAG_I) then
        push16(pc)
        push(band(status, bxor(0xFF, FLAG_B)))
        set_flag(FLAG_I, true)
        pc = bus.read16(0xFFFE)
        cycles = cycles + 7
    end
end

function cpu.step()
    local opcode = bus.read(pc)
    pc = band(pc + 1, 0xFFFF)

    local op = opcodes[opcode]
    local exec, mode, base_cycles = op[1], op[2], op[3]

    page_crossed = false
    mode()
    exec()

    cycles = base_cycles
    if page_crossed and (opcode == 0x11 or opcode == 0x19 or opcode == 0x1D or
                         opcode == 0x31 or opcode == 0x39 or opcode == 0x3D or
                         opcode == 0x51 or opcode == 0x59 or opcode == 0x5D or
                         opcode == 0x71 or opcode == 0x79 or opcode == 0x7D or
                         opcode == 0xB1 or opcode == 0xB9 or opcode == 0xBD or
                         opcode == 0xBE or opcode == 0xBC or
                         opcode == 0xD1 or opcode == 0xD9 or opcode == 0xDD or
                         opcode == 0xF1 or opcode == 0xF9 or opcode == 0xFD) then
        cycles = cycles + 1
    end

    local dma = bus.get_dma_cycles()
    cycles = cycles + dma

    return cycles
end

function cpu.get_pc()
    return pc
end

return cpu
