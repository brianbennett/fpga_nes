/***************************************************************************************************
** fpga_nes/hw/src/cart/cart.v
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
*  Cartridge emulator for an fpga-based NES emulator.  This block provides access to cartridge
*  memories (PRG-ROM, CHR-ROM) and emulates mapper functionality in order to play emulation ROMs.
*  The intention is that this interface could be re-implemented on top of a hardware NES
*  cartridge, where almost all of the work would pass through directly.
***************************************************************************************************/

module cart
(
  input  wire        clk_in,           // system clock signal

  // Mapper config data.
  input  wire [39:0] cfg_in,           // cartridge config (from iNES header)
  input  wire        cfg_upd_in,       // pulse signal on cfg_in update

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

wire        prgrom_bram_we;
wire [14:0] prgrom_bram_a;
wire [7:0]  prgrom_bram_dout;

// Block ram instance for PRG-ROM memory range (0x8000 - 0xFFFF).  Will eventually be
// replaced with SRAM.
single_port_ram_sync #(.ADDR_WIDTH(15),
                       .DATA_WIDTH(8)) prgrom_bram(
  .clk(clk_in),
  .we(prgrom_bram_we),
  .addr_a(prgrom_bram_a),
  .din_a(prg_d_in),
  .dout_a(prgrom_bram_dout)
);

assign prgrom_bram_we = (~prg_nce_in) ? ~prg_r_nw_in     : 1'b0;
assign prg_d_out      = (~prg_nce_in) ? prgrom_bram_dout : 8'h00;
assign prgrom_bram_a  = (cfg_in[33])  ? prg_a_in[14:0]   : { 1'b0, prg_a_in[13:0] };

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
assign ciram_a10_out      = (cfg_in[16])    ? chr_a_in[10] : chr_a_in[11];
assign chrrom_pat_bram_we = (ciram_nce_out) ? ~chr_r_nw_in : 1'b0;
assign chr_d_out          = (ciram_nce_out) ? chrrom_pat_bram_dout : 8'h00;

endmodule

