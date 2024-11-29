library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.router_pkg_vhdl.all;

-- This route computation module is for a 2D mesh NoC.
-- The Nodes of the NoC are addressed using the (X,Y) ids of the 2D mesh, as shown below 
-- y/x	|	0		1		2		3
-- -----|--------------------------------
-- 0	|	(0,0)	(1,0)	(2,0)	(3,0)
-- 1	|	(0,1)	(1,1)	(2,1)	(3,1)
-- 2	|	(0,2)	(1,2)	(2,2)	(3,2)
-- 3	|	(0,3)	(1,3)	(2,3)	(3,3)





entity rc is
   generic (
    mode : integer := 2;
    in_port : dir_t := E
    );
   port (
    -- Input current location of the packet header
    LOCAL_X : in std_logic_vector(DIM_BITS-1 downto 0); -- Specifies the X id of the current NoC router
    LOCAL_Y : in std_logic_vector(DIM_BITS-1 downto 0); -- Specifies the Y id of the current NoC router
    
    -- Input destination address for the packet
    dst_x   : in std_logic_vector(DIM_BITS-1 downto 0); -- Specifies the X id of the destination NoC router
    dst_y   : in std_logic_vector(DIM_BITS-1 downto 0); -- Specifies the Y id of the destination NoC router
	
    -- Input VC and credit information in the current location of the packet header
    -- You can check the signal types in packages/router_pkg_vhdl.vhdl
	out_vc_free : in out_vc_free_t;                     -- This signal is set if an output VC is free. It is accessed by specifying the output port and output VC-id which is being checked. E.g. out_vc_free[N][0] to check if output VC-0 in the N direction is free.
	ovc_credits_count_r : in ovc_credits_array_t;       -- This signal specifies available credits in an output VC. It is accessed by specifying the output port and output VC-id which is being checked. E.g. ovc_credits_count_r[N][0] will give the number of available credits in VC-0 of the output port N.
    random : in std_logic;
    -- The direction the input packet should take
    rc_out  : out dir_t
    );
end entity rc;


architecture behavioral of rc is
    signal xy_out, yx_out : dir_t;
    signal out0, out1 : dir_t;
    signal two_choices : std_logic; 

