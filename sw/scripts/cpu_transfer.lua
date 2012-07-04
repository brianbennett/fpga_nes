----------------------------------------------------------------------------------------------------
-- Script:      cpu_transfer.lua
-- Description: CPU test.  Directed test for transfer instructions: TAX, TAY, TSX, TXA, TXS, and
--              TYA.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: TXS Verify z is not cleared, n is not set
  {
    code = { Ops.LDA_IMM, 33,
             Ops.LDX_IMM, 177,
             Ops.LDY_IMM, 0,
             Ops.TXS,
             Ops.HLT },
    aVal = 33,
    xVal = 177,
    yVal = 0,
    sVal = 177,
    zVal = true,
    nVal = false
  },

  -- Test 2: TXS Verify n is not cleared, z is not set
  {
    code = { Ops.LDX_IMM, 0,
             Ops.LDA_IMM, 255,
             Ops.TXS,
             Ops.HLT },
    aVal = 255,
    xVal = 0,
    yVal = 0,
    sVal = 0,
    zVal = false,
    nVal = true
  },
  
  -- Test 3: TAX Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM, 232,
             Ops.LDX_IMM, 146,
             Ops.LDY_IMM, 0,
             Ops.TAX,
             Ops.HLT },
    aVal = 232,
    xVal = 232,
    yVal = 0,
    sVal = 0,
    zVal = false,
    nVal = true
  },

  -- Test 4: TAX Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM, 0,
             Ops.LDY_IMM, 196,
             Ops.TAX,
             Ops.HLT },
    aVal = 0,
    xVal = 0,
    yVal = 196,
    sVal = 0,
    zVal = true,
    nVal = false
  },

  -- Test 5: TAY Verify z is cleared, n is set
  {
    code = { Ops.LDA_IMM, 128,
             Ops.LDX_IMM, 0,
             Ops.TAY,
             Ops.HLT },
    aVal = 128,
    xVal = 0,
    yVal = 128,
    sVal = 0,
    zVal = false,
    nVal = true
  },

  -- Test 6: TAY Verify n is cleared, z is set
  {
    code = { Ops.LDA_IMM, 0,
             Ops.LDX_IMM, 211,
             Ops.TAY,
             Ops.HLT },
    aVal = 0,
    xVal = 211,
    yVal = 0,
    sVal = 0,
    zVal = true,
    nVal = false
  },

  -- Test 7: TSX Verify z is cleared, n is set
  {
    code = { Ops.LDX_IMM, 142,
             Ops.TXS,
             Ops.LDX_IMM, 0,
             Ops.TSX,
             Ops.HLT },
    aVal = 0,
    xVal = 142,
    yVal = 0,
    sVal = 142,
    zVal = false,
    nVal = true
  },

  -- Test 8: TSX Verify n is cleared, z is set
  {
    code = { Ops.LDX_IMM, 0,
             Ops.TXS,
             Ops.LDX_IMM, 222,
             Ops.TSX,
             Ops.HLT },
    aVal = 0,
    xVal = 0,
    yVal = 0,
    sVal = 0,
    zVal = true,
    nVal = false
  },
  
  -- Test 9: TXA Verify z is cleared, n is set
  {
    code = { Ops.LDX_IMM, 253,
             Ops.LDY_IMM, 0,
             Ops.TXA,
             Ops.HLT },
    aVal = 253,
    xVal = 253,
    yVal = 0,
    sVal = 0,
    zVal = false,
    nVal = true
  },

  -- Test 10: TXA Verify n is cleared, z is set
  {
    code = { Ops.LDX_IMM, 0,
             Ops.LDY_IMM, 152,
             Ops.TXA,
             Ops.HLT },
    aVal = 0,
    xVal = 0,
    yVal = 152,
    sVal = 0,
    zVal = true,
    nVal = false
  },
  
  -- Test 11: TYA Verify z is cleared, n is set
  {
    code = { Ops.LDY_IMM, 175,
             Ops.LDX_IMM, 0,
             Ops.TYA,
             Ops.HLT },
    aVal = 175,
    xVal = 0,
    yVal = 175,
    sVal = 0,
    zVal = false,
    nVal = true
  },

  -- Test 12: TYA Verify n is cleared, z is set
  {
    code = { Ops.LDY_IMM, 0,
             Ops.LDX_IMM, 211,
             Ops.TYA,
             Ops.HLT },
    aVal = 0,
    xVal = 211,
    yVal = 0,
    sVal = 0,
    zVal = true,
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
  local s  = GetS()
  local z  = GetZ()
  local n  = GetN()

  if ((ac == curTest.aVal) and
      (x == curTest.xVal) and
      (y == curTest.yVal) and
      (s == curTest.sVal) and
      (z == curTest.zVal) and
      (n == curTest.nVal)) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail

    print("ac: " .. ac .. " x: " .. x ..           " y: " .. y .. 
          " s: " .. s  .. " z: " .. tostring(z) .. " n: " .. tostring(n) .. "\n")
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

