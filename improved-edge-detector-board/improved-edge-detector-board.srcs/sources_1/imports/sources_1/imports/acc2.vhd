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
		finish : OUT bit_t;

		ram_we0 : OUT bit_t;
		ram_we1 : OUT bit_t;
		ram_we2 : OUT bit_t;
		ram_ar : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		ram_aw : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		ram_data_in : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		ram_data_out0 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
		ram_data_out1 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
		ram_data_out2 : IN STD_LOGIC_VECTOR(47 DOWNTO 0)
	);
END acc;

ARCHITECTURE rtl OF acc IS
	TYPE state_type IS (S0, S1, S2, S3, S4, S5, S6, S7);

	TYPE line3_t IS ARRAY (2 DOWNTO 0) OF byte_t;
	SUBTYPE rem_addr_type IS STD_LOGIC_VECTOR(18 DOWNTO 0);
	SUBTYPE rem_addr_type_lin IS STD_LOGIC_VECTOR(1 DOWNTO 0);
	SUBTYPE rem_addr_type_col IS STD_LOGIC_VECTOR(6 DOWNTO 0);

	SIGNAL state, next_state : state_type;

	SIGNAL addrR, next_addrR : halfword_t;
	SIGNAL addrW, next_addrW : halfword_t;

BEGIN

	cl : PROCESS (clk, reset, state, addrR, addrW, start, dataR, ram_data_out0, ram_data_out1, ram_data_out2)

		CONSTANT num_addr_img : INTEGER := 25344;
		CONSTANT line_addr_jump : INTEGER := 352/4;

		FUNCTION IsNextAddrRStartLine RETURN BOOLEAN IS
		BEGIN
			RETURN ((to_integer(unsigned(addrR)) + 1) REM line_addr_jump) = 0;
		END FUNCTION;

		FUNCTION IsNextAddrWStartLine RETURN BOOLEAN IS
		BEGIN
			RETURN ((TO_INTEGER(unsigned(addrW)) + 1)REM line_addr_jump) = 0;
		END FUNCTION;

		FUNCTION IsNextAddrWLastLine RETURN BOOLEAN IS
		BEGIN
			RETURN to_integer(unsigned(addrW)) + 1 = (num_addr_img * 2) - line_addr_jump;
		END FUNCTION;
		FUNCTION GetPixels(offset : STD_LOGIC_VECTOR(1 DOWNTO 0); vector : STD_LOGIC_VECTOR(47 DOWNTO 0)) RETURN line3_t IS
			VARIABLE A : line3_t;
		BEGIN
			CASE (offset) IS
				WHEN "00" =>
					A(0) := vector(47 DOWNTO 40);
					A(1) := vector(39 DOWNTO 32);
					A(2) := vector(31 DOWNTO 24);

				WHEN "01" =>
					A(0) := vector(39 DOWNTO 32);
					A(1) := vector(31 DOWNTO 24);
					A(2) := vector(23 DOWNTO 16);

				WHEN "10" =>
					A(0) := vector(31 DOWNTO 24);
					A(1) := vector(23 DOWNTO 16);
					A(2) := vector(15 DOWNTO 8);

				WHEN "11" =>
					A(0) := vector(23 DOWNTO 16);
					A(1) := vector(15 DOWNTO 8);
					A(2) := vector(7 DOWNTO 0);

				WHEN OTHERS =>
					A(0) := byte_zero;
					A(1) := byte_zero;
					A(2) := byte_zero;

			END CASE;

			RETURN A;

		END FUNCTION;

		IMPURE FUNCTION ComputeSobel (
			offset : STD_LOGIC_VECTOR(1 DOWNTO 0)) RETURN byte_t IS
			VARIABLE gx, gy : INTEGER;
			VARIABLE total : STD_LOGIC_VECTOR(10 DOWNTO 0);

			VARIABLE A : line3_t;
			VARIABLE B : line3_t;
			VARIABLE C : line3_t;

			VARIABLE address : INTEGER;
			VARIABLE out_line : INTEGER;

		BEGIN
			address := (to_integer(unsigned(addrW)) - num_addr_img);
			ram_ar <= STD_LOGIC_VECTOR(to_unsigned(address REM line_addr_jump, 7));

			out_line := address / line_addr_jump;

			IF (out_line REM 3) = 0 THEN
				A := GetPixels(offset, ram_data_out0);
				B := GetPixels(offset, ram_data_out1);
				C := GetPixels(offset, ram_data_out2);
			ELSIF (out_line REM 3) = 1 THEN
				A := GetPixels(offset, ram_data_out1);
				B := GetPixels(offset, ram_data_out2);
				C := GetPixels(offset, ram_data_out0);
			ELSIF (out_line REM 3) = 2 THEN
				A := GetPixels(offset, ram_data_out2);
				B := GetPixels(offset, ram_data_out0);
				C := GetPixels(offset, ram_data_out1);
			END IF;

			gx := - 1 * to_integer(unsigned(A(0))) - 2 * to_integer(unsigned(B(0))) - 1 * to_integer(unsigned(C(0)))
			      + 1 * to_integer(unsigned(A(2))) + 2 * to_integer(unsigned(B(2))) + 1 * to_integer(unsigned(C(2)));

			gy := + 1 * to_integer(unsigned(A(0))) + 2 * to_integer(unsigned(A(1))) + 1 * to_integer(unsigned(A(2)))
				  - 1 * to_integer(unsigned(C(0))) - 2 * to_integer(unsigned(C(1))) - 1 * to_integer(unsigned(C(2)));

			total := STD_LOGIC_VECTOR(to_unsigned(ABS(gx) + ABS(gy), 11));
			RETURN total(10 DOWNTO 3);

		END FUNCTION;

		PROCEDURE EnableWriteCorrectRam IS
			VARIABLE readAddr : INTEGER;
			VARIABLE writeAddr : INTEGER;

		BEGIN
			readAddr := to_integer(unsigned(addrR));
			writeAddr := to_integer(unsigned(addrW));

			-- edge case (last)
			IF writeAddr >= ((num_addr_img * 2) - line_addr_jump) THEN
				ram_we1 <= '1';

				-- edge case (first)
			ELSIF readAddr < line_addr_jump THEN
				ram_we0 <= '1';
				ram_we1 <= '1';

			ELSIF (((readAddr / line_addr_jump) + 1) REM 3) = 0 THEN
				ram_we0 <= '1';
			ELSIF (((readAddr / line_addr_jump) + 1) REM 3) = 1 THEN
				ram_we1 <= '1';
			ELSE
				ram_we2 <= '1';
			END IF;
		END PROCEDURE;
		FUNCTION getRamWriteAddress(plus : INTEGER) RETURN rem_addr_type_col IS
			VARIABLE readAddr : INTEGER;
		BEGIN
			readAddr := to_integer(unsigned(addrR));
			RETURN STD_LOGIC_VECTOR(to_unsigned((readAddr REM line_addr_jump) + plus, 7));
		END FUNCTION;

	BEGIN

		next_state <= state;
		next_addrR <= addrR;
		next_addrW <= addrW;
		dataW <= (OTHERS => '0');
		addr <= (OTHERS => '0');
		finish <= '0';

		En <= '0';
		We <= '0';
		-- RAM --
		ram_we0 <= '0';
		ram_we1 <= '0';
		ram_we2 <= '0';

		ram_ar <= (OTHERS => '0');
		ram_aw <= (OTHERS => '0');
		ram_data_in <= (OTHERS => '0');

		CASE (state) IS
			WHEN S0 =>

				next_addrR <= halfword_zero;
				next_addrW <= STD_LOGIC_VECTOR(to_unsigned(num_addr_img, 16));

				IF start = '1' THEN
					next_state <= S1;

				END IF;

			WHEN S1 =>
				En <= '1';
				addr <= addrR;

				next_state <= S2;

			WHEN S2 => -- read first 4 pixels for first time
				En <= '1';

				ram_aw <= getRamWriteAddress(0);

				EnableWriteCorrectRam;
				ram_data_in <= byte_zero & byte_zero & byte_zero & dataR(31 DOWNTO 24);

				addr <= addrR; -- next state: read first again
				next_addrR <= STD_LOGIC_VECTOR(to_unsigned(to_integer(unsigned(addrR)) + 1, 16));
				next_state <= S3;
			WHEN S3 => -- read first 4 pixels once again, and also all the rest
				En <= '1';

				-- we will want to save it on ram_aw = addr + 1 (which is addrR here)
				ram_aw <= getRamWriteAddress(0);
				EnableWriteCorrectRam;
				ram_data_in <= dataR;

				addr <= addrR; -- next state: read next byte in same row
				IF IsNextAddrRStartLine THEN
					next_state <= S4; -- process last "read" and repeat
				ELSE
					next_addrR <= STD_LOGIC_VECTOR(to_unsigned(to_integer(unsigned(addrR)) + 1, 16));

				END IF;
			WHEN S4 => -- almost same as before
				En <= '1';

				-- we will want to save it on ram_aw = addr + 2.... (which is addrR+1 here)
				ram_aw <= getRamWriteAddress(1);
				EnableWriteCorrectRam;
				ram_data_in <= dataR;

				addr <= addrR; -- next state: read next byte in same row; don't update it
				next_state <= S5;
			WHEN S5 => -- read last pixel for the 2nd time
				En <= '1';

				-- we want to save it on addrR + 2
				ram_aw <= getRamWriteAddress(2);

				EnableWriteCorrectRam;

				ram_data_in <= dataR(7 DOWNTO 0) & byte_zero & byte_zero & byte_zero;

				addr <= addrR; -- next state: read last

				-- next will read the first of the next line
				next_addrR <= STD_LOGIC_VECTOR(to_unsigned(to_integer(unsigned(addrR)) + 1, 16));

				-- if this is at least the 2nd line:
				IF ((to_integer(unsigned(addrR))) / line_addr_jump) > 0 THEN
					next_state <= S6; -- compute next
				ELSE
					next_state <= S2; -- read more
				END IF;

			WHEN S6 =>
				En <= '1';
				We <= '1';
				addr <= addrW;

				dataW <= ComputeSobel("11") &
					ComputeSobel("10") &
					ComputeSobel("01") &
					ComputeSobel("00");

				next_addrW <= STD_LOGIC_VECTOR(to_unsigned(to_integer(unsigned(addrW)) + 1, 16));
				IF to_integer(unsigned(addrW)) = (num_addr_img * 2) - 1 THEN
					next_state <= S7;

					-- handle last case!    
				ELSIF IsNextAddrWLastLine THEN
					next_addrR <= STD_LOGIC_VECTOR(to_unsigned(num_addr_img - line_addr_jump, 16));
					next_state <= S1;

				ELSIF IsNextAddrWStartLine THEN
					next_state <= S1;

				END IF;

			WHEN S7 =>
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
