----------------------------------------------------------------------------------------------------
-- Script:      cpu_bit.lua
-- Description: CPU test.  Directed test for BIT instruction.  Covers all address modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: BIT_ZP: !n, !v, !z
  {
    code = { Ops.LDA_IMM, 0x3F,  -- M
             Ops.LDX_IMM, 0x00,
             Ops.LDY_IMM, 0x00,
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0xC6,  -- A
             Ops.BIT_ZP,  0x52,
             Ops.BRK },
    aVal = 0xC6,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    vVal = false
  },

  -- Test 2: BIT_ZP: !n, !v, z
  {
    code = { Ops.LDA_IMM, 0x38,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x07,  -- A
             Ops.BIT_ZP,  0x52,
             Ops.BRK },
    aVal = 0x07,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    vVal = false
  },

  -- Test 3: BIT_ZP: !n, v, !z
  {
    code = { Ops.LDA_IMM, 0x41,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x27,  -- A
             Ops.BIT_ZP,  0x52,
             Ops.BRK },
    aVal = 0x27,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    vVal = true
  },

  -- Test 4: BIT_ZP: !n, v, z
  {
    code = { Ops.LDA_IMM, 0x41,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x26,  -- A
             Ops.BIT_ZP,  0x52,
             Ops.BRK },
    aVal = 0x26,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    vVal = true
  },

  -- Test 5: BIT_ZP: n, !v, !z
  {
    code = { Ops.LDA_IMM, 0xBF,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x21,  -- A
             Ops.BIT_ZP,  0x52,
             Ops.BRK },
    aVal = 0x21,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = true,
    vVal = false
  },

  -- Test 6: BIT_ZP: n, !v, z
  {
    code = { Ops.LDA_IMM, 0xB3,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x0C,  -- A
             Ops.BIT_ZP,  0x52,
             Ops.BRK },
    aVal = 0x0C,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = true,
    vVal = false
  },

  -- Test 7: BIT_ZP: n, v, !z
  {
    code = { Ops.LDA_IMM, 0xC3,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0xFC,  -- A
             Ops.BIT_ZP,  0x52,
             Ops.BRK },
    aVal = 0xFC,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = true,
    vVal = true
  },

  -- Test 8: BIT_ZP: n, v, z
  {
    code = { Ops.LDA_IMM, 0xC3,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x3C,  -- A
             Ops.BIT_ZP,  0x52,
             Ops.BRK },
    aVal = 0x3C,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = true,
    vVal = true
  },

  -- Test 9: BIT_ABS: !n, !v, !z
  {
    code = { Ops.LDA_IMM, 0x32,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDA_IMM, 0x8A,        -- A
             Ops.BIT_ABS, 0x03, 0x03,
             Ops.BRK },
    aVal = 0x8A,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    vVal = false
  },

  -- Test 10: BIT_ABS: n, v, z
  {
    code = { Ops.LDA_IMM, 0xC7,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDA_IMM, 0x38,        -- A
             Ops.BIT_ABS, 0x03, 0x03,
             Ops.BRK },
    aVal = 0x38,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = true,
    vVal = true
  },

