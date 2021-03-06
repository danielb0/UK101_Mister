-- This file is copyright by Grant Searle 2014
-- You are free to use this file in your own projects but must never charge for it nor use it without
-- acknowledgement.
-- Please ask permission from Grant Searle before republishing elsewhere.
-- If you use this file or any part of it, please add an acknowledgement to myself and
-- a link back to my main web site http://searle.hostei.com/grant/    
-- and to the UK101 page at http://searle.hostei.com/grant/uk101FPGA/index.html
--
-- Please check on the above web pages to see if there are any updates before using this file.
-- If for some reason the page is no longer available, please search for "Grant Searle"
-- on the internet to see if I have moved to another web hosting service.
--
-- Grant Searle
-- eMail address available on my main web page link above.

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use ieee.std_logic_unsigned.all;

entity uk101 is
	port(
		n_reset		: in std_logic;
		clk			: in std_logic;
		video_clock	: in std_logic; 
		cpuOverclock	: in std_logic_vector(2 downto 0);
		ce_pix	: in std_logic; 	
		rxd			: in std_logic;
		txd			: out std_logic;
		rts			: out std_logic;
		--videoSync	: out std_logic;
		--video			: out std_logic;
		hsync			:	out std_logic;
		vsync			:	out std_logic;
		r				:	out std_logic;
		g				:	out std_logic;
		b				:	out std_logic;
		screen_mode	:	in std_logic_vector(1 downto 0);
		actual_res	:	out std_logic;
		--colours		:	in std_logic_vector(1 downto 0);
		monitor_type : in std_logic_vector(2 downto 0);
		memory_size : in std_logic_vector(2 downto 0);
		machine_type	: in std_logic_vector(1 downto 0);
		baud_rate : in std_logic;
		hblank		:	out std_logic;
		vblank		:	out std_logic;
		ps2Clk		: in std_logic;
		ps2Data		: in std_logic;
		loadFrom			: in std_logic;
	   ioctl_download : in std_logic;
		ioctl_wr : in std_logic;
		ioctl_data : in std_logic_vector(7 downto 0);
      ioctl_addr  : in std_logic_vector(15 downto 0)
	);
end uk101;

architecture struct of uk101 is

	signal n_WR				: std_logic;
	signal cpuAddress		: std_logic_vector(15 downto 0);
	signal cpuDataOut		: std_logic_vector(7 downto 0);
	signal cpuDataIn		: std_logic_vector(7 downto 0);

	signal basRomData		: std_logic_vector(7 downto 0);
	signal basRomDataOSI		: std_logic_vector(7 downto 0);
	signal ramDataOut		: std_logic_vector(7 downto 0);
	signal monitorRomData : std_logic_vector(7 downto 0);
	signal monUKRomData : std_logic_vector(7 downto 0);
	signal SynmonRomData : std_logic_vector(7 downto 0);
	signal WemonRomData : std_logic_vector(7 downto 0);
	signal cegmonOSIRomData : std_logic_vector(7 downto 0);
	signal cegmonC1PRomData : std_logic_vector(7 downto 0);
	signal aciaData		: std_logic_vector(7 downto 0);

	signal n_memWR			: std_logic;
	
	signal n_dispRamCS	: std_logic;
	signal n_ramCS			: std_logic;
	signal n_basRomCS		: std_logic;
	signal n_monitorRomCS : std_logic;
	signal n_aciaCS		: std_logic;
	signal n_kbCS			: std_logic;
	signal n_iocs			: std_logic;
	
	signal dispAddrB 		: std_logic_vector(10 downto 0);
	signal dispRamDataOutA : std_logic_vector(7 downto 0);
	signal dispRamDataOutB : std_logic_vector(7 downto 0);
	signal charAddr 		: std_logic_vector(10 downto 0);
	signal charData 		: std_logic_vector(7 downto 0);
	signal charDataUK101 		: std_logic_vector(7 downto 0);
	signal charDataOSI 		: std_logic_vector(7 downto 0);

	signal serialClkCount: std_logic_vector(14 downto 0); 
	signal cpuClkCount	: std_logic_vector(5 downto 0); 
	signal cpuClock		: std_logic;
	signal serialClock	: std_logic;

	signal kbReadData 	: std_logic_vector(7 downto 0);
	signal kbRowSel 		: std_logic_vector(7 downto 0);
	--signal video_clock		: std_ulogic;
	
	--serial clock count thresholds
	constant c_9600BaudClkCount1 : integer:=325;
	constant c_9600BaudClkCount2 : integer:=162;
	constant c_300BaudClkCount1 : integer:=10416;
	constant c_300BaudClkCount2 : integer:=5208;
	
	signal serialClkCount1: integer := 0;
	signal serialClkCount2: integer := 0;
	signal i_clockThreshold1 : integer range 0 to 50 := 0;
	signal i_clockThreshold2 : integer range 0 to 25 := 0;
	signal i_cpuOverclock : integer range 0 to 5 := 0;
	signal i_monitor_type : integer range 0 to 3 := 0;
	signal i_memory_size : integer range 0 to 3 := 0;
	signal i_machine_type : integer range 0 to 3 := 0;
	signal latchedbits : std_logic_vector(7 downto 0);
	signal resolution : std_logic;

