library ieee;
use ieee.std_logic_1164.all;

ENTITY Part2 is 
	port(xin       : in  std_logic_vector(29 downto 0); --EL 11/11/26
		  sevenseg1 : out std_logic_vector(6 downto 0);
		  sevenseg2 : out std_logic_vector(6 downto 0);
		  sevenseg3 : out std_logic_vector(6 downto 0);
		  sevenseg4 : out std_logic_vector(6 downto 0);
		  sevenseg5 : out std_logic_vector(6 downto 0);
		  sevenseg6 : out std_logic_vector(6 downto 0));
END Part2;

ARCHITECTURE decode OF Part2 IS
BEGIN
	--EL 10/30/26
	display1: entity work.LAB5 port map (xin(4 downto 0),   sevenseg1);
	display2: entity work.LAB5 port map (xin(9 downto 5),   sevenseg2);
	display3: entity work.LAB5 port map (xin(14 downto 10),  sevenseg3);
	display4: entity work.LAB5 port map (xin(19 downto 15), sevenseg4);
	display5: entity work.LAB5 port map (xin(24 downto 20), sevenseg5);
	display6: entity work.LAB5 port map (xin(29 downto 25), sevenseg6);
END decode;