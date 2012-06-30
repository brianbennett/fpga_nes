/***************************************************************************************************
** fpga_nes/hw/src/cpu/apu/apu_mixer.v
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
*  APU mixer.
***************************************************************************************************/

module apu_mixer
(
  input  wire       clk_in,       // system clock signal
  input  wire       rst_in,       // reset signal
  input  wire [3:0] mute_in,      // mute specific channels
  input  wire [3:0] pulse0_in,    // pulse 0 channel input
  input  wire [3:0] pulse1_in,    // pulse 1 channel input
  input  wire [3:0] triangle_in,  // triangle channel input
  input  wire [3:0] noise_in,     // noise channel input
  output wire       audio_out     // mixed audio output
);

wire [3:0] pulse0;
wire [3:0] pulse1;
wire [3:0] triangle;
wire [3:0] noise;

reg [4:0] pulse_in_total;
reg [5:0] pulse_out;

reg [6:0] tnd_in_total;
reg [5:0] tnd_out;

reg [5:0] mixed_out;

always @*
  begin
    pulse_in_total = pulse0 + pulse1;

    case (pulse_in_total)
      5'h00:   pulse_out = 6'h00;
      5'h01:   pulse_out = 6'h01;
      5'h02:   pulse_out = 6'h01;
      5'h03:   pulse_out = 6'h02;
      5'h04:   pulse_out = 6'h03;
      5'h05:   pulse_out = 6'h03;
      5'h06:   pulse_out = 6'h04;
      5'h07:   pulse_out = 6'h05;
      5'h08:   pulse_out = 6'h05;
      5'h09:   pulse_out = 6'h06;
      5'h0A:   pulse_out = 6'h07;
      5'h0B:   pulse_out = 6'h07;
      5'h0C:   pulse_out = 6'h08;
      5'h0D:   pulse_out = 6'h08;
      5'h0E:   pulse_out = 6'h09;
      5'h0F:   pulse_out = 6'h09;
      5'h10:   pulse_out = 6'h0A;
      5'h11:   pulse_out = 6'h0A;
      5'h12:   pulse_out = 6'h0B;
      5'h13:   pulse_out = 6'h0B;
      5'h14:   pulse_out = 6'h0C;
      5'h15:   pulse_out = 6'h0C;
      5'h16:   pulse_out = 6'h0D;
      5'h17:   pulse_out = 6'h0D;
      5'h18:   pulse_out = 6'h0E;
      5'h19:   pulse_out = 6'h0E;
      5'h1A:   pulse_out = 6'h0F;
      5'h1B:   pulse_out = 6'h0F;
      5'h1C:   pulse_out = 6'h0F;
      5'h1D:   pulse_out = 6'h10;
      5'h1E:   pulse_out = 6'h10;
      default: pulse_out = 6'bxxxxxx;
    endcase

    tnd_in_total = { triangle, 1'b0 } + { 1'b0, triangle } + { noise, 1'b0 };

    case (tnd_in_total)
      7'h00:   tnd_out = 6'h00;
      7'h01:   tnd_out = 6'h01;
      7'h02:   tnd_out = 6'h01;
      7'h03:   tnd_out = 6'h02;
      7'h04:   tnd_out = 6'h03;
      7'h05:   tnd_out = 6'h03;
      7'h06:   tnd_out = 6'h04;
      7'h07:   tnd_out = 6'h05;
      7'h08:   tnd_out = 6'h05;
      7'h09:   tnd_out = 6'h06;
      7'h0A:   tnd_out = 6'h07;
      7'h0B:   tnd_out = 6'h07;
      7'h0C:   tnd_out = 6'h08;
      7'h0D:   tnd_out = 6'h08;
      7'h0E:   tnd_out = 6'h09;
      7'h0F:   tnd_out = 6'h09;
      7'h10:   tnd_out = 6'h0A;
      7'h11:   tnd_out = 6'h0A;
      7'h12:   tnd_out = 6'h0B;
      7'h13:   tnd_out = 6'h0B;
      7'h14:   tnd_out = 6'h0C;
      7'h15:   tnd_out = 6'h0C;
      7'h16:   tnd_out = 6'h0D;
      7'h17:   tnd_out = 6'h0D;
      7'h18:   tnd_out = 6'h0E;
      7'h19:   tnd_out = 6'h0E;
      7'h1A:   tnd_out = 6'h0F;
      7'h1B:   tnd_out = 6'h0F;
      7'h1C:   tnd_out = 6'h0F;
      7'h1D:   tnd_out = 6'h10;
      7'h1E:   tnd_out = 6'h10;
      7'h1F:   tnd_out = 6'h11;
      7'h20:   tnd_out = 6'h11;
      7'h21:   tnd_out = 6'h11;
      7'h22:   tnd_out = 6'h12;
      7'h23:   tnd_out = 6'h12;
      7'h24:   tnd_out = 6'h12;
      7'h25:   tnd_out = 6'h13;
      7'h26:   tnd_out = 6'h13;
      7'h27:   tnd_out = 6'h14;
      7'h28:   tnd_out = 6'h14;
      7'h29:   tnd_out = 6'h14;
      7'h2A:   tnd_out = 6'h15;
      7'h2B:   tnd_out = 6'h15;
      7'h2C:   tnd_out = 6'h15;
      7'h2D:   tnd_out = 6'h15;
      7'h2E:   tnd_out = 6'h16;
      7'h2F:   tnd_out = 6'h16;
      7'h30:   tnd_out = 6'h16;
      7'h31:   tnd_out = 6'h17;
      7'h32:   tnd_out = 6'h17;
      7'h33:   tnd_out = 6'h17;
      7'h34:   tnd_out = 6'h17;
      7'h35:   tnd_out = 6'h18;
      7'h36:   tnd_out = 6'h18;
      7'h37:   tnd_out = 6'h18;
      7'h38:   tnd_out = 6'h19;
      7'h39:   tnd_out = 6'h19;
      7'h3A:   tnd_out = 6'h19;
      7'h3B:   tnd_out = 6'h19;
      7'h3C:   tnd_out = 6'h1A;
      7'h3D:   tnd_out = 6'h1A;
      7'h3E:   tnd_out = 6'h1A;
      7'h3F:   tnd_out = 6'h1A;
      7'h40:   tnd_out = 6'h1B;
      7'h41:   tnd_out = 6'h1B;
      7'h42:   tnd_out = 6'h1B;
      7'h43:   tnd_out = 6'h1B;
      7'h44:   tnd_out = 6'h1B;
      7'h45:   tnd_out = 6'h1C;
      7'h46:   tnd_out = 6'h1C;
      7'h47:   tnd_out = 6'h1C;
      7'h48:   tnd_out = 6'h1C;
      7'h49:   tnd_out = 6'h1C;
      7'h4A:   tnd_out = 6'h1D;
      7'h4B:   tnd_out = 6'h1D;
      default: tnd_out = 6'bxxxxxx;
    endcase

    mixed_out = pulse_out + tnd_out;
  end

//
// Pulse width modulation.
//
reg  [5:0] q_pwm_cnt;
wire [5:0] d_pwm_cnt;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_pwm_cnt  <= 6'h0;
      end
    else
      begin
        q_pwm_cnt  <= d_pwm_cnt;
      end
  end

assign d_pwm_cnt = q_pwm_cnt + 4'h1;

assign pulse0   = (mute_in[0]) ? 4'h0 : pulse0_in;
assign pulse1   = (mute_in[1]) ? 4'h0 : pulse1_in;
assign triangle = (mute_in[2]) ? 4'h0 : triangle_in;
assign noise    = (mute_in[3]) ? 4'h0 : noise_in;

assign audio_out = mixed_out > q_pwm_cnt;

endmodule

