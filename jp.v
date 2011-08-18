///////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name: jp
//
// Author:      Brian Bennett (brian.k.bennett@gmail.com)
// Create Date: 08/06/2011
//
// Description:
// 
// Joypad controller block for an fpga-based NES emulator.  Designed for a Spartan 3E FPGA.
//
///////////////////////////////////////////////////////////////////////////////////////////////////
module jp
(
  input  wire        clk,       // 50MHz system clock signal
  input  wire        rst,       // reset signal
  input  wire        wr,        // write enable signal
  input  wire [15:0] addr,      // 16-bit memory address
  input  wire [ 7:0] din,       // data input bus
  input  wire        jp_data1,  // joypad 1 input signal
  input  wire        jp_data2,  // joypad 2 input signal
  output wire        jp_clk,    // joypad output clk signal
  output wire        jp_latch,  // joypad output latch signal
  output reg  [ 7:0] dout       // data output bus
);

//
// FFs for tracking/reading current controller state.
//
reg [7:0] q_jp1_state, d_jp1_state;
reg [7:0] q_jp2_state, d_jp2_state;
reg       q_jp_clk,    d_jp_clk;
reg       q_jp_latch,  d_jp_latch;
reg [7:0] q_cnt,       d_cnt;

always @(posedge clk)
  begin
    if (rst)
      begin
        q_jp1_state <= 8'h00;
        q_jp2_state <= 8'h00;
        q_jp_clk    <= 1'b0;
        q_jp_latch  <= 1'b0;
        q_cnt       <= 8'h00;
      end
    else
      begin
        q_jp1_state <= d_jp1_state;
        q_jp2_state <= d_jp2_state;
        q_jp_clk    <= d_jp_clk;
        q_jp_latch  <= d_jp_latch;
        q_cnt       <= d_cnt;
      end
  end

reg [2:0] state_idx;
  
always @*
  begin
    // Default most FFs to current state.
    d_jp1_state = q_jp1_state;
    d_jp2_state = q_jp2_state;
    d_jp_clk    = q_jp_clk;
    d_jp_latch  = q_jp_latch;

    d_cnt = q_cnt + 1;

    // Drive LATCH signal to latch current controller state and return state of A button.  Pulse
    // clock 7 more times to read other 7 buttons.  Controller states are active low.
    if (q_cnt[4:0] == 5'h00)
      begin
        state_idx = q_cnt[7:5] - 3'h1;

        d_jp1_state[state_idx] = ~jp_data1;
        d_jp2_state[state_idx] = ~jp_data2;

        if (q_cnt == 8'h00)
          d_jp_latch = 1'b1;
        else
          d_jp_clk = 1'b1;
      end
    else if (q_cnt[4:0] == 5'h10)
      begin
        d_jp_clk   = 1'b0;
        d_jp_latch = 1'b0;
      end
  end

assign jp_latch = q_jp_latch;
assign jp_clk   = q_jp_clk;

localparam [15:0] JOYPAD1_MMR_ADDR = 16'h4016;
localparam [15:0] JOYPAD2_MMR_ADDR = 16'h4017;

localparam S_STROBE_WROTE_0 = 1'b0,
           S_STROBE_WROTE_1 = 1'b1;

//
// FFs for managing MMR interface for reading joypad state.
//
reg [15:0] q_addr;
reg [ 8:0] q_jp1_read_state, d_jp1_read_state;
reg [ 8:0] q_jp2_read_state, d_jp2_read_state;
reg        q_strobe_state,   d_strobe_state;

always @(posedge clk)
  begin
    if (rst)
      begin
        q_addr           <= 16'h0000;
        q_jp1_read_state <= 8'h00;
        q_jp2_read_state <= 8'h00;
        q_strobe_state   <= S_STROBE_WROTE_0;
      end
    else
      begin
        q_addr           <= addr;
        q_jp1_read_state <= d_jp1_read_state;
        q_jp2_read_state <= d_jp2_read_state;
        q_strobe_state   <= d_strobe_state;
      end
  end

always @*
  begin
    dout = 8'h00;

    // Default FFs to current state.
    d_jp1_read_state = q_jp1_read_state;
    d_jp2_read_state = q_jp2_read_state;
    d_strobe_state   = q_strobe_state;

    if (addr[15:1] == JOYPAD1_MMR_ADDR[15:1])
      begin
        dout = ((addr[0]) ? q_jp2_read_state : q_jp1_read_state) & 8'h01;

        // Only update internal state one time per read/write.
        if (addr != q_addr)
          begin
            // App must write 0x4016 to 1 then to 0 in order to reset and begin reading the joypad
            // state.
            if (wr && !addr[0])
              begin
                if ((q_strobe_state == S_STROBE_WROTE_0) && (din[0] == 1'b1))
                  begin
                    d_strobe_state = S_STROBE_WROTE_1;
                  end
                else if ((q_strobe_state == S_STROBE_WROTE_1) && (din[0] == 1'b0))
                  begin
                    d_strobe_state = S_STROBE_WROTE_0;
                    d_jp1_read_state = { q_jp1_state, 1'b0 };
                    d_jp2_read_state = { q_jp2_state, 1'b0 };
                  end
              end

            // Shift appropriate jp read state on every read.  After 8 reads, all subsequent reads
            // should be 1.
            else if (!wr && !addr[0])
              d_jp1_read_state = { 1'b1, q_jp1_read_state[8:1] };
            else if (!wr && addr[0])
              d_jp2_read_state = { 1'b1, q_jp2_read_state[8:1] };
          end
      end
  end

endmodule

