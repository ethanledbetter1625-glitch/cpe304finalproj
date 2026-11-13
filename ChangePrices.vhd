library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ChangePrices is
    port (
        -- 50 MHz clock.
        clk : in std_logic;

        -- Separate active-high reset.
        -- Connect to '0' if no separate reset is used.
        reset : in std_logic;

        -- Physical buttons: 0 means pressed.
        key0 : in std_logic;
        key2 : in std_logic;

        -- 1 means no customer transaction is active.
        purchase_idle : in std_logic;

        -- Selected item from keypad logic.
        -- Example: item 21 = x"21".
        item_address : in std_logic_vector(7 downto 0);
        item_valid   : in std_logic;

        -- Debounced money-switch levels.
        sw_clean : in std_logic_vector(3 downto 0);

        -- Status outputs.
        setup_active   : out std_logic;
        clear_selector : out std_logic;
        item_chosen    : out std_logic;
        price_error    : out std_logic;

        -- Price currently being entered, in cents.
        draft_cents : out integer range 0 to 999;

        -- Reset outputs for other modules.
        system_reset : out std_logic; -- active high
        ram_reset_n  : out std_logic; -- active low

        -- Outputs to the RAM write interface.
        write_request : out std_logic;
        ram_address   : out std_logic_vector(7 downto 0);
        ram_price     : out std_logic_vector(11 downto 0)
    );
end entity ChangePrices;


architecture rtl of ChangePrices is

    -- Steps followed by the controller.
    type state_t is (
        purchase_mode,
        choose_item,
        edit_price,
        send_write
    );

    signal state : state_t := purchase_mode;

    -- Remember the item being edited.
    signal selected_address : std_logic_vector(7 downto 0)
                            := x"11";

    -- Previous switch levels for detecting new flips.
    signal previous_sw : std_logic_vector(3 downto 0)
                       := (others => '0');

    -- 1000 means the entered price exceeded $9.99.
    signal draft : integer range 0 to 1000 := 0;

    signal error_flag : std_logic := '0';

    -- Index 0 is KEY0. Index 1 is KEY2.
    signal button_pressed : std_logic_vector(1 downto 0);
    signal button_pulse   : std_logic_vector(1 downto 0);

    signal maintenance : std_logic;
    signal reset_now   : std_logic;
    signal save_now    : std_logic;


    -- Convert cents into three decimal digit nibbles.
    function to_bcd(value : natural)
        return std_logic_vector is

        variable result : std_logic_vector(11 downto 0);

    begin
        -- Hundreds digit.
        result(11 downto 8) :=
            std_logic_vector(to_unsigned(value / 100, 4));

        -- Tens digit.
        result(7 downto 4) :=
            std_logic_vector(
                to_unsigned((value / 10) mod 10, 4));

        -- Ones digit.
        result(3 downto 0) :=
            std_logic_vector(to_unsigned(value mod 10, 4));

        return result;
    end function;

