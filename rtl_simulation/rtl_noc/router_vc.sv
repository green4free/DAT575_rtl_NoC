`include "router_pkg.sv"
import router_pkg::*;

module router_vc (
	input logic [DIM_BITS-1:0] LOCAL_X,
	input logic [DIM_BITS-1:0] LOCAL_Y,
	
	input logic clk, arst_n,
	
	input channel_t inport [NUM_PORTS],	//for port binding in the instantiating module, port array order is reversed
	output logic outcredit [NUM_PORTS][NUM_VCS],
	
	output channel_t outport [NUM_PORTS],
	input logic incredit [NUM_PORTS][NUM_VCS]
	);
	
	logic vc_allocated_va_ib[NUM_PORTS][NUM_VCS];
	logic [VC_ID_BITS-1:0] vc_allocated_id_va_ib[NUM_PORTS][NUM_VCS];
	logic sw_allocated_r_sa_ib[NUM_PORTS][NUM_VCS];
	dir_t reqva_ib_va [NUM_PORTS][NUM_VCS];
	dir_t reqsa_ib_sa [NUM_PORTS][NUM_VCS];
	logic unlock_vc_ib_va[NUM_PORTS][NUM_VCS];
	channel_t flit_ib_xbar[NUM_PORTS][NUM_VCS];
	channel_t flit_xbar_ob [NUM_PORTS];
	logic [CREDIT_CTR_WIDTH-1:0] credits_avail_count_r_ob_ib_rev_xbar [NUM_PORTS][NUM_VCS];
	logic [CREDIT_CTR_WIDTH-1:0] credits_count_rev_xbar_sa [NUM_PORTS][NUM_VCS];
	logic [1:0] xbar_port_sel_r_sa_xbar [NUM_PORTS];
	logic [VC_ID_BITS-1:0] xbar_vc_sel_r_sa_xbar [NUM_PORTS];
	logic [1:0] out_route_ib_rev_xbar [NUM_PORTS][NUM_VCS];
	logic [VC_ID_BITS-1:0] out_vcid_ib_rev_xbar [NUM_PORTS][NUM_VCS];
	logic op_grant_r_sa_ob [NUM_PORTS];
	logic out_vc_free_va_ib[NUM_PORTS][NUM_VCS];
	
	genvar i, v;
	generate 
	for(i=0; i<NUM_PORTS; i++) begin : router_port
		
		input_block_vc #(i) ib_i (
			.LOCAL_X(LOCAL_X), .LOCAL_Y(LOCAL_Y),
			.clk(clk), .arst_n(arst_n),
			.inflit(inport[i]),
			.vc_allocated(vc_allocated_va_ib[i]),
			.vc_allocated_id(vc_allocated_id_va_ib[i]),
			.sw_allocated_r(sw_allocated_r_sa_ib[i]),
			.out_vc_free(out_vc_free_va_ib),
			.ovc_credits_count_r(credits_avail_count_r_ob_ib_rev_xbar),
			.req_out_dir_va(reqva_ib_va[i]),
			.req_out_dir_sa(reqsa_ib_sa[i]),
			.unlock_vc(unlock_vc_ib_va[i]),
			.outflit(flit_ib_xbar[i]),
			.out_route(out_route_ib_rev_xbar[i]),
			.out_vc_id(out_vcid_ib_rev_xbar[i])
		);
		
		output_block_vc #(i) ob_i (
`ifndef SYNTHESIS
			.LOCAL_X(LOCAL_X), .LOCAL_Y(LOCAL_Y),
`endif
			.clk(clk), .arst_n(arst_n),
			.flitin(flit_xbar_ob[i]),
			.ob_en_r(op_grant_r_sa_ob[i]),
			.creditin(incredit[i]),
			.credits_avail_count_r(credits_avail_count_r_ob_ib_rev_xbar[i]),
			.flitout(outport[i])
		);
		
		for(v=0; v<NUM_VCS; v++) begin : router_vc
			assign outcredit[i][v] = sw_allocated_r_sa_ib[i][v];
		end
	end
	endgenerate
	
	
	vc_alloc va_i (
`ifndef SYNTHESIS
		.LOCAL_X(LOCAL_X), .LOCAL_Y(LOCAL_Y),
`endif
		.clk(clk), .arst_n(arst_n),
		.reqva(reqva_ib_va),
		.unlock_vc(unlock_vc_ib_va),
		.vc_allocated(vc_allocated_va_ib),
		.vc_allocated_id(vc_allocated_id_va_ib),
		.out_vc_free(out_vc_free_va_ib)
	);
	
	
	sw_alloc_vc sa_i (
`ifndef SYNTHESIS
		.LOCAL_X(LOCAL_X), .LOCAL_Y(LOCAL_Y),	
`endif
		.clk(clk), .arst_n(arst_n),
		.reqsa(reqsa_ib_sa),
		.credits_avail_count_r(credits_count_rev_xbar_sa),
		.sw_allocated_r(sw_allocated_r_sa_ib),
		.op_grant_r(op_grant_r_sa_ob),
		.xbar_port_sel_r(xbar_port_sel_r_sa_xbar),
		.xbar_vc_sel_r(xbar_vc_sel_r_sa_xbar)
	);
	
	
	crossbar_vc #(CH_BITS) xbar_i (
		.inport(flit_ib_xbar),
		.p_sel(xbar_port_sel_r_sa_xbar),
		.vc_sel(xbar_vc_sel_r_sa_xbar),
		.outport(flit_xbar_ob)
	);
	
	
	rev_xbar_vc #(CREDIT_CTR_WIDTH) rev_xbar_i (
		.inport(credits_avail_count_r_ob_ib_rev_xbar),
		.p_sel(out_route_ib_rev_xbar),
		.vc_sel(out_vcid_ib_rev_xbar),
		.outport(credits_count_rev_xbar_sa)
	);
	
	
endmodule
