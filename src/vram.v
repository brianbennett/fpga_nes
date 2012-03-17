///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: vram
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 03/17/2012
//
// Description:
//
// Video RAM module for an fpga-based NES emulator.  Implements 2KB of on-board VRAM as fpga
// block RAM.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module vram
(
  input  wire         clk_in,   // system clock
  input  wire         en_in,    // chip enable
  input  wire         r_nw_in,  // read/write select (read: 0, write: 1)
  input  wire  [10:0] a_in,     // memory address
  input  wire  [ 7:0] d_in,     // data input
  output wire  [ 7:0] d_out     // data output
);

wire       vram_bram_we;
wire [7:0] vram_bram_dout;

single_port_ram_sync #(.ADDR_WIDTH(11),
                       .DATA_WIDTH(8)) vram_bram(
  .clk(clk_in),
  .we(vram_bram_we),
  .addr_a(a_in),
  .din_a(d_in),
  .dout_a(vram_bram_dout)
);

assign vram_bram_we = (en_in) ? ~r_nw_in       : 1'b0;
assign d_out        = (en_in) ? vram_bram_dout : 8'h00;

endmodule

