/***************************************************************************************************
** fpga_nes/hw/src/ppu/ppu_spr.v
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
*  Sprite PPU sub-block.
***************************************************************************************************/

module ppu_spr
(
  input  wire        clk_in,            // 100MHz system clock signal
  input  wire        rst_in,            // reset signal
  input  wire        en_in,             // enable sprites
  input  wire        ls_clip_in,        // clip sprites in left 8 pixels
  input  wire        spr_h_in,          // select 8/16 pixel high sprites
  input  wire        spr_pt_sel_in,     // sprite palette table select
  input  wire [ 7:0] oam_a_in,          // sprite ram address
  input  wire [ 7:0] oam_d_in,          // sprite ram data in
  input  wire        oam_wr_in,         // sprite ram write enable
  input  wire [ 9:0] nes_x_in,          // nes x coordinate
  input  wire [ 9:0] nes_y_in,          // nes y coordinate
  input  wire [ 9:0] nes_y_next_in,     // next line's nes y coordinate
  input  wire        pix_pulse_in,      // pulse signal one clock immediately before nes x changes
  input  wire [ 7:0] vram_d_in,         // vram data in for pattern table reads
  output wire [ 7:0] oam_d_out,         // sprite ram data out
  output wire        overflow_out,      // more than 8 sprites on one scanline in current frame
  output wire [ 3:0] palette_idx_out,   // final sprite palette index
  output wire        primary_out,       // final sprite is the primary object (sprite 0)
  output wire        priority_out,      // final sprite priority (foreground/background)
  output reg  [13:0] vram_a_out,        // vram address bus for pattern table reads
  output reg         vram_req_out       // indicates sprite block needs vram ownership
);

// OAM: Object Attribute Memory (256 entries, 4 bytes per entry)
//
// byte bits desc
// ---- ---- ----
//  0   7:0  scanline coordinate minus one of object's top pixel row.
//  1   7:0  tile index number. Bit 0 here controls pattern table selection when reg 0x2000[5]5 = 1.
//  2     0  palette select low bit
//        1  palette select high bit
//        5 object priority (> playfield's if 0; < playfield's if 1)
//        6 apply bit reversal to fetched object pattern table data
//        7 invert the 3/4-bit (8/16 scanlines/object mode) scanline address used to access an object
//          tile
//  3   7:0 scanline pixel coordinate of most left-hand side of object.
reg [7:0] m_oam [255:0];

always @(posedge clk_in)
  begin
    if (oam_wr_in)
      m_oam[oam_a_in] <= oam_d_in;
  end

// STM: Sprite Temporary Memory
//
// bits     desc
// -------  -----
//      24  primary object flag (is sprite 0?)
// 23 : 16  tile index
// 15 :  8  x coordinate
//  7 :  6  palette select bits
//       5  object priority
//       4  apply bit reversal to fetched object pattern table data (horizontal invert)
//  3 :  0  range comparison result (sprite row)
reg [24:0] m_stm [7:0];

reg [24:0] stm_din;
reg [ 2:0] stm_a;
reg        stm_wr;

always @(posedge clk_in)
  begin
    if (stm_wr)
      m_stm[stm_a] <= stm_din;
  end

// SBM: Sprite Buffer Memory
//
// bits     desc
// -------  -----
//      27  primary object flag (is sprite 0?)
//      26  priority
// 25 - 24  palette select (bit 3-2)
// 23 - 16  pattern data bit 1
// 15 -  8  pattern data bit 0
//  7 -  0  x-start
reg [27:0] m_sbm [7:0];

reg [27:0] sbm_din;
reg [ 2:0] sbm_a;
reg        sbm_wr;

always @(posedge clk_in)
  begin
    if (sbm_wr)
      m_sbm[sbm_a] <= sbm_din;
  end

//
// In-range object evaluation (line N-1, fetch phases 1-128).
//
reg [3:0] q_in_rng_cnt,   d_in_rng_cnt;    // number of objects on the next scanline
reg       q_spr_overflow, d_spr_overflow;  // signals more than 8 objects on a scanline this frame

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_in_rng_cnt   <= 4'h0;
        q_spr_overflow <= 1'h0;
      end
    else
      begin
        q_in_rng_cnt   <= d_in_rng_cnt;
        q_spr_overflow <= d_spr_overflow;
      end
  end

