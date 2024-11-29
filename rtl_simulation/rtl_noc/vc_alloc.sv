`include "router_pkg.sv"
import router_pkg::*;

module vc_alloc (
`ifndef SYNTHESIS
	input logic [DIM_BITS-1:0] LOCAL_X,
	input logic [DIM_BITS-1:0] LOCAL_Y,
	output logic out_vc_free[NUM_PORTS][NUM_VCS],
`endif
	
	input logic clk, arst_n,
	input dir_t reqva[NUM_PORTS][NUM_VCS],
	input logic unlock_vc[NUM_PORTS][NUM_VCS],
	
	output logic vc_allocated [NUM_PORTS][NUM_VCS],	//to input_block
	output logic [VC_ID_BITS-1:0] vc_allocated_id [NUM_PORTS][NUM_VCS]	//to input_block

	);

	dir_t in_arb_req [NUM_PORTS][NUM_VCS][NUM_PORTS-1][NUM_VCS];			//[output vc port][output vc][input vc port][input vc]
	logic in_arb_unlock[NUM_PORTS][NUM_VCS][NUM_PORTS-1][NUM_VCS];			//[output vc port][output vc][input vc port][input vc]
	logic in_arb_grant[NUM_PORTS][NUM_VCS][NUM_PORTS-1][NUM_VCS];			//[output vc port][output vc][input vc port][input vc]
	logic in_arb_grant_success[NUM_PORTS][NUM_VCS][NUM_PORTS-1][NUM_VCS];	//[output vc port][output vc][input vc port][input vc]
	
	logic out_arb_req [NUM_PORTS][NUM_VCS][NUM_VCS];
	logic out_arb_grant [NUM_PORTS][NUM_VCS][NUM_VCS];
	
	
	always_comb 
		for(int unsigned op=0; op<NUM_PORTS; op++) 
			for(int unsigned ovc=0; ovc<NUM_VCS; ovc++)
				for(int unsigned ip=0; ip<NUM_PORTS-1; ip++) 
					for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) 
						in_arb_req[op][ovc][ip][ivc] = (op<=ip) ? reqva[ip+1][ivc] : reqva[ip][ivc]; 
						
	always_comb 
		for(int unsigned op=0; op<NUM_PORTS; op++) 
			for(int unsigned ovc=0; ovc<NUM_VCS; ovc++)
				for(int unsigned ip=0; ip<NUM_PORTS-1; ip++) 
					for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) 
							in_arb_unlock[op][ovc][ip][ivc] = (op<=ip) ? unlock_vc[ip+1][ivc] : unlock_vc[ip][ivc];
							
	always_comb 
		for(int unsigned op=0; op<NUM_PORTS; op++) 
			for(int unsigned ovc=0; ovc<NUM_VCS; ovc++)
				for(int unsigned ip=0; ip<NUM_PORTS-1; ip++) 
					for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) 
						in_arb_grant_success[op][ovc][ip][ivc] = (op<=ip) ? out_arb_grant[ip+1][ivc][ovc] : out_arb_grant[ip][ivc][ovc];
		
	
	//input side vc arbiters
	genvar op_g, ovc_g;
	generate
		for(op_g=0; op_g<NUM_PORTS; op_g++) begin : in_vcarb_op
			for(ovc_g=0; ovc_g<NUM_VCS; ovc_g++) begin : in_vcarb_ovc
				vc_input_arb #(op_g, ovc_g) in_vcarb ( 
			`ifndef SYNTHESIS
					LOCAL_X, LOCAL_Y, out_vc_free[op_g][ovc_g], clk, arst_n, in_arb_req[op_g][ovc_g], in_arb_unlock[op_g][ovc_g], in_arb_grant_success[op_g][ovc_g], in_arb_grant[op_g][ovc_g]);
			`else
					clk, arst_n, in_arb_req[op_g][ovc_g], in_arb_unlock[op_g][ovc_g], in_arb_grant_success[op_g][ovc_g], in_arb_grant[op_g][ovc_g]);
			`endif
			end
		end
	endgenerate	
	
	
	
	//output side vc arbiters
	always_comb begin
		for(int unsigned ip=0; ip<NUM_PORTS; ip++) begin
			for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) begin
				for(int unsigned i=0; i<NUM_VCS; i++) begin
					case (ip)
						N: begin
							case (reqva[ip][ivc])
								E: out_arb_req[N][ivc][i] = in_arb_grant[E][i][N][ivc];
								S: out_arb_req[N][ivc][i] = in_arb_grant[S][i][N][ivc];
								W: out_arb_req[N][ivc][i] = in_arb_grant[W][i][N][ivc];
								R: out_arb_req[N][ivc][i] = in_arb_grant[R][i][N][ivc];
								default: out_arb_req[N][ivc][i] = '0;
							endcase
						end
						E: begin
							case (reqva[ip][ivc])
								N: out_arb_req[E][ivc][i] = in_arb_grant[N][i][E-1][ivc];
								S: out_arb_req[E][ivc][i] = in_arb_grant[S][i][E][ivc];
								W: out_arb_req[E][ivc][i] = in_arb_grant[W][i][E][ivc];
								R: out_arb_req[E][ivc][i] = in_arb_grant[R][i][E][ivc];
								default: out_arb_req[E][ivc][i] = '0;
							endcase
						end
						S: begin
							case (reqva[ip][ivc])
								N: out_arb_req[S][ivc][i] = in_arb_grant[N][i][S-1][ivc];
								E: out_arb_req[S][ivc][i] = in_arb_grant[E][i][S-1][ivc];
								W: out_arb_req[S][ivc][i] = in_arb_grant[W][i][S][ivc];
								R: out_arb_req[S][ivc][i] = in_arb_grant[R][i][S][ivc];
								default: out_arb_req[S][ivc][i] = '0;
							endcase
						end
						W: begin
							case (reqva[ip][ivc])
								N: out_arb_req[W][ivc][i] = in_arb_grant[N][i][W-1][ivc];
								E: out_arb_req[W][ivc][i] = in_arb_grant[E][i][W-1][ivc];
								S: out_arb_req[W][ivc][i] = in_arb_grant[S][i][W-1][ivc];
								R: out_arb_req[W][ivc][i] = in_arb_grant[R][i][W][ivc];
								default: out_arb_req[W][ivc][i] = '0;
							endcase
						end
						R: begin
							case (reqva[ip][ivc])
								N: out_arb_req[R][ivc][i] = in_arb_grant[N][i][R-1][ivc];
								E: out_arb_req[R][ivc][i] = in_arb_grant[E][i][R-1][ivc];
								S: out_arb_req[R][ivc][i] = in_arb_grant[S][i][R-1][ivc];
								W: out_arb_req[R][ivc][i] = in_arb_grant[W][i][R-1][ivc];
								default: out_arb_req[R][ivc][i] = '0;
							endcase
						end						
						default: out_arb_req[ip][ivc][i] = '0;
					endcase
				end
			end
		end
	end
	
	genvar ip_g, ivc_g;
	generate
		for(ip_g=0; ip_g<NUM_PORTS; ip_g++) begin : out_vcarb_ip
			for(ivc_g=0; ivc_g<NUM_VCS; ivc_g++) begin : out_vcarb_ivc 
				vc_output_arb #(ip_g, ivc_g) out_vcarb (
		`ifndef SYNTHESIS
					LOCAL_X, LOCAL_Y, out_arb_req[ip_g][ivc_g], out_arb_grant[ip_g][ivc_g]);
		`else
					out_arb_req[ip_g][ivc_g], out_arb_grant[ip_g][ivc_g]);
		`endif
			end
		end
	endgenerate
	
	
	always_comb begin
		for(int unsigned ip=0; ip<NUM_PORTS; ip++)
			for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) begin
				vc_allocated[ip][ivc] = '0;
				for(int unsigned ovc=0; ovc<NUM_VCS; ovc++) begin
					vc_allocated[ip][ivc] |= out_arb_grant[ip][ivc][ovc];
				end			
			end
	end
	
	
	//one hot to binary conversion
	always_comb begin
		logic [VC_ID_BITS-1:0] tmp;
		for(int unsigned ip=0; ip<NUM_PORTS; ip++)
			for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) begin
				tmp = '1;
				for(int unsigned ovc=0; ovc<NUM_VCS; ovc++) begin
					tmp++;
					if (out_arb_grant[ip][ivc][ovc]) break;
				end
				vc_allocated_id[ip][ivc] = tmp;
			end
	end
	/////////////
	
endmodule
/* COMMENTS
performs output first arbitration
1. try to simplify in_arb_grant -> out_arb_req code
2. verify and optimize one hot code to binary code converter
3. the unlock_vc signal is registered in the in_arb block. is it possible to have it unregistered??
*/