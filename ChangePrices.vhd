-- Nicholas Winowitch Change Price entity
-- Updated 11/23/2026

-- This controller handles the technician's item selection and price entry.
-- KEY2 enters or leaves maintenance. KEY0 saves while maintenance is active.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ChangePrices is

    -- Wait about 10 ms for a button to settle before accepting the press.
    generic (
        DEBOUNCE_TICKS : positive := 500_000
    );
    port (
        -- Clock, reset, and physical board buttons.
        clk   : in std_logic; -- Board clock: 50 MHz.
        reset : in std_logic; -- Separate active-high reset.
        key0  : in std_logic; -- Active-low Save in maintenance, Reset otherwise.
        key2  : in std_logic; -- Active-low Enter/Exit maintenance.

        -- Main gives permission to enter maintenance when no purchase is active.
        purchase_idle : in std_logic;

        -- The keypad sends the item as two decimal digits, such as x"23".
        -- item_ready says both digits have been entered and the key is released.
        -- We still check that both digits are between 1 and 4 before using them.
        item_address : in std_logic_vector(7 downto 0);
        item_ready   : in std_logic;

        -- These switch levels have already been debounced in the main file.
        sw_clean : in std_logic_vector(3 downto 0);

        -- These signals let this controller ask the main file for something
        -- and wait until that work is finished.
        read_done  : in std_logic; -- The stored price is available.
        error_done : in std_logic; -- The error display has finished its two seconds.

        read_request : out std_logic; -- Ask main to read the selected RAM location.
        show_current_price : out std_logic; -- Show the old price before editing.

        -- Main uses these outputs to pause purchases and choose what to display.
        setup_active   : out std_logic; -- High throughout maintenance.
        clear_selector : out std_logic; -- Clear the old keypad entry.
        item_chosen    : out std_logic; -- A valid item has been selected.
        price_error    : out std_logic; -- High during either item or price errors.

        -- Prices are stored as whole cents. For example, 135 means $1.35.
        -- Zero is needed while starting or clearing a draft.
        draft_cents : out integer range 0 to 999;

        -- Supply both reset polarities because the other modules use different ones.
        -- Main registers these requests before sending them to those modules.
        system_reset : out std_logic; -- Active high.
        ram_reset_n  : out std_logic; -- Active low.

        -- Main captures this address and price when a save is requested.
        -- write_request asks for a save; it does not confirm that RAM is finished.
        write_request : out std_logic;
        ram_address   : out std_logic_vector(7 downto 0);
        ram_price     : out std_logic_vector(11 downto 0)
    );

end entity;


architecture rtl of ChangePrices is

    -- Each state is one step in selecting, reviewing, changing, or saving a price.
    type state_t is (
        purchase_mode,    -- Wait for permission and a KEY2 press.
        choose_item,      -- Wait for a complete keypad entry.
        send_read,        -- Request the item's current price for one clock.
        wait_read,        -- Wait for main to finish reading RAM.
        preview_price,    -- Show the existing price before the first switch flip.
        edit_price,       -- Add switch values to the replacement price.
        send_write,       -- Request a save for one clock.
        item_error_state, -- Wait out an error, then request a fresh item.
        price_error_state -- Wait out an error, then retry the same item.
    );

    signal state : state_t := purchase_mode;

    -- Remember the chosen item so later keypad activity cannot redirect the save.
    signal selected_address : std_logic_vector(7 downto 0) := x"11";

    -- Remember the switch levels so each off-to-on flip adds money only once.
    signal previous_sw : std_logic_vector(3 downto 0) := "0000";

    -- Work in whole cents. Zero is needed while clearing or starting a new price.
    signal draft : integer range 0 to 999 := 0;

    -- Index 0 belongs to KEY0; index 1 belongs to KEY2.
    signal button_pressed : std_logic_vector(1 downto 0);
    signal button_pulse   : std_logic_vector(1 downto 0);

    signal maintenance : std_logic;
    signal reset_now   : std_logic;
    signal save_now    : std_logic;


    -- RAM stores each decimal digit in its own four-bit section.
    -- For example, 135 cents becomes x"135" in BCD:
    -- hundreds = 1, tens = 3, and ones = 5.
    function to_bcd(value : natural) return std_logic_vector is

        variable result : std_logic_vector(11 downto 0);

    begin
        result(11 downto 8) :=
            std_logic_vector(to_unsigned(value / 100, 4));

        result(7 downto 4) :=
            std_logic_vector(to_unsigned((value / 10) mod 10, 4));

        result(3 downto 0) :=
            std_logic_vector(to_unsigned(value mod 10, 4));

        return result;
    end function;

