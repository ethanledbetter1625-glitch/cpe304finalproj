--When you make changes, initial and date them with a comment.
--ALWAYS ALWAYS ALWAYS PULL FROM ORIGIN BEFORE MAKING CHANGES

-- Nicholas Winowitch 11/27/2026 ADDITION BEGIN: ChangePrices integration overview.
-- ChangePrices owns KEY2 entry/exit and makes KEY0 Save during maintenance.
-- The main file pauses purchases, completes RAM accesses, shares the existing
-- message timer, and selects the technician display while editing prices.
-- NW 11/27/2026 ADDITION END: ChangePrices integration overview.

--HOW CUSTOMER MODE WORKS --EL 11/27/2026
--  controls:
--    keypad : type a 2 digit item number, row digit then column digit (1-4 each, so items 11 to 44)
--    sw0-3  : insert 5c, 10c, 25c, $1 (flip up to drop a coin, flip back down to get ready for the next)
--    key3   : vend
--    key1   : cancel / refund
--    key0   : reset everything (also loads $1.00 into every ram slot, press once after programming)
--
--  displays (hex5 is the far left, money is in cents so 125 = $1.25):
--    picking an item   : [item][item] [blank] [paid][paid][paid]   item shows "--" until it is typed
--    item picked       : [price][price][price] [paid][paid][paid]
--    vending           : C H g [change][change][change]            change also blinks out on the leds
--    refunding         : r E F [refund][refund][refund]            refund also blinks out on the leds
--    bad item number   : E r r [blank] [item][item]                2 sec, use case 4
--    not enough money  : A d d [still owed][..][..]                2 sec, use case 6
--    vend with no item : S E L E C t                               2 sec, use case 9
--
--  leds: payment owns them normally (flashes a coin that got kicked back because you already paid),
--        the dispenser owns them while it pays out (led3 $1, led2 25c, led1 10c, led0 5c)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FinalProject is
	--timings are generics so they can be shrunk for simulation, quartus uses these defaults --EL 11/27/2026
	generic(DB_TICKS       : integer := 500_000;      --debounce time, 500k @ 50mhz = 10 ms
	        MSG_TICKS      : integer := 100_000_000;  --message time, 100m @ 50mhz = 2 sec
	        COIN_LED_TICKS : integer := 25_000_000);  --kicked back coin led time, 25m @ 50mhz = 0.5 sec
	port(clk_in : in std_logic;    --50 mhz board clock
		  key0 : in std_logic;      --active low reset
		  Key2 : in std_logic;      --active low maintenance button, not used in customer mode --Nicholas Winowitch 11/18/2026
		  Key1 : in std_logic;      --active low cancel/refund --Graham Fales 11/21/2026
		  Key3 : in std_logic;      --active low vend --Graham Fales 11/20/2026
		  LEDR : out std_logic_vector(3 downto 0); --coin leds --CC 11/18/2026
		  row : inout std_logic_vector(3 downto 0);    --keypad rows --Graham Fales 11/14/2026
		  column : inout std_logic_vector(2 downto 0); --keypad columns --Graham Fales 11/14/2026
		  display0 : out std_logic_vector(6 downto 0);
		  display1 : out std_logic_vector(6 downto 0);
		  display2 : out std_logic_vector(6 downto 0);
		  display3 : out std_logic_vector(6 downto 0);
		  display4 : out std_logic_vector(6 downto 0);
		  display5 : out std_logic_vector(6 downto 0);
		  sw       : in std_logic_vector(3 downto 0)); --raw switches, use sw_clean in logic
end FinalProject;

