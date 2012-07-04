----------------------------------------------------------------------------------------------------
-- Script:      cpu_stack.lua
-- Description: CPU test.  Directed test for PHA, PLA, PHP, and PLP instructions.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: Push 3 values onto the stack.
  {
    code = { Ops.LDA_IMM, 0x00,
             Ops.PHA,
             Ops.PLP,
             Ops.LDY_IMM, 0x00,
             Ops.LDX_IMM, 0xFF,
             Ops.TXS,
             Ops.LDA_IMM, 0x6a,
             Ops.PHA,
             Ops.LDA_IMM, 0x15,
             Ops.PHA,
             Ops.LDA_IMM, 0xC3,
             Ops.PHA,
             Ops.HLT },
    sVal = 0xFC,
    aVal = 0xC3,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = true,
    addrs = { 0x01FF, 0x01FE, 0x01FD },
    vals  = {   0x6A,   0x15,   0xC3 }
  },

  -- Test 2:
  {
    code = { Ops.LDA_IMM, 0x00,
             Ops.PLA,
             Ops.HLT },
    sVal = 0xFD,
    aVal = 0xC3,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = true,
    addrs = { 0x01FF, 0x01FE, 0x01FD },
    vals  = {   0x6A,   0x15,   0xC3 }
  },
  
  -- Test 3:
  {
    code = { Ops.LDA_IMM, 0x33,
             Ops.PLA,
             Ops.HLT },
    sVal = 0xFE,
    aVal = 0x15,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = { 0x01FF, 0x01FE, 0x01FD },
    vals  = {   0x6A,   0x15,   0xC3 }
  },
  
  -- Test 4:
  {
    code = { Ops.LDA_IMM, 0x33,
             Ops.LDA_IMM, 0xAA,
             Ops.PHA,
             Ops.LDA_IMM, 0xBB,
             Ops.PHA,
             Ops.LDA_IMM, 0xCC,
             Ops.PHA,
             Ops.LDA_IMM, 0xDD,
             Ops.PHA,
             Ops.PLA,
             Ops.PLA,
             Ops.PLA,
             Ops.PLA,
             Ops.PLA,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x6A,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = { 0x01FF, 0x01FE, 0x01FD, 0x01FC, 0x01FB },
    vals  = {   0x6A,   0xAA,   0xBB,   0xCC,   0xDD }
  },

  -- Test 5:
  {
    code = { Ops.LDA_IMM, 0x01,
             Ops.SEC,
             Ops.SED,
             Ops.SEI,
             Ops.PHP,
             Ops.PLA,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x3D,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = true,
    zVal = false,
    iVal = true,
    dVal = true,
    vVal = false,
    nVal = false,
    addrs = { 0x01FF, 0x01FE, 0x01FD, 0x01FC, 0x01FB },
    vals  = {   0x3D,   0xAA,   0xBB,   0xCC,   0xDD }
  },

  -- Test 6:
  {
    code = { Ops.LDA_IMM, 0xC0,
             Ops.PHA,
             Ops.PLP,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0xC0,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = true,
    nVal = true,
    addrs = { 0x01FF, 0x01FE, 0x01FD, 0x01FC, 0x01FB },
    vals  = {   0xC0,   0xAA,   0xBB,   0xCC,   0xDD }
  },

  -- Test 7:
  {
    code = { Ops.LDA_IMM, 0xE1,
             Ops.PHA,
             Ops.LDA_IMM, 0xE2,
             Ops.PHA,
             Ops.LDA_IMM, 0xE3,
             Ops.PHA,
             Ops.LDA_IMM, 0x65,
             Ops.PHA,
             Ops.LDA_IMM, 0xE5,
             Ops.PHA,
             Ops.LDA_IMM, 0xE6,
             Ops.PHA,
             Ops.PLP,
             Ops.PLA,
             Ops.TAX,
             Ops.PLP,
             Ops.PLA,
             Ops.HLT },
    sVal = 0xFD,
    aVal = 0xE3,
    xVal = 0xE5,
    yVal = 0x00,
    cVal = true,
    zVal = false,
    iVal = true,
    dVal = false,
    vVal = true,
    nVal = true,
    addrs = { 0x01FF, 0x01FE, 0x01FD, 0x01FC, 0x01FB, 0x01FA },
    vals  = {   0xE1,   0xE2,   0xE3,   0x65,   0xE5,   0xE6 }
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

  local c  = GetC()
  local z  = GetZ()
  local i  = GetI()
  local d  = GetD()
  local v  = GetV()
  local n  = GetN()
  
  if ((ac == curTest.aVal) and
      (x == curTest.xVal) and
      (y == curTest.yVal) and
      (s == curTest.sVal) and
      (c == curTest.cVal) and
      (z == curTest.zVal) and
      (i == curTest.iVal) and
      (d == curTest.dVal) and
      (v == curTest.vVal) and
      (n == curTest.nVal)) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail

    print("s: "  .. s           .. " ac: " .. ac          .. " x: " .. x .. " y: " .. y ..
          " c: " .. tostring(c) .. " z: " .. tostring(z) .. " i: " .. tostring(i) ..
          " d: " .. tostring(d) .. " v: " .. tostring(v) .. " n: " .. tostring(n) .. "\n")
  end

  for addrIdx = 1, #curTest.addrs do
    local val = nesdbg.CpuMemRd(curTest.addrs[addrIdx], 1)
    if val[1] ~= curTest.vals[addrIdx] then
      print("Expected: " .. curTest.vals[addrIdx] .. ", Result: " .. val[1] .. "\n")
      val = nesdbg.CpuMemRd(0x100, 256)
      for i = 1, 256 do
        print(val[256 - i + 1] .. " ")
      end
      print("\n")
      results[subTestIdx] = ScriptResult.Fail
      break
    end
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

