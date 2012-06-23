/***************************************************************************************************
** fpga_nes/src/cpu/apu/apu.v
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
*  Audio Processing Unit.
***************************************************************************************************/

module apu
(
  input  wire clk_in,    // system clock signal
  input  wire rst_in,    // reset signal
  output wire audio_out  // pwm audio output
);

// Currently APU just outputs an annoying constant 440Hz "A".  This verifies everything's hooked
// up correctly for later support.
reg  [17:0] q_cnt;
wire [17:0] d_cnt;
reg         q_out;
wire        d_out;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_cnt <= 18'h00000;
        q_out <= 1'b0;
      end
    else
      begin
        q_cnt <= d_cnt;
        q_out <= d_out;
      end
  end

assign d_cnt = (q_cnt == 0) ? 18'h377C8 : q_cnt - 18'h00001;
assign d_out = (q_cnt == 0) ? ~q_out : q_out;

assign audio_out = q_out;

endmodule

