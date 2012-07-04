----------------------------------------------------------------------------------------------------
-- Script:      cpu_ld_st_abs.lua
-- Description: CPU test.  Directed tests for lda, ldx, ldy, sta, stx, sty instructions with the
--              various absolute address modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1
  {
    code  = { Ops.LDA_IMM, 169,
              Ops.LDX_IMM, 69,
              Ops.LDY_IMM, 245,
              Ops.STA_ABS, 0x0C, 0x07,
              Ops.HLT },
    aVal  = 169,
    xVal  = 69,
    yVal  = 245,
    zVal  = false,
    nVal  = true,
    addrs = { 0x070C },
    vals  = {    169 }
  },

  -- Test 2
  {
    code  = { Ops.STX_ABS, 0xA1, 0x03,
              Ops.HLT },
    aVal  = 169,
    xVal  = 69,
    yVal  = 245,
    zVal  = false,
    nVal  = true,
    addrs = { 0x070C, 0x03A1 },
    vals  = {    169,     69 }
  },

  -- Test 3
  {
    code  = { Ops.STY_ABS, 0x09, 0x04,
              Ops.HLT },
    aVal  = 169,
    xVal  = 69,
    yVal  = 245,
    zVal  = false,
    nVal  = true,
    addrs = { 0x070C, 0x03A1, 0x0409 },
    vals  = {    169,     69,    245 }
  },

  -- Test 4
  {
    code  = { Ops.LDA_ABS, 0xA1, 0x03,
              Ops.HLT },
    aVal  = 69,
    xVal  = 69,
    yVal  = 245,
    zVal  = false,
    nVal  = false,
    addrs = { 0x070C, 0x03A1, 0x0409 },
    vals  = {    169,     69,    245 }
  },

  -- Test 5
  {
    code  = { Ops.LDX_ABS, 0x09, 0x04,
              Ops.HLT },
    aVal  = 69,
    xVal  = 245,
    yVal  = 245,
    zVal  = false,
    nVal  = true,
    addrs = { 0x070C, 0x03A1, 0x0409 },
    vals  = {    169,     69,    245 }
  },

  -- Test 6
  {
    code  = { Ops.LDY_ABS, 0x0C, 0x07,
              Ops.HLT },
    aVal  = 69,
    xVal  = 245,
    yVal  = 169,
    zVal  = false,
    nVal  = true,
    addrs = { 0x070C, 0x03A1, 0x0409 },
    vals  = {    169,     69,    245 }
  },

  -- Test 6
  {
    code  = { Ops.LDA_IMM,  222,
              Ops.LDX_IMM,  0x11,
              Ops.STA_ABSX, 0x22, 0x03,
              Ops.HLT },
    aVal  = 222,
    xVal  = 17,
    yVal  = 169,
    zVal  = false,
    nVal  = false,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333 },
    vals  = {    169,     69,    245,    222 }
  },

  -- Test 7
  {
    code  = { Ops.LDA_IMM,  194,
              Ops.LDX_IMM,  0xE9,
              Ops.STA_ABSX, 0x3B, 0x03,
              Ops.HLT },
    aVal  = 194,
    xVal  = 0xE9,
    yVal  = 169,
    zVal  = false,
    nVal  = true,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424 },
    vals  = {    169,     69,    245,    222,    194 }
  },

  -- Test 9
  {
    code  = { Ops.LDA_IMM,  71,
              Ops.LDY_IMM,  0x37,
              Ops.STA_ABSY, 0x19, 0x07,
              Ops.HLT },
    aVal  = 71,
    xVal  = 0xE9,
    yVal  = 0x37,
    zVal  = false,
    nVal  = false,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424, 0x0750 },
    vals  = {    169,     69,    245,    222,    194,     71 }
  },

  -- Test 10
  {
    code  = { Ops.LDA_IMM,  122,
              Ops.LDY_IMM,  0x93,
              Ops.STA_ABSY, 0xAD, 0x05,
              Ops.HLT },
    aVal  = 122,
    xVal  = 0xE9,
    yVal  = 0x93,
    zVal  = false,
    nVal  = true,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424, 0x0750, 0x0640 },
    vals  = {    169,     69,    245,    222,    194,     71,    122 }
  },

  -- Test 11
  {
    code  = { Ops.LDX_IMM,  0x1C,
              Ops.LDA_ABSX, 0x34, 0x07,
              Ops.HLT },
    aVal  = 71,
    xVal  = 0x1C,
    yVal  = 0x93,
    zVal  = false,
    nVal  = false,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424, 0x0750, 0x0640 },
    vals  = {    169,     69,    245,    222,    194,     71,    122 }
  },

  -- Test 12
  {
    code  = { Ops.LDX_IMM,  0x4F,
              Ops.LDA_ABSX, 0xE4, 0x02,
              Ops.HLT },
    aVal  = 222,
    xVal  = 0x4F,
    yVal  = 0x93,
    zVal  = false,
    nVal  = true,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424, 0x0750, 0x0640 },
    vals  = {    169,     69,    245,    222,    194,     71,    122 }
  },

  -- Test 13
  {
    code  = { Ops.LDY_IMM,  0x79,
              Ops.LDA_ABSY, 0x28, 0x03,
              Ops.HLT },
    aVal  = 69,
    xVal  = 0x4F,
    yVal  = 0x79,
    zVal  = false,
    nVal  = false,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424, 0x0750, 0x0640 },
    vals  = {    169,     69,    245,    222,    194,     71,    122 }
  },

  -- Test 14
  {
    code  = { Ops.LDY_IMM,  0x0A,
              Ops.LDA_ABSY, 0xFF, 0x03,
              Ops.HLT },
    aVal  = 245,
    xVal  = 0x4F,
    yVal  = 0x0A,
    zVal  = false,
    nVal  = true,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424, 0x0750, 0x0640 },
    vals  = {    169,     69,    245,    222,    194,     71,    122 }
  },
  
  -- Test 15
  {
    code  = { Ops.LDY_IMM,  0x20,
              Ops.LDX_ABSY, 0x30, 0x07,
              Ops.HLT },
    aVal  = 245,
    xVal  = 71,
    yVal  = 0x20,
    zVal  = false,
    nVal  = false,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424, 0x0750, 0x0640 },
    vals  = {    169,     69,    245,    222,    194,     71,    122 }
  },

  -- Test 16
  {
    code  = { Ops.LDY_IMM,  0xA2,
              Ops.LDX_ABSY, 0xFF, 0x02,
              Ops.HLT },
    aVal  = 245,
    xVal  = 69,
    yVal  = 0xA2,
    zVal  = false,
    nVal  = false,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424, 0x0750, 0x0640 },
    vals  = {    169,     69,    245,    222,    194,     71,    122 }
  },

  -- Test 17
  {
    code  = { Ops.LDX_IMM,  0x01,
              Ops.LDY_ABSX, 0x0B, 0x07,
              Ops.HLT },
    aVal  = 245,
    xVal  = 0x01,
    yVal  = 169,
    zVal  = false,
    nVal  = true,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424, 0x0750, 0x0640 },
    vals  = {    169,     69,    245,    222,    194,     71,    122 }
  },

  -- Test 18
  {
    code  = { Ops.LDX_IMM,  0x41,
              Ops.LDY_ABSX, 0xFF, 0x05,
              Ops.HLT },
    aVal  = 245,
    xVal  = 0x41,
    yVal  = 122,
    zVal  = false,
    nVal  = false,
    addrs = { 0x070C, 0x03A1, 0x0409, 0x0333, 0x0424, 0x0750, 0x0640 },
    vals  = {    169,     69,    245,    222,    194,     71,    122 }
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
      print("@ addr: " .. test.addrs[addrIdx] .. "Expected: " .. test.vals[addrIdx] .. ", Result: " .. val[1] .. "\n")
      zp = nesdbg.CpuMemRd(0, 0x800)
      for j=1,0x800 do
        print(zp[j] .. " ")
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

