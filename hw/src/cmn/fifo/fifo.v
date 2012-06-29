/***************************************************************************************************
** fpga_nes/hw/src/cmn/fifo/fifo.v
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
*  Circular first in first out buffer implementation.
***************************************************************************************************/

module fifo
#(
  parameter DATA_BITS = 8,
  parameter ADDR_BITS = 3
)
(
  input  wire                 clk,      // 50MHz system clock
  input  wire                 reset,    // Reset signal
  input  wire                 rd_en,    // Read enable, pop front of queue
  input  wire                 wr_en,    // Write enable, add wr_data to end of queue
  input  wire [DATA_BITS-1:0] wr_data,  // Data to be written on wr_en
  output wire [DATA_BITS-1:0] rd_data,  // Current front of fifo data
  output wire                 full,     // FIFO is full (writes invalid)
  output wire                 empty     // FIFO is empty (reads invalid)
);

reg  [ADDR_BITS-1:0] q_rd_ptr;
wire [ADDR_BITS-1:0] d_rd_ptr;
reg  [ADDR_BITS-1:0] q_wr_ptr;
wire [ADDR_BITS-1:0] d_wr_ptr;
reg                  q_empty;
wire                 d_empty;
reg                  q_full;
wire                 d_full;

reg  [DATA_BITS-1:0] q_data_array [2**ADDR_BITS-1:0];
wire [DATA_BITS-1:0] d_data;

wire rd_en_prot;
wire wr_en_prot;

// FF update logic.  Synchronous reset.
always @(posedge clk)
  begin
    if (reset)
      begin
        q_rd_ptr <= 0;
        q_wr_ptr <= 0;
        q_empty  <= 1'b1;
        q_full   <= 1'b0;
      end
    else
      begin
        q_rd_ptr               <= d_rd_ptr;
        q_wr_ptr               <= d_wr_ptr;
        q_empty                <= d_empty;
        q_full                 <= d_full;
        q_data_array[q_wr_ptr] <= d_data;
      end
  end

// Derive "protected" read/write signals.
assign rd_en_prot = (rd_en && !q_empty);
assign wr_en_prot = (wr_en && !q_full);

// Handle writes.
assign d_wr_ptr = (wr_en_prot)  ? q_wr_ptr + 1'h1 : q_wr_ptr;
assign d_data   = (wr_en_prot)  ? wr_data         : q_data_array[q_wr_ptr];

// Handle reads.
assign d_rd_ptr = (rd_en_prot)  ? q_rd_ptr + 1'h1 : q_rd_ptr;

wire [ADDR_BITS-1:0] addr_bits_wide_1;
assign addr_bits_wide_1 = 1;

// Detect empty state:
//   1) We were empty before and there was no write.
//   2) We had one entry and there was a read.
assign d_empty = ((q_empty && !wr_en_prot) ||
                  (((q_wr_ptr - q_rd_ptr) == addr_bits_wide_1) && rd_en_prot));

// Detect full state:
//   1) We were full before and there was no read.
//   2) We had n-1 entries and there was a write.
assign d_full  = ((q_full && !rd_en_prot) ||
                  (((q_rd_ptr - q_wr_ptr) == addr_bits_wide_1) && wr_en_prot));

// Assign output signals to appropriate FFs.
assign rd_data = q_data_array[q_rd_ptr];
assign full    = q_full;
assign empty   = q_empty;

endmodule

