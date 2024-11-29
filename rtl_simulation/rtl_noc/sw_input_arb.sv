`include "router_pkg.sv"
import router_pkg::*;

module sw_input_arb #(
	parameter dir_t LOCAL_PORT = E,
	parameter idth = (NUM_PORTS-1)*NUM_VCS
	) (
`ifndef SYNTHESIS
	input logic [DIM_BITS-1:0] LOCAL_X,
	input logic [DIM_BITS-1:0] LOCAL_Y,
`endif
	
	input logic clk, arst_n,
	input dir_t reqsa[idth],
	input [idth-1:0] grant_success,
	
	output logic [idth-1:0] sw_grant
	);
	
//	logic [idth-1:0] reqsa_i;
	logic [idth-1:0] pri;
	logic c0[idth], c1[idth];
	logic c0_feedback, c1_feedback;
	logic [idth-1:0] sw_grant_i0, sw_grant_i1;
	
	assign sw_grant = sw_grant_i0 | sw_grant_i1;
	
	always_comb begin
		c0[0] = 1'b0;
		for(int unsigned i=0; i<idth; i++) begin
			sw_grant_i0[i] = (pri[i] | c0[i]) & (reqsa[i]==LOCAL_PORT);
			if(i==idth-1)
				c0_feedback = (pri[i] | c0[i]) & ~(reqsa[i]==LOCAL_PORT);
			else
				c0[i+1] = (pri[i] | c0[i]) & ~(reqsa[i]==LOCAL_PORT);
		end
	end
	
	always_comb begin
		c1[0] = c0_feedback;
		for(int unsigned i=0; i<idth; i++) begin
			sw_grant_i1[i] = (pri[i] | c1[i]) & (reqsa[i]==LOCAL_PORT);
			if(i==idth-1)
				c1_feedback = (pri[i] | c1[i]) & ~(reqsa[i]==LOCAL_PORT);
			else
				c1[i+1] = (pri[i] | c1[i]) & ~(reqsa[i]==LOCAL_PORT);
		end
	end
	
	
	always_ff @(posedge clk or negedge arst_n) 
		if(!arst_n)
			pri <= 'd1;
		else if(|grant_success)
			pri <= {grant_success[idth-2:0], grant_success[idth-1]};
			
endmodule

/*COMMENTS


*/
