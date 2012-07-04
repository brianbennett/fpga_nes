----------------------------------------------------------------------------------------------------
-- Script:      cpu_ld_st_zp.lua
-- Description: CPU test.  Directed tests for lda, ldx, ldy, sta, stx, sty instructions with the
--              various zero page address modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1
  {
    code  = { Ops.LDA_IMM, 7,
              Ops.LDX_IMM, 61,
              Ops.LDY_IMM, 103,
              Ops.STA_ZP,  48,
              Ops.HLT },
    aVal  = 7,
    xVal  = 61,
    yVal  = 103,
    zVal  = false,
    nVal  = false,
    addrs = { 48 },
    vals  = {  7 }
  },

  -- Test 2
  {
    code  = { Ops.LDX_IMM, 166,
              Ops.STX_ZP,  19,
              Ops.HLT },
    aVal  = 7,
    xVal  = 166,
    yVal  = 103,
    zVal  = false,
    nVal  = true,
    addrs = { 48,  19 },
    vals  = {  7, 166 }
  },

  -- Test 3
  {
    code  = { Ops.LDY_IMM, 45,
              Ops.STY_ZP,  136,
              Ops.HLT },
    aVal  = 7,
    xVal  = 166,
    yVal  = 45,
    zVal  = false,
    nVal  = false,
    addrs = { 48,  19, 136 },
    vals  = {  7, 166,  45 }
  },

  -- Test 4
  {
    code  = { Ops.LDA_ZP, 19,
              Ops.HLT },
    aVal  = 166,
    xVal  = 166,
    yVal  = 45,
    zVal  = false,
    nVal  = true,
    addrs = { 48,  19, 136 },
    vals  = {  7, 166,  45 }
  },

  -- Test 5
  {
    code  = { Ops.LDX_ZP, 136,
              Ops.HLT },
    aVal  = 166,
    xVal  = 45,
    yVal  = 45,
    zVal  = false,
    nVal  = false,
    addrs = { 48,  19, 136 },
    vals  = {  7, 166,  45 }
  },

  -- Test 6
  {
    code  = { Ops.LDY_ZP, 48,
              Ops.HLT },
    aVal  = 166,
    xVal  = 45,
    yVal  = 7,
    zVal  = false,
    nVal  = false,
    addrs = { 48,  19, 136 },
    vals  = {  7, 166,  45 }
  },

  -- Test 7
  {
    code  = { Ops.STA_ZPX, 171,
              Ops.HLT },
    aVal  = 166,
    xVal  = 45,
    yVal  = 7,
    zVal  = false,
    nVal  = false,
    addrs = { 48,  19, 136, 216 },
    vals  = {  7, 166,  45, 166 }
  },

  -- Test 8
  {
    code  = { Ops.STA_ZPX, 233,
              Ops.HLT },
    aVal  = 166,
    xVal  = 45,
    yVal  = 7,
    zVal  = false,
    nVal  = false,
    addrs = { 48,  19, 136, 216, 22 },
    vals  = {  7, 166,  45, 166, 166 }
  },

  -- Test 9
  {
    code  = { Ops.STX_ZPY, 224,
              Ops.HLT },
    aVal  = 166,
    xVal  = 45,
    yVal  = 7,
    zVal  = false,
    nVal  = false,
    addrs = { 48,  19, 136, 216, 22,  231 },
    vals  = {  7, 166,  45, 166, 166, 45  }
  },

  -- Test 10
  {
    code  = { Ops.STY_ZPX, 91,
              Ops.HLT },
    aVal  = 166,
    xVal  = 45,
    yVal  = 7,
    zVal  = false,
    nVal  = false,
    addrs = { 48,  19, 136, 216, 22,  231 },
    vals  = {  7, 166,   7, 166, 166, 45  }
  },

  -- Test 11
  {
    code  = { Ops.LDA_ZPX, 186,
              Ops.HLT },
    aVal  = 45,
    xVal  = 45,
    yVal  = 7,
    zVal  = false,
    nVal  = false,
    addrs = { 48,  19, 136, 216, 22,  231 },
    vals  = {  7, 166,   7, 166, 166, 45  }
  },

  -- Test 12
  {
    code  = { Ops.LDX_ZPY, 209,
              Ops.HLT },
    aVal  = 45,
    xVal  = 166,
    yVal  = 7,
    zVal  = false,
    nVal  = true,
    addrs = { 48,  19, 136, 216, 22,  231 },
    vals  = {  7, 166,   7, 166, 166, 45  }
  },

  -- Test 13
  {
    code  = { Ops.LDY_ZPX, 112,
              Ops.HLT },
    aVal  = 45,
    xVal  = 166,
    yVal  = 166,
    zVal  = false,
    nVal  = true,
    addrs = { 48,  19, 136, 216, 22,  231 },
    vals  = {  7, 166,   7, 166, 166, 45  }
  },  
}

-- EvaluateSubtest()
function EvaluateSubtest(test)
  local ac = GetAc()
  local x  = GetX()
  local y  = GetY()
  local z  = GetZ()
  local n  = GetN()

  if ((ac ~= test.aVal) or
      (x ~= test.xVal)  or
      (y ~= test.yVal)  or
      (z ~= test.zVal)  or
      (n ~= test.nVal))
  then
    print("ac: " .. ac .. " x: " .. x .. " y: " .. y .. " z: " .. tostring(z) .. " n: " .. tostring(n) .. "\n")
    return false
  end

  for addrIdx = 1, #test.addrs do
    local val = nesdbg.CpuMemRd(test.addrs[addrIdx], 1)
    if val[1] ~= test.vals[addrIdx] then
      print("Expected: " .. test.vals[addrIdx] .. ", Result: " .. val[1] .. "\n")
      val = nesdbg.CpuMemRd(0, 256)
      for i = 1, 256 do
        print(val[i] .. " ")
      end
      print("\n")
      return false
    end
  end

  return true
end

for subTestIdx = 1, #testTbl do
  local curTest = testTbl[subTestIdx]

  local startPc = GetPc()

  nesdbg.CpuMemWr(startPc, #curTest.code, curTest.code)

  nesdbg.DbgRun()
  nesdbg.WaitForHlt()

  if EvaluateSubtest(curTest) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

