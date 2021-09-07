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
		--dataOut : out std_logic_vector(7 downto 0);
		n_int   : out std_logic; 
		rxClock : in  std_logic; -- 16 x baud rate
		txClock : in  std_logic; -- 16 x baud rate
		rxd     : in  std_logic;
		txd     : out std_logic;
		n_rts   : out std_logic :='0';
		n_cts   : in  std_logic; 
		n_dcd   : in  std_logic;
		ioctl_download : in std_logic;
		ioctl_data : in std_logic_vector(7 downto 0);
      ioctl_addr :  in std_logic_vector(15 downto 0);
		address : in std_logic;
		dout		:out std_logic_vector(7 downto 0) -- 8-bit output bus
      --data_ready : out std_logic 

   );
end bufferedUART;

architecture rtl of bufferedUART is
	
	type byteArray is array (0 to 65535) of std_logic_vector(7 downto 0);
	signal ascii_data : byteArray;
   --signal v_text_byte : unsigned(15 downto 0);
	signal ascii : std_logic_vector(7 downto 0);
   signal in_dl : std_logic;
	signal ascii_rdy : std_logic;
	--signal w_data_ready : std_logic;

	
begin

	
	output: process (n_rd)
	
	variable v_ascii_last_byte : natural range 0 to 65535 := 0;
	variable v_text_byte : natural range 0 to 65535 := 0;
   variable v_ioctl_addr : natural range 0 to 65535 := 0;
	begin

	
		if falling_edge(n_rd) then
		
			
				if rst = '1' then
					ascii_rdy   <= '0';
					v_ascii_last_byte := 0;
				end if;
		
				if ascii_rdy = '0' and v_ascii_last_byte = v_text_byte then
					ascii <= ascii_data(v_text_byte);
					ascii_rdy   <= '1';
               v_text_byte := v_text_byte + 1;
				end if;
		
				if ioctl_download ='1' then
					v_ioctl_addr := to_integer(unsigned(ioctl_addr));
					ascii_data(v_ioctl_addr) <= ioctl_data;
					v_ascii_last_byte := v_ioctl_addr;
					v_text_byte := 0;
					in_dl <= '1';
				elsif in_dl = '1' and v_text_byte > v_ascii_last_byte then
					  in_dl <= '0';
				end if;
				
				
				
			-- if rising_edge(rxclock) then
			  if address = '0' then
						--RX buffer address
				dout <= ascii(7 downto 0);
				ascii_rdy <= '0'; 
			 else
					  --RX status register
				dout <= ascii_rdy & "0000000";
			 end if;
		--	 end if;
		end if;

	--w_data_ready <= in_dl and not ioctl_download;
	
	--data_ready <= w_data_ready;

	end process;
		
		
end rtl;
