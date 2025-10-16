library ieee;
use ieee.std_logic_1164.all;

entity adder64 is
    port (
        a   : in  std_logic_vector(63 downto 0);
        b   : in  std_logic_vector(63 downto 0);
        cin : in  std_logic;                             -- carry-in global
        sum : out std_logic_vector(63 downto 0);
        cout: out std_logic
    );
end adder64;

architecture structural of adder64 is
    component adder16
        port (
            a   : in  std_logic_vector(15 downto 0);
            b   : in  std_logic_vector(15 downto 0);
            cin : in  std_logic;
            sum : out std_logic_vector(15 downto 0);
            cout: out std_logic
        );
    end component;

    signal c : std_logic_vector(4 downto 0); -- c(0)=cin, c(4)=cout
begin
    c(0) <= cin;

    -- Least significant 16 bits: bits 15 downto 0
    a0: adder16 port map (
        a    => a(15 downto 0),
        b    => b(15 downto 0),
        cin  => c(0),
        sum  => sum(15 downto 0),
        cout => c(1)
    );

    -- Next 16 bits: bits 31 downto 16
    a1: adder16 port map (
        a    => a(31 downto 16),
        b    => b(31 downto 16),
        cin  => c(1),
        sum  => sum(31 downto 16),
        cout => c(2)
    );

    -- Next 16 bits: bits 47 downto 32
    a2: adder16 port map (
        a    => a(47 downto 32),
        b    => b(47 downto 32),
        cin  => c(2),
        sum  => sum(47 downto 32),
        cout => c(3)
    );

    -- Most significant 16 bits: bits 63 downto 48
    a3: adder16 port map (
        a    => a(63 downto 48),
        b    => b(63 downto 48),
        cin  => c(3),
        sum  => sum(63 downto 48),
        cout => c(4)
    );

    cout <= c(4);
end structural;
