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
wire [9:0] x;
wire [9:0] y;

vga_sync vga_sync_blk(
  .clk(clk),
  .hsync(hsync),
  .vsync(vsync),
  .en(en),
  .x(x),
  .y(y)
);

//
// Internal PPU registers.
//
reg  [11:0] q_rgb;  // output color latch (required by vga_sync for stability)
wire [11:0] d_rgb;

always @(posedge clk)
  begin
    if (rst)
      q_rgb = 12'h000;
    else
      q_rgb = d_rgb;
  end

wire [9:0] nes_x;
wire [9:0] nes_y;
wire       border;

// Compute X,Y position in NES screen, and accounts for resolution doubling when necessary.
assign nes_x  = (x - ((DISPLAY_W - (NES_W << dbl)) >> 1)) >> dbl;
assign nes_y  = (y - ((DISPLAY_H - (NES_H << dbl)) >> 1)) >> dbl;
assign border = (nes_x >= NES_W) || (nes_y >= NES_H);

// Composite output color.
assign d_rgb = (!en    ) ? 12'h000      :
               ( border) ? BORDER_COLOR : { nes_x[7:4], nes_y[7:4], 4'h7 };

// Assign output signals.
assign { r, g, b } = q_rgb;

endmodule

