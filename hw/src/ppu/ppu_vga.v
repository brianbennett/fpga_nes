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
  output wire [2:0] r_out,               // vga red signal
  output wire [2:0] g_out,               // vga green signal
  output wire [1:0] b_out,               // vga blue signal
  output wire [9:0] nes_x_out,           // nes x coordinate
  output wire [9:0] nes_y_out,           // nes y coordinate
  output wire [9:0] nes_y_next_out,      // next line's nes y coordinate
  output wire       pix_pulse_out,       // 1 clk pulse prior to nes_x update
  output wire       vblank_out           // indicates a vblank is occuring (no PPU vram access)
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
reg  [7:0] q_rgb;     // output color latch (1 clk delay required by vga_sync)
reg  [7:0] d_rgb;
reg        q_vblank;  // current vblank state
wire       d_vblank;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_rgb    <= 8'h00;
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
        // Lookup RGB values based on sys_palette_idx.  Table is an approximation of the NES
        // system palette.  Taken from http://nesdev.parodius.com/NESTechFAQ.htm#nessnescompat.
        case (sys_palette_idx_in)
          6'h00:  d_rgb = { 3'h3, 3'h3, 2'h1 };
          6'h01:  d_rgb = { 3'h1, 3'h0, 2'h2 };
          6'h02:  d_rgb = { 3'h0, 3'h0, 2'h2 };
          6'h03:  d_rgb = { 3'h2, 3'h0, 2'h2 };
          6'h04:  d_rgb = { 3'h4, 3'h0, 2'h1 };
          6'h05:  d_rgb = { 3'h5, 3'h0, 2'h0 };
          6'h06:  d_rgb = { 3'h5, 3'h0, 2'h0 };
          6'h07:  d_rgb = { 3'h3, 3'h0, 2'h0 };
          6'h08:  d_rgb = { 3'h2, 3'h1, 2'h0 };
          6'h09:  d_rgb = { 3'h0, 3'h2, 2'h0 };
          6'h0a:  d_rgb = { 3'h0, 3'h2, 2'h0 };
          6'h0b:  d_rgb = { 3'h0, 3'h1, 2'h0 };
          6'h0c:  d_rgb = { 3'h0, 3'h1, 2'h1 };
          6'h0d:  d_rgb = { 3'h0, 3'h0, 2'h0 };
          6'h0e:  d_rgb = { 3'h0, 3'h0, 2'h0 };
          6'h0f:  d_rgb = { 3'h0, 3'h0, 2'h0 };

          6'h10:  d_rgb = { 3'h5, 3'h5, 2'h2 };
          6'h11:  d_rgb = { 3'h0, 3'h3, 2'h3 };
          6'h12:  d_rgb = { 3'h1, 3'h1, 2'h3 };
          6'h13:  d_rgb = { 3'h4, 3'h0, 2'h3 };
          6'h14:  d_rgb = { 3'h5, 3'h0, 2'h2 };
          6'h15:  d_rgb = { 3'h7, 3'h0, 2'h1 };
          6'h16:  d_rgb = { 3'h6, 3'h1, 2'h0 };
          6'h17:  d_rgb = { 3'h6, 3'h2, 2'h0 };
          6'h18:  d_rgb = { 3'h4, 3'h3, 2'h0 };
          6'h19:  d_rgb = { 3'h0, 3'h4, 2'h0 };
          6'h1a:  d_rgb = { 3'h0, 3'h5, 2'h0 };
          6'h1b:  d_rgb = { 3'h0, 3'h4, 2'h0 };
          6'h1c:  d_rgb = { 3'h0, 3'h4, 2'h2 };
          6'h1d:  d_rgb = { 3'h0, 3'h0, 2'h0 };
          6'h1e:  d_rgb = { 3'h0, 3'h0, 2'h0 };
          6'h1f:  d_rgb = { 3'h0, 3'h0, 2'h0 };

          6'h20:  d_rgb = { 3'h7, 3'h7, 2'h3 };
          6'h21:  d_rgb = { 3'h1, 3'h5, 2'h3 };
          6'h22:  d_rgb = { 3'h2, 3'h4, 2'h3 };
          6'h23:  d_rgb = { 3'h5, 3'h4, 2'h3 };
          6'h24:  d_rgb = { 3'h7, 3'h3, 2'h3 };
          6'h25:  d_rgb = { 3'h7, 3'h3, 2'h2 };
          6'h26:  d_rgb = { 3'h7, 3'h3, 2'h1 };
          6'h27:  d_rgb = { 3'h7, 3'h4, 2'h0 };
          6'h28:  d_rgb = { 3'h7, 3'h5, 2'h0 };
          6'h29:  d_rgb = { 3'h4, 3'h6, 2'h0 };
          6'h2a:  d_rgb = { 3'h2, 3'h6, 2'h1 };
          6'h2b:  d_rgb = { 3'h2, 3'h7, 2'h2 };
          6'h2c:  d_rgb = { 3'h0, 3'h7, 2'h3 };
          6'h2d:  d_rgb = { 3'h0, 3'h0, 2'h0 };
          6'h2e:  d_rgb = { 3'h0, 3'h0, 2'h0 };
          6'h2f:  d_rgb = { 3'h0, 3'h0, 2'h0 };

          6'h30:  d_rgb = { 3'h7, 3'h7, 2'h3 };
          6'h31:  d_rgb = { 3'h5, 3'h7, 2'h3 };
          6'h32:  d_rgb = { 3'h6, 3'h6, 2'h3 };
          6'h33:  d_rgb = { 3'h6, 3'h6, 2'h3 };
          6'h34:  d_rgb = { 3'h7, 3'h6, 2'h3 };
          6'h35:  d_rgb = { 3'h7, 3'h6, 2'h3 };
          6'h36:  d_rgb = { 3'h7, 3'h5, 2'h2 };
          6'h37:  d_rgb = { 3'h7, 3'h6, 2'h2 };
          6'h38:  d_rgb = { 3'h7, 3'h7, 2'h2 };
          6'h39:  d_rgb = { 3'h7, 3'h7, 2'h2 };
          6'h3a:  d_rgb = { 3'h5, 3'h7, 2'h2 };
          6'h3b:  d_rgb = { 3'h5, 3'h7, 2'h3 };
          6'h3c:  d_rgb = { 3'h4, 3'h7, 2'h3 };
          6'h3d:  d_rgb = { 3'h0, 3'h0, 2'h0 };
          6'h3e:  d_rgb = { 3'h0, 3'h0, 2'h0 };
          6'h3f:  d_rgb = { 3'h0, 3'h0, 2'h0 };
        endcase
      end
  end

assign { r_out, g_out, b_out } = q_rgb;
assign pix_pulse_out           = nes_x_next != nes_x_out;

// Clear the VBLANK signal immediately before starting processing of the pre-0 garbage line.  From
// here.  Set the vblank approximately 2270 CPU cycles before it will be cleared.  This is done
// in order to pass vbl_clear_time.nes.  It eats into the visible portion of the playfield, but we
// currently hide that portion of the screen anyway.
assign d_vblank = ((sync_x == 730) && (sync_y == 477)) ? 1'b1 :
                  ((sync_x == 64) && (sync_y == 519))  ? 1'b0 : q_vblank;

assign vblank_out = q_vblank;

endmodule

