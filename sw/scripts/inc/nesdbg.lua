----------------------------------------------------------------------------------------------------
-- Script:      nesdbg.lua
-- Description: Common definitions for NesDbg scripts.
----------------------------------------------------------------------------------------------------

-- ScriptResult: Values to be returned by NesDbg scripts to indicate test's pass/fail/error status.
ScriptResult =
{
  Pass  = 0,  -- SCRIPT_RESULT_PASS
  Fail  = 1,  -- SCRIPT_RESULT_FAIL
  Error = 2   -- SCRIPT_RESULT_ERROR
}

-- CpuReg: Values used to select CPU register for CpuRegRd/CpuRegWr commands.
CpuReg =
{
  PCL = 0, -- PCL: Program Counter Low Register
  PCH = 1, -- PCH: Program Counter High Register
  AC  = 2, -- AC:  Accumulator Register
  X   = 3, -- X:   X Register
  Y   = 4, -- Y:   Y Register
  P   = 5, -- P:   Processor Status Register
  S   = 6, -- S:   Stack Pointer Register
}

-- Ops: 6502 Opcodes
Ops =
{
  ADC_ABS  = 0x6D,
  ADC_ABSX = 0x7D,
  ADC_ABSY = 0x79,
  ADC_IMM  = 0x69,
  ADC_INDX = 0x61,
  ADC_INDY = 0x71,
  ADC_ZP   = 0x65,
  ADC_ZPX  = 0x75,
  AND_ABS  = 0x2D,
  AND_ABSX = 0x3D,
  AND_ABSY = 0x39,
  AND_IMM  = 0x29,
  AND_INDX = 0x21,
  AND_INDY = 0x31,
  AND_ZP   = 0x25,
  AND_ZPX  = 0x35,
  ASL_ABS  = 0x0E,
  ASL_ABSX = 0x1E,
  ASL_ACC  = 0x0A,
  ASL_ZP   = 0x06,
  ASL_ZPX  = 0x16,
  BCC      = 0x90,
  BCS      = 0xB0,
  BEQ      = 0xF0,
  BIT_ABS  = 0x2C,
  BIT_ZP   = 0x24,
  BMI      = 0x30,
  BNE      = 0xD0,
  BPL      = 0x10,
  BRK      = 0x00,
  BVC      = 0x50,
  BVS      = 0x70,
  CLC      = 0x18,
  CLD      = 0xD8,
  CLI      = 0x58,
  CLV      = 0xB8,
  CMP_ABS  = 0xCD,
  CMP_ABSX = 0xDD,
  CMP_ABSY = 0xD9,
  CMP_IMM  = 0xC9,
  CMP_INDX = 0xC1,
  CMP_INDY = 0xD1,
  CMP_ZP   = 0xC5,
  CMP_ZPX  = 0xD5,
  CPX_ABS  = 0xEC,
  CPX_IMM  = 0xE0,
  CPX_ZP   = 0xE4,
  CPY_ABS  = 0xCC,
  CPY_IMM  = 0xC0,
  CPY_ZP   = 0xC4,
  DEC_ABS  = 0xCE,
  DEC_ABSX = 0xDE,
  DEC_ZP   = 0xC6,
  DEC_ZPX  = 0xD6,
  DEX      = 0xCA,
  DEY      = 0x88,
  EOR_ABS  = 0x4D,
  EOR_ABSX = 0x5D,
  EOR_ABSY = 0x59,
  EOR_IMM  = 0x49,
  EOR_INDX = 0x41,
  EOR_INDY = 0x51,
  EOR_ZP   = 0x45,
  EOR_ZPX  = 0x55,
  HLT      = 0x02,
  INC_ABS  = 0xEE,
  INC_ABSX = 0xFE,
  INC_ZP   = 0xE6,
  INC_ZPX  = 0xF6,
  INX      = 0xE8,
  INY      = 0xC8,
  JMP_ABS  = 0x4C,
  JMP_IND  = 0x6C,
  JSR      = 0x20,
  LDA_ABS  = 0xAD,
  LDA_ABSX = 0xBD,
  LDA_ABSY = 0xB9,
  LDA_IMM  = 0xA9,
  LDA_INDX = 0xA1,
  LDA_INDY = 0xB1,
  LDA_ZP   = 0xA5,
  LDA_ZPX  = 0xB5,
  LDX_ABS  = 0xAE,
  LDX_ABSY = 0xBE,
  LDX_IMM  = 0xA2,
  LDX_ZP   = 0xA6,
  LDX_ZPY  = 0xB6,
  LDY_ABS  = 0xAC,
  LDY_ABSX = 0xBC,
  LDY_IMM  = 0xA0,
  LDY_ZP   = 0xA4,
  LDY_ZPX  = 0xB4,
  LSR_ABS  = 0x4E,
  LSR_ABSX = 0x5E,
  LSR_ACC  = 0x4A,
  LSR_ZP   = 0x46,
  LSR_ZPX  = 0x56,
  ORA_ABS  = 0x0D,
  ORA_ABSX = 0x1D,
  ORA_ABSY = 0x19,
  ORA_IMM  = 0x09,
  ORA_INDX = 0x01,
  ORA_INDY = 0x11,
  ORA_ZP   = 0x05,
  ORA_ZPX  = 0x15,
  PHA      = 0x48,
  PHP      = 0x08,
  PLA      = 0x68,
  PLP      = 0x28,
  ROL_ABS  = 0x2E,
  ROL_ABSX = 0x3E,
  ROL_ACC  = 0x2A,
  ROL_ZP   = 0x26,
  ROL_ZPX  = 0x36,
  ROR_ABS  = 0x6E,
  ROR_ABSX = 0x7E,
  ROR_ACC  = 0x6A,
  ROR_ZP   = 0x66,
  ROR_ZPX  = 0x76,
  RTS      = 0x60,
  SBC_ABS  = 0xED,
  SBC_ABSX = 0xFD,
  SBC_ABSY = 0xF9,
  SBC_IMM  = 0xE9,
  SBC_INDX = 0xE1,
  SBC_INDY = 0xF1,
  SBC_ZP   = 0xE5,
  SBC_ZPX  = 0xF5,
  SEC      = 0x38,
  SED      = 0xF8,
  SEI      = 0x78,
  STA_ABS  = 0x8D,
  STA_ABSX = 0x9D,
  STA_ABSY = 0x99,
  STA_INDX = 0x81,
  STA_INDY = 0x91,
  STA_ZP   = 0x85,
  STA_ZPX  = 0x95,
  STX_ABS  = 0x8E,
  STX_ZP   = 0x86,
  STX_ZPY  = 0x96,
  STY_ABS  = 0x8C,
  STY_ZP   = 0x84,
  STY_ZPX  = 0x94,
  NOP      = 0xEA,
  TAX      = 0xAA,
  TAY      = 0xA8,
  TSX      = 0xBA,
  TXA      = 0x8A,
  TXS      = 0x9A,
  TYA      = 0x98,
}

