/***************************************************************************************************
** fpga_nes/hw/src/cmn/block_ram/block_ram.v
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
*  Various generic, inferred block ram descriptors.
***************************************************************************************************/

// Dual port RAM with synchronous read.  Modified version of listing 12.4 in "FPGA Prototyping by
// Verilog Examples," itself a modified version of XST 8.11 v_rams_11.
module dual_port_ram_sync
#(
  parameter ADDR_WIDTH = 6,
  parameter DATA_WIDTH = 8
)
(
  input  wire                  clk,
  input  wire                  we,
  input  wire [ADDR_WIDTH-1:0] addr_a,
  input  wire [ADDR_WIDTH-1:0] addr_b,
  input  wire [DATA_WIDTH-1:0] din_a,
  output wire [DATA_WIDTH-1:0] dout_a,
  output wire [DATA_WIDTH-1:0] dout_b
);

reg [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0];
reg [ADDR_WIDTH-1:0] q_addr_a;
reg [ADDR_WIDTH-1:0] q_addr_b;

always @(posedge clk)
  begin
    if (we)
        ram[addr_a] <= din_a;
    q_addr_a <= addr_a;
    q_addr_b <= addr_b;
  end

assign dout_a = ram[q_addr_a];
assign dout_b = ram[q_addr_b];

endmodule

// Single port RAM with synchronous read.
module single_port_ram_sync
#(
  parameter ADDR_WIDTH = 6,
  parameter DATA_WIDTH = 8
)
(
  input  wire                  clk,
  input  wire                  we,
  input  wire [ADDR_WIDTH-1:0] addr_a,
  input  wire [DATA_WIDTH-1:0] din_a,
  output wire [DATA_WIDTH-1:0] dout_a
);

reg [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0];
reg [ADDR_WIDTH-1:0] q_addr_a;

always @(posedge clk)
  begin
    if (we)
        ram[addr_a] <= din_a;
    q_addr_a <= addr_a;
  end

assign dout_a = ram[q_addr_a];

endmodule

