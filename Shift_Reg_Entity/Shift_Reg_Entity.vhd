library ieee;
use ieee.std_logic_1164.all;

--Defining the upper level entity for this shift register
--This shift register will recieve a 4 bit value from 
--the Keypad_Entity along with a shift signal
--This shift signal will tell the register when to perform a shift
--When shift is 1, the register will take the input number and place it 
--in the bit values of addrs (3 downto 0)
--The bit values that were in addrs (3 downto 0) will
--be placed in addrs (7 downto 4)
--A reset signal will be used to set the values of addrs to 0

entity Shift_Reg_Entity is
   port(number : in std_logic_vector(3 downto 0);
	     shift  : in std_logic;
		  reset  : in std_logic;
		  addrs  : out std_logic_vector(7 downto 0));
end entity;


--Creating the architecture of the program.
architecture shift_reg of Shift_Reg_Entity is
   --Creating a temporary signal for address to avoid 
	--Needing to declare address as a buffer
	signal address_Reg : std_logic_vector(7 downto 0) := "11111111";
begin
   
   --Defining a process that will be activated whenever reset or shift changes
	Shift_Process: process(reset,shift)
   
	begin
	   --Defining the reset state
		--If reset is activated, the values of address will be set to 0
		if(reset = '0') then
		   address_Reg <= "11111111";
		--Creating the shift algorythm if shift = 1
		elsif(shift'event and shift = '1') then
		   address_Reg <= address_Reg(3 downto 0) & number;
		end if;
	end process;
	addrs<=address_Reg;
end architecture;