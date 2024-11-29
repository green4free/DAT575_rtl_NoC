library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package router_pkg_vhdl is
	
	constant NUM_PORTS 		: integer := 5;
	constant NUM_VCS 		: integer := 4;
	constant CREDITS_PER_VC : integer := 6;
	
	constant CREDIT_CTR_WIDTH : integer := 3;
	constant DIRECTION_BITS : integer := 3;
	constant DIM_BITS		: integer := 5;
	
	subtype dir_t is std_logic_vector(DIRECTION_BITS-1 downto 0);
    
	-- Define direction constants (E, W, S, N, R) as std_logic_vector literals
    constant N  : dir_t := "000";
    constant E  : dir_t := "001";
    constant S  : dir_t := "010";
    constant W  : dir_t := "011";
    constant R  : dir_t := "100";
	constant DI : dir_t := "101";
	
	type out_vc_free_t is array (0 to NUM_PORTS-1, 0 to NUM_VCS-1) of std_logic;
	type ovc_credits_array_t is array (0 to NUM_PORTS-1, 0 to NUM_VCS-1) of std_logic_vector(CREDIT_CTR_WIDTH-1 downto 0);

	function clog2_vhdl(value : integer) return integer;
    
end package router_pkg_vhdl;


package body router_pkg_vhdl is
	function clog2_vhdl(value : integer) return integer is
    	variable result : integer := 0;
    	variable temp   : integer := value - 1; -- Adjust for ceiling
	begin
	    while temp > 0 loop
	        temp := temp / 2;
	        result := result + 1;
	    end loop;
	    return result;
	end function;
end package body router_pkg_vhdl;