--[[
  -- Test 1: CMP_IMM: A > M
  {
    code = { Ops.LDA_IMM, 0x70,  -- A
             Ops.LDX_IMM, 0x00,
             Ops.LDY_IMM, 0x00,
             Ops.CMP_IMM, 0x44,  -- M
             Ops.BRK },
    aVal = 0x70,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    vVal = true
  },

  -- Test 2: CMP_IMM: A == M
  {
    code = { Ops.LDA_IMM, 0x3E,  -- A
             Ops.CMP_IMM, 0x3E,  -- M
             Ops.BRK },
    aVal = 0x3E,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    vVal = true
  },

  -- Test 3: CMP_IMM: A < M
  {
    code = { Ops.LDA_IMM, 0x3E,  -- A
             Ops.CMP_IMM, 0x8E,  -- M
             Ops.BRK },
    aVal = 0x3E,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = true,
    vVal = false
  },

  -- Test 4: CMP_ZP: A > M
  {
    code = { Ops.LDA_IMM, 0x99,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0xF0,  -- A
             Ops.CMP_ZP,  0x52,
             Ops.BRK },
    aVal = 0xF0,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    vVal = true
  },

  -- Test 5: CMP_ZP: A == M
  {
    code = { Ops.LDA_IMM, 0x27,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x27,  -- A
             Ops.CMP_ZP,  0x52,
             Ops.BRK },
    aVal = 0x27,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    vVal = true
  },

  -- Test 6: CMP_ZP: A < M
  {
    code = { Ops.LDA_IMM, 0x91,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x10,  -- A
             Ops.CMP_ZP,  0x52,
             Ops.BRK },
    aVal = 0x10,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    vVal = false
  },

  -- Test 7: CMP_ZPX: A > M
  {
    code = { Ops.LDA_IMM, 0xFA,  -- M
             Ops.STA_ZP,  0xC2,
             Ops.LDA_IMM, 0xFB,  -- A
             Ops.LDX_IMM, 0x13,
             Ops.CMP_ZPX, 0xAF,
             Ops.BRK },
    aVal = 0xFB,
    xVal = 0x13,
    yVal = 0x00,
    zVal = false,
    nVal = false,
    vVal = true
  },

  -- Test 8: CMP_ZPX: A == M
  {
    code = { Ops.LDA_IMM, 0x34,  -- M
             Ops.STA_ZP,  0xC2,
             Ops.LDA_IMM, 0x34,  -- A
             Ops.LDX_IMM, 0x13,
             Ops.CMP_ZPX, 0xAF,
             Ops.BRK },
    aVal = 0x34,
    xVal = 0x13,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    vVal = true
  },

  -- Test 9: CMP_ZPX: A < M
  {
    code = { Ops.LDA_IMM, 0xFA,  -- M
             Ops.STA_ZP,  0xC2,
             Ops.LDA_IMM, 0xB1,  -- A
             Ops.LDX_IMM, 0x13,
             Ops.CMP_ZPX, 0xAF,
             Ops.BRK },
    aVal = 0xB1,
    xVal = 0x13,
    yVal = 0x00,
    zVal = false,
    nVal = true,
    vVal = false
  },

  -- Test 10: CMP_ABS: A > M
  {
    code = { Ops.LDA_IMM, 0x00,        -- M
             Ops.STA_ABS, 0xC0, 0x05,
             Ops.LDA_IMM, 0xFF,        -- A
             Ops.LDX_IMM, 0x00,
             Ops.CMP_ABS, 0xC0, 0x05,
             Ops.BRK },
    aVal = 0xFF,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = true,
    vVal = true
  },

  -- Test 11: CMP_ABS: A == M
  {
    code = { Ops.LDA_IMM, 0x19,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDA_IMM, 0x19,        -- A
             Ops.CMP_ABS, 0x03, 0x03,
             Ops.BRK },
    aVal = 0x19,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = false,
    vVal = true
  },

  -- Test 12: CMP_ABS: A < M
  {
    code = { Ops.LDA_IMM, 0x11,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDA_IMM, 0x10,        -- A
             Ops.CMP_ABS, 0x03, 0x03,
             Ops.BRK },
    aVal = 0x10,
    xVal = 0x00,
    yVal = 0x00,
    zVal = false,
    nVal = true,
    vVal = false
  },

  -- Test 13: CMP_ABSX: A > M
  {
    code = { Ops.LDA_IMM,  0x88,        -- M
             Ops.STA_ABS,  0x80, 0x07,
             Ops.LDA_IMM,  0xF7,        -- A
             Ops.LDX_IMM,  0x73,
             Ops.LDY_IMM,  0x00,
             Ops.CMP_ABSX, 0x0D, 0x07,
             Ops.BRK },
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
             Ops.BRK },
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
             Ops.BRK },
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
             Ops.BRK },
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
             Ops.BRK },
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
             Ops.BRK },
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
             Ops.BRK },
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
             Ops.BRK },
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
             Ops.BRK },
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
             Ops.BRK },
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
             Ops.BRK },
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
             Ops.BRK },
    aVal = 0x19,
    xVal = 0x00,
    yVal = 0x71,
    zVal = false,
    nVal = true,
    cVal = false
  },
  ]]
}

for subTestIdx = 1, #testTbl do
  local curTest = testTbl[subTestIdx]

  local startPc = GetPc()
  nesdbg.CpuMemWr(startPc, #curTest.code, curTest.code)

  nesdbg.DbgRun()
  nesdbg.WaitForBrk()

  local ac = GetAc()
  local x  = GetX()
  local y  = GetY()
  local z  = GetZ()
  local n  = GetN()
  local v  = GetV()

  if ((ac == curTest.aVal) and
      (x == curTest.xVal) and
      (y == curTest.yVal) and
      (z == curTest.zVal) and
      (n == curTest.nVal) and
      (v == curTest.vVal)) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail

    print("ac: " .. ac .. " x: " .. x ..           " y: " .. y ..
          " z: " .. tostring(z) .. " n: " .. tostring(n) ..
          " v: " .. tostring(v) .. "\n")
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

