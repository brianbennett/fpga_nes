----------------------------------------------------------------------------------------------------
-- Script:      cpu_cmp.lua
-- Description: CPU test.  Directed test for CMP, CPX, and CPY instructions.  Covers all address 
--              modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: CMP_IMM: A > M
  {
    code = { Ops.LDA_IMM, 0x70,  -- A
             Ops.LDX_IMM, 0x00,
             Ops.LDY_IMM, 0x00,
             Ops.CMP_IMM, 0x44,  -- M
             Ops.HLT },
    aVal = 0x70,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 2: CMP_IMM: A == M
  {
    code = { Ops.LDA_IMM, 0x3E,  -- A
             Ops.CMP_IMM, 0x3E,  -- M
             Ops.HLT },
    aVal = 0x3E,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 3: CMP_IMM: A < M
  {
    code = { Ops.LDA_IMM, 0x3E,  -- A
             Ops.CMP_IMM, 0x8E,  -- M
             Ops.HLT },
    aVal = 0x3E,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = true,
    cVal = false
  },

  -- Test 4: CMP_ZP: A > M
  {
    code = { Ops.LDA_IMM, 0x99,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0xF0,  -- A
             Ops.CMP_ZP,  0x52,
             Ops.HLT },
    aVal = 0xF0,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 5: CMP_ZP: A == M
  {
    code = { Ops.LDA_IMM, 0x27,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x27,  -- A
             Ops.CMP_ZP,  0x52,
             Ops.HLT },
    aVal = 0x27,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 6: CMP_ZP: A < M
  {
    code = { Ops.LDA_IMM, 0x91,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x10,  -- A
             Ops.CMP_ZP,  0x52,
             Ops.HLT },
    aVal = 0x10,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    cVal = false
  },

  -- Test 7: CMP_ZPX: A > M
  {
    code = { Ops.LDA_IMM, 0xFA,  -- M
             Ops.STA_ZP,  0xC2,
             Ops.LDA_IMM, 0xFB,  -- A
             Ops.LDX_IMM, 0x13,
             Ops.CMP_ZPX, 0xAF,
             Ops.HLT },
    aVal = 0xFB,
    xVal = 0x13,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 8: CMP_ZPX: A == M
  {
    code = { Ops.LDA_IMM, 0x34,  -- M
             Ops.STA_ZP,  0xC2,
             Ops.LDA_IMM, 0x34,  -- A
             Ops.LDX_IMM, 0x13,
             Ops.CMP_ZPX, 0xAF,
             Ops.HLT },
    aVal = 0x34,
    xVal = 0x13,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 9: CMP_ZPX: A < M
  {
    code = { Ops.LDA_IMM, 0xFA,  -- M
             Ops.STA_ZP,  0xC2,
             Ops.LDA_IMM, 0xB1,  -- A
             Ops.LDX_IMM, 0x13,
             Ops.CMP_ZPX, 0xAF,
             Ops.HLT },
    aVal = 0xB1,
    xVal = 0x13,
    yVal = 0x00,
    zVal = false,
    nVal = true,
    cVal = false
  },

  -- Test 10: CMP_ABS: A > M
  {
    code = { Ops.LDA_IMM, 0x00,        -- M
             Ops.STA_ABS, 0xC0, 0x05,
             Ops.LDA_IMM, 0xFF,        -- A
             Ops.LDX_IMM, 0x00,
             Ops.CMP_ABS, 0xC0, 0x05,
             Ops.HLT },
    aVal = 0xFF,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = true,
    cVal = true
  },

  -- Test 11: CMP_ABS: A == M
  {
    code = { Ops.LDA_IMM, 0x19,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDA_IMM, 0x19,        -- A
             Ops.CMP_ABS, 0x03, 0x03,
             Ops.HLT },
    aVal = 0x19,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 12: CMP_ABS: A < M
  {
    code = { Ops.LDA_IMM, 0x11,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDA_IMM, 0x10,        -- A
             Ops.CMP_ABS, 0x03, 0x03,
             Ops.HLT },
    aVal = 0x10,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = true,
    cVal = false
  },

  -- Test 13: CMP_ABSX: A > M
  {
    code = { Ops.LDA_IMM,  0x88,        -- M
             Ops.STA_ABS,  0x80, 0x07,
             Ops.LDA_IMM,  0xF7,        -- A
             Ops.LDX_IMM,  0x73,
             Ops.LDY_IMM,  0x00,
             Ops.CMP_ABSX, 0x0D, 0x07,
             Ops.HLT },
    aVal = 0xF7,
    xVal = 0x73,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 14: CMP_ABSX: A == M
  {
    code = { Ops.LDA_IMM,  0x39,        -- M
             Ops.STA_ABS,  0x13, 0x02,
             Ops.LDA_IMM,  0x39,        -- A
             Ops.LDX_IMM,  0xF0,
             Ops.CMP_ABSX, 0x23, 0x01,
             Ops.HLT },
    aVal = 0x39,
    xVal = 0xF0,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 15: CMP_ABSX: A < M
  {
    code = { Ops.LDA_IMM,  0xF1,        -- M
             Ops.STA_ABS,  0x13, 0x02,
             Ops.LDA_IMM,  0x13,        -- A
             Ops.LDX_IMM,  0xF0,
             Ops.CMP_ABSX, 0x23, 0x01,
             Ops.HLT },
    aVal = 0x13,
    xVal = 0xF0,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    cVal = false
  },

  -- Test 16: CMP_ABSY: A > M
  {
    code = { Ops.LDA_IMM,  0x81,        -- M
             Ops.STA_ABS,  0x10, 0x03,
             Ops.LDA_IMM,  0x92,        -- A
             Ops.LDY_IMM,  0x86,
             Ops.LDX_IMM,  0x00,
             Ops.CMP_ABSY, 0x8A, 0x02,
             Ops.HLT },
    aVal = 0x92,
    xVal = 0x00,
    yVal = 0x86,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 17: CMP_ABSY: A == M
  {
    code = { Ops.LDA_IMM,  0x2D,        -- M
             Ops.STA_ABS,  0x31, 0x06,
             Ops.LDA_IMM,  0x2D,        -- A
             Ops.LDY_IMM,  0xE0,
             Ops.CMP_ABSY, 0x51, 0x05,
             Ops.HLT },
    aVal = 0x2D,
    xVal = 0x00,
    yVal = 0xE0,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 18: CMP_ABSY: A < M
  {
    code = { Ops.LDA_IMM,  0x02,        -- M
             Ops.STA_ABS,  0x31, 0x06,
             Ops.LDA_IMM,  0x01,        -- A
             Ops.LDY_IMM,  0xE0,
             Ops.CMP_ABSY, 0x51, 0x05,
             Ops.HLT },
    aVal = 0x01,
    xVal = 0x00,
    yVal = 0xE0,
    zVal = false,
    nVal = true,
    cVal = false
  },

  -- Test 19: CMP_INDX: A > M
  {
    code = { Ops.LDA_IMM,  0xEE,        -- M
             Ops.STA_ABS,  0x10, 0x03,
             Ops.LDA_IMM,  0x10,
             Ops.STA_ZP,   0x44,
             Ops.LDA_IMM,  0x03,
             Ops.STA_ZP,   0x45,
             Ops.LDA_IMM,  0xF5,        -- A
             Ops.LDX_IMM,  0x14,
             Ops.LDY_IMM,  0x00,
             Ops.CMP_INDX, 0x30,
             Ops.HLT },
    aVal = 0xF5,
    xVal = 0x14,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 20: CMP_INDX: A == M
  {
    code = { Ops.LDA_IMM,  0x1E,        -- M
             Ops.STA_ABS,  0x8C, 0x02,
             Ops.LDA_IMM,  0x8C,
             Ops.STA_ZP,   0x14,
             Ops.LDA_IMM,  0x02,
             Ops.STA_ZP,   0x15,
             Ops.LDA_IMM,  0x1E,        -- A
             Ops.LDX_IMM,  0xD2,
             Ops.CMP_INDX, 0x42,
             Ops.HLT },
    aVal = 0x1E,
    xVal = 0xD2,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 21: CMP_INDX: A < M
  {
    code = { Ops.LDA_IMM,  0xE7,        -- M
             Ops.STA_ABS,  0x8C, 0x02,
             Ops.LDA_IMM,  0x8C,
             Ops.STA_ZP,   0x14,
             Ops.LDA_IMM,  0x02,
             Ops.STA_ZP,   0x15,
             Ops.LDA_IMM,  0x10,        -- A
             Ops.LDX_IMM,  0xD2,
             Ops.CMP_INDX, 0x42,
             Ops.HLT },
    aVal = 0x10,
    xVal = 0xD2,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    cVal = false
  },

  -- Test 22: CMP_INDY: A > M
  {
    code = { Ops.LDA_IMM,  0x99,        -- M
             Ops.STA_ABS,  0x50, 0x05,
             Ops.LDA_IMM,  0xDF,
             Ops.STA_ZP,   0xD6,
             Ops.LDA_IMM,  0x04,
             Ops.STA_ZP,   0xD7,
             Ops.LDA_IMM,  0xA2,        -- A
             Ops.LDY_IMM,  0x71,
             Ops.LDX_IMM,  0x00,
             Ops.CMP_INDY, 0xD6,
             Ops.HLT },
    aVal = 0xA2,
    xVal = 0x00,
    yVal = 0x71,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 23: CMP_INDY: A == M
  {
    code = { Ops.LDA_IMM,  0xE4,        -- M
             Ops.STA_ABS,  0x50, 0x05,
             Ops.LDA_IMM,  0xDF,
             Ops.STA_ZP,   0xD6,
             Ops.LDA_IMM,  0x04,
             Ops.STA_ZP,   0xD7,
             Ops.LDA_IMM,  0xE4,        -- A
             Ops.LDY_IMM,  0x71,
             Ops.LDX_IMM,  0x00,
             Ops.CMP_INDY, 0xD6,
             Ops.HLT },
    aVal = 0xE4,
    xVal = 0x00,
    yVal = 0x71,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 24: CMP_INDY: A < M
  {
    code = { Ops.LDA_IMM,  0x99,        -- M
             Ops.STA_ABS,  0x50, 0x05,
             Ops.LDA_IMM,  0xDF,
             Ops.STA_ZP,   0xD6,
             Ops.LDA_IMM,  0x04,
             Ops.STA_ZP,   0xD7,
             Ops.LDA_IMM,  0x19,        -- A
             Ops.LDY_IMM,  0x71,
             Ops.LDX_IMM,  0x00,
             Ops.CMP_INDY, 0xD6,
             Ops.HLT },
    aVal = 0x19,
    xVal = 0x00,
    yVal = 0x71,
    zVal = false,
    nVal = true,
    cVal = false
  },

  -- Test 25: CPX_IMM: X > M
  {
    code = { Ops.LDX_IMM, 0x70,  -- X
             Ops.CPX_IMM, 0x44,  -- M
             Ops.HLT },
    aVal = 0x19,
    xVal = 0x70,
    yVal = 0x71,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 26: CPX_IMM: X == M
  {
    code = { Ops.LDX_IMM, 0x3E,  -- X
             Ops.CPX_IMM, 0x3E,  -- M
             Ops.HLT },
    aVal = 0x19,
    xVal = 0x3E,
    yVal = 0x71,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 27: CPX_IMM: X < M
  {
    code = { Ops.LDX_IMM, 0x3E,  -- X
             Ops.CPX_IMM, 0x8E,  -- M
             Ops.HLT },
    aVal = 0x19,
    xVal = 0x3E,
    yVal = 0x71,
    zVal = false,
    nVal = true,
    cVal = false
  },

  -- Test 28: CPY_IMM: Y > M
  {
    code = { Ops.LDY_IMM, 0x70,  -- Y
             Ops.CPY_IMM, 0x44,  -- M
             Ops.HLT },
    aVal = 0x19,
    xVal = 0x3E,
    yVal = 0x70,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 29: CPY_IMM: Y == M
  {
    code = { Ops.LDY_IMM, 0x3E,  -- Y
             Ops.CPY_IMM, 0x3E,  -- M
             Ops.HLT },
    aVal = 0x19,
    xVal = 0x3E,
    yVal = 0x3E,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 30: CPY_IMM: Y < M
  {
    code = { Ops.LDY_IMM, 0x3E,  -- Y
             Ops.CPY_IMM, 0x8E,  -- M
             Ops.HLT },
    aVal = 0x19,
    xVal = 0x3E,
    yVal = 0x3E,
    zVal = false,
    nVal = true,
    cVal = false
  },

  -- Test 31: CPX_ZP: X > M
  {
    code = { Ops.LDA_IMM, 0x99,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDX_IMM, 0xF0,  -- X
             Ops.CPX_ZP,  0x52,
             Ops.HLT },
    aVal = 0x99,
    xVal = 0xF0,
    yVal = 0x3E,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 32: CPX_ZP: X == M
  {
    code = { Ops.LDA_IMM, 0x27,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDX_IMM, 0x27,  -- X
             Ops.CPX_ZP,  0x52,
             Ops.HLT },
    aVal = 0x27,
    xVal = 0x27,
    yVal = 0x3E,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 33: CPX_ZP: X < M
  {
    code = { Ops.LDA_IMM, 0x91,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDX_IMM, 0x10,  -- X
             Ops.CPX_ZP,  0x52,
             Ops.HLT },
    aVal = 0x91,
    xVal = 0x10,
    yVal = 0x3E,
    zVal = false,
    nVal = false,
    cVal = false
  },

  -- Test 34: CPY_ZP: Y > M
  {
    code = { Ops.LDA_IMM, 0x99,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDY_IMM, 0xF0,  -- Y
             Ops.CPY_ZP,  0x52,
             Ops.HLT },
    aVal = 0x99,
    xVal = 0x10,
    yVal = 0xF0,
    zVal = false,
    nVal = false,
    cVal = true
  },

  -- Test 35: CPY_ZP: Y == M
  {
    code = { Ops.LDA_IMM, 0x27,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDY_IMM, 0x27,  -- Y
             Ops.CPY_ZP,  0x52,
             Ops.HLT },
    aVal = 0x27,
    xVal = 0x10,
    yVal = 0x27,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 36: CPY_ZP: Y < M
  {
    code = { Ops.LDA_IMM, 0x91,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDY_IMM, 0x10,  -- Y
             Ops.CPY_ZP,  0x52,
             Ops.HLT },
    aVal = 0x91,
    xVal = 0x10,
    yVal = 0x10,
    zVal = false,
    nVal = false,
    cVal = false
  },
  
  -- Test 37: CPX_ABS: X > M
  {
    code = { Ops.LDA_IMM, 0x00,        -- M
             Ops.STA_ABS, 0xC0, 0x05,
             Ops.LDX_IMM, 0xFF,        -- X
             Ops.CPX_ABS, 0xC0, 0x05,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0xFF,
    yVal = 0x10,
    zVal = false,
    nVal = true,
    cVal = true
  },

  -- Test 38: CPX_ABS: X == M
  {
    code = { Ops.LDA_IMM, 0x19,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDX_IMM, 0x19,        -- X
             Ops.CPX_ABS, 0x03, 0x03,
             Ops.HLT },
    aVal = 0x19,
    xVal = 0x19,
    yVal = 0x10,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 39: CPX_ABS: X < M
  {
    code = { Ops.LDA_IMM, 0x11,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDX_IMM, 0x10,        -- X
             Ops.CPX_ABS, 0x03, 0x03,
             Ops.HLT },
    aVal = 0x11,
    xVal = 0x10,
    yVal = 0x10,
    zVal = false,
    nVal = true,
    cVal = false
  },

  -- Test 40: CPY_ABS: Y > M
  {
    code = { Ops.LDA_IMM, 0x00,        -- M
             Ops.STA_ABS, 0xC0, 0x05,
             Ops.LDY_IMM, 0xFF,        -- Y
             Ops.CPY_ABS, 0xC0, 0x05,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x10,
    yVal = 0xFF,
    zVal = false,
    nVal = true,
    cVal = true
  },

  -- Test 41: CPY_ABS: Y == M
  {
    code = { Ops.LDA_IMM, 0x19,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDY_IMM, 0x19,        -- Y
             Ops.CPY_ABS, 0x03, 0x03,
             Ops.HLT },
    aVal = 0x19,
    xVal = 0x10,
    yVal = 0x19,
    zVal = true,
    nVal = false,
    cVal = true
  },

  -- Test 42: CPY_ABS: Y < M
  {
    code = { Ops.LDA_IMM, 0x11,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDY_IMM, 0x10,        -- Y
             Ops.CPY_ABS, 0x03, 0x03,
             Ops.HLT },
    aVal = 0x11,
    xVal = 0x10,
    yVal = 0x10,
    zVal = false,
    nVal = true,
    cVal = false
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
  local c  = GetC()

  if ((ac == curTest.aVal) and
      (x == curTest.xVal) and
      (y == curTest.yVal) and
      (z == curTest.zVal) and
      (n == curTest.nVal) and
      (c == curTest.cVal)) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail

    print("ac: " .. ac .. " x: " .. x ..           " y: " .. y ..
          " z: " .. tostring(z) .. " n: " .. tostring(n) ..
          " c: " .. tostring(c) .. "\n")
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

