library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--Declaring an intity name clk_div
entity clk_div is
   --Defining the generic values 
   generic(count_mx: integer:=12500000);
	--Defining port signals
   port(clock_in: in std_logic;
	     clock_out: out std_logic);

--Ending the entity
end clk_div;

--Defining the architecture that will transform a 50MHz clock into a 2Hz clock
architecture clk_div_arch of clk_div is
begin
   process(clock_in) is
	
	   variable counter: integer range 0 to count_mx;
		variable toggle : std_logic;
		
	begin
	
	   --Defining an if-then statment to divide up the clock
		if(clock_in'event and clock_in = '1') then
		   counter:=counter+1;
			if(counter = count_mx) then
			   counter:=0;
				
				toggle:=not toggle;
				
			end if;
			
		end if;
		clock_out <= toggle;
		
	end process;
end clk_div_arch;
		