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
  input  wire        clk,    // 50MHz system clock signal
  input  wire        rst,    // reset signal
  input  wire        dbl,    // request nes resolution doubler
  input  wire [ 7:0] din,    // video memory data bus (input)
  output wire        hsync,  // vga hsync signal
  output wire        vsync,  // vga vsync signal
  output wire [ 3:0] r,      // vga red signal
  output wire [ 3:0] g,      // vga green signal
  output wire [ 3:0] b,      // vga blue signal
  output reg  [13:0] a       // video memory address bus
);

// Display dimensions (640x480).
localparam [9:0] DISPLAY_W = 10'h280,
                 DISPLAY_H = 10'h1E0;

// NES screen dimensions (256x240).
localparam [9:0] NES_W = 10'h100,
                 NES_H = 10'h0F0;

// Border color (surrounding NES screen).
localparam [11:0] BORDER_COLOR = 12'h888;

// PPU memory segment base addresses.
localparam [13:0] PATTERN_TABLE   = 14'h0000;
localparam [13:0] NAME_TABLE      = 14'h2000;
localparam [13:0] ATTRIBUTE_TABLE = 14'h23C0;

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
reg [11:0] q_rgb;              // output color latch (required by vga_sync)
reg [11:0] d_rgb;
reg [ 7:0] q_tile_name;        // name for current and next tile
reg [ 7:0] d_tile_name;
reg [ 7:0] q_attribute [1:0];  // attribute byte for current and next tile
reg [ 7:0] d_attribute [1:0];
reg [ 7:0] q_tile_bit0 [1:0];  // pattern table data with bit0 data for current and next tile
reg [ 7:0] d_tile_bit0 [1:0];
reg [ 7:0] q_tile_bit1 [1:0];  // pattern table data with bit1 data for current and next tile
reg [ 7:0] d_tile_bit1 [1:0];

always @(posedge clk)
  begin
    if (rst)
      begin
        q_rgb          = 12'h000;
        q_tile_name    = 8'h00;
        q_attribute[0] = 8'h00;
        q_attribute[1] = 8'h00;
        q_tile_bit0[0] = 8'h00;
        q_tile_bit0[1] = 8'h00;
        q_tile_bit1[0] = 8'h00;
        q_tile_bit1[1] = 8'h00;
      end
    else
      begin
        q_rgb          = d_rgb;
        q_tile_name    = d_tile_name;
        q_attribute[0] = d_attribute[0];
        q_attribute[1] = d_attribute[1];
        q_tile_bit0[0] = d_tile_bit0[0];
        q_tile_bit0[1] = d_tile_bit0[1];
        q_tile_bit1[0] = d_tile_bit1[0];
        q_tile_bit1[1] = d_tile_bit1[1];
      end
  end

//
// PPU internal RAM.
//
reg [5:0] image_palette [15:0];

always @(posedge clk)
  begin
    if (rst)
      begin
        image_palette[ 0] <= 6'h0E;
        image_palette[ 1] <= 6'h00;
        image_palette[ 2] <= 6'h0E;
        image_palette[ 3] <= 6'h19;
        image_palette[ 4] <= 6'h00;
        image_palette[ 5] <= 6'h00;
        image_palette[ 6] <= 6'h00;
        image_palette[ 7] <= 6'h00;
        image_palette[ 8] <= 6'h00;
        image_palette[ 9] <= 6'h00;
        image_palette[10] <= 6'h00;
        image_palette[11] <= 6'h00;
        image_palette[12] <= 6'h01;
        image_palette[13] <= 6'h00;
        image_palette[14] <= 6'h01;
        image_palette[15] <= 6'h21;
      end
  end

//
// Translate <vga_x, vga_y> to NES display coordinates.  Account for resolution doubling
// if necessary.
//
wire [9:0] x, y;
wire [4:0] tile_x, tile_y, next_tile_x;
wire       border;

assign x           = (vga_x - ((DISPLAY_W - (NES_W << dbl)) >> 1)) >> dbl;
assign y           = (vga_y - ((DISPLAY_H - (NES_H << dbl)) >> 1)) >> dbl;
assign tile_x      = x >> 3;
assign tile_y      = y >> 3;
assign next_tile_x = tile_x + 5'h01;
assign border      = (x >= NES_W) || (y >= NES_H);

//
// Derive output color (system palette index).
//
always @(q_tile_name or q_attribute[0] or q_attribute[1] or q_tile_bit0[0] or q_tile_bit0[1] or
         q_tile_bit1[0] or q_tile_bit1[1] or tile_x or tile_y or next_tile_x or x or y or din)
  begin
    // Default registers to their current values.
    d_tile_name    = q_tile_name;
    d_attribute[0] = q_attribute[0];
    d_attribute[1] = q_attribute[1];
    d_tile_bit0[0] = q_tile_bit0[0];
    d_tile_bit0[1] = q_tile_bit0[1];
    d_tile_bit1[0] = q_tile_bit1[0];
    d_tile_bit1[1] = q_tile_bit1[1];

    a = 14'h0000;

    case (x[2:0])
      3'b000:
        begin
          // Stage 0.  Load next tile's name.
          a = { NAME_TABLE[13:10], tile_y[4:0], next_tile_x[4:0] };
          d_tile_name = din;
        end
      3'b001:
        begin
          // Stage 1.  Load next tile's attrib byte.
          a = { ATTRIBUTE_TABLE[13:6], tile_y[4:2], next_tile_x[4:2] };
          d_attribute[~tile_x[0]] = din;
        end
      3'b010:
        begin
          // Stage 2.  Load bit0 pattern data based on tile name.
          a = { PATTERN_TABLE[13:12], q_tile_name, 1'b0, y[2:0] };
          d_tile_bit0[~tile_x[0]] = din;
        end
      3'b011:
        begin
          // Stage 3.  Load bit1 pattern data based on tile name.
          a = { PATTERN_TABLE[13:12], q_tile_name, 1'b1, y[2:0] };
          d_tile_bit1[~tile_x[0]] = din;
        end
    endcase
  end

//
// Final image composition.
//
wire [3:0] image_palette_idx;
wire [5:0] sys_palette_idx;

assign image_palette_idx = { q_attribute[tile_x[0]] >> { tile_y[1], tile_x[1], 1'b0 },
                             q_tile_bit1[tile_x[0]][~x],
                             q_tile_bit0[tile_x[0]][~x] };
assign sys_palette_idx = image_palette[image_palette_idx];

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

