----------------------------------------------------------------------------------------------------
-- Script:      cpu_lsr.lua
-- Description: CPU test.  Directed test for LSR instruction.  Covers all address modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: LSR_ACC: !c, !z, !n
  {
    code  = { Ops.LDA_IMM, 0x8C,  -- A
              Ops.LDX_IMM, 0x00,
              Ops.LDY_IMM, 0x00,
              Ops.LSR_ACC,
              Ops.HLT },
    aVal  = 0x46,
    xVal  = 0x00,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    cVal  = false,
    addrs = { },
    vals  = { }
  },

  -- Test 2: LSR_ACC: !c, z, !n
  {
    code  = { Ops.LDA_IMM, 0x00,  -- A
              Ops.LSR_ACC,
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

  -- Test 3: LSR_ACC: c, !z, !n
  {
    code  = { Ops.LDA_IMM, 0x83,  -- A
              Ops.LSR_ACC,
              Ops.HLT },
    aVal  = 0x41,
    xVal  = 0x00,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    cVal  = true,
    addrs = { },
    vals  = { }
  },

  -- Test 4: LSR_ACC: c, z, !n
  {
    code  = { Ops.LDA_IMM, 0x01,  -- A
              Ops.LSR_ACC,
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

  -- Test 7: LSR_ZP
  {
    code  = { Ops.LDA_IMM, 0x99,  -- M
              Ops.STA_ZP,  0x52,
              Ops.LSR_ZP,  0x52,
              Ops.HLT },
    aVal  = 0x99,
    xVal  = 0x00,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    cVal  = true,
    addrs = { 0x0052 },
    vals  = {   0x4C }
  },

  -- Test 8: LSR_ZPX
  {
    code  = { Ops.LDA_IMM, 0x01,  -- M
              Ops.STA_ZP,  0xC2,
              Ops.LDX_IMM, 0x13,
              Ops.LSR_ZPX, 0xAF,
              Ops.HLT },
    aVal  = 0x01,
    xVal  = 0x13,
    yVal  = 0x00,
    zVal  = true,
    nVal  = false,
    cVal  = true,
    addrs = { 0x0052, 0x00C2 },
    vals  = {   0x4C,   0x00 }
  },

  -- Test 9: LSR_ABS
  {
    code  = { Ops.LDA_IMM, 0x8E,        -- M
              Ops.STA_ABS, 0xC0, 0x05,
              Ops.LSR_ABS, 0xC0, 0x05,
              Ops.HLT },
    aVal  = 0x8E,
    xVal  = 0x13,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    cVal  = false,
    addrs = { 0x0052, 0x00C2, 0x05C0 },
    vals  = {   0x4C,   0x00,   0x47 }
  },

  -- Test 10: LSR_ABSX
  {
    code  = { Ops.LDA_IMM,  0x56,        -- M
              Ops.STA_ABS,  0x80, 0x07,
              Ops.LDX_IMM,  0x73,
              Ops.LSR_ABSX, 0x0D, 0x07,
              Ops.HLT },
    aVal  = 0x56,
    xVal  = 0x73,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    cVal  = false,
    addrs = { 0x0052, 0x00C2, 0x05C0, 0x0780 },
    vals  = {   0x4C,   0x00,   0x47,   0x2B }
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


