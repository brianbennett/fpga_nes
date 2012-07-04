----------------------------------------------------------------------------------------------------
-- Script:      cpu_rand.lua
-- Description: CPU test.  Random tests.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local numSubtests = 20
local instructionsPerSubtest = 1000

local swEmuState =
{
  ac    = 0,
  x     = 0,
  y     = 0,
  s     = 0,
  c     = false,
  z     = false,
  i     = false,
  d     = false,
  v     = false,
  n     = false,
  ram   = {},
}

-- GenRand1ByteInst(): Generate a "random" 1 byte instruction.
local function GenRand1ByteInst(op, code, curOffset)
  code[curOffset] = op

  return curOffset + 1
end

-- GenRand2ByteInst(): Generate a random 2 byte instruction (op followed by 0-255 rand byte)
local function GenRand2ByteInst(op, code, curOffset)
  code[curOffset]     = op
  code[curOffset + 1] = math.random(0,255)

  return curOffset + 2
end

-- GenRandAbsAddrInst(): Generate a random 3 byte absolute addressing instruction.  For testing
-- purposes, absolute addresses are confined to 0x0200 - 0x07FF (ram range).
local function GenRandAbsAddrInst(op, code, curOffset)
  code[curOffset]     = op
  code[curOffset + 1] = math.random(0,255)
  code[curOffset + 2] = math.random(2,7)

  return curOffset + 3
end

-- GenRandAbsAddrIdxInst(): Generate a random 3 byte absolute addressing w/ indexing instruction.
-- For testing purposes, absolute addresses are confined to 0x0200 - 0x06FF (ram range).  Smaller
-- range than GenRandAbsAddrInst() to allow for an index of up to 255 to be added.
local function GenRandAbsAddrIdxInst(op, code, curOffset)
  code[curOffset]     = op
  code[curOffset + 1] = math.random(0,255)
  code[curOffset + 2] = math.random(2,6)

  return curOffset + 3
end

-- GenRandIndxInst(): Generates a random (Indirect,X) instruction.  In order to prevent this from
-- reading invalid memory, it is always preceded by a STA instruction to write the high word of the
-- final address to a random (2 - 7) so we will load/store from the 0x200 - 0x7FF range.
local function GenRandIndxInst(op, code, curOffset)
  local addr = math.random(0,255)
  local x = math.random(0,255)

  code[curOffset]     = Ops.LDX_IMM
  code[curOffset + 1] = x

  code[curOffset + 2] = Ops.LDY_IMM
  code[curOffset + 3] = math.random(2,7)

  code[curOffset + 4] = Ops.STY_ZP
  code[curOffset + 5] = (addr + x + 1) % 256

  code[curOffset + 6] = op
  code[curOffset + 7] = addr

  return curOffset + 8
end

-- GenRandIndyInst(): Generates a random (Indirect),Y instruction.  In order to prevent this from
-- reading invalid memory, it is always preceded by a STA instruction to write the high word of the
-- indirect address to a random (2 - 6) so we will load/store from the 0x200 - 0x7FF range.
local function GenRandIndyInst(op, code, curOffset)
  local addr = math.random(0,255)

  code[curOffset]     = Ops.LDX_IMM
  code[curOffset + 1] = math.random(2,6)

  code[curOffset + 2] = Ops.STX_ZP
  code[curOffset + 3] = (addr + 1) % 256

  code[curOffset + 4] = op
  code[curOffset + 5] = addr

  return curOffset + 6
end

-- UpdateZ(): Update processor status register Z bit based on val.
local function UpdateZ(val)
  if val == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end
end

-- UpdateN(): Update processor status register N bit based on val.
local function UpdateN(val)
  if val > 127 then
    swEmuState.n = true
  else
    swEmuState.n = false
  end
end

-- ExecuteAdc(): Meat of ADC instruction, shared regardless of addressing mode.
local function ExecuteAdc(a, m)
  local cin = 0
  if swEmuState.c then
    cin = 1
  end

  local result = a + m + cin

  swEmuState.ac = result % 256

  if result >= 256 then
    swEmuState.c = true
  else
    swEmuState.c = false
  end

  if swEmuState.ac == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end

  if swEmuState.ac >= 128 then
    swEmuState.n = true
  else
    swEmuState.n = false
  end

  -- Overflow detection
  local a2c = a
  local m2c = m

  if a >= 128 then
    a2c = -(256 - a)
  end
  if m >= 128 then
    m2c = -(256 - m)
  end

  local result2c = a2c + m2c + cin
  if (result2c < -128) or (result2c > 127) then
    swEmuState.v = true
  else
    swEmuState.v = false
  end
end

