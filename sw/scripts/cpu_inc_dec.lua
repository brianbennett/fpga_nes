----------------------------------------------------------------------------------------------------
-- Script:      cpu_inc_dec.lua
-- Description: CPU test.  Directed test for INC, INX, INY, DEC, DEX, and DEY instructions.  Covers
--              all address modes.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: INX
  {
    code  = { Ops.LDA_IMM, 0x00,
              Ops.LDX_IMM, 0x00,  -- X
              Ops.LDY_IMM, 0x00,
              Ops.INX,
              Ops.HLT },
    aVal  = 0x00,
    xVal  = 0x01,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    addrs = { },
    vals  = { }
  },

  -- Test 2: INX
  {
    code  = { Ops.LDX_IMM, 0x7F,  -- X
              Ops.INX,
              Ops.HLT },
    aVal  = 0x00,
    xVal  = 0x80,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    addrs = { },
    vals  = { }
  },
  
  -- Test 3: INY
  {
    code  = { Ops.LDY_IMM, 0xFF,  -- Y
              Ops.INY,
              Ops.HLT },
    aVal  = 0x00,
    xVal  = 0x80,
    yVal  = 0x00,
    zVal  = true,
    nVal  = false,
    addrs = { },
    vals  = { }
  },

  -- Test 4: DEX
  {
    code  = { Ops.LDX_IMM, 0x80,  -- X
              Ops.DEX,
              Ops.HLT },
    aVal  = 0x00,
    xVal  = 0x7F,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    addrs = { },
    vals  = { }
  },

  -- Test 5: DEX
  {
    code  = { Ops.LDX_IMM, 0x81,  -- X
              Ops.DEX,
              Ops.HLT },
    aVal  = 0x00,
    xVal  = 0x80,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    addrs = { },
    vals  = { }
  },

  -- Test 6: DEY
  {
    code  = { Ops.LDY_IMM, 0x01,  -- Y
              Ops.DEY,
              Ops.HLT },
    aVal  = 0x00,
    xVal  = 0x80,
    yVal  = 0x00,
    zVal  = true,
    nVal  = false,
    addrs = { },
    vals  = { }
  },
  
  -- Test 7: INC_ZP
  {
    code  = { Ops.LDA_IMM, 0x99,  -- M
              Ops.STA_ZP,  0x52,
              Ops.INC_ZP,  0x52,
              Ops.HLT },
    aVal  = 0x99,
    xVal  = 0x80,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    addrs = { 0x0052 },
    vals  = {   0x9A }
  },

  -- Test 8: INC_ZPX
  {
    code  = { Ops.LDA_IMM, 0xFF,  -- M
              Ops.STA_ZP,  0xC2,
              Ops.LDX_IMM, 0x13,
              Ops.INC_ZPX, 0xAF,
              Ops.HLT },
    aVal  = 0xFF,
    xVal  = 0x13,
    yVal  = 0x00,
    zVal  = true,
    nVal  = false,
    addrs = { 0x0052, 0x00C2 },
    vals  = {   0x9A,   0x00 }
  },

  -- Test 9: INC_ABS
  {
    code  = { Ops.LDA_IMM, 0x8F,        -- M
              Ops.STA_ABS, 0xC0, 0x05,
              Ops.INC_ABS, 0xC0, 0x05,
              Ops.HLT },
    aVal  = 0x8F,
    xVal  = 0x13,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    addrs = { 0x0052, 0x00C2, 0x05C0 },
    vals  = {   0x9A,   0x00,   0x90 }
  },

  -- Test 10: INC_ABSX
  {
    code  = { Ops.LDA_IMM,  0x56,        -- M
              Ops.STA_ABS,  0x80, 0x07,
              Ops.LDX_IMM,  0x73,
              Ops.INC_ABSX, 0x0D, 0x07,
              Ops.HLT },
    aVal  = 0x56,
    xVal  = 0x73,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    addrs = { 0x0052, 0x00C2, 0x05C0, 0x0780 },
    vals  = {   0x9A,   0x00,   0x90,   0x57 }
  },

  -- Test 11: DEC_ZP
  {
    code  = { Ops.LDA_IMM, 0x99,  -- M
              Ops.STA_ZP,  0x52,
              Ops.DEC_ZP,  0x52,
              Ops.HLT },
    aVal  = 0x99,
    xVal  = 0x73,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    addrs = { 0x0052 },
    vals  = {   0x98 }
  },

  -- Test 12: DEC_ZPX
  {
    code  = { Ops.LDA_IMM, 0x01,  -- M
              Ops.STA_ZP,  0xC2,
              Ops.LDX_IMM, 0x13,
              Ops.DEC_ZPX, 0xAF,
              Ops.HLT },
    aVal  = 0x01,
    xVal  = 0x13,
    yVal  = 0x00,
    zVal  = true,
    nVal  = false,
    addrs = { 0x0052, 0x00C2 },
    vals  = {   0x98,   0x00 }
  },

  -- Test 13: DEC_ABS
  {
    code  = { Ops.LDA_IMM, 0x8F,        -- M
              Ops.STA_ABS, 0xC0, 0x05,
              Ops.DEC_ABS, 0xC0, 0x05,
              Ops.HLT },
    aVal  = 0x8F,
    xVal  = 0x13,
    yVal  = 0x00,
    zVal  = false,
    nVal  = true,
    addrs = { 0x0052, 0x00C2, 0x05C0 },
    vals  = {   0x98,   0x00,   0x8E }
  },

  -- Test 14: DEC_ABSX
  {
    code  = { Ops.LDA_IMM,  0x56,        -- M
              Ops.STA_ABS,  0x80, 0x07,
              Ops.LDX_IMM,  0x73,
              Ops.DEC_ABSX, 0x0D, 0x07,
              Ops.HLT },
    aVal  = 0x56,
    xVal  = 0x73,
    yVal  = 0x00,
    zVal  = false,
    nVal  = false,
    addrs = { 0x0052, 0x00C2, 0x05C0, 0x0780 },
    vals  = {   0x98,   0x00,   0x8E,   0x55 }
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

  if ((ac == curTest.aVal) and
      (x == curTest.xVal) and
      (y == curTest.yVal) and
      (z == curTest.zVal) and
      (n == curTest.nVal)) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail

    print("ac: " .. ac .. " x: " .. x ..           " y: " .. y ..
          " z: " .. tostring(z) .. " n: " .. tostring(n) .. "\n")
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


