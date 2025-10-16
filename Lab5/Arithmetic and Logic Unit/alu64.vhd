library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu64 is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        a        : in  std_logic_vector(63 downto 0);
        b        : in  std_logic_vector(63 downto 0);
        opcode   : in  std_logic_vector(3 downto 0);
        result   : out std_logic_vector(63 downto 0);
        zero     : out std_logic;
        overflow : out std_logic;
        carryout : out std_logic
    );
end alu64;

architecture behavioral of alu64 is

    signal comb_result    : std_logic_vector(63 downto 0);
    signal comb_overflow  : std_logic;
    signal comb_carry     : std_logic;

    signal reg_result     : std_logic_vector(63 downto 0);
    signal reg_zero       : std_logic;
    signal reg_overflow   : std_logic;
    signal reg_carryout   : std_logic;

    -- función comprobación cero (segura)
    function is_zero_vec(s: std_logic_vector) return boolean is
    begin
        for i in s'range loop
            if s(i) = '1' then
                return false;
            end if;
        end loop;
        return true;
    end function;

    -- rotate left: usa índices relativos seguros (soporta cualquier rango)
    function rotl64(s : std_logic_vector; n : integer) return std_logic_vector is
        variable res : std_logic_vector(s'range) := (others => '0');
        constant len : integer := s'length;
        variable k   : integer := n mod len;
        variable src_idx, dst_idx : integer;
        variable base : integer := s'low;
    begin
        for p in 0 to len-1 loop
            dst_idx := base + p;
            src_idx := base + ((p - k + len) mod len);
            res(dst_idx) := s(src_idx);
        end loop;
        return res;
    end function;

    function rotr64(s : std_logic_vector; n : integer) return std_logic_vector is
    begin
        return rotl64(s, s'length - (n mod s'length));
    end function;

    -- logical left (SLL) - seguro para cualquier rango
    function sll64(s : std_logic_vector; n : integer) return std_logic_vector is
        variable res : std_logic_vector(s'range) := (others => '0');
        constant len : integer := s'length;
        variable k : integer := n;
        variable base : integer := s'low;
        variable p : integer;
    begin
        if k >= len then
            return res;
        else
            for p in k to len-1 loop
                res(base + p) := s(base + p - k);
            end loop;
            return res;
        end if;
    end function;

    -- logical right (SRL)
    function srl64(s : std_logic_vector; n : integer) return std_logic_vector is
        variable res : std_logic_vector(s'range) := (others => '0');
        constant len : integer := s'length;
        variable k : integer := n;
        variable base : integer := s'low;
        variable p : integer;
    begin
        if k >= len then
            return res;
        else
            for p in 0 to len-1-k loop
                res(base + p) := s(base + p + k);
            end loop;
            return res;
        end if;
    end function;

    -- arithmetic right (SRA) con sign-extend
    function sra64(s : std_logic_vector; n : integer) return std_logic_vector is
        variable res : std_logic_vector(s'range) := (others => '0');
        constant len : integer := s'length;
        variable k : integer := n;
        variable signbit : std_logic := s(s'high);
        variable base : integer := s'low;
        variable p : integer;
    begin
        if k >= len then
            if signbit = '1' then
                for p in res'range loop
                    res(p) := '1';
                end loop;
            end if;
            return res;
        else
            for p in len-1 downto len-k loop
                res(base + p) := signbit;
            end loop;
            for p in 0 to len-1-k loop
                res(base + p) := s(base + p + k);
            end loop;
            return res;
        end if;
    end function;

begin

    comb_proc: process(a, b, opcode)
        variable ua    : unsigned(a'range);
        variable ub    : unsigned(b'range);
        variable sa    : signed(a'range);
        variable sb    : signed(b'range);
        variable sum65 : unsigned(64 downto 0);
        variable prod128 : unsigned(127 downto 0);
        variable tmp_result : std_logic_vector(63 downto 0);
        variable ofl : std_logic := '0';
        variable coutv : std_logic := '0';
        variable shamt : integer;
        variable tmp_signed : signed(63 downto 0);
        variable upper_nonzero : boolean;
        variable i : integer;
    begin
        ua := unsigned(a);
        ub := unsigned(b);
        sa := signed(a);
        sb := signed(b);

        tmp_result := (others => '0');
        ofl := '0';
        coutv := '0';
        shamt := to_integer(unsigned(b(5 downto 0))); -- 0..63

        case opcode is
            when "0000" => -- ADD
                sum65 := ('0' & ua) + ('0' & ub);
                tmp_result := std_logic_vector(sum65(63 downto 0));
                coutv := sum65(64);
                tmp_signed := signed(tmp_result);
                if sa(sa'high) = sb(sb'high) then
                    if tmp_signed(tmp_signed'high) /= sa(sa'high) then
                        ofl := '1';
                    else
                        ofl := '0';
                    end if;
                else
                    ofl := '0';
                end if;

            when "0001" => -- SUB
                sum65 := ('0' & ua) - ('0' & ub);
                tmp_result := std_logic_vector(sum65(63 downto 0));
                coutv := sum65(64);
                tmp_signed := signed(tmp_result);
                if sa(sa'high) /= sb(sb'high) then
                    if tmp_signed(tmp_signed'high) /= sa(sa'high) then
                        ofl := '1';
                    else
                        ofl := '0';
                    end if;
                else
                    ofl := '0';
                end if;

            when "0010" => -- AND
                tmp_result := std_logic_vector(ua and ub);
                ofl := '0'; coutv := '0';

            when "0011" => -- OR
                tmp_result := std_logic_vector(ua or ub);
                ofl := '0'; coutv := '0';

            when "0100" => -- XOR
                tmp_result := std_logic_vector(ua xor ub);
                ofl := '0'; coutv := '0';

            when "0101" => -- NOT A
                tmp_result := not a;
                ofl := '0'; coutv := '0';

            when "0110" => -- NAND
                tmp_result := not std_logic_vector(ua and ub);
                ofl := '0'; coutv := '0';

            when "0111" => -- NOR
                tmp_result := not std_logic_vector(ua or ub);
                ofl := '0'; coutv := '0';

            when "1000" => -- XNOR
                tmp_result := not std_logic_vector(ua xor ub);
                ofl := '0'; coutv := '0';

            when "1001" => -- SLL
                tmp_result := sll64(a, shamt);
                ofl := '0'; coutv := '0';

            when "1010" => -- SRL
                tmp_result := srl64(a, shamt);
                ofl := '0'; coutv := '0';

            when "1011" => -- SRA
                tmp_result := sra64(a, shamt);
                ofl := '0'; coutv := '0';

            when "1100" => -- ROTL
                tmp_result := rotl64(a, shamt);
                ofl := '0'; coutv := '0';

            when "1101" => -- ROTR
                tmp_result := rotr64(a, shamt);
                ofl := '0'; coutv := '0';

            when "1110" => -- MUL unsigned (lower 64)
                prod128 := ua * ub;
                tmp_result := std_logic_vector(prod128(63 downto 0));
                upper_nonzero := false;
                for i in 127 downto 64 loop
                    if prod128(i) = '1' then
                        upper_nonzero := true;
                        exit;
                    end if;
                end loop;
                -- reemplazo seguro: usar if/then en lugar de la expresión condicional
                if upper_nonzero then
                    ofl := '1';
                else
                    ofl := '0';
                end if;
                coutv := '0';

            when others => -- PASS B
                tmp_result := b;
                ofl := '0'; coutv := '0';
        end case;

        comb_result   <= tmp_result;
        comb_overflow <= ofl;
        comb_carry    <= coutv;
    end process comb_proc;

    -- outputs registered (síncrono con rst)
    sync_proc: process(clk, rst)
    begin
        if rst = '1' then
            reg_result   <= (others => '0');
            reg_zero     <= '1';
            reg_overflow <= '0';
            reg_carryout <= '0';
        elsif rising_edge(clk) then
            reg_result   <= comb_result;
            if is_zero_vec(comb_result) then
                reg_zero <= '1';
            else
                reg_zero <= '0';
            end if;
            reg_overflow <= comb_overflow;
            reg_carryout <= comb_carry;
        end if;
    end process sync_proc;

    -- map outputs
    result   <= reg_result;
    zero     <= reg_zero;
    overflow <= reg_overflow;
    carryout <= reg_carryout;

end behavioral;

