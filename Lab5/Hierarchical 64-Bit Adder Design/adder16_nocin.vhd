library ieee;
use ieee.std_logic_1164.all;

entity adder16_nocin is
    port (
        a   : in  std_logic_vector(15 downto 0);
        b   : in  std_logic_vector(15 downto 0);
        sum : out std_logic_vector(15 downto 0);
        cout: out std_logic
    );
end adder16_nocin;

architecture structural of adder16_nocin is
    component half_adder
        port (
            a    : in  std_logic;
            b    : in  std_logic;
            sum  : out std_logic;
            carry: out std_logic
        );
    end component;

    component full_adder
        port (
            a    : in  std_logic;
            b    : in  std_logic;
            cin  : in  std_logic;
            sum  : out std_logic;
            cout : out std_logic
        );
    end component;

    signal c : std_logic_vector(16 downto 0);
begin
    -- LSB: use half-adder, no carry-in assumed
    ha0: half_adder port map (
        a     => a(0),
        b     => b(0),
        sum   => sum(0),
        carry => c(1)
    );

    -- bits 1..15 use full adders, carry chain from c(1) .. c(16)
    gen_full: for i in 1 to 15 generate
        fa_inst: full_adder
            port map (
                a    => a(i),
                b    => b(i),
                cin  => c(i),
                sum  => sum(i),
                cout => c(i+1)
            );
    end generate gen_full;

    cout <= c(16);
end structural;
