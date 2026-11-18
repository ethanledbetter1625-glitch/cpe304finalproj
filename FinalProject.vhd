--All testing done. 
--Debounce testing done. --EL 11/04/2026
--RAM tied to payment (price from ram into ChangeCalc). --EL 11/17/2026
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
		  
		  --CC 11/18/2026 START
		  LEDR : out std_logic_vector(3 downto 0); --LED Lights output
		  --CC 11/18/2026 END
		  
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
	signal price : integer range 0 to 999; --comes from ram now --EL 11/17/2026
	signal p_hund, p_ten, p_one : integer range 0 to 9; --ram price digits --EL 11/17/2026
	signal xin_s : std_logic_vector(29 downto 0); --EL 11/17/2026
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
	signal reg_sel : std_logic := '1'; --1 = shift reg records the address (Shift_Reg_Entity), was 0 --EL 11/17/2026
	
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
	
	--Graham Fales 11/17/2026 Start
	--Defining an enumerated type that gives the states of the overall FSM
	--This enum type will need to be updated as more states are added
   type FSM_states is (std_mode,gt_price,disp_pay,call_pay_ent,pay_st,addrs_clear);
   --Declaring a signal that will represent the state of the machine
   signal state : FSM_states;

   --Creating a signal that will be assigned a unique value depending on which signal needs to be
	--   Displayed. For values entered for the user
   --   My plan which is available for changing is to have one signal passed to the hex displays	
	--   And then to use a structure of multiplexers which will assign multiple signals from the different
   --   entities to this one signal based on the value of the below signal. The FSM will assign the value
	--   of this signal.
	signal choose_display : std_logic_vector(2 downto 0); --Making this the only signal that governs displays
	--Currently 100 means "display the address".
	
	--Another signal will be made that will control Hex 5 to 3
	--   This signal will be used to display error messages or RAM values
	--   Again these signals are for the multiplexer structure that will need to be created
	--signal choose_display_machine : std_logic_vector(2 downto 0); Commented out on 11/18/2026 by Graham Fales
	--Currently 100 means "display RAM price"
	--Currenlty 000 means "display nothing" 
	--Graham Fales 11/17/2026 End
	
		--CC 11/18/2026 START																		
	signal dispense_start: std_logic := '0'; --When to start dispensing change (0 --> Off, 1 --> On)
	signal dispenser_busy: std_logic; --Still working on dispensing change, wait
	signal dispenser_done: std_logic; --Machine done dispensing, waiting for next value of change
		--CC 11/18/2026 END
	
	--EL 11/17/26 begin
	--lab5 codes
	constant C_0     : std_logic_vector(4 downto 0) := "00000";
	constant C_1     : std_logic_vector(4 downto 0) := "00001";
	constant C_2     : std_logic_vector(4 downto 0) := "00010";
	constant C_3     : std_logic_vector(4 downto 0) := "00011";
	constant C_4     : std_logic_vector(4 downto 0) := "00100";
	constant C_5     : std_logic_vector(4 downto 0) := "00101";
	constant C_6     : std_logic_vector(4 downto 0) := "00110";
	constant C_7     : std_logic_vector(4 downto 0) := "00111";
	constant C_8     : std_logic_vector(4 downto 0) := "01000";
	constant C_9     : std_logic_vector(4 downto 0) := "01001";
	constant C_STAR  : std_logic_vector(4 downto 0) := "01010";
	constant C_H     : std_logic_vector(4 downto 0) := "01011";
	constant C_C     : std_logic_vector(4 downto 0) := "01100";
	constant C_D     : std_logic_vector(4 downto 0) := "01101";
	constant C_E     : std_logic_vector(4 downto 0) := "01110";
	constant C_BLANK : std_logic_vector(4 downto 0) := "01111";
	constant C_A     : std_logic_vector(4 downto 0) := "10000";
	constant C_G     : std_logic_vector(4 downto 0) := "10001";
	constant C_S     : std_logic_vector(4 downto 0) := "10010";
	constant C_L     : std_logic_vector(4 downto 0) := "10011";
	constant C_R     : std_logic_vector(4 downto 0) := "10100";
	constant C_LH    : std_logic_vector(4 downto 0) := "10101"; --lowercase h
	constant C_F     : std_logic_vector(4 downto 0) := "10110";
	constant C_T     : std_logic_vector(4 downto 0) := "10111";
	constant C_DASH  : std_logic_vector(4 downto 0) := "11000";
	--EL 11/17/26 end
	
	--Graham Fales 11/18/2026 start
	--Declaring signals that will hold the values for the amount that the user pays
	signal dig3 : std_logic_vector(3 downto 0);
	signal dig4 : std_logic_vector(3 downto 0);
	signal dig5 : std_logic_vector(3 downto 0);
	--Graham Fales 11/18/2026 end
	
