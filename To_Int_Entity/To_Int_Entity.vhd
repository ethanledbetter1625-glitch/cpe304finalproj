library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--splits a 12 bit bcd price into 3 integer digits
--ex: x"125" -> Int3 = 1, Int2 = 2, Int1 = 5 -> $1.25
entity To_Int_Entity is
   port(Data : in std_logic_vector(11 downto 0);
	     Int3 : out integer range 0 to 9;  --hundreds
		  Int2 : out integer range 0 to 9;  --tens
		  Int1 : out integer range 0 to 9); --ones
end;

architecture converter of To_Int_Entity is
	--4 bits can be 0-15, so the temps need that full range --EL 11/27/2026
   Signal Int3Temp, Int2Temp, Int1Temp : integer range 0 to 15;
begin
   Int3Temp <= to_integer(unsigned(Data(11 downto 8)));
   Int2Temp <= to_integer(unsigned(Data(7 downto 4)));
   Int1Temp <= to_integer(unsigned(Data(3 downto 0)));
	
	--anything over 9 isnt bcd, cap it so the price never goes past 999 --EL 11/27/2026
	Int3 <= Int3Temp when Int3Temp <= 9 else 9;
	Int2 <= Int2Temp when Int2Temp <= 9 else 9;
	Int1 <= Int1Temp when Int1Temp <= 9 else 9;
	
end architecture;