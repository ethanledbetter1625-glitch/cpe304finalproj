library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

ENTITY ChangeCalc IS 
			port(price : in integer range 0 to 999;
			     paid  : in integer range 0 to 999;
				  change : inout integer range 0 to 999;
				  short : out std_logic;
				  quarters : out integer range 0 to 39;
				  dimes : out integer range 0 to 2;
				  nickels : out integer range 0 to 1;
				  pennies : out integer range 0 to 4);
END ChangeCalc;

ARCHITECTURE calc OF ChangeCalc is 
	signal c : integer range 0 to 999;
BEGIN
	c <= paid - price when paid >= price else 0;
	change <= c;
	short <= '1' when paid < price else '0';
	
	quarters <= c / 25;
	dimes <= (c mod 25) / 10;
	nickels <= ((c mod 25) mod 10) / 5;
	pennies <= c mod 5;
END calc;