begin

	resolution <= latchedbits(0) when i_machine_type=1 and screen_mode(1)='1' else screen_mode(0);
	actual_res <= resolution;
	i_clockThreshold1 <= 49 when i_cpuOverclock = 0 else 	--1Mhz
								23 when i_cpuOverclock = 1 else	--2 Mhz
								11 when i_cpuOverclock = 2 else	--4 Mhz
								5 when i_cpuOverclock = 3 else 4; -- 8, 10 Mhz
								
	i_clockThreshold2 <= 25 when i_cpuOverclock = 0 else
							  12 when i_cpuOverclock = 1 else
							  6 when i_cpuOverclock = 2 else
							  3 when i_cpuOverclock = 3 else 2;
								
	serialClkCount1 <= c_9600BaudClkCount1 when baud_rate = '0' else c_300BaudClkCount1;
	serialClkCount2 <= c_9600BaudClkCount2 when baud_rate = '0' else c_300BaudClkCount2;
	
	i_cpuOverclock <= to_integer(unsigned(cpuOverclock));
	i_monitor_type <= to_integer(unsigned(monitor_type(1 downto 0))) when i_machine_type = 0 else to_integer(unsigned('0' & monitor_type(2 downto 2))) ;
	i_memory_size <= to_integer(unsigned(memory_size(2 downto 0)));
	i_machine_type <= to_integer(unsigned(machine_type(1 downto 0)));
	charData <= charDataUK101 when i_machine_type = 0 else charDataOSI;
	
	n_memWR <= not(cpuClock) nand (not n_WR);

	n_dispRamCS <= '0' when cpuAddress(15 downto 11) = "11010" and  (i_machine_type = 0 or i_machine_type = 1) else
						'0' when cpuAddress(15 downto 10) = "110100" and  i_machine_type = 2 else 
						'1';
	n_basRomCS <= '0' when cpuAddress(15 downto 13) = "101" else '1'; --8k
	n_monitorRomCS	<= '0' when cpuAddress(15 downto 11) = "11111" and ((i_machine_type = 0 and i_monitor_type < 2) or i_machine_type = 2) else --uk101
							'0' when cpuAddress(15 downto 12) = "1111" and i_machine_type = 0 and i_monitor_type = 2 else	--uk101 with wemon
						'0' when cpuAddress(15 downto 11) = "11111" and i_machine_type = 1 and i_monitor_type = 1  else		--OSI with Synmon
						'0' when (cpuAddress(15 downto 11) = "11111" and cpuAddress(11 downto 8) /= "1100") and i_machine_type = 1 and i_monitor_type = 0  else		-- 2K      $F800-$FFFF  (except $FC00-$FCFF)  C2/C4
					   '0' when cpuAddress(15 downto 8)  = "11110100" and i_machine_type = 1 and i_monitor_type = 0 else	   										-- 256byte $F400-$F4FF  (relocated FC00-FCFF block)
					   '1';
	n_iocs <= '0' when cpuAddress(15 downto 0 ) = X"DE00" and i_machine_type = 1 else '1'; 						
	n_ramCS <= not(n_dispRamCS and n_basRomCS and n_monitorRomCS and n_aciaCS and n_kbCS) when i_memory_size = 3 else  --41K
					'0' when cpuAddress(15 downto 12) = "0000" and i_memory_size = 0 else											--4k
					'0' when cpuAddress(15 downto 13) = "000"  and i_memory_size = 1 else											--8k
					'0' when cpuAddress(15) = '0' and i_memory_size = 2																	--32K
					else '1';
	n_aciaCS <= '0' when cpuAddress(15 downto 1) = "111100000000000" and ((i_machine_type = 0 and i_monitor_type < 2) or i_machine_type = 2) else
					'0' when cpuAddress(15 downto 1) = "111000000000000" and i_machine_type = 0 and i_monitor_type = 2 else
					'0' when cpuAddress(15 downto 1) = "111111000000000" and i_machine_type = 1 else '1';
	n_kbCS <= '0' when cpuAddress(15 downto 10) = "110111" else '1';

 
	cpuDataIn <=
		    -- CEGMON PATCH TO CORRECT AUTO-REPEAT IN FAST MODE(UK101)
		x"A0" when cpuAddress = X"FCE0" and i_cpuOverclock = 4 and (i_machine_type = 0 or i_machine_type = 2) else -- Address = FCE0 and fastMode = 1 : CHANGE REPEAT RATE LOOP VALUE (was $10)
		x"80" when cpuAddress = X"FCE0" and i_cpuOverclock = 3 and (i_machine_type = 0 or i_machine_type = 2) else 
		x"40" when cpuAddress = X"FCE0" and i_cpuOverclock = 2 and (i_machine_type = 0 or i_machine_type = 2) else 	
		x"20" when cpuAddress = X"FCE0" and i_cpuOverclock = 1 and (i_machine_type = 0 or i_machine_type = 2) else 	
		x"10" when cpuAddress = X"FCE0" and i_cpuOverclock = 0 and (i_machine_type = 0 or i_machine_type = 2) else 	
	
		 -- CEGMON PATCH TO CORRECT AUTO-REPEAT IN FAST MODE(OSI)
		x"A0" when cpuAddress = X"F4E0" and i_cpuOverclock = 4 and i_machine_type = 1 else -- Address = F4E0 and fastMode = 1 : CHANGE REPEAT RATE LOOP VALUE (was $10)
		x"80" when cpuAddress = X"F4E0" and i_cpuOverclock = 3 and i_machine_type = 1 else 
		x"40" when cpuAddress = X"F4E0" and i_cpuOverclock = 2 and i_machine_type = 1 else 	
		x"20" when cpuAddress = X"F4E0" and i_cpuOverclock = 1 and i_machine_type = 1 else 	
		x"10" when cpuAddress = X"F4E0" and i_cpuOverclock = 0 and i_machine_type = 1 else 		
		
		
		
		-- CEGMON PATCH FOR 64x32 SCREEN
		x"3F" when cpuAddress = x"FBBC" and resolution='1' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON SWIDTH (was $47)
		x"00" when cpuAddress = x"FBBD" and resolution='1' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON TOP L (was $0C (1st line) or $8C (3rd line))
		x"BF" when cpuAddress = x"FBBF" and resolution='1' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON BASE L (was $CC)
		x"D7" when cpuAddress = x"FBC0" and resolution='1' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON BASE H (was $D3)
		x"00" when cpuAddress = x"FBC2" and resolution='1' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON STARTUP TOP L (was $0C (1st line) or $8C (3rd line))
		x"00" when cpuAddress = x"FBC5" and resolution='1' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON STARTUP TOP L (was $0C (1st line) or $8C (3rd line))
		x"00" when cpuAddress = x"FBCB" and resolution='1' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON STARTUP TOP L (was $0C (1st line) or $8C (3rd line))
		x"10" when cpuAddress = x"FE62" and resolution='1' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON CLR SCREEN SIZE (was $08)
		x"D8" when cpuAddress = x"FB8B" and resolution='1' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON SCREEN BOTTOM H (was $D4) - Part of CTRL-F code
		x"D7" when cpuAddress = x"FE3B" and resolution='1' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON SCREEN BOTTOM H - 1 (was $D3) - Part of CTRL-A code
		
		x"2F" when cpuAddress = x"FBBC" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON SWIDTH (was $47)
		x"1F" when cpuAddress = x"FBBC" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 1 else -- CEGMON SWIDTH (was $47)
		x"00" when cpuAddress = x"FBBD" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON TOP L (was $0C (1st line) or $8C (3rd line))
		x"85" when cpuAddress = x"FBBF" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON BASE L (was $CC)
		x"D3" when cpuAddress = x"FBC0" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON BASE H (was $D3)
		x"00" when cpuAddress = x"FBC2" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON STARTUP TOP L (was $0C (1st line) or $8C (3rd line))
		x"00" when cpuAddress = x"FBC5" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON STARTUP TOP L (was $0C (1st line) or $8C (3rd line))
		x"00" when cpuAddress = x"FBCB" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON STARTUP TOP L (was $0C (1st line) or $8C (3rd line))
		x"08" when cpuAddress = x"FE62" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON CLR SCREEN SIZE (was $08)
		x"D4" when cpuAddress = x"FB8B" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON SCREEN BOTTOM H (was $D4) - Part of CTRL-F code
		x"D3" when cpuAddress = x"FE3B" and resolution='0' and screen_mode(1)='0' and i_monitor_type = 0 and i_machine_type = 0 else -- CEGMON SCREEN BOTTOM H - 1 (was $D3) - Part of CTRL-A code
		basRomData when n_basRomCS = '0' and i_machine_type = 0 else
		basRomDataOSI when n_basRomCS = '0' and (i_machine_type = 1 or i_machine_type = 2) else
		monitorRomData when n_monitorRomCS = '0' and i_machine_type = 0 and i_monitor_type = 0 else
		monUKRomData when n_monitorRomCS = '0' and i_machine_type = 0 and i_monitor_type = 1 else
		WemonRomData when n_monitorRomCS = '0' and i_machine_type = 0 and i_monitor_type = 2 else
		cegmonOSIRomData when n_monitorRomCS = '0' and i_machine_type = 1 and i_monitor_type = 0  else
		cegmonC1PRomData when n_monitorRomCS = '0' and i_machine_type = 2 else
		SynmonRomData when n_monitorRomCS = '0' and i_machine_type = 1 and i_monitor_type = 1 and cpuAddress >=x"FD00"  else
		aciaData when n_aciaCS = '0' else
		ramDataOut when n_ramCS = '0' else
		dispRamDataOutA when n_dispRamCS = '0' else
		kbReadData when n_kbCS='0'
		else x"FF";
		
	u1 : entity work.T65
	port map(
		Enable => '1',
		Mode => "00",
		Res_n => n_reset,
		Clk => cpuClock,
		Rdy => '1',
		Abort_n => '1',
		IRQ_n => '1',
		NMI_n => '1',
		SO_n => '1',
		R_W_n => n_WR,
		A(15 downto 0) => cpuAddress,
		DI => cpuDataIn,
		DO => cpuDataOut);
			

	u2 : entity work.BasicRom -- 8KB
	port map(
		address => cpuAddress(12 downto 0),
		clock => clk,
		q => basRomData
	);
	
	
	u10 : entity work.BasicRomOSI -- 8KB
	port map(
		address => cpuAddress(12 downto 0),
		clock => clk,
		q => basRomDataOSI
	);

	u3: entity work.ProgRam 
	port map
	(
		address => cpuAddress(15 downto 0),
		clock => clk,
		data => cpuDataOut,
		wren => not(n_memWR or n_ramCS),
		q => ramDataOut
	);
		
	u4: entity work.CegmonRom
	port map
	(
		address => cpuAddress(10 downto 0),
		q => monitorRomData
	);
	
	u11: entity work.MonUK02Rom
	port map
	(
		address => cpuAddress(10 downto 0),
		q => monUKRomData
	);
	
	
	u12: entity work.CegmonRomOSI
	port map
	(
		address => cpuAddress(10 downto 0),
		q => cegmonOSIRomData
	);
	
	u16: entity work.CegmonRomC1P
	port map
	(
		address => cpuAddress(10 downto 0),
		q => cegmonC1PRomData
	);
	
	u14: entity work.SynmonRom
	port map
	(
		address => cpuAddress(10 downto 0),
		q => SynmonRomData
	);
	
	u15: entity work.WemonRom
	port map
	(
		address => cpuAddress(11 downto 0),
		q => WemonRomData
	);

	u5: entity work.bufferedUART
	port map(
		clk => clk,
		n_wr => n_aciaCS or cpuClock or n_WR,
		n_rd => n_aciaCS or cpuClock or (not n_WR),
		regSel => cpuAddress(0),
		dataIn => cpuDataOut,
		dataOut => aciaData,
		rxClock => serialClock,
		txClock => serialClock,
		rxd => rxd,
		txd => txd,
		n_cts => '0',
		n_dcd => '0',
		n_rts => rts,
		ioctl_download => ioctl_download,
	   ioctl_data => ioctl_data,
		ioctl_addr => ioctl_addr,
		ioctl_wr => ioctl_wr,
		loadFrom => loadFrom
	
	);
	
	u6 : entity work.UK101TextDisplay
	port map (
		charAddr => charAddr,
		charData => charData,
		dispAddr => dispAddrB,
		dispData => dispRamDataOutB,
		clk => video_clock,
		ce_pix => ce_pix,
		hsync_out => hsync,
		vsync_out => vsync,
		hblank_out => hblank,
		vblank_out => vblank,
		--colours => colours,
		resolution => resolution,
		machine_type => i_machine_type,
		--monitor_type => monitor_type,
		r => r,
		g => g,
		b => b
	);

	process (clk)
	begin
		if rising_edge(clk) then

			if cpuClkCount < i_clockThreshold1 then
				 cpuClkCount <= cpuClkCount + 1;
			else
				 cpuClkCount <= (others=>'0');
			end if;
			if cpuClkCount < i_clockThreshold2 then
				 cpuClock <= '0';
			else
				 cpuClock <= '1';
			end if;
     
							
			if serialClkCount < serialClkCount1 then
				serialClkCount <= serialClkCount + 1;
			else
				serialClkCount <= (others => '0');
			end if;

			if serialClkCount < serialClkCount2 then 
				serialClock <= '0';
			else
				serialClock <= '1';
			end if;	
		end if;
	end process;
	

	u7: entity work.CharRom
	port map
	(
		address => charAddr,
		q => charDataUK101
	);
	
	u13: entity work.CharRomOSI
	port map
	(
		address => charAddr,
		q => charDataOSI
	);

	u8: entity work.DisplayRam 
	port map
	(
		address_a => cpuAddress(10 downto 0),
		address_b => dispAddrB,
		clock	=> clk,
		data_a => cpuDataOut,
		data_b => (others => '0'),
		wren_a => not(n_memWR or n_dispRamCS),
		wren_b => '0',
		q_a => dispRamDataOutA,
		q_b => dispRamDataOutB
	);
	
	u9 : entity work.UK101keyboard
	port map(
		CLK => clk,
		nRESET => n_reset,
		PS2_CLK	=> ps2Clk,
		PS2_DATA	=> ps2Data,
		A	=> kbRowSel,
		KEYB	=> kbReadData,
		machine_type => i_machine_type
	);
	
	
	DisplayRegister	:	entity work.OutLatch
	port map (
		dataIn	=> cpuDataOut,
		clock		=> clk,
		load		=> n_iocs,
		clear		=> n_reset,
		latchOut	=> latchedbits
	);
	
	process (n_kbCS,n_memWR)
	begin
		if	n_kbCS='0' and n_memWR = '0' then
			kbRowSel <= cpuDataOut;
		end if;
	end process;
	
end;