ARCHITECTURE FPArch OF FinalProject IS

	--lab5 display codes, 5 bits per digit into Part2 --EL 11/17/2026
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

	--turns a 0-999 cents value into 3 display codes (hundreds & tens & ones) = 15 bits --EL 11/27/2026
	--ex: 125 -> C_1 & C_2 & C_5
	function money3(value : integer range 0 to 999) return std_logic_vector is
		variable result : std_logic_vector(14 downto 0);
	begin
		result(14 downto 10) := std_logic_vector(to_unsigned(value / 100, 5));        --hundreds digit
		result(9 downto 5)   := std_logic_vector(to_unsigned((value / 10) mod 10, 5)); --tens digit
		result(4 downto 0)   := std_logic_vector(to_unsigned(value mod 10, 5));        --ones digit
		return result;
	end function;

	--turns one 4 bit keypad digit into a display code --EL 11/27/2026
	--the shift register holds 1111 in a spot that hasnt been typed yet, that shows as a dash
	function key_dig(nib : std_logic_vector(3 downto 0)) return std_logic_vector is
	begin
		if nib = "1111" then
			return C_DASH;
		else
			return '0' & nib;   --0-9 codes are just the number with a 0 in front
		end if;
	end function;

	--money --EL 11/17/2026, 11/27/2026
	signal price        : integer range 0 to 999;       --price straight out of the ram (through To_Int), cents
	signal p_hund, p_ten, p_one : integer range 0 to 9; --ram price digits
	signal paid         : integer range 0 to 999;       --total the customer has put in, from Payment
	signal num          : integer range 0 to 999 := 0;  --change = paid - price, from ChangeCalc
	signal item_price   : integer range 0 to 999 := 0;  --price of the picked item, latched after the ram read
	signal item_sel     : std_logic := '0';             --1 = a valid item is picked right now
	signal price_to_pay : integer range 0 to 999;       --item_price when an item is picked, 0 when not
	                                                    --  (0 tells Payment "no item yet, take every coin")
	signal owed         : integer range 0 to 999;       --how much more is needed, shown on "Add"
	signal dispense_amt : integer range 0 to 999 := 0;  --amount for the dispenser (change on vend, all of paid on refund)

	--display --EL 11/17/2026
	signal xin_s : std_logic_vector(29 downto 0); --6 display codes x 5 bits into Part2

	--switches --EL 10/31/2026
	signal sw_clean : std_logic_vector(3 downto 0); --debounced switch levels
	signal sw_pulse : std_logic_vector(3 downto 0); --1 clk pulse on each up-flip (not used, Payment does its own edge detect)

	--buttons --EL 11/27/2026
	--key1/key3 get flipped to active high and run through the debounce entity,
	--its sw_pulse output gives exactly 1 clock pulse per press no matter how long it is held
	signal key0_hi      : std_logic; --key0 flipped to active high, for entities with an active high reset
	signal key1_hi      : std_logic; --1 = key1 pressed
	signal key3_hi      : std_logic; --1 = key3 pressed
	signal cancel_pulse : std_logic; --1 clock pulse per key1 press
	signal vend_pulse   : std_logic; --1 clock pulse per key3 press

	--keypad --Graham Fales 11/14/2026, 11/20/2026
	signal address_k     : std_logic_vector(7 downto 0);  --2 typed digits, upper nibble = row digit, lower = column digit
	signal data_kPad     : std_logic_vector(11 downto 0); --3 digit data register, not used in customer mode
	signal reg_sel       : std_logic := '1';              --1 = keypad digits go into the address register --EL 11/17/2026
	signal addrs_changed : std_logic := '0';              --1 the whole time a keypad button is held
	signal clear_addrs   : std_logic := '0';              --1 = wipe the typed digits

	--keypad press tracking --EL 11/27/2026
	--addrs_changed comes from the keypad's slow scan clock, so it goes through 2 flip flops (sync)
	--before the fsm uses it. the 3rd flip flop is the old value, for catching the moment a key goes down
	signal kp_sync   : std_logic_vector(2 downto 0) := "000";
	signal kp_held   : std_logic;                         --synced addrs_changed, 1 while a key is held
	signal kp_press  : std_logic;                         --1 clock pulse when a key first goes down
	signal key_count : integer range 0 to 2 := 0;         --digits typed since the last clear
	signal addr_ok   : std_logic;                         --1 when both digits are 1-4 (a real slot in the 4x4 ram)
	signal sel_addr  : std_logic_vector(7 downto 0) := x"11"; --picked item number, sent to the ram
	signal bad_addr  : std_logic_vector(7 downto 0) := x"FF"; --copy of a bad item number for the "Err" message

	--ram --Graham Fales 11/14/2026
	signal R_W        : std_logic;                     --0 = write, 1 = read
	signal Ram_Enter  : std_logic := '1';              --0 = ram is allowed to clock
	signal address_R  : std_logic_vector(7 downto 0);  --item number the ram reads
	signal data_R_in  : std_logic_vector(11 downto 0); --price to write (maintenance mode)
	signal data_R_out : std_logic_vector(11 downto 0); --price that was read, 3 bcd digits
	signal ram_wait   : integer range 0 to 7 := 0;     --gt_price holds Ram_Enter low for 8 clocks so the ram fsm
	                                                   --  can go standby -> read_st and put the price out --EL 11/27/2026

	--leds --Graham Fales 11/14/2026
	signal LED_E   : std_logic_vector(3 downto 0); --from Payment (kicked back coins)
	signal LED_C   : std_logic_vector(3 downto 0); --from ChangeDispenser (change/refund)
	signal LED_sel : std_logic := '1';             --1 = payment owns the leds, 0 = dispenser

	--change dispenser --CC 11/18/2026
	signal dispense_start : std_logic := '0'; --1 clock pulse starts dispensing dispense_amt
	signal dispenser_busy : std_logic;        --1 while still dispensing
	signal dispenser_done : std_logic;        --1 clock pulse when finished

	--payment --Graham Fales 11/20/2026
	signal rst_pay : std_logic := '1'; --1 = hold paid at 0

	--message timer (nick's ErrorTimer) --EL 11/27/2026
	signal timer_start : std_logic := '0'; --1 clock pulse starts a 2 sec countdown
	signal timer_busy  : std_logic;        --1 while counting (not used)
	signal timer_done  : std_logic;        --1 clock pulse when the 2 sec are up

	--master fsm states --EL 11/27/2026 (built off of graham's 11/17 fsm)
	--  std_mode  : waiting for an item number, money can already go in here
	--  gt_price  : valid item typed, let the ram clock and grab its price
	--  disp_pay  : item picked, show price + paid, wait for vend / cancel / a new item number
	--  err_item  : bad item number, "Err xx" for 2 sec (use case 4)
	--  err_sel   : vend with no item, "SELECt" for 2 sec (use case 9)
	--  err_short : vend without enough money, "Add xxx" for 2 sec (use case 6)
	--  vend_go   : enough money, start the dispenser on the change (use cases 1 and 5)
	--  ref_go    : cancel with money in, start the dispenser on all of paid (use case 3)
	--  vend_st   : wait for the dispenser to finish
	--  hold_st   : leave the vend/refund message up for 2 sec
	--  clear_st  : wipe the keypad, payment and picked item, then start over
	
-- NW 11/27/2026 CHANGE BEGIN: Existing FSM state list.
    -- Appended technician_mode to the group's state list. It holds customer
    -- operation while ChangePrices runs, then returns to customer selection.
    type FSM_states is (std_mode,gt_price,disp_pay,err_item,err_sel,err_short,vend_go,ref_go,vend_st,hold_st,clear_st,technician_mode);					 
    -- NW 11/27/2026 CHANGE END: Existing FSM state list.
	 
	signal state : FSM_states := std_mode;

	--what the displays show, set by the fsm and read by the display mux --EL 11/27/2026
	type disp_modes is (d_select,d_price,d_vend,d_refund,d_bad_item,d_short,d_no_item);
	signal disp_mode : disp_modes := d_select;

	--maintenance mode hookup for ChangePrices --Nicholas Winowitch 11/18/2026
    signal cp_item_valid     : std_logic; --both keypad address digits are 1-4
    signal cp_purchase_idle  : std_logic; --permission to enter maintenance mode
    signal cp_setup_active   : std_logic; --1 while ChangePrices is in maintenance mode
    signal cp_clear_selector : std_logic; --requests clearing the keypad selection
    signal cp_item_chosen    : std_logic; --1 when an item is selected for editing
    signal cp_price_error    : std_logic; --1 when an invalid selection or price is detected
    signal cp_draft_cents    : integer range 0 to 999; --price being entered, cents (135 = $1.35)
    signal cp_system_reset   : std_logic; --active high reset request
    signal cp_ram_reset_n    : std_logic; --active low ram reset request
    signal cp_write_request  : std_logic; --1 clock save request
    signal cp_address        : std_logic_vector(7 downto 0);  --selected item, x23 = item 23
    signal cp_price          : std_logic_vector(11 downto 0); --new price in bcd, x135 = $1.35
	
	-- NW 11/27/2026 ADDITION BEGIN: ChangePrices integration signals.
    -- These additional signals connect the current controller's read and timer ports.
    signal cp_item_ready, cp_address_complete : std_logic;
    signal cp_read_request, cp_show_current_price : std_logic;
    signal cp_read_done : std_logic := '0';
    signal cp_current_price : std_logic_vector(11 downto 0) := x"100";

    -- Share the keypad and keep Payment cleared while editing prices.
    signal cp_hold_purchase, cp_keypad_clear, cp_pay_reset : std_logic;

    -- Register the controller's reset decision before distributing it.
    -- Startup values load the existing RAM defaults and clear the customer FSM.
    signal cp_reset_hi : std_logic := '1';
    signal cp_reset_lo : std_logic := '0';

    -- The RAM entity takes several clocks to change state and complete an access.
    -- Hold a copy of the chosen address and draft until that operation finishes.
    type cp_ram_state_t is (cp_ram_idle, cp_read_arm, cp_read_sample, cp_read_capture, cp_write_arm, cp_write_store, cp_write_finish);
    signal cp_ram_state : cp_ram_state_t := cp_ram_idle;
    signal cp_ram_busy, cp_ram_enable_n : std_logic;
    signal cp_ram_address : std_logic_vector(7 downto 0) := x"11";
    signal cp_saved_price : std_logic_vector(11 downto 0) := x"100";

    -- Keep the one existing ErrorTimer. Choose whose start request reaches it,
    -- cancel a technician message on exit, and return done to ChangePrices.
    signal cp_error_previous, cp_setup_previous : std_logic := '0';
    signal cp_error_start, cp_error_done : std_logic;
    signal msg_start, msg_cancel : std_logic;

    -- The original customer display feeds purchase_xin. xin_s is the final
    -- selection between that value and the technician display.
    signal purchase_xin, cp_xin : std_logic_vector(29 downto 0);
    signal cp_display_address : std_logic_vector(7 downto 0);
    signal cp_display_price : std_logic_vector(14 downto 0);
    -- NW 11/27/2026 ADDITION END: ChangePrices integration signals.
BEGIN

	--switch debounce --EL 11/04/2026
	gen_db : for i in 0 to 3 generate
		 db_i : entity work.debounce
			  generic map (CNT_MAX => DB_TICKS)
			  port map (
					clk      => clk_in,
					rst      => '0',
					sw_in    => sw(i),
					sw_out   => sw_clean(i),
					sw_pulse => sw_pulse(i)
			  );
	end generate;
	
-- NW 11/27/2026 ADDITION BEGIN: Controller connections and entry permission.
    -- An entry is complete when both keypad positions contain decimal digits.
    -- A complete invalid location, such as 25, must reach ChangePrices so it
    -- can show an error. x"FF" and a partly typed address are not complete.
    cp_item_valid <= addr_ok;
    cp_address_complete <= '1' when
        unsigned(address_k(7 downto 4)) <= to_unsigned(9, 4) and
        unsigned(address_k(3 downto 0)) <= to_unsigned(9, 4) else '0';
    cp_item_ready <= cp_address_complete and not kp_held and not addrs_changed
                     and not cp_keypad_clear and not cp_ram_busy;

    -- Customer mode accepts money even before an item is chosen. Require an
    -- empty transaction and no current coin/button/keypad event before entry.
    -- sw_pulse also blocks a coin arriving on the same clock as KEY2.
    cp_purchase_idle <= '1' when
        state = std_mode and paid = 0 and item_sel = '0' and key_count = 0 and
        kp_held = '0' and kp_press = '0' and sw_pulse = "0000" and
        vend_pulse = '0' and cancel_pulse = '0' and dispenser_busy = '0' and
        timer_busy = '0' and timer_start = '0' and cp_ram_busy = '0'
        else '0';

    price_controller : entity work.ChangePrices
        generic map (DEBOUNCE_TICKS => DB_TICKS)
        port map (
            clk => clk_in,
            reset => '0', -- KEY0 reset/save decisions remain inside ChangePrices.
            key0 => key0,
            key2 => key2,
            purchase_idle => cp_purchase_idle,
            item_address => address_k,
            item_ready => cp_item_ready,
            sw_clean => sw_clean,
            read_done => cp_read_done,
            error_done => cp_error_done,
            read_request => cp_read_request,
            show_current_price => cp_show_current_price,
            setup_active => cp_setup_active,
            clear_selector => cp_clear_selector,
            item_chosen => cp_item_chosen,
            price_error => cp_price_error,
            draft_cents => cp_draft_cents,
            system_reset => cp_system_reset,
            ram_reset_n => cp_ram_reset_n,
            write_request => cp_write_request,
            ram_address => cp_address,
            ram_price => cp_price
        );
    -- NW 11/27/2026 ADDITION END: Controller connections and entry permission.
	 
	 -- NW 11/27/2026 ADDITION BEGIN: Shared resets and keypad clearing.
    -- Include the clear request so purchases pause on the entry/exit clock.
    -- Finish any RAM access already accepted before releasing customer mode.
    cp_ram_busy <= '0' when cp_ram_state = cp_ram_idle else '1';
    cp_hold_purchase <= cp_setup_active or cp_ram_busy or cp_clear_selector;
    cp_keypad_clear <= clear_addrs or cp_clear_selector or cp_reset_hi;

    -- Payment now uses the same 50 MHz clock as this controller. It can use
    -- this combined reset directly; no slower-clock reset extension is needed.
    cp_pay_reset <= rst_pay or cp_hold_purchase or cp_reset_hi;

    -- Sampling the reset decision prevents a brief reset when Save and Exit
    -- are pressed together. KEY0 must not reload RAM defaults during a save.
    cp_reset_registers : process(clk_in)
    begin
        if rising_edge(clk_in) then
            cp_reset_hi <= cp_system_reset;
            cp_reset_lo <= cp_ram_reset_n;
        end if;
    end process;
    -- NW 11/27/2026 ADDITION END: Shared resets and keypad clearing.
	 
	 -- NW 11/27/2026 ADDITION BEGIN: Requests for the existing message timer.
    -- Only one mode owns the message timer at a time. Customer requests keep
    -- using timer_start; technician errors request one start when the flag rises.
    cp_error_start <= cp_price_error and not cp_error_previous;
    msg_start <= cp_error_start when cp_hold_purchase = '1' else timer_start;
    msg_cancel <= cp_setup_previous and not cp_setup_active;
    cp_error_done <= timer_done and cp_setup_active;

    cp_request_history : process(clk_in)
    begin
        if rising_edge(clk_in) then
            if cp_reset_hi = '1' then
                cp_error_previous <= '0';
                cp_setup_previous <= '0';
            else
                cp_error_previous <= cp_price_error;
                cp_setup_previous <= cp_setup_active;
            end if;
        end if;
    end process;
    -- NW 11/27/2026 ADDITION END: Requests for the existing message timer.
    
    -- NW 11/27/2026 ADDITION BEGIN: Technician RAM read and save sequence.
    -- Keep the customer's existing sel_addr/ram_wait read sequence in its FSM.
    -- This process handles only the reads and writes requested by ChangePrices.
    cp_ram_access : process(clk_in)
    begin
        if rising_edge(clk_in) then
            cp_read_done <= '0'; -- One-clock acknowledgement after the price is captured.
            if cp_reset_hi = '1' then
                cp_ram_state <= cp_ram_idle;
                cp_ram_address <= x"11";
                cp_saved_price <= x"100";
                cp_current_price <= x"100";
            else
                case cp_ram_state is
                    when cp_ram_idle =>
                        if cp_write_request = '1' then
                             --the controller clears its draft after the one-clock request, before RAM finishes the write.
                            cp_ram_address <= cp_address;
                            cp_saved_price <= cp_price;
                            cp_ram_state <= cp_write_arm;
                        elsif cp_read_request = '1' then
                            cp_ram_address <= cp_address;
                            cp_ram_state <= cp_read_arm;
                        end if;
                    when cp_read_arm =>
                        cp_ram_state <= cp_read_sample; -- Allow RAM to enter read_st.
                    when cp_read_sample =>
                        cp_ram_state <= cp_read_capture; -- RAM updates Data_out.
                    when cp_read_capture =>
                        cp_current_price <= data_r_out;
                        cp_read_done <= '1';
                        cp_ram_state <= cp_ram_idle;
                    when cp_write_arm =>
                        cp_ram_state <= cp_write_store; -- RAM enters write_st.
                    when cp_write_store =>
                        cp_ram_state <= cp_write_finish; -- RAM writes the held price.
                    when cp_write_finish =>
                        -- This RAM writes again while leaving write_st. Keep the
                        -- same address/data for that edge, then release the access.
                        cp_ram_state <= cp_ram_idle;
                end case;
            end if;
        end if;
    end process;
    -- NW 11/27/2026 ADDITION END: Technician RAM read and save sequence.
    
    -- NW 11/27/2026 ADDITION BEGIN: Technician display and final display selection.
    -- Show t and the selected item on HEX5..3. Show the stored price first,
    -- then the replacement draft. Err has priority for the timer's duration.
    cp_display_address <= cp_address when cp_item_chosen = '1' else address_k;
    cp_display_price <= C_E & C_R & C_R
                        when cp_price_error = '1' and timer_busy = '1' else
                        C_DASH & C_DASH & C_DASH when cp_item_chosen = '0' else
                        '0' & cp_current_price(11 downto 8) &
                        '0' & cp_current_price(7 downto 4) &
                        '0' & cp_current_price(3 downto 0)
                        when cp_show_current_price = '1' else money3(cp_draft_cents);
    cp_xin <= C_T & key_dig(cp_display_address(7 downto 4)) &
              key_dig(cp_display_address(3 downto 0)) & cp_display_price;
    xin_s <= cp_xin when cp_hold_purchase = '1' else purchase_xin;
    -- NW 11/27/2026 ADDITION END: Technician display and final display selection.
    
	--button debounce, buttons are active low so they get flipped first --EL 11/27/2026
   
-- NW 11/27/2026 CHANGE BEGIN: Shared active-high reset.
-- Replaced not key0 with the controller's registered reset decision.
-- The existing dispenser and message timer still receive key0_hi, but
-- a KEY0 Save in technician mode no longer resets those modules.
   key0_hi <= cp_reset_hi;
-- NW 11/27/2026 CHANGE END: Shared active-high reset.
	key1_hi <= not Key1;
	key3_hi <= not Key3;

	db_cancel : entity work.debounce
		generic map (CNT_MAX => DB_TICKS)
		port map (clk      => clk_in,
		          rst      => '0',
		          sw_in    => key1_hi,
		          sw_out   => open,
		          sw_pulse => cancel_pulse);

	db_vend : entity work.debounce
		generic map (CNT_MAX => DB_TICKS)
		port map (clk      => clk_in,
		          rst      => '0',
		          sw_in    => key3_hi,
		          sw_out   => open,
		          sw_pulse => vend_pulse);

	--keypad --Graham Fales 11/14/2026
	keypad : entity work.Keypad_Entity
		port map(clk         => clk_in,
		-- NW 11/27/2026 CHANGE BEGIN: Keypad reset connection.
      -- Was reset => key0. Use the mode-dependent reset so Save leaves the scanner running.
               reset       => cp_reset_lo,  
      -- NW 11/27/2026 CHANGE END: Keypad reset connection.         
		         Adrs_Data   => reg_sel,
	   -- NW 11/27/2026 CHANGE BEGIN: Keypad clear connection.
      -- Was clear => clear_addrs. Either controller can now request a fresh selection.
               clear       => cp_keypad_clear,
      -- NW 11/27/2026 CHANGE END: Keypad clear connection.
		         column      => column,
		         row         => row,
		         address     => address_k,
		         data        => data_kpad,
		         reg_changed => addrs_changed);

	--sync addrs_changed into the clk_in domain and catch the press edge --EL 11/27/2026
	kp_sync_proc : process(clk_in)
	begin
		if rising_edge(clk_in) then
			kp_sync <= kp_sync(1 downto 0) & addrs_changed;
		end if;
	end process;
	kp_held  <= kp_sync(1);
	kp_press <= kp_sync(1) and not kp_sync(2); --was 0 last clock, 1 now = key just went down

	--both digits have to be 1-4 to be a real slot in the 4x4 ram --EL 11/27/2026
	addr_ok <= '1' when (unsigned(address_k(7 downto 4)) >= 1 and unsigned(address_k(7 downto 4)) <= 4 and
	                     unsigned(address_k(3 downto 0)) >= 1 and unsigned(address_k(3 downto 0)) <= 4)
	           else '0';

	--ram --Graham Fales 11/14/2026
	Ram : entity work.RAM_Entity
		port map(Clk         => clk_in,
		         R_W         => R_W,
		    -- NW 11/27/2026 CHANGE BEGIN: RAM reset connection.
          -- Was Reset => key0. Save must update one item without reloading every RAM default.
                 Reset       => cp_reset_lo,
          -- NW 11/27/2026 CHANGE END: RAM reset connection.
		    
			-- NW 11/27/2026 CHANGE BEGIN: RAM enable connection.
         -- Was clk_enabled => Ram_Enter. The selected owner now controls the RAM's enable.
                 clk_enabled => cp_ram_enable_n,
         -- NW 11/27/2026 CHANGE END: RAM enable connection.
		         Address     => address_r,
		         Data_in     => data_r_in,
		         Data_out    => data_r_out);

	--customer mode only reads the ram --EL 11/27/2026
	
	-- NW 11/27/2026 CHANGE BEGIN: Existing RAM control assignments.
    -- Previously R_W was fixed at 1, data_r_in at zero, and address_r at sel_addr.
    -- Add technician write data and address selection while preserving customer reads.
    R_W <= '0' when cp_ram_state = cp_write_arm or cp_ram_state = cp_write_store else '1';
    data_r_in <= cp_saved_price;
    address_r <= cp_ram_address when cp_ram_busy = '1' else sel_addr;

    -- Ram_Enter still comes from the customer FSM. Only a technician access
    -- overrides it, and the RAM stays disabled while maintenance is idle.
    cp_ram_enable_n <= '0' when cp_ram_busy = '1' and cp_reset_hi = '0' else
                       '1' when cp_hold_purchase = '1' or cp_reset_hi = '1' else Ram_Enter;
    -- NW 11/27/2026 CHANGE END: Existing RAM control assignments.

	--3 bcd digits from the ram into one cents value --EL 11/17/2026
	to_int : entity work.To_Int_Entity port map(data_r_out, p_hund, p_ten, p_one);
	price <= p_hund * 100 + p_ten * 10 + p_one;

	--payment only gets a price once an item is picked --EL 11/27/2026
	price_to_pay <= item_price when item_sel = '1' else 0;

	--how much more the customer has to put in --EL 11/27/2026
	owed <= item_price - paid when (item_sel = '1' and paid < item_price) else 0;

	--payment + change --EL 11/04/2026
	calc : entity work.ChangeCalc
		port map (price => price_to_pay,
					 paid => paid, 
					 change => num,         --paid - price (0 if short)
					 short => open,
				    quarters => open, 
				    dimes => open, 
					 nickels => open, 
					 pennies => open);

	pay : entity work.Payment
		generic map (LED_TICKS => COIN_LED_TICKS)
		port map (clk => clk_in,
	  -- NW 11/27/2026 CHANGE BEGIN: Payment reset connection.
     -- Was reset => rst_pay. This also clears Payment during technician price entry.
                reset => cp_pay_reset,
    -- NW 11/27/2026 CHANGE END: Payment reset connection.
					 sw => sw_clean, 
					 paid => paid,
					 item_price => price_to_pay, --0 when no item, so coins never get kicked back before picking
					 LED => LED_E                --kicked back coin leds, led0 nickel ... led3 dollar
					 );

	--change dispenser --CC 11/18/2026
	Dispenser: entity work.ChangeDispenser
		port map(
			clk => clk_in,
			reset => key0_hi,
			start => dispense_start,
			change_cents => dispense_amt, --change on a vend, all of paid on a refund --EL 11/27/2026
			LED => LED_C,
			busy => dispenser_busy,
			done => dispenser_done
			);

	 --pick which entity drives the leds --Graham Fales 11/20/2026
	 -- NW 11/27/2026 CHANGE BEGIN: LED selection during maintenance.
    -- Added a maintenance condition before the existing customer LED choice.
    -- Technician price entry must not look like a customer coin or refund event.
    LEDR <= "0000" when cp_hold_purchase = '1' else
            LED_E when LED_sel = '1' else LED_C;
    -- NW 11/27/2026 CHANGE END: LED selection during maintenance.

	--message timer, shared by every 2 sec message since only one is up at a time --EL 11/27/2026
	msg_timer : entity work.ErrorTimer
		generic map (TICKS => MSG_TICKS)
		port map (clk    => clk_in,
		          reset  => key0_hi,
	 -- NW 11/27/2026 CHANGE BEGIN: Existing message timer connections.
    -- Was start => timer_start and cancel => '0'. Route the selected mode's
    -- request and cancel a technician error when KEY2 leaves maintenance.
                start  => msg_start,
                cancel => msg_cancel,
    -- NW 11/27/2026 CHANGE END: Existing message timer connections.
		          busy   => timer_busy,
		          done   => timer_done);

	--display mux, left most 5 bits = hex5, right most = hex0 --EL 11/27/2026
 -- NW 11/27/2026 CHANGE BEGIN: Customer display assignment destination.
 -- Changed xin_s to purchase_xin. The customer choices below stay the same;
 -- the final display selection above now chooses customer or technician data.
      with disp_mode select purchase_xin <=
 -- NW 11/27/2026 CHANGE END: Customer display assignment destination.
		--typed digits (dashes until typed), blank, paid
		key_dig(address_k(7 downto 4)) & key_dig(address_k(3 downto 0)) & C_BLANK & money3(paid)   when d_select,
		--price, paid
		money3(item_price) & money3(paid)                                                          when d_price,
		--"CHg" + change
		C_C & C_H & C_G & money3(dispense_amt)                                                     when d_vend,
		--"rEF" + refund
		C_R & C_E & C_F & money3(dispense_amt)                                                     when d_refund,
		--"Err" + blank + the bad number
		C_E & C_R & C_R & C_BLANK & key_dig(bad_addr(7 downto 4)) & key_dig(bad_addr(3 downto 0))  when d_bad_item,
		--"Add" + amount still owed
		C_A & C_D & C_D & money3(owed)                                                             when d_short,
		--"SELECt"
		C_S & C_E & C_L & C_E & C_C & C_T                                                          when d_no_item;

	--EL 11/17/2026
	disp : entity work.Part2
		port map (xin => xin_s,
				  sevenseg1 => display0, 
				  sevenseg2 => display1, 
				  sevenseg3 => display2,
				  sevenseg4 => display3,
				  sevenseg5 => display4,
				  sevenseg6 => display5
				  );

	--MASTER FSM --EL 11/27/2026 (built off of graham's 11/17-11/21 fsm)
	--pulse signals (dispense_start, timer_start, clear_addrs) default to 0 every clock,
	--so a state only sets them when it wants them on
	 -- NW 11/27/2026 CHANGE BEGIN: Customer FSM reset source.
    -- Replaced key0 in the sensitivity list with cp_reset_hi, and changed the
    -- reset condition from key0 = '0' to cp_reset_hi = '1'. KEY0 Save must not
    -- enter the customer's global-reset branch.
    Overall_FSM: process(clk_in, cp_reset_hi)
    begin
        if (cp_reset_hi = '1') then
    -- NW 11/27/2026 CHANGE END: Customer FSM reset source.
			state          <= std_mode;
			disp_mode      <= d_select;
			rst_pay        <= '1';
			LED_sel        <= '1';
			Ram_Enter      <= '1';
			clear_addrs    <= '0';   --NW 11/27/2026 CHANGE: cp_reset_lo clears the keypad on reset
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

			--defaults, states override these when they need to
			dispense_start <= '0';
			timer_start    <= '0';
			clear_addrs    <= '0';
			rst_pay        <= '0';
			Ram_Enter      <= '1';
			LED_sel        <= '1';
     -- NW 11/27/2026 ADDITION BEGIN: Pause customer states during maintenance.
     -- ChangePrices owns mode entry/exit. This branch only holds customer
     -- operation and keeps its selection/payment separate from the price edit.
     if cp_hold_purchase = '1' then
         state <= technician_mode;
         rst_pay <= '1';
         key_count <= 0;
         item_sel <= '0';
         item_price <= 0;
         dispense_amt <= 0;
     else
     -- The matching end if is marked after the customer case statement below.
     -- NW 11/27/2026 ADDITION END: Pause customer states during maintenance.
			--count keypad presses up to 2, states that clear the keypad set this back to 0
			if (kp_press = '1' and key_count < 2) then
				key_count <= key_count + 1;
			end if;

			case state is

				when std_mode => --waiting on an item number, coins can already go in
					disp_mode <= d_select;
					item_sel  <= '0';

					if (key_count = 2 and kp_held = '0') then
						--2nd digit typed and let go, the number is done
						if (addr_ok = '1') then
							sel_addr <= address_k;
							ram_wait <= 0;
							state    <= gt_price;
						else
							bad_addr    <= address_k;
							timer_start <= '1';
							state       <= err_item;
						end if;
						clear_addrs <= '1'; --wipe the keypad so the next number starts fresh
						key_count   <= 0;

					elsif (vend_pulse = '1') then
						--vend with no item, money stays put
						timer_start <= '1';
						state       <= err_sel;

					elsif (cancel_pulse = '1') then
						if (paid > 0) then
							--money in but no item, hand it all back
							dispense_amt <= paid;
							state        <= ref_go;
						else
							--nothing to give back, just wipe any half typed number
							clear_addrs <= '1';
							key_count   <= 0;
						end if;
					end if;

				when gt_price => --let the ram clock so it reads sel_addr
					if (ram_wait < 7) then
						Ram_Enter <= '0';
						ram_wait  <= ram_wait + 1;
					else
						item_price <= price;
						item_sel   <= '1';
						state      <= disp_pay;
					end if;

				when disp_pay => --item picked, show price + paid
					disp_mode <= d_price;
					item_sel  <= '1';

					if (kp_press = '1') then
						--started typing a different item (use case 2), keep the money
						--key_count already went to 1 above, std_mode picks up the 2nd digit
						item_sel <= '0';
						state    <= std_mode;

					elsif (vend_pulse = '1') then
						if (paid >= item_price) then
							dispense_amt <= num; --change
							state        <= vend_go;
						else
							--not enough, block it and keep the money
							timer_start <= '1';
							state       <= err_short;
						end if;

					elsif (cancel_pulse = '1') then
						if (paid > 0) then
							dispense_amt <= paid; --refund everything
							state        <= ref_go;
						else
							--no money in, just drop the item
							item_sel <= '0';
							state    <= std_mode;
						end if;
					end if;

				when err_item => --"Err xx", then back to picking with the money kept
					disp_mode   <= d_bad_item;
					item_sel    <= '0';
					clear_addrs <= '1';  --ignore the keypad while the message is up
					key_count   <= 0;
					if (timer_done = '1') then
						state <= std_mode;
					end if;

				when err_sel => --"SELECt", then back to picking with the money kept
					disp_mode   <= d_no_item;
					clear_addrs <= '1';
					key_count   <= 0;
					if (timer_done = '1') then
						state <= std_mode;
					end if;

				when err_short => --"Add xxx", then back to paying with the item + money kept
					disp_mode   <= d_short;
					item_sel    <= '1';
					clear_addrs <= '1';
					key_count   <= 0;
					if (timer_done = '1') then
						state <= disp_pay;
					end if;

				when vend_go => --start handing back change
					disp_mode      <= d_vend;
					LED_sel        <= '0';      --dispenser owns the leds
					rst_pay        <= '1';      --money is spent, also ignores coins till clear_st
					dispense_start <= '1';
					clear_addrs    <= '1';
					key_count      <= 0;
					state          <= vend_st;

				when ref_go => --start handing back the refund
					disp_mode      <= d_refund;
					LED_sel        <= '0';
					rst_pay        <= '1';
					dispense_start <= '1';
					clear_addrs    <= '1';
					key_count      <= 0;
					item_sel       <= '0';
					state          <= vend_st;

				when vend_st => --dispenser is blinking out coins, display stays on CHg or rEF
					LED_sel     <= '0';
					rst_pay     <= '1';
					clear_addrs <= '1';
					key_count   <= 0;
					if (dispenser_done = '1') then
						timer_start <= '1'; --leave the message up 2 more sec
						state       <= hold_st;
					end if;

				when hold_st => --message stays up so the customer can read it
					LED_sel     <= '0';
					rst_pay     <= '1';
					clear_addrs <= '1';
					key_count   <= 0;
					if (timer_done = '1') then
						state <= clear_st;
					end if;

				when clear_st => --wipe everything and start over
					rst_pay      <= '1';
					clear_addrs  <= '1';
					key_count    <= 0;
					item_sel     <= '0';
					item_price   <= 0;
					dispense_amt <= 0;
					disp_mode    <= d_select;	
			      state        <= std_mode;
-- NW 11/27/2026 ADDITION BEGIN: Return from technician mode.
             when technician_mode =>
   -- Maintenance and any accepted RAM operation have finished. Clear only
   -- the customer selection/payment; keep the prices that were saved in RAM.
               state <= std_mode;
               disp_mode <= d_select;
               clear_addrs <= '1';
               rst_pay <= '1';
               key_count <= 0;
               item_sel <= '0';
               item_price <= 0;
               dispense_amt <= 0;
    -- NW 11/27/2026 ADDITION END: Return from technician mode.
				when others =>
					state <= std_mode;
			end case;
			  -- NW 11/27/2026 ADDITION BEGIN: Close the maintenance hold condition.
          end if; -- Matches if cp_hold_purchase = '1' above the customer case statement.
            -- NW 11/27/2026 ADDITION END: Close the maintenance hold condition.
		end if;
	end process;

END FPArch;