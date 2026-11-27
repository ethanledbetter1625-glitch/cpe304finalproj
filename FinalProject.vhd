--All testing done. 
--Debounce testing done. --EL 11/04/2026
--RAM tied to payment (price from ram into ChangeCalc). --EL 11/17/2026
--full customer mode: new master fsm, refund, short pay block, error msgs, change display --EL 11/27/2026
--When you make changes, initial and date them with a comment.
--ALWAYS ALWAYS ALWAYS PULL FROM ORIGIN BEFORE MAKING CHANGES

-----------------------------------------------------------------------------------------------------------
--HOW CUSTOMER MODE WORKS --EL 11/27/2026
--  controls:
--    keypad : type a 2 digit item number, row digit then column digit (1-4 each, so items 11 to 44)
--    sw0-3  : insert 5c, 10c, 25c, $1 (flip it up to drop a coin, flip it back down to get ready for the next)
--    key3   : vend
--    key1   : cancel / refund
--    key0   : reset everything (also loads $1.00 back into every ram slot, press once after programming)
--
--  displays (hex5 is the far left, hex0 is the far right, money is in cents so 125 = $1.25):
--    picking an item   : [item][item] [blank] [paid][paid][paid]   item shows "--" until it is typed
--    item picked       : [price][price][price] [paid][paid][paid]
--    vending           : C H g [change][change][change]            change also blinks out on the leds
--    refunding         : r E F [refund][refund][refund]            refund also blinks out on the leds
--    bad item number   : E r r [blank] [item][item]                2 sec, use case 4
--    not enough money  : A d d [still owed][..][..]                2 sec, use case 6
--    vend with no item : S E L E C t                               2 sec, use case 9
--
--  leds: payment entity owns them normally (flashes a coin that got kicked back because you already paid),
--        change dispenser owns them while it is paying out (led3 $1, led2 25c, led1 10c, led0 5c)
--
--  use cases covered: 1 buy, 2 look at multiple prices first, 3 cancel/refund, 4 bad item number,
--                     5 overpay + change, 6 vend without enough money, 9 vend without picking an item
--  maintenance (use cases 7/8/10) is nick's ChangePrices, still commented out below
-----------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--took out std_logic_signed, nothing up here needs it and it can make = comparisons ambiguous --EL 11/27/2026
--EL 10/31/2026

