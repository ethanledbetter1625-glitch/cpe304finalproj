
-- Nicholas Winowitch 11/23/2026
-- This timer tells main how long to keep an error message on the display.
-- At 50 MHz, 100,000,000 clock periods = two seconds.
library ieee;
use ieee.std_logic_1164.all;


entity ErrorTimer is

    generic (
        TICKS : positive := 100_000_000
    );

    port (
        clk    : in std_logic; -- Connect to the 50 MHz board clock.
        reset  : in std_logic; -- Active-high reset.
        start  : in std_logic; -- A rising edge starts an idle timer.
        cancel : in std_logic; -- Stop early without producing done.

        busy : out std_logic; -- High while the error should remain visible.
        done : out std_logic  -- One-clock pulse when the full time has passed.
    );

end entity;


architecture rtl of ErrorTimer is

    -- Counting from zero through TICKS - 1 gives TICKS complete clock periods.
    signal count : natural range 0 to TICKS - 1 := 0;

    -- Remember whether a countdown is currently running.
    signal active : std_logic := '0';

    -- Remember the previous Start level so a held request only starts once.
    signal start_previous : std_logic := '0';

    -- Internal version of the done output.
    signal finished : std_logic := '0';

begin

    -- Send the internal timer status back to the main file.
    busy <= active;
    done <= finished;


    process(clk)
    begin
        if rising_edge(clk) then

            start_previous <= start;

            -- Clear done each clock.
            -- Only normal timer completion sets it high again.
            finished <= '0';


            -- Reset or Cancel stops the timer on this clock edge.
            -- Do not send done because the full display time was not completed.
            if reset = '1' or cancel = '1' then

                count  <= 0;
                active <= '0';


            -- While idle, accept a new low-to-high change on Start.
            -- Keeping Start high after completion will not start another timer.
            elsif active = '0' then

                if start = '1' and start_previous = '0' then
                    count  <= 0;
                    active <= '1';
                end if;


            -- The requested number of periods has passed.
            -- Lower busy and pulse done so the controller can leave its error state.
            elsif count = TICKS - 1 then

                count    <= 0;
                active   <= '0';
                finished <= '1';


            else

                -- Keep counting. New Start requests are ignored while active,
                -- so repeated presses cannot extend the error message.
                count <= count + 1;

            end if;
        end if;
    end process;

end architecture;