/***************************************************************************************************
** fpga_nes/hw/src/ppu/ppu_bg.v
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
*  Background/playfield PPU sub-block.
***************************************************************************************************/

module ppu_bg
(
  input  wire        clk_in,             // 100MHz system clock signal
  input  wire        rst_in,             // reset signal
  input  wire        en_in,              // enable background
  input  wire        ls_clip_in,         // clip background in left 8 pixels
  input  wire [ 2:0] fv_in,              // fine vertical scroll reg value
  input  wire [ 4:0] vt_in,              // vertical tile scroll reg value
  input  wire        v_in,               // vertical name table selection reg value
  input  wire [ 2:0] fh_in,              // fine horizontal scroll reg value
  input  wire [ 4:0] ht_in,              // horizontal tile scroll reg value
  input  wire        h_in,               // horizontal name table selection reg value
  input  wire        s_in,               // playfield pattern table selection reg value
  input  wire [ 9:0] nes_x_in,           // nes x coordinate
  input  wire [ 9:0] nes_y_in,           // nes y coordinate
  input  wire [ 9:0] nes_y_next_in,      // next line's nes y coordinate
  input  wire        pix_pulse_in,       // pulse signal one clock immediately before nes x changes
  input  wire [ 7:0] vram_d_in,          // vram data input bus
  input  wire        ri_upd_cntrs_in,    // update counters from scroll regs (after 0x2006 write)
  input  wire        ri_inc_addr_in,     // increment scroll regs for 0x2007 ri access
  input  wire        ri_inc_addr_amt_in, // amount to inc addr on ri_inc_addr_in (1 or 32 bytes)
  output reg  [13:0] vram_a_out,         // vram address bus for bg or ri 0x2007 access
  output wire [ 3:0] palette_idx_out     // background palette idx for the current pixel
);

//
// Background registers.
//
reg [ 2:0] q_fvc,           d_fvc;            // fine vertical scroll counter
reg [ 4:0] q_vtc,           d_vtc;            // vertical tile index counter
reg        q_vc,            d_vc;             // vertical name table selection counter
reg [ 4:0] q_htc,           d_htc;            // horizontal tile index counter
reg        q_hc,            d_hc;             // horizontal name table selection counter

reg [ 7:0] q_par,           d_par;            // picture address register (holds tile index)
reg [ 1:0] q_ar,            d_ar;             // tile attribute value latch (bits 3 and 2)
reg [ 7:0] q_pd0,           d_pd0;            // palette data 0 (bit 0 for tile)
reg [ 7:0] q_pd1,           d_pd1;            // palette data 1 (bit 1 for tile)

reg [ 8:0] q_bg_bit3_shift, d_bg_bit3_shift;  // shift register with per-pixel bg palette idx bit 3
reg [ 8:0] q_bg_bit2_shift, d_bg_bit2_shift;  // shift register with per-pixel bg palette idx bit 2
reg [15:0] q_bg_bit1_shift, d_bg_bit1_shift;  // shift register with per-pixel bg palette idx bit 1
reg [15:0] q_bg_bit0_shift, d_bg_bit0_shift;  // shift register with per-pixel bg palette idx bit 0

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_fvc           <=  2'h0;
        q_vtc           <=  5'h00;
        q_vc            <=  1'h0;
        q_htc           <=  5'h00;
        q_hc            <=  1'h0;
        q_par           <=  8'h00;
        q_ar            <=  2'h0;
        q_pd0           <=  8'h00;
        q_pd1           <=  8'h00;
        q_bg_bit3_shift <=  9'h000;
        q_bg_bit2_shift <=  9'h000;
        q_bg_bit1_shift <= 16'h0000;
        q_bg_bit0_shift <= 16'h0000;
      end
    else
      begin
        q_fvc           <= d_fvc;
        q_vtc           <= d_vtc;
        q_vc            <= d_vc;
        q_htc           <= d_htc;
        q_hc            <= d_hc;
        q_par           <= d_par;
        q_ar            <= d_ar;
        q_pd0           <= d_pd0;
        q_pd1           <= d_pd1;
        q_bg_bit3_shift <= d_bg_bit3_shift;
        q_bg_bit2_shift <= d_bg_bit2_shift;
        q_bg_bit1_shift <= d_bg_bit1_shift;
        q_bg_bit0_shift <= d_bg_bit0_shift;
      end
  end

