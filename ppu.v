///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: ppu
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 02/13/2012
//
// Description:
//
// Picture processing unit block for an fpga-based NES emulator.  Designed for a Spartan 3E FPGA.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module ppu
(
  input  wire        clk_in,        // 50MHz system clock signal
  input  wire        rst_in,        // reset signal
  input  wire        dbl_in,        // request nes resolution doubler
  input  wire [ 2:0] ri_sel_in,     // register interface reg select
  input  wire        ri_ncs_in,     // register interface enable
  input  wire        ri_r_nw_in,    // register interface read/write select
  input  wire [ 7:0] ri_d_in,       // register interface data in
  input  wire [ 7:0] vram_d_in,     // video memory data bus (input)
  output wire        hsync_out,     // vga hsync signal
  output wire        vsync_out,     // vga vsync signal
  output wire [ 3:0] r_out,         // vga red signal
  output wire [ 3:0] g_out,         // vga green signal
  output wire [ 3:0] b_out,         // vga blue signal
  output wire [ 7:0] ri_d_out,      // register interface data out
  output wire        nvbl_out,      // /VBL (low during vertical blank)
  output wire [13:0] vram_a_out,    // video memory address bus
  output wire [ 7:0] vram_d_out,    // video memory data bus (output)
  output wire        vram_wr_out    // video memory read/write select
);

//
// PPU_VGA: VGA output block.
//
wire [5:0] vga_sys_palette_idx;
wire [9:0] vga_nes_x;
wire [9:0] vga_nes_y;
wire [9:0] vga_nes_y_next;
wire       vga_pix_pulse;
wire       vga_vblank;

ppu_vga ppu_vga_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .dbl_in(dbl_in),
  .sys_palette_idx_in(vga_sys_palette_idx),
  .hsync_out(hsync_out),
  .vsync_out(vsync_out),
  .r_out(r_out),
  .g_out(g_out),
  .b_out(b_out),
  .nes_x_out(vga_nes_x),
  .nes_y_out(vga_nes_y),
  .nes_y_next_out(vga_nes_y_next),
  .pix_pulse_out(vga_pix_pulse),
  .vblank_out(vga_vblank)
);

//
// PPU_RI: PPU register interface block.
//
wire [7:0] ri_vram_din;
wire [7:0] ri_pram_din;
wire [7:0] ri_spr_ram_din;
wire       ri_spr_overflow;
wire       ri_spr_pri_col;
wire [7:0] ri_vram_dout;
wire       ri_vram_wr;
wire       ri_pram_wr;
wire [2:0] ri_fv;
wire [4:0] ri_vt;
wire       ri_v;
wire [2:0] ri_fh;
wire [4:0] ri_ht;
wire       ri_h;
wire       ri_s;
wire       ri_inc_addr;
wire       ri_inc_addr_amt;
wire       ri_nvbl_en;
wire       ri_bg_en;
wire       ri_spr_en;
wire       ri_spr_h;
wire       ri_spr_pt_sel;
wire       ri_upd_cntrs;
wire [7:0] ri_spr_ram_a;
wire [7:0] ri_spr_ram_dout;
wire       ri_spr_ram_wr;

ppu_ri ppu_ri_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .sel_in(ri_sel_in),
  .ncs_in(ri_ncs_in),
  .r_nw_in(ri_r_nw_in),
  .cpu_d_in(ri_d_in),
  .vram_a_in(vram_a_out),
  .vram_d_in(ri_vram_din),
  .pram_d_in(ri_pram_din),
  .vblank_in(vga_vblank),
  .spr_ram_d_in(ri_spr_ram_din),
  .spr_overflow_in(ri_spr_overflow),
  .spr_pri_col_in(ri_spr_pri_col),
  .cpu_d_out(ri_d_out),
  .vram_d_out(ri_vram_dout),
  .vram_wr_out(ri_vram_wr),
  .pram_wr_out(ri_pram_wr),
  .fv_out(ri_fv),
  .vt_out(ri_vt),
  .v_out(ri_v),
  .fh_out(ri_fh),
  .ht_out(ri_ht),
  .h_out(ri_h),
  .s_out(ri_s),
  .inc_addr_out(ri_inc_addr),
  .inc_addr_amt_out(ri_inc_addr_amt),
  .nvbl_en_out(ri_nvbl_en),
  .bg_en_out(ri_bg_en),
  .spr_en_out(ri_spr_en),
  .spr_h_out(ri_spr_h),
  .spr_pt_sel_out(ri_spr_pt_sel),
  .upd_cntrs_out(ri_upd_cntrs),
  .spr_ram_a_out(ri_spr_ram_a),
  .spr_ram_d_out(ri_spr_ram_dout),
  .spr_ram_wr_out(ri_spr_ram_wr)
);

