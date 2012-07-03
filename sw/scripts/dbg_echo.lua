----------------------------------------------------------------------------------------------------
-- Script:      dbg_echo.lua
-- Description: Tests dbg block's echo packet.
----------------------------------------------------------------------------------------------------

dofile("../scripts/inc/nesdbg.lua")

local results = {}

local testByteCounts =
{
  0,
  1099,
  100,
  1,
  17,
  2047,
  5,
  4012
}

for subTestIdx = 1, #testByteCounts do
  local outData = {}
  local inData  = {}

  for i = 1, testByteCounts[subTestIdx] do
    outData[i] = math.random(0, 255)
  end

  inData = nesdbg.Echo(testByteCounts[subTestIdx], outData)

  if CompareArrayData(inData, outData) then
    results[subTestIdx] = ScriptResult.Pass
  else
    results[subTestIdx] = ScriptResult.Fail
  end

  ReportSubTestResult(subTestIdx, results[subTestIdx])
end

return ComputeOverallResult(results)

