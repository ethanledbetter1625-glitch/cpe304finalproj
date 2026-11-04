--All testing done. 
--Debounce testing done. --EL 11/04/2026
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
	constant price : integer range 0 to 999 := 135; --static price, $1.35
	signal paid    : integer range 0 to 999;
	signal num : integer range 0 to 999 := 0;
	signal dig0, dig1, dig2 : std_logic_vector(3 downto 0);
	signal clk_100hz : std_logic;
	--EL 10/31/26
	signal sw_clean : std_logic_vector(3 downto 0); --debounced switch levels
	signal sw_pulse : std_logic_vector(3 downto 0); --1 clk pulse on each switch up-flip
	--EL 11/04/2026
BEGIN
	dig0 <= std_logic_vector(to_unsigned(num mod 10, 4));
	dig1 <= std_logic_vector(to_unsigned((num / 10) mod 10, 4));
	dig2 <= std_logic_vector(to_unsigned(num / 100, 4));
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
	--EL 11/04/2026

	disp : entity work.Part2
		port map (xin => x"000" & dig2 & dig1 & dig0,
				  sevenseg1 => display0, sevenseg2 => display1, sevenseg3 => display2);
	calc : entity work.ChangeCalc
		port map (price => price, paid => paid, change => num, short => open,
				  quarters => open, dimes => open, nickels => open, pennies => open);
	pay : entity work.Payment
		port map (clk => clk_100hz, reset => '0', sw => sw_clean, paid => paid);
	--testing payment method
	--EL 11/04/2026 uses debounced switches
	
	div_btn : clk_div
		generic map (cnt_max => 250000) --100 hz from 50 mhz
		port map (clock_in => clk_in, clock_out => clk_100hz);
	--EL 11/04/2026
	
	--TODO: ram
END FPArch;

--if you need to make an instance of the clock with a value that is not 62500 (this is just an init value)
--do this:
--div_example : clk_div
--		generic map (cnt_max => 62500)
--		port map (clock_in => clk_in, clock_out => clk_example);
--EL 10/30/26