-- Nicholas Winowitch Change Price entity
-- Updated 11/23/2026
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This controller handles entering and leaving maintenance,
-- selecting an item, entering its replacement price, and requesting Save.
-- KEY2 enters or leaves maintenance.
-- KEY0 saves during maintenance and requests reset during customer operation.

entity ChangePrices is

    -- About 10 ms of debounce time with the 50 MHz board clock.
    -- A smaller value can be used to speed up simulation.
    generic (
        DEBOUNCE_TICKS : positive := 500_000
    );

    port (
        -- Board clock and separate active-high reset.
        clk   : in std_logic;
        reset : in std_logic;

        -- Physical buttons are active low: 0 means pressed.
        key0 : in std_logic;
        key2 : in std_logic;
        purchase_idle : in std_logic;

        -- The keypad sends two decimal digits, such as x"23" for item 23.
        item_address : in std_logic_vector(7 downto 0);
        item_ready   : in std_logic; -- both digits are entered and the key is released.
        sw_clean : in std_logic_vector(3 downto 0);
        read_done : in std_logic;
        error_done : in std_logic; -- ErrorTimer reports when the two-second error display is finished.
       
		
	  	  read_request       : out std_logic; -- Asks Final to read the selected item and display its existing price.
        show_current_price : out std_logic;
        -- Final uses these signals to pause purchases and choose the display.
        setup_active   : out std_logic; -- High throughout maintenance.
        clear_selector : out std_logic; -- Clear the old keypad entry.
        item_chosen    : out std_logic; -- A valid item has been selected.
        price_error    : out std_logic; -- An item or price error is active.
		  
        draft_cents : out integer range 0 to 999; --use whole cents. For example, 135 means $1.35.

        -- Supply both reset polarities because the other modules differ.
        system_reset : out std_logic; -- Active high.
        ram_reset_n  : out std_logic; -- Active low.
        write_request : out std_logic; -- write_request is a request, not confirmation that RAM saved it.
        ram_address   : out std_logic_vector(7 downto 0);
        ram_price     : out std_logic_vector(11 downto 0)
    );

end entity ChangePrices;


architecture rtl of ChangePrices is

    -- Each state represents one step of the maintenance process.
    type state_t is (
        purchase_mode,    -- Wait for permission and a KEY2 press.
        choose_item,      -- Wait for a complete keypad entry.
        send_read,        -- Request the existing price for one clock.
        wait_read,        -- Wait for main to finish reading RAM.
        preview_price,    -- Show the existing price before editing.
        edit_price,       -- Add switch values to the replacement price.
        send_write,       -- Request a save for one clock.
        item_error_state, -- Wait through an error, then select another item.
        price_error_state -- Wait through an error, then retry the same item.
    );

    signal state : state_t := purchase_mode;

    -- Remember the selected item so later keypad activity cannot change which location receives the new price.
    signal selected_address : std_logic_vector(7 downto 0)
                            := x"11";

    -- Remember switch levels so each off-to-on flip adds money once.
    signal previous_sw : std_logic_vector(3 downto 0) := "0000";

    -- Work in whole cents.
    -- The allowed save range is checked later in the process.
    signal draft : integer range 0 to 999 := 0;

    -- Index 0 belongs to KEY0. Index 1 belongs to KEY2.
    signal button_pressed : std_logic_vector(1 downto 0);
    signal button_pulse   : std_logic_vector(1 downto 0);

    -- Internal signals for maintenance status and button actions.
    signal maintenance : std_logic;
    signal reset_now   : std_logic;
    signal save_now    : std_logic;


    -- RAM stores each decimal digit in its own four-bit section.
    -- For example, 135 cents becomes x"135" in BCD.
    -- Dividing by 100 gives the hundreds digit.
    -- Dividing by 10 and taking mod 10 gives the tens digit.
    -- Taking mod 10 gives the ones digit.
    function to_bcd(value : natural)
        return std_logic_vector is

        variable result : std_logic_vector(11 downto 0);

    begin
        result(11 downto 8) :=
            std_logic_vector(to_unsigned(value / 100, 4));

        result(7 downto 4) :=
            std_logic_vector(
                to_unsigned((value / 10) mod 10, 4));

        result(3 downto 0) :=
            std_logic_vector(to_unsigned(value mod 10, 4));

        return result;
    end function;

