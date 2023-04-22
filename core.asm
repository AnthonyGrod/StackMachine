global core
extern get_value                             ; Requires one argument: uint64_t n. Returns value in rax. Can modify all scratch registers.
extern put_value                             ; Requires two arguments: uint64_t n, uint64_t w. Can modify all scratch registers.

section .data

align 8
values: times N dq N                         ; N-size array filled with N values at the beginning. It will help us with S operation because need 
                                             ; a place to store values to switch between two cores.
align 8
synchro: times N dq N                        ; N-size array filled with N values at the beginning. It will help us to synchronize S operation.

; rdi - uint64_t n. It's core's number.
; rsi - char const *p. It's operations string.
section .text

; core function reads operations in p and executes given orders. Modifies r8, r9, r10, rdx, rax, rsi. Returns value stored in rax.
core:
        push    r13
        push    r12                       
        mov     r12, rsp                     ; Moving rsp into r12 (perserved register) in order to retreive it at the end of the function.                  
        jmp     .read                        ; Jumping into label which reads an operation order character.

.check_if_digit:                             ; Checks if char loaded into dl register represents a digit. 
                                             ; If so, we translate it into digit by subtracting 0x30 and push onto the stack.
        cmp     dl, '0'                         
        jb      .check_if_ok_nondigit 
        cmp     dl, '9'
        ja      .check_if_ok_nondigit
        sub     dl, 0x30                     ; Translating char into actual digit.
        push    rdx                          ; Pushing that digit onto the stack as instruction demands.
        jmp     .read

.mult_order:
        pop     rdx
        pop     rax
        mul     rdx                          ; Performing multiplication rax = rdx * rax.
        push    rax                          ; Pushing multiplied value onto the stack.
        jmp     .read

.neg_order:
        neg     qword [rsp]                  ; Negating 64 bit value on the top of the stack.
        jmp     .read

.n_order:
        push    rdi                          ; Pushing value n onto the stack.
        jmp     .read

.B_order:
        pop     rdx
        cmp     qword [rsp], 0               ; Checking if current 64 bit stack top is equal to 0.
        jz      .read                        ; If so, we just read another operation order.
        add     rsi, rdx                     ; If not, we shift operation order pointer (rsi) by value rdx.
        jmp     .read

.check_if_ok_nondigit:                       ; In order to minimize the usage of cmp we perform a simple optimization. We arrange possible orders
                                             ; in descending ASCII order. cmp is done only on every other order. Then we know that if cmp yields 0
                                             ; then we found compared order, if cmp yields value more than 0 then we found order that is above compared
                                             ; order and since we have considered all greater orders besides that one, we jump to that order. In other case
                                             ; our order must have lower ASCII size and we move on.
        cmp     dl, 'S'
        jz      .S_order
        ja      .n_order

        cmp     dl, 'G'
        jz      .G_order
        ja      .P_order

        cmp     dl, 'D'
        jz      .D_order
        ja      .E_order

        cmp     dl, 'B'
        jz      .B_order
        ja      .C_order
         
        cmp     dl, '+'
        jb      .mult_order
        ja      .neg_order

.add_order:                                  ; If zero flag has not been raised in last comparison, we just directly go to .add_order.
                                             ; .add_order adds two values on top of the stack together. We can just pop the top value and
                                             ; add it directly to the top of the stack.
        pop     rdx
        add     qword [rsp], rdx             ; Adding popped above value to the value on top of the stack.
        jmp     .read

.C_order:                                    ; .C_order removes a value from the top of the stack
        pop     rdx
        jmp     .read

.D_order:                                    ; .D_order duplicates value on the top of the stack.
        mov     rdx, qword [rsp]             
        push    rdx

.read:                                       ; We will read next order character into dl.
        movzx   rdx, byte [rsi]              ; Moving next order character to dl and zeroing potential garbage value in rdx.
        test    dl, dl                       ; Testing if we encountered null terminating character.
        jz      .end                         ; If so, the core has ended it's work.
        inc     rsi                          ; Increasing our iterator over order string.
        jmp     .check_if_digit              ; We jump to label which checks what order it has been given. 

.end:
        pop     rax                          ; Return value will be the value from the top of the stack.
        mov     rsp, r12                     ; Restoring stack pointer from the beginning.
        pop     r12                          ; Restoring r12 value from the beginning.
        pop     r13                          ; Restoring r12 value from the beginning.
        ret                                  ; Returning value stored in rax.

.E_order:                                    ; .E_order switches two 64 bit values from the top of the stack.
        pop     rdx
        pop     rax
        push    rdx                          ; Pushing rdx and rax in reverse order than they were at the beginning of the function.
        push    rax
        jmp     .read

.G_order:
	push	rdi                          ; Pushing rdi and rsi cause we could loose these values in case get_value changed these registers.
        push    rsi
	mov	r13, rsp                     ; Moving rsp value into r13 so we can return to current stack frame after get_value execution.
	and	rsp, ~0xF                    ; Making sure that rsp value is divisible by 16 (we zero 4 least significant bits).
	call	get_value
	mov	rsp, r13                     ; Restoring values of r13, rsi and rdi.
        pop     rsi
	pop	rdi
	push	rax                          ; Pushing get_value return value onto the stack.
        jmp     .read

.P_order:
        pop     rdx                          ; rdx = uint64_t w.
        push	rdi                          ; Pushing rdi and rsi cause we could loose these values in case get_value changed these registers.
        push    rsi
        mov     rsi, rdx                     ; Second argument of put_value function = w.
	mov	r13, rsp                     ; Moving rsp value into r13 so we can return to current stack frame after get_value execution.
	and	rsp, ~0xF                    ; Making sure that rsp value is divisible by 16 (we zero 4 least significant bits).
	call	put_value
	mov	rsp, r13                     ; Restoring values of r13, rsi and rdi.
        pop     rsi
	pop	rdi
        jmp     .read

.S_order:
        pop     rax                          ; rax = top(s), pop(s).
        lea     r8, [rel values]             ; r8 = values.
        pop     qword [r8+rdi*8]             ; values[n] = top(s), pop(s).
        lea     r9, [rel synchro]            ; r9 = synchro.
        mov     qword [r9+rdi*8], rax        ; synchro[n] = rax.
        mov     r10, N                       ; r10 = N.

.spin_lock_raxn:
        cmp     qword [r9+rax*8], rdi        ; while (synchro[rax] != n){}.
        jnz     .spin_lock_raxn

.S_order_continue:
        push    qword [r8+rax*8]             ; push(values[rax]).
        mov     qword [r9+rax*8], r10        ; synchro[rax] = N.

.spin_lock_nN:
        cmp     qword [r9+rdi*8], r10        ; while (synchro[n] != N){}.
        jnz     .spin_lock_nN

.S_order_end:
        jmp     .read
