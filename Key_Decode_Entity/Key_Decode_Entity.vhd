library ieee;
use ieee.std_logic_1164.all;

--Defining the overall entity for this design
--This design will have one 7 bit input and one 4 bit input
--The input will be convereted into bit strings that can more easily be 
--Convereted into integers
entity Key_Decode_Entity is
   port(keypad_num : in std_logic_vector(6 downto 0);
	     digit      : out std_logic_vector(3 downto 0));
end entity;

--Creating the architecture of this program. This program 
--will use when-else statements to assign 4 bit values to the digit signal
architecture convert of Key_Decode_Entity is
   
begin
   
	digit <= "0000" when keypad_num = "1110101" else
	         "0001" when keypad_num = "0111011" else
				"0010" when keypad_num = "0111101" else
				"0011" when keypad_num = "0111110" else
				"0100" when keypad_num = "1011011" else
				"0101" when keypad_num = "1011101" else
				"0110" when keypad_num = "1011110" else
				"0111" when keypad_num = "1101011" else
				"1000" when keypad_num = "1101101" else
				"1001" when keypad_num = "1101110" else
				"1111";
end architecture;