-- EmulateAdcAbs(): Emulate an ADC_ABS instruction.
local function EmulateAdcAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  ExecuteAdc(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateAdcAbsx(): Emulate an ADC_ABSX instruction.
local function EmulateAdcAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  ExecuteAdc(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateAdcAbsy(): Emulate an ADC_ABSY instruction.
local function EmulateAdcAbsy(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.y
  ExecuteAdc(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateAdcImm(): Emulate an ADC_IMM instruction.
local function EmulateAdcImm(code, curOffset)
  local arg = code[curOffset + 1]
  ExecuteAdc(swEmuState.ac, arg)

  return curOffset + 2
end

-- EmulateAdcIndx(): Emulate an ADC_INDX instruction.
local function EmulateAdcIndx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[(addr + 1) % 256 + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo

  ExecuteAdc(swEmuState.ac, swEmuState.ram[indAddr + 1])

  return curOffset + 2
end

-- EmulateAdcIndy(): Emulate an ADC_INDY instruction.
local function EmulateAdcIndy(code, curOffset)
  local addr = code[curOffset + 1]

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[((addr + 1) % 256) + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo + swEmuState.y

  ExecuteAdc(swEmuState.ac, swEmuState.ram[indAddr + 1])

  return curOffset + 2
end

-- EmulateAdcZp(): Emulate an ADC_ZP instruction.
local function EmulateAdcZp(code, curOffset)
  local addr = code[curOffset + 1]
  ExecuteAdc(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateAdcZpx(): Emulate an ADC_ZPX instruction.
local function EmulateAdcZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  ExecuteAdc(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- ComputeAndResult(): Meat of AND calculation, shared regardless of addressing mode.
local function ComputeAndResult(arg1, arg2)
  local result = 0
  local divisor = 1

  for i = 1,8 do
    local arg1Bit = math.floor(arg1 / divisor) % 2
    local arg2Bit = math.floor(arg2 / divisor) % 2

    if arg1Bit ~= 0 and arg2Bit ~= 0 then
      result = result + divisor
    end

    divisor = divisor * 2
  end

  return result
end

-- EmulateAndAbs(): Emulate an AND_ABS instruction.
local function EmulateAndAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ac = ComputeAndResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateAndAbsx(): Emulate an AND_ABSX instruction.
local function EmulateAndAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ac = ComputeAndResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateAndAbsy(): Emulate an AND_ABSY instruction.
local function EmulateAndAbsy(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.y
  swEmuState.ac = ComputeAndResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateAndImm(): Emulate an AND_IMM instruction.
local function EmulateAndImm(code, curOffset)
  local arg = code[curOffset + 1]
  swEmuState.ac = ComputeAndResult(swEmuState.ac, arg)

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateAndIndx(): Emulate an AND_INDX instruction.
local function EmulateAndIndx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[(addr + 1) % 256 + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo

  swEmuState.ac = ComputeAndResult(swEmuState.ac, swEmuState.ram[indAddr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateAndIndy(): Emulate an AND_INDY instruction.
local function EmulateAndIndy(code, curOffset)
  local addr = code[curOffset + 1]

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[((addr + 1) % 256) + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo + swEmuState.y

  swEmuState.ac = ComputeAndResult(swEmuState.ac, swEmuState.ram[indAddr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateAndZp(): Emulate an AND_ZP instruction.
local function EmulateAndZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ac = ComputeAndResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateAndZpx(): Emulate an AND_ZPX instruction.
local function EmulateAndZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ac = ComputeAndResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- ExecuteAsl(): Meat of ASL instruction, shared regardless of addressing mode.
local function ExecuteAsl(m)
  local result = (m * 2) % 256

  if m * 2 >= 256 then
    swEmuState.c = true
  else
    swEmuState.c = false
  end

  if result == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end

  if result > 127 then
    swEmuState.n = true
  else
    swEmuState.n = false
  end

  return result
end

-- EmulateAslAbs(): Emulate an ASL_ABS instruction.
local function EmulateAslAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteAsl(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateAslAbsx(): Emulate an ASL_ABSX instruction.
local function EmulateAslAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ram[addr + 1] = ExecuteAsl(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateAslAcc(): Emulate an ASL_ACC instruction.
local function EmulateAslAcc(code, curOffset)
  swEmuState.ac = ExecuteAsl(swEmuState.ac)

  return curOffset + 1
end

-- EmulateAslZp(): Emulate an ASL_ZP instruction.
local function EmulateAslZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteAsl(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateAslZpx(): Emulate an ASL_ZPX instruction.
local function EmulateAslZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ram[addr + 1] = ExecuteAsl(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- ExecuteBit(): Meat of BIT instruction, shared regardless of addressing mode.
local function ExecuteBit(a, m)
  local result = 0
  local divisor = 1

  for i = 1,8 do
    local arg1Bit = math.floor(a / divisor) % 2
    local arg2Bit = math.floor(m / divisor) % 2

    if arg1Bit ~= 0 and arg2Bit ~= 0 then
      result = result + divisor
    end

    divisor = divisor * 2
  end

  if result == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end

  if m >= 128 then
    swEmuState.n = true
  else
    swEmuState.n = false
  end

  if (m % 128) >= 64 then
    swEmuState.v = true
  else
    swEmuState.v = false
  end
end

-- EmulateBitAbs(): Emulate an BIT_ABS instruction.
local function EmulateBitAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  ExecuteBit(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateBitZp(): Emulate an BIT_ZP instruction.
local function EmulateBitZp(code, curOffset)
  local addr = code[curOffset + 1]
  ExecuteBit(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateClc(): Emulate a CLC instruction.
local function EmulateClc(code, curOffset)
  swEmuState.c = false

  return curOffset + 1
end

-- EmulateCld(): Emulate a CLD instruction.
local function EmulateCld(code, curOffset)
  swEmuState.d = false

  return curOffset + 1
end

-- EmulateCli(): Emulate a CLI instruction.
local function EmulateCli(code, curOffset)
  swEmuState.i = false

  return curOffset + 1
end

-- EmulateClv(): Emulate a CLV instruction.
local function EmulateClv(code, curOffset)
  swEmuState.v = false

  return curOffset + 1
end

-- ExecuteCmp(): Meat of CMP instruction, shared regardless of addressing mode.
local function ExecuteCmp(a, m)
  local result = a - m

  if result >= 0 then
    swEmuState.c = true
  else
    swEmuState.c = false
  end

  if result == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end

  if (result < 0 and result >= -128) or (result >= 128) then
    swEmuState.n = true
  else
    swEmuState.n = false
  end
end

-- EmulateCmpAbs(): Emulate an CMP_ABS instruction.
local function EmulateCmpAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  ExecuteCmp(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateCmpAbsx(): Emulate an CMP_ABSX instruction.
local function EmulateCmpAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  ExecuteCmp(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateCmpAbsy(): Emulate an CMP_ABSY instruction.
local function EmulateCmpAbsy(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.y
  ExecuteCmp(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateCmpImm(): Emulate an CMP_IMM instruction.
local function EmulateCmpImm(code, curOffset)
  local arg = code[curOffset + 1]
  ExecuteCmp(swEmuState.ac, arg)

  return curOffset + 2
end

-- EmulateCmpIndx(): Emulate an CMP_INDX instruction.
local function EmulateCmpIndx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[(addr + 1) % 256 + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo

  ExecuteCmp(swEmuState.ac, swEmuState.ram[indAddr + 1])

  return curOffset + 2
end

-- EmulateCmpIndy(): Emulate an CMP_INDY instruction.
local function EmulateCmpIndy(code, curOffset)
  local addr = code[curOffset + 1]

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[((addr + 1) % 256) + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo + swEmuState.y

  ExecuteCmp(swEmuState.ac, swEmuState.ram[indAddr + 1])

  return curOffset + 2
end

-- EmulateCmpZp(): Emulate an CMP_ZP instruction.
local function EmulateCmpZp(code, curOffset)
  local addr = code[curOffset + 1]
  ExecuteCmp(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateCmpZpx(): Emulate an CMP_ZPX instruction.
local function EmulateCmpZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  ExecuteCmp(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateCpxAbs(): Emulate an CPX_ABS instruction.
local function EmulateCpxAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  ExecuteCmp(swEmuState.x, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateCpxImm(): Emulate an CPX_IMM instruction.
local function EmulateCpxImm(code, curOffset)
  local arg = code[curOffset + 1]
  ExecuteCmp(swEmuState.x, arg)

  return curOffset + 2
end

-- EmulateCpxZp(): Emulate an CPX_ZP instruction.
local function EmulateCpxZp(code, curOffset)
  local addr = code[curOffset + 1]
  ExecuteCmp(swEmuState.x, swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateCpyAbs(): Emulate an CPY_ABS instruction.
local function EmulateCpyAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  ExecuteCmp(swEmuState.y, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateCpyImm(): Emulate an CPY_IMM instruction.
local function EmulateCpyImm(code, curOffset)
  local arg = code[curOffset + 1]
  ExecuteCmp(swEmuState.y, arg)

  return curOffset + 2
end

-- EmulateCpyZp(): Emulate an CPY_ZP instruction.
local function EmulateCpyZp(code, curOffset)
  local addr = code[curOffset + 1]
  ExecuteCmp(swEmuState.y, swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- ExecuteDec(): Meat of DEC instruction, shared regardless of addressing mode.
local function ExecuteDec(m)
  local result = 255

  if m > 0 then
    result = m - 1
  end

  if result == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end

  if result > 127 then
    swEmuState.n = true
  else
    swEmuState.n = false
  end

  return result
end

-- EmulateDecAbs(): Emulate an DEC_ABS instruction.
local function EmulateDecAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteDec(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateDecAbsx(): Emulate an DEC_ABSX instruction.
local function EmulateDecAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ram[addr + 1] = ExecuteDec(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateDecZp(): Emulate an DEC_ZP instruction.
local function EmulateDecZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteDec(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateDecZpx(): Emulate an DEC_ZPX instruction.
local function EmulateDecZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ram[addr + 1] = ExecuteDec(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateDex(): Emulate a DEX instruction.
local function EmulateDex(code, curOffset)
  swEmuState.x = ExecuteDec(swEmuState.x)

  return curOffset + 1
end

-- EmulateDey(): Emulate a DEY instruction.
local function EmulateDey(code, curOffset)
  swEmuState.y = ExecuteDec(swEmuState.y)

  return curOffset + 1
end

-- ComputeEorResult(): Meat of EOR calculation, shared regardless of addressing mode.
local function ComputeEorResult(arg1, arg2)
  local result = 0
  local divisor = 1

  for i = 1,8 do
    local arg1Bit = math.floor(arg1 / divisor) % 2
    local arg2Bit = math.floor(arg2 / divisor) % 2

    if arg1Bit ~= arg2Bit then
      result = result + divisor
    end

    divisor = divisor * 2
  end

  return result
end

-- EmulateEorAbs(): Emulate an EOR_ABS instruction.
local function EmulateEorAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ac = ComputeEorResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateEorAbsx(): Emulate an EOR_ABSX instruction.
local function EmulateEorAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ac = ComputeEorResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateEorAbsy(): Emulate an EOR_ABSY instruction.
local function EmulateEorAbsy(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.y
  swEmuState.ac = ComputeEorResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateEorImm(): Emulate an EOR_IMM instruction.
local function EmulateEorImm(code, curOffset)
  local arg = code[curOffset + 1]
  swEmuState.ac = ComputeEorResult(swEmuState.ac, arg)

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateEorIndx(): Emulate an EOR_INDX instruction.
local function EmulateEorIndx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[(addr + 1) % 256 + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo

  swEmuState.ac = ComputeEorResult(swEmuState.ac, swEmuState.ram[indAddr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateEorIndy(): Emulate an EOR_INDY instruction.
local function EmulateEorIndy(code, curOffset)
  local addr = code[curOffset + 1]

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[((addr + 1) % 256) + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo + swEmuState.y

  swEmuState.ac = ComputeEorResult(swEmuState.ac, swEmuState.ram[indAddr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateEorZp(): Emulate an EOR_ZP instruction.
local function EmulateEorZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ac = ComputeEorResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateEorZpx(): Emulate an EOR_ZPX instruction.
local function EmulateEorZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ac = ComputeEorResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- ExecuteInc(): Meat of INC instruction, shared regardless of addressing mode.
local function ExecuteInc(m)
  local result = 0

  if m < 255 then
    result = m + 1
  end

  if result == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end

  if result > 127 then
    swEmuState.n = true
  else
    swEmuState.n = false
  end

  return result
end

-- EmulateIncAbs(): Emulate an INC_ABS instruction.
local function EmulateIncAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteInc(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateIncAbsx(): Emulate an INC_ABSX instruction.
local function EmulateIncAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ram[addr + 1] = ExecuteInc(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateIncZp(): Emulate an INC_ZP instruction.
local function EmulateIncZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteInc(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateIncZpx(): Emulate an INC_ZPX instruction.
local function EmulateIncZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ram[addr + 1] = ExecuteInc(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateInx(): Emulate a INX instruction.
local function EmulateInx(code, curOffset)
  swEmuState.x = ExecuteInc(swEmuState.x)

  return curOffset + 1
end

-- EmulateIny(): Emulate a INY instruction.
local function EmulateIny(code, curOffset)
  swEmuState.y = ExecuteInc(swEmuState.y)

  return curOffset + 1
end

-- EmulateLdaAbs(): Emulate an LDA_ABS instruction.
local function EmulateLdaAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ac = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateLdaAbsx(): Emulate an LDA_ABSX instruction.
local function EmulateLdaAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ac = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateLdaAbsy(): Emulate an LDA_ABSY instruction.
local function EmulateLdaAbsy(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.y
  swEmuState.ac = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateLdaImm(): Emulate an LDA_IMM instruction.
local function EmulateLdaImm(code, curOffset)
  local val = code[curOffset + 1]
  swEmuState.ac = val

  UpdateZ(val)
  UpdateN(val)

  return curOffset + 2
end

-- EmulateLdaIndx(): Emulate an LDA_INDX instruction.
local function EmulateLdaIndx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[(addr + 1) % 256 + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo

  swEmuState.ac = swEmuState.ram[indAddr + 1]

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateLdaIndy(): Emulate an LDA_INDY instruction.
local function EmulateLdaIndy(code, curOffset)
  local addr = code[curOffset + 1]

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[((addr + 1) % 256) + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo + swEmuState.y

  swEmuState.ac = swEmuState.ram[indAddr + 1]

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateLdaZp(): Emulate an LDA_ZP instruction.
local function EmulateLdaZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ac = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateLdaZpx(): Emulate an LDA_ZPX instruction.
local function EmulateLdaZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ac = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateLdxAbs(): Emulate an LDX_ABS instruction.
local function EmulateLdxAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.x = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.x)
  UpdateN(swEmuState.x)

  return curOffset + 3
end

-- EmulateLdxAbsy(): Emulate an LDX_ABSY instruction.
local function EmulateLdxAbsy(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.y
  swEmuState.x = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.x)
  UpdateN(swEmuState.x)

  return curOffset + 3
end

-- EmulateLdxImm(): Emulate an LDX_IMM instruction.
local function EmulateLdxImm(code, curOffset)
  local val = code[curOffset + 1]
  swEmuState.x = val

  UpdateZ(val)
  UpdateN(val)

  return curOffset + 2
end

-- EmulateLdxZp(): Emulate an LDX_ZP instruction.
local function EmulateLdxZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.x = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.x)
  UpdateN(swEmuState.x)

  return curOffset + 2
end

-- EmulateLdxZpy(): Emulate an LDX_ZPY instruction.
local function EmulateLdxZpy(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.y) % 256
  swEmuState.x = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.x)
  UpdateN(swEmuState.x)

  return curOffset + 2
end

-- EmulateLdyAbs(): Emulate an LDY_ABS instruction.
local function EmulateLdyAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.y = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.y)
  UpdateN(swEmuState.y)

  return curOffset + 3
end

-- EmulateLdyAbsx(): Emulate an LDY_ABSX instruction.
local function EmulateLdyAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.y = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.y)
  UpdateN(swEmuState.y)

  return curOffset + 3
end

-- EmulateLdyImm(): Emulate an LDY_IMM instruction.
local function EmulateLdyImm(code, curOffset)
  local val = code[curOffset + 1]
  swEmuState.y = val

  UpdateZ(val)
  UpdateN(val)

  return curOffset + 2
end

-- EmulateLdyZp(): Emulate an LDY_ZP instruction.
local function EmulateLdyZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.y = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.y)
  UpdateN(swEmuState.y)

  return curOffset + 2
end

-- EmulateLdyZpx(): Emulate an LDY_ZPX instruction.
local function EmulateLdyZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.y = swEmuState.ram[addr + 1]

  UpdateZ(swEmuState.y)
  UpdateN(swEmuState.y)

  return curOffset + 2
end

-- ExecuteLsr(): Meat of LSR instruction, shared regardless of addressing mode.
local function ExecuteLsr(m)
  local result = math.floor(m / 2)

  if m % 2 == 1 then
    swEmuState.c = true
  else
    swEmuState.c = false
  end

  if result == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end

  swEmuState.n = false

  return result
end

-- EmulateLsrAbs(): Emulate an LSR_ABS instruction.
local function EmulateLsrAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteLsr(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateLsrAbsx(): Emulate an LSR_ABSX instruction.
local function EmulateLsrAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ram[addr + 1] = ExecuteLsr(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateLsrAcc(): Emulate an LSR_ACC instruction.
local function EmulateLsrAcc(code, curOffset)
  swEmuState.ac = ExecuteLsr(swEmuState.ac)

  return curOffset + 1
end

-- EmulateLsrZp(): Emulate an LSR_ZP instruction.
local function EmulateLsrZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteLsr(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateLsrZpx(): Emulate an LSR_ZPX instruction.
local function EmulateLsrZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ram[addr + 1] = ExecuteLsr(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateNop(): Emulate a NOP instruction.
local function EmulateNop(code, curOffset)
  return curOffset + 1
end

-- ComputeOrResult(): Meat of OR calculation, shared regardless of addressing mode.
local function ComputeOrResult(arg1, arg2)
  local result = 0
  local divisor = 1

  for i = 1,8 do
    local arg1Bit = math.floor(arg1 / divisor) % 2
    local arg2Bit = math.floor(arg2 / divisor) % 2

    if arg1Bit ~= 0 or arg2Bit ~= 0 then
      result = result + divisor
    end

    divisor = divisor * 2
  end

  return result
end

-- EmulateOraAbs(): Emulate an ORA_ABS instruction.
local function EmulateOraAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ac = ComputeOrResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateOraAbsx(): Emulate an ORA_ABSX instruction.
local function EmulateOraAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ac = ComputeOrResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateOraAbsy(): Emulate an ORA_ABSY instruction.
local function EmulateOraAbsy(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.y
  swEmuState.ac = ComputeOrResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 3
end

-- EmulateOraImm(): Emulate an ORA_IMM instruction.
local function EmulateOraImm(code, curOffset)
  local arg = code[curOffset + 1]
  swEmuState.ac = ComputeOrResult(swEmuState.ac, arg)

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateOraIndx(): Emulate an ORA_INDX instruction.
local function EmulateOraIndx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[(addr + 1) % 256 + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo

  swEmuState.ac = ComputeOrResult(swEmuState.ac, swEmuState.ram[indAddr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateOraIndy(): Emulate an ORA_INDY instruction.
local function EmulateOraIndy(code, curOffset)
  local addr = code[curOffset + 1]

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[((addr + 1) % 256) + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo + swEmuState.y

  swEmuState.ac = ComputeOrResult(swEmuState.ac, swEmuState.ram[indAddr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateOraZp(): Emulate an ORA_ZP instruction.
local function EmulateOraZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ac = ComputeOrResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulateOraZpx(): Emulate an ORA_ZPX instruction.
local function EmulateOraZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ac = ComputeOrResult(swEmuState.ac, swEmuState.ram[addr + 1])

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 2
end

-- EmulatePha(): Emulate a PHA instruction.
local function EmulatePha(code, curOffset)
  swEmuState.ram[256 + swEmuState.s + 1] = swEmuState.ac

  if swEmuState.s == 0 then
    swEmuState.s = 255
  else
    swEmuState.s = swEmuState.s - 1
  end

  return curOffset + 1
end

-- EmulatePhp(): Emulate a PHP instruction.
local function EmulatePhp(code, curOffset)
  local p = 0

  if swEmuState.c == true then
    p = p + 1
  end
  if swEmuState.z == true then
    p = p + 2
  end
  if swEmuState.i == true then
    p = p + 4
  end
  if swEmuState.d == true then
    p = p + 8
  end
  if swEmuState.v == true then
    p = p + 64
  end
  if swEmuState.n == true then
    p = p + 128
  end

  -- php always sets bits 4 and 5 to 1.
  p = p + 16
  p = p + 32

  swEmuState.ram[256 + swEmuState.s + 1] = p

  if swEmuState.s == 0 then
    swEmuState.s = 255
  else
    swEmuState.s = swEmuState.s - 1
  end

  return curOffset + 1
end

-- EmulatePla(): Emulate a PLA instruction.
local function EmulatePla(code, curOffset)
  swEmuState.s = (swEmuState.s + 1) % 256
  swEmuState.ac = swEmuState.ram[256 + swEmuState.s + 1]

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 1
end

-- EmulatePlp(): Emulate a PLP instruction.
local function EmulatePlp(code, curOffset)
  swEmuState.s = (swEmuState.s + 1) % 256
  local p = swEmuState.ram[256 + swEmuState.s + 1]

  if p % 2 ~= 0 then
    swEmuState.c = true
    p = p - 1
  else
    swEmuState.c = false
  end

  if p % 4 ~= 0 then
    swEmuState.z = true
    p = p - 2
  else
    swEmuState.z = false
  end

  if p % 8 ~= 0 then
    swEmuState.i = true
    p = p - 4
  else
    swEmuState.i = false
  end

  if p % 16 ~= 0 then
    swEmuState.d = true
    p = p - 8
  else
    swEmuState.d = false
  end

  if p % 32 ~= 0 then
    p = p - 16
  end

  if p % 64 ~= 0 then
    p = p - 32
  end
  
  if p % 128 ~= 0 then
    swEmuState.v = true
    p = p - 64
  else
    swEmuState.v = false
  end

  if p % 256 ~= 0 then
    swEmuState.n = true
    p = p - 128
  else
    swEmuState.n = false
  end

  return curOffset + 1
end

-- ExecuteRol(): Meat of ROL instruction, shared regardless of addressing mode.
local function ExecuteRol(m)
  local result = (m * 2) % 256

  if swEmuState.c then
    result = result + 1
  end

  if m * 2 >= 256 then
    swEmuState.c = true
  else
    swEmuState.c = false
  end

  if result == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end

  if result > 127 then
    swEmuState.n = true
  else
    swEmuState.n = false
  end

  return result
end

-- EmulateRolAbs(): Emulate an ROL_ABS instruction.
local function EmulateRolAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteRol(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateRolAbsx(): Emulate an ROL_ABSX instruction.
local function EmulateRolAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ram[addr + 1] = ExecuteRol(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateRolAcc(): Emulate an ROL_ACC instruction.
local function EmulateRolAcc(code, curOffset)
  swEmuState.ac = ExecuteRol(swEmuState.ac)

  return curOffset + 1
end

-- EmulateRolZp(): Emulate an ROL_ZP instruction.
local function EmulateRolZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteRol(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateRolZpx(): Emulate an ROL_ZPX instruction.
local function EmulateRolZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ram[addr + 1] = ExecuteRol(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- ExecuteRor(): Meat of ROR instruction, shared regardless of addressing mode.
local function ExecuteRor(m)
  local result = math.floor(m / 2)

  if swEmuState.c then
    result = result + 128
  end

  if m % 2 == 1 then
    swEmuState.c = true
  else
    swEmuState.c = false
  end

  if result == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end

  if result > 127 then
    swEmuState.n = true
  else
    swEmuState.n = false
  end

  return result
end

-- EmulateRorAbs(): Emulate an ROR_ABS instruction.
local function EmulateRorAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteRor(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateRorAbsx(): Emulate an ROR_ABSX instruction.
local function EmulateRorAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ram[addr + 1] = ExecuteRor(swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateRorAcc(): Emulate an ROR_ACC instruction.
local function EmulateRorAcc(code, curOffset)
  swEmuState.ac = ExecuteRor(swEmuState.ac)

  return curOffset + 1
end

-- EmulateRorZp(): Emulate an ROR_ZP instruction.
local function EmulateRorZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ram[addr + 1] = ExecuteRor(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateRorZpx(): Emulate an ROR_ZPX instruction.
local function EmulateRorZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ram[addr + 1] = ExecuteRor(swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- ExecuteSbc(): Meat of SBC instruction, shared regardless of addressing mode.
local function ExecuteSbc(a, m)
  local cin = 0
  if swEmuState.c then
    cin = 1
  end

  local result = a + (255 - m) + cin
  swEmuState.ac = result % 256

  if result > 255 then
    swEmuState.c = true
  else
    swEmuState.c = false
  end

  if swEmuState.ac == 0 then
    swEmuState.z = true
  else
    swEmuState.z = false
  end

  if swEmuState.ac >= 128 then
    swEmuState.n = true
  else
    swEmuState.n = false
  end

  -- Overflow detection
  local a2c = a
  local m2c = m

  if a >= 128 then
    a2c = -(256 - a)
  end
  if m >= 128 then
    m2c = -(256 - m)
  end

  local result2c = a2c - m2c - (1 - cin)

  if (result2c < 0) ~= (swEmuState.ac > 127) then
    swEmuState.v = true
  else
    swEmuState.v = false
  end
end

-- EmulateSbcAbs(): Emulate an SBC_ABS instruction.
local function EmulateSbcAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  ExecuteSbc(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateSbcAbsx(): Emulate an SBC_ABSX instruction.
local function EmulateSbcAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  ExecuteSbc(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateSbcAbsy(): Emulate an SBC_ABSY instruction.
local function EmulateSbcAbsy(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.y
  ExecuteSbc(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 3
end

-- EmulateSbcImm(): Emulate an SBC_IMM instruction.
local function EmulateSbcImm(code, curOffset)
  local arg = code[curOffset + 1]

  ExecuteSbc(swEmuState.ac, arg)

  return curOffset + 2
end

-- EmulateSbcIndx(): Emulate an SBC_INDX instruction.
local function EmulateSbcIndx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[(addr + 1) % 256 + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo

  ExecuteSbc(swEmuState.ac, swEmuState.ram[indAddr + 1])

  return curOffset + 2
end

-- EmulateSbcIndy(): Emulate an SBC_INDY instruction.
local function EmulateSbcIndy(code, curOffset)
  local addr = code[curOffset + 1]

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[((addr + 1) % 256) + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo + swEmuState.y

  ExecuteSbc(swEmuState.ac, swEmuState.ram[indAddr + 1])

  return curOffset + 2
end

-- EmulateSbcZp(): Emulate an SBC_ZP instruction.
local function EmulateSbcZp(code, curOffset)
  local addr = code[curOffset + 1]
  ExecuteSbc(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateSbcZpx(): Emulate an SBC_ZPX instruction.
local function EmulateSbcZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  ExecuteSbc(swEmuState.ac, swEmuState.ram[addr + 1])

  return curOffset + 2
end

-- EmulateSec(): Emulate an SEC instruction.
local function EmulateSec(code, curOffset)
  swEmuState.c = true

  return curOffset + 1
end

-- EmulateSed(): Emulate an SED instruction.
local function EmulateSed(code, curOffset)
  swEmuState.d = true

  return curOffset + 1
end

-- EmulateSei(): Emulate an SEI instruction.
local function EmulateSei(code, curOffset)
  swEmuState.i = true

  return curOffset + 1
end

-- EmulateStaAbs(): Emulate an STA_ABS instruction.
local function EmulateStaAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ram[addr + 1] = swEmuState.ac

  return curOffset + 3
end

-- EmulateStaAbsx(): Emulate an STA_ABSX instruction.
local function EmulateStaAbsx(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.x
  swEmuState.ram[addr + 1] = swEmuState.ac

  return curOffset + 3
end

-- EmulateStaAbsy(): Emulate an STA_ABSY instruction.
local function EmulateStaAbsy(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1] + swEmuState.y
  swEmuState.ram[addr + 1] = swEmuState.ac

  return curOffset + 3
end

-- EmulateStaIndx(): Emulate an STA_INDX instruction.
local function EmulateStaIndx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[(addr + 1) % 256 + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo

  swEmuState.ram[indAddr + 1] = swEmuState.ac

  return curOffset + 2
end

-- EmulateStaIndy(): Emulate an STA_INDY instruction.
local function EmulateStaIndy(code, curOffset)
  local addr = code[curOffset + 1]

  local indAddrLo = swEmuState.ram[addr + 1]
  local indAddrHi = swEmuState.ram[(addr + 1) % 256 + 1]
  local indAddr   = indAddrHi * 256 + indAddrLo + swEmuState.y

  swEmuState.ram[indAddr + 1] = swEmuState.ac

  return curOffset + 2
end

-- EmulateStaZp(): Emulate an STA_ZP instruction.
local function EmulateStaZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ram[addr + 1] = swEmuState.ac

  return curOffset + 2
end

-- EmulateStaZpx(): Emulate an STA_ZPX instruction.
local function EmulateStaZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ram[addr + 1] = swEmuState.ac

  return curOffset + 2
end

-- EmulateStxAbs(): Emulate an STX_ABS instruction.
local function EmulateStxAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ram[addr + 1] = swEmuState.x

  return curOffset + 3
end

-- EmulateStxZp(): Emulate an STA_ZP instruction.
local function EmulateStxZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ram[addr + 1] = swEmuState.x

  return curOffset + 2
end

-- EmulateStxZpy(): Emulate an STX_ZPY instruction.
local function EmulateStxZpy(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.y) % 256
  swEmuState.ram[addr + 1] = swEmuState.x

  return curOffset + 2
end

-- EmulateStyAbs(): Emulate an STY_ABS instruction.
local function EmulateStyAbs(code, curOffset)
  local addr = code[curOffset + 2] * 256 + code[curOffset + 1]
  swEmuState.ram[addr + 1] = swEmuState.y

  return curOffset + 3
end

-- EmulateStyZp(): Emulate an STY_ZP instruction.
local function EmulateStyZp(code, curOffset)
  local addr = code[curOffset + 1]
  swEmuState.ram[addr + 1] = swEmuState.y

  return curOffset + 2
end

-- EmulateStyZpx(): Emulate an STY_ZPX instruction.
local function EmulateStyZpx(code, curOffset)
  local addr = (code[curOffset + 1] + swEmuState.x) % 256
  swEmuState.ram[addr + 1] = swEmuState.y

  return curOffset + 2
end

-- EmulateTax(): Emulate a TAX instruction.
local function EmulateTax(code, curOffset)
  swEmuState.x = swEmuState.ac

  UpdateZ(swEmuState.x)
  UpdateN(swEmuState.x)

  return curOffset + 1
end

-- EmulateTay(): Emulate a TAY instruction.
local function EmulateTay(code, curOffset)
  swEmuState.y = swEmuState.ac

  UpdateZ(swEmuState.y)
  UpdateN(swEmuState.y)

  return curOffset + 1
end

-- EmulateTsx(): Emulate a TSX instruction.
local function EmulateTsx(code, curOffset)
  swEmuState.x = swEmuState.s

  UpdateZ(swEmuState.x)
  UpdateN(swEmuState.x)

  return curOffset + 1
end

-- EmulateTxa(): Emulate a TXA instruction.
local function EmulateTxa(code, curOffset)
  swEmuState.ac = swEmuState.x

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 1
end

-- EmulateTxs(): Emulate a TXS instruction.
local function EmulateTxs(code, curOffset)
  swEmuState.s = swEmuState.x

  return curOffset + 1
end

-- EmulateTya(): Emulate a TYA instruction.
local function EmulateTya(code, curOffset)
  swEmuState.ac = swEmuState.y

  UpdateZ(swEmuState.ac)
  UpdateN(swEmuState.ac)

  return curOffset + 1
end

local instructionsTbl =
{
  { op = Ops.ADC_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateAdcAbs  },
  { op = Ops.ADC_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateAdcAbsx },
  { op = Ops.ADC_ABSY, gen = GenRandAbsAddrIdxInst, emu = EmulateAdcAbsy },
  { op = Ops.ADC_IMM,  gen = GenRand2ByteInst,      emu = EmulateAdcImm  },
  { op = Ops.ADC_INDX, gen = GenRandIndxInst,       emu = EmulateAdcIndx },
  { op = Ops.ADC_INDY, gen = GenRandIndyInst,       emu = EmulateAdcIndy },
  { op = Ops.ADC_ZP,   gen = GenRand2ByteInst,      emu = EmulateAdcZp   },
  { op = Ops.ADC_ZPX,  gen = GenRand2ByteInst,      emu = EmulateAdcZpx  },
  { op = Ops.AND_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateAndAbs  },
  { op = Ops.AND_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateAndAbsx },
  { op = Ops.AND_ABSY, gen = GenRandAbsAddrIdxInst, emu = EmulateAndAbsy },
  { op = Ops.AND_IMM,  gen = GenRand2ByteInst,      emu = EmulateAndImm  },
  { op = Ops.AND_INDX, gen = GenRandIndxInst,       emu = EmulateAndIndx },
  { op = Ops.AND_INDY, gen = GenRandIndyInst,       emu = EmulateAndIndy },
  { op = Ops.AND_ZP,   gen = GenRand2ByteInst,      emu = EmulateAndZp   },
  { op = Ops.AND_ZPX,  gen = GenRand2ByteInst,      emu = EmulateAndZpx  },
  { op = Ops.ASL_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateAslAbs  },
  { op = Ops.ASL_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateAslAbsx },
  { op = Ops.ASL_ACC,  gen = GenRand1ByteInst,      emu = EmulateAslAcc  },
  { op = Ops.ASL_ZP,   gen = GenRand2ByteInst,      emu = EmulateAslZp   },
  { op = Ops.ASL_ZPX,  gen = GenRand2ByteInst,      emu = EmulateAslZpx  },
  { op = Ops.BIT_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateBitAbs  },
  { op = Ops.BIT_ZP,   gen = GenRand2ByteInst,      emu = EmulateBitZp   },
  { op = Ops.CLC,      gen = GenRand1ByteInst,      emu = EmulateClc     },
  { op = Ops.CLD,      gen = GenRand1ByteInst,      emu = EmulateCld     },
  { op = Ops.CLI,      gen = GenRand1ByteInst,      emu = EmulateCli     },
  { op = Ops.CLV,      gen = GenRand1ByteInst,      emu = EmulateClv     },
  { op = Ops.CMP_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateCmpAbs  },
  { op = Ops.CMP_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateCmpAbsx },
  { op = Ops.CMP_ABSY, gen = GenRandAbsAddrIdxInst, emu = EmulateCmpAbsy },
  { op = Ops.CMP_IMM,  gen = GenRand2ByteInst,      emu = EmulateCmpImm  },
  { op = Ops.CMP_INDX, gen = GenRandIndxInst,       emu = EmulateCmpIndx },
  { op = Ops.CMP_INDY, gen = GenRandIndyInst,       emu = EmulateCmpIndy },
  { op = Ops.CMP_ZP,   gen = GenRand2ByteInst,      emu = EmulateCmpZp   },
  { op = Ops.CMP_ZPX,  gen = GenRand2ByteInst,      emu = EmulateCmpZpx  },
  { op = Ops.CPX_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateCpxAbs  },
  { op = Ops.CPX_IMM,  gen = GenRand2ByteInst,      emu = EmulateCpxImm  },
  { op = Ops.CPX_ZP,   gen = GenRand2ByteInst,      emu = EmulateCpxZp   },
  { op = Ops.CPY_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateCpyAbs  },
  { op = Ops.CPY_IMM,  gen = GenRand2ByteInst,      emu = EmulateCpyImm  },
  { op = Ops.CPY_ZP,   gen = GenRand2ByteInst,      emu = EmulateCpyZp   },
  { op = Ops.DEC_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateDecAbs  },
  { op = Ops.DEC_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateDecAbsx },
  { op = Ops.DEC_ZP,   gen = GenRand2ByteInst,      emu = EmulateDecZp   },
  { op = Ops.DEC_ZPX,  gen = GenRand2ByteInst,      emu = EmulateDecZpx  },
  { op = Ops.DEX,      gen = GenRand1ByteInst,      emu = EmulateDex     },
  { op = Ops.DEY,      gen = GenRand1ByteInst,      emu = EmulateDey     },
  { op = Ops.EOR_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateEorAbs  },
  { op = Ops.EOR_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateEorAbsx },
  { op = Ops.EOR_ABSY, gen = GenRandAbsAddrIdxInst, emu = EmulateEorAbsy },
  { op = Ops.EOR_IMM,  gen = GenRand2ByteInst,      emu = EmulateEorImm  },
  { op = Ops.EOR_INDX, gen = GenRandIndxInst,       emu = EmulateEorIndx },
  { op = Ops.EOR_INDY, gen = GenRandIndyInst,       emu = EmulateEorIndy },
  { op = Ops.EOR_ZP,   gen = GenRand2ByteInst,      emu = EmulateEorZp   },
  { op = Ops.EOR_ZPX,  gen = GenRand2ByteInst,      emu = EmulateEorZpx  },
  { op = Ops.INC_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateIncAbs  },
  { op = Ops.INC_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateIncAbsx },
  { op = Ops.INC_ZP,   gen = GenRand2ByteInst,      emu = EmulateIncZp   },
  { op = Ops.INC_ZPX,  gen = GenRand2ByteInst,      emu = EmulateIncZpx  },
  { op = Ops.INX,      gen = GenRand1ByteInst,      emu = EmulateInx     },
  { op = Ops.INY,      gen = GenRand1ByteInst,      emu = EmulateIny     },
  { op = Ops.LDA_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateLdaAbs  },
  { op = Ops.LDA_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateLdaAbsx },
  { op = Ops.LDA_ABSY, gen = GenRandAbsAddrIdxInst, emu = EmulateLdaAbsy },
  { op = Ops.LDA_IMM,  gen = GenRand2ByteInst,      emu = EmulateLdaImm  },
  { op = Ops.LDA_INDX, gen = GenRandIndxInst,       emu = EmulateLdaIndx },
  { op = Ops.LDA_INDY, gen = GenRandIndyInst,       emu = EmulateLdaIndy },
  { op = Ops.LDA_ZP,   gen = GenRand2ByteInst,      emu = EmulateLdaZp   },
  { op = Ops.LDA_ZPX,  gen = GenRand2ByteInst,      emu = EmulateLdaZpx  },
  { op = Ops.LDX_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateLdxAbs  },
  { op = Ops.LDX_ABSY, gen = GenRandAbsAddrIdxInst, emu = EmulateLdxAbsy },
  { op = Ops.LDX_IMM,  gen = GenRand2ByteInst,      emu = EmulateLdxImm  },
  { op = Ops.LDX_ZP,   gen = GenRand2ByteInst,      emu = EmulateLdxZp   },
  { op = Ops.LDX_ZPY,  gen = GenRand2ByteInst,      emu = EmulateLdxZpy  },
  { op = Ops.LDY_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateLdyAbs  },
  { op = Ops.LDY_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateLdyAbsx },
  { op = Ops.LDY_IMM,  gen = GenRand2ByteInst,      emu = EmulateLdyImm  },
  { op = Ops.LDY_ZP,   gen = GenRand2ByteInst,      emu = EmulateLdyZp   },
  { op = Ops.LDY_ZPX,  gen = GenRand2ByteInst,      emu = EmulateLdyZpx  },
  { op = Ops.LSR_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateLsrAbs  },
  { op = Ops.LSR_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateLsrAbsx },
  { op = Ops.LSR_ACC,  gen = GenRand1ByteInst,      emu = EmulateLsrAcc  },
  { op = Ops.LSR_ZP,   gen = GenRand2ByteInst,      emu = EmulateLsrZp   },
  { op = Ops.LSR_ZPX,  gen = GenRand2ByteInst,      emu = EmulateLsrZpx  },
  { op = Ops.NOP,      gen = GenRand1ByteInst,      emu = EmulateNop     },
  { op = Ops.ORA_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateOraAbs  },
  { op = Ops.ORA_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateOraAbsx },
  { op = Ops.ORA_ABSY, gen = GenRandAbsAddrIdxInst, emu = EmulateOraAbsy },
  { op = Ops.ORA_IMM,  gen = GenRand2ByteInst,      emu = EmulateOraImm  },
  { op = Ops.ORA_INDX, gen = GenRandIndxInst,       emu = EmulateOraIndx },
  { op = Ops.ORA_INDY, gen = GenRandIndyInst,       emu = EmulateOraIndy },
  { op = Ops.ORA_ZP,   gen = GenRand2ByteInst,      emu = EmulateOraZp   },
  { op = Ops.ORA_ZPX,  gen = GenRand2ByteInst,      emu = EmulateOraZpx  },
  { op = Ops.PHA,      gen = GenRand1ByteInst,      emu = EmulatePha     },
  { op = Ops.PHP,      gen = GenRand1ByteInst,      emu = EmulatePhp     },
  { op = Ops.PLA,      gen = GenRand1ByteInst,      emu = EmulatePla     },
  { op = Ops.PLP,      gen = GenRand1ByteInst,      emu = EmulatePlp     },
  { op = Ops.ROL_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateRolAbs  },
  { op = Ops.ROL_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateRolAbsx },
  { op = Ops.ROL_ACC,  gen = GenRand1ByteInst,      emu = EmulateRolAcc  },
  { op = Ops.ROL_ZP,   gen = GenRand2ByteInst,      emu = EmulateRolZp   },
  { op = Ops.ROL_ZPX,  gen = GenRand2ByteInst,      emu = EmulateRolZpx  },
  { op = Ops.ROR_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateRorAbs  },
  { op = Ops.ROR_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateRorAbsx },
  { op = Ops.ROR_ACC,  gen = GenRand1ByteInst,      emu = EmulateRorAcc  },
  { op = Ops.ROR_ZP,   gen = GenRand2ByteInst,      emu = EmulateRorZp   },
  { op = Ops.ROR_ZPX,  gen = GenRand2ByteInst,      emu = EmulateRorZpx  },
  { op = Ops.SBC_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateSbcAbs  },
  { op = Ops.SBC_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateSbcAbsx },
  { op = Ops.SBC_ABSY, gen = GenRandAbsAddrIdxInst, emu = EmulateSbcAbsy },
  { op = Ops.SBC_IMM,  gen = GenRand2ByteInst,      emu = EmulateSbcImm  },
  { op = Ops.SBC_INDX, gen = GenRandIndxInst,       emu = EmulateSbcIndx },
  { op = Ops.SBC_INDY, gen = GenRandIndyInst,       emu = EmulateSbcIndy },
  { op = Ops.SBC_ZP,   gen = GenRand2ByteInst,      emu = EmulateSbcZp   },
  { op = Ops.SBC_ZPX,  gen = GenRand2ByteInst,      emu = EmulateSbcZpx  },
  { op = Ops.SEC,      gen = GenRand1ByteInst,      emu = EmulateSec     },
  { op = Ops.SED,      gen = GenRand1ByteInst,      emu = EmulateSed     },
  { op = Ops.SEI,      gen = GenRand1ByteInst,      emu = EmulateSei     },
  { op = Ops.STA_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateStaAbs  },
  { op = Ops.STA_ABSX, gen = GenRandAbsAddrIdxInst, emu = EmulateStaAbsx },
  { op = Ops.STA_ABSY, gen = GenRandAbsAddrIdxInst, emu = EmulateStaAbsy },
  { op = Ops.STA_INDX, gen = GenRandIndxInst,       emu = EmulateStaIndx },
  { op = Ops.STA_INDY, gen = GenRandIndyInst,       emu = EmulateStaIndy },
  { op = Ops.STA_ZP,   gen = GenRand2ByteInst,      emu = EmulateStaZp   },
  { op = Ops.STA_ZPX,  gen = GenRand2ByteInst,      emu = EmulateStaZpx  },
  { op = Ops.STX_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateStxAbs  },
  { op = Ops.STX_ZP,   gen = GenRand2ByteInst,      emu = EmulateStxZp   },
  { op = Ops.STX_ZPY,  gen = GenRand2ByteInst,      emu = EmulateStxZpy  },
  { op = Ops.STY_ABS,  gen = GenRandAbsAddrInst,    emu = EmulateStyAbs  },
  { op = Ops.STY_ZP,   gen = GenRand2ByteInst,      emu = EmulateStyZp   },
  { op = Ops.STY_ZPX,  gen = GenRand2ByteInst,      emu = EmulateStyZpx  },
  { op = Ops.TAX,      gen = GenRand1ByteInst,      emu = EmulateTax     },
  { op = Ops.TAY,      gen = GenRand1ByteInst,      emu = EmulateTay     },
  { op = Ops.TSX,      gen = GenRand1ByteInst,      emu = EmulateTsx     },
  { op = Ops.TXA,      gen = GenRand1ByteInst,      emu = EmulateTxa     },
  { op = Ops.TXS,      gen = GenRand1ByteInst,      emu = EmulateTxs     },
  { op = Ops.TYA,      gen = GenRand1ByteInst,      emu = EmulateTya     },
}

-- GetInstr(): Find an instructionsTbl entry for the specified opcode.
local function GetInstr(op)
  for i = 1, #instructionsTbl do
    if instructionsTbl[i].op == op then
      return instructionsTbl[i]
    end
  end

  print("Emulator error.\n")
  return 0
end

-- EvaluateSubtest()
function EvaluateSubtest(code, startPc)
  local ret = true

  local pc = GetPc()
  local ac = GetAc()
  local x  = GetX()
  local y  = GetY()
  local s  = GetS()
  local c  = GetC()
  local z  = GetZ()
  local i  = GetI()
  local d  = GetD()
  local v  = GetV()
  local n  = GetN()

  if pc ~= (startPc + #code) or
     ac ~= swEmuState.ac     or
     x  ~= swEmuState.x      or
     y  ~= swEmuState.y      or
     s  ~= swEmuState.s      or
     c  ~= swEmuState.c      or
     z  ~= swEmuState.z      or
     i  ~= swEmuState.i      or
     d  ~= swEmuState.d      or
     v  ~= swEmuState.v      or
     n  ~= swEmuState.n then
    ret = false
  end

  -- Check RAM for mismatch.
  hwRam = nesdbg.CpuMemRd(0x0000, 0x800)
  for idx = 1, 0x800 do
    if swEmuState.ram[idx] ~= hwRam[idx] then
      print("RAM mismatch @ " .. idx .. "\n")
      ret = false
      break
    end
  end

  if ret == false then
    print("Code: ")
    for idx = 1, #code do
      print(code[idx] .. " ")
    end
    print("\n")
    print("\n")
    print("EMU State: PC=" .. startPc + #code        ..
                    " AC=" .. swEmuState.ac          ..
                    " X="  .. swEmuState.x           ..
                    " Y="  .. swEmuState.y           ..
                    " C="  .. tostring(swEmuState.c) ..
                    " Z="  .. tostring(swEmuState.z) ..
                    " I="  .. tostring(swEmuState.i) ..
                    " D="  .. tostring(swEmuState.d) ..
                    " V="  .. tostring(swEmuState.v) ..
                    " N="  .. tostring(swEmuState.n))
    print("\n")
    print("RAM:")
    for idx = 1, 0x800 do
      print(swEmuState.ram[idx] .. " ")
    end
    print("\n")
    print("\n")

    print("HW  State: PC=" .. pc                     ..
                    " AC=" .. ac                     ..
                    " X="  .. x                      ..
                    " Y="  .. y                      ..
                    " C="  .. tostring(c)            ..
                    " Z="  .. tostring(z)            ..
                    " I="  .. tostring(i)            ..
                    " D="  .. tostring(d)            ..
                    " V="  .. tostring(v)            ..
                    " N="  .. tostring(n))
    print("\n")
    print("RAM:")
    for idx = 1, 0x800 do
      print(hwRam[idx] .. " ")
    end
    print("\n")
    print("\n")
  end

  return ret
end

local results = {}

-- Initialize SW EMU with current hw reg vals.
swEmuState.ac = GetAc()
swEmuState.x  = GetX()
swEmuState.y  = GetY()
swEmuState.s  = GetS()
swEmuState.c  = GetC()
swEmuState.z  = GetZ()
swEmuState.i  = GetI()
swEmuState.d  = GetD()
swEmuState.v  = GetV()
swEmuState.n  = GetN()

-- Initialize RAM with random contents.
for i = 1, 0x800 do
  swEmuState.ram[i] = math.random(0, 255)
end
nesdbg.CpuMemWr(0x0000, #swEmuState.ram, swEmuState.ram)

for subTestIdx = 1, numSubtests do
  local code = {}
  local curCodeOffset = 1

  -- Generate random code.
  for i = 1, instructionsPerSubtest do
    local instrIdx = math.random(1, #instructionsTbl)
    local tblEntry = instructionsTbl[instrIdx]

    curCodeOffset = tblEntry.gen(tblEntry.op, code, curCodeOffset)
  end

  code[curCodeOffset] = Ops.HLT

  -- Load code into hardware.
  local startPc = 0x8000
  SetPc(startPc)
  nesdbg.CpuMemWr(startPc, #code, code)

  -- Execute random code.
  nesdbg.DbgRun()
  nesdbg.WaitForHlt()

  -- Emulate random code.
  curCodeOffset = 1
  while code[curCodeOffset] ~= Ops.HLT do
    local instr = GetInstr(code[curCodeOffset])
    curCodeOffset = instr.emu(code, curCodeOffset)
  end

  -- Evaluate result.
  if EvaluateSubtest(code, startPc) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail
    break
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

