library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adt7420_reader is
    generic (
        CLK_HZ  : integer := 100_000_000;
        I2C_HZ  : integer := 100_000;
        POLL_MS : integer := 500
    );
    port (
        clk        : in    std_logic;
        reset      : in    std_logic;

        tmp_scl    : inout std_logic;
        tmp_sda    : inout std_logic;

        temp_raw   : out   std_logic_vector(15 downto 0);
        data_valid : out   std_logic;
        i2c_error  : out   std_logic
    );
end entity;


architecture Behavioral of adt7420_reader is
    type stage is (
        IDLE,
        
        -- Start I2C kommunikasjons prosess 
        START1,
        
        -- Skriver til adressen (temp sensor) at jeg skal skrive    
        ADDRESS,
        ACK_ADDRESS,
        -- Sir at den skal starte å lese fra register adresse 0x0.
        SENDREGISTER,
        ACK_REGISTER,
        
        --REPEATED START: Starter på nytt, og skal nå hente ut data fra sensoren
        START2,
        ADDRESS2,
        ACK_ADDRESS2,
        
        DATAFRAME1, -- Byte en fra start 0x00
        ACK_DATA1,  -- Hent mer data
        DATAFRAME2, -- Byte to fra start 0x00
        NACK_DATA2, -- Ferdig å hente data
        
        STOP
    );
    
    constant I2C_COUNT : integer := CLK_HZ / (I2C_HZ * 2);
    
    signal adr : std_logic_vector(7 downto 0); -- Adressen til temp sensor
    signal ACKNACK : std_logic;
    signal phase : integer := 0; -- Brukes som delsteg
    signal bit_counter : integer; -- brukes for å måle hvor mange bits som har blitt sendt
    
    signal data : std_logic_vector(7 downto 0) := (others=>'0');
    signal temp_temp : std_logic_vector(15 downto 0) := (others=>'0');
    
    signal current_stage : stage := IDLE;
    signal counter : integer := 0;
    
    signal scl_low : std_logic := '0';
    signal sda_low : std_logic := '0';
