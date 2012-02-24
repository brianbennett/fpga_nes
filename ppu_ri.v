///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: ppu_ri
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 02/14/2012
//
// Description:
//
// External register interface sub-block of the PPU for an fpga-based NES emulator.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module ppu_ri
(
  input  wire       clk_in,            // 50MHz system clock signal
  input  wire       rst_in,            // reset signal
  input  wire [2:0] sel_in,            // register interface reg select
  input  wire       ncs_in,            // register interface enable (active low)
  input  wire       r_nw_in,           // register interface read/write select
  input  wire [7:0] cpu_d_in,          // register interface data in from cpu
  input  wire [7:0] vram_d_in,         // data in from vram
  input  wire       vblank_in,         // high during vertical blank
  input  wire [7:0] spr_ram_d_in,      // sprite ram data (for 0x2004 reads)
  input  wire       spr_overflow_in,   // more than 8 sprites hit on a scanline during last frame
  input  wire       spr_pri_col_in,    // primary object collision in last frame
  output wire [7:0] cpu_d_out,         // register interface data out to cpu
  output reg  [7:0] vram_d_out,        // data out to vram
  output reg        vram_wr_out,       // rd/wr select for vram ops
  output wire [2:0] fv_out,            // fine vertical scroll register
  output wire [4:0] vt_out,            // vertical tile scroll register
  output wire       v_out,             // vertical name table selection register
  output wire [2:0] fh_out,            // fine horizontal scroll register
  output wire [4:0] ht_out,            // horizontal tile scroll register
  output wire       h_out,             // horizontal name table selection register
  output wire       s_out,             // playfield pattern table selection register
  output reg        inc_addr_out,      // increment vmem addr (due to ri mem access)
  output wire       inc_addr_amt_out,  // amount to increment vmem addr by (0x2002.7)
  output wire       nvbl_en_out,       // enable nmi on vertical blank
  output wire       bg_en_out,         // enable background rendering
  output wire       spr_en_out,        // enable sprite rendering
  output wire       spr_h_out,         // 8/16 scanline sprites
  output wire       spr_pt_sel_out,    // pattern table select for sprites (0x2000.3)
  output wire       upd_cntrs_out,     // copy PPU registers to PPU counters
  output wire [7:0] spr_ram_a_out,     // sprite ram address (for 0x2004 reads/writes)
  output reg  [7:0] spr_ram_d_out,     // sprite ram data (for 0x2004 writes)
  output reg        spr_ram_wr_out     // sprite ram write enable (for 0x2004 writes)
);

//
// Scroll Registers
//
reg [2:0] q_fv,  d_fv;   // fine vertical scroll latch
reg [4:0] q_vt,  d_vt;   // vertical tile index latch
reg       q_v,   d_v;    // vertical name table selection latch
reg [2:0] q_fh,  d_fh;   // fine horizontal scroll latch
reg [4:0] q_ht,  d_ht;   // horizontal tile index latch
reg       q_h,   d_h;    // horizontal name table selection latch
reg       q_s,   d_s;    // playfield pattern table selection latch

//
// Output Latches
//
reg [7:0] q_cpu_d_out,     d_cpu_d_out;      // output data bus latch for 0x2007 reads
reg       q_upd_cntrs_out, d_upd_cntrs_out;  // output latch for upd_cntrs_out

//
// External State Registers
//
reg q_nvbl_en,    d_nvbl_en;     // 0x2000[7]: enables an NMI interrupt on vblank
reg q_spr_h,      d_spr_h;       // 0x2000[5]: select 8/16 scanline high sprites
reg q_spr_pt_sel, d_spr_pt_sel;  // 0x2000[3]: sprite pattern table select
reg q_addr_incr,  d_addr_incr;   // 0x2000[2]: amount to increment addr on 0x2007 access.
                                 //            0: 1 byte, 1: 32 bytes.
reg q_spr_en,     d_spr_en;      // 0x2001[4]: enables sprite rendering
reg q_bg_en,      d_bg_en;       // 0x2001[3]: enables background rendering
reg q_vblank,     d_vblank;      // 0x2002[7]: indicates a vblank is occurring