//
// PPU_BG: PPU backgroud/playfield generator block.
//
wire [13:0] bg_vram_a;
wire [ 3:0] bg_palette_idx;

ppu_bg ppu_bg_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .en_in(ri_bg_en),
  .fv_in(ri_fv),
  .vt_in(ri_vt),
  .v_in(ri_v),
  .fh_in(ri_fh),
  .ht_in(ri_ht),
  .h_in(ri_h),
  .s_in(ri_s),
  .nes_x_in(vga_nes_x),
  .nes_y_in(vga_nes_y),
  .nes_y_next_in(vga_nes_y_next),
  .pix_pulse_in(vga_pix_pulse),
  .vram_d_in(vram_d_in),
  .ri_upd_cntrs_in(ri_upd_cntrs),
  .ri_inc_addr_in(ri_inc_addr),
  .ri_inc_addr_amt_in(ri_inc_addr_amt),
  .vram_a_out(bg_vram_a),
  .palette_idx_out(bg_palette_idx)
);

//
// PPU_SPR: PPU sprite generator block.
//
wire  [3:0] spr_palette_idx;
wire        spr_primary;
wire        spr_priority;
wire [13:0] spr_vram_a;
wire        spr_vram_req;

ppu_spr ppu_spr_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .en_in(ri_spr_en),
  .spr_h_in(ri_spr_h),
  .spr_pt_sel_in(ri_spr_pt_sel),
  .oam_a_in(ri_spr_ram_a),
  .oam_d_in(ri_spr_ram_dout),
  .oam_wr_in(ri_spr_ram_wr),
  .nes_x_in(vga_nes_x),
  .nes_y_in(vga_nes_y),
  .nes_y_next_in(vga_nes_y_next),
  .pix_pulse_in(vga_pix_pulse),
  .vram_d_in(vram_d_in),
  .oam_d_out(ri_spr_ram_din),
  .overflow_out(ri_spr_overflow),
  .palette_idx_out(spr_palette_idx),
  .primary_out(spr_primary),
  .priority_out(spr_priority),
  .vram_a_out(spr_vram_a),
  .vram_req_out(spr_vram_req)
);

//
// Vidmem interface.
//
reg  [5:0] palette_ram [31:0];  // internal palette RAM.  32 entries, 6-bits per entry.

always @(posedge clk_in)
  begin
    if (ri_pram_wr)
      palette_ram[vram_a_out[4:0]] <= ri_vram_dout;
  end

assign ri_vram_din = vram_d_in;
assign ri_pram_din = palette_ram[vram_a_out[4:0]];

assign vram_a_out  = (spr_vram_req) ? spr_vram_a : bg_vram_a;
assign vram_d_out  = ri_vram_dout;
assign vram_wr_out = ri_vram_wr;

//
// Multiplexer.  Final system palette index derivation.
//
reg  q_pri_obj_col;
wire d_pri_obj_col;

always @(posedge clk_in)
  begin
    if (rst_in)
      q_pri_obj_col = 1'b0;
    else
      q_pri_obj_col = d_pri_obj_col;
  end

wire spr_foreground;
wire spr_transparent;
wire bg_transparent;

assign spr_foreground  = ~spr_priority;
assign spr_transparent = ~|spr_palette_idx[1:0];
assign bg_transparent  = ~|bg_palette_idx[1:0];

assign d_pri_obj_col =
  (vga_nes_y_next == 0)                                ? 1'b0 :
  (spr_primary && !spr_transparent && !bg_transparent) ? 1'b1 : 
                                                         q_pri_obj_col;

assign vga_sys_palette_idx = 
  ((spr_foreground || bg_transparent) && !spr_transparent) ? palette_ram[{ 1'b1, spr_palette_idx }] :
  (!bg_transparent)                                        ? palette_ram[{ 1'b0, bg_palette_idx }]  :
                                                             palette_ram[5'b00000];

assign ri_spr_pri_col = q_pri_obj_col;

//
// Assign miscellaneous output signals.
//
assign nvbl_out = ~(vga_vblank & ri_nvbl_en);

endmodule

