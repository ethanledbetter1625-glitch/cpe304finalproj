--All testing done. 
--Debounce testing done. --EL 11/04/2026
--When you make changes, initial and date them with a comment.
--ALWAYS ALWAYS ALWAYS PULL FROM ORIGIN BEFORE MAKING CHANGES

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;
--EL 10/31/2026

entity FinalProject is
	port(clk_in : in std_logic;    --50 mhz board clock
		  key0 : in std_logic;      --active low
		  
		  --Graham Fales 11/14/2026 Start
		  --Adding the ports for the column and row buses for the keypad
		  row : inout std_logic_vector(3 downto 0);
		  column : inout std_logic_vector(2 downto 0);
		  --Graham Fales 11/14/2026 END
		  display0 : out std_logic_vector(6 downto 0);
		  display1 : out std_logic_vector(6 downto 0);
		  display2 : out std_logic_vector(6 downto 0);
		  sw       : in std_logic_vector(3 downto 0)); --raw switches, use sw_clean in logic
end FinalProject;

ARCHITECTURE FPArch OF FinalProject IS

	component clk_div
		generic (cnt_max : integer := 62500);
		port (clock_in : in std_logic; 
				clock_out : out std_logic);
	end component;
	--EL 10/30/26
	signal key_prev : std_logic := '1';
	constant price : integer range 0 to 999 := 135; --static price, $1.35
	signal paid    : integer range 0 to 999;
	signal num : integer range 0 to 999 := 0;
	signal dig0, dig1, dig2 : std_logic_vector(3 downto 0);
	signal clk_100hz : std_logic;
	--EL 10/31/26
	signal sw_clean : std_logic_vector(3 downto 0); --debounced switch levels
	signal sw_pulse : std_logic_vector(3 downto 0); --1 clk pulse on each switch up-flip
	--EL 11/04/2026
	
	--Graham Fales 11/14/2026 Start
	--Declaring the signals that will be used to carry information between the keypad entity and other entities
	--Note the Keypad_Entity requires a 50MHz clock
	
	--The following signal will connect to the address bus of the Keypad_Entity
	--This bus will record and save two 4-bit BCD digits when the Registor select signal
   --	(which has not been created yet) is set to 0
	signal address_k : std_logic_vector(7 downto 0);

	--The following signal will connect to the data bus of the Keypad_Entity
	--This bus will record and save three 4- bit BCD digits when the Registor select signal
   --	(which has not been created yet) is set to 1	
	signal data_kPad : std_logic_vector(11 downto 0);
	
	--Creating the registor select signal that will be used to change which values the keypad is recording
	signal reg_sel : std_logic := '0'; --Default means that the keypad will record the address
	
	--Creating signals for the RAM entity to connect to other entities
	
	--The following signal will be used to change the RAM between read mode and write mode
	--   This signal should be 0 for Write and 1 for Read
	signal R_W : std_logic;
	
	--This signal will be used to activate the RAM. I will act like an "enter" button
	--   The RAM will not sned or receive data unless this signal is pulled low
	signal Ram_Enter : std_logic;
	
	--This signal will send the address (item number) to the RAM for the 
	--   RAM to get the price and send back
	signal address_R : std_logic_vector(7 downto 0);
	--This signal will send data to the RAM for writing
	signal data_R_in : std_logic_vector(11 downto 0);
	
	--This signal will carry data away from the RAM;
	signal data_R_out : std_logic_vector(11 downto 0);
	--Graham Fales 11/14/2026 End
	
	
BEGIN
	dig0 <= std_logic_vector(to_unsigned(num mod 10, 4));
	dig1 <= std_logic_vector(to_unsigned((num / 10) mod 10, 4));
	dig2 <= std_logic_vector(to_unsigned(num / 100, 4));
	--calculate digits
	--EL 10/31/26
	
	--debounce on every switch
	--use sw_clean(i) for switches
	--generic map here overrides the default in debounce.vhd
	gen_db : for i in 0 to 3 generate
		 db_i : entity work.debounce
			  generic map (CNT_MAX => 500_000)
			  port map (
					clk      => clk_in,
					rst      => '0',
					sw_in    => sw(i),
					sw_out   => sw_clean(i),
					sw_pulse => sw_pulse(i)
			  );
	end generate;
	--EL 11/04/2026

	disp : entity work.Part2
		port map (xin => x"000" & dig2 & dig1 & dig0,
				  sevenseg1 => display0, sevenseg2 => display1, sevenseg3 => display2);
	calc : entity work.ChangeCalc
		port map (price => price, paid => paid, change => num, short => open,
				  quarters => open, dimes => open, nickels => open, pennies => open);
	pay : entity work.Payment
		port map (clk => clk_100hz, reset => '0', sw => sw_clean, paid => paid);
	--testing payment method
	--EL 11/04/2026 uses debounced switches
	
	div_btn : clk_div
		generic map (cnt_max => 250000) --100 hz from 50 mhz
		port map (clock_in => clk_in, clock_out => clk_100hz);
	--EL 11/04/2026
	
	--TODO: ram
	--Graham Fales 11/14/2026 Start
	--Instantiating the Keypad_Entity
	keypad : entity.work Keypad_Entity port map(clk_in,key0,reg_sel,row,column,address_k,data_kpad);
	
	--Instantiating the RAM_Entity
	Ram : entity.work RAM_Entity port map(clk_in,R_W,key0,enter,address_r,data_r_in,data_r_out);
	--Graham Fales 11/14/2026 End
END FPArch;

--if you need to make an instance of the clock with a value that is not 62500 (this is just an init value)
--do this:
--div_example : clk_div
--		generic map (cnt_max => 62500)
--		port map (clock_in => clk_in, clock_out => clk_example);
--EL 10/30/26

