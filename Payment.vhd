library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

ENTITY Payment is
	port(clk : in std_logic;
		  reset : in std_logic;
		  sw : in std_logic_vector(3 downto 0);
		  paid : out integer range 0 to 999);
END Payment;

ARCHITECTURE pay OF Payment IS
	signal sw_prev : std_logic_vector(3 downto 0) :="1111";
	signal total : integer range 0 to 999 := 0;
BEGIN
	process(clk)
		variable add : integer range 0 to 999;
		variable sum : integer range 0 to 2047;
	BEGIN 
		if rising_edge(clk) then
			sw_prev <= sw;
			if reset = '1' then
				total <=0;
			else 
				add := 0;
				if sw(0) = '1' and sw_prev(0) = '0' then add := add + 5; end if;
				if sw(1) = '1' and sw_prev(1) = '0' then add := add + 10; end if;
				if sw(2) = '1' and sw_prev(2) = '0' then add := add + 25; end if;
				if sw(3) = '1' and sw_prev(3) = '0' then add := add + 100; end if;
				--EL 10/31/26
				sum := total + add;
				if sum > 999 then
					total <= 999;
				else 
					total <= sum;
				end if;
			end if;
		end if;
	end process;
	
	paid <= total;
END pay;