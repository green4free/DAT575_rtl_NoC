`include "router_pkg.sv"
`include "tb_pkg.sv"

import router_pkg::*;
import tb_pkg::*;

module pkt_queue
	#(
		int unsigned sx, sy
	) (
		input logic clk, arst_n,
		
		input pkt_t pkt_to_queue,
		input logic pkt_rdy_to_queue,
		
		input logic tx_ready,
		output pkt_t pkt_to_tx,
		output logic pkt_to_tx_valid
	);
	
	pkt_t pkt_q[$];
	logic pkt_push, pkt_pop;
	
	//push
	always @(negedge arst_n or pkt_rdy_to_queue) begin
		if (!arst_n) begin
			pkt_q.delete();
			pkt_push <= 0;
		end else begin
			pkt_q.push_back(pkt_to_queue);
			pkt_push <= ~pkt_push;
		end
	end
	
	
	//pop
	always_ff @(posedge clk or negedge arst_n) begin
		if (!arst_n) begin
			pkt_pop <= 0;
		end else begin
			if (tx_ready && pkt_to_tx_valid) begin
				void'(pkt_q.pop_front());
				pkt_pop <= ~pkt_pop;
			end
		end
	end
	
	
	//output
	initial begin
		@(negedge arst_n);
		pkt_to_tx_valid <= 0;
		
		while (1) begin
			fork
				begin
					@(pkt_push);
					pkt_to_tx_valid <= 1;
					pkt_to_tx <= pkt_q[0];
				end
				
				begin
					@(pkt_pop);
					if (pkt_q.size() != 0) begin
						pkt_to_tx_valid <= 1;
						pkt_to_tx <= pkt_q[0];
					end else begin
						pkt_to_tx_valid <= 0;
					end
				end
			join_any
		end
	end
	
endmodule