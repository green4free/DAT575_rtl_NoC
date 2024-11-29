`include "router_pkg.sv"		//contains the definition of _DEBUG_
import router_pkg::*;

module rc (
	input logic [DIM_BITS-1:0] LOCAL_X, LOCAL_Y,
	input logic [DIM_BITS-1:0] dst_x, dst_y,
	
	input logic out_vc_free[NUM_PORTS][NUM_VCS],
	input logic [CREDIT_CTR_WIDTH-1:0] ovc_credits_count_r[NUM_PORTS][NUM_VCS],
	
	output logic [DIRECTION_BITS-1:0] rc_out 
);
	
	always_comb begin : rc_proc
		if (dst_x > LOCAL_X)
			rc_out = E;
		else if (dst_x < LOCAL_X)
			rc_out = W;
		else if (dst_y > LOCAL_Y)
			rc_out = S;
		else if (dst_y < LOCAL_Y)
			rc_out = N;
		else 
			rc_out = R;
	end : rc_proc
	
endmodule