BEGIN
	dig0 <= std_logic_vector(to_unsigned(num mod 10, 4));
	dig1 <= std_logic_vector(to_unsigned((num / 10) mod 10, 4));
	dig2 <= std_logic_vector(to_unsigned(num / 100, 4));
	--Graham Fales 11/18/2026 Start
	dig3 <= std_logic_vector(to_unsigned(paid mod 10, 4));
	dig4 <= std_logic_vector(to_unsigned((paid / 10) mod 10, 4));
	dig5 <= std_logic_vector(to_unsigned(paid / 100, 4));	
	--Graham Fales 11/18/2026 end
	
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
	--Graham Fales 11/18/2026 Start
	--Creating the multiplexer structer that will govern which things are displayed when
	xin_s <= C_BLANK & C_BLANK & C_BLANK & C_BLANK & '0' & address_k(7 downto 4) & '0' & address_k(3 downto 0) when choose_display = "100" else
	         '0' & data_r_out(11 downto 8) & '0' & data_r_out(7 downto 4) & '0' & data_r_out(3 downto 0) & C_BLANK & C_BLANK & C_BLANK when choose_display = "110" ELSE
			   '0' & data_r_out(11 downto 8) & '0' & data_r_out(7 downto 4) & '0' & data_r_out(3 downto 0) & '0' & dig3 & '0' & dig4 & '0' & dig5 when choose_display = "101" else
				C_E & C_R & C_R & C_E & C_R & C_R;
	
	--Graham Fales 11/18/2026 End
	--EL 11/04/2026

	--xin_s <= C_BLANK & C_BLANK & C_BLANK & '0' & dig2 & '0' & dig1 & '0' & dig0; --hex5-3 blank, hex2-0 = num --EL 11/17/2026 --Commented by GF 11/18/2026
	disp : entity work.Part2
		port map (xin => xin_s, --part2 is 6 x 5 bit codes now --EL 11/17/2026
				  sevenseg1 => display0, sevenseg2 => display1, sevenseg3 => display2);
	calc : entity work.ChangeCalc
		port map (price => price, paid => paid, change => num, short => open,
				  quarters => open, dimes => open, nickels => open, pennies => open);
	pay : entity work.Payment
		port map (clk => clk_100hz, reset => '0', sw => sw_clean, paid => paid);
	--testing payment method
	--EL 11/04/2026 uses debounced switches
	
	--CC 11/18/2026 START
	Dispenser: entity work.ChangeDispenser
		port map(
			clk => clk_in,
			reset => not key0,
			start => dispense_start,
			change_cents => num, --Connecting my change_cents value to num, the integer value outputed from EL's ChangeCalc
			LED => LEDR, --Using all four LEDs assigned above
			busy => dispenser_busy, --Calling busy from interior to dispenser_busy signal in main
			done => dispenser_done --Calling done from interior to dispenser_done signal in main
			);
	--CC 11/18/2026 END
	
	div_btn : clk_div
		generic map (cnt_max => 250000) --100 hz from 50 mhz
		port map (clock_in => clk_in, clock_out => clk_100hz);
	--EL 11/04/2026
	
	--Graham Fales 11/14/2026 Start
	--Instantiating the Keypad_Entity
	keypad : entity work.Keypad_Entity port map(clk_in,key0,reg_sel,column,row,address_k,data_kpad); --fixed syntax + port order --EL 11/17/2026
	
	--Instantiating the RAM_Entity
	Ram : entity work.RAM_Entity port map(clk_in,R_W,key0,Ram_Enter,address_r,data_r_in,data_r_out); --fixed syntax --EL 11/17/2026
	--Graham Fales 11/14/2026 End
	
	--RAM to payment --EL 11/17/2026 --Graham Fales Edited 11/18/2026 --Commented out address assignment
	--R_W <= '1';         --read only for now
	--Ram_Enter <= '0';   --always enabled -GF Edited 11/18/2026 commented out, FSM will dictate when this is on or off
	data_r_in <= (others => '0');
	--only valid locations (11-44) go to the ram, anything else reads 11
	--address_r <= address_k when (to_integer(unsigned(address_k(7 downto 4))) >= 1 and to_integer(unsigned(address_k(7 downto 4))) <= 4 and
	                            -- to_integer(unsigned(address_k(3 downto 0))) >= 1 and to_integer(unsigned(address_k(3 downto 0))) <= 4) else x"11";
	to_int : entity work.To_Int_Entity port map(data_r_out, p_hund, p_ten, p_one);
	price <= p_hund * 100 + p_ten * 10 + p_one; --cents, goes into ChangeCalc against paid from Payment
	
	--Graham's FSM commented out until it's finished, it doesn't compile yet --EL 11/17/2026
	--  (clk not declared, st_mode not in FSM_states and listed twice, case/process never closed,
	--   and its address_r <= address_k would fight the address_r line above)
