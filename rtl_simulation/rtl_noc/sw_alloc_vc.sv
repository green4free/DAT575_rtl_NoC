`include "router_pkg.sv"
import router_pkg::*;

module sw_alloc_vc (
`ifndef SYNTHESIS
	input logic [DIM_BITS-1:0] LOCAL_X,
	input logic [DIM_BITS-1:0] LOCAL_Y,
`endif
	
	input logic clk, arst_n,
	input dir_t reqsa[NUM_PORTS][NUM_VCS],
	input logic [CREDIT_CTR_WIDTH-1:0] credits_avail_count_r[NUM_PORTS][NUM_VCS],
	
	output logic sw_allocated_r [NUM_PORTS][NUM_VCS],	//to input_block
	output logic op_grant_r [NUM_PORTS],				//to output_block_vc
	output logic [1:0] xbar_port_sel_r [NUM_PORTS],
	output logic [VC_ID_BITS-1:0] xbar_vc_sel_r [NUM_PORTS]
	);
		
	dir_t reqsa_in_arb [NUM_PORTS][(NUM_PORTS-1)*NUM_VCS];
	logic [(NUM_PORTS-1)*NUM_VCS-1:0] grantsa_in_arb [NUM_PORTS];
	logic [(NUM_PORTS-1)*NUM_VCS-1:0] grant_success_in_arb [NUM_PORTS];
	
	logic [1:0] xbar_port_sel_w [NUM_PORTS];
	logic [VC_ID_BITS-1:0] xbar_vc_sel_w [NUM_PORTS];
	logic req_out_arb[NUM_PORTS][NUM_VCS];
	logic [NUM_VCS-1:0] grant_out_arb[NUM_PORTS];
	
	
	always_comb begin
		int tmp;
		for(int unsigned op=0; op<NUM_PORTS; op++)  begin
			tmp=0;
			for(int unsigned ip=0; ip<NUM_PORTS-1; ip++) 
				for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) begin
					if(ip>=op) 
						reqsa_in_arb[op][tmp] = ((sw_allocated_r[ip+1][ivc] && credits_avail_count_r[ip+1][ivc]=='d1) || credits_avail_count_r[ip+1][ivc]=='d0) ? DI : reqsa[ip+1][ivc];
					else 
						reqsa_in_arb[op][tmp] = ((sw_allocated_r[ip][ivc] && credits_avail_count_r[ip][ivc]=='d1) || credits_avail_count_r[ip][ivc]=='d0) ? DI : reqsa[ip][ivc];
					tmp++;
				end
		end
	end

	//input port arbitration
	genvar op_g;
	generate 
		for(op_g=0; op_g<NUM_PORTS; op_g++)  begin : in_swarb_op
			sw_input_arb #(op_g, (NUM_PORTS-1)*NUM_VCS)  in_sw_arb ( 
		`ifndef SYNTHESIS
				LOCAL_X, LOCAL_Y, clk, arst_n, reqsa_in_arb[op_g], grant_success_in_arb[op_g], grantsa_in_arb[op_g]);
		`else
				clk, arst_n, reqsa_in_arb[op_g], grant_success_in_arb[op_g], grantsa_in_arb[op_g]);
		`endif
		end
	endgenerate
	
	
	always_comb begin
		for(int unsigned ip=0; ip<NUM_PORTS; ip++) begin
			for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) begin
				case (ip)
					N: begin
						case (reqsa[ip][ivc])
							E: req_out_arb[N][ivc] = grantsa_in_arb[E][N*NUM_VCS + ivc];
							S: req_out_arb[N][ivc] = grantsa_in_arb[S][N*NUM_VCS + ivc];
							W: req_out_arb[N][ivc] = grantsa_in_arb[W][N*NUM_VCS + ivc];
							R: req_out_arb[N][ivc] = grantsa_in_arb[R][N*NUM_VCS + ivc];
							default: req_out_arb[N][ivc] = '0;
						endcase
					end
					E: begin
						case (reqsa[ip][ivc])
							N: req_out_arb[E][ivc] = grantsa_in_arb[N][(E-1)*NUM_VCS + ivc];
							S: req_out_arb[E][ivc] = grantsa_in_arb[S][E*NUM_VCS + ivc];
							W: req_out_arb[E][ivc] = grantsa_in_arb[W][E*NUM_VCS + ivc];
							R: req_out_arb[E][ivc] = grantsa_in_arb[R][E*NUM_VCS + ivc];
							default: req_out_arb[E][ivc] = '0;
						endcase
					end
					S: begin
						case (reqsa[ip][ivc])
							N: req_out_arb[S][ivc] = grantsa_in_arb[N][(S-1)*NUM_VCS + ivc];
							E: req_out_arb[S][ivc] = grantsa_in_arb[E][(S-1)*NUM_VCS + ivc];
							W: req_out_arb[S][ivc] = grantsa_in_arb[W][S*NUM_VCS + ivc];
							R: req_out_arb[S][ivc] = grantsa_in_arb[R][S*NUM_VCS + ivc];
							default: req_out_arb[S][ivc] = '0;
						endcase
					end
					W: begin
						case (reqsa[ip][ivc])
							N: req_out_arb[W][ivc] = grantsa_in_arb[N][(W-1)*NUM_VCS + ivc];
							E: req_out_arb[W][ivc] = grantsa_in_arb[E][(W-1)*NUM_VCS + ivc];
							S: req_out_arb[W][ivc] = grantsa_in_arb[S][(W-1)*NUM_VCS + ivc];
							R: req_out_arb[W][ivc] = grantsa_in_arb[R][W*NUM_VCS + ivc];
							default: req_out_arb[W][ivc] = '0;
						endcase
					end
					R: begin
						case (reqsa[ip][ivc])
							N: req_out_arb[R][ivc] = grantsa_in_arb[N][(R-1)*NUM_VCS + ivc];
							E: req_out_arb[R][ivc] = grantsa_in_arb[E][(R-1)*NUM_VCS + ivc];
							S: req_out_arb[R][ivc] = grantsa_in_arb[S][(R-1)*NUM_VCS + ivc];
							W: req_out_arb[R][ivc] = grantsa_in_arb[W][(R-1)*NUM_VCS + ivc];
							default: req_out_arb[R][ivc] = '0;
						endcase
					end						
					default: req_out_arb[ip][ivc] = '0;
				endcase
			end
		end
	end
	
	
	genvar ip_g;
	generate
		for(ip_g=0; ip_g<NUM_PORTS; ip_g++) begin : out_swarb_ip
			sw_output_arb #(ip_g, NUM_VCS) out_sw_arb (
		`ifndef SYNTHESIS
				LOCAL_X, LOCAL_Y, clk, arst_n, req_out_arb[ip_g], grant_out_arb[ip_g]);
		`else
				clk, arst_n, req_out_arb[ip_g], grant_out_arb[ip_g]);
		`endif
		end
	endgenerate
	
	
	always_comb begin
		int tmp;
		for(int unsigned op=0; op<NUM_PORTS; op++)  begin
			tmp=0;
			for(int unsigned  ip=0; ip<NUM_PORTS-1; ip++) 
				for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) begin
					if(ip>=op) 
						grant_success_in_arb[op][tmp] = grant_out_arb[ip+1][ivc] & grantsa_in_arb[op][tmp];
					else 
						grant_success_in_arb[op][tmp] = grant_out_arb[ip][ivc] & grantsa_in_arb[op][tmp];
					tmp++;
				end
		end
	end
	
	
	always_comb begin
		logic [VC_ID_BITS-1:0] tmp;
		for(int unsigned ip=0; ip<NUM_PORTS; ip++) begin
				tmp = '1;
				for(int unsigned ivc=0; ivc<NUM_VCS; ivc++) begin
					tmp++;
					if (grant_out_arb[ip][ivc]) break;
				end
				xbar_vc_sel_w[ip] = tmp;
			end
	end
	
	
	always_comb begin
		for(int unsigned op=0; op<NUM_PORTS; op++) begin
			unique case({|grant_success_in_arb[op][3*NUM_VCS+:NUM_VCS], |grant_success_in_arb[op][2*NUM_VCS+:NUM_VCS], |grant_success_in_arb[op][1*NUM_VCS+:NUM_VCS], |grant_success_in_arb[op][0*NUM_VCS+:NUM_VCS]})
				4'b0000: xbar_port_sel_w[op] = 2'd0;
				4'b0001: xbar_port_sel_w[op] = 2'd0;
				4'b0010: xbar_port_sel_w[op] = 2'd1;
				4'b0100: xbar_port_sel_w[op] = 2'd2;
				4'b1000: xbar_port_sel_w[op] = 2'd3;
				default: begin
					xbar_port_sel_w[op] = 2'd0;
				//	if(!arst_n) $display($time(), " NS ERROR: SW_ALLOC(%1d,%1d): NO CONDITION IS TRUE IN THE UNIQUE/PRIORITY CASE STATEMENT.", LOCAL_X, LOCAL_Y);
				end
			endcase
		end
	end

	
	always_ff @(posedge clk or negedge arst_n) 
		if(!arst_n) begin
			sw_allocated_r 	<= '{NUM_PORTS{'{NUM_VCS{1'b0}}}};
			xbar_vc_sel_r 	<= '{NUM_PORTS{'b0}};
			xbar_port_sel_r <= '{NUM_PORTS{'b0}};
			op_grant_r 		<= '{NUM_PORTS{'b0}};
		end else begin
			xbar_vc_sel_r 	<= xbar_vc_sel_w;
			xbar_port_sel_r <= xbar_port_sel_w;
			for(int unsigned op=0; op<NUM_PORTS; op++) begin
				op_grant_r[op] <= |(grant_success_in_arb[op]);
				for(int unsigned vc=0; vc<NUM_VCS; vc++)
					sw_allocated_r[op][vc] <= grant_out_arb[op][vc];
			end
		end
	
endmodule

/*COMMENTS
1. reqsa is forwarded to reqsa_in_arb after checking the sw_allocated_r signal and ds vc counter value. these checks should be moved to input_block_vc

*/