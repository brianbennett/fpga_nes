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
             Ops.HLT },
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
             Ops.HLT },
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
             Ops.HLT },
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
             Ops.HLT },
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
             Ops.HLT },
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
             Ops.HLT },
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
             Ops.HLT },
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
             Ops.HLT },
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
             Ops.HLT },
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
             Ops.HLT },
    aVal = 0x38,
    xVal = 0x00,
    yVal = 0x00,
    zVal = true,
    nVal = true,
    vVal = true
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

