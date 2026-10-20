// NPC integration profile, SoC-side guard before AXI4Xbar (not part of CPU).
// One service slot; independent AW/W capture; register-buffered errors/responses.
// Enabled: SRAM, read-only MROM, byte UART, word SPI registers.
// Disabled: Flash XIP/PSRAM until S4, GPIO/PS2/VGA/SDRAM for this milestone.
// This module is explicitly single-beat; retain the shared-reset requirement.
module npc_axi4_guard (
    input clock,
    input reset,
    input [3:0] in_arid, in_awid,
    input [7:0] in_arlen, in_awlen,
    input [1:0] in_arburst, in_awburst,
    input in_wlast,
    output [3:0] out_arid, out_awid,
    output [7:0] out_arlen, out_awlen,
    output [1:0] out_arburst, out_awburst,
    output out_wlast,
    input in_arvalid,
    output in_arready,
    input [31:0] in_araddr,
    input [2:0] in_arsize,
    output in_rvalid,
    input in_rready,
    output [31:0] in_rdata,
    output [1:0] in_rresp,
    output [3:0] in_rid,
    output in_rlast,
    input in_awvalid,
    output in_awready,
    input [31:0] in_awaddr,
    input [2:0] in_awsize,
    input in_wvalid,
    output in_wready,
    input [31:0] in_wdata,
    input [3:0] in_wstrb,
    output in_bvalid,
    input in_bready,
    output [1:0] in_bresp,
    output [3:0] in_bid,
    output out_arvalid,
    input out_arready,
    output [31:0] out_araddr,
    output [2:0] out_arsize,
    input out_rvalid,
    output out_rready,
    input [31:0] out_rdata,
    input [1:0] out_rresp,
    input [3:0] out_rid,
    input out_rlast,
    output out_awvalid,
    input out_awready,
    output [31:0] out_awaddr,
    output [2:0] out_awsize,
    output out_wvalid,
    input out_wready,
    output [31:0] out_wdata,
    output [3:0] out_wstrb,
    input out_bvalid,
    output out_bready,
    input [1:0] out_bresp,
    input [3:0] out_bid
);
wire reset_n = !reset;
typedef enum logic [3:0] {IDLE, COLLECT_W, DISPATCH_R, DISPATCH_W,
                        SEND_R, WAIT_R, SEND_W, WAIT_B, RESP_R, RESP_B} state_t;
state_t state_q;
reg [31:0] addr_q, data_q, rdata_q;
reg [2:0] size_q;
reg [3:0] strb_q, id_q, request_id_q;
reg wlast_q;
reg [1:0] burst_q;
reg [1:0] resp_q;
reg last_q, aw_have_q, w_have_q, aw_sent_q, w_sent_q;
// Decode full byte addresses before the upstream optimized crossbars can alias
// an unmapped address onto a device. Check the final byte as well as the first.
wire [32:0] last_addr = {1'b0, addr_q} + ((33'd1 << size_q) - 1);
wire sram = addr_q >= 32'h0f000000 && last_addr < 33'h00f002000;
wire mrom = addr_q >= 32'h20000000 && last_addr < 33'h020001000;
wire uart = addr_q >= 32'h10000000 && last_addr < 33'h010001000;
wire spi = addr_q >= 32'h10001000 && last_addr < 33'h010002000;
wire disabled = (addr_q >= 32'h10002000 && addr_q < 32'h10002010) ||
                (addr_q >= 32'h10011000 && addr_q < 32'h10011008) ||
                (addr_q >= 32'h21000000 && addr_q < 32'h21200000) ||
                (addr_q >= 32'h30000000 && addr_q < 32'h40000000) ||
                (addr_q >= 32'h80000000 && addr_q < 32'h80400000) ||
                (addr_q >= 32'ha0000000 && addr_q < 32'ha2000000);
wire writing = state_q == DISPATCH_W;
wire aligned = size_q == 0 || (size_q == 1 && !addr_q[0]) ||
               (size_q == 2 && addr_q[1:0] == 0);
wire [7:0] byte_mask = ((8'd1 << (4'd1 << size_q)) - 1) << addr_q[1:0];
wire shape_ok = aligned && (burst_q == 0 || burst_q == 1) &&
                (!writing || (wlast_q && (strb_q & ~byte_mask[3:0]) == 0));