wire [5:0] oam_rd_idx;       // oam entry selector
wire [7:0] oam_rd_y;         // cur oam entry y coordinate
wire [7:0] oam_rd_tile_idx;  // cur oam entry tile index
wire       oam_rd_v_inv;     // cur oam entry vertical inversion state
wire       oam_rd_h_inv;     // cur oam entry horizontal inversion state
wire       oam_rd_priority;  // cur oam entry priority
wire [1:0] oam_rd_ps;        // cur oam entry palette select
wire [7:0] oam_rd_x;         // cur oam entry x coordinate

wire [8:0] rng_cmp_res;      // 9-bit comparison result for in-range check
wire       in_rng;           // indicates whether current object is in-range

assign oam_rd_idx      = nes_x_in[7:2];

assign oam_rd_y        = m_oam[{ oam_rd_idx, 2'b00 }] + 8'h01;
assign oam_rd_tile_idx = m_oam[{ oam_rd_idx, 2'b01 }];
assign oam_rd_v_inv    = m_oam[{ oam_rd_idx, 2'b10 }] >> 3'h7;
assign oam_rd_h_inv    = m_oam[{ oam_rd_idx, 2'b10 }] >> 3'h6;
assign oam_rd_priority = m_oam[{ oam_rd_idx, 2'b10 }] >> 3'h5;
assign oam_rd_ps       = m_oam[{ oam_rd_idx, 2'b10 }];
assign oam_rd_x        = m_oam[{ oam_rd_idx, 2'b11 }];

assign rng_cmp_res     = nes_y_next_in - oam_rd_y;
assign in_rng          = (~|rng_cmp_res[8:4]) & (~rng_cmp_res[3] | spr_h_in);

always @*
  begin
    d_in_rng_cnt  = q_in_rng_cnt;

    // Reset the sprite overflow flag at the beginning of each frame.  Otherwise, set the flag if
    // any scanline in this frame has intersected more than 8 sprites.
    if ((nes_y_next_in == 0) && (nes_x_in == 0))
      d_spr_overflow = 1'b0;
    else
      d_spr_overflow = q_spr_overflow || q_in_rng_cnt[3];

    stm_a  = q_in_rng_cnt[2:0];
    stm_wr = 1'b0;

    stm_din[   24] = ~|oam_rd_idx;
    stm_din[23:16] = oam_rd_tile_idx;
    stm_din[15: 8] = oam_rd_x;
    stm_din[ 7: 6] = oam_rd_ps;
    stm_din[    5] = oam_rd_priority;
    stm_din[    4] = oam_rd_h_inv;
    stm_din[ 3: 0] = (oam_rd_v_inv) ? ~rng_cmp_res[3:0] : rng_cmp_res[3:0];

    if (en_in && pix_pulse_in && (nes_y_next_in < 239))
      begin
        if (nes_x_in == 320)
          begin
            // Reset the in-range count and sprite 0 in-rnage flag at the end of each scanline.
            d_in_rng_cnt  = 4'h0;
          end
        else if ((nes_x_in < 256) && (nes_x_in[1:0] == 2'h0) && in_rng && !q_in_rng_cnt[3])
          begin
            // Current object is in range, and there are less than 8 in-range objects found
            // so far.  Update the STM and increment the in-range counter.
            stm_wr       = 1'b1;
            d_in_rng_cnt = q_in_rng_cnt + 4'h1;
          end
      end
  end

//
// Object pattern fetch (fetch phases 129-160).
//
reg [7:0] q_pd0, d_pd0;
reg [7:0] q_pd1, d_pd1;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_pd1 <= 8'h00;
        q_pd0 <= 8'h00;
      end
    else
      begin
        q_pd1 <= d_pd1;
        q_pd0 <= d_pd0;
      end
  end

wire [2:0] stm_rd_idx;
wire       stm_rd_primary;
wire [7:0] stm_rd_tile_idx;
wire [7:0] stm_rd_x;
wire [1:0] stm_rd_ps;
wire       stm_rd_priority;
wire       stm_rd_h_inv;
wire [3:0] stm_rd_obj_row;

assign stm_rd_idx      = nes_x_in[5:3];
assign stm_rd_primary  = m_stm[stm_rd_idx] >> 24;
assign stm_rd_tile_idx = m_stm[stm_rd_idx] >> 16;
assign stm_rd_x        = m_stm[stm_rd_idx] >> 8;
assign stm_rd_ps       = m_stm[stm_rd_idx] >> 6;
assign stm_rd_priority = m_stm[stm_rd_idx] >> 5;
assign stm_rd_h_inv    = m_stm[stm_rd_idx] >> 4;
assign stm_rd_obj_row  = m_stm[stm_rd_idx];

always @*
  begin
    d_pd1 = q_pd1;
    d_pd0 = q_pd0;

    sbm_a   = stm_rd_idx;
    sbm_wr  = 1'b0;
    sbm_din = 28'h000;

    vram_req_out = 1'b0;

    if (spr_h_in)
      vram_a_out = { 1'b0,
                     stm_rd_tile_idx[0],
                     stm_rd_tile_idx[7:1],
                     stm_rd_obj_row[3],
                     nes_x_in[1],
                     stm_rd_obj_row[2:0] };
    else
      vram_a_out = { 1'b0,
                     spr_pt_sel_in,
                     stm_rd_tile_idx,
                     nes_x_in[1],
                     stm_rd_obj_row[2:0] };

    if (en_in && (nes_y_next_in < 239) && (nes_x_in >= 256) && (nes_x_in < 320))
      begin
        if (stm_rd_idx < q_in_rng_cnt)
          begin
            case (nes_x_in[2:1])
              2'h0:
                begin
                  vram_req_out = 1'b1;

                  if (stm_rd_h_inv)
                    begin
                      d_pd0 = vram_d_in;
                    end
                  else
                    begin
                      d_pd0[0] = vram_d_in[7];
                      d_pd0[1] = vram_d_in[6];
                      d_pd0[2] = vram_d_in[5];
                      d_pd0[3] = vram_d_in[4];
                      d_pd0[4] = vram_d_in[3];
                      d_pd0[5] = vram_d_in[2];
                      d_pd0[6] = vram_d_in[1];
                      d_pd0[7] = vram_d_in[0];
                    end
                end
              2'h1:
                begin
                  vram_req_out = 1'b1;

                  if (stm_rd_h_inv)
                    begin
                      d_pd1 = vram_d_in;
                    end
                  else
                    begin
                      d_pd1[0] = vram_d_in[7];
                      d_pd1[1] = vram_d_in[6];
                      d_pd1[2] = vram_d_in[5];
                      d_pd1[3] = vram_d_in[4];
                      d_pd1[4] = vram_d_in[3];
                      d_pd1[5] = vram_d_in[2];
                      d_pd1[6] = vram_d_in[1];
                      d_pd1[7] = vram_d_in[0];
                    end
                end
              2'h2:
                begin
                  sbm_din = { stm_rd_primary, stm_rd_priority, stm_rd_ps, q_pd1, q_pd0, stm_rd_x };
                  sbm_wr  = 1'b1;
                end
            endcase
          end
        else
          begin
            sbm_din = 28'h0000000;
            sbm_wr  = 1'b1;
          end
      end
  end

//
// Object prioritization and output (line N, fetch phases 1-128).
//
reg  [7:0] q_obj0_pd1_shift, d_obj0_pd1_shift;
reg  [7:0] q_obj1_pd1_shift, d_obj1_pd1_shift;
reg  [7:0] q_obj2_pd1_shift, d_obj2_pd1_shift;
reg  [7:0] q_obj3_pd1_shift, d_obj3_pd1_shift;
reg  [7:0] q_obj4_pd1_shift, d_obj4_pd1_shift;
reg  [7:0] q_obj5_pd1_shift, d_obj5_pd1_shift;
reg  [7:0] q_obj6_pd1_shift, d_obj6_pd1_shift;
reg  [7:0] q_obj7_pd1_shift, d_obj7_pd1_shift;
reg  [7:0] q_obj0_pd0_shift, d_obj0_pd0_shift;
reg  [7:0] q_obj1_pd0_shift, d_obj1_pd0_shift;
reg  [7:0] q_obj2_pd0_shift, d_obj2_pd0_shift;
reg  [7:0] q_obj3_pd0_shift, d_obj3_pd0_shift;
reg  [7:0] q_obj4_pd0_shift, d_obj4_pd0_shift;
reg  [7:0] q_obj5_pd0_shift, d_obj5_pd0_shift;
reg  [7:0] q_obj6_pd0_shift, d_obj6_pd0_shift;
reg  [7:0] q_obj7_pd0_shift, d_obj7_pd0_shift;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_obj0_pd1_shift <= 8'h00;
        q_obj1_pd1_shift <= 8'h00;
        q_obj2_pd1_shift <= 8'h00;
        q_obj3_pd1_shift <= 8'h00;
        q_obj4_pd1_shift <= 8'h00;
        q_obj5_pd1_shift <= 8'h00;
        q_obj6_pd1_shift <= 8'h00;
        q_obj7_pd1_shift <= 8'h00;
        q_obj0_pd0_shift <= 8'h00;
        q_obj1_pd0_shift <= 8'h00;
        q_obj2_pd0_shift <= 8'h00;
        q_obj3_pd0_shift <= 8'h00;
        q_obj4_pd0_shift <= 8'h00;
        q_obj5_pd0_shift <= 8'h00;
        q_obj6_pd0_shift <= 8'h00;
        q_obj7_pd0_shift <= 8'h00;
      end
    else
      begin
        q_obj0_pd1_shift <= d_obj0_pd1_shift;
        q_obj1_pd1_shift <= d_obj1_pd1_shift;
        q_obj2_pd1_shift <= d_obj2_pd1_shift;
        q_obj3_pd1_shift <= d_obj3_pd1_shift;
        q_obj4_pd1_shift <= d_obj4_pd1_shift;
        q_obj5_pd1_shift <= d_obj5_pd1_shift;
        q_obj6_pd1_shift <= d_obj6_pd1_shift;
        q_obj7_pd1_shift <= d_obj7_pd1_shift;
        q_obj0_pd0_shift <= d_obj0_pd0_shift;
        q_obj1_pd0_shift <= d_obj1_pd0_shift;
        q_obj2_pd0_shift <= d_obj2_pd0_shift;
        q_obj3_pd0_shift <= d_obj3_pd0_shift;
        q_obj4_pd0_shift <= d_obj4_pd0_shift;
        q_obj5_pd0_shift <= d_obj5_pd0_shift;
        q_obj6_pd0_shift <= d_obj6_pd0_shift;
        q_obj7_pd0_shift <= d_obj7_pd0_shift;
      end
  end

wire       sbm_rd_obj0_primary;
wire       sbm_rd_obj0_priority;
wire [1:0] sbm_rd_obj0_ps;
wire [7:0] sbm_rd_obj0_pd1;
wire [7:0] sbm_rd_obj0_pd0;
wire [7:0] sbm_rd_obj0_x;
wire       sbm_rd_obj1_primary;
wire       sbm_rd_obj1_priority;
wire [1:0] sbm_rd_obj1_ps;
wire [7:0] sbm_rd_obj1_pd1;
wire [7:0] sbm_rd_obj1_pd0;
wire [7:0] sbm_rd_obj1_x;
wire       sbm_rd_obj2_primary;
wire       sbm_rd_obj2_priority;
wire [1:0] sbm_rd_obj2_ps;
wire [7:0] sbm_rd_obj2_pd1;
wire [7:0] sbm_rd_obj2_pd0;
wire [7:0] sbm_rd_obj2_x;
wire       sbm_rd_obj3_primary;
wire       sbm_rd_obj3_priority;
wire [1:0] sbm_rd_obj3_ps;
wire [7:0] sbm_rd_obj3_pd1;
wire [7:0] sbm_rd_obj3_pd0;
wire [7:0] sbm_rd_obj3_x;
wire       sbm_rd_obj4_primary;
wire       sbm_rd_obj4_priority;
wire [1:0] sbm_rd_obj4_ps;
wire [7:0] sbm_rd_obj4_pd1;
wire [7:0] sbm_rd_obj4_pd0;
wire [7:0] sbm_rd_obj4_x;
wire       sbm_rd_obj5_primary;
wire       sbm_rd_obj5_priority;
wire [1:0] sbm_rd_obj5_ps;
wire [7:0] sbm_rd_obj5_pd1;
wire [7:0] sbm_rd_obj5_pd0;
wire [7:0] sbm_rd_obj5_x;
wire       sbm_rd_obj6_primary;
wire       sbm_rd_obj6_priority;
wire [1:0] sbm_rd_obj6_ps;
wire [7:0] sbm_rd_obj6_pd1;
wire [7:0] sbm_rd_obj6_pd0;
wire [7:0] sbm_rd_obj6_x;
wire       sbm_rd_obj7_primary;
wire       sbm_rd_obj7_priority;
wire [1:0] sbm_rd_obj7_ps;
wire [7:0] sbm_rd_obj7_pd1;
wire [7:0] sbm_rd_obj7_pd0;
wire [7:0] sbm_rd_obj7_x;


assign sbm_rd_obj0_primary  = m_sbm[0] >> 27;
assign sbm_rd_obj0_priority = m_sbm[0] >> 26;
assign sbm_rd_obj0_ps       = m_sbm[0] >> 24;
assign sbm_rd_obj0_pd1      = m_sbm[0] >> 16;
assign sbm_rd_obj0_pd0      = m_sbm[0] >> 8;
assign sbm_rd_obj0_x        = m_sbm[0];
assign sbm_rd_obj1_primary  = m_sbm[1] >> 27;
assign sbm_rd_obj1_priority = m_sbm[1] >> 26;
assign sbm_rd_obj1_ps       = m_sbm[1] >> 24;
assign sbm_rd_obj1_pd1      = m_sbm[1] >> 16;
assign sbm_rd_obj1_pd0      = m_sbm[1] >> 8;
assign sbm_rd_obj1_x        = m_sbm[1];
assign sbm_rd_obj2_primary  = m_sbm[2] >> 27;
assign sbm_rd_obj2_priority = m_sbm[2] >> 26;
assign sbm_rd_obj2_ps       = m_sbm[2] >> 24;
assign sbm_rd_obj2_pd1      = m_sbm[2] >> 16;
assign sbm_rd_obj2_pd0      = m_sbm[2] >> 8;
assign sbm_rd_obj2_x        = m_sbm[2];
assign sbm_rd_obj3_primary  = m_sbm[3] >> 27;
assign sbm_rd_obj3_priority = m_sbm[3] >> 26;
assign sbm_rd_obj3_ps       = m_sbm[3] >> 24;
assign sbm_rd_obj3_pd1      = m_sbm[3] >> 16;
assign sbm_rd_obj3_pd0      = m_sbm[3] >> 8;
assign sbm_rd_obj3_x        = m_sbm[3];
assign sbm_rd_obj4_primary  = m_sbm[4] >> 27;
assign sbm_rd_obj4_priority = m_sbm[4] >> 26;
assign sbm_rd_obj4_ps       = m_sbm[4] >> 24;
assign sbm_rd_obj4_pd1      = m_sbm[4] >> 16;
assign sbm_rd_obj4_pd0      = m_sbm[4] >> 8;
assign sbm_rd_obj4_x        = m_sbm[4];
assign sbm_rd_obj5_primary  = m_sbm[5] >> 27;
assign sbm_rd_obj5_priority = m_sbm[5] >> 26;
assign sbm_rd_obj5_ps       = m_sbm[5] >> 24;
assign sbm_rd_obj5_pd1      = m_sbm[5] >> 16;
assign sbm_rd_obj5_pd0      = m_sbm[5] >> 8;
assign sbm_rd_obj5_x        = m_sbm[5];
assign sbm_rd_obj6_primary  = m_sbm[6] >> 27;
assign sbm_rd_obj6_priority = m_sbm[6] >> 26;
assign sbm_rd_obj6_ps       = m_sbm[6] >> 24;
assign sbm_rd_obj6_pd1      = m_sbm[6] >> 16;
assign sbm_rd_obj6_pd0      = m_sbm[6] >> 8;
assign sbm_rd_obj6_x        = m_sbm[6];
assign sbm_rd_obj7_primary  = m_sbm[7] >> 27;
assign sbm_rd_obj7_priority = m_sbm[7] >> 26;
assign sbm_rd_obj7_ps       = m_sbm[7] >> 24;
assign sbm_rd_obj7_pd1      = m_sbm[7] >> 16;
assign sbm_rd_obj7_pd0      = m_sbm[7] >> 8;
assign sbm_rd_obj7_x        = m_sbm[7];

always @*
  begin
    d_obj0_pd1_shift = q_obj0_pd1_shift;
    d_obj1_pd1_shift = q_obj1_pd1_shift;
    d_obj2_pd1_shift = q_obj2_pd1_shift;
    d_obj3_pd1_shift = q_obj3_pd1_shift;
    d_obj4_pd1_shift = q_obj4_pd1_shift;
    d_obj5_pd1_shift = q_obj5_pd1_shift;
    d_obj6_pd1_shift = q_obj6_pd1_shift;
    d_obj7_pd1_shift = q_obj7_pd1_shift;
    d_obj0_pd0_shift = q_obj0_pd0_shift;
    d_obj1_pd0_shift = q_obj1_pd0_shift;
    d_obj2_pd0_shift = q_obj2_pd0_shift;
    d_obj3_pd0_shift = q_obj3_pd0_shift;
    d_obj4_pd0_shift = q_obj4_pd0_shift;
    d_obj5_pd0_shift = q_obj5_pd0_shift;
    d_obj6_pd0_shift = q_obj6_pd0_shift;
    d_obj7_pd0_shift = q_obj7_pd0_shift;

    if (en_in && (nes_y_in < 239))
      begin
        if (pix_pulse_in)
          begin
            d_obj0_pd1_shift = { 1'b0, q_obj0_pd1_shift[7:1] };
            d_obj0_pd0_shift = { 1'b0, q_obj0_pd0_shift[7:1] };
          end
        else if ((nes_x_in - sbm_rd_obj0_x) == 8'h00)
          begin
            d_obj0_pd1_shift = sbm_rd_obj0_pd1;
            d_obj0_pd0_shift = sbm_rd_obj0_pd0;
          end

        if (pix_pulse_in)
          begin
            d_obj1_pd1_shift = { 1'b0, q_obj1_pd1_shift[7:1] };
            d_obj1_pd0_shift = { 1'b0, q_obj1_pd0_shift[7:1] };
          end
        else if ((nes_x_in - sbm_rd_obj1_x) == 8'h00)
          begin
            d_obj1_pd1_shift = sbm_rd_obj1_pd1;
            d_obj1_pd0_shift = sbm_rd_obj1_pd0;
          end

        if (pix_pulse_in)
          begin
            d_obj2_pd1_shift = { 1'b0, q_obj2_pd1_shift[7:1] };
            d_obj2_pd0_shift = { 1'b0, q_obj2_pd0_shift[7:1] };
          end
        else if ((nes_x_in - sbm_rd_obj2_x) == 8'h00)
          begin
            d_obj2_pd1_shift = sbm_rd_obj2_pd1;
            d_obj2_pd0_shift = sbm_rd_obj2_pd0;
          end

        if (pix_pulse_in)
          begin
            d_obj3_pd1_shift = { 1'b0, q_obj3_pd1_shift[7:1] };
            d_obj3_pd0_shift = { 1'b0, q_obj3_pd0_shift[7:1] };
          end
        else if ((nes_x_in - sbm_rd_obj3_x) == 8'h00)
          begin
            d_obj3_pd1_shift = sbm_rd_obj3_pd1;
            d_obj3_pd0_shift = sbm_rd_obj3_pd0;
          end

        if (pix_pulse_in)
          begin
            d_obj4_pd1_shift = { 1'b0, q_obj4_pd1_shift[7:1] };
            d_obj4_pd0_shift = { 1'b0, q_obj4_pd0_shift[7:1] };
          end
        else if ((nes_x_in - sbm_rd_obj4_x) == 8'h00)
          begin
            d_obj4_pd1_shift = sbm_rd_obj4_pd1;
            d_obj4_pd0_shift = sbm_rd_obj4_pd0;
          end

        if (pix_pulse_in)
          begin
            d_obj5_pd1_shift = { 1'b0, q_obj5_pd1_shift[7:1] };
            d_obj5_pd0_shift = { 1'b0, q_obj5_pd0_shift[7:1] };
          end
        else if ((nes_x_in - sbm_rd_obj5_x) == 8'h00)
          begin
            d_obj5_pd1_shift = sbm_rd_obj5_pd1;
            d_obj5_pd0_shift = sbm_rd_obj5_pd0;
          end

        if (pix_pulse_in)
          begin
            d_obj6_pd1_shift = { 1'b0, q_obj6_pd1_shift[7:1] };
            d_obj6_pd0_shift = { 1'b0, q_obj6_pd0_shift[7:1] };
          end
        else if ((nes_x_in - sbm_rd_obj6_x) == 8'h00)
          begin
            d_obj6_pd1_shift = sbm_rd_obj6_pd1;
            d_obj6_pd0_shift = sbm_rd_obj6_pd0;
          end

        if (pix_pulse_in)
          begin
            d_obj7_pd1_shift = { 1'b0, q_obj7_pd1_shift[7:1] };
            d_obj7_pd0_shift = { 1'b0, q_obj7_pd0_shift[7:1] };
          end
        else if ((nes_x_in - sbm_rd_obj7_x) == 8'h00)
          begin
            d_obj7_pd1_shift = sbm_rd_obj7_pd1;
            d_obj7_pd0_shift = sbm_rd_obj7_pd0;
          end
      end
  end

assign { primary_out, priority_out, palette_idx_out } =
  (!en_in || (ls_clip_in && (nes_x_in >= 10'h000) && (nes_x_in < 10'h008))) ?
      6'h00 :
  ({ q_obj0_pd1_shift[0], q_obj0_pd0_shift[0] } != 0) ?
      { sbm_rd_obj0_primary, sbm_rd_obj0_priority, sbm_rd_obj0_ps, q_obj0_pd1_shift[0], q_obj0_pd0_shift[0] } :
  ({ q_obj1_pd1_shift[0], q_obj1_pd0_shift[0] } != 0) ?
      { sbm_rd_obj1_primary, sbm_rd_obj1_priority, sbm_rd_obj1_ps, q_obj1_pd1_shift[0], q_obj1_pd0_shift[0] } :
  ({ q_obj2_pd1_shift[0], q_obj2_pd0_shift[0] } != 0) ?
      { sbm_rd_obj2_primary, sbm_rd_obj2_priority, sbm_rd_obj2_ps, q_obj2_pd1_shift[0], q_obj2_pd0_shift[0] } :
  ({ q_obj3_pd1_shift[0], q_obj3_pd0_shift[0] } != 0) ?
      { sbm_rd_obj3_primary, sbm_rd_obj3_priority, sbm_rd_obj3_ps, q_obj3_pd1_shift[0], q_obj3_pd0_shift[0] } :
  ({ q_obj4_pd1_shift[0], q_obj4_pd0_shift[0] } != 0) ?
      { sbm_rd_obj4_primary, sbm_rd_obj4_priority, sbm_rd_obj4_ps, q_obj4_pd1_shift[0], q_obj4_pd0_shift[0] } :
  ({ q_obj5_pd1_shift[0], q_obj5_pd0_shift[0] } != 0) ?
      { sbm_rd_obj5_primary, sbm_rd_obj5_priority, sbm_rd_obj5_ps, q_obj5_pd1_shift[0], q_obj5_pd0_shift[0] } :
  ({ q_obj6_pd1_shift[0], q_obj6_pd0_shift[0] } != 0) ?
      { sbm_rd_obj6_primary, sbm_rd_obj6_priority, sbm_rd_obj6_ps, q_obj6_pd1_shift[0], q_obj6_pd0_shift[0] } :
  ({ q_obj7_pd1_shift[0], q_obj7_pd0_shift[0] } != 0) ?
      { sbm_rd_obj7_primary, sbm_rd_obj7_priority, sbm_rd_obj7_ps, q_obj7_pd1_shift[0], q_obj7_pd0_shift[0] } : 6'b0000;

assign oam_d_out    = m_oam[oam_a_in];
assign overflow_out = q_spr_overflow;

endmodule