-- CompareArrayData: Returns true if the two arrays' data are the same, false otherwise.
function CompareArrayData(arrayA, arrayB)
  local result = true

  if #arrayA ~= #arrayB then
      result = false
  else
    for i = 1, #arrayA do
      if arrayA[i] ~= arrayB[i] then
        result = false
        break
      end
    end
  end

  return result
end

-- ReportSubTestResult(): Print an update with the specified subtest result.
function ReportSubTestResult(subTestIdx, result)
  print("Subtest " .. subTestIdx .. ": ")
  if result == ScriptResult.Pass then
    print("PASS")
  elseif result == ScriptResult.Fail then
    print("FAIL")
  elseif result == ScriptResult.Error then
    print("ERROR")
  end
  print("\n")
end

-- ComputeOverallResult: Traverses an array of subtest results to compute the overall result.
function ComputeOverallResult(results)
  local overallResult = ScriptResult.Pass

  for i = 1, #results do
    if results[i] == ScriptResult.Error then
      overallResult = ScriptResult.Error
      break
    elseif results[i] == ScriptResult.Fail then
      overallResult = ScriptResult.Fail
    end
  end

  return overallResult
end

-- GetPc: Return the current program counter
function GetPc()
  local pcl = nesdbg.CpuRegRd(CpuReg.PCL)
  local pch = nesdbg.CpuRegRd(CpuReg.PCH)

  return (pch * 256) + pcl
end

-- SetPc: Sets the current program counter
function SetPc(pc)
  local pcl = pc % 256
  local pch = pc / 256

  nesdbg.CpuRegWr(CpuReg.PCL, pcl)
  nesdbg.CpuRegWr(CpuReg.PCH, pch)
end

-- GetAc: Return the current accumulator register
function GetAc()
  return nesdbg.CpuRegRd(CpuReg.AC)
end

-- SetAc: Sets the current accumulator register
function SetAc(ac)
  nesdbg.CpuRegWr(CpuReg.AC, ac)
end

-- GetX: Return the current x register
function GetX()
  return nesdbg.CpuRegRd(CpuReg.X)
end

-- GetY: Return the current y register
function GetY()
  return nesdbg.CpuRegRd(CpuReg.Y)
end

-- GetS: Return the current s register (stack pointer)
function GetS()
  return nesdbg.CpuRegRd(CpuReg.S)
end

-- GetC: Return true if P.C is set.
function GetC()
  local p = nesdbg.CpuRegRd(CpuReg.P)
  return (p % 2 ~= 0)
end

-- GetZ: Return true if P.Z is set.
function GetZ()
  local p = nesdbg.CpuRegRd(CpuReg.P)
  return (((p - (p % 2)) % 4) ~= 0)
end

-- GetI: Return true if P.I is set.
function GetI()
  local p = nesdbg.CpuRegRd(CpuReg.P)
  return (((p - (p % 4)) % 8) ~= 0)
end

-- GetD: Return true if P.D is set.
function GetD()
  local p = nesdbg.CpuRegRd(CpuReg.P)
  return (((p - (p % 8)) % 16) ~= 0)
end

-- GetV: Return true if P.V is set.
function GetV()
  local p = nesdbg.CpuRegRd(CpuReg.P)
  return (((p - (p % 64)) % 128) ~= 0)
end

-- GetN: Return true if P.N is set.
function GetN()
  local p = nesdbg.CpuRegRd(CpuReg.P)
  return (((p - (p % 128)) % 256) ~= 0)
end

