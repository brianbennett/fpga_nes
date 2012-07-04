----------------------------------------------------------------------------------------------------
-- Script:      cpu_ld_st_ind.lua
-- Description: CPU test.  Directed tests for lda and sta instructions with the various indirect
--              address modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: LDA_INDX
  {
    -- @ 0x0627 = 0x38
    -- @ 0x00A2 = 0x0627
    code  = { Ops.LDA_IMM,  0x38,
              Ops.STA_ABS,  0x27, 0x06,
              Ops.LDA_IMM,  0x27,
              Ops.STA_ABS,  0xA2, 0x00,
              Ops.LDA_IMM,  0x06,
              Ops.STA_ABS,  0xA3, 0x00,

              Ops.LDX_IMM,  0x0F,
              Ops.LDA_INDX, 0x93,

              Ops.LDY_IMM,  0x00,
              Ops.HLT },
    aVal  = 0x38,
    xVal  = 0x0F,
    yVal  = 0x00,
    zVal  = true,
    nVal  = false,
    addrs = { 0x0627, 0x00A2, 0x00A3 },
    vals  = {   0x38,   0x27,   0x06 }
  },

  -- Test 2: LDA_INDX w/ X wrapping
  {
    -- @ 0x04F1 = 0x89
    -- @ 0x0019 = 0x04F1
    code  = { Ops.LDA_IMM,  0x89,
              Ops.STA_ABS,  0xF1, 0x04,
              Ops.LDA_IMM,  0xF1,
              Ops.STA_ABS,  0x19, 0x00,
              Ops.LDA_IMM,  0x04,
              Ops.STA_ABS,  0x1A, 0x00,

              Ops.LDX_IMM,  0xF8,
              Ops.LDA_INDX, 0x21,
              Ops.HLT },
    aVal  = 0x89,
    xVal  = 0xF8,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    addrs = { 0x0627, 0x00A2, 0x00A3, 0x04F1, 0x0019, 0x001A },
    vals  = {   0x38,   0x27,   0x06,   0x89,   0xF1,   0x04 }
  },

  -- Test 3: STA_INDX
  {
    code  = { Ops.LDA_IMM , 0xFE,
              Ops.LDX_IMM,  0x09,
              Ops.STA_INDX, 0x99,
              Ops.HLT },
    aVal  = 0xFE,
    xVal  = 0x09,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    addrs = { 0x0627, 0x00A2, 0x00A3, 0x04F1, 0x0019, 0x001A },
    vals  = {   0xFE,   0x27,   0x06,   0x89,   0xF1,   0x04 }
  },

  -- Test 4: STA_INDX w/ X wrapping
  {
    code  = { Ops.LDA_IMM , 0x77,
              Ops.LDX_IMM,  0x5C,
              Ops.STA_INDX, 0xBD,
              Ops.HLT },
    aVal  = 0x77,
    xVal  = 0x5C,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    addrs = { 0x0627, 0x00A2, 0x00A3, 0x04F1, 0x0019, 0x001A },
    vals  = {   0xFE,   0x27,   0x06,   0x77,   0xF1,   0x04 }
  },

  -- Test 5: LDA_INDY
  {
    -- @ 0x079C = 0xC1
    -- @ 0x001E = 0x0732
    code  = { Ops.LDA_IMM,  0xC1,
              Ops.STA_ABS,  0x9C, 0x07,
              Ops.LDA_IMM,  0x32,
              Ops.STA_ABS,  0x1E, 0x00,
              Ops.LDA_IMM,  0x07,
              Ops.STA_ABS,  0x1F, 0x00,

              Ops.LDY_IMM,  0x6A,
              Ops.LDA_INDY, 0x1E,
              Ops.HLT },
    aVal  = 0xC1,
    xVal  = 0x5C,
    yVal  = 0x6A,
    zVal  = false,
    nVal  = true,
    addrs = { 0x0627, 0x00A2, 0x00A3, 0x04F1, 0x0019, 0x001A, 0x079C, 0x001E, 0x001F },
    vals  = {   0xFE,   0x27,   0x06,   0x77,   0xF1,   0x04,   0xC1,   0x32,   0x07 }
  },
  
  -- Test 5: LDA_INDY w/ page boundary crossing
  {
    -- @ 0x0031 = 0x05E2
    code  = { Ops.LDA_IMM,  0xE2,
              Ops.STA_ABS,  0x31, 0x00,
              Ops.LDA_IMM,  0x05,
              Ops.STA_ABS,  0x32, 0x00,

              Ops.LDY_IMM,  0x45,
              Ops.LDA_INDY, 0x31,
              Ops.HLT },
    aVal  = 0xFE,
    xVal  = 0x5C,
    yVal  = 0x45,
    zVal  = false,
    nVal  = true,
    addrs = { 0x0627, 0x00A2, 0x00A3, 0x04F1, 0x0019, 0x001A, 0x079C, 0x001E, 0x001F },
    vals  = {   0xFE,   0x27,   0x06,   0x77,   0xF1,   0x04,   0xC1,   0x32,   0x07 }
  },
  
  -- Test 6: STA_INDY
  {
    code  = { Ops.LDA_IMM , 0x9D,
              Ops.LDY_IMM,  0x15,
              Ops.STA_INDY, 0xA2,
              Ops.HLT },
    aVal  = 0x9D,
    xVal  = 0x5C,
    yVal  = 0x15,
    zVal  = false,
    nVal  = false,
    addrs = { 0x0627, 0x00A2, 0x00A3, 0x04F1, 0x0019, 0x001A, 0x079C, 0x001E, 0x001F, 0x063C },
    vals  = {   0xFE,   0x27,   0x06,   0x77,   0xF1,   0x04,   0xC1,   0x32,   0x07,   0x9D }
  },
  
  -- Test 4: STA_INDY w/ page boundary crossing
  {
    code  = { Ops.LDA_IMM , 0xC1,
              Ops.LDY_IMM,  0xF0,
              Ops.STA_INDY, 0x19,
              Ops.HLT },
    aVal  = 0xC1,
    xVal  = 0x5C,
    yVal  = 0xF0,
    zVal  = false,
    nVal  = true,
    addrs = { 0x0627, 0x00A2, 0x00A3, 0x04F1, 0x0019, 0x001A, 0x079C, 0x001E, 0x001F, 0x063C, 0x05E1 },
    vals  = {   0xFE,   0x27,   0x06,   0x77,   0xF1,   0x04,   0xC1,   0x32,   0x07,   0x9D,   0xC1 }
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
    print("ac: " .. ac .. " x: " .. x .. " y: " .. y .. 
          " z: " .. tostring(z) .. " n: " .. tostring(n) .. "\n")
    return false
  end

  for addrIdx = 1, #test.addrs do
    local val = nesdbg.CpuMemRd(test.addrs[addrIdx], 1)
    if val[1] ~= test.vals[addrIdx] then
      print("@ addr: " .. test.addrs[addrIdx] .. "Expected: " .. test.vals[addrIdx] .. 
                                                 ", Result: " .. val[1] .. "\n")
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

