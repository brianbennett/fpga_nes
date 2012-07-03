----------------------------------------------------------------------------------------------------
-- Script:      cpumc.lua
-- Description: Tests cpumc block (read/write CPU memory)
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
  { wrEn=true,  wrAddr=0x8000, wrBytes=0x0001, rdEn=true,  rdAddr=0x8000, rdBytes=0x0001 },
  { wrEn=true,  wrAddr=0xC000, wrBytes=0x0001, rdEn=true,  rdAddr=0xC000, rdBytes=0x0001 },

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
  
  { wrEn=true,  wrAddr=0x8000, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x8001, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x8002, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x8000, rdBytes=0x0003 },

  { wrEn=true,  wrAddr=0x8200, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x8201, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x8202, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x8203, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x8200, rdBytes=0x0004 },
  
  { wrEn=true,  wrAddr=0xC000, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0xC001, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0xC002, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0xC000, rdBytes=0x0003 },

  { wrEn=true,  wrAddr=0xC200, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0xC201, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0xC202, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0xC203, wrBytes=0x0001, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0xC200, rdBytes=0x0004 },

  --
  -- Multi-byte write tests to various addr segments, covering end of segments.
  -- 
  { wrEn=true,  wrAddr=0x0000, wrBytes=0x0002, rdEn=true,  rdAddr=0x0000, rdBytes=0x0002 },
  { wrEn=true,  wrAddr=0x0010, wrBytes=0x0017, rdEn=true,  rdAddr=0x0010, rdBytes=0x0017 },
  { wrEn=true,  wrAddr=0x0100, wrBytes=0x0700, rdEn=true,  rdAddr=0x0100, rdBytes=0x0700 },

  { wrEn=true,  wrAddr=0xB000, wrBytes=0x0002, rdEn=true,  rdAddr=0xB000, rdBytes=0x0002 },
  { wrEn=true,  wrAddr=0xB010, wrBytes=0x0017, rdEn=true,  rdAddr=0xB010, rdBytes=0x0017 },
  { wrEn=true,  wrAddr=0xB900, wrBytes=0x0700, rdEn=true,  rdAddr=0xB900, rdBytes=0x0700 },

  { wrEn=true,  wrAddr=0xF000, wrBytes=0x0002, rdEn=true,  rdAddr=0xF000, rdBytes=0x0002 },
  { wrEn=true,  wrAddr=0xF010, wrBytes=0x0017, rdEn=true,  rdAddr=0xF010, rdBytes=0x0017 },
  { wrEn=true,  wrAddr=0xF900, wrBytes=0x0700, rdEn=true,  rdAddr=0xF900, rdBytes=0x0700 },

  --
  -- Overlapping multi-byte writes then read at once for various addr segments
  --
  { wrEn=true,  wrAddr=0x0400, wrBytes=0x0100, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x0420, wrBytes=0x00C0, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x0440, wrBytes=0x0080, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x0400, rdBytes=0x0100 },

  { wrEn=true,  wrAddr=0x8400, wrBytes=0x0100, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x8420, wrBytes=0x00C0, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0x8440, wrBytes=0x0080, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x8400, rdBytes=0x0100 },

  { wrEn=true,  wrAddr=0xC400, wrBytes=0x0100, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0xC420, wrBytes=0x00C0, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=true,  wrAddr=0xC440, wrBytes=0x0080, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0xC400, rdBytes=0x0100 },

  --
  -- RAM mirroring tests (0x0000 - 0x1FFF)
  --
  { wrEn=true,  wrAddr=0x0170, wrBytes=0x0029, rdEn=true,  rdAddr=0x0170, rdBytes=0x0029 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x0970, rdBytes=0x0029 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x1170, rdBytes=0x0029 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x1970, rdBytes=0x0029 },

  { wrEn=true,  wrAddr=0x0780, wrBytes=0x0100, rdEn=false, rdAddr=0x0000, rdBytes=0x0000 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x0000, rdBytes=0x0080 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x0780, rdBytes=0x0100 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x0F80, rdBytes=0x0100 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x1780, rdBytes=0x0100 },
  { wrEn=false, wrAddr=0x0000, wrBytes=0x0000, rdEn=true,  rdAddr=0x1F80, rdBytes=0x0080 },

  --
  -- Big write, big read
  --
  { wrEn=true,  wrAddr=0xC000, wrBytes=0x4000, rdEn=true,  rdAddr=0xC000, rdBytes=0x4000 },
}

local shadowMem = {}

-- TranslateAddr: Handles mirroring for RAM area of shadow RAM.  This will also return nil for
--                unsupported addresses, causing a lua error.
function TranslateAddr(addr)
  local translatedAddr = nil

  if addr < 0x2000 then
    -- RAM: 0x0800 - 0x1FFF mirror 0x0000 - 0x07FF.
    translatedAddr = addr % 0x800
  elseif addr >= 0x8000 and addr < 0x10000 then
    -- PRG-ROM range
    translatedAddr = addr
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
    nesdbg.CpuMemWr(curTest.wrAddr, curTest.wrBytes, wrData)
    ShadowMemWr(curTest.wrAddr, curTest.wrBytes, wrData)
  end

  if curTest.rdEn then
    -- Read data from FPGA and shadow mem.
    cpuRdData = nesdbg.CpuMemRd(curTest.rdAddr, curTest.rdBytes)
    shadowRdData = ShadowMemRd(curTest.rdAddr, curTest.rdBytes)


    if CompareArrayData(cpuRdData, shadowRdData) then
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

