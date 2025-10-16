-- Universal shift register (paramétrico)
-- Soporta: SISO, SIPO, PISO, PIPO
-- Codificación de mode (2 bits):
-- "00" = SISO  (Serial-In Serial-Out)
-- "01" = SIPO  (Serial-In Parallel-Out)
-- "10" = PISO  (Parallel-In Serial-Out)
-- "11" = PIPO  (Parallel-In Parallel-Out)

library ieee;                                   -- importa la librería IEEE estándar
use ieee.std_logic_1164.all;                    -- incluye tipos lógicos: std_logic, std_logic_vector
use ieee.numeric_std.all;                       -- incluye tipos y operaciones aritméticas (unsigned, signed)

entity universal_shift is                       -- inicio de la entidad: definición externa del módulo
    generic (
        WIDTH : integer := 8  -- ancho del registro (parámetro)
    );                                            -- permite parametrizar el ancho del registro
    port (                                       -- lista de puertos (entradas/salidas)
        clk        : in  std_logic;             -- reloj (flanco de subida usado para muestrear)
        rst        : in  std_logic;             -- reset síncrono activo '1' (limpia el registro en el flanco)
        mode       : in  std_logic_vector(1 downto 0); -- modo de operación (2 bits)
        load       : in  std_logic;             -- señal para cargar paralelo (Parallel-In) en el flanco
        shift_en   : in  std_logic;             -- habilita el desplazamiento (si '1' se desplaza)
        serial_in  : in  std_logic;             -- entrada serial (para SISO/SIPO)
        parallel_in: in  std_logic_vector(WIDTH-1 downto 0); -- entradas paralelas (para PISO/PIPO)
        serial_out : out std_logic;             -- salida serial (por donde sale MSB en desplazamiento izquierdo)
        parallel_out: out std_logic_vector(WIDTH-1 downto 0) -- salidas paralelas (refleja el registro)
    );
end universal_shift;                            -- fin de la entidad

architecture behavioral of universal_shift is  -- inicio de la arquitectura (implementación)
    -- registro interno que almacena los bits
    signal reg_shift : std_logic_vector(WIDTH-1 downto 0); -- señal interna que guarda el estado del registro
begin

    -- proceso síncrono principal: carga y desplazamiento
    process(clk)                                -- proceso sensible al reloj (solo se evalúa en flancos)
    begin
        if rising_edge(clk) then                -- acción a realizar en flanco ascendente del reloj
            if rst = '1' then                  -- si reset activo ('1') en este flanco...
                -- reset síncrono: limpia el registro
                reg_shift <= (others => '0');  -- pone todos los bits del registro a '0'
            else
                -- prioridad: si load='1' hacemos carga paralela (captura)
                if load = '1' then
                    -- Cargar las entradas paralelas en el registro
                    reg_shift <= parallel_in; -- copia parallel_in en el registro en el flanco
                else
                    -- Si shift_en='1' ejecutamos desplazamiento según modo
                    if shift_en = '1' then
                        case mode is           -- seleccionamos la operación según el modo
                            when "00" =>  -- SISO: entrada serial, salida serial
                                -- Desplazamos hacia la izquierda.
                                -- LSB recibe serial_in; MSB será el bit que sale por serial_out.
                                reg_shift <= reg_shift(WIDTH-2 downto 0) & serial_in;
                                -- toma todos los bits menos el MSB (0..W-2) y concatena serial_in en LSB

                            when "01" =>  -- SIPO: entrada serial, salida paralela
                                -- Igual que SISO: vamos desplazando en serie; el vector paralelo
                                -- se podrá leer desde parallel_out.
                                reg_shift <= reg_shift(WIDTH-2 downto 0) & serial_in;
                                -- idéntico a SISO: construye el registro desplazando e insertando serial_in

                            when "10" =>  -- PISO: carga paralela (antes) y luego envío serial
                                -- En PISO normalmente primero se hace load='1', y luego con shift_en='1'
                                -- vamos desplazando hacia la izquierda sacando MSB por serial_out.
                                reg_shift <= reg_shift(WIDTH-2 downto 0) & '0'; -- empuja un '0' en LSB
                                -- Nota: serial_in no se usa para PISO al desplazar (aquí definimos '0')
                                -- así el MSB previo será el que aparezca en serial_out al desplazar

                            when others => -- "11" PIPO: Parallel-In Parallel-Out
                                -- Para PIPO no necesitamos desplazar: si no hay load, el registro retiene su valor.
                                reg_shift <= reg_shift; -- redundante, deja el valor sin cambios
                                -- La asignación es redundante pero expresa la intención: no hacer shift
                        end case;             -- fin case
                    end if; -- shift_en      -- fin if shift_en = '1'
                end if; -- load           -- fin if load = '1'
            end if; -- rst                -- fin if rst = '1'
        end if; -- rising_edge           -- fin if rising_edge(clk)
    end process;                             -- fin del proceso síncrono

    -- Salidas:
    -- serial_out será el bit más significativo (MSB) del registro (bit que sale al desplazar izquierda)
    serial_out <= reg_shift(WIDTH-1);        -- conecta MSB del registro a la salida serial

    -- Salida paralela: siempre reflejamos el contenido del registro
    parallel_out <= reg_shift;               -- salida paralela refleja todo el registro

end behavioral;                              -- fin de la arquitectura
