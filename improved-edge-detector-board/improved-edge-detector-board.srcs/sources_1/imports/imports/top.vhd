-- -----------------------------------------------------------------------------
--
--  Title      :  Top level for task 2 of the Edge-Detection design project.
--             :
--  Developers :  Luca Pezzarossa - lpez@dtu.dk
--             :  Mariana - s233360@student.dtu.dk
--             :
--  Purpose    :  A top-level entity connecting all the components.
--
-- -----------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.types.ALL;

ENTITY top IS
	PORT (
		clk_100mhz : IN STD_LOGIC;
		rst : IN STD_LOGIC;
		led : OUT STD_LOGIC;
		start : IN STD_LOGIC;
		-- Serial interface for PC communication
		serial_tx : IN STD_LOGIC; -- from the PC
		serial_rx : OUT STD_LOGIC -- to the PC
	);
END top;

ARCHITECTURE structure OF top IS
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
	-- The accelerator clock frequency will be (100MHz/CLK_DIVISION_FACTOR)
	CONSTANT CLK_DIVISION_FACTOR : INTEGER := 2; --(1 to 7)

	SIGNAL clk : bit_t;
	SIGNAL rst_s : STD_LOGIC;

	SIGNAL addr : halfword_t;
	SIGNAL dataR : word_t;
	SIGNAL dataW : word_t;
	SIGNAL en : bit_t;
	SIGNAL we : bit_t;
	SIGNAL finish : bit_t;
	SIGNAL start_db : bit_t;

	-- ram
	SIGNAL ram_we0 : bit_t;
	SIGNAL ram_we1 : bit_t;
	SIGNAL ram_we2 : bit_t;

	SIGNAL ram_ar : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL ram_aw : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL ram_data_in : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL ram_data_out0 : STD_LOGIC_VECTOR(47 DOWNTO 0);
	SIGNAL ram_data_out1 : STD_LOGIC_VECTOR(47 DOWNTO 0);
	SIGNAL ram_data_out2 : STD_LOGIC_VECTOR(47 DOWNTO 0);
	-- ram  

	SIGNAL mem_enb : STD_LOGIC;
	SIGNAL mem_web : STD_LOGIC;
	SIGNAL mem_addrb : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL mem_dib : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL mem_dob : STD_LOGIC_VECTOR(31 DOWNTO 0);

	SIGNAL data_stream_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL data_stream_in_stb : STD_LOGIC;
	SIGNAL data_stream_in_ack : STD_LOGIC;
	SIGNAL data_stream_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL data_stream_out_stb : STD_LOGIC;

BEGIN
	led <= finish;

	clock_divider_inst_0 : ENTITY work.clock_divider
		GENERIC MAP(
			DIVIDE => CLK_DIVISION_FACTOR
		)
		PORT MAP(
			clk_in => clk_100mhz,
			clk_out => clk
		);

	debounce_inst_0 : ENTITY work.debounce
		PORT MAP(
			clk => clk,
			reset => rst,
			sw => start,
			db_level => start_db,
			db_tick => OPEN,
			reset_sync => rst_s
		);

	accelerator_inst_0 : ENTITY work.acc
		PORT MAP(
			clk => clk,
			reset => rst_s,
			addr => addr,
			dataR => dataR,
			dataW => dataW,
			en => en,
			we => we,
			start => start_db,
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

	controller_inst_0 : ENTITY work.controller
		GENERIC MAP(
			MEMORY_ADDR_SIZE => 16
		)
		PORT MAP(
			clk => clk,
			reset => rst_s,
			data_stream_tx => data_stream_in,
			data_stream_tx_stb => data_stream_in_stb,
			data_stream_tx_ack => data_stream_in_ack,
			data_stream_rx => data_stream_out,
			data_stream_rx_stb => data_stream_out_stb,
			mem_en => mem_enb,
			mem_we => mem_web,
			mem_addr => mem_addrb,
			mem_dw => mem_dib,
			mem_dr => mem_dob
		);

	uart_inst_0 : ENTITY work.uart
		GENERIC MAP(
			baud => 115200,
			clock_frequency => POSITIVE(100_000_000 / CLK_DIVISION_FACTOR)
		)
		PORT MAP(
			clock => clk,
			reset => rst_s,
			data_stream_in => data_stream_in,
			data_stream_in_stb => data_stream_in_stb,
			data_stream_in_ack => data_stream_in_ack,
			data_stream_out => data_stream_out,
			data_stream_out_stb => data_stream_out_stb,
			tx => serial_rx,
			rx => serial_tx
		);

	memory3_inst_0 : ENTITY work.memory3
		GENERIC MAP(
			ADDR_SIZE => 16
		)
		PORT MAP(
			clk => clk,
			-- Port a (for the accelerator)
			ena => en,
			wea => we,
			addra => addr,
			dia => dataW,
			doa => dataR,
			-- Port b (for the uart/controller)
			enb => mem_enb,
			web => mem_web,
			addrb => mem_addrb,
			dib => mem_dib,
			dob => mem_dob
		);
		
	-- RAMs

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
