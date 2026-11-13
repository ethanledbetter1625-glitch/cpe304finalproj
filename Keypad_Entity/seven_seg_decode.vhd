--Declaring the Library that will be used
library IEEE;
use IEEE.std_logic_1164.all;
--Defining the entity that will contain the decoder
entity seven_seg_decode is
	port
	(
		-- Input ports
		bin : in  std_logic_vector(3 downto 0);

		-- Output ports
		hex	: out std_logic_vector(6 downto 0));
end seven_seg_decode;

--Defining the architecture
architecture Decoder of seven_seg_decode is

begin
--Using a when-else structure to compare the 
--Incoming values to the outgoing values

   hex <= "1000000" when bin = "0000" else --creating zero on LED 
	       "1111001" when bin = "0001" else --creating 1
			 "0100100" when bin = "0010" else -- creating 2
			 "0110000" when bin = "0011" else --3
			 "0011001" when bin = "0100" else --4
			 "0010010" when bin = "0101" else --5
			 "0000010" when bin = "0110" else --6
			 "1111000" when bin = "0111" else --7
			 "0000000" when bin = "1000" else --8
			 "0011000" when bin = "1001" else --9
			 "1111111"; --default catch all
end Decoder;