//
// Scroll counter management.
//
reg upd_v_cntrs;
reg upd_h_cntrs;
reg inc_v_cntrs;
reg inc_h_cntrs;

always @*
  begin
    // Default to original values.
    d_fvc = q_fvc;
    d_vc  = q_vc;
    d_hc  = q_hc;
    d_vtc = q_vtc;
    d_htc = q_htc;

    if (ri_inc_addr_in)
      begin
        // If the VRAM address increment bit (2000.2) is clear (inc. amt. = 1), all the scroll
        // counters are daisy-chained (in the order of HT, VT, H, V, FV) so that the carry out of
        // each counter controls the next counter's clock rate. The result is that all 5 counters
        // function as a single 15-bit one. Any access to 2007 clocks the HT counter here.
        //
        // If the VRAM address increment bit is set (inc. amt. = 32), the only difference is that
        // the HT counter is no longer being clocked, and the VT counter is now being clocked by
        // access to 2007.
        if (ri_inc_addr_amt_in)
          { d_fvc, d_vc, d_hc, d_vtc } = { q_fvc, q_vc, q_hc, q_vtc } + 10'h001;
        else
          { d_fvc, d_vc, d_hc, d_vtc, d_htc } = { q_fvc, q_vc, q_hc, q_vtc, q_htc } + 15'h0001;
      end
    else
      begin
        if (inc_v_cntrs)
          begin
            // The vertical scroll counter is 9 bits, and is made up by daisy-chaining FV to VT, and
            // VT to V. FV is clocked by the PPU's horizontal blanking impulse, and therefore will
            // increment every scanline. VT operates here as a divide-by-30 counter, and will only
            // generate a carry condition when the count increments from 29 to 30 (the counter will
            // also reset). Dividing by 30 is neccessary to prevent attribute data in the name
            // tables from being used as tile index data.
            if ({ q_vtc, q_fvc } == { 5'b1_1101, 3'b111 })
              { d_vc, d_vtc, d_fvc } = { ~q_vc, 8'h00 };
            else
              { d_vc, d_vtc, d_fvc } = { q_vc, q_vtc, q_fvc } + 9'h001;
          end

        if (inc_h_cntrs)
          begin
            // The horizontal scroll counter consists of 6 bits, and is made up by daisy-chaining the
            // HT counter to the H counter. The HT counter is then clocked every 8 pixel dot clocks
            // (or every 8/3 CPU clock cycles).
            { d_hc, d_htc } = { q_hc, q_htc } + 6'h01;
          end

        // Counter loading. There are 2 conditions that update all 5 PPU scroll counters with the
        // contents of the latches adjacent to them. The first is after a write to 2006/2. The
        // second, is at the beginning of scanline 20, when the PPU starts rendering data for the
        // first time in a frame (this update won't happen if all rendering is disabled via 2001.3
        // and 2001.4).
        //
        // There is one condition that updates the H & HT counters, and that is at the end of the
        // horizontal blanking period of a scanline. Again, image rendering must be occuring for
        // this update to be effective.
        if (upd_v_cntrs || ri_upd_cntrs_in)
          begin
            d_vc  = v_in;
            d_vtc = vt_in;
            d_fvc = fv_in;
          end

        if (upd_h_cntrs || ri_upd_cntrs_in)
          begin
            d_hc  = h_in;
            d_htc = ht_in;
          end
      end
  end

//
// VRAM address derivation logic.
//
localparam [2:0] VRAM_A_SEL_RI       = 3'h0,
                 VRAM_A_SEL_NT_READ  = 3'h1,
                 VRAM_A_SEL_AT_READ  = 3'h2,
                 VRAM_A_SEL_PT0_READ = 3'h3,
                 VRAM_A_SEL_PT1_READ = 3'h4;

reg [2:0] vram_a_sel;

always @*
  begin
    case (vram_a_sel)
      VRAM_A_SEL_NT_READ:
        vram_a_out = { 2'b10, q_vc, q_hc, q_vtc, q_htc };
      VRAM_A_SEL_AT_READ:
        vram_a_out = { 2'b10, q_vc, q_hc, 4'b1111, q_vtc[4:2], q_htc[4:2] };
      VRAM_A_SEL_PT0_READ:
        vram_a_out = { 1'b0, s_in, q_par, 1'b0, q_fvc };
      VRAM_A_SEL_PT1_READ:
        vram_a_out = { 1'b0, s_in, q_par, 1'b1, q_fvc };
      default:
        vram_a_out = { q_fvc[1:0], q_vc, q_hc, q_vtc, q_htc };
    endcase
  end

//
// Background palette index derivation logic.
//
wire clip;

always @*
  begin
    // Default to original value.
    d_par           = q_par;
    d_ar            = q_ar;
    d_pd0           = q_pd0;
    d_pd1           = q_pd1;
    d_bg_bit3_shift = q_bg_bit3_shift;
    d_bg_bit2_shift = q_bg_bit2_shift;
    d_bg_bit1_shift = q_bg_bit1_shift;
    d_bg_bit0_shift = q_bg_bit0_shift;

    upd_v_cntrs = 1'b0;
    inc_v_cntrs = 1'b0;
    upd_h_cntrs = 1'b0;
    inc_h_cntrs = 1'b0;

    vram_a_sel = VRAM_A_SEL_RI;

    if (en_in && ((nes_y_in < 239) || (nes_y_next_in == 0)))
      begin
        if (pix_pulse_in && (nes_x_in == 319))
          begin
            upd_h_cntrs = 1'b1;

            if (nes_y_next_in != nes_y_in)
              begin
                if (nes_y_next_in == 0)
                  upd_v_cntrs = 1'b1;
                else
                  inc_v_cntrs = 1'b1;
              end
          end

        if ((nes_x_in < 256) || ((nes_x_in >= 320 && nes_x_in < 336)))
          begin
            if (pix_pulse_in)
              begin
                d_bg_bit3_shift = { q_bg_bit3_shift[8], q_bg_bit3_shift[8:1] };
                d_bg_bit2_shift = { q_bg_bit2_shift[8], q_bg_bit2_shift[8:1] };
                d_bg_bit1_shift = { 1'b0, q_bg_bit1_shift[15:1] };
                d_bg_bit0_shift = { 1'b0, q_bg_bit0_shift[15:1] };
              end

            if (pix_pulse_in && (nes_x_in[2:0] == 3'h7))
              begin
                inc_h_cntrs         = 1'b1;

                d_bg_bit3_shift[8]  = q_ar[1];
                d_bg_bit2_shift[8]  = q_ar[0];

                d_bg_bit1_shift[15] = q_pd1[0];
                d_bg_bit1_shift[14] = q_pd1[1];
                d_bg_bit1_shift[13] = q_pd1[2];
                d_bg_bit1_shift[12] = q_pd1[3];
                d_bg_bit1_shift[11] = q_pd1[4];
                d_bg_bit1_shift[10] = q_pd1[5];
                d_bg_bit1_shift[ 9] = q_pd1[6];
                d_bg_bit1_shift[ 8] = q_pd1[7];

                d_bg_bit0_shift[15] = q_pd0[0];
                d_bg_bit0_shift[14] = q_pd0[1];
                d_bg_bit0_shift[13] = q_pd0[2];
                d_bg_bit0_shift[12] = q_pd0[3];
                d_bg_bit0_shift[11] = q_pd0[4];
                d_bg_bit0_shift[10] = q_pd0[5];
                d_bg_bit0_shift[ 9] = q_pd0[6];
                d_bg_bit0_shift[ 8] = q_pd0[7];
              end

            case (nes_x_in[2:0])
              3'b000:
                begin
                  vram_a_sel = VRAM_A_SEL_NT_READ;
                  d_par      = vram_d_in;
                end
              3'b001:
                begin
                  vram_a_sel = VRAM_A_SEL_AT_READ;
                  d_ar       = vram_d_in >> { q_vtc[1], q_htc[1], 1'b0 };
                end
              3'b010:
                begin
                  vram_a_sel = VRAM_A_SEL_PT0_READ;
                  d_pd0      = vram_d_in;
                end
              3'b011:
                begin
                  vram_a_sel = VRAM_A_SEL_PT1_READ;
                  d_pd1      = vram_d_in;
                end
            endcase
          end
      end
  end

assign clip            = ls_clip_in && (nes_x_in >= 10'h000) && (nes_x_in < 10'h008);
assign palette_idx_out = (!clip && en_in) ? { q_bg_bit3_shift[fh_in],
                                              q_bg_bit2_shift[fh_in],
                                              q_bg_bit1_shift[fh_in],
                                              q_bg_bit0_shift[fh_in] } : 4'h0;

endmodule