//
// Internal State Registers
//
reg       q_byte_sel,  d_byte_sel;   // tracks if next 0x2005/0x2006 write is high or low byte
reg [7:0] q_rd_buf,    d_rd_buf;     // internal latch for buffered 0x2007 reads
reg       q_rd_rdy,    d_rd_rdy;     // controls q_rd_buf updates
reg [7:0] q_spr_ram_a, d_spr_ram_a;  // sprite ram pointer (set on 0x2003 write)
reg       q_ncs;                     // last ncs signal (to detect falling edges)

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        q_fv            <= 2'h0;
        q_vt            <= 5'h00;
        q_v             <= 1'h0;
        q_fh            <= 3'h0;
        q_ht            <= 5'h00;
        q_h             <= 1'h0;
        q_s             <= 1'h0;
        q_cpu_d_out     <= 8'h00;
        q_upd_cntrs_out <= 1'h0;
        q_nvbl_en       <= 1'h0;
        q_spr_h         <= 1'h0;
        q_spr_pt_sel    <= 1'h0;
        q_addr_incr     <= 1'h0;
        q_spr_en        <= 1'h0;
        q_bg_en         <= 1'h0;
        q_vblank        <= 1'h0;
        q_byte_sel      <= 1'h0;
        q_rd_buf        <= 8'h00;
        q_rd_rdy        <= 1'h0;
        q_spr_ram_a     <= 8'h00;
        q_ncs           <= 1'h1;
      end
    else
      begin
        q_fv            <= d_fv;
        q_vt            <= d_vt;
        q_v             <= d_v;
        q_fh            <= d_fh;
        q_ht            <= d_ht;
        q_h             <= d_h;
        q_s             <= d_s;
        q_cpu_d_out     <= d_cpu_d_out;
        q_upd_cntrs_out <= d_upd_cntrs_out;
        q_nvbl_en       <= d_nvbl_en;
        q_spr_h         <= d_spr_h;
        q_spr_pt_sel    <= d_spr_pt_sel;
        q_addr_incr     <= d_addr_incr;
        q_spr_en        <= d_spr_en;
        q_bg_en         <= d_bg_en;
        q_vblank        <= d_vblank;
        q_byte_sel      <= d_byte_sel;
        q_rd_buf        <= d_rd_buf;
        q_rd_rdy        <= d_rd_rdy;
        q_spr_ram_a     <= d_spr_ram_a;
        q_ncs           <= ncs_in;
      end
  end

