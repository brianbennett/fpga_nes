///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: ppu_spr
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 02/19/2012
//
// Description:
//
// Sprite sub-block of the PPU for an fpga-based NES emulator.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module ppu_spr
(
  input  wire       clk_in,             // 50MHz system clock signal
  input  wire       rst_in,             // reset signal
  input  wire [7:0] spr_ram_a_in,       // sprite ram address
  input  wire [7:0] spr_ram_d_in,       // sprite ram data in
  input  wire       spr_ram_wr_in,      // sprite ram write enable
  output wire [7:0] spr_ram_d_out       // sprite ram data out
);

reg [7:0] sprite_ram [255:0];

always @(posedge clk_in)
  begin
    if (spr_ram_wr_in)
      sprite_ram[spr_ram_a_in] <= spr_ram_d_in;
  end

assign spr_ram_d_out = sprite_ram[spr_ram_a_in];

endmodule
