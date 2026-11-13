library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ChangeDispenser is
	port(
		clk: in std_logic;
		reset: in std_logic;
		start: in std_logic;
		
		change_cents: in unsigned(9 downto 0);
		
		LED: out std_logic_vector(3 downto 0);
		busy: out std_logic;
		done: out std_logic
	);
end entity ChangeDispenser;

architecture change of ChangeDispenser is

	constant CLK_FREQ: integer := 50000000;
	
	type state_type is(
		IDLE, SELECT_COIN, LED_ON, LED_OFF, DONE_STATE
		);
		
	signal state : state_type := IDLE;
	
	signal remaining: integer range 0 to 999 := 0;
	signal coin_value: integer range 0 to 100 := 0;
	
	signal timer: integer range 0 to (CLK_FREQ/2)-1 := 0;
	
	signal led_reg : std_logic_vector(3 downto 0) := "0000";
	
begin

	LED<= led_reg;
	
	process(clk)
	begin
		if rising_edge(clk)then
		
			if reset = '1' then
			
				state<= IDLE;
				remaining<= 0;
				coin_value<= 0;
				timer<= 0;
				led_reg<= "0000";
				busy<= '0';
				done<= '0';
				
			else
			
				done<= '0';
				
			case state is
			
				--Waiting for the value of the change from the machine
				when IDLE=>
				
					led_reg<= "0000";
					busy<= '0';
					
					if start= '1' then
						
						remaining <= to_integer(change_cents);
						busy<= '1';
						state<= SELECT_COIN;
					end if;
					
				when SELECT_COIN=>
				
					led_reg<= "0000";
					
					if remaining >= 100 then 	--If there is greater than 100 cents, $1.00 left of change then send out
						coin_value<= 100;			--a dollars worth of change
						led_reg<= "1000";			--Flash the dollar LED (LED(3))
						timer<= 0;
						state<= LED_ON;
					
					elsif remaining >= 25 then	--If there is greater than 25 cents and less than 100 cents, then send out
						coin_value<= 25;			--a quarters worth of change
						led_reg<= "0100";			--Flash the quarter LED LED(2)
						timer<= 0;
						state<= LED_ON;
					
					elsif remaining >= 10 then	--If there is greater than 10 cents and less than 25 cents, then send out
						coin_value<= 10;			--a dimes worth of change
						led_reg<= "0010";			--Flash the dime LED LED(1)
						timer<= 0;
						state<= LED_ON;
				
					elsif remaining >= 5 then	--If there is greater than 5 cents and less than 10 cents, then send out
						coin_value<= 5;			--a nickels worth of change
						led_reg<= "0001";			--Flash the nickel LED LED(0)
						timer<= 0;
						state<= LED_ON;
				
					else
						state<= DONE_STATE;		--If there is no change left, then we are done dispensing
					
					end if;
					
				--LED On for 0.5 seconds
				when LED_ON =>
				
					if timer = (CLK_FREQ/2)-1 then
					
						timer<= 0;
						led_reg<= "0000";
						state<= LED_OFF;
					else
					
						timer<= timer+1;
					
					end if;
					
				--LED off for 0.5 seconds
				when LED_OFF=>
				
					led_reg<= "0000";
						
						if timer = (CLK_FREQ/2)-1 then
						
							timer<= 0;
							remaining<= remaining - coin_value;
							state<= SELECT_COIN;
						
						else
						
							timer<= timer + 1;
						
						end if;
						
				--Finished Dispensing Change == All LEDs off and call it done
				when DONE_STATE=>
				
					led_reg<= "0000";
					busy<= '0';
					done<= '1';
					
					state<= IDLE;
					
			end case;
			end if;
	
		end if;
	end process;
end change;
				
				
				
				
				
				
				
				
	
	
	
	