library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--Building an entity that will have 1 -- 12 bit input and 
--3 -- integer outputs
--  Data(11 downto 8) = hundreds digit, Data(7 downto 4) = tens digit, Data(3 downto 0) = ones digit (bcd)
--  ex: x"125" -> Int3 = 1, Int2 = 2, Int1 = 5 -> $1.25
entity To_Int_Entity is
   port(Data : in std_logic_vector(11 downto 0);
	     Int3 : out integer range 0 to 9;  --was 0 to 10, a bcd digit only goes to 9 --EL 11/27/2026
		  Int2 : out integer range 0 to 9;
		  Int1 : out integer range 0 to 9);
end;

--Creating the architecture of this program

architecture converter of To_Int_Entity is
   --Creating three internal integer signals that will have the three sections of
	--The std logic vector assigned to them
	--These signals will then be assigned to the three integer outputs
	--range was 0 to 4, which can't hold bcd digits 5-9 (prices like $1.95 would come out wrong
	--  once prices can change). 4 bits can be 0-15 so the range has to cover that --EL 11/27/2026
   Signal Int3Temp, Int2Temp, Int1Temp : integer range 0 to 15;
begin
   Int3Temp <= to_integer(unsigned(Data(11 downto 8)));
   Int2Temp <= to_integer(unsigned(Data(7 downto 4)));
   Int1Temp <= to_integer(unsigned(Data(3 downto 0)));
	
	--a real bcd digit is 0-9. if the ram ever hands back 10-15 (not bcd), cap it at 9
	--so the price math in FinalProject never goes past 999 --EL 11/27/2026
	Int3 <= Int3Temp when Int3Temp <= 9 else 9;
	Int2 <= Int2Temp when Int2Temp <= 9 else 9;
	Int1 <= Int1Temp when Int1Temp <= 9 else 9;
	
end architecture;