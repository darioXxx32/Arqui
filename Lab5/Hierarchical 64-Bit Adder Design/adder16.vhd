library ieee;
use ieee.std_logic_1164.all;

entity adder16 is
    port (
        a   : in  std_logic_vector(15 downto 0);
        b   : in  std_logic_vector(15 downto 0);
        cin : in  std_logic;                              -- carry in
        sum : out std_logic_vector(15 downto 0);
        cout: out std_logic                               -- carry out
    );
end adder16;

architecture structural of adder16 is
    -- component declaration
    component full_adder
        port (
            a    : in  std_logic;
            b    : in  std_logic;
            cin  : in  std_logic;
            sum  : out std_logic;
            cout : out std_logic
        );
    end component;

    -- internal carries: c(0)=cin, c(16)=cout
    signal c : std_logic_vector(16 downto 0);
begin
    c(0) <= cin;

    gen_full: for i in 0 to 15 generate
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
