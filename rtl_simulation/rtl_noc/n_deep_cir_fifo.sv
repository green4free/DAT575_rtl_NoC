`include "router_pkg.sv"
import router_pkg::*;


module n_deep_cir_fifo #(
	parameter dir_t LOCAL_PORT = W,
	parameter _vc_id = 0,
	parameter _ctr_width = 3,
	parameter _ptr_width = 2,
	parameter _fifo_depth = 4
	)(
	
`ifndef SYNTHESIS
	input logic [DIM_BITS-1:0] LOCAL_X,
	input logic [DIM_BITS-1:0] LOCAL_Y,
`endif
	
	input logic clk, arst_n,
	input logic [CH_BITS-VC_ID_BITS-1:0] din,
	input logic wr, rd,
	
	output logic [CH_BITS-VC_ID_BITS-1:0] dout,
	output logic [_ctr_width-1:0] count_r = '0
	);
	
	logic [CH_BITS-VC_ID_BITS-1:0] buff_r [0:_fifo_depth-1];
	logic [_ptr_width-1:0] head_r, tail_r;
	
	
	//read
	assign dout = buff_r[tail_r];
		
	//write
	always_ff @(posedge clk) begin
		if(!arst_n) begin
			for (int i = 0; i<_fifo_depth; i++)
				buff_r[i] <= '0;
		end else if(wr) begin
			buff_r[head_r] <= din;
		end
	end
	
	//update tail_r
	always_ff @(posedge clk) begin
		if(!arst_n)
			tail_r <= '0;
		else if(rd)
			tail_r <= (tail_r==_fifo_depth - 1'b1) ? '0 : tail_r+1'b1;
	end
	
	//update head_r
	always_ff @(posedge clk) begin
		if(!arst_n)
			head_r <= '0;
		else if(wr)
			head_r <= (head_r==_fifo_depth -1'b1) ? '0 : head_r + 1'b1;
	end
	
	//update count_r
	always_ff @(posedge clk) begin
		if(!arst_n) 
			count_r <= '0;
		else begin
			case ({rd, wr}) 
			2'b01: 	count_r <= (count_r==_fifo_depth[_ctr_width-1:0]) ? '0 : count_r + 1'b1;	//write
			2'b10: 	count_r <= (count_r==0) ? _fifo_depth : count_r - 1'b1;	//read
			default:count_r <= count_r;
			endcase
		end
	end
	
	
	
	`ifndef SYNTHESIS
	logic [_ctr_width:0] count_debug = '0;
	
	always_ff @(posedge clk) begin
		if(!arst_n) 
			count_debug <= '0;
		else begin
			
			assert (!(count_debug == '0 && rd == 1'b1)) else if(arst_n) $error("N_DEEP_CIR_FIFO(%1d,%1d,%1d,%1d): EMPTY READ", LOCAL_X, LOCAL_Y, LOCAL_PORT, _vc_id);
			assert (!(count_debug >= _fifo_depth && wr == 1'b1)) else if(arst_n) $error("N_DEEP_CIR_FIFO(%1d,%1d,%1d,%1d): FULL WRITE", LOCAL_X, LOCAL_Y, LOCAL_PORT, _vc_id);
			
			case ({rd, wr}) 
			2'b00:	count_debug <= count_debug;
			2'b01:	count_debug <= count_debug + 1'b1;
			2'b10:	count_debug <= count_debug - 1'b1;
			2'b11:	count_debug <= count_debug;
			endcase
		end
	end
	`endif
	
endmodule

/*	COMMENTS
this fifo does nto store the vcid of the channel_t.  the output of the the fifo of channel_t contains 'd0 as vcid. this vcid is not used in the input block. it is only appended for the the output to conform to the channel_t in the ib

*/