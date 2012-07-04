----------------------------------------------------------------------------------------------------
-- Script:      cpu_jsr_rts.lua
-- Description: CPU test.  Directed test for JSR and RTS instructions.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local subRoutineTbl =
{
  -- Subroutine 1: Add 1 to AC value and break.
  {
    addr = 0x9010,
    code = {  Ops.ADC_IMM, 0x01,
              Ops.HLT },
  },

  -- Subroutine 2: Nested JSR, adds 3 without returning.
  {
    addr = 0x9020,
    code = {  Ops.ADC_IMM, 0x02,
              Ops.JSR, 0x10, 0x90 },
  },

  -- Subroutine 3: Add 1 and return.
  {
    addr = 0x9030,
    code = {  Ops.ADC_IMM, 0x01,
              Ops.RTS },
  },

  -- Subroutine 4: Add 3 and return.
  {
    addr = 0x9040,
    code = {  Ops.JSR, 0x30, 0x90,
              Ops.JSR, 0x30, 0x90,
              Ops.JSR, 0x30, 0x90,
              Ops.RTS },
  },

  -- Subroutine 5: Add 9 and return.
  {
    addr = 0x9050,
    code = {  Ops.JSR, 0x40, 0x90,
              Ops.JSR, 0x40, 0x90,
              Ops.JSR, 0x40, 0x90,
              Ops.RTS },
  },

  -- Subroutine 5: Add 27 and return.
  {
    addr = 0x9060,
    code = {  Ops.JSR, 0x50, 0x90,
              Ops.JSR, 0x50, 0x90,
              Ops.JSR, 0x50, 0x90,
              Ops.RTS },
  },

  -- Subroutine 6: Add two parameters from stack:
  --    ARG0
  --    ARG1
  --    RET
  --    PCH
  --    PCL
  {
    addr = 0xA000,
    code = {  Ops.PHA,
              Ops.TXA,
              Ops.PHA,
              Ops.TSX,
              Ops.LDA_ABSX, 0x07, 0x01,
              Ops.ADC_ABSX, 0x06, 0x01,
              Ops.STA_ABSX, 0x05, 0x01,
              Ops.PLA,
              Ops.TAX,
              Ops.PLA,
              Ops.RTS },
  },
  
}

local testTbl =
{
  -- Test 1: Call subroutine that adds one and doesn't return.
  {
    code = { Ops.CLC,
             Ops.CLV,
             Ops.CLD,
             Ops.CLI,
             Ops.LDA_IMM, 0x00,
             Ops.LDY_IMM, 0x00,
             Ops.LDX_IMM, 0xFF,
             Ops.TXS,
             Ops.JSR, 0x10, 0x90 },
    sVal = 0xFD,
    aVal = 0x01,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = { 0x01FF, 0x01FE },
    vals  = {   0x80,   0x0D }
  },

  -- Test 2: Call subroutine that adds 3 and doesn't return (nested jsr).
  {
    code = { Ops.LDA_IMM, 0x00,
             Ops.TXS,
             Ops.JSR, 0x20, 0x90 },
    sVal = 0xFB,
    aVal = 0x03,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = { 0x01FF, 0x01FE, 0x01FD, 0x01FC },
    vals  = {   0x80,   0x05,   0x90,   0x24 }
  },

  -- Test 3: Basic RTS test.
  {
    code = { Ops.LDA_IMM, 0x00,
             Ops.TXS,
             Ops.JSR, 0x30, 0x90,
             Ops.ADC_IMM, 0x03,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x04,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = { 0x01FF, 0x01FE },
    vals  = {   0x80,   0x05 }
  },  

  -- Test 4: Call same subroutine several times, serially.
  {
    code = { Ops.LDA_IMM, 0x12,
             Ops.TXS,
             Ops.JSR, 0x30, 0x90,
             Ops.ADC_IMM, 0x03,
             Ops.JSR, 0x30, 0x90,
             Ops.ADC_IMM, 0x10,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0x27,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = false,
    addrs = { 0x01FF, 0x01FE },
    vals  = {   0x80,   0x0a }
  },  

  -- Test 5: Nested subroutines.
  {
    code = { Ops.LDA_IMM, 0xA1,
             Ops.TXS,
             Ops.JSR, 0x60, 0x90,
             Ops.ADC_IMM, 0x07,
             Ops.HLT },
    sVal = 0xFF,
    aVal = 0xC3,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = true,
    addrs = { 0x01FF, 0x01FE },
    vals  = {   0x80,   0x05 }
  },  
  
  -- Test 6: Pass subroutine parameters on the stack.
  {
    code = { Ops.TXS,
             Ops.LDA_IMM, 0x23,
             Ops.PHA,
             Ops.LDA_IMM, 0xB9,
             Ops.PHA,
             Ops.PHA,
             Ops.JSR, 0x00, 0xA0,
             Ops.PLA,
             Ops.HLT },
    sVal = 0xFD,
    aVal = 0xDC,
    xVal = 0xFF,
    yVal = 0x00,
    cVal = false,
    zVal = false,
    iVal = false,
    dVal = false,
    vVal = false,
    nVal = true,
    addrs = { 0x01FF, 0x01FE, 0x01FD, 0x01FC, 0x01FB },
    vals  = {   0x23,   0xB9,   0xDC,   0x80,   0x0A }
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


