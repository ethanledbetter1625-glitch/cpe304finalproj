library ieee;
use ieee.std_logic_1164.all;

ENTITY LAB5 is
	port(inp : in std_logic_vector(4 downto 0); --5 bits, codes 0-15 same as before --EL 11/11/2026
		  outp : out std_logic_vector(6 downto 0));
END LAB5;

ARCHITECTURE LEDS OF LAB5 IS
BEGIN
	outp <= "1000000" when inp = "00000" else
			  "1111001" when inp = "00001" else
			  "0100100" when inp = "00010" else
			  "0110000" when inp = "00011" else
			  "0011001" when inp = "00100" else
			  "0010010" when inp = "00101" else
			  "0000010" when inp = "00110" else
			  "1111000" when inp = "00111" else
			  "0000000" when inp = "01000" else
			  "0011000" when inp = "01001" else
			  "0111100" when inp = "01010" else -- * (segs 0,1,6)
			  "0001001" when inp = "01011" else -- H
			  "1000110" when inp = "01100" else -- C
			  "0100001" when inp = "01101" else -- d
			  "0000110" when inp = "01110" else -- E
			  "1111111" when inp = "01111" else -- blank
			  "0001000" when inp = "10000" else -- A     --EL 11/11/2026
			  "0010000" when inp = "10001" else -- g
			  "0010010" when inp = "10010" else -- S (same as 5)
			  "1000111" when inp = "10011" else -- L
			  "0101111" when inp = "10100" else -- r
			  "0001011" when inp = "10101" else -- h
			  "0001110" when inp = "10110" else -- F
			  "0000111" when inp = "10111" else -- t
			  "0111111" when inp = "11000" else -- dash
			  "1111111";
END LEDS;

--copy these to the constants section in main file: 
-- 	--lab5 codes
--	constant C_0     : std_logic_vector(4 downto 0) := "00000";
--	constant C_1     : std_logic_vector(4 downto 0) := "00001";
--	constant C_2     : std_logic_vector(4 downto 0) := "00010";
--	constant C_3     : std_logic_vector(4 downto 0) := "00011";
--	constant C_4     : std_logic_vector(4 downto 0) := "00100";
--	constant C_5     : std_logic_vector(4 downto 0) := "00101";
--	constant C_6     : std_logic_vector(4 downto 0) := "00110";
--	constant C_7     : std_logic_vector(4 downto 0) := "00111";
--	constant C_8     : std_logic_vector(4 downto 0) := "01000";
--	constant C_9     : std_logic_vector(4 downto 0) := "01001";
--	constant C_STAR  : std_logic_vector(4 downto 0) := "01010";
--	constant C_H     : std_logic_vector(4 downto 0) := "01011";
--	constant C_C     : std_logic_vector(4 downto 0) := "01100";
--	constant C_D     : std_logic_vector(4 downto 0) := "01101";
--	constant C_E     : std_logic_vector(4 downto 0) := "01110";
--	constant C_BLANK : std_logic_vector(4 downto 0) := "01111";
--	constant C_A     : std_logic_vector(4 downto 0) := "10000";
--	constant C_G     : std_logic_vector(4 downto 0) := "10001";
--	constant C_S     : std_logic_vector(4 downto 0) := "10010";
--	constant C_L     : std_logic_vector(4 downto 0) := "10011";
--	constant C_R     : std_logic_vector(4 downto 0) := "10100";
--	constant C_LH    : std_logic_vector(4 downto 0) := "10101"; --lowercase h
--	constant C_F     : std_logic_vector(4 downto 0) := "10110";
--	constant C_T     : std_logic_vector(4 downto 0) := "10111";
--	constant C_DASH  : std_logic_vector(4 downto 0) := "11000";