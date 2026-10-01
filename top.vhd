----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.09.2026 13:14:58
-- Design Name: 
-- Module Name: top - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top is
    Port (
        clk : in std_logic;
        tmpSDA : inout std_logic;
        tmpSCL : inout std_logic;
        an : out std_logic_vector(7 downto 0) := (others=>'1'); 
        seg : out std_logic_vector(6 downto 0);
        dp : out std_logic;
        btnC   : in std_logic
    );
end top;

architecture Behavioral of top is
    signal temp_raw_internal : std_logic_vector(15 downto 0);
    signal temp_value        : std_logic_vector(11 downto 0);
begin
    temperature: entity work.adt7420_reader
        port map(
            clk => clk,
            reset => btnC,
            tmp_sda => tmpSDA,
            tmp_scl => tmpSCL,
            temp_raw => temp_raw_internal
        );
    
    converter: entity work.convert
        port map (
            temp_value => temp_value,
            temp_raw => temp_raw_internal
        );
    
    display: entity work.display
        port map(
            temp_value => temp_value,
            an => an,
            seg => seg,
            dp => dp,
            clk => clk
        );
        
end Behavioral;
