`include "router_pkg.sv"
import router_pkg::*;

module vc_output_arb #(
	parameter dir_t LOCAL_PORT = E,	//local output port
	parameter logic [VC_ID_BITS-1:0] LOCAL_VC =  0
	) (
`ifndef SYNTHESIS
	input logic [DIM_BITS-1:0] LOCAL_X,
	input logic [DIM_BITS-1:0] LOCAL_Y,
`endif

	input logic vc_granted[NUM_VCS], 
	
	output logic out_vc_selected [NUM_VCS]
	);
	
	logic [NUM_VCS:2] c;

	always_comb begin 
		for(int unsigned vc=0; vc<NUM_VCS; vc++) begin
			if(vc==0)
				out_vc_selected[0] = vc_granted[0];
			else if(vc==1) begin
				out_vc_selected[vc] = ~vc_granted[0] & vc_granted[1];
				c[2] = vc_granted[0] | vc_granted[1];
			end 
			else begin
				out_vc_selected[vc] = ~c[vc] & vc_granted[vc];
				c[vc+1] = c[vc] | vc_granted[vc];
			end
		end
	end
	 
	
endmodule

/*COMMENTS
1. verify out_vc_selected in systhesis because of questasim warning

*/