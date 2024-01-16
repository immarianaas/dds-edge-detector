-- -----------------------------------------------------------------------------
--
--  Title      :  Edge-Detection design project - Pixel Inverter
--             :
--  Developers :  Mariana - s233360@student.dtu.dk
--             :
--  Purpose    :  This design contains an entity for the pixel inverter that
--             :  was built for task 0 in the Edge Detection design project. 
--             
-- -----------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.types.ALL;
ENTITY acc IS
	PORT (
		clk : IN bit_t; -- The clock.
		reset : IN bit_t; -- The reset signal. Active high.
		addr : OUT halfword_t; -- Address bus for data.
		dataR : IN word_t; -- The data bus.
		dataW : OUT word_t; -- The data bus.
		en : OUT bit_t; -- Request signal for data.
		we : OUT bit_t; -- Read/Write signal for data.
		start : IN bit_t;
		finish : OUT bit_t
	);
END acc;
ARCHITECTURE rtl OF acc IS
	TYPE state_type IS (S0, S1, S2, S3);
	SIGNAL state, next_state : state_type;
	SIGNAL addrR, next_addrR : halfword_t;
	SIGNAL addrW, next_addrW : halfword_t;
BEGIN
	cl : PROCESS (clk, reset, state, addrR, addrW, start, dataR)
	BEGIN
		next_state <= state;
		next_addrR <= addrR;
		next_addrW <= addrW;
		dataW <= (OTHERS => '0');
		addr <= (OTHERS => '0');
		finish <= '0';
		En <= '0';
		We <= '0';
		CASE (state) IS
			WHEN S0 =>
				-- En <= '0';
				next_addrR <= halfword_zero;
				next_addrW <= std_logic_vector(to_unsigned(25344, 16));
				IF start = '1' THEN
					next_state <= S1;
				END IF;
			WHEN S1 =>
				En <= '1';
				next_state <= S2;
				addr <= addrR;
			WHEN S2 =>
				next_addrR <= std_logic_vector(to_unsigned(to_integer(unsigned(addrR)) + 1, 16));
				next_addrW <= std_logic_vector(unsigned(addrW) + 1);
				En <= '1';
				We <= '1';
				addr <= addrW;
				dataW <= NOT dataR(31 DOWNTO 24)
					 & NOT dataR(23 DOWNTO 16)
					 & NOT dataR(15 DOWNTO 8)
					 & NOT dataR(7 DOWNTO 0);

					IF addrR = std_logic_vector(to_unsigned(25344, 16)) THEN
						next_state <= S3;
					ELSE
						next_state <= S1;
					END IF;
			WHEN S3 =>
				finish <= '1';
				next_state <= S0;

			WHEN OTHERS =>
				next_state <= S0;
		END CASE;

	END PROCESS cl;

	seq : PROCESS (clk, reset)
	BEGIN
		IF reset = '1' THEN
			state <= S0;
			addrR <= (OTHERS => '0');
			addrW <= byte_zero & byte_one;
		ELSIF rising_edge(clk) THEN
			state <= next_state;
			addrR <= next_addrR;
			addrW <= next_addrW;
		END IF;
	END PROCESS seq;
END rtl;
