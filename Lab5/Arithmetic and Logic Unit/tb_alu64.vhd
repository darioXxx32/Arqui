library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_alu64 is
end tb_alu64;

architecture sim of tb_alu64 is
    constant CLK_PERIOD : time := 10 ns; -- 100 MHz

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal a_sig    : std_logic_vector(63 downto 0) := (others => '0');
    signal b_sig    : std_logic_vector(63 downto 0) := (others => '0');
    signal opcode   : std_logic_vector(3 downto 0) := (others => '0');
    signal result   : std_logic_vector(63 downto 0);
    signal zero     : std_logic;
    signal overflow : std_logic;
    signal carryout : std_logic;

    -- convierte vector a cadena binaria
    function slv_to_string(s : std_logic_vector) return string is
        variable res : string(1 to s'length);
        variable pos : integer := 1;
    begin
        for idx in s'range loop
            if s(idx) = '1' then
                res(pos) := '1';
            elsif s(idx) = '0' then
                res(pos) := '0';
            elsif s(idx) = 'Z' then
                res(pos) := 'Z';
            else
                res(pos) := 'X';
            end if;
            pos := pos + 1;
        end loop;
        return res;
    end function;

    -- convierte vector 64b a hex (16 chars)
    function slv_to_hex(s : std_logic_vector) return string is
        constant hexchars : string := "0123456789ABCDEF";
        variable res : string(1 to 16);
        variable u : unsigned(s'range);
        variable nibble : integer;
        variable i : integer;
    begin
        u := unsigned(s);
        for i in 0 to 15 loop
            nibble := to_integer(u((63 - i*4) downto (60 - i*4)));
            res(i+1) := hexchars(nibble + 1);
        end loop;
        return res;
    end function;

begin
    -- Instancia del DUT
    dut: entity work.alu64
        port map (
            clk      => clk,
            rst      => rst,
            a        => a_sig,
            b        => b_sig,
            opcode   => opcode,
            result   => result,
            zero     => zero,
            overflow => overflow,
            carryout => carryout
        );

    -- Generador de reloj
    clk_proc: process
    begin
        while true loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
    end process;

    -- Proceso de estímulos (sin sensibilidad; usamos waits)
    stim_proc: process
        variable expected_u   : unsigned(63 downto 0);
        variable expected128  : unsigned(127 downto 0);
    begin
        -- RESET: mantener activo durante 2 ciclos y luego liberar
        rst <= '1';
        wait for 2*CLK_PERIOD;
        rst <= '0';
        wait for 2*CLK_PERIOD;

        -- === TEST 1: ADD 0 + 0 ===
        opcode <= "0000"; -- ADD
        a_sig <= (others => '0');
        b_sig <= (others => '0');
        -- esperar que DUT capture (2 flancos para seguridad)
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        expected_u := unsigned(a_sig) + unsigned(b_sig);
        assert unsigned(result) = expected_u
            report "ADD TEST1 FAILED: expected= x" & slv_to_hex(std_logic_vector(expected_u))
                   & " got= x" & slv_to_hex(result) severity error;

        -- === TEST 2: SUB max - 0 ===
        opcode <= "0001"; -- SUB
        a_sig <= (others => '1');
        b_sig <= (others => '0');
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        expected_u := unsigned(a_sig) - unsigned(b_sig);
        assert unsigned(result) = expected_u
            report "SUB TEST FAILED: expected= x" & slv_to_hex(std_logic_vector(expected_u))
                   & " got= x" & slv_to_hex(result) severity error;

        -- === TEST 3: ADD max + 1 ===
        opcode <= "0000";
        a_sig <= (others => '1');
        b_sig <= (others => '0'); b_sig(0) <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        expected128 := unsigned(a_sig) + unsigned(b_sig);
        assert unsigned(result) = unsigned(expected128(63 downto 0))
            report "ADD MAX+1 RESULT INCORRECT: expected low64= x" &
                   slv_to_hex(std_logic_vector(expected128(63 downto 0))) &
                   " got= x" & slv_to_hex(result) severity error;
        report "ADD MAX+1 OVFLAG=" & std_logic'image(overflow) severity note;

        -- === LOGIC ops: AND/OR/XOR ===
        opcode <= "0010"; a_sig <= x"F0F0F0F0F0F0F0F0"; b_sig <= x"0FF00FF00FF00FF0";
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert result = std_logic_vector(unsigned(a_sig) and unsigned(b_sig))
            report "AND failed: got= x" & slv_to_hex(result) severity error;

        opcode <= "0011"; wait until rising_edge(clk); wait until rising_edge(clk);
        assert result = std_logic_vector(unsigned(a_sig) or unsigned(b_sig))
            report "OR failed: got= x" & slv_to_hex(result) severity error;

        opcode <= "0100"; wait until rising_edge(clk); wait until rising_edge(clk);
        assert result = std_logic_vector(unsigned(a_sig) xor unsigned(b_sig))
            report "XOR failed: got= x" & slv_to_hex(result) severity error;

        -- === SHIFTS: SLL / SRL / SRA ===
        a_sig <= x"00000000000000FF";
        b_sig <= (others => '0'); b_sig(5 downto 0) <= "000010"; -- shift = 2
        opcode <= "1001"; -- SLL
        wait until rising_edge(clk); wait until rising_edge(clk);
        assert result = std_logic_vector(shift_left(unsigned(a_sig), 2))
            report "SLL failed: expected= x" & slv_to_hex(std_logic_vector(shift_left(unsigned(a_sig),2))) &
                   " got= x" & slv_to_hex(result) severity error;

        opcode <= "1010"; wait until rising_edge(clk); wait until rising_edge(clk);
        assert result = std_logic_vector(shift_right(unsigned(a_sig), 2))
            report "SRL failed: got= x" & slv_to_hex(result) severity error;

        opcode <= "1011"; wait until rising_edge(clk); wait until rising_edge(clk);
        report "SRA sample: result (hex)= x" & slv_to_hex(result) severity note;

        -- === ROTL sample ===
        opcode <= "1100";
        b_sig <= (others => '0'); b_sig(5 downto 0) <= "000001"; -- rot by 1
        a_sig <= x"8000000000000001";
        wait until rising_edge(clk); wait until rising_edge(clk);
        report "ROTL sample: result (hex)= x" & slv_to_hex(result) severity note;

        -- === MUL ===
        opcode <= "1110";
        a_sig <= x"0000000000000002";
        b_sig <= x"0000000000000003";
        wait until rising_edge(clk); wait until rising_edge(clk);
        wait until rising_edge(clk);
        expected128 := unsigned(a_sig) * unsigned(b_sig);
        assert unsigned(result) = unsigned(expected128(63 downto 0))
            report "MUL failed: expected low64= x" & slv_to_hex(std_logic_vector(expected128(63 downto 0))) &
                   " got= x" & slv_to_hex(result) severity error;

        -- === PASS B ===
        opcode <= "1111";
        a_sig <= x"AAAAAAAAAAAAAAAA";
        b_sig <= x"5555555555555555";
        wait until rising_edge(clk); wait until rising_edge(clk);
        assert result = b_sig
            report "PASSB failed: expected= x" & slv_to_hex(b_sig) & " got= x" & slv_to_hex(result) severity error;

        report "tb_alu64: FINISHED (si no hay severity error, todos los tests pasaron)" severity note;
        wait;
    end process;

end sim;
