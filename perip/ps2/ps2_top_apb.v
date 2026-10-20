module ps2_top_apb(
  input         clock,
  input         reset,
  input  [31:0] in_paddr,
  input         in_psel,
  input         in_penable,
  input  [2:0]  in_pprot,
  input         in_pwrite,
  input  [31:0] in_pwdata,
  input  [3:0]  in_pstrb,
  output        in_pready,
  output [31:0] in_prdata,
  output        in_pslverr,

  input         ps2_clk,
  input         ps2_data
);

// Explicitly disabled peripheral for the NPC integration profile.
// Deterministic APB error and benign external outputs; no device functionality.
assign in_pready = in_psel && in_penable;
assign in_prdata = 32'b0;
assign in_pslverr = 1'b1;

endmodule
