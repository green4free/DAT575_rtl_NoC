`include "router_pkg.sv"		//contains the definition of _DEBUG_
import router_pkg::*;

`include "tb_pkg.sv"
import tb_pkg::*;

module input_block_vc #(
	parameter dir_t LOCAL_PORT = W	
	) (
	input logic [DIM_BITS-1:0] LOCAL_X,
	input logic [DIM_BITS-1:0] LOCAL_Y,
	
	input logic clk, arst_n,
	input channel_t inflit,
	input logic vc_allocated[NUM_VCS],
	input logic [VC_ID_BITS-1:0] vc_allocated_id[NUM_VCS],
	input logic sw_allocated_r[NUM_VCS],
	input logic [CREDIT_CTR_WIDTH-1:0] ovc_credits_count_r [NUM_PORTS][NUM_VCS],
	input logic out_vc_free[NUM_PORTS][NUM_VCS],
	
	output dir_t req_out_dir_va[NUM_VCS],
	output dir_t req_out_dir_sa[NUM_VCS],
	output logic unlock_vc[NUM_VCS],
	output channel_t outflit[NUM_VCS],
	
	//control signals for rev_xbar
	output logic [1:0] out_route [NUM_VCS],
	output logic [VC_ID_BITS-1:0] out_vc_id [NUM_VCS]
	);
	
	
	vc_states_t p_state_r[NUM_VCS] = '{NUM_VCS{IDLE}};
	vc_states_t n_state[NUM_VCS];
	
	dir_t rc_w[NUM_VCS], rc_r[NUM_VCS];
	logic [VC_ID_BITS-1:0] vc_allocated_id_r[NUM_VCS];		//allocated vc_id for downstream router

	logic [NUM_VCS-1:0] req_va, req_sa;
	logic [DIM_BITS-1:0] dst_x[NUM_VCS], dst_y[NUM_VCS];
	
	logic  wr[NUM_VCS], rd[NUM_VCS];
	channel_t fifo_outflit[NUM_VCS];
	logic [CREDIT_CTR_WIDTH-1:0] vc_fifo_count_r[NUM_VCS];
	
	
	assign rd = sw_allocated_r;
	assign out_vc_id = vc_allocated_id_r;
	
	
	genvar vcn;
	generate
	for(vcn=0; vcn<NUM_VCS; vcn++) begin : VC_GEN
	`ifndef SYNTHESIS
		n_deep_cir_fifo #(LOCAL_PORT, vcn, CREDIT_CTR_WIDTH, VC_BUFFER_PTR_WIDTH, CREDITS_PER_VC) ib_fifo_inst 
			(LOCAL_X, LOCAL_Y, clk, arst_n, {inflit.head.ftype, inflit.body.data}, wr[vcn], rd[vcn],{fifo_outflit[vcn].head.ftype, fifo_outflit[vcn].body.data}, vc_fifo_count_r[vcn]);
	`else 
		n_deep_cir_fifo #(LOCAL_PORT, vcn, CREDIT_CTR_WIDTH, VC_BUFFER_PTR_WIDTH, CREDITS_PER_VC) ib_fifo_inst 
			(clk, arst_n, {inflit.head.ftype, inflit.body.data}, wr[vcn], rd[vcn], {fifo_outflit[vcn]head.ftype, fifo_outflit[vcn].body.data}, vc_fifo_count_r[vcn]);
	`endif
		
		assign wr[vcn] = (inflit.head.ftype != I && inflit.head.fvcid == vcn) ? 1'b1 : 1'b0;
		assign outflit[vcn] = {fifo_outflit[vcn].head.ftype, vc_allocated_id_r[vcn], fifo_outflit[vcn].body.data};
		
		assign req_out_dir_va[vcn] = (req_va[vcn]) ? rc_r[vcn] : DI;
		assign req_out_dir_sa[vcn] = (req_sa[vcn]) ? rc_r[vcn] : DI;
		assign unlock_vc[vcn] = sw_allocated_r[vcn] & (outflit[vcn].head.ftype==T || outflit[vcn].head.ftype==HT);
		

		always_comb begin		
			if(rc_r[vcn] > LOCAL_PORT)
				out_route[vcn] = rc_r[vcn]-1;
			else
				out_route[vcn] = rc_r[vcn];
		end
		
		always_comb begin : next_state_proc
			n_state[vcn] = p_state_r[vcn];
			
			case (p_state_r[vcn]) 
			IDLE: begin
				if(vc_fifo_count_r[vcn] == 0) begin
					if(inflit.head.ftype != I && inflit.head.fvcid == vcn)
						n_state[vcn] = RC;
					else
						n_state[vcn] = IDLE;
					
					`ifndef SYNTHESIS
						assert #0 (inflit.head.fvcid == vcn ? inflit.head.ftype == H || inflit.head.ftype == HT || inflit.head.ftype == I : 1) else
							$error("(DEFFERED): INPUT_BLOCK(%1d,%1d,%1d,%1d): NEXT_STATE: INFLIT.TYPE(=%d) != {I|H|HT} IN IDLE STATE", LOCAL_X, LOCAL_Y, LOCAL_PORT, vcn, inflit.head.ftype);
					`endif
					
				end else begin
					n_state[vcn] = RC;
					
					`ifndef SYNTHESIS
						assert #0 (fifo_outflit[vcn].head.ftype == H || fifo_outflit[vcn].head.ftype == HT) else 
							$error("(DEFFERED): INPUT_BLOCK(%1d,%1d,%1d,%1d): NEXT_STATE: FIFO_OUTFLIT.FTYPE(=%D) != {H|HT} IN IDLE STATE", LOCAL_X, LOCAL_Y, LOCAL_PORT, vcn, fifo_outflit[vcn].head.ftype);							
						assert (vc_fifo_count_r[vcn] == 1) else 
							$error("INPUT_BLOCK(%1d,%1d,%1d,%1d): NEXT_STATE: MULTIPLE FLITS IN BUFFER WHILE IN IDLE STATE. vc_fifo_COUNT_r=%d", LOCAL_X, LOCAL_Y, LOCAL_PORT, vcn, vc_fifo_count_r[vcn]);
					`endif
				end
			end
			
			RC: begin
				n_state[vcn] = VA;
			end
			
			VA: begin
				if(vc_allocated[vcn])
					n_state[vcn] = A;
				
				`ifndef SYNTHESIS
					assert (vc_fifo_count_r[vcn] > 0) else
						$error("INPUT_BLOCK(%1d,%1d,%1d,%1d): NEXT_STATE: EMPTY FIFO IN VA STATE", LOCAL_X, LOCAL_Y, LOCAL_PORT, vcn);
					assert #0 (fifo_outflit[vcn].head.ftype == H || fifo_outflit[vcn].head.ftype == HT) else
						$error("(DEFFERED): INPUT_BLOCK(%1d,%1d,%1d,%1d): NEXT_STATE: NON-{H|HT} FLIT AT TOP IN FIFO IN VA STATE. FTYPE=%d", LOCAL_X, LOCAL_Y, LOCAL_PORT, vcn, fifo_outflit[vcn].head.ftype);
				`endif
			end
			
			A: begin
				if ( !( (fifo_outflit[vcn].head.ftype == T || fifo_outflit[vcn].head.ftype == HT) && sw_allocated_r[vcn]) )
					n_state[vcn] = A;
				else if (vc_fifo_count_r[vcn] == 1)
					n_state[vcn] = IDLE;
				else begin	//if vc_fifo_count_r==0 || vc_fifo_count_r>1
					n_state[vcn] = RC;
					
					`ifndef SYNTHESIS
						assert final (vc_fifo_count_r[vcn] != 0) else
							$error("INPUT_BLOCK(%1d,%1d,%1d,%1d): NEXT_STATE: EMPTY FIFO IN A STATE", LOCAL_X, LOCAL_Y, LOCAL_PORT, vcn);
					`endif
				end
			end
			
			default: begin
				n_state[vcn] = IDLE;
				`ifndef SYNTHESIS
					assert (0) else $error("INPUT_BLOCK(%1d,%1d,%1d,%1d): NEXT_STATE CASE UNKNOWN %d", LOCAL_X, LOCAL_Y, LOCAL_PORT, vcn, p_state_r[vcn]);
				`endif
			end
			endcase
		end : next_state_proc
		
		
		
		always_comb begin : out_proc
			dst_x[vcn] = '0;
			dst_y[vcn] = '0;
			req_va[vcn] = 0;
			req_sa[vcn] = 0;
			
			case (p_state_r[vcn]) 
			IDLE: begin
			end
			
			RC: begin
				dst_x[vcn] = fifo_outflit[vcn].head.dstx;
				dst_y[vcn] = fifo_outflit[vcn].head.dsty;
			end
			
			VA: begin
				req_va[vcn] = 1'b1;
			end
			
			A: begin
				if (sw_allocated_r[vcn]) 
					if (fifo_outflit[vcn].head.ftype == T || fifo_outflit[vcn].head.ftype == HT || vc_fifo_count_r[vcn] == 1)
						req_sa[vcn] = 0;
					else begin
						req_sa[vcn] = 1;
						
						`ifndef SYNTHESIS
							assert final (vc_fifo_count_r[vcn] != 0) else 
								$error("INPUT_BLOCK(%1d,%1d,%1d,%1d): OUT: EMPTY FIFO IN A STATE. SA_ALLOCATED=%d", LOCAL_X, LOCAL_Y, LOCAL_PORT, vcn, sw_allocated_r[vcn]);
						`endif
					end
					
				else if(vc_fifo_count_r[vcn] >= 1)
					req_sa[vcn] = 1;
				else
					req_sa[vcn] = 0;
					
			end
			
			`ifndef SYNTHESIS
			default: begin
				assert(0) else $error("INPUT_BLOCK(%1d,%1d,%1d,%1d): OUT CASE UNKNOWN", LOCAL_X, LOCAL_Y, LOCAL_PORT, vcn);
			end
			`endif
			
			endcase
		end : out_proc
		
		wire [31:0] LFSR_INIT = (LOCAL_X + MAX_X*LOCAL_Y + MAX_X*MAX_Y*vcn) % (1 << 32 - 1);
		logic [31:0] lfsr = LFSR_INIT;
		always_ff @(posedge clk or negedge arst_n)
			if(!arst_n) lfsr <= LFSR_INIT;
			else begin
				lfsr[31:1] <= lfsr[30:0];
				lfsr[0] <= ~(^{lfsr[31], lfsr[21], lfsr[1], lfsr[0]});
			end
		localparam RANDOM_WIDTH = 9;
		rc #(.random_width(RANDOM_WIDTH), .mode(RC_MODE)) rc_i (
			.LOCAL_X(LOCAL_X),
			.LOCAL_Y(LOCAL_Y),
			.dst_x(dst_x[vcn]),
			.dst_y(dst_y[vcn]),
			.out_vc_free(out_vc_free),
			.ovc_credits_count_r(ovc_credits_count_r),
			.rc_out(rc_w[vcn][2:0]),
			.random(lfsr[RANDOM_WIDTH-1:0])
		);
		
		
		always_ff @(posedge clk or negedge arst_n) begin : update_state_proc
			if(!arst_n) begin
				p_state_r[vcn] <= IDLE;
				rc_r[vcn] <= DI;
				vc_allocated_id_r[vcn] <= '0;
			end else begin
				p_state_r[vcn] <= n_state[vcn];
				if(p_state_r[vcn] == RC) begin
					rc_r[vcn] <= rc_w[vcn];
					if (rc_w[vcn] == W)
						assert (|{LOCAL_PORT==E, LOCAL_PORT==R, LOCAL_PORT==DI}) else $error("Never turn towords west.");
				end
				if(p_state_r[vcn] == VA && vc_allocated[vcn]) begin
					vc_allocated_id_r[vcn] <= vc_allocated_id[vcn];
				end
			end
		end : update_state_proc
	end : VC_GEN
	endgenerate
	
	
	`ifndef SYNTHESIS
		initial begin
			$assertkill();
			@(negedge arst_n);
			`ifdef _DEBUG_
				$asserton();
			`endif
		end
	`endif
	
endmodule


/*	COMMENTS
1. fifo_outflit signal might be unnecessary
2. is it possible to remove the always block outside the assert property statement in the end??
*/