begin

    -- The board buttons are low when pressed. Invert them so the debounce
    -- modules see a rising input when a button is pressed.
    button_pressed(0) <= not key0;
    button_pressed(1) <= not key2;


    -- Use one debounce instance per button. Each accepted press produces a
    -- one-clock pulse, so holding a button does not repeat the action.
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


    -- All states except purchase_mode belong to maintenance.
    -- This is how KEY0 becomes Save during an edit and Reset during normal use.
    maintenance <= '0' when state = purchase_mode else '1';

    setup_active <= maintenance;

    reset_now <= reset or
                 (button_pulse(0) and not maintenance);

    save_now <= button_pulse(0) and maintenance;

    system_reset <= reset_now;
    ram_reset_n  <= not reset_now;


    -- Tell main whether an item is selected, an error is active,
    -- or the existing stored price should be displayed.
    item_chosen <= '0' when
        state = purchase_mode or
        state = choose_item or
        state = item_error_state
        else '1';

    price_error <= '1' when
        state = item_error_state or
        state = price_error_state
        else '0';

    show_current_price <= '1' when
        state = preview_price
        else '0';


    -- Keep the selected address and replacement price available to main.
    -- The display uses integer cents, while RAM receives the BCD version.
    ram_address <= selected_address;
    ram_price   <= to_bcd(draft);
    draft_cents <= draft;


    -- These states last one clock, making each request a single pulse.
    -- KEY2 suppresses a request that main has not accepted yet.
    -- Once a write has been accepted, main finishes it before releasing RAM.
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


    -- Clear old digits when changing modes, resetting, or saving an item.
    -- During an invalid-item error, keep the keypad clear so the same bad
    -- address is not accepted again when the timer finishes.
    clear_selector <= '1' when
        reset_now = '1' or
        state = send_write or
        state = item_error_state or
        (button_pulse(1) = '1' and
         (state /= purchase_mode or purchase_idle = '1'))
        else '0';


    -- Make state changes on the board clock.
    -- Variables let us calculate the complete new total before checking it.
    process(clk)

        variable switched_on : std_logic_vector(3 downto 0);

        -- Enough room for 999 cents plus all four switch values at once.
        variable total : integer range 0 to 1139;

        -- Four bits can represent 0 through 15.
        -- We check the smaller valid item range after converting the digits.
        variable row_number, col_number : integer range 0 to 15;

    begin
        if rising_edge(clk) then

            -- A bit is high here only when that switch just changed from 0 to 1.
            switched_on := sw_clean and not previous_sw;

            -- Track switches even during errors so ignored flips are not added later.
            previous_sw <= sw_clean;


            -- Reset takes priority over any mode change, entry, or save.
            if reset_now = '1' then

                state            <= purchase_mode;
                selected_address <= x"11";
                draft            <= 0;


            -- KEY2 may leave any maintenance state, including an error state.
            -- Entering maintenance requires permission from the main FSM.
            elsif button_pulse(1) = '1' then

                if state /= purchase_mode then
                    state <= purchase_mode; -- Discard the unsaved draft.

                elsif purchase_idle = '1' then
                    state <= choose_item;

                end if;

                draft <= 0;


            else
                case state is

                    when purchase_mode =>

                        -- The purchase FSM handles customers.
                        -- This controller waits for KEY2.
                        null;


                    when choose_item =>

                        -- Split the two entered digits into row and column numbers.
                        -- An entry can be complete but still be outside the 4x4 RAM.
                        if item_ready = '1' then

                            row_number :=
                                to_integer(unsigned(item_address(7 downto 4)));

                            col_number :=
                                to_integer(unsigned(item_address(3 downto 0)));

                            if row_number >= 1 and row_number <= 4 and
                               col_number >= 1 and col_number <= 4 then

                                -- Keep this item and request its current price.
                                selected_address <= item_address;
                                draft            <= 0;
                                state            <= send_read;

                            else

                                state <= item_error_state;

                            end if;

                        elsif save_now = '1' then

                            -- Save was pressed before a valid item was selected.
                            state <= item_error_state;

                        end if;


                    when send_read =>

                        -- read_request is high in this state.
                        -- Move on so the request only lasts one clock.
                        state <= wait_read;


                    when wait_read =>

                        -- Wait until main has the stored price ready to display.
                        if read_done = '1' then
                            state <= preview_price;
                        end if;


                    -- First show the existing RAM price.
                    -- The first switch flip starts a replacement price from zero.
                    -- Saving before entering anything is a zero-price error.
                    when preview_price | edit_price =>

                        total := draft;

                        -- Separate if statements allow more than one switch
                        -- to add its value during the same clock cycle.
                        if switched_on(0) = '1' then 
								    total := total + 5;
                        end if;

                        if switched_on(1) = '1' then
                            total := total + 10;
                        end if;

                        if switched_on(2) = '1' then
                            total := total + 25;
                        end if;

                        if switched_on(3) = '1' then
                            total := total + 100;
                        end if;


                        if total > 999 then

                            -- Reject overflow before assigning it to the draft.
                            -- This prevents a large price from wrapping around.
                            draft <= 0;
                            state <= price_error_state;

                        elsif save_now = '1' then

                            -- The upper limit was checked above.
                            -- Five cents is the minimum accepted price.
                            if total >= 5 then

                                draft <= total;
                                state <= send_write;

                            else

                                draft <= 0;
                                state <= price_error_state;

                            end if;

                        elsif switched_on /= "0000" then

                            -- Keep the new draft and switch the display from
                            -- the stored price to the replacement being entered.
                            draft <= total;
                            state <= edit_price;

                        end if;


                    when send_write =>

                        -- Main captures the save request and finishes the RAM write.
                        -- It blocks another item selection until that access is done.
                        draft <= 0;
                        state <= choose_item;


                    when item_error_state =>

                        -- Ignore Save and switch input while the message is shown.
                        -- KEY2 can still exit through the higher-priority branch.
                        if error_done = '1' then
                            state <= choose_item;
                        end if;


                    when price_error_state =>

                        -- Keep the selected item and restart its draft at zero.
                        -- Neither error state produces a RAM write request.
                        if error_done = '1' then
                            draft <= 0;
                            state <= edit_price;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture;