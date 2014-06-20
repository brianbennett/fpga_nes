/***************************************************************************************************
** fpga_nes/hw/src/ppu/ppu_vga.v
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
*  VGA output PPU sub-block.
***************************************************************************************************/

module ppu_vga
(
  input  wire       clk_in,              // 100MHz system clock signal
  input  wire       rst_in,              // reset signal
  input  wire [5:0] sys_palette_idx_in,  // system palette index (selects output color)
  output wire       hsync_out,           // vga hsync signal
  output wire       vsync_out,           // vga vsync signal
  output wire [3:0] r_out,               // vga red signal
  output wire [3:0] g_out,               // vga green signal
  output wire [3:0] b_out,               // vga blue signal
  output wire [9:0] nes_x_out,           // nes x coordinate
  output wire [9:0] nes_y_out,           // nes y coordinate
  output wire [9:0] nes_y_next_out,      // next line's nes y coordinate
  output wire       pix_pulse_out,       // 1 clk pulse prior to nes_x update
  output wire       vblank_out           // indicates a vblank is occuring (no PPU vram access)
  //output wire [14:0] single_pixel,
  //input wire [14:0] double_pixel
);

// Display dimensions (640x480).
localparam [9:0] DISPLAY_W    = 10'h280,
                 DISPLAY_H    = 10'h1E0;

// NES screen dimensions (256x240).
localparam [9:0] NES_W        = 10'h100,
                 NES_H        = 10'h0F0;

// Border color (surrounding NES screen).
localparam [7:0] BORDER_COLOR = 8'h49;

//
// VGA_SYNC: VGA synchronization control block.
//
wire       sync_en;      // vga enable signal
wire [9:0] sync_x;       // current vga x coordinate
wire [9:0] sync_y;       // current vga y coordinate
wire [9:0] sync_x_next;  // vga x coordinate for next clock
wire [9:0] sync_y_next;  // vga y coordinate for next line

reg [14:0] pallut[0:63];
initial $readmemh("nes_palette.txt", pallut);

vga_sync vga_sync_blk(
  .clk(clk_in),
  .hsync(hsync_out),
  .vsync(vsync_out),
  .en(sync_en),
  .x(sync_x),
  .y(sync_y),
  .x_next(sync_x_next),
  .y_next(sync_y_next)
);

//
// Registers.
//
reg  [14:0] q_rgb;     // output color latch (1 clk delay required by vga_sync)
reg  [14:0] d_rgb;
reg        q_vblank;  // current vblank state
wire       d_vblank;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_rgb    <= 14'h00;
        q_vblank <= 1'h0;
      end
    else
      begin
        q_rgb    <= d_rgb;
        q_vblank <= d_vblank;
      end
  end

//
// Coord and timing signals.
//
wire [9:0] nes_x_next;  // nes x coordinate for next clock
wire       border;      // indicates we are displaying a vga pixel outside the nes extents

assign nes_x_out      = (sync_x - 10'h040) >> 1;
assign nes_y_out      = sync_y >> 1;
assign nes_x_next     = (sync_x_next - 10'h040) >> 1;
assign nes_y_next_out = sync_y_next >> 1;
assign border         = (nes_x_out >= NES_W) || (nes_y_out < 8) || (nes_y_out >= (NES_H - 8));

//
// Lookup RGB values based on sys_palette_idx.
//
always @*
  begin
    if (!sync_en)
      begin
        d_rgb = 8'h00;
      end
    else if (border)
      begin
        d_rgb = BORDER_COLOR;
      end
    else
      begin
        d_rgb = pallut[sys_palette_idx_in];
      end
  end

assign { r_out, g_out, b_out } = {q_rgb[4:1], q_rgb[9:6], q_rgb[14:11]};
assign pix_pulse_out           = nes_x_next != nes_x_out;

// Clear the VBLANK signal immediately before starting processing of the pre-0 garbage line.  From
// here.  Set the vblank approximately 2270 CPU cycles before it will be cleared.  This is done
// in order to pass vbl_clear_time.nes.  It eats into the visible portion of the playfield, but we
// currently hide that portion of the screen anyway.
assign d_vblank = ((sync_x == 730) && (sync_y == 477)) ? 1'b1 :
                  ((sync_x == 64) && (sync_y == 519))  ? 1'b0 : q_vblank;

assign vblank_out = q_vblank;

endmodule