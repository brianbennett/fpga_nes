/***************************************************************************************************
** fpga_nes/hw/src/cpu/apu/apu_div.v
*
*  Copyright (c) 2012, Brian Bennett
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without modification, are permitted
*  provided that the following conditions are met:
*
*  1. Redistributions of source code must retain the above copyright notice, this list of conditions
*     and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright notice, this list of
*     conditions and the following disclaimer in the documentation and/or other materials provided
*     with the distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
*  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
*  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
*  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
*  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
*  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*  APU divider; building block used by several other APU components.  Outputs a pulse every n input
*  pulses, where n is the divider's period. It contains a counter which is decremented on the
*  arrival of each pulse. When the counter reaches 0, it is reloaded with the period and an output
*  pulse is generated. A divider can also be forced to reload its counter immediately, but this
*  does not output a pulse. When a divider's period is changed, the current count is not affected.
*
*  apu_div_const is a variation on apu_div that has an immutable period.
***************************************************************************************************/

module apu_div
#(
  parameter PERIOD_BITS = 16
)
(
  input  wire                   clk_in,     // system clock signal
  input  wire                   rst_in,     // reset signal
  input  wire                   pulse_in,   // input pulse
  input  wire                   reload_in,  // reset counter to period_in (no pulse_out generated)
  input  wire [PERIOD_BITS-1:0] period_in,  // new period value
  output wire                   pulse_out   // divided output pulse
);

reg  [PERIOD_BITS-1:0] q_cnt;
wire [PERIOD_BITS-1:0] d_cnt;

always @(posedge clk_in)
  begin
    if (rst_in)
      q_cnt <= 0;
    else
      q_cnt <= d_cnt;
  end

assign d_cnt     = (reload_in || (pulse_in && (q_cnt == 0))) ? period_in    :
                   (pulse_in)                                ? q_cnt - 1'h1 : q_cnt;
assign pulse_out = pulse_in && (q_cnt == 0);

endmodule

