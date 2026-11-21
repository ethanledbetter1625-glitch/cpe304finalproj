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
		  -- Nicholas Winowitch addition 11/18/2026
		  Key2 : in std_logic; -- active low maintence button
		  Key3 : in std_logic; --Graham Fales 11/20/2026 for vending purposes
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
		  display3 : out std_logic_vector(6 downto 0);
		  display4 : out std_logic_vector(6 downto 0);
		  display5 : out std_logic_vector(6 downto 0);
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
	signal dig0, dig1, dig2, dig3, dig4, dig5 : std_logic_vector(4 downto 0);
	signal clk_100hz : std_logic;
	--EL 10/31/26
	signal sw_clean : std_logic_vector(3 downto 0); --debounced switch levels
	signal sw_pulse : std_logic_vector(3 downto 0); --1 clk pulse on each switch up-flip
	--EL 11/04/2026
	
	--Graham Fales 11/20/2026 start
	--Creating a signal to activate if the shift register inside the Keypad_Enity is shifting a new value
	signal addrs_changed : std_logic:='0';
	--Defining a signal to reset the payment entity
	signal rst_pay : std_logic;
	--Defining a signal that will carry the clear command to the keypad entity- this will be so that the address can be cleared after a vend
	signal clear_addrs : std_logic :='0';
	--Graham Fales 11/20/2026 End
	
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
	
	--Creating two signals for LED's. LED_E will be assigned to the output of Ethan's Pay entity
	--   LED_C will be assigned to the output of Caden's dispensor entity
	--   A multiplexer structure will be used to choose which of these signals to assign to LEDR
	signal LED_E : std_logic_vector(3 downto 0);
	signal LED_C : std_logic_vector(3 downto 0);
	signal LED_sel : std_logic; --Choose which entity is controlling which LED's
	
	--This signal will carry data away from the RAM;
	signal data_R_out : std_logic_vector(11 downto 0);
	--Graham Fales 11/14/2026 End
	
	--Graham Fales 11/17/2026 Start
	--Defining an enumerated type that gives the states of the overall FSM
	--This enum type will need to be updated as more states are added
   type FSM_states is (std_mode,gt_price,disp_pay,part_addr_ch,vend_go,vend_st,clear_st,key_p1,key_r1,key_p2);
   --Declaring a signal that will represent the state of the machine
   signal state : FSM_states;

   --Creating a signal that will be assigned a unique value depending on which signal needs to be
	--   Displayed. For values entered for the user
   --   My plan which is available for changing is to have one signal passed to the hex displays	
	--   And then to use a structure of multiplexers which will assign multiple signals from the different
   --   entities to this one signal based on the value of the below signal. The FSM will assign the value
	--   of this signal.
	signal choose_display : std_logic_vector(2 downto 0);
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
	--Nicholas Winowitch 11/18/2026 additions begin
	--Inputs supplied.
    signal cp_item_valid    : std_logic; --indicates both keypad address digits are within the allowed range 1-4
    signal cp_purchase_idle : std_logic; --gives permission to enter maintenance mode

    --Maintenance status and keypad-clear request.
    signal cp_setup_active   : std_logic; -- '1' while ChangePricees is in maintenance mode
    signal cp_clear_selector : std_logic; -- Requests clearing the previous keypad selection
    signal cp_item_chosen    : std_logic; -- '1' when an item is selected for editing or save request
    signal cp_price_error    : std_logic; -- '1' when the controller detects an invalid selection or error

    --Price being entered, in integer cents.
    signal cp_draft_cents : integer range 0 to 999; -- Draft value for the display. So 135 would mean $1.35

    --Reset outputs from my controller.
    signal cp_system_reset : std_logic; --Active-high reset request '1' means restart
    signal cp_ram_reset_n  : std_logic; --Active-low ram reset request '0' means restart

    --Save request, selected item, and new BCD price.
    signal cp_write_request : std_logic; -- clock cycle saves request
    signal cp_address : std_logic_vector(7 downto 0); --selected items row and column digits say x23 means item 23
    signal cp_price   : std_logic_vector(11 downto 0); --three BCD price digits x135 would mean $1.35
    
	 --NICK ADDITIONS END
	 
	 signal FSM_clk : std_logic := '0'; --Creating a slower clock for the FSM to see if bug can be fixed
	 