// UART ignores PSTRB and uses byte register addresses. SPI has word registers.
// Reject unsupported device widths/masks before they can produce side effects.
wire device_ok = (!uart || (size_q == 0 && (!writing || strb_q == byte_mask[3:0]))) &&
                 (!spi || (size_q == 2 && (!writing || strb_q == 4'hf)));
wire mapped = sram || mrom || uart || spi;
wire reject = !mapped || !shape_ok || !device_ok || (mrom && writing);
wire [1:0] reject_resp = (!mapped && !disabled) ? 2'b11 : 2'b10;
wire ar_fire = in_arvalid && in_arready;
wire aw_fire = in_awvalid && in_awready;
wire w_fire = in_wvalid && in_wready;
assign out_arid = request_id_q;
assign out_awid = request_id_q;
assign out_arlen = 0;
assign out_awlen = 0;
assign out_arburst = burst_q;
assign out_awburst = burst_q;
assign out_wlast = 1'b1;
// IDLE observes which transaction is being offered, then reserves a channel.
// A read can be accepted directly; write ready is raised only in COLLECT_W.
assign in_arready = reset_n && state_q == IDLE;
assign in_awready = reset_n && state_q == COLLECT_W && !aw_have_q;
assign in_wready = reset_n && state_q == COLLECT_W && !w_have_q;
assign in_rvalid = reset_n && state_q == RESP_R;
assign in_rdata = rdata_q;
assign in_rresp = resp_q;
assign in_rid = id_q;
assign in_rlast = last_q;
assign in_bvalid = reset_n && state_q == RESP_B;
assign in_bresp = resp_q;
assign in_bid = id_q;
assign out_arvalid = reset_n && state_q == SEND_R;
assign out_araddr = addr_q;
assign out_arsize = size_q;
assign out_rready = reset_n && state_q == WAIT_R;
assign out_awvalid = reset_n && state_q == SEND_W && !aw_sent_q;
assign out_awaddr = addr_q;
assign out_awsize = size_q;
assign out_wvalid = reset_n && state_q == SEND_W && !w_sent_q;
assign out_wdata = data_q;
assign out_wstrb = strb_q;
assign out_bready = reset_n && state_q == WAIT_B;
always @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
        state_q <= IDLE;
        addr_q <= 0; data_q <= 0; rdata_q <= 0;
        size_q <= 0; strb_q <= 0; id_q <= 0; resp_q <= 0; request_id_q <= 0; burst_q <= 0; wlast_q <= 0;
        last_q <= 1; aw_have_q <= 0; w_have_q <= 0; aw_sent_q <= 0; w_sent_q <= 0;
    end else case (state_q)
        IDLE: begin
            if (ar_fire) begin
                addr_q <= in_araddr; size_q <= in_arsize;
                request_id_q <= in_arid; burst_q <= in_arburst;
                state_q <= DISPATCH_R;
            end else if (in_awvalid || in_wvalid) state_q <= COLLECT_W;
        end
        COLLECT_W: begin
            if (aw_fire) begin
                addr_q <= in_awaddr; size_q <= in_awsize;
                request_id_q <= in_awid; burst_q <= in_awburst;
                aw_have_q <= 1;
            end
            if (w_fire) begin
                data_q <= in_wdata; strb_q <= in_wstrb; wlast_q <= in_wlast; w_have_q <= 1;
            end
            if ((aw_have_q || aw_fire) && (w_have_q || w_fire)) state_q <= DISPATCH_W;
        end
        DISPATCH_R: begin
            if (reject) begin
                rdata_q <= 0; resp_q <= reject_resp;
                id_q <= request_id_q; last_q <= 1; state_q <= RESP_R;
            end else state_q <= SEND_R;
        end
        DISPATCH_W: begin
            if (reject) begin
                resp_q <= reject_resp; id_q <= request_id_q; state_q <= RESP_B;
            end else state_q <= SEND_W;
        end
        SEND_R: if (out_arready) state_q <= WAIT_R;
        WAIT_R: if (out_rvalid) begin
            rdata_q <= out_rdata; resp_q <= out_rresp;
            id_q <= out_rid; last_q <= out_rlast; state_q <= RESP_R;
        end
        SEND_W: begin
            if (out_awvalid && out_awready) aw_sent_q <= 1;
            if (out_wvalid && out_wready) w_sent_q <= 1;
            if ((aw_sent_q || out_awready) && (w_sent_q || out_wready)) state_q <= WAIT_B;
        end
        WAIT_B: if (out_bvalid) begin
            resp_q <= out_bresp; id_q <= out_bid; state_q <= RESP_B;
        end
        RESP_R, RESP_B: if ((in_rvalid && in_rready) || (in_bvalid && in_bready)) begin
            aw_have_q <= 0; w_have_q <= 0; aw_sent_q <= 0; w_sent_q <= 0;
            state_q <= IDLE;
        end
        default: state_q <= IDLE;
    endcase
end
`ifndef SYNTHESIS
// The single-outstanding upstream contract is guaranteed by the arbiter.
a_no_read_write_overlap: assert property (@(posedge clock) disable iff (!reset_n)
    !(in_arvalid && (in_awvalid || in_wvalid)));
// S2 supports single-beat requests only. Multi-beat draining/fragmentation is
// deliberately not claimed; M6 must extend this contract before burst refill.
a_single_read: assert property (@(posedge clock) disable iff (!reset_n)
    in_arvalid |-> in_arlen == 0);
a_single_write: assert property (@(posedge clock) disable iff (!reset_n)
    in_awvalid |-> in_awlen == 0);
a_r_expected: assert property (@(posedge clock) disable iff (!reset_n)
    out_rvalid |-> state_q == WAIT_R || state_q == SEND_R);
a_b_expected: assert property (@(posedge clock) disable iff (!reset_n)
    out_bvalid |-> state_q == WAIT_B || state_q == SEND_W);
a_ar_hold: assert property (@(posedge clock) disable iff (!reset_n)
    out_arvalid && !out_arready |=> out_arvalid && $stable({out_araddr,out_arsize,out_arid,out_arlen,out_arburst}));
a_aw_hold: assert property (@(posedge clock) disable iff (!reset_n)
    out_awvalid && !out_awready |=> out_awvalid && $stable({out_awaddr,out_awsize,out_awid,out_awlen,out_awburst}));
a_w_hold: assert property (@(posedge clock) disable iff (!reset_n)
    out_wvalid && !out_wready |=> out_wvalid && $stable({out_wdata,out_wstrb,out_wlast}));
a_r_hold: assert property (@(posedge clock) disable iff (!reset_n)
    in_rvalid && !in_rready |=> in_rvalid && $stable({in_rdata,in_rresp,in_rid,in_rlast}));
a_b_hold: assert property (@(posedge clock) disable iff (!reset_n)
    in_bvalid && !in_bready |=> in_bvalid && $stable({in_bresp,in_bid}));
`endif
endmodule
