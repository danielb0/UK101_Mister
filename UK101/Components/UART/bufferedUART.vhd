-- 6850 ACIA COMPATIBLE UART WITH HARDWARE INPUT BUFFER AND HANDSHAKE
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

entity bufferedUART is
	port (
		clk		:	in std_logic;
		rst		:	in std_logic;
		n_wr    : in  std_logic;
		n_rd    : in  std_logic;
		regSel  : in  std_logic;
		--dataIn  : in  std_logic_vector(7 downto 0);
		dataOut : out std_logic_vector(7 downto 0);
		n_int   : out std_logic; 
		rxClock : in  std_logic; -- 16 x baud rate
		txClock : in  std_logic; -- 16 x baud rate
		rxd     : in  std_logic;
		txd     : out std_logic;
		n_rts   : out std_logic :='0';
		n_cts   : in  std_logic; 
		n_dcd   : in  std_logic;
		ioctl_download : in std_logic;
		ioctl_wr : in std_logic;
		ioctl_data : in std_logic_vector(7 downto 0);
      ioctl_addr :  in std_logic_vector(15 downto 0);
		--address : in std_logic;
		--dout		:out std_logic_vector(7 downto 0); -- 8-bit output bus
      data_ready : out std_logic 

   );
end bufferedUART;

architecture rtl of bufferedUART is
	
	type byteArray is array (0 to 1024) of std_logic_vector(7 downto 0);
	signal ascii_data : byteArray;
   --signal v_text_byte : unsigned(15 downto 0);
	signal ascii : std_logic_vector(7 downto 0);
   signal in_dl : std_logic;
	signal ascii_rdy : std_logic;
	signal w_data_ready : std_logic;
	signal i_outCounter  : integer range 0 to 1024 := 0;
	signal i_ascii_last_byte : integer range 0 to 65535 := 0;
	signal i_ioctl_addr : natural range 0 to 65535 := 0;
	signal i_text_byte : natural range 0 to 65535 := 0;
	signal i_previous_addr : integer range 0 to 65535 := 0;
	signal prev_clk : std_logic;
	signal statusReg : std_logic_vector(7 downto 0) := (others => '0'); 
	signal n_int_internal   : std_logic := '1';


 
----Outputs
		signal new_clk : std_logic;


	
begin


--Instantiate the clock divider
		uut: entity work.Clock_Divider PORT MAP (
		clk => clk,
		reset => rst,
		clock_out => new_clk
		);

		statusReg(0) <= '0' when i_ioctl_addr = i_outCounter else '1';
		statusReg(1) <=  '0';
		statusReg(2) <= n_dcd;
		statusReg(3) <= n_cts;
		statusReg(7) <= not(n_int_internal);
		  
		-- interrupt mask
		n_int <= n_int_internal;
		n_int_internal <= '0' when (i_ioctl_addr /= i_outCounter) and in_dl = '1' else '1';
	
	    w_data_ready <= in_dl and  (not ioctl_download);
		 data_ready <= w_data_ready;
		
	o1: process (clk)
	
	begin
		if rising_edge (clk) then
		
				if rst = '1' then
					i_ascii_last_byte <= 0;
					i_outCounter <= 0;
					ascii_rdy <= '0';
					prev_clk <= '0';
				else				
					if prev_clk = '1' and n_rd = '0' then
							if ascii_rdy = '0' and w_data_ready = '1' and i_outCounter <= i_ascii_last_byte then
										ascii <= ascii_data(i_outCounter)(7 downto 0);
										i_outCounter <= i_outCounter+1;
										ascii_rdy <= '1';
							end if;
					 end if;
			
					if ioctl_download = '1' then
						i_ioctl_addr <= to_integer(unsigned(ioctl_addr));
						ascii_data(i_ioctl_addr) <= ioctl_data;
						i_ascii_last_byte <= i_ioctl_addr;
						i_outCounter <= 0;
						in_dl <= '1';
					else
						if in_dl = '1' and i_outCounter > i_ascii_last_byte then
							in_dl<= '0';
						end if;
					end if;
	
		
					if n_rd = '0' then	
						if regSel = '1' then
					
									dataOut <= ascii(7 downto 0);

									ascii_rdy <= '0';
						else
									dataOut<= statusReg;
						end if;
					end if;
				end if;

				prev_clk <= n_rd;
		end if;
		
	
	end process;
	
		
end rtl;




library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity Clock_Divider is
	port ( clk,reset: in std_logic;
	clock_out: out std_logic);
	end Clock_Divider;
	  
	architecture bhv of Clock_Divider is
	  
		signal count: integer:=1;
		signal tmp : std_logic := '0';
		  
		begin
		  
		process(clk,reset)
		begin
			if(reset='1') then
				count<=1;
				tmp<='0';
			elsif(clk'event and clk='1') then
				count <=count+1;
				if (count = 3000) then
					tmp <= NOT tmp;
					count <= 1;
				end if;
			end if;
			clock_out <= tmp;
		end process;
	  
	end bhv;

