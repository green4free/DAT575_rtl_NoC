`include "router_pkg.sv"
import router_pkg::*;

module output_block_vc #(
	parameter dir_t LOCAL_PORT = W
	) (
`ifndef SYNTHESIS
	input logic [DIM_BITS-1:0] LOCAL_X,
	input logic [DIM_BITS-1:0] LOCAL_Y,
`endif

	input logic clk, arst_n,
	input channel_t flitin,
	input logic ob_en_r,
	input logic creditin [NUM_VCS],
	
	output logic [CREDIT_CTR_WIDTH-1:0] credits_avail_count_r[NUM_VCS],
	output channel_t flitout
	);
	
	logic [CREDIT_CTR_WIDTH-1:0] credit_counter_w[NUM_VCS];
	logic [NUM_VCS-1:0] cur_grant;
	

	always_ff @(posedge clk or negedge arst_n) begin
		if(!arst_n) begin
			flitout.head.fvcid <= '0;
			flitout.body.data <= '0;
		end else if(ob_en_r) begin
			flitout.head.fvcid <= flitin.head.fvcid;
			flitout.body.data <= flitin.body.data;
			
			`ifndef SYNTHESIS
				assert (flitin.head.ftype != I) else 
					$error("OB(%1d,%1d,%1d): OB_EN==1 WHILE FLITIN==I.", LOCAL_X, LOCAL_Y, LOCAL_PORT);
			`endif
		end
	end
	
	always_ff @(posedge clk or negedge arst_n) begin
		if(!arst_n)
			flitout.head.ftype <= I;
		else begin
			flitout.head.ftype <= ob_en_r ? flitin.head.ftype : I;
		end
	end
			
	
	always_ff @(posedge clk or negedge arst_n) begin
		if(!arst_n)
			credits_avail_count_r <= '{default: CREDITS_PER_VC};
		else
			credits_avail_count_r <= credit_counter_w;
	end
	
	
	always @(ob_en_r or flitin) begin
		cur_grant = '0;
		if(ob_en_r) begin
			cur_grant[flitin.head.fvcid] = 1'b1;
			
			`ifndef SYNTHESIS
				assert #0 (flitin.head.ftype != I) else 
					$error("OB(%1d,%1d,%1d): OB_EN==1 WHILE FLITIN.head.ftype==I.", LOCAL_X, LOCAL_Y, LOCAL_PORT);
			`endif
		end
	end
	
	
	genvar vc;
	generate
	for(vc=0; vc<NUM_VCS; vc++) begin
		//always @(cur_grant[vc] or creditin[vc] or credits_avail_count_r[vc])
		always_comb begin
			unique case ({cur_grant[vc], creditin[vc]})
			2'b00 : credit_counter_w[vc] = credits_avail_count_r[vc];
			2'b01 : begin
				`ifndef SYNTHESIS
					assert #0 (credits_avail_count_r[vc] != CREDITS_PER_VC) else
						$error("(-1 CYCLE) ERROR: OB(%1d,%1d,%1d,%1d): CREDIT RECEIVED WHEN CREDIT_COUNTER_REG == CREDITS_PER_VC.", LOCAL_X, LOCAL_Y, LOCAL_PORT, vc);
				`endif
				
				credit_counter_w[vc] = credits_avail_count_r[vc] + 1;
			end
			
			2'b10 : begin
				`ifndef SYNTHESIS
					/*assert (credits_avail_count_r[vc] != '0) else 
						$display($time(), " NS ERROR: OB(%1d,%1d,%1d,%1d): FLIT RECEIVED WHEN CREDIT_COUNTER_REG == 0. flit is %b \n cur_grant=%b , creditin=%b", LOCAL_X, LOCAL_Y, LOCAL_PORT, vc, flitin, cur_grant, creditin[vc]);
					*/		
					assert #0 (flitin.head.fvcid == vc) else
						$error("OB(%1d,%1d,%1d,%1d): FLIT(TYPE=%0d, VCID=%0d) RECEIVED IN WRONG VC.", LOCAL_X, LOCAL_Y, LOCAL_PORT, vc, flitin.head.ftype, flitin.head.fvcid);
				`endif
				
				credit_counter_w[vc] = credits_avail_count_r[vc] - 1;	
			end
			
			2'b11 : credit_counter_w[vc] = credits_avail_count_r[vc];
			
			`ifndef SYNTHESIS
			default: 
				assert (arst_n) else 
					$error("OB(%1d,%1d,%1d,%1d): CASE ARGUMENT UNMATCHED %d, %d.", LOCAL_X, LOCAL_Y, LOCAL_PORT, vc, cur_grant[vc], creditin[vc]);
			`endif
				
			endcase
		end
	end
	endgenerate
	
	`ifndef SYNTHESIS
	always_comb 
		for(int unsigned v=0; v<NUM_VCS; v++) 
			a0: assert (credits_avail_count_r[v]<=CREDITS_PER_VC) else if(arst_n)
				$error("ERROR: OB(%1d,%1d,%1d,%1d): CREDIT_COUNTER_REG(%0d) > CREDITS_PER_VC.", LOCAL_X, LOCAL_Y, LOCAL_PORT, v, credits_avail_count_r[v]);
	`endif

	
endmodule
/*COMMENTS
assert that flitin.head.ftype is not >3
assert flit is on the correct output direction
assert flitin vc is not out of bound
assertion a0 should be replaced with check that counter does not go from '0 to '1
*/
