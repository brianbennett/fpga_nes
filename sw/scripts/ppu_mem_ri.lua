----------------------------------------------------------------------------------------------------
-- Script:      ppu_mem_ri.lua
-- Description: PPU test.  Directed test for reading/writing VRAM through the PPU register
--              interface.
----------------------------------------------------------------------------------------------------
dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testTbl =
{
  -- Test 1: Write one byte to palette RAM then read it back.
  {
    code = { Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x00, 0x20,

             Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x01, 0x20,
      
             Ops.LDA_IMM, 0x3F,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x06, 0x20,

             -- Store 0x19 @ VRAM[0x3F00]
             Ops.LDA_IMM, 0x19,
             Ops.STA_ABS, 0x07, 0x20,

             Ops.LDA_IMM, 0x3F,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x06, 0x20,
             
             Ops.LDA_ABS, 0x07, 0x20,

             Ops.STA_ZP, 0x00,
             Ops.HLT },
    cpuAddrs = { 0x0000, },
    cpuVals  = {   0x19, }
  },

  -- Test 2: Write several sequential bytes to palette RAM then read them back.
  {
    code = { Ops.LDA_IMM, 0x3F,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x04,
             Ops.STA_ABS, 0x06, 0x20,

             -- Store 0x29 @ VRAM[0x3F04]
             Ops.LDA_IMM, 0x29,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0x03 @ VRAM[0x3F05]
             Ops.LDA_IMM, 0x03,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0x11 @ VRAM[0x3F06]
             Ops.LDA_IMM, 0x11,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0x39 @ VRAM[0x3F07]
             Ops.LDA_IMM, 0x39,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0x0E @ VRAM[0x3F08]
             Ops.LDA_IMM, 0x0E,
             Ops.STA_ABS, 0x07, 0x20,
             
             Ops.LDA_IMM, 0x3F,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x04,
             Ops.STA_ABS, 0x06, 0x20,
             
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x00,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x01,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x02,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x03,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x04,

             Ops.HLT },
    cpuAddrs = { 0x0000, 0x0001, 0x0002, 0x0003, 0x0004, },
    cpuVals  = {   0x29,   0x03,   0x11,   0x39,   0x0E, }
  },
  
  -- Test 3: Write one byte to VRAM then read it back.
  {
    code = { Ops.LDA_IMM, 0x03,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x17,
             Ops.STA_ABS, 0x06, 0x20,

             -- Store 0xE9 @ VRAM[0x0317]
             Ops.LDA_IMM, 0xE9,
             Ops.STA_ABS, 0x07, 0x20,

             Ops.LDA_IMM, 0x03,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x17,
             Ops.STA_ABS, 0x06, 0x20,
             
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.LDA_ABS, 0x07, 0x20,

             Ops.STA_ZP, 0x00,
             Ops.HLT },
    cpuAddrs = { 0x0000, },
    cpuVals  = {   0xE9, }
  },

  -- Test 4: Write several sequential bytes to VRAM then read them back.
  {
    code = { Ops.LDA_IMM, 0x3E,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x04,
             Ops.STA_ABS, 0x06, 0x20,

             -- Store 0xF1 @ VRAM[0x3E04]
             Ops.LDA_IMM, 0xF1,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0x44 @ VRAM[0x3E05]
             Ops.LDA_IMM, 0x44,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0x41 @ VRAM[0x3E06]
             Ops.LDA_IMM, 0x41,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0xC9 @ VRAM[0x3E07]
             Ops.LDA_IMM, 0xC9,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0x12 @ VRAM[0x3E08]
             Ops.LDA_IMM, 0x12,
             Ops.STA_ABS, 0x07, 0x20,
             
             Ops.LDA_IMM, 0x3E,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x04,
             Ops.STA_ABS, 0x06, 0x20,
             
             Ops.LDA_ABS, 0x07, 0x20,

             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x00,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x01,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x02,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x03,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x04,

             Ops.HLT },
    cpuAddrs = { 0x0000, 0x0001, 0x0002, 0x0003, 0x0004, },
    cpuVals  = {   0xF1,   0x44,   0x41,   0xC9,   0x12, }
  },

  -- Test 5: Write one byte to palette RAM then read it back.
  {
    code = { Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x00, 0x20,

             Ops.LDA_IMM, 0x3F,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x06, 0x20,

             -- Store 0x19 @ VRAM[0x3F00]
             Ops.LDA_IMM, 0x30,
             Ops.STA_ABS, 0x07, 0x20,

             Ops.LDA_IMM, 0x3F,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x00,
             Ops.STA_ABS, 0x06, 0x20,
             
             Ops.LDA_ABS, 0x07, 0x20,

             Ops.STA_ZP, 0x00,
             Ops.HLT },
    cpuAddrs = { 0x0000, },
    cpuVals  = {   0x30, }
  },

  -- Test 6: Write one byte to VRAM then read it back.
  {
    code = { Ops.LDA_IMM, 0x03,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x17,
             Ops.STA_ABS, 0x06, 0x20,

             -- Store 0xE9 @ VRAM[0x0317]
             Ops.LDA_IMM, 0x55,
             Ops.STA_ABS, 0x07, 0x20,

             Ops.LDA_IMM, 0x03,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x17,
             Ops.STA_ABS, 0x06, 0x20,
             
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.LDA_ABS, 0x07, 0x20,

             Ops.STA_ZP, 0x00,
             Ops.HLT },
    cpuAddrs = { 0x0000, },
    cpuVals  = {   0x55, }
  },

  -- Test 7: Write several sequential bytes to VRAM then read them back.
  {
    code = { Ops.LDA_IMM, 0x3E,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x04,
             Ops.STA_ABS, 0x06, 0x20,

             -- Store 0xF1 @ VRAM[0x3E04]
             Ops.LDA_IMM, 0xE1,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0x44 @ VRAM[0x3E24]
             Ops.LDA_IMM, 0x34,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0x41 @ VRAM[0x3E44]
             Ops.LDA_IMM, 0x31,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0xC9 @ VRAM[0x3E64]
             Ops.LDA_IMM, 0xB9,
             Ops.STA_ABS, 0x07, 0x20,

             -- Store 0x12 @ VRAM[0x3E84]
             Ops.LDA_IMM, 0x02,
             Ops.STA_ABS, 0x07, 0x20,
             
             Ops.LDA_IMM, 0x3E,
             Ops.STA_ABS, 0x06, 0x20,
             Ops.LDA_IMM, 0x04,
             Ops.STA_ABS, 0x06, 0x20,
             
             Ops.LDA_ABS, 0x07, 0x20,

             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x00,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x01,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x02,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x03,
             Ops.LDA_ABS, 0x07, 0x20,
             Ops.STA_ZP, 0x04,

             Ops.HLT },
    cpuAddrs = { 0x0000, 0x0001, 0x0002, 0x0003, 0x0004, },
    cpuVals  = {   0xE1,   0x34,   0x31,   0xB9,   0x02, }
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
      break
    end
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)


