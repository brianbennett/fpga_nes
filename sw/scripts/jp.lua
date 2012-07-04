----------------------------------------------------------------------------------------------------
-- Script:      jp.lua
-- Description: Joypad test.  Execute externally built asm program that reads joypad input, waiting
--              for a particular input sequence.  Requires user interaction.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl = 
{
  -- Controller 1 Tests.
  {
    sequence = "Controller 1: A",
    initState = 
    {
      ac = 0x00,
      addrs = { 0x0000, 0x0001, 0x0200 },
      vals  = { 0x80,   0x00,   0x00   },
    },
    resultState =
    {
      ac = 0x01
    }
  },
  {
    sequence = "Controller 1: UP",
    initState = 
    {
      ac = 0x00,
      addrs = { 0x0000, 0x0001, 0x0200 },
      vals  = { 0x08,   0x00,   0x00   },
    },
    resultState =
    {
      ac = 0x01
    }
  },
  {
    sequence = "Controller 1: B, SELECT",
    initState = 
    {
      ac = 0x00,
      addrs = { 0x0000, 0x0001, 0x0002, 0x0200 },
      vals  = { 0x40,   0x20,   0x00,   0x00   },
    },
    resultState =
    {
      ac = 0x01
    }
  },
  {
    sequence = "Controller 1: UP, UP, DOWN, DOWN, LEFT, RIGHT, LEFT, RIGHT, B, A, START",
    initState = 
    {
      ac = 0x00,
      addrs = { 0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000A, 0x000B, 0x0200 },
      vals  = { 0x08,   0x08,   0x04,   0x04,   0x02,   0x01,   0x02,   0x01,   0x40,   0x80,   0x10,   0x00,   0x00   },
    },
    resultState =
    {
      ac = 0x01
    }
  },
  {
    sequence = "Controller 1: SELECT, START, DOWN, DOWN, DOWN, RIGHT, RIGHT, B",
    initState = 
    {
      ac = 0x00,
      addrs = { 0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0200 },
      vals  = { 0x20,   0x10,   0x04,   0x04,   0x04,   0x01,   0x01,   0x40,   0x00,   0x00   },
    },
    resultState =
    {
      ac = 0x01
    }
  },

  -- Controller 2 Tests.
  {
    sequence = "Controller 2: B",
    initState = 
    {
      ac = 0x00,
      addrs = { 0x0000, 0x0001, 0x0200 },
      vals  = { 0x40,   0x00,   0x01   },
    },
    resultState =
    {
      ac = 0x01
    }
  },
   {
    sequence = "Controller 2: DOWN",
    initState = 
    {
      ac = 0x00,
      addrs = { 0x0000, 0x0001, 0x0200 },
      vals  = { 0x04,   0x00,   0x01   },
    },
    resultState =
    {
      ac = 0x01
    }
  },
  {
    sequence = "Controller 2: A, START",
    initState = 
    {
      ac = 0x00,
      addrs = { 0x0000, 0x0001, 0x0002, 0x0200 },
      vals  = { 0x80,   0x10,   0x00,   0x01   },
    },
    resultState =
    {
      ac = 0x01
    }
  },
  {
    sequence = "Controller 2: DOWN, DOWN, UP, UP, RIGHT, LEFT, RIGHT, LEFT, A, B, SELECT",
    initState = 
    {
      ac = 0x00,
      addrs = { 0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000A, 0x000B, 0x0200 },
      vals  = { 0x04,   0x04,   0x08,   0x08,   0x01,   0x02,   0x01,   0x02,   0x80,   0x40,   0x20,   0x00,   0x01   },
    },
    resultState =
    {
      ac = 0x01
    }
  },
  {
    sequence = "Controller 2: START, SELECT, UP, UP, UP, LEFT, LEFT, A",
    initState = 
    {
      ac = 0x00,
      addrs = { 0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0200 },
      vals  = { 0x10,   0x20,   0x08,   0x08,   0x08,   0x02,   0x02,   0x80,   0x00,   0x01   },
    },
    resultState =
    {
      ac = 0x01
    }
  }, 
}

local startPc = nesdbg.LoadAsm("jp.prg")

local testIdx = 1

for testIdx = 1, #testTbl do
  local curTest = testTbl[testIdx]

  --
  -- Set initial test state.
  --
  if curTest.initState.ac ~= nil then
    SetAc(curTest.initState.ac)
  end

  if curTest.initState.addrs ~= nil then
    for addrIdx = 1, #curTest.initState.addrs do
      local tempTbl = { curTest.initState.vals[addrIdx] }
      nesdbg.CpuMemWr(curTest.initState.addrs[addrIdx], 1, tempTbl)
    end
  end

  print(curTest.sequence .. "\n");

  --
  -- Load the ASM code and run the test.
  --
  SetPc(startPc)

  nesdbg.DbgRun()
  nesdbg.WaitForHlt()

  -- 
  -- Check result.
  -- 
  results[testIdx] = ScriptResult.Pass

  if curTest.resultState.ac ~= nil and curTest.resultState.ac ~= GetAc() then
    print("AC = " .. GetAc() .. ", expected " .. curTest.resultState.ac .. ".\n");
    results[testIdx] = ScriptResult.Fail
  end

  if curTest.resultState.addrs ~= nil then
    for addrIdx = 1, #curTest.resultState.addrs do
      local val = nesdbg.CpuMemRd(curTest.resultState.addrs[addrIdx], 1)
      if val[1] ~= curTest.resultState.vals[addrIdx] then
        print("[" .. curTest.resultState.addrs[addrIdx] .. "] = " .. val[1] .. 
              ", expected: " .. curTest.resultState.vals[addrIdx] .. "\n")
        results[testIdx] = ScriptResult.Fail
        break
      end
    end
  end

  print("   ")
  ReportSubTestResult(testIdx, results[testIdx])

  testIdx = testIdx + 1
end

return ComputeOverallResult(results)

