----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.09.2026 19:42:21
-- Design Name: 
-- Module Name: to_bcd - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity convert is
    Port ( 
        temp_raw : in std_logic_vector(15 downto 0);
        temp_value : out std_logic_vector(11 downto 0)
    );
end convert;

architecture Behavioral of convert is

begin
    process (temp_raw)
        variable temp_code : signed(12 downto 0); -- rå verdi
        variable temp_calc : signed(15 downto 0); -- Midlertidig mellomverdi
    begin
        -- Hent 13 bit temperaturverdi fra sensoren
        temp_code := signed(temp_raw(15 downto 3));
        
        --temp_tenths = temp_code * 5/8
        temp_calc := resize( resize(temp_code, 16) * 5, 16 );
        temp_value <= std_logic_vector ( resize(temp_calc / 8, 12) );
        
    end process;

end Behavioral;
