----------------------------------------------------------------------------------------------------
-- Script:      cpu_asm.lua
-- Description: CPU test.  Execute externally built asm programs from the ../asm directory.  Useful
--              for more detailed directed tests, especially since cpu_rand doesn't cover branches,
--              jumps, or subroutines.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local asmTbl = 
{
  -- trivial.asm
  {
    file = "trivial.prg",
    subTestTbl =
    {
      {
        initState =
        {
          ac = 0x00,
        },
        resultState =
        {
          ac = 0xBB,
        }
      },
    }
  },

  -- sum_array.asm
  {
    file = "sum_array.prg",
    subTestTbl =
    {
      {
        initState =
        {
          addrs = { 0x0000, 0x0001, 0x0002, 0x0300, 0x0301, 0x0302, 0x0303, 0x0304, 0x0305, 0x0306 },
          vals  = {   0x00,   0x03,   0x07,    250,    136,     66,     45,     26,     92,      4 }
        },
        resultState =
        {
          addrs = { 0x0004, 0x0005 },
          vals  = {   0x6B,   0x02  }
        }
      },
      {
        initState =
        {
          addrs = { 0x0000, 0x0001, 0x0002, 0x0500, 0x0501, 0x0502, 0x0503, 0x0504, 0x0505, 0x0506, 0x0507, 0x0508, 0x0509, 0x050A, 0x050B, 0x050C, 0x050D, 0x050E, 0x050F, 0x0510, 0x0511, 0x0512, 0x0513, 0x0514, 0x0515, 0x0516, 0x0517, 0x0518, 0x0519, 0x051A, 0x051B, 0x051C, 0x051D, 0x051E, 0x051F, 0x0520, 0x0521, 0x0522, 0x0523, 0x0524 },
          vals  = {   0x00,   0x05,   0x25,    194,    141,    101,    143,    201,    253,    185,    202,    201,      3,     25,     28,    172,     12,    156,    242,    134,    184,    150,    142,      6,    245,    169,    236,     58,    242,     71,     44,     95,     63,    107,     47,    181,    238,     38,     14,    210 }
        },
        resultState =
        {
          addrs = { 0x0004, 0x0005 },
          vals  = {   0x45,   0x13  }
        }
      },
    }
  },

  -- bubble8.asm
  {
    file = "bubble8.prg",
    subTestTbl =
    {
      {
        initState =
        {
          addrs = { 0x0030, 0x0031, 0x0600, 0x0601, 0x0602, 0x0603, 0x0604, 0x0605, 0x0606, 0x0607 },
          vals  = {   0x00,   0x06,   0x07,    223,    176,     32,     45,    194,     87,    244 }
        },
        resultState =
        {
          addrs = { 0x0601, 0x0602, 0x0603, 0x0604, 0x0605, 0x0606, 0x0607 },
          vals  = {     32,     45,     87,    176,    194,    223,    244 }
        }
      },
      {
        initState =
        {
          addrs = { 0x0030, 0x0031, 0x0500, 0x0501, 0x0502, 0x0503, 0x0504, 0x0505, 0x0506, 0x0507, 0x0508, 0x0509, 0x050A, 0x050B, 0x050C, 0x050D, 0x050E, 0x050F, 0x0510, 0x0511, 0x0512, 0x0513, 0x0514, 0x0515, 0x0516, 0x0517, 0x0518, 0x0519, 0x051A, 0x051B, 0x051C, 0x051D, 0x051E, 0x051F, 0x0520, 0x0521, 0x0522, 0x0523, 0x0524 },
          vals  = {   0x00,   0x05,   0x24,    141,    101,    143,    201,    253,    185,    202,    201,      3,     25,     28,    172,     12,    156,    242,    134,    184,    150,    142,      6,    245,    169,    236,     58,    242,     71,     44,     95,     63,    107,     47,    181,    238,     38,     14,    210 }
        },
        resultState =
        {
          addrs = { 0x0501, 0x0502, 0x0503, 0x0504, 0x0505, 0x0506, 0x0507, 0x0508, 0x0509, 0x050A, 0x050B, 0x050C, 0x050D, 0x050E, 0x050F, 0x0510, 0x0511, 0x0512, 0x0513, 0x0514, 0x0515, 0x0516, 0x0517, 0x0518, 0x0519, 0x051A, 0x051B, 0x051C, 0x051D, 0x051E, 0x051F, 0x0520, 0x0521, 0x0522, 0x0523, 0x0524 },
          vals  = {      3,      6,     12,     14,     25,     28,     38,     44,     47,     58,     63,     71,     95,    101,    107,    134,    141,    142,    143,    150,    156,    169,    172,    181,    184,    185,    201,    201,    202,    210,    236,    238,    242,    242,    245,    253 }
        }
      },
    }
  },

  -- bubble16.asm
  {
    file = "bubble16.prg",
    subTestTbl =
    {
      {
        initState =
        {
          addrs = { 0x0030, 0x0031, 0x0600, 0x0601, 0x0602, 0x0603, 0x0604, 0x0605, 0x0606, 0x0607, 0x0608, 0x0609, 0x060A, 0x060B, 0x060C, 0x060D, 0x060E, 0x060F, 0x0610, 0x0611, 0x0612 },
          vals  = {   0x00,   0x06,   0x12,     90,    178,    219,     94,     23,     26,    119,     94,    105,    155,    221,    247,    105,     55,    169,     57,    228,    237 }
        },
        resultState =
        {
          addrs = { 0x0601, 0x0602, 0x0603, 0x0604, 0x0605, 0x0606, 0x0607, 0x0608, 0x0609, 0x060A, 0x060B, 0x060C, 0x060D, 0x060E, 0x060F, 0x0610, 0x0611, 0x0612 },
          vals  = {     23,     26,    105,     55,    169,     57,    119,     94,    219,    94,    105,    155,     90,    178,    228,    237,    221,    247 }
        }
      },
    }
  },
}