BEGIN
	dig0 <= std_logic_vector(to_unsigned(num mod 10, 5));
	dig1 <= std_logic_vector(to_unsigned((num / 10) mod 10, 5));
	dig2 <= std_logic_vector(to_unsigned(num / 100, 5));
	--Graham Fales 11/18/2026 Start
	dig3 <= std_logic_vector(to_unsigned(paid mod 10, 5));
	dig4 <= std_logic_vector(to_unsigned((paid / 10) mod 10, 5));
	dig5 <= std_logic_vector(to_unsigned(paid / 100, 5));	
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
--	--Nicholas Winowitch 11/19/2026 ChangePrice connections START
--
--    --Validate the item address from the keypad
--	 --upper four bits = row digit. Lower four bits = column digit.
--	 --Both digits must be 1-4. 
--    cp_item_valid <= '1' when
--        (
--            address_k(7 downto 4) = x"1" or
--            address_k(7 downto 4) = x"2" or
--            address_k(7 downto 4) = x"3" or
--            address_k(7 downto 4) = x"4"
--        )
--        and
--        (
--            address_k(3 downto 0) = x"1" or
--            address_k(3 downto 0) = x"2" or
--            address_k(3 downto 0) = x"3" or
--            address_k(3 downto 0) = x"4"
--        )
--        else '0';  --Rejects the invalid or incomplete addresses
--		  -- This checks the stored address, not whether a new key was pressed.
--        -- The keypad selector must be cleared between item selections.
--
--
--        -- Provisional permission to enter maintenance.
--        -- This checks the main state and deposited amount.
--        -- The overall FSM still needs to provide a complete transaction-idle check.
--    cp_purchase_idle <= '1' when
--        state = std_mode and paid = 0 -- Standard mode with not deposited money
--        else '0';
--		  -- Create and connect the ChangePrices controller.
--        -- Left of => is the ChangePrices port.
--        -- Right of => is its connection in FinalProject.
--    price_controller : entity work.ChangePrices
--        port map (
--            --Clock and separate reset.
--            clk   => clk_in, -- uses the boards 50MHz clock
--            reset => '0',    -- separate reset is not active. Internal KEY0 handling still operates.
--
--            --Physical active-low buttons.
--            key0 => key0, --Save in maintenance mode, reset in purchase mode.
--            key2 => key2, --Enter/Exit
--
--            --Permission to enter maintenance.
--            purchase_idle => cp_purchase_idle, -- Must be '1' to accept a request to enter maintenance.
--
--            --Item selected using the existing keypad.
--            item_address => address_k,     -- Supply the row and column digits of the selected item.
--            item_valid   => cp_item_valid, -- Indicate that both digits are within the allowed range.
--
--            --Existing debounced switch levels.
--            sw_clean => sw_clean,
--
--            --Maintenance and entry status.
--            setup_active   => cp_setup_active,   -- Reports maintenance mode to the overall controller.
--            clear_selector => cp_clear_selector, -- Requests clearing the old keypad selection.
--            item_chosen    => cp_item_chosen,    -- Reports that an item has been selected.
--            price_error    => cp_price_error,    -- Reports an invalid entry.
--
--            --Draft price for display.
--            draft_cents => cp_draft_cents, -- Integer cents, before conversion to display digits.
--
--            --Reset outputs.
--            system_reset => cp_system_reset,  -- Active-high reset request.
--            ram_reset_n  => cp_ram_reset_n,   -- Active-low RAM reset request.
--
--            --Save outputs.
--            write_request => cp_write_request,  -- Requests saving the selected item's new price.
--            ram_address   => cp_address,        -- Address to capture with the save request.
--            ram_price     => cp_price           -- BCD price to capture with the save request.
--        );

    --Nicholas Winowitch addition END
	 
	--Graham Fales 11/18/2026 Start
	--Creating the multiplexer structer that will govern which things are displayed when
	xin_s <= C_BLANK & C_BLANK & C_BLANK & C_BLANK & '0' & address_k(7 downto 4) & '0' & address_k(3 downto 0) when choose_display = "100" else
				'0' & data_r_out(11 downto 8) & '0' & data_r_out(7 downto 4) & '0' & data_r_out(3 downto 0) & C_BLANK & C_BLANK & C_BLANK when choose_display = "110" ELSE
			   '0' & data_r_out(11 downto 8) & '0' & data_r_out(7 downto 4) & '0' & data_r_out(3 downto 0) & dig5 & dig4 & dig3 when choose_display = "101" else
				C_BLANK & C_BLANK & C_BLANK & C_BLANK & C_BLANK & C_BLANK when choose_display = "111" else
				C_E & C_R & C_R & C_E & C_R & C_R;
