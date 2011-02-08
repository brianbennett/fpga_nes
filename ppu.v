///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: ppu
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 02/06/2011
//
// Description:
//
// Picture processing unit block for an fpga-based NES emulator.  Designed for a Spartan 3E FPGA.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module ppu
(
  input  wire       clk,    // 50MHz system clock signal
  input  wire       rst,    // reset signal
  input  wire       dbl,    // request nes resolution doubler
  output wire       hsync,  // vga hsync signal
  output wire       vsync,  // vga vsync signal
  output wire [3:0] r,      // vga red signal
  output wire [3:0] g,      // vga green signal
  output wire [3:0] b       // vga blue signal
);

// Display dimensions (640x480).
localparam [9:0] DISPLAY_W = 10'h280,
                 DISPLAY_H = 10'h1E0;

// NES screen dimensions (256x240).
localparam [9:0] NES_W = 10'h100,
                 NES_H = 10'h0F0;

// Border color (surrounding NES screen).               
localparam [11:0] BORDER_COLOR = 12'h888;

//
// VGA_SYNC: VGA synchronization control block.
//
wire       en;
wire [9:0] vga_x, vga_y;

vga_sync vga_sync_blk(
  .clk(clk),
  .hsync(hsync),
  .vsync(vsync),
  .en(en),
  .x(vga_x),
  .y(vga_y)
);

//
// PPU registers.
//
reg  [11:0] q_rgb, d_rgb;  // output color latch (required by vga_sync for stability)

always @(posedge clk)
  begin
    if (rst)
      q_rgb = 12'h000;
    else
      q_rgb = d_rgb;
  end

//
// Translate <vga_x, vga_y> to NES display coordinates.  Account for resolution doubling
// if necessary.
//
wire [9:0] x, y;
wire       border;

assign x      = (vga_x - ((DISPLAY_W - (NES_W << dbl)) >> 1)) >> dbl;
assign y      = (vga_y - ((DISPLAY_H - (NES_H << dbl)) >> 1)) >> dbl;
assign border = (x >= NES_W) || (y >= NES_H);

//
// Derive output color (system palette index).
//
wire [5:0] sys_palette_idx;

assign sys_palette_idx = { y[5:4], x[7:4] };

//             
// Lookup RGB values based on sys_palette_idx.
//
always @*
  begin
    if (!en)
      begin
        d_rgb = 12'h000;
      end
    else if (border)
      begin
        d_rgb = BORDER_COLOR;
      end
    else
      begin
        // Lookup RGB values based on sys_palette_idx.  Table is an approximation of the NES
        // system palette.  Taken from http://nesdev.parodius.com/NESTechFAQ.htm#nessnescompat.
        case (sys_palette_idx)
          6'h00:  d_rgb = 12'h888;
          6'h01:  d_rgb = 12'h03a;
          6'h02:  d_rgb = 12'h01b;
          6'h03:  d_rgb = 12'h409;
          6'h04:  d_rgb = 12'ha05;
          6'h05:  d_rgb = 12'hc02;
          6'h06:  d_rgb = 12'hb00;
          6'h07:  d_rgb = 12'h810;
          6'h08:  d_rgb = 12'h520;
          6'h09:  d_rgb = 12'h140;
          6'h0a:  d_rgb = 12'h040;
          6'h0b:  d_rgb = 12'h042;
          6'h0c:  d_rgb = 12'h046;
          6'h0d:  d_rgb = 12'h000;
          6'h0e:  d_rgb = 12'h000;
          6'h0f:  d_rgb = 12'h000;

          6'h10:  d_rgb = 12'hccc;
          6'h11:  d_rgb = 12'h07f;
          6'h12:  d_rgb = 12'h25f;
          6'h13:  d_rgb = 12'h83f;
          6'h14:  d_rgb = 12'he2b;
          6'h15:  d_rgb = 12'hf25;
          6'h16:  d_rgb = 12'hf20;
          6'h17:  d_rgb = 12'hd30;
          6'h18:  d_rgb = 12'hc60;
          6'h19:  d_rgb = 12'h380;
          6'h1a:  d_rgb = 12'h080;
          6'h1b:  d_rgb = 12'h085;
          6'h1c:  d_rgb = 12'h09c;
          6'h1d:  d_rgb = 12'h222;
          6'h1e:  d_rgb = 12'h000;
          6'h1f:  d_rgb = 12'h000;

          6'h20:  d_rgb = 12'hfff;
          6'h21:  d_rgb = 12'h0df;
          6'h22:  d_rgb = 12'h6af;
          6'h23:  d_rgb = 12'hd8f;
          6'h24:  d_rgb = 12'hf4f;
          6'h25:  d_rgb = 12'hf68;
          6'h26:  d_rgb = 12'hf83;
          6'h27:  d_rgb = 12'hf91;
          6'h28:  d_rgb = 12'hfb2;
          6'h29:  d_rgb = 12'h9e0;
          6'h2a:  d_rgb = 12'h2f3;
          6'h2b:  d_rgb = 12'h0fa;
          6'h2c:  d_rgb = 12'h0ff;
          6'h2d:  d_rgb = 12'h555;
          6'h2e:  d_rgb = 12'h000;
          6'h2f:  d_rgb = 12'h000;

          6'h30:  d_rgb = 12'hfff;
          6'h31:  d_rgb = 12'haff;
          6'h32:  d_rgb = 12'hbef;
          6'h33:  d_rgb = 12'hdae;
          6'h34:  d_rgb = 12'hfaf;
          6'h35:  d_rgb = 12'hfab;
          6'h36:  d_rgb = 12'hfdb;
          6'h37:  d_rgb = 12'hfea;
          6'h38:  d_rgb = 12'hff9;
          6'h39:  d_rgb = 12'hde9;
          6'h3a:  d_rgb = 12'haea;
          6'h3b:  d_rgb = 12'hafd;
          6'h3c:  d_rgb = 12'h9ff;
          6'h3d:  d_rgb = 12'hddd;
          6'h3e:  d_rgb = 12'h111;
          6'h3f:  d_rgb = 12'h111;
        endcase
      end
  end

// Assign output signals.
assign { r, g, b } = q_rgb;

endmodule

