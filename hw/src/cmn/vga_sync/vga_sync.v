/***************************************************************************************************
** fpga_nes/hw/src/cmn/vga_sync/vga_sync.v
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
*  Outputs HSYNC and VSYNC signals to control 640x480@60Hz VGA output.  x/y outputs indicates the
*  current {x, y} pixel position being displayed.
*
*  Note: VSYNC/HSYNC signals are latched for stability, introducing a 1 CLK delay.  The RGB
*        generation circuit must be aware of this, and should latch its output as well.
***************************************************************************************************/

module vga_sync
(
  input  wire       clk,    // 100Mhz clock signal
  output wire       hsync,  // HSYNC VGA control output
  output wire       vsync,  // VSYNC VGA control output
  output wire       en,     // Indicates when RGB generation circuit should enable (x,y valid)
  output wire [9:0] x,      // Current X position being displayed
  output wire [9:0] y,      // Current Y position being displayed (top = 0)
  output wire [9:0] x_next, // Next X position to be displayed next clock
  output wire [9:0] y_next  // Next Y position to be displayed
);

//
// VGA signal timing parameters.  Taken from http://tinyvga.com/vga-timing/640x480@60Hz.  Note
// that this circuit uses a 25MHz clock instead of specified 25.175MHz clock.  Most displays can
// cope with this out of spec behavior.
//
localparam H_DISP  = 640;  // Number of displayable columns
localparam H_FP    = 16;   // Horizontal front porch in pixel clocks
localparam H_RT    = 96;   // Horizontal retrace (hsync pulse) in pixel clocks
localparam H_BP    = 48;   // Horizontal back porch in pixel clocks
localparam V_DISP  = 480;  // Number of displayable rows
localparam V_FP    = 10;   // Vertical front porch in lines
localparam V_RT    = 2;    // Vertical retrace (vsync pulse) in lines
localparam V_BP    = 29;   // Vertical back porch in lines

// FF for mod-4 counter.  Used to generate a 25MHz pixel enable signal.
reg  [1:0] q_mod4_cnt;
wire [1:0] d_mod4_cnt;

// Horizontal and vertical counters.  Used relative to timings specified in pixels or lines, above.
// Equivalent to x,y position when in the displayable region.
reg  [9:0] q_hcnt, q_vcnt;
wire [9:0] d_hcnt, d_vcnt;

// Output signal FFs.
reg  q_hsync, q_vsync, q_en;
wire d_hsync, d_vsync, d_en;

// FF update logic.
always @(posedge clk)
  begin
    q_mod4_cnt <= d_mod4_cnt;
    q_hcnt     <= d_hcnt;
    q_vcnt     <= d_vcnt;
    q_hsync    <= d_hsync;
    q_vsync    <= d_vsync;
    q_en       <= d_en;
  end

wire pix_pulse;     // 1 clk tick per-pixel
wire line_pulse;    // 1 clk tick per-line (reset to h-pos 0)
wire screen_pulse;  // 1 clk tick per-screen (reset to v-pos 0)

assign d_mod4_cnt = q_mod4_cnt + 2'h1;

assign pix_pulse    = (q_mod4_cnt == 0);
assign line_pulse   = pix_pulse  && (q_hcnt == (H_DISP + H_FP + H_RT + H_BP - 1));
assign screen_pulse = line_pulse && (q_vcnt == (V_DISP + V_FP + V_RT + V_BP - 1));

assign d_hcnt = (line_pulse)   ? 10'h000 : ((pix_pulse)  ? q_hcnt + 10'h001 : q_hcnt);
assign d_vcnt = (screen_pulse) ? 10'h000 : ((line_pulse) ? q_vcnt + 10'h001 : q_vcnt);

assign d_hsync = (q_hcnt >= (H_DISP + H_FP)) && (q_hcnt < (H_DISP + H_FP + H_RT));
assign d_vsync = (q_vcnt >= (V_DISP + V_FP)) && (q_vcnt < (V_DISP + V_FP + V_RT));

assign d_en = (q_hcnt < H_DISP) && (q_vcnt < V_DISP);

// Assign output wires to appropriate FFs.
assign hsync  = q_hsync;
assign vsync  = q_vsync;
assign x      = q_hcnt;
assign y      = q_vcnt;
assign x_next = d_hcnt;
assign y_next = (y == (V_DISP + V_FP + V_RT + V_BP - 10'h001)) ? 10'h000 : (q_vcnt + 10'h001);
assign en     = q_en;

endmodule

