----------------------------------------------------------------------------------------------------
-- Script:      cpu_jmp.lua
-- Description: CPU test.  Directed test for JMP instructions.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local subRoutineTbl =
{
}

local testTbl =
{
  -- Test 1: Simple JMP_ABS test, jump over one line.
  {
    code = { Ops.CLC,
             Ops.CLV,
             Ops.CLD,
             Ops.CLI,
             Ops.LDA_IMM, 0xBB,
             Ops.LDY_IMM, 0x00,
             Ops.LDX_IMM, 0xFF,
             Ops.TXS,
             Ops.JMP_ABS, 0x10, 0x80,
             Ops.LDA_IMM, 0x00,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0xBB,
    xVal = 0xFF,
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

  -- Test 2: JMP_ABS to some code, then JMP_ABS back.
  {
    code = { Ops.LDA_IMM, 0x31,
             Ops.JMP_ABS, 0x08, 0x80,
             Ops.ADC_IMM, 0x10,
             Ops.HLT,
             Ops.ADC_IMM, 0x20,
             Ops.JMP_ABS, 0x05, 0x80 },
    sVal = 0xFF,
    aVal = 0x61,
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

  -- Test 3: Simple JMP_IND test, jump over one line.
  {
    code = { Ops.LDA_IMM, 0x11,
             Ops.STA_ABS, 0x00, 0x03,
             Ops.LDA_IMM, 0x80,             
             Ops.STA_ABS, 0x01, 0x03,
             Ops.LDA_IMM, 0xAA,
             Ops.JMP_IND, 0x00, 0x03,
             Ops.LDA_IMM, 0x00,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0xAA,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = true,
    addrs = { 0x0300, 0x0301 },
    vals  = {   0x11,   0x80 }
  },
}

-- Load subroutines into memory.
for subRoutineIdx = 1, #subRoutineTbl do
  local curSubRoutine = subRoutineTbl[subRoutineIdx]
  nesdbg.CpuMemWr(curSubRoutine.addr, #curSubRoutine.code, curSubRoutine.code)
end

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


