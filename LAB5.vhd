LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY LAB5 is
	port(inp : in std_logic_vector(3 downto 0); 
		  outp : out std_logic_vector(6 downto 0));
END LAB5;


ARCHITECTURE LEDS OF LAB5 IS
BEGIN
	outp <= "1000000" when inp = "0000" else
			  "1111001" when inp = "0001" else
			  "0100100" when inp = "0010" else
			  "0110000" when inp = "0011" else
			  "0011001" when inp = "0100" else
			  "0010010" when inp = "0101" else
			  "0000010" when inp = "0110" else
			  "1111000" when inp = "0111" else
			  "0000000" when inp = "1000" else
			  "0011000" when inp = "1001" else
			  "0111100" when inp = "1010" else -- * (segs 0,1,6)
			  "0001001" when inp = "1011" else -- H
			  "1000110" when inp = "1100" else
			  "0100001" when inp = "1101" else
			  "0000110" when inp = "1110" else
			  "1111111" when inp = "1111" else -- blank
			  "1111111";
END LEDS;