entity FinalProject is
	--generics so the timings can be shrunk for simulation, quartus just uses these defaults --EL 11/27/2026
	generic(DB_TICKS       : integer := 500_000;      --debounce time for switches + buttons, 500k @ 50mhz = 10 ms
	        MSG_TICKS      : integer := 100_000_000;  --how long error/vend messages stay up, 100m @ 50mhz = 2 sec
	        COIN_LED_TICKS : integer := 25_000_000);  --how long a kicked back coin led stays on, 25m @ 50mhz = 0.5 sec
	port(clk_in : in std_logic;    --50 mhz board clock
		  key0 : in std_logic;      --active low, reset
		  -- Nicholas Winowitch addition 11/18/2026
		  Key2 : in std_logic; -- active low maintence button (not used in customer mode)
		  Key1 : in std_logic; --Graham Fales 11/21/2026 for cancel/refund purposes
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

	-----------------------------------------------------------------------------------------------------------
	--lab5 display codes, these go into Part2 5 bits per digit --EL 11/17/26
	-----------------------------------------------------------------------------------------------------------
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
	constant C_D     : std_logic_vector(4 downto 0) := "01101"; --lowercase d
	constant C_E     : std_logic_vector(4 downto 0) := "01110";
	constant C_BLANK : std_logic_vector(4 downto 0) := "01111";
	constant C_A     : std_logic_vector(4 downto 0) := "10000";
	constant C_G     : std_logic_vector(4 downto 0) := "10001"; --lowercase g
	constant C_S     : std_logic_vector(4 downto 0) := "10010";
	constant C_L     : std_logic_vector(4 downto 0) := "10011";
	constant C_R     : std_logic_vector(4 downto 0) := "10100"; --lowercase r
	constant C_LH    : std_logic_vector(4 downto 0) := "10101"; --lowercase h
	constant C_F     : std_logic_vector(4 downto 0) := "10110";
	constant C_T     : std_logic_vector(4 downto 0) := "10111"; --lowercase t
	constant C_DASH  : std_logic_vector(4 downto 0) := "11000";
	--EL 11/17/26 end

	-----------------------------------------------------------------------------------------------------------
	--display helper functions --EL 11/27/2026
	-----------------------------------------------------------------------------------------------------------
	--turns a 0-999 cents value into 3 display codes (hundreds & tens & ones) = 15 bits
	--ex: 125 -> C_1 & C_2 & C_5, shows up on the hex as 1 2 5
	function money3(value : integer range 0 to 999) return std_logic_vector is
		variable result : std_logic_vector(14 downto 0);
	begin
		result(14 downto 10) := std_logic_vector(to_unsigned(value / 100, 5));        --hundreds digit
		result(9 downto 5)   := std_logic_vector(to_unsigned((value / 10) mod 10, 5)); --tens digit
		result(4 downto 0)   := std_logic_vector(to_unsigned(value mod 10, 5));        --ones digit
		return result;
	end function;

	--turns one 4 bit keypad digit into a display code
	--the shift register holds 1111 in a spot that has not been typed yet, show that as a dash
	function key_dig(nib : std_logic_vector(3 downto 0)) return std_logic_vector is
	begin
		if nib = "1111" then
			return C_DASH;      --nothing typed here yet
		else
			return '0' & nib;   --0-9 codes are just the number with a 0 in front
		end if;
	end function;

	-----------------------------------------------------------------------------------------------------------
	--price / money signals
	-----------------------------------------------------------------------------------------------------------
	signal price : integer range 0 to 999; --price straight out of the ram (through To_Int), cents --EL 11/17/2026
	signal p_hund, p_ten, p_one : integer range 0 to 9; --ram price digits --EL 11/17/2026
	signal xin_s : std_logic_vector(29 downto 0); --6 display codes x 5 bits, goes into Part2 --EL 11/17/2026
	signal paid    : integer range 0 to 999; --total the customer has put in, from Payment
	signal num : integer range 0 to 999 := 0; --change = paid - price, from ChangeCalc

	--EL 11/27/2026 start
	signal item_price   : integer range 0 to 999 := 0;  --price of the picked item, latched once after the ram read
	signal item_sel     : std_logic := '0';             --1 = customer has a valid item picked right now
	signal price_to_pay : integer range 0 to 999;       --item_price when an item is picked, 0 when not
	                                                    --  (0 tells Payment "no item yet, take every coin")
	signal owed         : integer range 0 to 999;       --how much more money is needed, shown on the "Add" message
	signal dispense_amt : integer range 0 to 999 := 0;  --amount handed to the dispenser (change on a vend, all of paid on a refund)
	--EL 11/27/2026 end

	--EL 10/31/26
	signal sw_clean : std_logic_vector(3 downto 0); --debounced switch levels
	signal sw_pulse : std_logic_vector(3 downto 0); --1 clk pulse on each switch up-flip (not used, Payment does its own edge detect)
	--EL 11/04/2026

	-----------------------------------------------------------------------------------------------------------
	--button signals --EL 11/27/2026
	-----------------------------------------------------------------------------------------------------------
	--key1/key3 are raw active low buttons, they bounce and a press lasts millions of clocks
	--so they get flipped to active high and run through the same debounce entity as the switches
	--the debounce sw_pulse output gives exactly 1 clock pulse per press, no matter how long it is held
	signal key0_hi      : std_logic; --key0 flipped to active high, for the entities that want an active high reset
	signal key1_hi      : std_logic; --key1 flipped to active high (1 = pressed)
	signal key3_hi      : std_logic; --key3 flipped to active high (1 = pressed)
	signal cancel_pulse : std_logic; --1 clock pulse when key1 (cancel/refund) gets pressed
	signal vend_pulse   : std_logic; --1 clock pulse when key3 (vend) gets pressed

	--Graham Fales 11/20/2026 start
	--Creating a signal to activate if the shift register inside the Keypad_Enity is shifting a new value
	--  (this is 1 the whole time a keypad button is held down, 0 when nothing is pressed)
	signal addrs_changed : std_logic:='0';
	--Defining a signal to reset the payment entity
	signal rst_pay : std_logic := '1';
	--Defining a signal that will carry the clear command to the keypad entity- this will be so that the address can be cleared after a vend
	signal clear_addrs : std_logic :='0';
	--Graham Fales 11/20/2026 End

	-----------------------------------------------------------------------------------------------------------
	--keypad press tracking --EL 11/27/2026
	-----------------------------------------------------------------------------------------------------------
	--addrs_changed comes out of the keypad's slow scan clock, not clk_in, so it gets run through
	--2 flip flops first (sync) so the fsm never sees it change in the middle of a clock (metastability)
	--the 3rd flip flop is just the old value so we can catch the moment a key goes down
	signal kp_sync   : std_logic_vector(2 downto 0) := "000";
	signal kp_held   : std_logic; --synced version of addrs_changed, 1 while a key is held
	signal kp_press  : std_logic; --1 clock pulse when a key first goes down
	signal key_count : integer range 0 to 2 := 0; --how many digits have been typed since the last clear
	signal addr_ok   : std_logic; --1 when both typed digits are 1-4 (a real slot in the 4x4 ram)
	signal sel_addr  : std_logic_vector(7 downto 0) := x"11"; --the item address that got picked, sent to the ram
	signal bad_addr  : std_logic_vector(7 downto 0) := x"FF"; --copy of a bad item number so it can be shown on "Err"
	
	--Graham Fales 11/14/2026 Start
	--Declaring the signals that will be used to carry information between the keypad entity and other entities
	--Note the Keypad_Entity requires a 50MHz clock
	
	--The following signal will connect to the address bus of the Keypad_Entity
	--This bus will record and save two 4-bit BCD digits when the Registor select signal is set to 1
	signal address_k : std_logic_vector(7 downto 0);

	--The following signal will connect to the data bus of the Keypad_Entity
	--This bus will record and save three 4- bit BCD digits when the Registor select signal is set to 0
	signal data_kPad : std_logic_vector(11 downto 0);
	
	--Creating the registor select signal that will be used to change which values the keypad is recording
	signal reg_sel : std_logic := '1'; --1 = shift reg records the address (Shift_Reg_Entity), was 0 --EL 11/17/2026
	
	--Creating signals for the RAM entity to connect to other entities
	
	--The following signal will be used to change the RAM between read mode and write mode
	--   This signal should be 0 for Write and 1 for Read
	signal R_W : std_logic;
	
	--This signal will be used to activate the RAM. I will act like an "enter" button
	--   The RAM will not sned or receive data unless this signal is pulled low
	signal Ram_Enter : std_logic := '1';
	
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
	signal LED_sel : std_logic := '1'; --Choose which entity is controlling which LED's (1 = payment, 0 = dispenser)
	
	--This signal will carry data away from the RAM;
	signal data_R_out : std_logic_vector(11 downto 0);
	--Graham Fales 11/14/2026 End
	
	-----------------------------------------------------------------------------------------------------------
	--master fsm states --EL 11/27/2026 (built off of graham's 11/17 fsm)
	-----------------------------------------------------------------------------------------------------------
	--  std_mode  : waiting for an item number, money can already go in here
	--  gt_price  : valid item typed, let the ram clock for a few cycles and grab its price
	--  disp_pay  : item picked, show price + paid, wait for vend / cancel / a new item number
	--  err_item  : bad item number typed, show "Err xx" for 2 sec (use case 4)
	--  err_sel   : vend pressed with no item picked, show "SELECt" for 2 sec (use case 9)
	--  err_short : vend pressed without enough money, show "Add xxx" for 2 sec (use case 6)
	--  vend_go   : enough money, start the dispenser on the change (use cases 1 and 5)
	--  ref_go    : cancel pressed with money in, start the dispenser on all of paid (use case 3)
	--  vend_st   : wait for the dispenser to finish blinking out coins
	--  hold_st   : leave the final vend/refund message up for 2 sec so the customer can read it
	--  clear_st  : wipe the keypad, payment and picked item, then start over
	--graham's key_p1/key_r1/part_addr_ch/key_p2 states got replaced by the key_count counter
	type FSM_states is (std_mode,gt_price,disp_pay,err_item,err_sel,err_short,vend_go,ref_go,vend_st,hold_st,clear_st);
	signal state : FSM_states := std_mode;

	--what the 6 displays should be showing, the fsm sets this and the display mux below reads it
	--(replaces graham's choose_display bit codes, same idea just with names) --EL 11/27/2026
	type disp_modes is (d_select,d_price,d_vend,d_refund,d_bad_item,d_short,d_no_item);
	signal disp_mode : disp_modes := d_select;

	--ram read wait counter, gt_price holds Ram_Enter low for 8 clocks so the ram fsm has time to
	--go standby -> read_st and then actually put the price on data_r_out --EL 11/27/2026
	signal ram_wait : integer range 0 to 7 := 0;

	--CC 11/18/2026 START
	signal dispense_start: std_logic := '0'; --When to start dispensing change (0 --> Off, 1 --> On)
	signal dispenser_busy: std_logic; --Still working on dispensing change, wait
	signal dispenser_done: std_logic; --Machine done dispensing, waiting for next value of change
	--CC 11/18/2026 END

	--message timer (nick's ErrorTimer) hookup --EL 11/27/2026
	signal timer_start : std_logic := '0'; --1 clock pulse starts a 2 sec countdown
	signal timer_busy  : std_logic;        --1 while it is counting (not used, here for debugging)
	signal timer_done  : std_logic;        --1 clock pulse when the 2 sec are up

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
	 
BEGIN

	-----------------------------------------------------------------------------------------------------------
	--switch debounce --EL 11/04/2026
	-----------------------------------------------------------------------------------------------------------
	--debounce on every switch
	--use sw_clean(i) for switches
	--generic map here overrides the default in debounce.vhd
	gen_db : for i in 0 to 3 generate
		 db_i : entity work.debounce
			  generic map (CNT_MAX => DB_TICKS) --was 500_000, now the top generic (same default) --EL 11/27/2026
			  port map (
					clk      => clk_in,
					rst      => '0',
					sw_in    => sw(i),
					sw_out   => sw_clean(i),
					sw_pulse => sw_pulse(i)
			  );
	end generate;

	-----------------------------------------------------------------------------------------------------------
	--button debounce --EL 11/27/2026
	-----------------------------------------------------------------------------------------------------------
	--buttons are active low so flip them first, then debounce gives a clean 1 clock pulse per press
	key0_hi <= not key0;
	key1_hi <= not Key1;
	key3_hi <= not Key3;

	db_cancel : entity work.debounce
		generic map (CNT_MAX => DB_TICKS)
		port map (clk      => clk_in,
		          rst      => '0',
		          sw_in    => key1_hi,
		          sw_out   => open,          --dont need the level, just the press pulse
		          sw_pulse => cancel_pulse); --1 clock when key1 goes down

	db_vend : entity work.debounce
		generic map (CNT_MAX => DB_TICKS)
		port map (clk      => clk_in,
		          rst      => '0',
		          sw_in    => key3_hi,
		          sw_out   => open,
		          sw_pulse => vend_pulse);   --1 clock when key3 goes down

	-----------------------------------------------------------------------------------------------------------
	--keypad --Graham Fales 11/14/2026
	-----------------------------------------------------------------------------------------------------------
	--Instantiating the Keypad_Entity
	--fixed syntax + port order --EL 11/17/2026, switched to named ports so it is easier to read --EL 11/27/2026
	keypad : entity work.Keypad_Entity
		port map(clk         => clk_in,
		         reset       => key0,           --active low, clears the shift register
		         Adrs_Data   => reg_sel,        --1 = digits go into the address register
		         clear       => clear_addrs,    --1 = wipe the typed digits (fsm drives this)
		         column      => column,
		         row         => row,
		         address     => address_k,      --2 typed digits, upper nibble = first digit (row), lower = second (column)
		         data        => data_kpad,      --not used in customer mode
		         reg_changed => addrs_changed); --1 while a key is held

	--sync addrs_changed into the clk_in domain, then catch the press edge --EL 11/27/2026
	kp_sync_proc : process(clk_in)
	begin
		if rising_edge(clk_in) then
			kp_sync <= kp_sync(1 downto 0) & addrs_changed; --shift it through 3 flip flops
		end if;
	end process;
	kp_held  <= kp_sync(1);                    --synced level
	kp_press <= kp_sync(1) and not kp_sync(2); --was 0 last clock, 1 now = key just went down

	--item number check, both digits have to be 1-4 to be a real slot in the 4x4 ram --EL 11/27/2026
	--(same check graham had in std_mode, just pulled out into its own signal)
	addr_ok <= '1' when (unsigned(address_k(7 downto 4)) >= 1 and unsigned(address_k(7 downto 4)) <= 4 and
	                     unsigned(address_k(3 downto 0)) >= 1 and unsigned(address_k(3 downto 0)) <= 4)
	           else '0';

	-----------------------------------------------------------------------------------------------------------
	--ram --Graham Fales 11/14/2026
	-----------------------------------------------------------------------------------------------------------
	--Instantiating the RAM_Entity
	--fixed syntax --EL 11/17/2026, named ports --EL 11/27/2026
	Ram : entity work.RAM_Entity
		port map(Clk         => clk_in,
		         R_W         => R_W,
		         Reset       => key0,        --active low, loads $1.00 into every slot
		         clk_enabled => Ram_Enter,   --0 = ram is allowed to clock
		         Address     => address_r,
		         Data_in     => data_r_in,
		         Data_out    => data_r_out); --price of the slot at address_r, 3 bcd digits

	--customer mode only ever reads the ram, nick's maintenance mode will take these over later --EL 11/27/2026
	R_W       <= '1';             --read mode
	data_r_in <= (others => '0'); --nothing to write
	address_r <= sel_addr;        --the latched item number, not the live keypad, so typing doesnt mess with the ram

	--turn the 3 bcd digits out of the ram into one cents value
	to_int : entity work.To_Int_Entity port map(data_r_out, p_hund, p_ten, p_one);
	price <= p_hund * 100 + p_ten * 10 + p_one; --cents, latched into item_price by the fsm --EL 11/17/2026

	--payment only cares about a price once an item is actually picked --EL 11/27/2026
	price_to_pay <= item_price when item_sel = '1' else 0;

	--how much more the customer has to put in, for the "Add" message --EL 11/27/2026
	owed <= item_price - paid when (item_sel = '1' and paid < item_price) else 0;

	-----------------------------------------------------------------------------------------------------------
	--payment + change --EL 11/04/2026
	-----------------------------------------------------------------------------------------------------------
	calc : entity work.ChangeCalc
		port map (price => price_to_pay, --was price straight from ram, now only once an item is picked --EL 11/27/2026
					 paid => paid, 
					 change => num,         --paid - price (0 if short), used as the change on a vend
					 short => open,
				    quarters => open, 
				    dimes => open, 
					 nickels => open, 
					 pennies => open);

	pay : entity work.Payment
		generic map (LED_TICKS => COIN_LED_TICKS) --0.5 sec at 50 mhz now that it runs on clk_in --EL 11/27/2026
		port map (clk => clk_in,         --was clk_100hz, moved to the board clock so the fsm and payment share --EL 11/27/2026
		                                 --  one clock (no missed resets), the switches are already debounced
					 reset => rst_pay,      --Connecting to signal so the FSM can reset it
					 sw => sw_clean, 
					 paid => paid,
					 item_price => price_to_pay, --0 when no item, so coins are never kicked back before picking --EL 11/27/2026
					 LED => LED_E --kicked back coin leds, led0 nickel ... led3 dollar --EL 11/18/2026
					 ); --tabbed for visibility EL
	--the old 100hz clk_div (div_btn) got taken out, nothing uses it anymore --EL 11/27/2026

	-----------------------------------------------------------------------------------------------------------
	--change dispenser --CC 11/18/2026
	-----------------------------------------------------------------------------------------------------------
	Dispenser: entity work.ChangeDispenser
		port map(
			clk => clk_in,
			reset => key0_hi,            --active high reset (same as not key0) --EL 11/27/2026
			start => dispense_start,
			change_cents => dispense_amt, --was num, now the fsm picks change (vend) or all of paid (refund) --EL 11/27/2026
			LED => LED_C, --Using all four LEDs assigned above
			busy => dispenser_busy, --Calling busy from interior to dispenser_busy signal in main
			done => dispenser_done --Calling done from interior to dispenser_done signal in main
			);
	--CC 11/18/2026 END

	--Choosing which entity to control the LED's --Graham Fales 11/20/2026
	LEDR <= LED_E when LED_sel = '1' else
	        LED_C;

	-----------------------------------------------------------------------------------------------------------
	--message timer --EL 11/27/2026 (nick's ErrorTimer from 11/23)
	-----------------------------------------------------------------------------------------------------------
	--one timer is shared by every 2 sec message, only one message can be up at a time so they never fight
	msg_timer : entity work.ErrorTimer
		generic map (TICKS => MSG_TICKS)
		port map (clk    => clk_in,
		          reset  => key0_hi,     --active high
		          start  => timer_start, --1 clock pulse from the fsm starts it
		          cancel => '0',         --never cut a message short
		          busy   => timer_busy,
		          done   => timer_done); --1 clock pulse when time is up

	-----------------------------------------------------------------------------------------------------------
	--display mux --EL 11/27/2026 (replaces graham's choose_display mux from 11/18)
	-----------------------------------------------------------------------------------------------------------
	--left most 5 bits = hex5, right most 5 bits = hex0
	with disp_mode select xin_s <=
		--picking an item: typed digits on hex5-4 (dashes until typed), hex3 blank, paid on hex2-0
		key_dig(address_k(7 downto 4)) & key_dig(address_k(3 downto 0)) & C_BLANK & money3(paid) when d_select,
		--item picked: price on hex5-3, paid on hex2-0
		money3(item_price) & money3(paid)                                                     when d_price,
		--vending: "CHg" + change being handed back
		C_C & C_H & C_G & money3(dispense_amt)                                                when d_vend,
		--refunding: "rEF" + money being handed back
		C_R & C_E & C_F & money3(dispense_amt)                                                when d_refund,
		--bad item number: "Err" + blank + the number they typed
		C_E & C_R & C_R & C_BLANK & key_dig(bad_addr(7 downto 4)) & key_dig(bad_addr(3 downto 0)) when d_bad_item,
		--not enough money: "Add" + how much more is needed
		C_A & C_D & C_D & money3(owed)                                                        when d_short,
		--vend without an item: "SELECt"
		C_S & C_E & C_L & C_E & C_C & C_T                                                     when d_no_item;

	disp : entity work.Part2
		port map (xin => xin_s, --part2 is 6 x 5 bit codes now --EL 11/17/2026
				  sevenseg1 => display0, 
				  sevenseg2 => display1, 
				  sevenseg3 => display2,
				  sevenseg4 => display3,
				  sevenseg5 => display4,
				  sevenseg6 => display5
				  );

	-----------------------------------------------------------------------------------------------------------
	--MASTER FSM --EL 11/27/2026 (built off of graham's 11/17-11/21 fsm)
	-----------------------------------------------------------------------------------------------------------
	--everything runs on clk_in. key0 is an async reset like the rest of the project.
	--signals that are pulses (dispense_start, timer_start, clear_addrs) default to 0 at the top
	--of every clock, so a state only has to set them when it wants them on.
	Overall_FSM: process(clk_in, key0)
	begin
		if (key0 = '0') then --reset state, same idea as graham's
			state          <= std_mode;
			disp_mode      <= d_select;
			rst_pay        <= '1';   --hold payment at 0
			LED_sel        <= '1';   --payment owns the leds by default
			Ram_Enter      <= '1';   --ram not clocking
			clear_addrs    <= '0';   --keypad already gets cleared by key0 directly
			dispense_start <= '0';
			timer_start    <= '0';
			dispense_amt   <= 0;
			item_price     <= 0;
			item_sel       <= '0';
			sel_addr       <= x"11";
			bad_addr       <= x"FF";
			key_count      <= 0;
			ram_wait       <= 0;

		elsif rising_edge(clk_in) then

			--defaults every clock, states override these when they need to
			dispense_start <= '0'; --pulse
			timer_start    <= '0'; --pulse
			clear_addrs    <= '0'; --pulse (or held on by states that ignore the keypad)
			rst_pay        <= '0'; --payment runs unless a state says otherwise
			Ram_Enter      <= '1'; --ram only clocks in gt_price
			LED_sel        <= '1'; --payment leds unless the dispenser is running

			--count keypad presses, stops at 2. states that clear the keypad set this back to 0 below
			if (kp_press = '1' and key_count < 2) then
				key_count <= key_count + 1;
			end if;

			case state is

				---------------------------------------------------------------------------------
				when std_mode => --waiting on an item number, coins can already go in here
					disp_mode <= d_select;
					item_sel  <= '0';        --no item picked, payment takes every coin

					if (key_count = 2 and kp_held = '0') then
						--2nd digit typed and the key is let go, the number is done
						if (addr_ok = '1') then
							sel_addr <= address_k;  --lock in the item number for the ram
							ram_wait <= 0;
							state    <= gt_price;   --go grab its price
						else
							bad_addr    <= address_k; --save it to show on "Err"
							timer_start <= '1';       --start the 2 sec message
							state       <= err_item;  --use case 4
						end if;
						clear_addrs <= '1'; --wipe the keypad either way so the next number starts fresh
						key_count   <= 0;

					elsif (vend_pulse = '1') then
						--vend with no item picked, money stays put (use case 9)
						timer_start <= '1';
						state       <= err_sel;

					elsif (cancel_pulse = '1') then
						if (paid > 0) then
							--money in but no item, hand it all back (use case 3 before picking)
							dispense_amt <= paid;
							state        <= ref_go;
						else
							--nothing to give back, just wipe any half typed number
							clear_addrs <= '1';
							key_count   <= 0;
						end if;
					end if;

				---------------------------------------------------------------------------------
				when gt_price => --valid item, let the ram clock so it reads sel_addr
					--display stays on d_select for these 8 clocks (160 ns), nobody will see it
					if (ram_wait < 7) then
						Ram_Enter <= '0';           --0 = ram clocks
						ram_wait  <= ram_wait + 1;
					else
						--ram has had plenty of clocks to put the price out, latch it
						item_price <= price;
						item_sel   <= '1';
						state      <= disp_pay;
					end if;

				---------------------------------------------------------------------------------
				when disp_pay => --item picked, show price + paid
					disp_mode <= d_price;
					item_sel  <= '1';

					if (kp_press = '1') then
						--customer started typing a different item (use case 2), keep their money
						--key_count already went to 1 above, std_mode picks up the second digit
						item_sel <= '0';
						state    <= std_mode;

					elsif (vend_pulse = '1') then
						if (paid >= item_price) then
							--enough money, vend and give back the change (use cases 1 and 5)
							dispense_amt <= num;     --ChangeCalc: paid - item_price
							state        <= vend_go;
						else
							--not enough, block it and keep their money (use case 6)
							timer_start <= '1';
							state       <= err_short;
						end if;

					elsif (cancel_pulse = '1') then
						if (paid > 0) then
							--changed their mind, hand back everything they put in (use case 3)
							dispense_amt <= paid;
							state        <= ref_go;
						else
							--no money in, just drop the item and go back to picking
							item_sel <= '0';
							state    <= std_mode;
						end if;
					end if;

				---------------------------------------------------------------------------------
				when err_item => --"Err xx" for 2 sec, then back to picking (money kept)
					disp_mode   <= d_bad_item;
					item_sel    <= '0';
					clear_addrs <= '1';  --ignore the keypad while the message is up
					key_count   <= 0;
					if (timer_done = '1') then
						state <= std_mode;
					end if;

				---------------------------------------------------------------------------------
				when err_sel => --"SELECt" for 2 sec, then back to picking (money kept)
					disp_mode   <= d_no_item;
					clear_addrs <= '1';
					key_count   <= 0;
					if (timer_done = '1') then
						state <= std_mode;
					end if;

				---------------------------------------------------------------------------------
				when err_short => --"Add xxx" for 2 sec, then back to paying (item + money kept)
					disp_mode   <= d_short;
					item_sel    <= '1';
					clear_addrs <= '1';
					key_count   <= 0;
					if (timer_done = '1') then
						state <= disp_pay;
					end if;

				---------------------------------------------------------------------------------
				when vend_go => --start handing back change
					disp_mode      <= d_vend;   --"CHg xxx"
					LED_sel        <= '0';      --dispenser owns the leds now
					rst_pay        <= '1';      --zero out paid, the money is spent (also ignores coins till clear_st)
					dispense_start <= '1';      --dispenser grabs dispense_amt next clock
					clear_addrs    <= '1';
					key_count      <= 0;
					state          <= vend_st;

				---------------------------------------------------------------------------------
				when ref_go => --start handing back the refund
					disp_mode      <= d_refund; --"rEF xxx"
					LED_sel        <= '0';
					rst_pay        <= '1';
					dispense_start <= '1';
					clear_addrs    <= '1';
					key_count      <= 0;
					item_sel       <= '0';
					state          <= vend_st;

				---------------------------------------------------------------------------------
				when vend_st => --dispenser is blinking out coins, disp_mode stays CHg or rEF
					LED_sel     <= '0';
					rst_pay     <= '1';
					clear_addrs <= '1';
					key_count   <= 0;
					--done is a 1 clock pulse from the dispenser (same clock as us so we cant miss it)
					--(graham had "dispenser_done <= '0'" here, inside an if that is less than or equal, not an assignment)
					if (dispenser_done = '1') then
						timer_start <= '1'; --leave the message up for 2 more sec
						state       <= hold_st;
					end if;

				---------------------------------------------------------------------------------
				when hold_st => --message stays up so the customer can read it
					LED_sel     <= '0';
					rst_pay     <= '1';
					clear_addrs <= '1';
					key_count   <= 0;
					if (timer_done = '1') then
						state <= clear_st;
					end if;

				---------------------------------------------------------------------------------
				when clear_st => --wipe everything and start over
					rst_pay      <= '1';
					clear_addrs  <= '1';
					key_count    <= 0;
					item_sel     <= '0';
					item_price   <= 0;
					dispense_amt <= 0;
					disp_mode    <= d_select;
					state        <= std_mode;

				---------------------------------------------------------------------------------
				when others => --covering default
					state <= std_mode;
			end case;
		end if;
	end process;

	-----------------------------------------------------------------------------------------------------------
	--Nicholas Winowitch 11/19/2026 ChangePrice connections (maintenance mode, left commented out)
	--  NOTE --EL 11/27/2026: this port map is from before the 11/24 ChangePrices update. the entity now has
	--  item_ready, read_done, error_done, read_request and show_current_price, so this has to be redone
	--  before it gets uncommented. key0 also still resets the ram directly (see Ram port map), which
	--  would wipe every price when key0 is used as "save" in maintenance mode.
	-----------------------------------------------------------------------------------------------------------
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

END FPArch;

--if you need to make an instance of the clock with a value that is not 62500 (this is just an init value)
--do this (also add the clk_div component declaration back in the architecture):
--div_example : clk_div
--		generic map (cnt_max => 62500)
--		port map (clock_in => clk_in, clock_out => clk_example);
--EL 10/30/26