always @*
  begin
    // Default most state to its original value.
    d_fv         = q_fv;
    d_vt         = q_vt;
    d_v          = q_v;
    d_fh         = q_fh;
    d_ht         = q_ht;
    d_h          = q_h;
    d_s          = q_s;
    d_cpu_d_out  = q_cpu_d_out;
    d_nvbl_en    = q_nvbl_en;
    d_spr_h      = q_spr_h;
    d_spr_pt_sel = q_spr_pt_sel;
    d_addr_incr  = q_addr_incr;
    d_spr_en     = q_spr_en;
    d_bg_en      = q_bg_en;
    d_byte_sel   = q_byte_sel;
    d_spr_ram_a  = q_spr_ram_a;

    // Update the read buffer if a new read request is ready.  This happens one cycle after a read
    // of 0x2007.
    d_rd_buf = (q_rd_rdy) ? vram_d_in : q_rd_buf;
    d_rd_rdy = 1'b0;

    // Request a PPU counter update only after second write to 0x2006.
    d_upd_cntrs_out = 1'b0;

    // Set the vblank status bit on a rising vblank edge.  Clear it if vblank is false.  Can also
    // be cleared by reading 0x2002.
    d_vblank = (vblank_in & ~q_vblank) ? 1'b1 :
               (~vblank_in)            ? 1'b0 : q_vblank;

    // Only request VRAM write on write of 0x2007.
    vram_wr_out = 1'b0;
    vram_d_out  = 8'h00;

    // Only request VRAM addr increment on access of 0x2007.
    inc_addr_out = 1'b0;

    spr_ram_d_out  = 8'h00;
    spr_ram_wr_out = 1'b0;

    // Only evaluate RI reads/writes on /CS falling edges.  This prevents executing the same
    // command multiple times because the CPU runs at a slower clock rate than the PPU.
    if (q_ncs & ~ncs_in)
      begin
        if (r_nw_in)
          begin
            // External register read.
            case (sel_in)
              3'h2:  // 0x2002
                begin
                  d_cpu_d_out = { q_vblank, spr_pri_col_in, spr_overflow_in, 5'b00000 };
                  d_byte_sel  = 1'b0;
                  d_vblank    = 1'b0;
                end
              3'h4:  // 0x2004
                begin
                  d_cpu_d_out = spr_ram_d_in;
                end
              3'h7:  // 0x2007
                begin
                  d_cpu_d_out  = q_rd_buf;
                  d_rd_rdy     = 1'b1;
                  inc_addr_out = 1'b1;
                end
            endcase
          end
        else
          begin
            // External register write.
            case (sel_in)
              3'h0:  // 0x2000
                begin
                  d_nvbl_en    = cpu_d_in[7];
                  d_spr_h      = cpu_d_in[5];
                  d_s          = cpu_d_in[4];
                  d_spr_pt_sel = cpu_d_in[3];
                  d_addr_incr  = cpu_d_in[2];
                  d_v          = cpu_d_in[1];
                  d_h          = cpu_d_in[0];
                end
              3'h1:  // 0x2001
                begin
                  d_spr_en = cpu_d_in[4];
                  d_bg_en  = cpu_d_in[3];
                end
              3'h3:  // 0x2003
                begin
                  d_spr_ram_a = cpu_d_in;
                end
              3'h4:  // 0x2004
                begin
                  spr_ram_d_out  = cpu_d_in;
                  spr_ram_wr_out = 1'b1;
                  d_spr_ram_a    = q_spr_ram_a + 8'h01;
                end
              3'h5:  // 0x2005
                begin
                  d_byte_sel = ~q_byte_sel;
                  if (~q_byte_sel)
                    begin
                      // First write.
                      d_fh = cpu_d_in[2:0];
                      d_ht = cpu_d_in[7:3];
                    end
                  else
                    begin
                      // Second write.
                      d_fv = cpu_d_in[2:0];
                      d_vt = cpu_d_in[7:3];
                    end
                end
              3'h6:  // 0x2006
                begin
                  d_byte_sel = ~q_byte_sel;
                  if (~q_byte_sel)
                    begin
                      // First write.
                      d_fv      = { 1'b0, cpu_d_in[5:4] };
                      d_v       = cpu_d_in[3];
                      d_h       = cpu_d_in[2];
                      d_vt[4:3] = cpu_d_in[1:0];
                    end
                  else
                    begin
                      // Second write.
                      d_vt[2:0]       = cpu_d_in[7:5];
                      d_ht            = cpu_d_in[4:0];
                      d_upd_cntrs_out = 1'b1;
                    end
                end
              3'h7:  // 0x2007
                begin
                  vram_wr_out  = 1'b1;
                  vram_d_out   = cpu_d_in;
                  inc_addr_out = 1'b1;
                end
            endcase
          end
      end
  end

assign cpu_d_out        = (~ncs_in & r_nw_in) ? q_cpu_d_out : 8'h00;
assign fv_out           = q_fv;
assign vt_out           = q_vt;
assign v_out            = q_v;
assign fh_out           = q_fh;
assign ht_out           = q_ht;
assign h_out            = q_h;
assign s_out            = q_s;
assign inc_addr_amt_out = q_addr_incr;
assign nvbl_en_out      = q_nvbl_en;
assign bg_en_out        = q_bg_en;
assign spr_en_out       = q_spr_en;
assign spr_h_out        = q_spr_h;
assign spr_pt_sel_out   = q_spr_pt_sel;
assign upd_cntrs_out    = q_upd_cntrs_out;
assign spr_ram_a_out    = q_spr_ram_a;

endmodule
