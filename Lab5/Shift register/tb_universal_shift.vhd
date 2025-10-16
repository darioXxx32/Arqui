library ieee;                                -- importar librerías estándar
use ieee.std_logic_1164.all;                 -- tipos lógicos
use ieee.numeric_std.all;                    -- operaciones numéricas útiles (si se requieren)

entity tb_universal_shift is                  -- entidad del testbench (vacía: no tiene puertos)
end tb_universal_shift;

architecture sim of tb_universal_shift is     -- inicio de la arquitectura del tb
    constant WIDTH : integer := 8;           -- constante local que define ancho de ensayo (coincide con el DUT)

    -- señales del testbench (fáciles de conectar al DUT)
    signal clk         : std_logic := '0';   -- señal de reloj inicializada en '0'
    signal rst         : std_logic := '0';   -- reset inicial '0' (luego el TB lo activa)
    signal mode        : std_logic_vector(1 downto 0) := "00"; -- modo inicial
    signal load        : std_logic := '0';   -- señal de carga inicial
    signal shift_en    : std_logic := '0';   -- señal de enable para shift
    signal serial_in   : std_logic := '0';   -- entrada serial para aplicar estímulos
    signal parallel_in : std_logic_vector(WIDTH-1 downto 0) := (others => '0'); -- entrada paralela
    signal serial_out  : std_logic;          -- salida serial del DUT (observada por TB)
    signal parallel_out: std_logic_vector(WIDTH-1 downto 0); -- salida paralela del DUT

    -- Función para convertir std_logic_vector a string (binario) para usar en report
    function slv_to_string(s : std_logic_vector) return string is
        variable res : string(1 to s'length); -- pre-define una cadena con la misma longitud que el vector
        variable pos : integer := 1;          -- índice para llenar la cadena desde 1..length
    begin
        for i in s'range loop                 -- recorre cada índice del vector (por ejemplo 7 downto 0)
            if s(i) = '1' then
                res(pos) := '1';             -- si el bit es '1' escribe '1' en la cadena
            elsif s(i) = '0' then
                res(pos) := '0';             -- si el bit es '0' escribe '0'
            elsif s(i) = 'Z' then
                res(pos) := 'Z';             -- si hi-impedancia, marca 'Z' (raro en este tb)
            else
                res(pos) := 'X';             -- cualquier otro (U, W, -) lo marcamos como 'X'
            end if;
            pos := pos + 1;                  -- avanza la posición en la cadena
        end loop;
        return res;                          -- devuelve la cadena con la representación binaria
    end function slv_to_string;              -- fin de la función de utilidad

begin
    -- Instancia del DUT (Device Under Test): conecta las señales del TB con el módulo universal_shift
    uut: entity work.universal_shift
        generic map ( WIDTH => WIDTH )       -- mapea el genérico del DUT al valor WIDTH del TB
        port map (
            clk => clk,
            rst => rst,
            mode => mode,
            load => load,
            shift_en => shift_en,
            serial_in => serial_in,
            parallel_in => parallel_in,
            serial_out => serial_out,
            parallel_out => parallel_out
        );

    -- Reloj (VHDL-93 compatible)
    clk_proc: process                        -- proceso que genera un reloj periódico
    begin
        loop
            clk <= '0';                      -- poner clk a '0'
            wait for 5 ns;                   -- mantener 5 ns (periodo de 10 ns total -> 100 MHz teórico)
            clk <= '1';                      -- poner clk a '1' (flanco de subida ocurre aquí)
            wait for 5 ns;                   -- mantener 5 ns
        end loop;                            -- repetir indefinidamente
    end process clk_proc;

    -- Estímulos (VHDL-93 compatible)
    tb_proc: process                         -- proceso principal del testbench que genera vectores de prueba
    begin
        -- Reset inicial
        rst <= '1'; wait for 20 ns;         -- activa reset por 20 ns (en flanco hará la limpieza)
        rst <= '0'; wait for 10 ns;         -- desactiva reset y espera para estabilizar

        -- PIPO: carga y lee paralelo
        mode <= "11";                        -- seleccionar modo PIPO (Parallel-In Parallel-Out)
        parallel_in <= "10100101";          -- asignar dato paralelo de prueba
        load <= '1';                         -- activar carga en el siguiente flanco
        wait for 10 ns;                      -- esperar un flanco (o más) para que capture
        load <= '0';                         -- desactivar carga
        wait for 10 ns;                      -- esperar otro flanco para observar salida estable
        report "PIPO parallel_out = " & slv_to_string(parallel_out);
                                             -- imprime en consola el contenido paralelo usando la función

        -- PISO: carga paralelo y luego desplaza para leer serial_out
        mode <= "10";                        -- seleccionar modo PISO (Parallel-In Serial-Out)
        parallel_in <= "01101110";          -- preparar dato que se cargará
        load <= '1';                         -- activar carga
        wait for 10 ns;                      -- esperar para que la captura ocurra en flanco
        load <= '0';                         -- desactivar carga
        shift_en <= '1';                     -- activar desplazamiento para empezar a sacar bits
        for i in 0 to WIDTH-1 loop           -- loop para leer tantos ciclos como ancho (8)
            wait for 10 ns;                  -- esperar un ciclo (flanco)
            report "PISO serial_out = " & std_logic'image(serial_out);
                                             -- reporta el bit serial_out en cada ciclo
        end loop;
        shift_en <= '0';                     -- desactivar desplazamiento cuando termine
        wait for 20 ns;                      -- esperar unos ciclos adicionales

        -- SIPO: enviar bits en serie (VHDL-93: usar if..then en el loop)
        mode <= "01";                        -- seleccionar modo SIPO
        shift_en <= '1';                     -- habilitar desplazamiento/recepción serial
        for i in 0 to WIDTH-1 loop           -- enviar WIDTH bits de prueba
            if (i mod 2 = 0) then
                serial_in <= '1';            -- en posiciones pares poner '1'
            else
                serial_in <= '0';            -- en posiciones impares poner '0'
            end if;
            wait for 10 ns;                  -- esperar un flanco para que el bit sea capturado
        end loop;
        shift_en <= '0';                     -- desactivar desplazamiento tras enviar
        wait for 20 ns;                      -- esperar para estabilizar
        report "SIPO parallel_out = " & slv_to_string(parallel_out);
                                             -- mostrar el vector paralelo resultante

        -- SISO: enviar serie y observar serial_out (VHDL-93 compatible)
        mode <= "00";                        -- seleccionar SISO
        shift_en <= '1';                     -- habilitar desplazamiento
        for i in 0 to WIDTH-1 loop           -- enviar secuencia de prueba
            if (i mod 3 = 0) then
                serial_in <= '1';            -- patrón cada 3 ciclos un '1'
            else
                serial_in <= '0';
            end if;
            wait for 10 ns;                  -- esperar un ciclo para observación
            report "SISO serial_out = " & std_logic'image(serial_out);
                                             -- reporta la salida serial en cada ciclo
        end loop;
        shift_en <= '0';                     -- deshabilitar shift

        report "FIN SIMULACION";             -- mensaje de finalización del testbench
        wait;                                -- detener el proceso para mantener la simulación viva
    end process tb_proc;

end sim;                                     -- fin de la arquitectura del testbench
