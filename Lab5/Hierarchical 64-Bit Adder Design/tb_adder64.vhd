
library ieee;                                -- librería estándar IEEE (tipos comunes)
use ieee.std_logic_1164.all;                 -- paquete para std_logic, std_logic_vector, etc.
use ieee.numeric_std.all;                    -- paquete para tipos aritméticos (unsigned, signed)

-- entidad del testbench (vacía porque es solo un banco de pruebas)
entity tb_adder64 is
end tb_adder64;

-- arquitectura del testbench
architecture sim of tb_adder64 is

    -- señales que conectarán al DUT (device under test, adder64)
    signal a_sig   : std_logic_vector(63 downto 0) := (others => '0'); -- entrada A (64 bits), inicializada a 0
    signal b_sig   : std_logic_vector(63 downto 0) := (others => '0'); -- entrada B (64 bits), inicializada a 0
    signal cin_sig : std_logic := '0';                                  -- carry-in global (opcional), inicial '0'
    signal sum_sig : std_logic_vector(63 downto 0);                     -- salida suma del DUT (no inicializada)
    signal cout_sig: std_logic;                                         -- salida carry-out del DUT

    -- ---------------------------------------------------------------
    -- función auxiliar para convertir un std_logic_vector a string
    -- (esto facilita mostrar valores binarios en los 'report')
    -- recibe: s : std_logic_vector
    -- devuelve: string con '0'/'1'/'Z'/'X' por cada bit, en el mismo orden que s
    -- ---------------------------------------------------------------
    function slv_to_string(s : std_logic_vector) return string is
        -- res será la cadena devuelta; su tamaño es la longitud del vector
        variable res : string(1 to s'length);
        -- pos llevará la posición actual en la cadena (empezando en 1)
        variable pos : integer := 1;
    begin
        -- iteramos por el rango del vector s (puede ser downto)
        for i in s'range loop
            -- convertimos cada elemento std_logic a un carácter legible
            if s(i) = '1' then
                res(pos) := '1';
            elsif s(i) = '0' then
                res(pos) := '0';
            elsif s(i) = 'Z' then
                res(pos) := 'Z'; -- alta impedancia
            else
                res(pos) := 'X'; -- unknown / undefined / otros estados
            end if;
            pos := pos + 1; -- avanzamos la posición en la cadena
        end loop;
        return res; -- devolvemos la cadena resultante
    end function slv_to_string;

begin

    -- ===============================================================
    -- Instancia del DUT (Device Under Test): el sumador de 64 bits
    -- 'work.adder64' debe existir en el proyecto y ser la entidad a probar
    -- ===============================================================
    uut: entity work.adder64
        port map(
            a    => a_sig,    -- conectamos la señal a_sig al puerto 'a'
            b    => b_sig,    -- conectamos la señal b_sig al puerto 'b'
            cin  => cin_sig,  -- conectamos cin_sig al puerto 'cin' (si el DUT lo usa)
            sum  => sum_sig,  -- salida 'sum' del DUT -> sum_sig del testbench
            cout => cout_sig  -- salida 'cout' del DUT -> cout_sig del testbench
        );

    -- ===============================================================
    -- Proceso de estímulos (estimulación): aplica vectores de prueba
    -- Usamos un process sin sensibilidad (se controla con 'wait for')
    -- Dentro declaramos variables temporales para cálculos esperados
    -- ===============================================================
    stim_proc: process
        variable expected : unsigned(63 downto 0); -- variable para calcular el resultado esperado
    begin
        -- ------------------------
        -- TEST 1: 0 + 0
        -- ------------------------
        a_sig <= (others => '0');    -- ponemos A = 0
        b_sig <= (others => '0');    -- ponemos B = 0
        cin_sig <= '0';              -- carry in = 0
        wait for 20 ns;              -- esperamos 20 ns para que la lógica se asiente (registro/propagación)

        -- calculamos el valor esperado en 'expected' (usamos numeric_std: unsigned)
        if cin_sig = '1' then
            expected := unsigned(a_sig) + unsigned(b_sig) + 1; -- si hubiera cin=1 lo sumamos
        else
            expected := unsigned(a_sig) + unsigned(b_sig);     -- suma simple
        end if;

        -- mostramos por consola (report) el valor esperado y el obtenido
        report "TEST1: expected = " & slv_to_string(std_logic_vector(expected))
               & "  got = " & slv_to_string(sum_sig) severity note;

        -- comprobación automática: si la salida no coincide lanzamos assertion con severity error
        assert unsigned(sum_sig) = expected
            report "TEST1 FAILED: 0+0" severity error;

        -- ------------------------
        -- TEST 2: max + 0 (toda A en '1')
        -- ------------------------
        a_sig <= (others => '1');   -- A = 0xFFFFFFFFFFFFFFFF (todos 1)
        b_sig <= (others => '0');   -- B = 0
        cin_sig <= '0';             -- cin = 0
        wait for 20 ns;             -- esperamos para que la suma se calcule

        -- calculamos expected de nuevo (considerando cin si fuera 1)
        if cin_sig = '1' then
            expected := unsigned(a_sig) + unsigned(b_sig) + 1;
        else
            expected := unsigned(a_sig) + unsigned(b_sig);
        end if;

        -- mostramos y verificamos
        report "TEST2: expected = " & slv_to_string(std_logic_vector(expected))
               & "  got = " & slv_to_string(sum_sig) severity note;
        assert unsigned(sum_sig) = expected
            report "TEST2 FAILED: max+0" severity error;

        -- ------------------------
        -- TEST 3: max + 1 -> provoca overflow y carry out esperado
        -- ------------------------
        a_sig <= (others => '1');           -- A = all ones (max unsigned)
        b_sig <= (others => '0'); b_sig(0) <= '1'; -- B = 1 (se pone el bit0 en '1')
        cin_sig <= '0';                      -- cin = 0
        wait for 20 ns;                      -- esperar para que el DUT calcule

        -- cálculo esperado (si hubiera cin=1 lo consideraría)
        if cin_sig = '1' then
            expected := unsigned(a_sig) + unsigned(b_sig) + 1;
        else
            expected := unsigned(a_sig) + unsigned(b_sig);
        end if;

        -- mostramos expected y got
        report "TEST3: expected = " & slv_to_string(std_logic_vector(expected))
               & "  got = " & slv_to_string(sum_sig) severity note;

        -- assert: resultado de la suma de 64 bits (baja 64 bits) debe coincidir
        assert unsigned(sum_sig) = expected
            report "TEST3 FAILED: max+1 result incorrect" severity error;

        -- assert: en este caso, al sumar max + 1, el carry-out del bloque completo debería ser '1'
        assert cout_sig = '1'
            report "TEST3 FAILED: max+1 carry out expected = '1'" severity error;

        -- ------------------------
        -- TEST 4: Ripple carry across blocks (comportamiento interno)
        -- Ponemos lower 48 bits a 1 y sumamos 1 -> debería propagarse la onda de carry
        -- ------------------------
        a_sig <= x"0000FFFFFFFFFFFF"; -- ejemplo: bits inferiores a 1 (48 ones)
        b_sig <= x"0000000000000001"; -- sumamos 1 -> causa ripple en los bits bajos
        cin_sig <= '0';
        wait for 20 ns;

        if cin_sig = '1' then
            expected := unsigned(a_sig) + unsigned(b_sig) + 1;
        else
            expected := unsigned(a_sig) + unsigned(b_sig);
        end if;

        report "TEST4: expected = " & slv_to_string(std_logic_vector(expected))
               & "  got = " & slv_to_string(sum_sig) severity note;
        assert unsigned(sum_sig) = expected
            report "TEST4 FAILED: ripple test" severity error;

        -- ------------------------
        -- TEST 5: Comprobación con valores "random-ish" (ejemplo práctico)
        -- ------------------------
        a_sig <= x"1234567890ABCDEF"; -- valor hex
        b_sig <= x"0FEDCBA098765432"; -- otro valor hex
        cin_sig <= '0';
        wait for 20 ns;

        if cin_sig = '1' then
            expected := unsigned(a_sig) + unsigned(b_sig) + 1;
        else
            expected := unsigned(a_sig) + unsigned(b_sig);
        end if;

        report "TEST5: expected = " & slv_to_string(std_logic_vector(expected))
               & "  got = " & slv_to_string(sum_sig) severity note;
        assert unsigned(sum_sig) = expected
            report "TEST5 FAILED: random add" severity error;

        -- Si llegamos hasta aquí sin assertions con severity error -> pruebas pasaron
        report "Todos los tests pasaron (si no hubo assert con severity error)." severity note;

        wait; -- detenemos el proceso (mantener la simulación abierta)
    end process;

end sim;
