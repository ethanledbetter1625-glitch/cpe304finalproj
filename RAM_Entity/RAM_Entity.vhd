library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RAM_Entity is
   port(Clk : in std_logic; --Input for the clock that will control the FSM
	     R_W : in std_logic; --Read/Write input that will control the FSM
		  Reset : in std_logic; --Reset input for the FSM
		  --Creating an input that will carry the address of the Ram into the
		  --FSM
		  Address : in std_logic_vector(7 downto 0);
		  --Creating a bus that will carry Data from the entity or 
		  --Bring data to the entity
		  Data : inout std_logic_vector(11 downto 0));
end entity;


architecture RAM of Ram_Entity is
   --Creating an array that will have 4 rows and 4 columns. 
   --Inside of each row and column a std_logic_vector of 12 bits is stored
   --These 21 bits will house the prices of the items in three groups of 
   --Seven bits. The first group is the most significant number of the 
   --price. Second group is the second most significant number of the price
   --The third group is the last value of the price	
	type RAM_Setup is array (3 downto 0, 3 downto 0) of std_logic_vector(11 downto 0);
   signal RAM : RAM_Setup;
	--Creating two signasl to temporally carry the address to the RAM array
	--After it has been converted to an integers
	signal Adrs1 : integer range 0 to 4;
	signal Adrs2 : integer range 0 to 4;
	--Creating an enumerated type that will contain the states for the FSM
	type FSM_states is (standby,write_st,read_st);
	--Creating a signal that will contain the state of the FSM
	signal state : FSM_states := standby;
begin
   
	Adrs1 <= to_integer(unsigned(Address(7 downto 4))-1);
	Adrs2 <= to_integer(unsigned(Address(3 downto 0))-1);
	
	RAM_FSM: process(Clk, Reset) is
	   
	begin
	    --Creating FSM; this section is the reset section
	   if (reset = '0') then
		   --Creating two for loops that will populate the RAM array
			--To default Values
		   for i in 3 downto 0 loop
			   for j in 3 downto 0 loop
				   RAM(i,j) <= "000100000000";
				end loop;
			end loop;
		--Building the FSM with a case statement
		elsif (Clk'event and Clk = '1') then
		   Case state is 
			   when Standby => 
			      if (R_W = '0') then
				      state <= write_st;
					else state <= read_st;
				   end if;
				
				when write_st =>
				   RAM(Adrs1,Adrs2)<= Data;
					if (R_W = '1') then
					   state <= read_st;
					else state <= write_st;
					end if;
					
				when read_st =>
				   Data <= RAM(Adrs1,Adrs2);
					if (R_W = '0') then
					   state <= write_st;
					else state <= read_st;
					end if;
					
				when others =>
				   state <= Standby;
			end case;
			end if;
		end process;
end architecture;
					
		   
		
		
