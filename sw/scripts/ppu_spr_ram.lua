----------------------------------------------------------------------------------------------------
-- Script:      ppu_spr_ram.lua
-- Description: PPU test.  Directed test for reading/writing sprite ram through the PPU register
--              interface.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1
  {
    code = { Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x00, 0x20,

             Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x01, 0x20,

             Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x03, 0x20,

             -- Store 0x3D @ SPRRAM[0x00]
             Ops.LDA_IMM, 0x3D,
             Ops.STA_ABS, 0x04, 0x20,

             Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x03, 0x20,

             Ops.LDA_ABS, 0x04, 0x20,

             Ops.STA_ZP, 0x00,
             Ops.HLT },
    cpuAddrs = { 0x0000, },
    cpuVals  = {   0x3D, }
  },

  -- Test 2
  {
    code = { Ops.LDA_IMM, 0xE2,
             Ops.STA_ABS, 0x03, 0x20,

             -- Store 0x93 @ SPRRAM[0xE2]
             Ops.LDA_IMM, 0x93,
             Ops.STA_ABS, 0x04, 0x20,

             Ops.LDA_IMM, 0xE2,
             Ops.STA_ABS, 0x03, 0x20,

             Ops.LDA_ABS, 0x04, 0x20,

             Ops.STA_ZP, 0x00,
             Ops.HLT },
    cpuAddrs = { 0x0000, },
    cpuVals  = {   0x93, }
  },

  -- Test 3
  {
    code = { Ops.LDA_IMM, 0x72,
             Ops.STA_ABS, 0x03, 0x20,

             -- Store 0x22 @ SPRRAM[0x72]
             Ops.LDA_IMM, 0x22,
             Ops.STA_ABS, 0x04, 0x20,

             -- Store 0xC1 @ SPRRAM[0x73]
             Ops.LDA_IMM, 0xC1,
             Ops.STA_ABS, 0x04, 0x20,

             -- Store 0xE4 @ SPRRAM[0x74]
             Ops.LDA_IMM, 0xE4,
             Ops.STA_ABS, 0x04, 0x20,

             -- Store 0x08 @ SPRRAM[0x75]
             Ops.LDA_IMM, 0x08,
             Ops.STA_ABS, 0x04, 0x20,

             Ops.LDA_IMM, 0x72,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20,
             Ops.STA_ZP, 0x00,

             Ops.LDA_IMM, 0x73,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20,
             Ops.STA_ZP, 0x01,
             
             Ops.LDA_IMM, 0x74,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20,
             Ops.STA_ZP, 0x02,
             
             Ops.LDA_IMM, 0x75,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20,
             Ops.STA_ZP, 0x03,

             Ops.HLT },
    cpuAddrs = { 0x0000, 0x0001, 0x0002, 0x0003 },
    cpuVals  = {   0x22,   0xC1,   0xE4,   0x08 }
  },

  -- Test 4
  {
    code = { -- Initialize SPRRAM with random data through 2003/2004.
             Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x03, 0x20,

             Ops.LDA_IMM, 202, Ops.STA_ABS, 0x04, 0x20,
             Ops.LDA_IMM,  25, Ops.STA_ABS, 0x04, 0x20,
             Ops.LDA_IMM,  81, Ops.STA_ABS, 0x04, 0x20,

             Ops.LDA_IMM, 0x7F,
             Ops.STA_ABS, 0x03, 0x20,

             Ops.LDA_IMM,  45, Ops.STA_ABS, 0x04, 0x20,
             Ops.LDA_IMM, 199, Ops.STA_ABS, 0x04, 0x20,
             Ops.LDA_IMM,  22, Ops.STA_ABS, 0x04, 0x20,

             Ops.LDA_IMM, 0xFD,
             Ops.STA_ABS, 0x03, 0x20,

             Ops.LDA_IMM,  84, Ops.STA_ABS, 0x04, 0x20,
             Ops.LDA_IMM, 205, Ops.STA_ABS, 0x04, 0x20,
             Ops.LDA_IMM,  75, Ops.STA_ABS, 0x04, 0x20,

             -- Initialize 0x0700-0x07FF with random data.
             Ops.LDA_IMM, 176, Ops.STA_ABS, 0x00, 0x07,
             Ops.LDA_IMM, 202, Ops.STA_ABS, 0x01, 0x07,
             Ops.LDA_IMM, 122, Ops.STA_ABS, 0x02, 0x07,

             Ops.LDA_IMM, 219, Ops.STA_ABS, 0x7F, 0x07,
             Ops.LDA_IMM, 227, Ops.STA_ABS, 0x80, 0x07,
             Ops.LDA_IMM, 107, Ops.STA_ABS, 0x81, 0x07,

             Ops.LDA_IMM,  85, Ops.STA_ABS, 0xFD, 0x07,
             Ops.LDA_IMM, 191, Ops.STA_ABS, 0xFE, 0x07,
             Ops.LDA_IMM, 151, Ops.STA_ABS, 0xFF, 0x07,

             Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x03, 0x20,

             -- DMA 0x0700-0x07FF to SPRRAM.
             Ops.LDA_IMM, 0x07,
             Ops.STA_ABS, 0x14, 0x40,

             Ops.LDA_ABS, 0x04, 0x20, Ops.STA_ZP, 0x00,
             Ops.LDA_IMM, 0x01,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20, Ops.STA_ZP, 0x01,
             Ops.LDA_IMM, 0x02,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20, Ops.STA_ZP, 0x02,

             Ops.LDA_IMM, 0x7F,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20, Ops.STA_ZP, 0x03,
             Ops.LDA_IMM, 0x80,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20, Ops.STA_ZP, 0x04,
             Ops.LDA_IMM, 0x81,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20, Ops.STA_ZP, 0x05,

             Ops.LDA_IMM, 0xFD,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20, Ops.STA_ZP, 0x06,
             Ops.LDA_IMM, 0xFE,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20, Ops.STA_ZP, 0x07,
             Ops.LDA_IMM, 0xFF,
             Ops.STA_ABS, 0x03, 0x20,
             Ops.LDA_ABS, 0x04, 0x20, Ops.STA_ZP, 0x08,

             Ops.HLT },
    cpuAddrs = { 0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, },
    cpuVals  = {    176,    202,    122,    219,    227,    107,     85,    191,    151, }
  },
}

for subTestIdx = 1, #testTbl do
  local curTest = testTbl[subTestIdx]

  local startPc = 0xC000
  nesdbg.CpuMemWr(startPc, #curTest.code, curTest.code)
  SetPc(startPc)

  nesdbg.DbgRun()
  nesdbg.WaitForHlt()

  results[subTestIdx] = ScriptResult.Pass

  for addrIdx = 1, #curTest.cpuAddrs do
    local val = nesdbg.CpuMemRd(curTest.cpuAddrs[addrIdx], 1)
    if val[1] ~= curTest.cpuVals[addrIdx] then
      print("CPU [" .. curTest.cpuAddrs[addrIdx] .. "] = " .. val[1] ..
            ", expected: " .. curTest.cpuVals[addrIdx] .. "\n")
      results[subTestIdx] = ScriptResult.Fail
    --  break
    end
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)


