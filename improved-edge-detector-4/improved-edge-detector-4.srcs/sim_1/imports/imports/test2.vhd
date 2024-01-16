-- -----------------------------------------------------------------------------
--
--  Title      :  Testbench for task 2 of the Edge-Detection design project.
--             :
--  Developers :  Jonas Benjamin Borch - s052435@student.dtu.dk
--             :
--  Purpose    :  This design contains an architecture for the testbench used in
--             :  task 2 of the Edge-Detection design project.
--             :
--             :
--  Revision   :  1.0    07-10-08    Initial version
--             :  1.1    08-10-09    Split data line to dataR and dataW
--             :                     Edgar 
--             :
--  Special    :
--  thanks to  :  Niels Haandbaek -- c958307@student.dtu.dk
--             :  Michael Kristensen -- c973396@student.dtu.dk
--             :  Hans Holten-Lund -- hahl@imm.dtu.dk
-- -----------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE WORK.types.ALL;

ENTITY testbench IS
END testbench;

ARCHITECTURE structure OF testbench IS
	COMPONENT clock
		GENERIC (
			period : TIME := 80 ns
		);
		PORT (
			stop : IN STD_LOGIC;
			clk : OUT STD_LOGIC := '0'
		);
	END COMPONENT;

	COMPONENT memory2 IS
		GENERIC (
			load_file_name : STRING
		);
		PORT (
			clk : IN STD_LOGIC;
			en : IN STD_LOGIC;
			we : IN STD_LOGIC;
			addr : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			dataW : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			dataR : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			dump_image : IN STD_LOGIC
		);
	END COMPONENT memory2;

	COMPONENT acc
		PORT (
			clk : IN bit_t;
			reset : IN bit_t;
			addr : OUT halfword_t;
			dataR : IN word_t;
			dataW : OUT word_t;
			en : OUT bit_t;
			we : OUT bit_t;
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
	END COMPONENT;

	COMPONENT rams_dist IS
		PORT (
			clk : IN STD_LOGIC;
			we : IN STD_LOGIC;
			ar : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
			aw : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
			di : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			do : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
		);
	END COMPONENT;

	SIGNAL StopSimulation : bit_t := '0';
	SIGNAL clk : bit_t;
	SIGNAL reset : bit_t;

	SIGNAL addr : halfword_t;
	SIGNAL dataR : word_t;
	SIGNAL dataW : word_t;
	SIGNAL en : bit_t;
	SIGNAL we : bit_t;
	SIGNAL start : bit_t;
	SIGNAL finish : bit_t;
	SIGNAL ram_we0 : bit_t;
	SIGNAL ram_we1 : bit_t;
	SIGNAL ram_we2 : bit_t;

	SIGNAL ram_ar : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL ram_aw : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL ram_data_in : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL ram_data_out0 : STD_LOGIC_VECTOR(47 DOWNTO 0);
	SIGNAL ram_data_out1 : STD_LOGIC_VECTOR(47 DOWNTO 0);
	SIGNAL ram_data_out2 : STD_LOGIC_VECTOR(47 DOWNTO 0);
BEGIN
	-- reset is active-low
	reset <= '1', '0' AFTER 180 ns;

	-- start logic
	start_logic : PROCESS IS
	BEGIN
		start <= '0';

		WAIT UNTIL reset = '0' AND clk'event AND clk = '1';
		start <= '1';

		-- wait before accelerator is complete before deasserting the start
		WAIT UNTIL clk'event AND clk = '1' AND finish = '1';
		start <= '0';

		WAIT UNTIL clk'event AND clk = '1';
		REPORT "Test finished successfully! Simulation Stopped!" SEVERITY NOTE;
		StopSimulation <= '1';
	END PROCESS;

	SysClk : clock
	PORT MAP(
		stop => StopSimulation,
		clk => clk
	);

	Accelerator : acc
	PORT MAP(
		clk => clk,
		reset => reset,
		addr => addr,
		dataR => dataR,
		dataW => dataW,
		en => en,
		we => we,
		start => start,
		finish => finish,
		ram_we0 => ram_we0,
		ram_we1 => ram_we1,
		ram_we2 => ram_we2,
		ram_ar => ram_ar, -- the same for 3 rams
		ram_aw => ram_aw, -- the same for 3 rams
		ram_data_in => ram_data_in, -- the same for 3 rams
		ram_data_out0 => ram_data_out0,
		ram_data_out1 => ram_data_out1,
		ram_data_out2 => ram_data_out2
	);

	Memory : memory2
	GENERIC MAP(
		load_file_name => "/home/mar/pic1_.pgm"
	)
	-- Result is saved to: load_file_name & "_result.pgm"
	PORT MAP(
		clk => clk,
		en => en,
		we => we,
		addr => addr,
		dataW => dataW,
		dataR => dataR,
		dump_image => finish
	);

	RamDist0 : rams_dist
	PORT MAP(
		clk => clk,
		we => ram_we0,
		ar => ram_ar,
		aw => ram_aw,
		di => ram_data_in,
		do => ram_data_out0
	);
	RamDist1 : rams_dist
	PORT MAP(
		clk => clk,
		we => ram_we1,
		ar => ram_ar,
		aw => ram_aw,
		di => ram_data_in,
		do => ram_data_out1
	);

	RamDist2 : rams_dist
	PORT MAP(
		clk => clk,
		we => ram_we2,
		ar => ram_ar,
		aw => ram_aw,
		di => ram_data_in,
		do => ram_data_out2
	);

END structure;
