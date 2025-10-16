library ieee;
use ieee.std_logic_1164.all;

-- Full adder: suma con carry-in y carry-out
entity full_adder is
    port (
        a    : in  std_logic;
        b    : in  std_logic;
        cin  : in  std_logic;
        sum  : out std_logic;
        cout : out std_logic
    );
end full_adder;

architecture behavioral of full_adder is
begin
    -- sum = a XOR b XOR cin
    sum <= a xor b xor cin;
    -- cout = majority(a,b,cin) = (a and b) or (a and cin) or (b and cin)
    cout <= (a and b) or (a and cin) or (b and cin);
end behavioral;
