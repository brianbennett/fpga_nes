----------------------------------------------------------------------------------------------------
-- Script:      cpu_asl.lua
-- Description: CPU test.  Directed test for ASL instruction.  Covers all address modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: ASL_ACC: !c, !z, !n
  {
    code  = { Ops.LDA_IMM, 0x29,  -- A
              Ops.LDX_IMM, 0x00,
              Ops.LDY_IMM, 0x00,
              Ops.ASL_ACC,
              Ops.HLT },
    aVal  = 0x52,
    xVal  = 0x00,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    cVal  = false,
    addrs = { },
    vals  = { }
  },

  -- Test 2: ASL_ACC: !c, !z, n
  {
    code  = { Ops.LDA_IMM, 0x4F,  -- A
              Ops.ASL_ACC,
              Ops.HLT },
    aVal  = 0x9E,
    xVal  = 0x00,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    cVal  = false,
    addrs = { },
    vals  = { }
  },

  -- Test 3: ASL_ACC: !c, z, !n
  {
    code  = { Ops.LDA_IMM, 0x00,  -- A
              Ops.ASL_ACC,
              Ops.HLT },
    aVal  = 0x00,
    xVal  = 0x00,
    yVal  = 0x00,
    zVal  = true,
    nVal  = false,
    cVal  = false,
    addrs = { },
    vals  = { }
  },

  -- Test 4: ASL_ACC: c, !z, !n
  {
    code  = { Ops.LDA_IMM, 0x81,  -- A
              Ops.ASL_ACC,
              Ops.HLT },
    aVal  = 0x02,
    xVal  = 0x00,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    cVal  = true,
    addrs = { },
    vals  = { }
  },

  -- Test 5: ASL_ACC: c, !z, n
  {
    code  = { Ops.LDA_IMM, 0xC9,  -- A
              Ops.ASL_ACC,
              Ops.HLT },
    aVal  = 0x92,
    xVal  = 0x00,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    cVal  = true,
    addrs = { },
    vals  = { }
  },

  -- Test 6: ASL_ACC: c, z, !n
  {
    code  = { Ops.LDA_IMM, 0x80,  -- A
              Ops.ASL_ACC,
              Ops.HLT },
    aVal  = 0x00,
    xVal  = 0x00,
    yVal  = 0x00,
    zVal  = true,
    nVal  = false,
    cVal  = true,
    addrs = { },
    vals  = { }
  },

  -- Test 7: ASL_ZP
  {
    code  = { Ops.LDA_IMM, 0x99,  -- M
              Ops.STA_ZP,  0x52,
              Ops.ASL_ZP,  0x52,
              Ops.HLT },
    aVal  = 0x99,
    xVal  = 0x00,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    cVal  = true,
    addrs = { 0x0052 },
    vals  = {   0x32 }
  },

  -- Test 8: ASL_ZPX
  {
    code  = { Ops.LDA_IMM, 0xFA,  -- M
              Ops.STA_ZP,  0xC2,
              Ops.LDX_IMM, 0x13,
              Ops.ASL_ZPX, 0xAF,
              Ops.HLT },
    aVal  = 0xFA,
    xVal  = 0x13,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    cVal  = true,
    addrs = { 0x0052, 0x00C2 },
    vals  = {   0x32,   0xF4 }
  },

  -- Test 9: ASL_ABS
  {
    code  = { Ops.LDA_IMM, 0x8F,        -- M
              Ops.STA_ABS, 0xC0, 0x05,
              Ops.ASL_ABS, 0xC0, 0x05,
              Ops.HLT },
    aVal  = 0x8F,
    xVal  = 0x13,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    cVal  = true,
    addrs = { 0x0052, 0x00C2, 0x05C0 },
    vals  = {   0x32,   0xF4,   0x1E }
  },

  -- Test 10: ASL_ABSX
  {
    code  = { Ops.LDA_IMM,  0x56,        -- M
              Ops.STA_ABS,  0x80, 0x07,
              Ops.LDX_IMM,  0x73,
              Ops.ASL_ABSX, 0x0D, 0x07,
              Ops.HLT },
    aVal  = 0x56,
    xVal  = 0x73,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    cVal  = false,
    addrs = { 0x0052, 0x00C2, 0x05C0, 0x0780 },
    vals  = {   0x32,   0xF4,   0x1E,   0xAC }
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

  for addrIdx = 1, #curTest.addrs do
    local val = nesdbg.CpuMemRd(curTest.addrs[addrIdx], 1)
    if val[1] ~= curTest.vals[addrIdx] then
      print("Expected: " .. curTest.vals[addrIdx] .. ", Result: " .. val[1] .. "\n")
      val = nesdbg.CpuMemRd(0, 256)
      for i = 1, 256 do
        print(val[i] .. " ")
      end
      print("\n")
      results[subTestIdx] = ScriptResult.Fail
      break
    end
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)


