library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

ENTITY Payment is
	generic(LED_TICKS : integer := 50); --how many clk ticks a kicked back coin led stays on, 50 @ 100hz = 0.5 sec --EL 11/18/2026
	port(clk : in std_logic;
		  reset : in std_logic;
		  sw : in std_logic_vector(3 downto 0);
		  paid : buffer integer range 0 to 999;
		  item_price : in integer range 0 to 999;
		  LED: out std_logic_vector(3 downto 0)
		  );
END Payment;

ARCHITECTURE pay OF Payment IS
	signal sw_prev : std_logic_vector(3 downto 0) :="1111";
	signal total : integer range 0 to 999 := 0;
	signal led_reg : std_logic_vector(3 downto 0) := "0000";
	signal led_tmr : integer range 0 to LED_TICKS := 0; --counts down while a kicked back led is on --EL 11/18/2026
BEGIN
	LED<= led_reg;

	--everything is inside rising_edge now, the old price check was outside it --EL 11/18/2026
	process(clk)
		variable add : integer range 0 to 999;
		variable sum : integer range 0 to 2047;
		variable kick : std_logic_vector(3 downto 0); --coins flipped in after price is already paid --EL 11/18/2026
	BEGIN
		if rising_edge(clk) then
			sw_prev <= sw; --always track, even while coins are being kicked back --EL 11/18/2026
			if reset = '1' then
				total <=0;
				led_reg <= "0000"; --EL 11/18/2026
				led_tmr <= 0;      --EL 11/18/2026
			else
				add := 0;
				kick := "0000";
				--price 0 = nothing loaded from ram yet, so dont kick everything back --EL 11/18/2026
				if item_price > 0 and total >= item_price then
					--already paid enough, coin comes right back out, light its led --EL 11/18/2026
					kick := sw and not sw_prev;
				else
					if sw(0) = '1' and sw_prev(0) = '0' then add := add + 5; end if;
					if sw(1) = '1' and sw_prev(1) = '0' then add := add + 10; end if;
					if sw(2) = '1' and sw_prev(2) = '0' then add := add + 25; end if;
					if sw(3) = '1' and sw_prev(3) = '0' then add := add + 100; end if;
					--EL 10/31/26
				end if;
				sum := total + add;
				if sum > 999 then
					total <= 999;
				else
					total <= sum;
				end if;

				--led on for LED_TICKS then off --EL 11/18/2026
				if kick(0) = '1' or kick(1) = '1' or kick(2) = '1' or kick(3) = '1' then
					led_reg <= kick; --led0 nickel, led1 dime, led2 quarter, led3 dollar
					led_tmr <= LED_TICKS;
				elsif led_tmr > 0 then
					led_tmr <= led_tmr - 1;
				else
					led_reg <= "0000";
				end if;
			end if;
		end if;
	end process;

	paid <= total;
END pay;
