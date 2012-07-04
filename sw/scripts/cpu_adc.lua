----------------------------------------------------------------------------------------------------
-- Script:      cpu_adc.lua
-- Description: CPU test.  Directed test for ADC instruction.  Covers all address modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: ADC_IMM: Clear all flags
  {
    code = { Ops.LDA_IMM, 0x00,
             Ops.ADC_IMM, 0x00,
             Ops.LDA_IMM, 0x62,  -- A
             Ops.LDX_IMM, 0x00,
             Ops.LDY_IMM, 0x00,
             Ops.ADC_IMM, 0x1B,  -- M
             Ops.HLT },
    aVal = 0x7D,
    xVal = 0x00,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    vVal = false,
    nVal = false
  },

  -- Test 2: ADC_IMM: Set z, c flags
  {
    code = { Ops.LDA_IMM, 0x45,  -- A
             Ops.ADC_IMM, 0xBB,  -- M
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0x00,
    cVal = true,
    zVal = true,
    vVal = false,
    nVal = false
  },

  -- Test 3: ADC_IMM: Set v, n flags
  {
    code = { Ops.LDA_IMM, 0x7E,  -- A
             Ops.ADC_IMM, 0x03,  -- M
             Ops.HLT },
    aVal = 0x82,
    xVal = 0x00,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    vVal = true,
    nVal = true
  },
  
  -- Test 4: ADC_IMM: Set v, c, z flags
  {
    code = { Ops.LDA_IMM, 0x80,  -- A
             Ops.ADC_IMM, 0x80,  -- M
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0x00,
    cVal = true,
    zVal = true,
    vVal = true,
    nVal = false
  },

  -- Test 5: ADC_IMM: Set v, c flags
  {
    code = { Ops.LDA_IMM, 0x80,  -- A
             Ops.ADC_IMM, 0x80,  -- M
             Ops.HLT },
    aVal = 0x01,
    xVal = 0x00,
    yVal = 0x00,
    cVal = true,
    zVal = false,
    vVal = true,
    nVal = false
  },

  -- Test 6: ADC_ZP
  {
    code = { Ops.LDA_IMM, 0x99,  -- M
             Ops.STA_ZP,  0x52,
             Ops.LDA_IMM, 0x24,  -- A
             Ops.LDX_IMM, 0x00,
             Ops.ADC_ZP,  0x52,
             Ops.HLT },
    aVal = 0xBE,
    xVal = 0x00,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    vVal = false,
    nVal = true
  },

  -- Test 7: ADC_ZP
  {
    code = { Ops.LDA_IMM, 0x01,  -- M
             Ops.STA_ZP,  0x08,
             Ops.LDA_IMM, 0xFF,  -- A
             Ops.ADC_ZP,  0x08,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0x00,
    cVal = true,
    zVal = true,
    vVal = false,
    nVal = false
  },

  -- Test 8: ADC_ZPX
  {
    code = { Ops.LDA_IMM, 0xFA,  -- M
             Ops.STA_ZP,  0xC2,
             Ops.LDA_IMM, 0xB1,  -- A
             Ops.LDX_IMM, 0x13,
             Ops.ADC_ZPX, 0xAF,
             Ops.HLT },
    aVal = 0xAC,
    xVal = 0x13,
    yVal = 0x00,
    cVal = true,
    zVal = false,
    vVal = false,
    nVal = true
  },

  -- Test 9: ADC_ZPX
  {
    code = { Ops.LDA_IMM, 0x17,  -- M
             Ops.STA_ZP,  0x3A,
             Ops.LDA_IMM, 0x41,  -- A
             Ops.LDX_IMM, 0x7F,
             Ops.ADC_ZPX, 0xBB,
             Ops.HLT },
    aVal = 0x59,
    xVal = 0x7F,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    vVal = false,
    nVal = false
  },

  -- Test 10: ADC_ABS
  {
    code = { Ops.LDA_IMM, 0x26,        -- M
             Ops.STA_ABS, 0xC0, 0x05,
             Ops.LDA_IMM, 0x86,        -- A
             Ops.LDX_IMM, 0x00,
             Ops.ADC_ABS, 0xC0, 0x05,
             Ops.HLT },
    aVal = 0xAC,
    xVal = 0x00,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    vVal = false,
    nVal = true
  },

  -- Test 11: ADC_ABS
  {
    code = { Ops.LDA_IMM, 0x42,        -- M
             Ops.STA_ABS, 0x03, 0x03,
             Ops.LDA_IMM, 0x13,        -- A
             Ops.ADC_ABS, 0x03, 0x03,
             Ops.HLT },
    aVal = 0x55,
    xVal = 0x00,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    vVal = false,
    nVal = false
  },
  
  -- Test 12: ADC_ABSX
  {
    code = { Ops.LDA_IMM,  0x8C,        -- M
             Ops.STA_ABS,  0x80, 0x07,
             Ops.LDA_IMM,  0xC7,        -- A
             Ops.LDX_IMM,  0x73,
             Ops.LDY_IMM,  0x00,
             Ops.ADC_ABSX, 0x0D, 0x07,
             Ops.HLT },
    aVal = 0x53,
    xVal = 0x73,
    yVal = 0x00,
    cVal = true,
    zVal = false,
    vVal = true,
    nVal = false
  },

  -- Test 13: ADC_ABSY
  {
    code = { Ops.LDA_IMM,  0xFF,        -- M
             Ops.STA_ABS,  0x10, 0x03,
             Ops.LDA_IMM,  0x00,        -- A
             Ops.LDY_IMM,  0x86,
             Ops.LDX_IMM,  0x00,
             Ops.ADC_ABSY, 0x8A, 0x02,
             Ops.HLT },
    aVal = 0x00,
    xVal = 0x00,
    yVal = 0x86,
    cVal = true,
    zVal = true,
    vVal = false,
    nVal = false
  },

  -- Test 14: ADC_INDX
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
             Ops.ADC_INDX, 0x30,
             Ops.HLT },
    aVal = 0xF4,
    xVal = 0x14,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    vVal = false,
    nVal = true
  },

  -- Test 15: ADC_INDY
  {
    code = { Ops.LDA_IMM,  0x09,        -- M
             Ops.STA_ABS,  0x50, 0x05,
             Ops.LDA_IMM,  0xDF,
             Ops.STA_ZP,   0xD6,
             Ops.LDA_IMM,  0x04,
             Ops.STA_ZP,   0xD7,
             Ops.LDA_IMM,  0x07,        -- A
             Ops.LDY_IMM,  0x71,
             Ops.LDX_IMM,  0x00,
             Ops.ADC_INDY, 0xD6,
             Ops.HLT },
    aVal = 0x10,
    xVal = 0x00,
    yVal = 0x71,
    cVal = false,
    zVal = false,
    vVal = false,
    nVal = false
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
  local c  = GetC()
  local z  = GetZ()
  local v  = GetV()
  local n  = GetN()

  if ((ac == curTest.aVal) and
      (x == curTest.xVal) and
      (y == curTest.yVal) and
      (c == curTest.cVal) and
      (z == curTest.zVal) and
      (v == curTest.vVal) and
      (n == curTest.nVal)) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail

    print("ac: " .. ac .. " x: " .. x ..           " y: " .. y ..
          " c: " .. tostring(c) .. " z: " .. tostring(z) .. 
          " v: " .. tostring(v) .. " n: " .. tostring(n) .. "\n")
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

