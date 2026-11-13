library ieee;
use ieee.std_logic_1164.all;

--Defining the top level entity for the Keypad_Entity
--This entity will input a clk and reset signals. It will also input the row and column 
--of the keypad device
--It will output a 7 bit bus that will be sent to a decoder
entity Keypad_Entity is
   port(clk : in std_logic;
	     reset  : in std_logic;
		  Adrs_Data : in std_logic;
	     column : inout std_logic_vector( 2 downto 0);
		  row    : inout std_logic_vector( 3 downto 0);
		 
		  --Creating an output that will receive the values from the shift reg
		  address : out std_logic_vector(7 downto 0);
		  --Creating the data bus that will carry data from the shift reg
		  data : out std_logic_vector(11 downto 0));
		  
		  
		  --The following sections of code referencing displays are for testing only
		  --Please ignore
		  --shift : in std_logic;
		  --disp1 : out std_logic_vector(6 downto 0);
		  --disp2 : out std_logic_vector(6 downto 0));
		  
end Keypad_Entity;

--Defining the architecture of this entity
--This entity will have a state machine that use two states to read the keypad inputs
--It will also have temporary row and column signals that will store values for the row and column 

architecture keypad of Keypad_Entity is
   --Defining a state machine with three states, one for reading
	--the columns of the keypad, one for readind the rows of the keypad, 
	--and one for alerting the shift signal
   type state_machine is (column_rd,row_rd,shift_st,result_st); 
	signal state : state_machine;
	signal row_temp : std_logic_vector(3 downto 0);
	signal column_temp : std_logic_vector(2 downto 0);
	signal nextState : state_machine;
	--This signal will be used to tell the shift register when to shift
	signal shift : std_logic :='0';
	
	
	--Temporary address
	signal address_temp : std_logic_vector(7 downto 0) := "01110111";
	--Creating a temporary data bus for internal transmission
	signal data_temp : std_logic_vector(11 downto 0) := "111111111111";
	
	signal test : std_logic_vector( 7 downto 0) := "11111111"; --For debugging
	signal number : std_logic_vector(3 downto 0); -- For debugging
	
   --This signal will be used to pass the result of the keypad read into the decoder entity
   signal result: std_logic_vector(6 downto 0);
   --This signal will be used to retrieve the result of the decoder and pass it to the shift reg
   signal to_shift_num : std_logic_vector(3 downto 0);
	signal clk_slow : std_logic;--Slows down the clock so the elctronics have enough time to set up
	signal addrs_D : std_logic := '1'; --Creating a signal that will carry the input signal adrs_data to the shift reg
	--Testing for signal
	
	--signal LED_test : std_logic := '1';
 
	component clk_div
	   generic(count_mx : integer := 6000);
		port(clock_in : in std_logic; clock_out : out std_logic);
	end component;
	
begin
   --LED<=LED_test;
   addrs_D <= Adrs_Data;--Assigning the temporary signal addrs_D to the input to the entity
   clk_divider : clk_div port map(clk,clk_slow);
   --Telling the circuit what values to assign columns and rows so that they can 
	--Read on the proper clock pulse
	row <= "ZZZZ" when (nextState = row_rd) else "0000";
	column <= "ZZZ" when (nextState = column_rd) else
	"000";
   
	--shift <= '0';
	process(clk_slow,reset)

	begin	
	   --Defining the reset state
		if(reset = '0') then
		   result <= "1111111";
			shift <= '0';
			state <= row_rd;
			--LED<= '0';
		elsif(clk_slow'event and clk_slow = '1') then
		      --LED_test <= not LED_test; Dubbugging: display flashing LED
			   Case state is
				   when row_rd =>
						row_temp <= row;
						nextState <= column_rd;
						--shift <= '0';
						
					when column_rd =>
					   column_temp	<= column;
						nextState <= result_st;
					
					when result_st =>
					   result <= row_temp & column_temp;
						nextState <= shift_st;
						
					when others =>
					   if(result = "0111011" or result = "0111101" or result = "0111110" or result = "1011011" or result = "1011101" or
						result = "1011110" or result = "1101011" or result = "1101101" or result = "1101110" or 
						result = "1110011" or result = "1110101" or result = "1110110") then 
						--condition occurs when none of the buttons are pressed
						   shift <= '1';
						else shift <= '0';
						end if;
						nextState <= row_rd;
					end case;
		
		end if;
	   --Concatenating the various vectors
		state <= nextState;
		result <= row_temp & column_temp;
	end process;
	
						
   --Calling in the decoder entity to convert the 7 bit result inot a 4 bit recognizable
	--binary number
	decoder: entity work.Key_Decode_Entity port map(result,to_shift_num);
	--Calling in the shift register entity
	number <= "1000";
	shift_registor: entity work.Shift_Reg_Entity port map(to_shift_num,shift,reset,addrs_D,address_temp,data_temp);
	
	--The following code is for testing only. Please ignore
	--display1: entity work.seven_seg_decode port map(address(3 downto 0),disp1);
	--display2: entity work.seven_seg_decode port map(address(7 downto 4), disp2);
	address<= address_temp;
	data<= data_temp;
	
	
end keypad;