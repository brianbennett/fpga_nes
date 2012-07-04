----------------------------------------------------------------------------------------------------
-- Script:      cpu_ora.lua
-- Description: CPU test.  Directed test for OR instruction.  Covers all address modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: ORA_IMM: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM, 0x80,  -- A
             Ops.LDX_IMM, 0x00,
             Ops.LDY_IMM, 0x00,
             Ops.ORA_IMM, 0x44,  -- M
             Ops.HLT },
    aVal = 0xC4,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = true
  },

  -- Test 2: ORA_IMM: Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM, 0x00,  -- A
             Ops.LDY_IMM, 0xA1,
             Ops.ORA_IMM, 0x00,  -- M
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0xA1,
    zVal = true,
    nVal = false
  },

  -- Test 3: ORA_ZP: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM, 0x99,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x24,  -- A
             Ops.LDX_IMM, 0x00,
             Ops.ORA_ZP,  0x52,
             Ops.HLT },
    aVal = 0xBD,
    xVal = 0x00,
    yVal = 0xA1,
    zVal = false,
    nVal = true
  },

  -- Test 4: ORA_ZP: Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM, 0x00,  -- M
             Ops.STA_ZP,  0x08,
             Ops.LDA_IMM, 0x00,  -- A
             Ops.ORA_ZP,  0x08,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0xA1,
    zVal = true,
    nVal = false
  },

  -- Test 5: ORA_ZPX: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM, 0xFA,  -- M
             Ops.STA_ZP,  0xC2,
             Ops.LDA_IMM, 0xB1,  -- A
             Ops.LDX_IMM, 0x13,
             Ops.ORA_ZPX, 0xAF,
             Ops.HLT },
    aVal = 0xFB,
    xVal = 0x13,
    yVal = 0xA1,
    zVal = false,
    nVal = true
  },

  -- Test 6: ORA_ZPX: Verify z is cleared, n is set, wrap ZP addr
  {
    code = { Ops.LDA_IMM, 0x00,  -- M
             Ops.STA_ZP,  0x3A,
             Ops.LDA_IMM, 0x00,  -- A
             Ops.LDX_IMM, 0x7F,
             Ops.ORA_ZPX, 0xBB,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x7F,
    yVal = 0xA1,
    zVal = true,
    nVal = false
  },

  -- Test 7: ORA_ABS: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM, 0x84,        -- M
             Ops.STA_ABS, 0xC0, 0x05,
             Ops.LDA_IMM, 0x48,        -- A
             Ops.LDX_IMM, 0x00,
             Ops.ORA_ABS, 0xC0, 0x05,
             Ops.HLT },
    aVal = 0xCC,
    xVal = 0x00,
    yVal = 0xA1,
    zVal = false,
    nVal = true
  },

  -- Test 8: ORA_ABS: Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM, 0x00,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDA_IMM, 0x00,        -- A
             Ops.ORA_ABS, 0x03, 0x03,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0xA1,
    zVal = true,
    nVal = false
  },

  -- Test 9: ORA_ABSX: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM,  0x88,        -- M
             Ops.STA_ABS,  0x80, 0x07,
             Ops.LDA_IMM,  0x27,        -- A
             Ops.LDX_IMM,  0x73,
             Ops.LDY_IMM,  0x00,
             Ops.ORA_ABSX, 0x0D, 0x07,
             Ops.HLT },
    aVal = 0xAF,
    xVal = 0x73,
    yVal = 0x00,
    zVal = false,
    nVal = true
  },

  -- Test 10: ORA_ABSX: Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM,  0x00,        -- M
             Ops.STA_ABS,  0x13, 0x02,
             Ops.LDA_IMM,  0x00,        -- A
             Ops.LDX_IMM,  0xF0,
             Ops.ORA_ABSX, 0x23, 0x01,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0xF0,
    yVal = 0x00,
    zVal = true,
    nVal = false
  },

  -- Test 11: ORA_ABSY: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM,  0x81,        -- M
             Ops.STA_ABS,  0x10, 0x03,
             Ops.LDA_IMM,  0x0C,        -- A
             Ops.LDY_IMM,  0x86,
             Ops.LDX_IMM,  0x00,
             Ops.ORA_ABSY, 0x8A, 0x02,
             Ops.HLT },
    aVal = 0x8D,
    xVal = 0x00,
    yVal = 0x86,
    zVal = false,
    nVal = true
  },

  -- Test 12: ORA_ABSY: Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM,  0x00,        -- M
             Ops.STA_ABS,  0x31, 0x06,
             Ops.LDA_IMM,  0x00,        -- A
             Ops.LDY_IMM,  0xE0,
             Ops.ORA_ABSY, 0x51, 0x05,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0xE0,
    zVal = true,
    nVal = false
  },

  -- Test 13: ORA_INDX: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM,  0xEE,        -- M
             Ops.STA_ABS,  0x10, 0x03,
             Ops.LDA_IMM,  0x10,
             Ops.STA_ZP,   0x44,
             Ops.LDA_IMM,  0x03,
             Ops.STA_ZP,   0x45,
             Ops.LDA_IMM,  0x05,        -- A
             Ops.LDX_IMM,  0x14,
             Ops.LDY_IMM,  0x00,
             Ops.ORA_INDX, 0x30,
             Ops.HLT },
    aVal = 0xEF,
    xVal = 0x14,
    yVal = 0x00,
    zVal = false,
    nVal = true
  },

  -- Test 14: ORA_INDX: Verify n is cleared, z is set, X wrapping
  {
    code = { Ops.LDA_IMM,  0x00,        -- M
             Ops.STA_ABS,  0x8C, 0x02,
             Ops.LDA_IMM,  0x8C,
             Ops.STA_ZP,   0x14,
             Ops.LDA_IMM,  0x02,
             Ops.STA_ZP,   0x15,
             Ops.LDA_IMM,  0x00,        -- A
             Ops.LDX_IMM,  0xD2,
             Ops.ORA_INDX, 0x42,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0xD2,
    yVal = 0x00,
    zVal = true,
    nVal = false
  },

  -- Test 15: ORA_INDY: Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM,  0x99,        -- M
             Ops.STA_ABS,  0x50, 0x05,
             Ops.LDA_IMM,  0xDF,
             Ops.STA_ZP,   0xD6,
             Ops.LDA_IMM,  0x04,
             Ops.STA_ZP,   0xD7,
             Ops.LDA_IMM,  0x22,        -- A
             Ops.LDY_IMM,  0x71,
             Ops.LDX_IMM,  0x00,
             Ops.ORA_INDY, 0xD6,
             Ops.HLT },
    aVal = 0xBB,
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

