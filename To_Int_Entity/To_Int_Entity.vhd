library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--Building an entity that will have 1 -- 12 bit input and 
--3 -- integer outputs
entity To_Int_Entity is
   port(Data : in std_logic_vector(11 downto 0);
	     Int3 : out integer range 0 to 4;
		  Int2 : out integer range 0 to 4;
		  Int1 : out integer range 0 to 4);
end;

--Creating the architecture of this program

architecture converter of To_Int_Entity is
   --Creating three internal integer signals that will have the three sections of
	--The std logic vector assigned to them
	--These signals will then be assigned to the three integer outputs
   Signal Int3Temp, Int2Temp, Int1Temp : integer range 0 to 4;
begin
   Int3Temp <= to_integer(unsigned(Data(11 downto 8)));
   Int2Temp <= to_integer(unsigned(Data(7 downto 4)));
   Int1Temp <= to_integer(unsigned(Data(3 downto 0)));
	
	Int3 <= Int3Temp;
	Int2 <= Int2Temp;
	Int1 <= Int1Temp;
	
end architecture;
	
