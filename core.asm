global core
extern get_value
extern put_value

section .data

values: times N dq N                  ; N-size array filled with N values at the beginning. It will help us with S operation because need 
                                      ; a place to store values to switch between two cores.
synchro: times N dq N                 ; N-size array filled with N values at the beginning. It will help us with S operation because

; rdi - uint64_t n
; rsi - char const *p
section .text

core:
         push    r13
         push    r12
         mov     r12, rsp 
         xor     rcx, rcx

.read:                                ; We will read next command into dx (rdx). rcx will be an iterator over p array.
         xor     rdx, rdx             ; Clearing potential garbage value in rdx.
         movzx   edx, byte [rsi + rcx]  ; Moving p[rcx] character to dl.
         test    dl, dl               ; Testing if we encountered null terminating character.
         jz      .end                 ; If so, the core has ended it's work.
         inc     rcx                  ; Increasing our iterator.

.check_if_digit:                        ; Checks if char loaded into dl register represents a digit. 
                                        ; If so, we translate it into digit by subtracting 0x30 and push onto the stack.
         cmp     dl, '0'                         
         jb      .check_if_ok_nondigit 
         cmp     dl, '9'
         ja      .check_if_ok_nondigit
         sub     dl, 0x30                        ; Translating char into actual digit.
         push    rdx                             ; Pushing that digit onto the stack as instruction demands.
         jmp     .read

.check_if_ok_nondigit:
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

.add_order:
         pop     rdx                             ; Poping value from the top of the stack into rdx.
         add     qword [rsp], rdx                ; Adding that value to the value on top of the stack.
         jmp     .read

.mult_order:
         pop     rdx                             ; Poping value from the top of the stack into rdx.
         pop     rax                             ; Poping value from the top of the stack into rax.
         mul     rdx                             ; Performing multiplication rax = rdx * rax.
         push    rax                             ; Pushing multiplies value onto the stack.
         jmp     .read

.neg_order:
         neg     qword [rsp]
         jmp     .read

.n_order:
         push    rdi
         jmp     .read

.B_order:
         pop     rdx
         cmp     qword [rsp], 0
         jz      .read
         add     rsi, rdx
         jmp     .read

.C_order:
         pop     rdx
         jmp     .read

.D_order:
         mov     rdx, qword [rsp]
         push    rdx
         jmp     .read

.E_order:
         pop     rdx
         pop     rax
         push    rdx
         push    rax
         jmp     .read

.G_order:
	       push	   rdi
         push    rcx
         push    rsi
	       mov	   r13, rsp
	       and	   rsp, ~0xF
	       call	   get_value
	       mov	   rsp, r13
         pop     rsi
         pop     rcx
	       pop	   rdi
	       push	   rax
         jmp     .read

.P_order:
         pop     rdx                             ; Zdejmujemy uint64_t w.
         push	   rdi
         push    rcx
         push    rsi
         mov     rsi, rdx                        ; Zapisujemy je jako drugi argument.
	       mov	   r13, rsp
	       and	   rsp, ~0xF
	       call	   put_value
	       mov	   rsp, r13
         pop     rsi
         pop     rcx
	       pop	   rdi
         jmp     .read

.S_order:
         pop     rax                          ; m = rax = top(s), pop(s).
         lea     r8, [rel values]             ; r8 = values.
         pop     qword [r8+rdi*8]             ; values[n] = top(s), pop(s).
         lea     r9, [rel synchro]            ; r9 = synchro.
         mov     qword [r9+rdi*8], rax        ; synchro[n] = m.

.spin_lock_mn:
         ;mov     r10, qword [r9+rax*8]
         cmp     qword [r9+rax*8], rdi        ; while (synchro[m] != n).
         jnz     .spin_lock_mn

.S_order_continue:
         push    qword [r8+rax*8]             ; top(s) = values[m].
         mov     qword [r9+rax*8], N          ; synchro[m] = N.

.spin_lock_nN:
         ;mov     r10, qword [r9+rdi*8]
         cmp     qword [r9+rdi*8], N          ; while (synchro[n] != N).
         jnz     .spin_lock_nN

.S_order_end:
         jmp     .read

.end:
         pop     rax
         mov     rsp, r12
         pop     r12
         pop     r13
         ret
