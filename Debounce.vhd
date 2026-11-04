library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

ENTITY debounce IS
	generic(cnt_max : integer := 500000);

    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        sw_in     : in  std_logic;
        sw_out    : out std_logic;
        sw_pulse  : out std_logic
    );
END debounce;

ARCHITECTURE debounceArch OF debounce IS
    signal sync_0, sync_1 : std_logic := '0';
    signal stable         : std_logic := '0';
    signal stable_d       : std_logic := '0';
    signal cnt            : integer range 0 to CNT_MAX := 0;
BEGIN
	process(clk, rst)
	BEGIN
		if rst = '1' then
			sync_0 <= '0';
			sync_1 <= '0';
			stable <= '0';
			stable_d <= '0';
			cnt <= 0;
		elsif rising_edge(clk) then
			sync_0 <= sw_in;
			sync_1 <= sync_0;
			stable_d <= stable;
			
			if sync_1 = stable then
				cnt <= 0;
			elsif cnt = cnt_max then
				stable <= sync_1;
				cnt <= 0;
			else
				cnt <= cnt + 1;
			END IF;
		END IF;
	END process;
	
	sw_out <= stable;
	sw_pulse <= stable and not stable_d;
END debounceArch;