begin
    xy_proc : process(LOCAL_X, LOCAL_Y, dst_x, dst_y)
    begin
        if unsigned(dst_x) > unsigned(LOCAL_X) then
            xy_out <= E;
        elsif unsigned(dst_x) < unsigned(LOCAL_X) then
            xy_out <= W;
        elsif unsigned(dst_y) > unsigned(LOCAL_Y) then
            xy_out <= S;
        elsif unsigned(dst_y) < unsigned(LOCAL_Y) then
            xy_out <= N;
        else
            xy_out <= R;
        end if;
    end process xy_proc;

    yx_proc : process(LOCAL_X, LOCAL_Y, dst_x, dst_y)
    begin
        if unsigned(dst_y) > unsigned(LOCAL_Y) then
            yx_out <= S;
        elsif unsigned(dst_y) < unsigned(LOCAL_Y) then
            yx_out <= N;
        elsif unsigned(dst_x) > unsigned(LOCAL_X) then
            yx_out <= E;
        elsif unsigned(dst_x) < unsigned(LOCAL_X) then
            yx_out <= W;
        else
            yx_out <= R;
        end if;
    end process yx_proc;

    
        in_port_check: if in_port = E or in_port = R or in_port = DI generate
            west_first_west: process(xy_out, yx_out) begin
                out1 <= yx_out;
                if xy_out = W or yx_out = W then
                    two_choices <= '0';
                    out0 <= W;
                else 
                    two_choices <= '1';
                    out0 <= xy_out;
                end if;
            end process west_first_west;
        else generate
            west_first_not_west: process(xy_out, yx_out) begin
                out1 <= yx_out;
                if xy_out = W then
                    two_choices <= '0';
                    out0 <= yx_out;
                elsif yx_out = W then
                    two_choices <= '0';
                    out0 <= xy_out;
                else
                    two_choices <= '1';
                    out0 <= xy_out;
                end if;
            end process west_first_not_west;
        end generate;


        decision_mode: if mode = 0 generate
            credits_block: block
                constant sum_width : integer := clog2_vhdl(NUM_VCS * (2**CREDIT_CTR_WIDTH - 1) + 1);
		        type credits_sum_arr_t is array (0 to NUM_PORTS-1) of unsigned(sum_width - 1 downto 0);
                type csum_arr_t is array (natural range <>) of std_logic_vector(CREDIT_CTR_WIDTH-1 downto 0);
                signal credits_sum_arr: credits_sum_arr_t;   

                function adder_tree_func(
                    arr : in csum_arr_t
                ) return unsigned is
                    constant half : integer := arr'LOW + (arr'LENGTH / 2);
                begin
                    if arr'LENGTH = 1 then
                        return unsigned(arr(arr'LOW));
                    else
                        return ('0' & adder_tree_func(arr(arr'LOW to half-1))) + ('0' & adder_tree_func(arr(half to arr'HIGH)));
                    end if;
                end function;

            begin
                
                array_stuff: for dir in 0 to NUM_PORTS -1 generate
                    signal credits_1d : csum_arr_t(0 to NUM_VCS-1);
                begin
                    credits_sum_arr(dir) <= adder_tree_func(credits_1d);
                    inner_loop: for vc in 0 to NUM_VCS-1 generate
                        credits_1d(vc) <= ovc_credits_count_r(dir, vc);
                    end generate inner_loop;
                    
                end generate array_stuff;

                output_p: process (two_choices, credits_sum_arr, out0, out1)
                begin
                    if two_choices = '1' then
                        if credits_sum_arr(to_integer(unsigned(out0))) > credits_sum_arr(to_integer(unsigned(out1))) then
                            rc_out <= out0;
                        else
                            rc_out <= out1;
                        end if;
                    else
                        rc_out <= out0;
                    end if;
                end process output_p;

            end block credits_block;

        elsif mode = 1 generate
            vcs_block: block
                constant sum_width : integer := clog2_vhdl(NUM_VCS + 1);
		        type free_vcs_sum_arr_t is array (0 to NUM_PORTS-1 ) of unsigned(sum_width - 1 downto 0);
                type vcsum_arr_t is array (natural range <>) of std_logic_vector(0 downto 0);
                signal free_vcs_sum_arr: free_vcs_sum_arr_t;   

                function adder_tree_func(
                    arr : in vcsum_arr_t
                ) return unsigned is
                    constant half : integer := arr'LOW + (arr'LENGTH / 2);
                begin
                    if arr'LENGTH = 1 then
                        return unsigned(arr(arr'LOW));
                    else
                        return ('0' & adder_tree_func(arr(arr'LOW to half-1))) + ('0' & adder_tree_func(arr(half to arr'HIGH)));
                    end if;
                end function;

            begin
                
                array_stuff: for dir in 0 to NUM_PORTS-1 generate
                    signal free_vcs_1d : vcsum_arr_t(0 to NUM_VCS-1);
                begin
                    inner_loop: for vc in 0 to NUM_VCS-1 generate
                        free_vcs_1d(vc) <= "1" when out_vc_free(dir, vc) = '1' else "0";
                    end generate inner_loop;
                    free_vcs_sum_arr(dir) <= adder_tree_func(free_vcs_1d);
                end generate array_stuff;

                output_p: process (two_choices, free_vcs_sum_arr, out0, out1)
                begin
                    if two_choices = '1' then
                        if free_vcs_sum_arr(to_integer(unsigned(out0))) > free_vcs_sum_arr(to_integer(unsigned(out1))) then
                            rc_out <= out0;
                        else
                            rc_out <= out1;
                        end if;
                    else
                        rc_out <= out0;
                    end if;
                end process output_p;

            end block vcs_block;
        
        elsif mode = 2 generate
            rc_out <= out1 when (random and two_choices) = '1' else out0; 
        
        else generate
            rc_out <= xy_out;
        end generate;


end architecture behavioral;
