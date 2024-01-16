-- -----------------------------------------------------------------------------
--
--  Title      :  Edge-Detection design project
--             :
--  Developers :  Mariana - s233360@student.dtu.dk
--             :
--  Purpose    :  This design contains an entity for the accelerator that was built
--             :  in the Edge Detection design project. 
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
	TYPE state_type IS (S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13);
	TYPE line_t IS ARRAY (3 DOWNTO 0) OF byte_t;
	SIGNAL state, next_state : state_type;
	SIGNAL addrR, next_addrR : halfword_t;
	SIGNAL addrW, next_addrW : halfword_t;
	SIGNAL dataRegA, next_dataRegA : line_t;
	SIGNAL dataRegB, next_dataRegB : line_t;
	SIGNAL dataRegC, next_dataRegC : line_t;
	SIGNAL writeData, next_writeData : line_t;
BEGIN
	cl : PROCESS (clk, reset, state, addrR, addrW, dataRegA, dataRegB, dataRegC, writeData, start, dataR)
		CONSTANT num_addr_img : INTEGER := 25344;
		CONSTANT line_addr_jump : INTEGER := 352/4;

		FUNCTION IsAddrRNStartLine RETURN BOOLEAN IS
		BEGIN
			RETURN (to_integer(unsigned(addrR)) REM line_addr_jump) = 0;
		END FUNCTION;

		FUNCTION ComputeSobel (
			flag : BIT) RETURN byte_t IS
			VARIABLE gx, gy : INTEGER;
			VARIABLE total : std_logic_vector(10 DOWNTO 0);

			BEGIN
				IF flag = '0' THEN
                    gx := -1 * to_integer(unsigned(dataRegA(0))) -2 * to_integer(unsigned(dataRegB(0))) -1 * to_integer(unsigned(dataRegC(0))) 
                          +1 * to_integer(unsigned(dataRegA(2))) +2 * to_integer(unsigned(dataRegB(2))) +1 * to_integer(unsigned(dataRegC(2)));
                    gy := +1 * to_integer(unsigned(dataRegA(0))) +2 * to_integer(unsigned(dataRegA(1))) +1 * to_integer(unsigned(dataRegA(2))) 
                          -1 * to_integer(unsigned(dataRegC(0))) -2 * to_integer(unsigned(dataRegC(1))) -1 * to_integer(unsigned(dataRegC(2))); 
				ELSE
                    gx := -1 * to_integer(unsigned(dataRegA(1))) -2 * to_integer(unsigned(dataRegB(1))) -1 * to_integer(unsigned(dataRegC(1))) 
                          +1 * to_integer(unsigned(dataRegA(3))) +2 * to_integer(unsigned(dataRegB(3))) +1 * to_integer(unsigned(dataRegC(3)));
                    gy := +1 * to_integer(unsigned(dataRegA(1))) +2 * to_integer(unsigned(dataRegA(2))) +1 * to_integer(unsigned(dataRegA(3))) 
                          -1 * to_integer(unsigned(dataRegC(1))) -2 * to_integer(unsigned(dataRegC(2))) -1 * to_integer(unsigned(dataRegC(3)));
                END IF;
				total := std_logic_vector(to_unsigned(ABS(gx) + ABS(gy), 11)); RETURN total(10 DOWNTO 3);
			END FUNCTION;
			BEGIN
				next_state <= state;
				next_addrR <= addrR;
				next_addrW <= addrW;
				next_dataRegA <= dataRegA;
				next_dataRegB <= dataRegB;
				next_dataRegC <= dataRegC;
				next_writeData <= writeData;
				dataW <= (OTHERS => '0');
				addr <= (OTHERS => '0');
				finish <= '0';
				En <= '0';
				We <= '0';
				CASE (state) IS
					WHEN S0 =>
						next_addrR <= halfword_zero;
						next_addrW <= std_logic_vector(to_unsigned(num_addr_img + line_addr_jump, 16));

						IF start = '1' THEN
							next_state <= S1;
						END IF;
						
					WHEN S1 =>
						En <= '1';
						addr <= addrR; -- next state: read A
						next_addrR <= std_logic_vector(to_unsigned(to_integer(unsigned(addrR)) + line_addr_jump, 16)); -- next address: read B
						next_state <= S2;
						
					WHEN S2 =>
						En <= '1';
						next_dataRegA(3) <= dataR(7 DOWNTO 0);
						next_dataRegA(2) <= dataR(15 DOWNTO 8);
						next_dataRegA(1) <= dataR(23 DOWNTO 16);
						next_dataRegA(0) <= dataR(31 DOWNTO 24);
						
						addr <= addrR; -- next state: read B
						next_addrR <= std_logic_vector(to_unsigned(to_integer(unsigned(addrR)) + line_addr_jump, 16)); -- next address: read C
						next_state <= S3;
						
					WHEN S3 =>
						En <= '1';
						next_dataRegB(3) <= dataR(7 DOWNTO 0);
						next_dataRegB(2) <= dataR(15 DOWNTO 8);
						next_dataRegB(1) <= dataR(23 DOWNTO 16);
						next_dataRegB(0) <= dataR(31 DOWNTO 24);

						addr <= addrR; -- next state: read C
						next_addrR <= std_logic_vector(to_unsigned(to_integer(unsigned(addrR)) - (2 * line_addr_jump) + 1, 16)); -- next address: read following A
						next_state <= S4;
						
					WHEN S4 => -- reads C
						next_dataRegC(3) <= dataR(7 DOWNTO 0);
						next_dataRegC(2) <= dataR(15 DOWNTO 8);
						next_dataRegC(1) <= dataR(23 DOWNTO 16);
						next_dataRegC(0) <= dataR(31 DOWNTO 24);

						next_state <= S5;
						
					WHEN S5 =>
						next_writeData(1) <= ComputeSobel('0');
						next_writeData(2) <= ComputeSobel('1');
						IF IsAddrRNStartLine THEN
							-- if next addrR is a new line, then we want to finish
							-- this line without reading anymore for now;
							-- the address will continue to be the first pixels in the new line
							next_state <= S12;
						ELSE
							-- this is the "normal" situation
							-- we want to read the new pixels to compute the last two output pixels
							En <= '1';
							addr <= addrR; -- next state: read A
							next_addrR <= std_logic_vector(to_unsigned(to_integer(unsigned(addrR)) + line_addr_jump, 16)); -- next address: read B
							next_state <= S6;
						END IF;

					WHEN S6 =>
						En <= '1';
						-- read A and store half
						next_dataRegA(0) <= dataRegA(2);
						next_dataRegA(1) <= dataRegA(3);
						next_dataRegA(2) <= dataR(31 DOWNTO 24);
						next_dataRegA(3) <= dataR(23 DOWNTO 16);
						addr <= addrR; -- next state: read B
						next_addrR <= std_logic_vector(to_unsigned(to_integer(unsigned(addrR)) + line_addr_jump, 16)); -- next address: read C
						next_state <= S7;
						
					WHEN S7 =>
						En <= '1';
						-- read B and store half
						next_dataRegB(0) <= dataRegB(2);
						next_dataRegB(1) <= dataRegB(3);
						next_dataRegB(2) <= dataR(31 DOWNTO 24);
						next_dataRegB(3) <= dataR(23 DOWNTO 16);
						addr <= addrR; -- next state: read C
						-- next address: read the same A as before;
						-- we will want to re-read A, B and C once more!
						next_addrR <= std_logic_vector(to_unsigned(to_integer(unsigned(addrR)) - 2 * line_addr_jump, 16));
						next_state <= S8;
						
					WHEN S8 =>
						-- read C and store half
						next_dataRegC(0) <= dataRegC(2);
						next_dataRegC(1) <= dataRegC(3);
						next_dataRegC(2) <= dataR(31 DOWNTO 24);
						next_dataRegC(3) <= dataR(23 DOWNTO 16);

						next_state <= S9;
						
					WHEN S9 =>
						-- write buffer will now be complete
						next_writeData(3) <= ComputeSobel('0');
						next_state <= S10;
						
					WHEN S10 =>
						-- storing output
						En <= '1';
						We <= '1';
						dataW <= writeData(0) & writeData(1) & writeData(2) & writeData(3);
						addr <= addrW;
						-- increment write address by 1
						next_addrW <= std_logic_vector(to_unsigned(to_integer(unsigned(addrW)) + 1, 16));

						IF addrW = std_logic_vector(to_unsigned(num_addr_img * 2 - line_addr_jump - 1, 16)) THEN
							-- all pixels are finished: go to final state
							next_state <= S11;

						ELSIF IsAddrRNStartLine THEN
							-- start reading a new line
							-- borders are ignored -- output pixel is 0
							next_writeData(0) <= byte_zero;
							next_state <= S1;
						ELSE
							-- "normal" situation - continue reading other pixels in the same line
							next_state <= S13;
						END IF;
						
					WHEN S12 =>
						-- finish this line
						next_writeData(2) <= ComputeSobel('1');
						next_writeData(3) <= byte_zero; -- borders are set to 0
						-- output buffer is complete: save it on S10
						next_state <= S10;
						
					WHEN S13 =>
						-- compute first pixel of output buffer
						next_writeData(0) <= ComputeSobel('1');
						next_state <= S1;
						
					WHEN S11 =>
						finish <= '1';
						next_state <= S0;
						
					WHEN OTHERS =>
						next_state <= S0;
						
				END CASE;

			END PROCESS cl;

			seq : PROCESS (clk, reset)
			BEGIN
				IF reset = '1' THEN
					dataRegA(0) <= (OTHERS => '0');
					dataRegA(1) <= (OTHERS => '0');
					dataRegA(2) <= (OTHERS => '0');
					dataRegA(3) <= (OTHERS => '0');
					
					dataRegB(0) <= (OTHERS => '0');
					dataRegB(1) <= (OTHERS => '0');
					dataRegB(2) <= (OTHERS => '0');
					dataRegB(3) <= (OTHERS => '0');
					
					dataRegC(0) <= (OTHERS => '0');
					dataRegC(1) <= (OTHERS => '0');
					dataRegC(2) <= (OTHERS => '0');
					dataRegC(3) <= (OTHERS => '0');
					
					writeData(0) <= (OTHERS => '0');
					writeData(1) <= (OTHERS => '0');
					writeData(2) <= (OTHERS => '0');
					writeData(3) <= (OTHERS => '0');
					
					state <= S0;
					addrR <= (OTHERS => '0');
					addrW <= byte_zero & byte_one;
				ELSIF rising_edge(clk) THEN
					dataRegA <= next_dataRegA;
					dataRegB <= next_dataRegB;
					dataRegC <= next_dataRegC;
					writeData <= next_writeData;
					state <= next_state;
					addrR <= next_addrR;
					addrW <= next_addrW;
				END IF;
			END PROCESS seq;
END rtl;
