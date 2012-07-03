----------------------------------------------------------------------------------------------------
-- Script:      ppumc.lua
-- Description: Tests ppumc block (read/write PPU memory)
----------------------------------------------------------------------------------------------------

dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  --
  -- Test reading/writing 0 bytes.
  --
  { wrEn=true,  wrAddr=0x0000, wrBytes=0x0000, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x0000, rdBytes=0x0000 },

  --
  -- 1 byte write tests to various addr segments
  --
  { wrEn=true,  wrAddr=0x0000, wrBytes=0x0001, rdEn=true,  rdAddr=0x0000, rdBytes=0x0001 },
  { wrEn=true,  wrAddr=0x2000, wrBytes=0x0001, rdEn=true,  rdAddr=0x2000, rdBytes=0x0001 },

  --
  -- 1 byte write tests to consecutive bytes then read at once for various addr segments
  --
  { wrEn=true,  wrAddr=0x0000, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x0001, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x0002, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x0000, rdBytes=0x0003 },

  { wrEn=true,  wrAddr=0x0200, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x0201, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x0202, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x0203, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x0200, rdBytes=0x0004 },

  { wrEn=true,  wrAddr=0x2000, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x2001, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x2002, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x2000, wrBytes=0x0000, rdEn=true,  rdAddr=0x2000, rdBytes=0x0003 },

  { wrEn=true,  wrAddr=0x2200, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x2201, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x2202, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x2203, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x2200, rdBytes=0x0004 },

  --
  -- Multi-byte write tests to various addr segments, covering end of segments.
  --
  { wrEn=true,  wrAddr=0x0000, wrBytes=0x0002, rdEn=true,  rdAddr=0x0000, rdBytes=0x0002 },
  { wrEn=true,  wrAddr=0x0010, wrBytes=0x0017, rdEn=true,  rdAddr=0x0010, rdBytes=0x0017 },
  { wrEn=true,  wrAddr=0x0100, wrBytes=0x0700, rdEn=true,  rdAddr=0x0100, rdBytes=0x0700 },

  { wrEn=true,  wrAddr=0x2000, wrBytes=0x0002, rdEn=true,  rdAddr=0x2000, rdBytes=0x0002 },
  { wrEn=true,  wrAddr=0x2010, wrBytes=0x0017, rdEn=true,  rdAddr=0x2010, rdBytes=0x0017 },
  { wrEn=true,  wrAddr=0x2100, wrBytes=0x0300, rdEn=true,  rdAddr=0x2100, rdBytes=0x0300 },

  --
  -- Overlapping multi-byte writes then read at once for various addr segments
  --
  { wrEn=true,  wrAddr=0x0400, wrBytes=0x0100, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x0420, wrBytes=0x00C0, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x0440, wrBytes=0x0080, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x0400, rdBytes=0x0100 },

  { wrEn=true,  wrAddr=0x2400, wrBytes=0x0100, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x2420, wrBytes=0x00C0, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x2440, wrBytes=0x0080, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x2400, rdBytes=0x0100 },

  --
  -- RAM mirroring tests (0x0000 - 0x1FFF)
  --
  { wrEn=true,  wrAddr=0x0170, wrBytes=0x0029, rdEn=true,  rdAddr=0x0170, rdBytes=0x0029 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x4170, rdBytes=0x0029 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x8170, rdBytes=0x0029 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0xC170, rdBytes=0x0029 },

  { wrEn=true,  wrAddr=0x2280, wrBytes=0x0100, rdEn=true,  rdAddr=0x2280, rdBytes=0x0100 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x2680, rdBytes=0x0100 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x6280, rdBytes=0x0100 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x6680, rdBytes=0x0100 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0xA280, rdBytes=0x0100 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0xA680, rdBytes=0x0100 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0xE280, rdBytes=0x0100 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0xE680, rdBytes=0x0100 },
}

local shadowMem = {}

-- TranslateAddr: Handles mirroring for RAM area of shadow RAM.  This will also return nil for
--                unsupported addresses, causing a lua error.
function TranslateAddr(addr)
  -- 0x4000 - 0xFFFF mirors 0x0000 - 0x3FFF
  local translatedAddr = addr % 0x4000

--  if translatedAddr >= 0x2000 then
--   translatedAddr = (translatedAddr - 0x2000) % 0x800
--    translatedAddr = translatedAddr + 0x2000
--  end

  if translatedAddr >= 0x2000 and translatedAddr < 0x2400 then
    translatedAddr = translatedAddr
  elseif translatedAddr >= 0x2400 and translatedAddr < 0x2800 then
    translatedAddr = translatedAddr - 0x400
  elseif translatedAddr >= 0x2800 and translatedAddr < 0x2C00 then
    translatedAddr = translatedAddr - 0x400
  elseif translatedAddr >= 0x2C00 and translatedAddr < 0x3000 then
    translatedAddr = translatedAddr - 0x800
  end

  return translatedAddr
end

-- ShadowMemWr: Write specified data to addr in the shadow memory.
function ShadowMemWr(addr, numBytes, data)
  for i = 1,numBytes do
    shadowMem[TranslateAddr(addr + i - 1)] = data[i]
  end
end

-- ShadowMemRd: Read data from the shadow memory.
function ShadowMemRd(addr, numBytes)
  local data = {}
  for i = 1, numBytes do
    data[i] = shadowMem[TranslateAddr(addr + i - 1)]
  end
  return data
end

-- PrintRdData: Prints data contents, useful for debugging.
function PrintRdData(data)
  for i = 1, #data do
    print(data[i] .. " ")
  end
end

for subTestIdx = 1, #testTbl do
  curTest = testTbl[subTestIdx]

  if curTest.wrEn then
    -- Generate random test data to be written.
    wrData = {}
    for i = 1, curTest.wrBytes do
      wrData[i] = math.random(0, 255)
    end

    -- Write data for FPGA and shadow mem.
    nesdbg.PpuMemWr(curTest.wrAddr, curTest.wrBytes, wrData)
    ShadowMemWr(curTest.wrAddr, curTest.wrBytes, wrData)
  end

  if curTest.rdEn then
    -- Read data from FPGA and shadow mem.
    ppuRdData = nesdbg.PpuMemRd(curTest.rdAddr, curTest.rdBytes)
    shadowRdData = ShadowMemRd(curTest.rdAddr, curTest.rdBytes)


    if CompareArrayData(ppuRdData, shadowRdData) then
      results[subTestIdx] = ScriptResult.Pass
    else
      results[subTestIdx] = ScriptResult.Fail

      --[[
      print("shadowRdData:\t")
      PrintRdData(shadowRdData)
      print("\n")
      print("cpuRdData:\t")
      PrintRdData(cpuRdData)
      print("\n")
      ]]
    end
  else
    -- If this subtest doesn't read, there's nothing to check, so award a free pass.
    results[subTestIdx] = ScriptResult.Pass
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

