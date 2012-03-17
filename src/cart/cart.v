///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: cart
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 03/10/2012
//
// Description:
// 
// Cartridge emulator for an fpga-based NES emulator.  This block provides access to cartridge
// memories (PRG-ROM, CHR-ROM) and emulates mapper functionality in order to play emulation ROMs.
// The intention is that this interface could be re-implemented on top of a hardware NES
// cartridge, where almost all of the work would pass through directly.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module cart
(
  input  wire        clk_in,           // system clock signal

  // Mapper config data.
  input  wire        mirror_cfg_in,    // mirror configuration

  // PRG-ROM interface.
  input  wire        prg_nce_in,       // prg-rom chip enable (active low)
  input  wire [14:0] prg_a_in,         // prg-rom address
  input  wire        prg_r_nw_in,      // prg-rom read/write select
  input  wire [ 7:0] prg_d_in,         // prg-rom data in
  output wire [ 7:0] prg_d_out,        // prg-rom data out

  // CHR-ROM interface.
  input  wire [13:0] chr_a_in,         // chr-rom address
  input  wire        chr_r_nw_in,      // chr-rom read/write select
  input  wire [ 7:0] chr_d_in,         // chr-rom data in
  output wire [ 7:0] chr_d_out,        // chr-rom data out
  output wire        ciram_nce_out,    // vram chip enable (active low)
  output wire        ciram_a10_out     // vram a10 value (controls mirroring)
);

wire       prgrom_hi_bram_we;
wire [7:0] prgrom_hi_bram_dout;

// Block ram instance for "PRG-ROM HI" memory range (0xC000 - 0xFFFF).  Will eventually be
// replaced with SRAM.
single_port_ram_sync #(.ADDR_WIDTH(14),
                       .DATA_WIDTH(8)) prgrom_hi_bram(
  .clk(clk_in),
  .we(prgrom_hi_bram_we),
  .addr_a(prg_a_in[13:0]),
  .din_a(prg_d_in),
  .dout_a(prgrom_hi_bram_dout)
);

assign prgrom_hi_bram_we = (~prg_nce_in) ? ~prg_r_nw_in        : 1'b0;
assign prg_d_out         = (~prg_nce_in) ? prgrom_hi_bram_dout : 8'h00;

wire       chrrom_pat_bram_we;
wire [7:0] chrrom_pat_bram_dout;

// Block ram instance for "CHR Pattern Table" memory range (0x0000 - 0x1FFF).
single_port_ram_sync #(.ADDR_WIDTH(13),
                       .DATA_WIDTH(8)) chrrom_pat_bram(
  .clk(clk_in),
  .we(chrrom_pat_bram_we),
  .addr_a(chr_a_in[12:0]),
  .din_a(chr_d_in),
  .dout_a(chrrom_pat_bram_dout)
);

assign ciram_nce_out      = ~chr_a_in[13];
assign ciram_a10_out      = (mirror_cfg_in) ? chr_a_in[10] : chr_a_in[11];
assign chrrom_pat_bram_we = (ciram_nce_out) ? ~chr_r_nw_in : 1'b0;
assign chr_d_out          = (ciram_nce_out) ? chrrom_pat_bram_dout : 8'h00;

endmodule