begin
    tmp_scl <= '0' when scl_low = '1' else 'Z';
    tmp_sda <= '0' when sda_low = '1' else 'Z';
    
    process (clk)
    begin
        if (rising_edge(clk)) then
            data_valid <= '0';
            
            if (reset = '1') then
                scl_low <= '0';
                sda_low <= '0';
                current_stage <= IDLE;
                counter <= 0;
                i2c_error <= '0';
                data_valid <= '0';
            
            -- nok tid har gått til at linjen kan endres
            elsif (counter = I2C_COUNT-1) then
                counter <= 0;
                case current_stage is
                    when IDLE =>
                        current_stage <= START1;
                        
                    -- Start i2c    
                    when START1 =>
                        sda_low <= '1';
                        scl_low <= '0';
                        
                        adr <= "1001011" & '0'; -- Temperatur sensor adresse: 1001011 + RW=0 (Jeg skal skrive)
                        bit_counter <= 7;
                        phase <= 0;
                        
                        current_stage <= ADDRESS;
                        
                        
                    -- Skriv temp sensor adr på SDA
                    when ADDRESS =>
                        -- fase 0 av bit transmisjon
                        if (phase = 0) then
                            scl_low <= '1';
                            if( adr(bit_counter) = '0' ) then -- Er biten 0?
                                sda_low <= '1'; -- Ja, send 0
                            else
                                sda_low <= '0'; -- Nei, send 1.
                            end if;
                            phase <= 1; -- Neste fase
                        elsif (phase = 1) then
                            scl_low <= '0';
                            phase <= 0;
                            if (bit_counter = 0) then -- Ferdig å transmite bits?
                                current_stage <= ACK_ADDRESS;
                            else
                                bit_counter <= bit_counter - 1;
                            end if;
                        end if;
                    
                    
                    -- Sensor skal acknowledge at den har motatt alt    
                    when ACK_ADDRESS =>
                        if (phase=0) then
                            scl_low <= '1'; -- Klokke lav
                            sda_low <= '0'; -- Slipp SDA
                            phase <= 1;
                        elsif(phase=1) then
                            scl_low <= '0'; -- la en i2c syklus gå
                            phase <= 2;
                        elsif(phase=2) then
                            -- SCL settes høy av sensoren
                            if (tmp_sda = '0') then -- Sensor sender ACK, ingen problemer oppstått
                                current_stage <= SENDREGISTER;
                                bit_counter <= 7;
                            else -- NACK, feil oppstått.
                                i2c_error <= '1';
                                current_stage <= STOP;
                            end if;
                                                    
                            scl_low <= '1';  -- avslutt ACK-klokkeslaget
                            phase <= 0;
                        end if;

                    
                    
                    -- Fortell at vi skal lese fra register 0x00.
                    when SENDREGISTER =>
                        sda_low <= '1'; -- Skal sende 0x00, altså 0 åtte ganger.
                        
                        if phase=0 then
                            scl_low <= '1';
                            phase <= 1;
                            
                        elsif phase=1 then
                            scl_low <= '0';
                            phase <= 0;
                            
                            if (bit_counter = 0) then
                                current_stage <= ACK_REGISTER;
                            else
                                bit_counter <= bit_counter - 1;
                            end if;
                        end if;
                        
                        
                        
                    when ACK_REGISTER =>
                        if (phase=0) then
                            scl_low <= '1'; -- Klokke lav
                            sda_low <= '0'; -- Slipp SDA
                            phase <= 1;
                        elsif(phase=1) then
                            scl_low <= '0'; -- la en i2c syklus gå
                            phase <= 2;
                        elsif(phase=2) then
                            -- SCL settes høy av sensoren
                            if (tmp_sda = '0') then -- Sensor sender ACK, ingen problemer oppstått
                                current_stage <= START2;
                            else -- NACK, feil oppstått.
                                i2c_error <= '1';
                                current_stage <= STOP;
                            end if;
                            
                            scl_low <= '1';  -- avslutt ACK-klokkeslaget
                            phase <= 0;
                        end if;
                    
                    
                    when START2 =>
                        if phase = 0 then
                            -- Gjør klart
                            scl_low <= '1'; -- SCL LOW
                            sda_low <= '0'; -- SDA HIGH
                            phase <= 1;
                    
                        elsif phase = 1 then
                            scl_low <= '0'; -- SCL HIGH
                            phase <= 2;
                    
                        elsif phase = 2 then
                            sda_low <= '1'; -- SDA HIGH -> LOW
                            phase <= 3;
                    
                        elsif phase = 3 then
                            scl_low <= '1';
                    
                            adr <= "10010111"; -- adresse + READ
                            bit_counter <= 7;
                    
                            phase <= 0;
                            current_stage <= ADDRESS2;
                        end if;
                        
                    
                    when ADDRESS2 =>
                        if (phase=0) then
                            scl_low <= '1'; -- Trekk ned klokken
                            phase <= 1;
                            if (adr(bit_counter) = '1') then
                                sda_low <= '0'; -- Hvis bit posisjonen er 1, ikke trekk ned linjen
                            else
                                sda_low <= '1'; -- Hvis bit er 0, trekk ned linjen
                            end if;
                        elsif (phase=1) then
                            scl_low <= '0';
                            if (bit_counter=0) then
                                phase <= 0;
                                current_stage <= ACK_ADDRESS2;
                            else 
                                bit_counter <= bit_counter-1; 
                                phase <= 0;
                            end if;
                        end if;
                        
                        
                    when ACK_ADDRESS2 =>
                        if (phase=0) then
                            scl_low <= '1'; -- Klokke lav
                            sda_low <= '0'; -- Slipp SDA
                            phase <= 1;
                        elsif(phase=1) then
                            scl_low <= '0'; -- la en i2c syklus gå
                            phase <= 2;
                        elsif(phase=2) then
                            -- SCL settes høy av sensoren
                            if (tmp_sda = '0') then -- Sensor sender ACK, ingen problemer oppstått
                                current_stage <= DATAFRAME1;
                                bit_counter <= 7;
                            else -- NACK, feil oppstått.
                                i2c_error <= '1';
                                current_stage <= STOP;
                            end if;
                            scl_low <= '1';  -- avslutt ACK-klokkeslaget
                            phase <= 0;
                        end if;
                        
                        
                    when DATAFRAME1 =>
                        if phase=0 then
                            scl_low <= '0';
                            sda_low <= '0';
                            phase <= 1;
                        elsif phase=1 then
                            scl_low <= '1';
                            temp_temp(bit_counter + 8) <= tmp_sda;

                            if bit_counter=0 then
                                phase <= 0;
                                current_stage <= ACK_DATA1;
                                bit_counter <= 7;
                            else
                                phase <= 0;
                                bit_counter <= bit_counter - 1;
                            end if;
                        end if;
                        
                    when ACK_DATA1 =>
                        if phase = 0 then
                            -- Gjør ACK-biten klar mens SCL er lav
                            scl_low <= '1';
                            sda_low <= '1';   -- ACK = 0
                            phase <= 1;
                    
                        elsif phase = 1 then
                            -- SCL høy: sensoren leser ACK
                            scl_low <= '0';
                            phase <= 2;
                    
                        elsif phase = 2 then
                            -- Avslutt ACK og slipp SDA
                            scl_low <= '1';
                            sda_low <= '0';
                    
                            phase <= 0;
                            current_stage <= DATAFRAME2;
                        end if;
                        
                    when DATAFRAME2 =>
                        if phase=0 then
                            scl_low <= '0';
                            sda_low <= '0';
                            phase <= 1;
                        elsif phase=1 then
                            scl_low <= '1';
                            temp_temp(bit_counter) <= tmp_sda;

                            if bit_counter=0 then
                                phase <= 0;
                                current_stage <= NACK_DATA2;
                                bit_counter <= 7;
                            else
                                phase <= 0;
                                bit_counter <= bit_counter - 1;
                            end if;
                        end if;
                        
                        
                    when NACK_DATA2 =>
                        if phase = 0 then
                            scl_low <= '1';
                            sda_low <= '0'; -- slipp SDA = NACK 1
                            phase <= 1;
                    
                        elsif phase = 1 then
                            scl_low <= '0'; -- SCL HIGH
                            phase <= 2;
                    
                        elsif phase = 2 then
                            scl_low <= '1';
                            phase <= 0;
                            current_stage <= STOP;
                        end if;
                        
                        
                    when STOP =>
                        if phase = 0 then
                            scl_low <= '1'; -- SCL LOW
                            sda_low <= '1'; -- SDA LOW
                            phase <= 1;
                    
                        elsif phase = 1 then
                            scl_low <= '0'; -- SCL HIGH
                            phase <= 2;
                    
                        elsif phase = 2 then
                            sda_low <= '0'; -- SDA LOW -> HIGH = STOP
                    
                            temp_raw <= temp_temp;
                            data_valid <= '1';
                    
                            phase <= 0;
                            current_stage <= IDLE;
                        end if;
                    when others =>
                end case;
            else
                counter <= counter + 1;
            end if;
        end if; 
    end process;    
    
end architecture;