library ieee;
use ieee.std_logic_1164.all;

--Setting up the entity that will control this program. It
--will have a clk input, a reset input, column and row inputs,
--and 2 7-bit display signals bit address output

entity Test_Entity is
   port(clk : in std_logic;
	     reset : in std_logic;
		  reg_sel : in std_logic;
		  column : inout std_logic_vector(2 downto 0);
		  row : inout std_logic_vector(3 downto 0);
		  r_w : in std_logic;
		  enter : in std_logic;
		  disp1 : out std_logic_vector(6 downto 0);
		  disp2 : out std_logic_vector(6 downto 0);
		  disp3 : out std_logic_vector(6 downto 0);
		  disp4 : out std_logic_vector(6 downto 0);
		  disp5 : out std_logic_vector(6 downto 0);
		  disp6 : out std_logic_vector(6 downto 0));
end entity;


--Creating the architecture
--This will include an internal signal called address which will carry
--the output of the keypad entity to the display entity
architecture test of Test_Entity is
   signal address : std_logic_vector(7 downto 0) :="11111111"; --for address
	signal data_in : std_logic_vector(11 downto 0);
	signal display : std_logic_vector(11 downto 0); --This will be put into the displays and will be changed with multiplexers
	signal data_out : std_logic_vector(11 downto 0); --Will receive data from the RAM
	
begin
   --Bringing the keypad entity into this entity
	keypad: entity work.Keypad_Entity port map(clk,reset,reg_sel,column,row,address,data_in);
	--Declaring display entities
	display <= "1111" & address when reg_sel = '1' else
	           data_in;
	Display1: entity work.Seven_Seg_Decode port map(display(3 downto 0),disp1);
	Display2: entity work.Seven_Seg_Decode port map(display(7 downto 4),disp2);
	Display3: entity work.Seven_Seg_Decode port map(display(11 downto 8),disp3);
	Display4: entity work.Seven_Seg_Decode port map(data_out(3 downto 0),disp4);
	Display5: entity work.Seven_Seg_Decode port map(data_out(7 downto 4),disp5);
	Display6: entity work.Seven_Seg_Decode port map(data_out(11 downto 8),disp6);
	
	--Creating the Ram_Entity instantiation
	Ram: entity work.Ram_Entity port map(clk,r_w,reset,enter,address,data_in,data_out);
end architecture;