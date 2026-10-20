module gpio_top_apb(
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

  output [15:0] gpio_out,
  input  [15:0] gpio_in,
  output [7:0]  gpio_seg_0,
  output [7:0]  gpio_seg_1,
  output [7:0]  gpio_seg_2,
  output [7:0]  gpio_seg_3,
  output [7:0]  gpio_seg_4,
  output [7:0]  gpio_seg_5,
  output [7:0]  gpio_seg_6,
  output [7:0]  gpio_seg_7
);

// Explicitly disabled peripheral for the NPC integration profile.
// Deterministic APB error and benign external outputs; no device functionality.
assign in_pready = in_psel && in_penable;
assign in_prdata = 32'b0;
assign in_pslverr = 1'b1;
assign gpio_out = 16'b0;
assign gpio_seg_0 = 8'hff;
assign gpio_seg_1 = 8'hff;
assign gpio_seg_2 = 8'hff;
assign gpio_seg_3 = 8'hff;
assign gpio_seg_4 = 8'hff;
assign gpio_seg_5 = 8'hff;
assign gpio_seg_6 = 8'hff;
assign gpio_seg_7 = 8'hff;

endmodule
