--All testing done. 
--When you make changes, initial and date them with a comment.
--ALWAYS ALWAYS ALWAYS PULL FROM ORIGIN BEFORE MAKING CHANGES

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
--EL 10/28/2026

entity FinalProject is
	port(clk_in : in std_logic);
end FinalProject;

ARCHITECTURE FPArch OF FinalProject IS

		component clk_div
			generic (cnt_max : integer := 62500);
			port (clock_in : in std_logic; 
					clock_out : out std_logic);
		end component;
BEGIN

END FPArch;

--if you need to make an instance of the clock with a value that is not 62500 (this is just an init value)
--do this:
--div_example : clk_div
--		generic map (cnt_max => 62500)
--		port map (clock_in => clk_in, clock_out => clk_example);