--	
	--xin_s <= '0' & data_r_out(11 downto 8) & '0' & data_r_out(7 downto 4) & '0' & data_r_out(3 downto 0) & C_BLANK & C_BLANK & C_BLANK; --test Commented out by GF 11/19/2026
	--Graham Fales 11/18/2026 End
	--EL 11/04/2026

	
	--xin_s <= C_BLANK & C_BLANK & C_BLANK & '0' & dig2 & '0' & dig1 & '0' & dig0; --hex5-3 blank, hex2-0 = num --EL 11/17/2026 --Commented by GF 11/18/2026
	disp : entity work.Part2
		port map (xin => xin_s, --part2 is 6 x 5 bit codes now --EL 11/17/2026
				  sevenseg1 => display0, 
				  sevenseg2 => display1, 
				  sevenseg3 => display2,
				  sevenseg4 => display3,
				  sevenseg5 => display4,
				  sevenseg6 => display5
				  );
	calc : entity work.ChangeCalc
		port map (price => price, 
					 paid => paid, 
					 change => num, 
					 short => open,
				    quarters => open, 
				    dimes => open, 
					 nickels => open, 
					 pennies => open);
	pay : entity work.Payment
		port map (clk => clk_100hz, 
					 reset => rst_pay, --Connecting to signal so the FSM can reset it
					 sw => sw_clean, 
					 paid => paid,
					 item_price => price,
					 LED => LED_E --kicked back coin leds, led0 nickel ... led3 dollar --EL 11/18/2026
					 ); --tabbed for visibility EL
	--testing payment method
	--EL 11/04/2026 uses debounced switches
	
	--CC 11/18/2026 START
	Dispenser: entity work.ChangeDispenser
		port map(
			clk => clk_in,
			reset => not key0,
			start => dispense_start,
			change_cents => num, --Connecting my change_cents value to num, the integer value outputed from EL's ChangeCalc
			LED => LED_C, --Using all four LEDs assigned above
			busy => dispenser_busy, --Calling busy from interior to dispenser_busy signal in main
			done => dispenser_done --Calling done from interior to dispenser_done signal in main
			);
	--CC 11/18/2026 END
	
	div_btn : clk_div
		generic map (cnt_max => 250000) --100 hz from 50 mhz
		port map (clock_in => clk_in, clock_out => clk_100hz);
	--EL 11/04/2026
	
	--Graham Fales 11/21/2026 start
	div_clk_FSM : clk_div
		generic map (cnt_max => 62500) --Slower than keypad clock
		port map (clock_in => clk_in, clock_out => FSM_clk);
	--Graham Fales 11/21/2026 End
	
	--Graham Fales 11/14/2026 Start
	--Instantiating the Keypad_Entity
	keypad : entity work.Keypad_Entity port map(clk_in,key0,reg_sel,clear_addrs,column,row,address_k,data_kpad,addrs_changed); --fixed syntax + port order --EL 11/17/2026
	
	--Instantiating the RAM_Entity
	Ram : entity work.RAM_Entity port map(clk_in,R_W,key0,Ram_Enter,address_r,data_r_in,data_r_out); --fixed syntax --EL 11/17/2026
	--Graham Fales 11/14/2026 End
	
	--RAM to payment --EL 11/17/2026 --Graham Fales Edited 11/18/2026 --Commented out address assignment
	--R_W <= '1';         --read only for now
	--Ram_Enter <= '0';   --always enabled -GF Edited 11/18/2026 commented out, FSM will dictate when this is on or off
