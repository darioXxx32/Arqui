library ieee;
use ieee.std_logic_1164.all;

-- Half adder: suma y carry
entity half_adder is
    port (
        a    : in  std_logic;
        b    : in  std_logic;
        sum  : out std_logic;
        carry: out std_logic
    );
end half_adder;

architecture behavioral of half_adder is
begin
    -- sum = a XOR b
    sum   <= a xor b;
    -- carry = a AND b
    carry <= a and b;
end behavioral;
