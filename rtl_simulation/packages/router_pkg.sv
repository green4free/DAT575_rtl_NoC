`define _DEBUG_		//when defined, it turns SV assertions on from the input_block_vc.sv
//`define SYNTHESIS		//when defined, it removes all SV assertion statements independent of _DEBUG_

`ifndef _ROUTER_PKG_SV_
`define _ROUTER_PKG_SV_

package router_pkg;
	//-----------MAKE CHANGES IN THE FOLLOWING-----------
	
	localparam MAX_X = 8;
	localparam MAX_Y = 8;
	
	localparam int unsigned NOC_LINK_W = 128;
	localparam int unsigned NUM_VCS = 4;
	localparam int unsigned CREDITS_PER_VC = 6;
	
	//-----------DO NOT MAKE CHANGES IN THE FOLLOWING-----------
	
	localparam int unsigned NUM_PORTS = 5;
	localparam int unsigned CREDIT_CTR_WIDTH = $clog2(CREDITS_PER_VC);
	localparam int unsigned VC_BUFFER_PTR_WIDTH = $clog2(CREDITS_PER_VC);
	
	localparam int unsigned VC_ID_BITS = log2N_ptr(NUM_VCS);
	localparam int unsigned DIM_BITS = 5;
	localparam int unsigned PKT_ID_BITS = 32;
	localparam int unsigned FLIT_TYPE_BITS = 3;
	localparam int unsigned DIRECTION_BITS = 3;
	localparam int unsigned PKT_TYPE_BITS = 3;
	localparam int unsigned CH_STATUS_BITS = FLIT_TYPE_BITS + VC_ID_BITS;
	localparam int unsigned CH_BITS = NOC_LINK_W + CH_STATUS_BITS;
	
	
	typedef enum logic [FLIT_TYPE_BITS-1:0] {I='0, H=1, B=2, T=3, HT=4} ftype_t;
	typedef enum logic [2:0] {IDLE, RC, VA, SA, A} vc_states_t;
	typedef enum logic [DIRECTION_BITS-1:0] {N=0, E=1, S=2, W=3, R=4, DI=5} dir_t;	//DI IDLE DIRECTION
	typedef enum logic [PKT_TYPE_BITS-1:0] { none=0, rd_req=1, wr_req=2, rd_resp=3, wr_resp=4 } pkt_types_t;
	
	typedef union packed {	//channel_t has both control and data bits in it
		//ib fifo does not store fvcid 
		struct packed {
			ftype_t ftype;
			logic [VC_ID_BITS-1:0] fvcid;	//flit vc id
			//following is NOC_LINK_W wide
			logic [DIM_BITS-1:0] srcx, srcy, dstx, dsty;
			logic [PKT_ID_BITS-1:0] pkt_id;
			pkt_types_t pkt_type;
			logic [NOC_LINK_W - 4*DIM_BITS - PKT_ID_BITS - PKT_TYPE_BITS -1 : 0] payload;
		} head;
		
		struct packed {
			ftype_t ftype;
			logic [VC_ID_BITS-1:0] fvcid;	//flit vc id
			//following is NOC_LINK_W wide
			logic [NOC_LINK_W-1:0] data;
		} body;	//also tail
		
	} channel_t;
	
	
	function automatic int log2N_ctr (input int N); 
		/*int tmp = 0;
		real n=N;
		do begin
			n=n/2;
			tmp++;
		end while(n>=1);
		return tmp;*/
		return (N+1 <= 2) ? 1 : (N+1 <= 4) ? 2 : (N+1 <= 8) ? 3 : (N+1 <= 16) ? 4 : (N+1 <= 32) ? 5 : (N+1 <= 64) ? 6 : 7;
	endfunction
	
	function automatic int log2N_ptr (input int N); 
	/*	int tmp = 0;
		real n=N;
		do begin
			n=n/2;
			tmp++;
		end while(n>1);
		return tmp;
		*/
		return (N <= 2) ? 1 : (N <= 4) ? 2 : (N <= 8) ? 3 : (N <= 16) ? 4 : (N <= 32) ? 5 : (N <= 64) ? 6 : 7;
		
	endfunction
	
endpackage : router_pkg

`endif
/*
COMMENTS
1. Iincase of only 1 vc, the wire 'flit_vc_id' in channel_t will still exist and should be removed
2. check log2N_ctr and log2N_ptr when N=1 and N=0 
3. updated CH_BITS and CH_STATUS_BITS
4. reduce the no. of states in vc_states_t

*/