--	data_r_in <= (others => '0');
	--only valid locations (11-44) go to the ram, anything else reads 11
	--address_r <= address_k when (to_integer(unsigned(address_k(7 downto 4))) >= 1 and to_integer(unsigned(address_k(7 downto 4))) <= 4 and
	                            -- to_integer(unsigned(address_k(3 downto 0))) >= 1 and to_integer(unsigned(address_k(3 downto 0))) <= 4) else x"11";
	to_int : entity work.To_Int_Entity port map(data_r_out, p_hund, p_ten, p_one);
	price <= p_hund * 100 + p_ten * 10 + p_one; --cents, goes into ChangeCalc against paid from Payment
--	price <= 100; --TEMP test price ($1.00) while ram is commented out, DELETE when the to_int/price line above comes back --EL 11/18/2026
	
	--Graham Fales 11/20/2026 start
	
	--Creating a multiplexer that will activate a  signal
	--  This signal will tell the FSM whether the address has changed or not.
--	addrs_changed <= '0' when address_k = addrs_prev else --Commented by GF 11/21/2026 New Idea, have signal 
--	                 '1';										   --from Keypad Entity that alerts when an address change occurs
						  
	--Choosing which entity to control the LED's
	LEDR <= LED_E when LED_sel = '1' else
	        LED_C;
	--Graham Fales 11/20/2026 End
	
	
	
	
	--Graham's FSM commented out until it's finished, it doesn't compile yet --EL 11/17/2026
	--  (clk not declared, st_mode not in FSM_states and listed twice, case/process never closed,
	--   and its address_r <= address_k would fight the address_r line above)
	--Graham Fales 11/17/2026 Start
	--Assigning the address of the keypad to the address of the RAM
	address_r <= address_k;
	--Building the Overall FSM for this project. The idea is 
	--    for this FSM to control which data are sent to which entity.
	--    It will monitor Key 2 and activate the change prices entity when Key 2 is pressed
	--    this FSM will use signals to activate entities. It will send an activation signal 
	--    to each entity when that entity is needed.
	--    This FSM will be split into two sections or you can think if it as two sections
	--    If Key 2 is not pressed, then this FSM will be on the regular entering prices and 
	--    calulating change mode. Once Key 2 is pressed, the FSM will be on the change prices mode.
	Overall_FSM: process(clk_in,key0) 
	
	begin
	
	   if(key0 = '0') then --Defining Reset State-
		   state <=std_mode;
			rst_pay <= '1';
			--disp_pay <= '0';
			LED_sel <= '1'; --Assigning Ethan's pay entity to run the LED's be default
			
		elsif(clk_in'event and clk_in = '1') then --When reset is not activated
		
		   addrs_prev <= address_k;
		   Case state is
			
			   when std_mode =>
				   rst_pay <= '1'; --Making it so pay will not reset
				   R_W <= '1'; --setting RAM to read mode for now
					clear_addrs <= '0'; --Setting the address to not clear

					choose_display <= "100"; --Setting the currently as of 11/17/2026 non-existent 
					                             --  Multiplexer array to display the address entered
														  
					reg_sel <= '1'; --Setting the keypad entity to record the address
					
					--Checking to make sure a valid address has been entered -- We need to talk to Barlow about what should happen if an 
					--  invalid address has been entered
					--if ((to_integer(unsigned(address_k(7 downto 4))) >= 1 and to_integer(unsigned(address_k(7 downto 4))) <= 4 and
	             --                to_integer(unsigned(address_k(3 downto 0))) >= 1 and to_integer(unsigned(address_k(3 downto 0))) <= 4)) then 
					 if(((address_k(7 downto 4) = "0001") or (address_k(7 downto 4) = "0010") or (address_k(7 downto 4) = "0011") or (address_k(7 downto 4) = "0100")) and 
					 ((address_k(3 downto 0) = "0001") or (address_k(3 downto 0) = "0010") or (address_k(3 downto 0) = "0011") or (address_k(3 downto 0) = "0100"))) then
					   if (addrs_changed = '0') then --Checking to make sure the key has been released
						   state <= gt_price; --If a valid address is entered, change to the next state
						end if;
					 else state <= std_mode; --If the address is invalid stay in this state until a valid address is entered
					 end if;
					
				when gt_price => --We have a valid address and now are sending it to the RAM by allowing the RAM to clock
				
				   RST_PAY <= '0'; --ALLOWING THE PAY TO CHANGE 
					RAM_Enter <= '0'; --Allowing the RAM to go
               choose_display <= "110";
					state <= disp_pay; --Changing state
					
				when disp_pay =>	--Displays the values the user is entering
				   ram_enter <= '1'; --Turning off the RAM clock
					choose_display <= "101";
					LED_sel <= '1';
--					--Setting the next state to the std_mode state so that an address can be entered while the payment and other entities are running
--					state <= std_mode;
               --If the address changes, we need to move to the partical change state which waits for another change and displays the address
					--If the address has not changed, we stay in the disp_pay state
					if (addrs_changed = '1') then
					   state <= key_p1;
						
					elsif (key3 = '0') then --User is trying to vend
					   state <= vend_go; --Move to vend state
						--dispense_start <= '1';--Starting the dispensor in the previous state
						
					else state <= disp_pay;
					end if;
			   when key_p1 => --when a keypad is pressed on the keyboard, we enter this state
			      if (addrs_changed = '0') then --Essentially the key would have been released for this signal to be 0
					   state <= key_r1;
					else state <= key_p1;
					end if; 
				
				when key_r1 => --Enter this state when the key is released
				               --This state moves to the partial address change state
				   state <= part_addr_ch;
					
				when part_addr_ch => --Defining a state that waits until the address has been changed again to allow the address to be clocked in the RAM
				   --Setting the display to display the address being entered
					choose_display <= "100";
					if (addrs_changed = '1') then
					   state <= key_p2;  --Move to the second key is pressed state, indicating the second number is being entered for an address
					else state <= part_addr_ch;
					end if;
					
				when key_p2 => --This state notes that the key has been pressed and waits for the key to be released to change states 
				   if (addrs_changed = '0') then
					   state <= std_mode;
					else state <= key_p2;
					end if;
					
				when vend_go => --This state activates the change dispenser, displays blanks, and set the LED's to Cayden's control
				    dispense_start <= '1';--Starting the dispensor in the previous state
					 choose_display <= "111"; --Displaying blanks
					 LED_sel <= '0'; --Caden now has control of the LED's
					 state <= vend_st;
					 
				when vend_st => 
				   dispense_start <= '0'; --Turning off the start button
				   --Need to activate Caden's change LED entity 
					--dispense_start <= '1';
					--choose_display <= "111"; --Displaying blanks
					
					
					if (dispenser_done <= '0') then --Trying to create a sink state
					   state <= vend_st;
					else state <= clear_st;
					end if;

					
				when clear_st => --This state will send the clear signal to the address register of the keypad which will clear out the address
				   clear_addrs <= '1'; --Clear signal
					rst_pay <= '1'; --Clearing the paid amount
					state <= std_mode; --Changes to the beginning state to start the process over again
				   
				
			   when others => --covering default
				   state <= std_mode;
			end case;
		end if;
	end process;
				
				
				
				
	--Graham Fales 11/17/2026 End
	
END FPArch;

--if you need to make an instance of the clock with a value that is not 62500 (this is just an init value)
--do this:
--div_example : clk_div
--		generic map (cnt_max => 62500)
--		port map (clock_in => clk_in, clock_out => clk_example);
--EL 10/30/26