begin

    -- The physical buttons go low when pressed.
    -- Invert them so the debounce modules see a rising input.
    button_pressed(0) <= not key0;
    button_pressed(1) <= not key2;


    -- Create one debounce instance for each button.
    -- Each accepted press produces a one-clock pulse.
    -- Holding a button down therefore does not repeat its action.
    gen_button_db : for i in 0 to 1 generate

        db_button : entity work.debounce
            generic map (
                cnt_max => DEBOUNCE_TICKS
            )
            port map (
                clk      => clk,
                rst      => reset,
                sw_in    => button_pressed(i),
                sw_out   => open,
                sw_pulse => button_pulse(i)
            );

    end generate;


    -- Every state except purchase_mode belongs to maintenance.
    -- Main uses setup_active to pause customer operation.
    maintenance <= '0' when state = purchase_mode else '1';

    setup_active <= maintenance;

    -- KEY0 requests Reset outside maintenance.
    reset_now <= reset or
                 (button_pulse(0) and not maintenance);

    -- KEY0 requests Save inside maintenance.
    save_now <= button_pulse(0) and maintenance;

    -- Provide the same reset request in both polarities.
    system_reset <= reset_now;
    ram_reset_n  <= not reset_now;


    -- Tell main whether an item is currently selected.
    -- Keep the item selected during a price error so it can be retried.
    item_chosen <= '0' when
        state = purchase_mode or
        state = choose_item or
        state = item_error_state
        else '1';

    -- Hold the error flag high while waiting in either error state.
    price_error <= '1' when
        state = item_error_state or
        state = price_error_state
        else '0';

    -- The actual existing price is stored in FinalProject.
    -- This signal tells main when to display it.
    show_current_price <= '1' when
        state = preview_price
        else '0';

    -- Supply the selected item and replacement price to main.
    ram_address <= selected_address;
    ram_price   <= to_bcd(draft);
    draft_cents <= draft;


    -- These request states last one clock, producing a single pulse.
    -- KEY2 suppresses a request that main has not accepted yet.
    -- Once main accepts a write, it completes that RAM operation.
    read_request <= '1' when
        state = send_read and
        reset_now = '0' and
        button_pulse(1) = '0'
        else '0';

    write_request <= '1' when
        state = send_write and
        reset_now = '0' and
        button_pulse(1) = '0'
        else '0';


    -- Clear old digits when resetting, changing modes, or saving.
    -- During an invalid-item error, keep the keypad cleared so
    -- the same bad address is not accepted again after the timer.
    clear_selector <= '1' when
        reset_now = '1' or
        state = send_write or
        state = item_error_state or
        (button_pulse(1) = '1' and
         (state /= purchase_mode or purchase_idle = '1'))
        else '0';


    -- State changes happen on the rising edge of the board clock.
    -- Variables let us calculate the complete total before checking Save.
    -- A switch flip and Save on the same clock use the updated total.
    process(clk)

        variable switched_on : std_logic_vector(3 downto 0);

        -- Enough space for 999 plus all four switch values.
        variable total : integer range 0 to 1139;

        variable row_number : integer range 0 to 15;
        variable col_number : integer range 0 to 15;

    begin
        if rising_edge(clk) then

            -- Detect only switches that just changed from off to on.
            -- Leaving a switch on does not keep adding money.
            -- Turn it off and back on, allowing debounce to settle to add that amount again.
            switched_on := sw_clean and not previous_sw;

            -- Keep tracking switches during errors too.
            -- Ignored flips must not become delayed input afterward.
            previous_sw <= sw_clean;

            -- Reset takes priority over mode changes, entry, and Save.
            if reset_now = '1' then
                state            <= purchase_mode;
                selected_address <= x"11";
                draft            <= 0;


            -- KEY2 can leave any maintenance state, including errors.
            -- Entering maintenance requires permission from main.
            elsif button_pulse(1) = '1' then

                if state /= purchase_mode then
                    state <= purchase_mode;

                elsif purchase_idle = '1' then
                    state <= choose_item;
                end if;

                -- Discard any unfinished replacement price.
                draft <= 0;


            else
                case state is

                    when purchase_mode =>
                        -- Main handles customers while this controller waits.
                        null;


                    when choose_item =>
                        -- A complete keypad entry may still be an invalid item.
                        -- Split its two digits into row and column numbers.
                        if item_ready = '1' then

                            row_number :=
                                to_integer(unsigned(
                                    item_address(7 downto 4)));

                            col_number :=
                                to_integer(unsigned(
                                    item_address(3 downto 0)));

                            -- Both digits must be between 1 and 4
                            -- to identify a location in the 4-by-4 RAM.
                            if row_number >= 1 and
                               row_number <= 4 and
                               col_number >= 1 and
                               col_number <= 4 then

                                -- Remember this item and request its old price.
                                selected_address <= item_address;
                                draft <= 0;
                                state <= send_read;

                            else
                                state <= item_error_state;
                            end if;

                        elsif save_now = '1' then
                            -- Save cannot proceed without an item.
                            state <= item_error_state;
                        end if;


                    when send_read =>
                        -- read_request is high during this state.
                        -- Move on so the request lasts only one clock.
                        state <= wait_read;


                    when wait_read =>
                        -- Wait until main has captured the existing RAM price.
                        -- read_done comes from the main-file RAM process.
                        if read_done = '1' then
                            state <= preview_price;
                        end if;


                    when preview_price | edit_price =>
                        -- Its first switch flip changes the display to the draft.
                        total := draft;

                        -- Add every switch that flipped during this clock.
                        -- Separate if statements allow simultaneous additions.

                        -- SW0 adds five cents.
                        if switched_on(0) = '1' then
                            total := total + 5;
                        end if;

                        -- SW1 adds ten cents.
                        if switched_on(1) = '1' then
                            total := total + 10;
                        end if;

                        -- SW2 adds twenty-five cents.
                        if switched_on(2) = '1' then
                            total := total + 25;
                        end if;

                        -- SW3 adds one dollar.
                        if switched_on(3) = '1' then
                            total := total + 100;
                        end if;


                        -- Reject overflow before assigning it to draft.
                        -- The saved RAM price is unaffected by this error.
                        if total > 999 then
                            draft <= 0;
                            state <= price_error_state;

                        elsif save_now = '1' then

                            -- Five cents is the minimum valid price.
                            -- Saving an empty draft produces an error.
                            -- The upper limit was already checked above.
                            if total >= 5 then
                                draft <= total;
                                state <= send_write;

                            else
                                draft <= 0;
                                state <= price_error_state;
                            end if;

                        elsif switched_on /= "0000" then
                            -- Keep the replacement total and display it.
                            draft <= total;
                            state <= edit_price;
                        end if;


                    when send_write =>
                        -- Main captures the address and BCD price.
                        -- It then completes RAM's multi-clock write and
                        -- blocks another item selection until finished.
                        draft <= 0;
                        state <= choose_item;


                    when item_error_state =>
                        -- Ignore Save and switches while the error is shown.
                        -- KEY2 can still exit through the branch above.
                        -- After the timer finishes, request a fresh item.
                        if error_done = '1' then
                            state <= choose_item;
                        end if;


                    when price_error_state =>
                        -- Keep the selected item and retry its price from zero.
                        -- ErrorTimer counts the two seconds externally.
                        -- error_done lets this state resume.
                        -- No write request is produced during the error.
                        if error_done = '1' then
                            draft <= 0;
                            state <= edit_price;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;