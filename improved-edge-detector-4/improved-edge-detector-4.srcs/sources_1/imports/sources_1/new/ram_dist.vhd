-- -----------------------------------------------------------------------------
--
--  Title      :  Distributed memory for the Edge-Detection design project
--             :
--  Developers :  Mariana - s233360@student.dtu.dk
--             :
--  Purpose    :  This design contains a distributed memory entity for the
--             :  accelerator that must be build in the Edge Detection design 
--             :  project. It contains an architecture skeleton for the entity as well.
--
-- -----------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
ENTITY rams_dist IS
	PORT (
		clk : IN STD_LOGIC;
		we : IN STD_LOGIC;
		aw : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		ar : IN STD_LOGIC_VECTOR(6 DOWNTO 0);

		di : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		do : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
	);
END rams_dist;
ARCHITECTURE syn OF rams_dist IS

	TYPE ram_type IS ARRAY (89 DOWNTO 0) OF STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL RAM : ram_type;
BEGIN
	PROCESS (clk)
	BEGIN
		IF (clk'event AND clk = '1') THEN
			IF (we = '1') THEN
				RAM(to_integer(unsigned(aw))) <= di;
			END IF;
		END IF;
	END PROCESS;
	do <= RAM(to_integer(unsigned(ar)))(7 DOWNTO 0) & RAM(to_integer(unsigned(ar)) + 1)(31 DOWNTO 0) & RAM(to_integer(unsigned(ar)) + 2)(31 DOWNTO 24);
END syn;
