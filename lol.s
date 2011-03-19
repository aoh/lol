## some quick tests

## syscalls @ /usr/include/asm/unistd_32.h

.comm toemit,4,4    # pointer to use for initial one-char writes
.comm heap,10000,32 # 10000 words 
.text

emit: # byte cont → cont val
   movl $42, (toemit)           # assuming little endian machine here
   movl $4, %eax           # syscall num (write)
   movl $1, %ebx           # fd
   movl $toemit, %ecx      # buf
   movl $1, %edx           # count
   int $0x80               # make syscall
   ret

nudder: # r n .. → 42 .., O(n)
   cmpl $0, 4(%esp)
   je nudder_out
   subl $1, 4(%esp)
   jmp nudder
nudder_out:
   movl $42, 4(%esp)
   ret

adder: # r a b → n 
   movl 4(%esp), %eax 
   movl 8(%esp), %ebx 
   addl %ebx, %eax
   movl %eax, 8(%esp) # save result
   ret $4 # pop 1 arg

halt: # r a → 
   movl $1, %eax       # syscall to perform (exit)
   movl 4(%esp), %ebx  # return value
   int $0x80           # exit

.globl _start
_start:
   pushl $10000000
   call nudder
   call halt