--	--Graham Fales 11/17/2026 Start
	--Assigning the address of the keypad to the address of the RAM
	address_r <= address_k;
--	--Building the Overall FSM for this project. The idea is 
--	--    for this FSM to control which data are sent to which entity.
--	--    It will monitor Key 2 and activate the change prices entity when Key 2 is pressed
--	--    this FSM will use signals to activate entities. It will send an activation signal 
--	--    to each entity when that entity is needed.
--	--    This FSM will be split into two sections or you can think if it as two sections
--	--    If Key 2 is not pressed, then this FSM will be on the regular entering prices and 
--	--    calulating change mode. Once Key 2 is pressed, the FSM will be on the change prices mode.
	Overall_FSM: process(clk_in,key0) 
	
	begin
	
	   if(key0 = '0') then --Defining Reset State
		   state <=std_mode;
			
		elsif(clk_in'event and clk_in = '1') then --When reset is not activated
		   Case state is
			
			   when std_mode =>
				   R_W <= '1'; --setting RAM to read mode for now
					
				   choose_display <= "100"; --Setting the currently as of 11/17/2026 non-existent 
					                             --  Multiplexer array to display the address entered
														  
					reg_sel <= '0'; --Setting the keypad entity to record the address
					
					--Checking to make sure a valid address has been entered -- We need to talk to Barlow about what should happen if an 
					--  invalid address has been entered
					if ((to_integer(unsigned(address_k(7 downto 4))) >= 1 and to_integer(unsigned(address_k(7 downto 4))) <= 4 and
	                             to_integer(unsigned(address_k(3 downto 0))) >= 1 and to_integer(unsigned(address_k(3 downto 0))) <= 4)) then 
					   state <= gt_price; --If a valid address is entered, change to the next state
					else state <=std_mode; --If the address is invalid stay in this state until a valid address is entered
					end if;
					
				when gt_price => --We have a valid address and now are sending it to the RAM by allowing the RAM to clock
				   RAM_Enter <= '1'; --Allowing the RAM to go
               choose_display <= "110"; --allowing the price of the ram to be displayed
				   state <= disp_pay;
				when disp_pay => --Displays the values the user is entering
				   choose_display <= "101"; --Value corresponding to the pay value being entered by using the multiplexer structure
					--Setting the next state to the std_mode state so that an address can be entered while the payment and other entities are running
					state <= std_mode;
					
			   when others => --covering default
				   state <= std_mode;
			end case;
		end if;
	end process;
				
				
				
				
--	--Graham Fales 11/17/2026 End
	
END FPArch;

--if you need to make an instance of the clock with a value that is not 62500 (this is just an init value)
--do this:
--div_example : clk_div
--		generic map (cnt_max => 62500)
--		port map (clock_in => clk_in, clock_out => clk_example);
--EL 10/30/26
