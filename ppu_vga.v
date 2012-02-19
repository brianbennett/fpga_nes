///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: ppu_vga
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 02/18/2012
//
// Description:
//
// VGA output sub-block of the PPU for an fpga-based NES emulator.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module ppu_vga
(
  input  wire       clk_in,              // 50MHz system clock signal
  input  wire       rst_in,              // reset signal
  input  wire       dbl_in,              // enable nes resolution doubler
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
);

// Display dimensions (640x480).
localparam [ 9:0] DISPLAY_W    = 10'h280,
                  DISPLAY_H    = 10'h1E0;

// NES screen dimensions (256x240).
localparam [ 9:0] NES_W        = 10'h100,
                  NES_H        = 10'h0F0;

// Border color (surrounding NES screen).
localparam [11:0] BORDER_COLOR = 12'h444;

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
reg [11:0] q_rgb, d_rgb;  // output color latch (1 clk delay required by vga_sync)

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_rgb <= 12'h000;
      end
    else
      begin
        q_rgb <= d_rgb;
      end    
  end

//
// Coord and timing signals.
//
wire [9:0] nes_x_next;  // nes x coordinate for next clock
wire       border;      // indicates we are displaying a vga pixel outside the nes extents

assign nes_x_out      = (sync_x - ((DISPLAY_W - (NES_W << dbl_in)) >> 1)) >> dbl_in;
assign nes_y_out      = (sync_y - ((DISPLAY_H - (NES_H << dbl_in)) >> 1)) >> dbl_in;
assign nes_x_next     = (sync_x_next - ((DISPLAY_W - (NES_W << dbl_in)) >> 1)) >> dbl_in;
assign nes_y_next_out = (sync_y_next - ((DISPLAY_H - (NES_H << dbl_in)) >> 1)) >> dbl_in;
assign border         = (nes_x_out >= NES_W) || (nes_y_out < 8) || (nes_y_out >= (NES_H - 8));

//
// Lookup RGB values based on sys_palette_idx.
//
always @*
  begin
    if (!sync_en)
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
        case (sys_palette_idx_in)
          6'h00:  d_rgb = 12'h777;
          6'h01:  d_rgb = 12'h218;
          6'h02:  d_rgb = 12'h00a;
          6'h03:  d_rgb = 12'h409;
          6'h04:  d_rgb = 12'h807;
          6'h05:  d_rgb = 12'ha01;
          6'h06:  d_rgb = 12'ha00;
          6'h07:  d_rgb = 12'h700;
          6'h08:  d_rgb = 12'h420;
          6'h09:  d_rgb = 12'h040;
          6'h0a:  d_rgb = 12'h050;
          6'h0b:  d_rgb = 12'h031;
          6'h0c:  d_rgb = 12'h135;
          6'h0d:  d_rgb = 12'h000;
          6'h0e:  d_rgb = 12'h000;
          6'h0f:  d_rgb = 12'h000;

          6'h10:  d_rgb = 12'hbbb;
          6'h11:  d_rgb = 12'h07e;
          6'h12:  d_rgb = 12'h23e;
          6'h13:  d_rgb = 12'h80f;
          6'h14:  d_rgb = 12'hb0b;
          6'h15:  d_rgb = 12'he05;
          6'h16:  d_rgb = 12'hd20;
          6'h17:  d_rgb = 12'hc40;
          6'h18:  d_rgb = 12'h870;
          6'h19:  d_rgb = 12'h090;
          6'h1a:  d_rgb = 12'h0a0;
          6'h1b:  d_rgb = 12'h093;
          6'h1c:  d_rgb = 12'h088;
          6'h1d:  d_rgb = 12'h000;
          6'h1e:  d_rgb = 12'h000;
          6'h1f:  d_rgb = 12'h000;

          6'h20:  d_rgb = 12'hfff;
          6'h21:  d_rgb = 12'h3bf;
          6'h22:  d_rgb = 12'h59f;
          6'h23:  d_rgb = 12'ha8f;
          6'h24:  d_rgb = 12'hf7f;
          6'h25:  d_rgb = 12'hf7b;
          6'h26:  d_rgb = 12'hf76;
          6'h27:  d_rgb = 12'hf93;
          6'h28:  d_rgb = 12'hfb3;
          6'h29:  d_rgb = 12'h8d1;
          6'h2a:  d_rgb = 12'h4d4;
          6'h2b:  d_rgb = 12'h5f9;
          6'h2c:  d_rgb = 12'h0ed;
          6'h2d:  d_rgb = 12'h000;
          6'h2e:  d_rgb = 12'h000;
          6'h2f:  d_rgb = 12'h000;

          6'h30:  d_rgb = 12'hfff;
          6'h31:  d_rgb = 12'haef;
          6'h32:  d_rgb = 12'hcdf;
          6'h33:  d_rgb = 12'hdcf;
          6'h34:  d_rgb = 12'hfcf;
          6'h35:  d_rgb = 12'hfcd;
          6'h36:  d_rgb = 12'hfbb;
          6'h37:  d_rgb = 12'hfda;
          6'h38:  d_rgb = 12'hfea;
          6'h39:  d_rgb = 12'hefa;
          6'h3a:  d_rgb = 12'hafb;
          6'h3b:  d_rgb = 12'hbfc;
          6'h3c:  d_rgb = 12'h9ff;
          6'h3d:  d_rgb = 12'h000;
          6'h3e:  d_rgb = 12'h000;
          6'h3f:  d_rgb = 12'h000;
        endcase
      end
  end

assign { r_out, g_out, b_out } = q_rgb;
assign pix_pulse_out           = nes_x_next != nes_x_out;
assign vblank_out              = (nes_y_out >= NES_H) && (nes_y_next_out != 0);

endmodule
