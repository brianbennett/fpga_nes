----------------------------------------------------------------------------------------------------
-- Script:      cpu_ld_imm.lua
-- Description: CPU test.  Directed test for LDA, LDX, LDY immediate ops.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1
  { code = { Ops.LDA_IMM, 0x71, Ops.LDX_IMM, 0xFF, Ops.LDY_IMM, 0x00, Ops.HLT },
    aVal = 0x71, xVal = 0xFF, yVal = 0x00, zVal = true,  nVal = false },

  -- Test 2
  { code = { Ops.NOP, Ops.LDA_IMM, 0xBB, Ops.HLT },
    aVal = 0xBB, xVal = 0xFF, yVal = 0x00, zVal = false, nVal = true  },

  -- Test 3
  { code = { Ops.NOP, Ops.LDX_IMM, 0x13, Ops.HLT },
    aVal = 0xBB, xVal = 0x13, yVal = 0x00, zVal = false, nVal = false },

  -- Test 4
  { code = { Ops.NOP, Ops.LDY_IMM, 0x01, Ops.HLT },
    aVal = 0xBB, xVal = 0x13, yVal = 0x01, zVal = false, nVal = false },

  -- Test 5
  { code = { Ops.NOP, Ops.NOP, Ops.LDA_IMM, 0x1B, Ops.LDA_IMM, 0x29, Ops.NOP, Ops.HLT },
    aVal = 0x29, xVal = 0x13, yVal = 0x01, zVal = false, nVal = false },

  -- Test 6
  { code = { Ops.NOP, Ops.NOP, Ops.LDX_IMM, 0x29, Ops.LDX_IMM, 0x80, Ops.NOP, Ops.HLT },
    aVal = 0x29, xVal = 0x80, yVal = 0x01, zVal = false, nVal = true  },

  -- Test 7
  { code = { Ops.NOP, Ops.NOP, Ops.LDY_IMM, 0xFF, Ops.LDY_IMM, 0x00, Ops.NOP, Ops.HLT },
    aVal = 0x29, xVal = 0x80, yVal = 0x00, zVal = true, nVal = false },

  -- Test 8
  { code = { Ops.NOP, Ops.NOP, Ops.NOP, Ops.HLT },
    aVal = 0x29, xVal = 0x80, yVal = 0x00, zVal = true, nVal = false },

  -- Test 9
  { code = { Ops.LDX_IMM, 68,      Ops.LDA_IMM, 129,     Ops.LDA_IMM, 183,  Ops.LDA_IMM, 32,
             Ops.NOP,     Ops.NOP, Ops.NOP,     Ops.NOP, Ops.LDA_IMM, 215,  Ops.NOP,     Ops.HLT },
    aVal = 215, xVal = 68, yVal = 0, zVal = false, nVal = true },

  -- Test 10
  { code = { Ops.LDY_IMM, 247,     Ops.LDX_IMM, 232,     Ops.LDA_IMM, 65,   Ops.LDA_IMM, 228,
             Ops.NOP,     Ops.NOP, Ops.NOP,     Ops.NOP, Ops.LDX_IMM, 88,   Ops.NOP,     Ops.HLT },
    aVal = 228, xVal = 88, yVal = 247, zVal = false, nVal = false },

  -- Test 11
  { code = { Ops.LDY_IMM, 20,      Ops.LDX_IMM, 43,      Ops.LDY_IMM, 231,  Ops.LDA_IMM, 222,
             Ops.NOP,     Ops.NOP, Ops.NOP,     Ops.NOP, Ops.LDX_IMM, 241,  Ops.NOP,     Ops.HLT },
    aVal = 222, xVal = 241, yVal = 231, zVal = false, nVal = true },

  -- Test 12
  { code = { Ops.NOP, Ops.NOP, Ops.LDA_IMM, 0x1B, Ops.LDA_IMM, 0x00, Ops.NOP, Ops.HLT },
    aVal = 0x00, xVal = 241, yVal = 231, zVal = true, nVal = false },

  -- Test 13
  { code = { Ops.NOP, Ops.NOP, Ops.LDX_IMM, 0x3B, Ops.LDX_IMM, 0x00, Ops.NOP, Ops.HLT },
    aVal = 0x00, xVal = 0x00, yVal = 231, zVal = true, nVal = false },

  -- Test 14
  { code = { Ops.NOP, Ops.NOP, Ops.LDY_IMM, 0x5B, Ops.LDY_IMM, 0x00, Ops.NOP, Ops.HLT },
    aVal = 0x00, xVal = 0x00, yVal = 0x00, zVal = true, nVal = false },
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

--  print("ac: " .. ac .. " x: " .. x .. " y: " .. y .. "\n")

  if ((ac == curTest.aVal) and (x == curTest.xVal) and (y == curTest.yVal) and
      (z == curTest.zVal) and (n == curTest.nVal)) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

