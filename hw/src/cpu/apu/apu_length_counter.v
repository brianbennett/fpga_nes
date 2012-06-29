/***************************************************************************************************
** fpga_nes/hw/src/cpu/apu/apu_length_counter.v
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
*  APU length counter; building block used by several other APU components.  Provides automatic
*  duration control for the NES APU waveform channels. Once loaded with a value, it can optionally
*  count down and silence the channel when it reaches zero.
***************************************************************************************************/

module apu_length_counter
(
  input  wire       clk_in,           // system clock signal
  input  wire       rst_in,           // reset signal
  input  wire       en_in,            // enable signal (from $4015)
  input  wire       halt_in,          // disable length decrement
  input  wire       length_pulse_in,  // length pulse from frame counter
  input  wire [4:0] length_in,        // new length value
  input  wire       length_wr_in,     // update length to length_in
  output wire       en_out            // length counter is non-0
);

reg  [7:0] q_length, d_length;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_length <= 8'h00;
      end
    else
      begin
        q_length <= d_length;
      end
  end

always @*
  begin
    d_length = q_length;

    if (!en_in)
      begin
        d_length = 8'h00;
      end
    else if (length_wr_in)
      begin
        case (length_in)
          5'h00: d_length = 8'h0A;
          5'h01: d_length = 8'hFE;
          5'h02: d_length = 8'h14;
          5'h03: d_length = 8'h02;
          5'h04: d_length = 8'h28;
          5'h05: d_length = 8'h04;
          5'h06: d_length = 8'h50;
          5'h07: d_length = 8'h06;
          5'h08: d_length = 8'hA0;
          5'h09: d_length = 8'h08;
          5'h0A: d_length = 8'h3C;
          5'h0B: d_length = 8'h0A;
          5'h0C: d_length = 8'h0E;
          5'h0D: d_length = 8'h0C;
          5'h0E: d_length = 8'h1A;
          5'h0F: d_length = 8'h0E;
          5'h10: d_length = 8'h0C;
          5'h11: d_length = 8'h10;
          5'h12: d_length = 8'h18;
          5'h13: d_length = 8'h12;
          5'h14: d_length = 8'h30;
          5'h15: d_length = 8'h14;
          5'h16: d_length = 8'h60;
          5'h17: d_length = 8'h16;
          5'h18: d_length = 8'hC0;
          5'h19: d_length = 8'h18;
          5'h1A: d_length = 8'h48;
          5'h1B: d_length = 8'h1A;
          5'h1C: d_length = 8'h10;
          5'h1D: d_length = 8'h1C;
          5'h1E: d_length = 8'h20;
          5'h1F: d_length = 8'h1E;
        endcase
      end
    else if (length_pulse_in && !halt_in && (q_length != 8'h00))
      begin
        d_length = q_length - 8'h01;
      end
  end

assign en_out = (q_length != 8'h00);

endmodule

