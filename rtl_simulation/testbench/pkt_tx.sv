`include "router_pkg.sv"
`include "tb_pkg.sv"

import router_pkg::*;
import tb_pkg::*;

module pkt_tx
	#(
		int unsigned sx, sy
	) (
		input logic clk, arst_n,
		
		input stats_tracker_c pkt_stats_tracker,
		output logic tx_ready,
		input pkt_t pkt_to_tx,
		input logic pkt_to_tx_valid,
		
		output channel_t flit_to_noc,
		input logic credits_from_noc[NUM_VCS]
	);
	
	
	int rr_vcid_ptr_r;
	bit [NUM_VCS-1:0] vcid_free_bm_r;
	int credit_ctr_r[NUM_VCS], credit_ctr_w[NUM_VCS];
	
	int avail_vcid;
	pkt_t pkt_in_tx_tab[NUM_VCS];
	bit [NUM_VCS-1:0] pkt_in_tx_v_tab;
	
	channel_t flit_to_tx_tab_r[NUM_VCS];
	int pkt_tab_id_ptr_w, pkt_tab_id_ptr_r;
	
	
	//Pull ready packet
	initial begin
		@(negedge arst_n);
		tx_ready <= 0;
		pkt_in_tx_v_tab <= '0;
		vcid_free_bm_r = '1;
		rr_vcid_ptr_r <= 0;
		
		while(1) begin
			@(posedge clk);
			tx_ready <= 0;
			if (flit_to_noc.head.ftype == HT || flit_to_noc.head.ftype == T) begin
				pkt_in_tx_v_tab[flit_to_noc.head.fvcid] <= 0;
				vcid_free_bm_r[flit_to_noc.head.fvcid] <= 1;
			end
			
			@(negedge clk);
			//if (!pkt_to_tx_valid)
			//	@(posedge pkt_to_tx_valid);
			
			avail_vcid = get_avail_vcid_f();
			
			if (avail_vcid != -1 && pkt_to_tx_valid) begin
				tx_ready <= 1;
				
				pkt_in_tx_tab[avail_vcid] <= pkt_to_tx;
				pkt_in_tx_v_tab[avail_vcid] <= 1;
				
				vcid_free_bm_r[avail_vcid] <= 0;
				rr_vcid_ptr_r <= (rr_vcid_ptr_r + 1) % NUM_VCS;
			end
		end
	end
	
	
	//Transmit flit
	always_ff @(posedge clk or negedge arst_n) begin
		if (!arst_n) begin
			pkt_tab_id_ptr_r <= 0;
			for (int vc=0; vc<NUM_VCS; vc++)
				flit_to_tx_tab_r[vc].head.ftype <= I;
		end else begin
			if (flit_to_noc.head.ftype != I)
				pkt_tab_id_ptr_r <= (flit_to_noc.head.fvcid +1) %NUM_VCS;
			
			if (flit_to_noc.head.ftype == H || flit_to_noc.head.ftype == B) begin
				flit_to_tx_tab_r[flit_to_noc.head.fvcid].head.ftype <= (flit_to_tx_tab_r[flit_to_noc.head.fvcid].head.payload == pkt_in_tx_tab[flit_to_noc.head.fvcid].flit_count-2) ? T : B;
				flit_to_tx_tab_r[flit_to_noc.head.fvcid].head.payload <= flit_to_tx_tab_r[flit_to_noc.head.fvcid].head.payload + 1;
			end else if (flit_to_noc.head.ftype == T || flit_to_noc.head.ftype == HT) begin
				flit_to_tx_tab_r[flit_to_noc.head.fvcid].head.ftype <= I;
			end
			
			if (flit_to_noc.head.ftype == H || flit_to_noc.head.ftype == HT)
				pkt_stats_tracker.log_pkt_h_tx_time(sx, sy, flit_to_noc.head.pkt_id);
			
			for (int vc=0; vc<NUM_VCS; vc++) begin
				if (!vcid_free_bm_r[vc] && flit_to_tx_tab_r[vc].head.ftype == I) begin
					flit_to_tx_tab_r[vc].head.ftype		<= (pkt_in_tx_tab[vc].flit_count == 1) ? HT : H;
					flit_to_tx_tab_r[vc].head.fvcid 	<= vc;
					flit_to_tx_tab_r[vc].head.srcx 		<= sx;
					flit_to_tx_tab_r[vc].head.srcy 		<= sy;
					flit_to_tx_tab_r[vc].head.dstx 		<= pkt_in_tx_tab[vc].dx;
					flit_to_tx_tab_r[vc].head.dsty 		<= pkt_in_tx_tab[vc].dy;
					flit_to_tx_tab_r[vc].head.pkt_id 	<= pkt_in_tx_tab[vc].pkt_id;
					//flit_to_tx_tab_r[vc].head.nxt_route <= tb_pkg::get_next_route_for_tx(sx, sy, pkt_in_tx_tab[vc].dx, pkt_in_tx_tab[vc].dy);
					flit_to_tx_tab_r[vc].head.pkt_type 	<= none;
					flit_to_tx_tab_r[vc].head.payload 	<= '0;
				end
			end
		end
	end
	
	
	always_comb begin
		flit_to_noc.head.ftype = I;
		pkt_tab_id_ptr_w = -1;
		
		for (int vc=pkt_tab_id_ptr_r; vc<NUM_VCS+pkt_tab_id_ptr_r; vc++) begin
			if (flit_to_tx_tab_r[vc%NUM_VCS].head.ftype != I && credit_ctr_r[vc%NUM_VCS] > 0) begin
				pkt_tab_id_ptr_w = vc%NUM_VCS;
				break;
			end
		end
		
		if (pkt_tab_id_ptr_w != -1) begin
			flit_to_noc = flit_to_tx_tab_r[pkt_tab_id_ptr_w];
		end
		
	end
	
	
	
	//VC Alloc.
	function int get_avail_vcid_f();
		int vcid;
		get_avail_vcid_f = -1;
		
		for (int v=0; v<NUM_VCS; v++) begin
			vcid = (v + rr_vcid_ptr_r) % NUM_VCS;
			if (vcid_free_bm_r[vcid] && credit_ctr_r[vcid]>0) begin
				get_avail_vcid_f = vcid;
				break;
			end
		end
	endfunction
	
	
	
	//Credit management
	always_comb begin
		credit_ctr_w = credit_ctr_r;
		
		for (int vc=0; vc<NUM_VCS; vc++) begin
			credit_ctr_w[vc] = credit_ctr_w[vc] + credits_from_noc[vc];
		end
		
		if (flit_to_noc.head.ftype != I)
			credit_ctr_w[flit_to_noc.head.fvcid]--;
	end
	
	always_ff @(posedge clk or negedge arst_n) begin
		if (!arst_n) begin
			credit_ctr_r <= '{NUM_VCS{CREDITS_PER_VC}};
		end else begin
			for (int vc=0; vc<NUM_VCS; vc++) begin
				assert(credit_ctr_w[vc]>=0 && credit_ctr_w[vc]<=CREDITS_PER_VC) else
					$error("Credit counter our of range");
			end
			credit_ctr_r <= credit_ctr_w;
		end
	end
	
endmodule
