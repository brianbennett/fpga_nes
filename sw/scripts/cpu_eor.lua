----------------------------------------------------------------------------------------------------
-- Script:      cpu_eor.lua
-- Description: CPU test.  Directed test for EOR instruction.  Covers all address modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: EOR_IMM: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM, 0x8C,  -- A
             Ops.LDX_IMM, 0x00,
             Ops.LDY_IMM, 0x00,
             Ops.EOR_IMM, 0x19,  -- M
             Ops.HLT },
    aVal = 0x95,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = true
  },

  -- Test 2: EOR_IMM: Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM, 0x85,  -- A
             Ops.LDY_IMM, 0xA1,
             Ops.EOR_IMM, 0x85,  -- M
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0xA1,
    zVal = true,
    nVal = false
  },

  -- Test 3: EOR_ZP: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM, 0x3C,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0xA4,  -- A
             Ops.LDX_IMM, 0x00,
             Ops.EOR_ZP,  0x52,
             Ops.HLT },
    aVal = 0x98,
    xVal = 0x00,
    yVal = 0xA1,
    zVal = false,
    nVal = true
  },

  -- Test 4: EOR_ZP: Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM, 0xC3,  -- M
             Ops.STA_ZP,  0x08,
             Ops.LDA_IMM, 0xC3,  -- A
             Ops.EOR_ZP,  0x08,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0xA1,
    zVal = true,
    nVal = false
  },

  -- Test 5: EOR_ZPX: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM, 0x11,  -- M
             Ops.STA_ZP,  0xC2,
             Ops.LDA_IMM, 0x91,  -- A
             Ops.LDX_IMM, 0x13,
             Ops.EOR_ZPX, 0xAF,
             Ops.HLT },
    aVal = 0x80,
    xVal = 0x13,
    yVal = 0xA1,
    zVal = false,
    nVal = true
  },

  -- Test 6: EOR_ZPX: Verify z is cleared, n is set, wrap ZP addr
  {
    code = { Ops.LDA_IMM, 0xD2,  -- M
             Ops.STA_ZP,  0x3A,
             Ops.LDA_IMM, 0xD2,  -- A
             Ops.LDX_IMM, 0x7F,
             Ops.EOR_ZPX, 0xBB,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x7F,
    yVal = 0xA1,
    zVal = true,
    nVal = false
  },

  -- Test 7: EOR_ABS: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM, 0xD1,        -- M
             Ops.STA_ABS, 0xC0, 0x05,
             Ops.LDA_IMM, 0x7F,        -- A
             Ops.LDX_IMM, 0x00,
             Ops.EOR_ABS, 0xC0, 0x05,
             Ops.HLT },
    aVal = 0xAE,
    xVal = 0x00,
    yVal = 0xA1,
    zVal = false,
    nVal = true
  },

  -- Test 8: EOR_ABS: Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM, 0x51,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDA_IMM, 0x51,        -- A
             Ops.EOR_ABS, 0x03, 0x03,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0xA1,
    zVal = true,
    nVal = false
  },

  -- Test 9: EOR_ABSX: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM,  0xFF,        -- M
             Ops.STA_ABS,  0x80, 0x07,
             Ops.LDA_IMM,  0x27,        -- A
             Ops.LDX_IMM,  0x73,
             Ops.LDY_IMM,  0x00,
             Ops.EOR_ABSX, 0x0D, 0x07,
             Ops.HLT },
    aVal = 0xD8,
    xVal = 0x73,
    yVal = 0x00,
    zVal = false,
    nVal = true
  },

  -- Test 10: EOR_ABSX: Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM,  0x28,        -- M
             Ops.STA_ABS,  0x13, 0x02,
             Ops.LDA_IMM,  0x28,        -- A
             Ops.LDX_IMM,  0xF0,
             Ops.EOR_ABSX, 0x23, 0x01,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0xF0,
    yVal = 0x00,
    zVal = true,
    nVal = false
  },

  -- Test 11: EOR_ABSY: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM,  0x8E,        -- M
             Ops.STA_ABS,  0x10, 0x03,
             Ops.LDA_IMM,  0x26,        -- A
             Ops.LDY_IMM,  0x86,
             Ops.LDX_IMM,  0x00,
             Ops.EOR_ABSY, 0x8A, 0x02,
             Ops.HLT },
    aVal = 0xA8,
    xVal = 0x00,
    yVal = 0x86,
    zVal = false,
    nVal = true
  },

  -- Test 12: EOR_ABSY: Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM,  0xF5,        -- M
             Ops.STA_ABS,  0x31, 0x06,
             Ops.LDA_IMM,  0xF5,        -- A
             Ops.LDY_IMM,  0xE0,
             Ops.EOR_ABSY, 0x51, 0x05,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0xE0,
    zVal = true,
    nVal = false
  },

  -- Test 13: EOR_INDX: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM,  0x52,        -- M
             Ops.STA_ABS,  0x10, 0x03,
             Ops.LDA_IMM,  0x10,
             Ops.STA_ZP,   0x44,
             Ops.LDA_IMM,  0x03,
             Ops.STA_ZP,   0x45,
             Ops.LDA_IMM,  0x87,        -- A
             Ops.LDX_IMM,  0x14,
             Ops.LDY_IMM,  0x00,
             Ops.EOR_INDX, 0x30,
             Ops.HLT },
    aVal = 0xD5,
    xVal = 0x14,
    yVal = 0x00,
    zVal = false,
    nVal = true
  },

  -- Test 14: EOR_INDX: Verify n is cleared, z is set, X wrapping
  {
    code = { Ops.LDA_IMM,  0x91,        -- M
             Ops.STA_ABS,  0x8C, 0x02,
             Ops.LDA_IMM,  0x8C,
             Ops.STA_ZP,   0x14,
             Ops.LDA_IMM,  0x02,
             Ops.STA_ZP,   0x15,
             Ops.LDA_IMM,  0x91,        -- A
             Ops.LDX_IMM,  0xD2,
             Ops.EOR_INDX, 0x42,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0xD2,
    yVal = 0x00,
    zVal = true,
    nVal = false
  },

  -- Test 15: EOR_INDY: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM,  0x11,        -- M
             Ops.STA_ABS,  0x50, 0x05,
             Ops.LDA_IMM,  0xDF,
             Ops.STA_ZP,   0xD6,
             Ops.LDA_IMM,  0x04,
             Ops.STA_ZP,   0xD7,
             Ops.LDA_IMM,  0x9F,        -- A
             Ops.LDY_IMM,  0x71,
             Ops.LDX_IMM,  0x00,
             Ops.EOR_INDY, 0xD6,
             Ops.HLT },
    aVal = 0x8E,
    xVal = 0x00,
    yVal = 0x71,
    zVal = false,
    nVal = true
  },
}

for subTestIdx = 1, #testTbl do
  local curTest = testTbl[subTestIdx]

  local startPc = GetPc()
  nesdbg.CpuMemWr(startPc, #curTest.code, curTest.code)

  nesdbg.DbgRun()
  nesdbg.WaitForHlt()

  local ac = GetAc()
  local x  = GetX()
  local y  = GetY()
  local z  = GetZ()
  local n  = GetN()

  if ((ac == curTest.aVal) and
      (x == curTest.xVal) and
      (y == curTest.yVal) and
      (z == curTest.zVal) and
      (n == curTest.nVal)) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail

    print("ac: " .. ac .. " x: " .. x ..           " y: " .. y ..
          " z: " .. tostring(z) .. " n: " .. tostring(n) .. "\n")
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

