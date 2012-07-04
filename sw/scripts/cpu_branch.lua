----------------------------------------------------------------------------------------------------
-- Script:      cpu_branch.lua
-- Description: CPU test.  Directed test for branch instructions (BCC, BCS, BEQ, BMI, BNE, BPL,
--              BVC, BVS).
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: Simple BEQ test.  Jump forward over one instruction.
  {
    code = { Ops.CLC,
             Ops.CLV,
             Ops.CLD,
             Ops.CLI,
             Ops.LDA_IMM, 0xBB,
             Ops.LDY_IMM, 0x00,
             Ops.LDX_IMM, 0xFF,
             Ops.TXS,
             Ops.CMP_IMM, 0xBB,
             Ops.BEQ, 0x02,
             Ops.LDA_IMM, 0x17,
             Ops.LSR_ACC,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x5D,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = true,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = {  },
    vals  = {  }
  },

  -- Test 2: Simple BEQ test.  Do not Jump over one instruction.
  {
    code = { Ops.LDA_IMM, 0x75,
             Ops.CMP_IMM, 0x64,
             Ops.BEQ, 0x02,
             Ops.LDA_IMM, 0x17,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x17,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = true,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = {  },
    vals  = {  }
  },

  -- Test 3: BEQ test.  Branches forward across a page boundary.
  {
    code = { -- 200 NOPs
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 

             Ops.LDA_IMM, 0x11,
             Ops.CMP_IMM, 0x11,
             Ops.BEQ, 102,

             -- 100 NOPs
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             
             Ops.LDA_IMM, 0xFF,
             Ops.ASL_ACC,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x22,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = {  },
    vals  = {  }
  },

  -- Test 4: Backwards jump (loop).
  {
    code = { Ops.LDX_IMM, 0x10,
             Ops.LDA_IMM, 0x00,
             Ops.ADC_IMM, 0x03,
             Ops.DEX,
             Ops.BNE, 0xFB,
             Ops.ASL_ACC,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x60,
    xVal = 0x00,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = {  },
    vals  = {  }
  },  

  -- Test 5: Backwards jump over a page boundary.
  {
    code = { -- 200 NOPs
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 

             Ops.LDX_IMM, 0x11,
             Ops.LDA_IMM, 0x00,
             Ops.ADC_IMM, 0x07,
             Ops.DEX,

             -- 100 NOPs
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 
             Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, Ops.NOP, 

             Ops.BNE, 0x97,
             Ops.ASL_ACC,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0xEE,
    xVal = 0x00,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = true,
    addrs = {  },
    vals  = {  }
  },  

  -- Test 6: BCC sanity test.
  {
    code = { Ops.LDA_IMM, 0xFA,
             Ops.CLC,
             Ops.BCC, 0x02,
             Ops.LDA_IMM, 0x00,
             Ops.ADC_IMM, 0x01,
             Ops.SEC,
             Ops.BCC, 0x02,
             Ops.LDX_IMM, 0x71,
             Ops.CLC,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0xFB,
    xVal = 0x71,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = {  },
    vals  = {  }
  },

  -- Test 7: BCS sanity test.
  {
    code = { Ops.LDA_IMM, 0x47,
             Ops.SEC,
             Ops.BCS, 0x02,
             Ops.LDA_IMM, 0x00,
             Ops.ADC_IMM, 0x01,
             Ops.CLC,
             Ops.BCS, 0x02,
             Ops.LDX_IMM, 0x29,
             Ops.CLC,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x49,
    xVal = 0x29,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = {  },
    vals  = {  }
  },

  -- Test 8: BMI sanity test.
  {
    code = { Ops.LDA_IMM, 0x80,
             Ops.BMI, 0x02,
             Ops.LDA_IMM, 0x00,
             Ops.LDX_IMM, 0x01,
             Ops.BMI, 0x02,
             Ops.LDX_IMM, 0x55,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x80,
    xVal = 0x55,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = {  },
    vals  = {  }
  },

  -- Test 9: BPL sanity test.
  {
    code = { Ops.LDA_IMM, 0x80,
             Ops.BPL, 0x02,
             Ops.LDA_IMM, 0x00,
             Ops.LDX_IMM, 0x01,
             Ops.BPL, 0x02,
             Ops.LDX_IMM, 0x55,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x00,
    xVal = 0x01,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = {  },
    vals  = {  }
  },
  
  -- Test 10: BVC sanity test.
  {
    code = { Ops.LDX_IMM, 0x81,
             Ops.LDA_IMM, 0x00,
             Ops.ADC_IMM, 0x00,
             Ops.BVC, 0x02,
             Ops.LDX_IMM, 0x16,
             Ops.LDA_IMM, 0x7F,
             Ops.ADC_IMM, 0x01,
             Ops.BVC, 0x02,
             Ops.LDA_IMM, 0x31,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x31,
    xVal = 0x81,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = true,
    nVal = false,
    addrs = {  },
    vals  = {  }
  },

  -- Test 11: BVS sanity test.
  {
    code = { Ops.LDX_IMM, 0x81,
             Ops.LDA_IMM, 0x00,
             Ops.ADC_IMM, 0x00,
             Ops.BVS, 0x02,
             Ops.LDX_IMM, 0x16,
             Ops.LDA_IMM, 0x7F,
             Ops.ADC_IMM, 0x01,
             Ops.BVS, 0x02,
             Ops.LDA_IMM, 0x31,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x80,
    xVal = 0x16,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = true,
    nVal = true,
    addrs = {  },
    vals  = {  }
  },
}

for subTestIdx = 1, #testTbl do
  local curTest = testTbl[subTestIdx]

  -- Load code into hardware.
  local startPc = 0x8000
  SetPc(startPc)
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

  --print("PC: " .. GetPc() .. "\n")
  
  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)


