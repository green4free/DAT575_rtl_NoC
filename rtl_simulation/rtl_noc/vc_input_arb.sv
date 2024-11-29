/*
This is a part of input fiarst_n VC allocator. this performs input port arbitration. 
must have atleast 2 VCs, otherwise the vc_allocator is not required
*/
`include "router_pkg.sv"
import router_pkg::*;

module vc_input_arb #(
	parameter dir_t LOCAL_PORT = E,	//local output port
	parameter logic [VC_ID_BITS-1:0] LOCAL_VC =  0
	) (
`ifndef SYNTHESIS
	input logic [DIM_BITS-1:0] LOCAL_X,
	input logic [DIM_BITS-1:0] LOCAL_Y,
	output logic req_msk,
`endif

	input logic clk, arst_n,
	input dir_t reqva[NUM_PORTS-1][NUM_VCS],
	input logic vc_unlock[NUM_PORTS-1][NUM_VCS],
	input logic grant_success[NUM_PORTS-1][NUM_VCS],
	
	output logic vc_grant[NUM_PORTS-1][NUM_VCS]
	);

`ifdef SYNTHESIS	
	logic req_msk;
`endif
	logic reqvc_i [NUM_PORTS-1][NUM_VCS];
	logic pri [NUM_PORTS-1][NUM_VCS];
	logic vc_grant0[NUM_PORTS-1][NUM_VCS];
	logic vc_grant1[NUM_PORTS-1][NUM_VCS];
	logic lock, unlock;
	
	always_comb begin
		lock = 1'b0;
		for(int unsigned p=0; p<NUM_PORTS-1; p++)
				for(int unsigned v=0; v<NUM_VCS; v++) 
					lock |= (grant_success[p][v] & vc_grant[p][v]);
		
		
		/*if(lock===1'bx && !arst_n) begin
			$display($time(), " a ERROR INPUT_ARB(%1d,%1d,%1d,%1d)- LOCK, UNLOCK=(%1d,%1d)", LOCAL_X, LOCAL_Y, LOCAL_PORT, LOCAL_VC, lock, unlock );
		end
			for(int unsigned p=0; p<NUM_PORTS-1; p++)
				for(int unsigned v=0; v<NUM_VCS; v++) 
					//if(grant_success[p][v]===1'bx || vc_grant[p][v]===1'bx)
						$display($time(), " c [%1d][%1d][%1d][%1d] gs=%1d, vg=%1d", LOCAL_PORT, LOCAL_VC, p, v, grant_success[p][v], vc_grant[p][v]);
		*/
	end
	
	always_comb begin
		unlock = 1'b0;
		for(int unsigned p=0; p<NUM_PORTS-1; p++)
				for(int unsigned v=0; v<NUM_VCS; v++) 
					if(v==NUM_VCS-1) begin
						if(p==NUM_PORTS-2) begin
							unlock |= (vc_unlock[p][v] & pri[0][0]);
						end else begin
							unlock |= (vc_unlock[p][v] & pri[p+1][0]);
						end
					end else begin
						unlock |= (vc_unlock[p][v] & pri[p][v+1]);
					end
	end
	
	always_ff @(posedge clk or negedge arst_n) begin
		if(!arst_n) begin
			for(int unsigned p=0; p<NUM_PORTS-1; p++)
				for(int unsigned v=0; v<NUM_VCS; v++) 
					pri[p][v]  <= 1'b0;
			pri[0][0] <= 1'b1;
		end else if(lock) begin
			for(int unsigned p=0; p<NUM_PORTS-1; p++)
				for(int unsigned v=0; v<NUM_VCS; v++)
					if(v==0) begin
						if(p==0) 
							pri[0][0] <= vc_grant[NUM_PORTS-2][NUM_VCS-1];
						else 
							pri[p][0] <= vc_grant[p-1][NUM_VCS-1];
					end else 
						pri[p][v] <= vc_grant[p][v-1];
		end
	end

	always_ff @(posedge clk or negedge arst_n) begin
		
		`ifndef SYNTHESIS
			assert final (arst_n ? !(lock && unlock && !req_msk) : 1) else
				$error("INPUT_ARB(%1d,%1d,%1d,%1d): LOCK AND UNLOCK BOTH SET. REQ_MSK(%1d)", LOCAL_X, LOCAL_Y, LOCAL_PORT, LOCAL_VC, req_msk);
			assert final (arst_n ? !(lock && !req_msk) : 1) else
				$error("INPUT_ARB(%1d,%1d,%1d,%1d): ATTEMPT TO LOCK AN UNAVAILABLE VC. LOCK(1) AND REQ_MSK(%1d)", LOCAL_X, LOCAL_Y, LOCAL_PORT, LOCAL_VC, req_msk);
		`endif
		
		if(!arst_n)
			req_msk <= 1'b1;
		else if(lock)
			req_msk <= 1'b0;
		else if (unlock)
			req_msk <= 1'b1;
	end
/*	
	always @(lock, unlock) begin
		$display($time(), " b INPUT_ARB(%1d,%1d,%1d,%1d)- LOCK, UNLOCK=(%1d,%1d)", LOCAL_X, LOCAL_Y, LOCAL_PORT, LOCAL_VC, lock, unlock );
	end
	
	always @(req_msk, unlock)
		$display($time(), " d INPUT_ARB(%1d,%1d,%1d,%1d)- (RM%1d,UL%1d)", LOCAL_X, LOCAL_Y, LOCAL_PORT, LOCAL_VC, req_msk, unlock );
	*/
	always_comb begin
	//always @(req_msk, reqva) begin
		for(int unsigned ip=0; ip<NUM_PORTS-1; ip++) 
			for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) //input vc
				reqvc_i[ip][ivc] = req_msk & (reqva[ip][ivc]==LOCAL_PORT);
	end
	
	logic c0[NUM_PORTS-1][NUM_VCS];
	logic c1[NUM_PORTS-1][NUM_VCS];
	logic c_feedback0, c_feedback1;
	
	//assign c_feedback1 = c_feedback0;
	
	always_comb begin
		//c0 = '{NUM_PORTS-1{ '{NUM_VCS {1'b0}}}};	//can be added to remove the warning in questasim
		c0[0][0] = 1'b0;
		for(int unsigned ip=0; ip<NUM_PORTS-1; ip++) begin
			for(int unsigned ivc=0; ivc<NUM_VCS; ivc++)	begin	//input vc
				vc_grant0[ip][ivc] = (c0[ip][ivc] | pri[ip][ivc]) & reqvc_i[ip][ivc];
				if(ip==NUM_PORTS-2 && ivc==NUM_VCS-1) 
					c_feedback0= (c0[ip][ivc] | pri[ip][ivc]) & ~reqvc_i[ip][ivc];
				else if(ivc==NUM_VCS-1) 
					c0[ip+1][0] = (c0[ip][ivc] | pri[ip][ivc]) & ~reqvc_i[ip][ivc];
				else
					c0[ip][ivc+1] = (c0[ip][ivc] | pri[ip][ivc]) & ~reqvc_i[ip][ivc];
			end
		end
	end
	
	
	always_comb begin
		//c1 = '{NUM_PORTS-1{ '{NUM_VCS {1'b0}}}};	//can be added to remove the warning in questasim
		c1[0][0] = c_feedback0;
		for(int unsigned ip=0; ip<NUM_PORTS-1; ip++) begin
			for(int unsigned ivc=0; ivc<NUM_VCS; ivc++)	begin	//input vc
				vc_grant1[ip][ivc] = (c1[ip][ivc] | pri[ip][ivc]) & reqvc_i[ip][ivc];
				if(ip==NUM_PORTS-2 && ivc==NUM_VCS-1) 
					c_feedback1= (c1[ip][ivc] | pri[ip][ivc]) & ~reqvc_i[ip][ivc];
				else if(ivc==NUM_VCS-1) 
					c1[ip+1][0] = (c1[ip][ivc] | pri[ip][ivc]) & ~reqvc_i[ip][ivc];
				else
					c1[ip][ivc+1] = (c1[ip][ivc] | pri[ip][ivc] )& ~reqvc_i[ip][ivc];
			end
		end
	end
	
	always_comb 
		for(int unsigned ip=0; ip<NUM_PORTS-1; ip++) 
			for(int unsigned ivc=0; ivc<NUM_VCS; ivc++)	
				vc_grant[ip][ivc] = vc_grant0[ip][ivc] | vc_grant1[ip][ivc];
				
endmodule

/*COMMENTS
after grant, priority is grant shifted by 1.

*/
	