local reportingSubTestIdx = 1

for asmIdx = 1, #asmTbl do
  local curAsm = asmTbl[asmIdx]

  print(curAsm.file .. "\n");

  for subTestIdx = 1, #curAsm.subTestTbl do
    local curTest = curAsm.subTestTbl[subTestIdx]

    --
    -- Set initial test state.
    --
    if curTest.initState.ac ~= nil then
      SetAc(curTest.initState.ac)
    end

    if curTest.initState.addrs ~= nil then
      for addrIdx = 1, #curTest.initState.addrs do
        tempTbl = { curTest.initState.vals[addrIdx] }
        nesdbg.CpuMemWr(curTest.initState.addrs[addrIdx], 1, tempTbl)
      end
    end

    --
    -- Load the ASM code and run the test.
    --
    local startPc = nesdbg.LoadAsm(curAsm.file)
    SetPc(startPc)

    nesdbg.DbgRun()
    nesdbg.WaitForHlt()

    -- 
    -- Check result.
    -- 
    results[reportingSubTestIdx] = ScriptResult.Pass

    if curTest.resultState.ac ~= nil and curTest.resultState.ac ~= GetAc() then
      print("AC = " .. GetAc() .. ", expected " .. curTest.resultState.ac .. ".\n");
      results[reportingSubTestIdx] = ScriptResult.Fail
    end

    if curTest.resultState.addrs ~= nil then
      for addrIdx = 1, #curTest.resultState.addrs do
        local val = nesdbg.CpuMemRd(curTest.resultState.addrs[addrIdx], 1)
        if val[1] ~= curTest.resultState.vals[addrIdx] then
          print("[" .. curTest.resultState.addrs[addrIdx] .. "] = " .. val[1] .. 
                ", expected: " .. curTest.resultState.vals[addrIdx] .. "\n")
          results[reportingSubTestIdx] = ScriptResult.Fail
          break
        end
      end
    end

    print("   ")
    ReportSubTestResult(subTestIdx, results[reportingSubTestIdx])

    reportingSubTestIdx = reportingSubTestIdx + 1
  end
end

return ComputeOverallResult(results)

