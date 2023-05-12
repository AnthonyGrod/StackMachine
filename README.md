# StackMachine
Stack machine assembly module which allows concurrent stack operations execution. Available operations:

\+ Take two values from the stack, calculate their sum, and push the result onto the stack.

\* Take two values from the stack, calculate their product, and push the result onto the stack.
- Negate the value on the top of the stack.

0 to 9 - Push the respective value (0 to 9) onto the stack.

n - Push the core number onto the stack.

B - Take a value from the stack. If the value on the top of the stack is not zero, treat the taken value as a two's complement number and shift operations by that many positions.

C - Take a value from the stack and discard it.

D - Duplicate the value on the top of the stack and push it onto the stack.

E - Swap the positions of the top two values on the stack.

G - Call the function uint64_t get_value(uint64_t n) implemented elsewhere in the C language and push the obtained value onto the stack.

P - Take a value from the stack (let's denote it as w) and call the function void put_value(uint64_t n, uint64_t w) implemented elsewhere in the C language.

S - Synchronize the cores, take a value from the stack, treat it as the core number m, wait for the S operation from core n with the core number taken from the stack, and swap the values on the top of the stacks of cores m and n.