begin

    -- Convert active-low buttons to active-high presses.
    button_pressed(0) <= not key0;
    button_pressed(1) <= not key2;


    -- Debounce both buttons.
    -- Each press produces one clock-cycle pulse.
    gen_button_db : for i in 0 to 1 generate

        db_button : entity work.debounce
            generic map (
                cnt_max => 500_000
            )
            port map (
                clk      => clk,
                rst      => reset,
                sw_in    => button_pressed(i),
                sw_out   => open,
                sw_pulse => button_pulse(i)
            );

    end generate;


    -- Maintenance is active outside purchase_mode.
    maintenance <= '0' when state = purchase_mode else '1';

    setup_active <= maintenance;

    -- KEY0 resets outside maintenance. For now keep ask.
    reset_now <= reset or
                 (button_pulse(0) and not maintenance);

    -- KEY0 saves inside maintenance.
    save_now <= button_pulse(0) and maintenance;

    -- Provide both reset polarities.
    system_reset <= reset_now;
    ram_reset_n  <= not reset_now;


    -- Indicate that an item has been selected for editing.
    item_chosen <= '1' when
        state = edit_price or state = send_write
        else '0';

    price_error <= error_flag;

    -- Keep the selected address available.
    ram_address <= selected_address;

    -- Output the draft for display.
    -- An over-limit entry outputs 0 with price_error set.
    draft_cents <= draft when draft <= 999 else 0;

    -- Encode the draft for RAM storage.
    ram_price <= to_bcd(draft) when draft <= 999
                 else x"000";


    -- Request one write.
    -- Reset or a KEY2 press cancels a pending request.
    write_request <= '1' when
        state = send_write and
        reset_now = '0' and
        button_pulse(1) = '0'
        else '0';


    -- Clear old keypad selections during reset,
    -- mode changes, and a write request.
    clear_selector <= '1' when
        reset_now = '1' or
        state = send_write or
        (button_pulse(1) = '1' and
         (state /= purchase_mode or purchase_idle = '1'))
        else '0';


    process(clk)

        variable switched_on : std_logic_vector(3 downto 0);

        -- Enough space for 1000 plus all four switch values.
        variable total : integer range 0 to 1140;

        variable row_number : integer range 0 to 15;
        variable col_number : integer range 0 to 15;

    begin
        if rising_edge(clk) then

            -- Detect switches changing from 0 to 1.
            switched_on := sw_clean and not previous_sw;

            -- Remember the current levels for the next clock.
            previous_sw <= sw_clean;


            -- Reset has highest priority.
            if reset_now = '1' then

                state            <= purchase_mode;
                selected_address <= x"11";
                draft            <= 0;
                error_flag       <= '0';


            -- KEY2 enters or exits maintenance.
            elsif button_pulse(1) = '1' then

                if state /= purchase_mode then

                    -- Exit and discard the unsaved price.
                    state <= purchase_mode;

                elsif purchase_idle = '1' then

                    -- Enter only when no purchase is active.
                    state <= choose_item;

                end if;

                draft      <= 0;
                error_flag <= '0';


            else
                case state is

                    when purchase_mode =>

                        -- Wait for KEY2.
                        null;


                    when choose_item =>

                        if item_valid = '1' then

                            -- Read the row digit.
                            row_number :=
                                to_integer(unsigned(
                                    item_address(7 downto 4)));

                            -- Read the column digit.
                            col_number :=
                                to_integer(unsigned(
                                    item_address(3 downto 0)));

                            -- Both digits must be 1 through 4.
                            if row_number >= 1 and
                               row_number <= 4 and
                               col_number >= 1 and
                               col_number <= 4 then

                                selected_address <= item_address;
                                draft            <= 0;
                                error_flag       <= '0';
                                state            <= edit_price;

                            else

                                -- Invalid item: keep waiting.
                                error_flag <= '1';

                            end if;

                        elsif save_now = '1' then

                            -- Cannot save without selecting an item.
                            error_flag <= '1';

                        end if;


                    when edit_price =>

                        total := draft;

                        -- SW0 adds a nickel.
                        if switched_on(0) = '1' then
                            total := total + 5;
                        end if;

                        -- SW1 adds a dime.
                        if switched_on(1) = '1' then
                            total := total + 10;
                        end if;

                        -- SW2 adds a quarter.
                        if switched_on(2) = '1' then
                            total := total + 25;
                        end if;

                        -- SW3 adds a dollar.
                        if switched_on(3) = '1' then
                            total := total + 100;
                        end if;


                        -- Mark an over-limit entry as invalid.
                        if total > 999 then
                            total := 1000;
                        end if;

                        draft <= total;


                        -- KEY0 means Save in this state.
                        if save_now = '1' then

                            if total >= 5 and total <= 999 then

                                -- Valid price: request storage.
                                error_flag <= '0';
                                state      <= send_write;

                            else

                                -- Invalid price: clear the draft
                                -- and retry the same item.
                                error_flag <= '1';
                                draft      <= 0;

                            end if;

                        elsif total = 1000 then

                            error_flag <= '1';

                        elsif switched_on /= "0000" then

                            -- Clear a previous error after a
                            -- new in-range entry.
                            error_flag <= '0';

                        end if;


                    when send_write =>

                        -- The RAM interface must capture the
                        -- address and price on this clock edge.
                        -- This is a request, not confirmation
                        -- that the RAM successfully saved it.
                        state <= choose_item;
                        draft <= 0;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;