/***************************************************************************************************
** fpga_nes/src/cpu/apu/apu_noise.v
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
*  APU noise channel.
***************************************************************************************************/

module apu_noise
(
  input  wire clk_in,              // system clock signal
  input  wire rst_in,              // reset signal
  input  wire apu_cycle_pulse_in,  // 1 clk pulse on every apu cycle
  output wire noise_out            // noise channel output
);

reg [14:0] q_lfsr, d_lfsr;

wire timer_pulse;

apu_div_const #(.PERIOD_BITS(12),
                .PERIOD(202)) timer(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .pulse_in(apu_cycle_pulse_in),
  .pulse_out(timer_pulse)
);

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_lfsr <= 15'h0001;
      end
    else
      begin
        q_lfsr <= d_lfsr;
      end
  end

always @*
  begin
    d_lfsr = q_lfsr;

    if (timer_pulse)
      begin
        d_lfsr = { q_lfsr[0] ^ q_lfsr[1], q_lfsr[14:1] };
      end
  end

assign noise_out = q_lfsr[0];

endmodule

