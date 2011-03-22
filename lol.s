## lol - low-level lisp

#  Milestone 1: <- we're here
#    - choose data representation, calling convention, etc
#    - use manually translated written assembly with tagged data
#    - check that it works
#  Milestone 2:
#    - write a simple compiler in scheme to output the target assembly (.s, assume gas)
#    - write a simple runtime entry to start and run it (without gc)
#    - run small programs 
#  Milestone 3:
#    - add a GC 
#  Milestone 4:
#    - add features required to compile the compiler 
#    - compile the compiler
#  Milestone 5: 
#    - output a basic elf header and object code instead of assembly
#  Milestone 6:
#    - ./lol < compile.lol > lol-new

## Milestone 1:
#
# Data representation etc
#  - assume 32-bit i386 (devel machine being i686)
#  - use a list-structured heap
#     + align heap to 8-byte boundary -> 3 spare tag bits per pointer \o/
#  - leave 1 tag bit for gc (which will likely be Deutsch-Schorr-Waiteish)
#  - descriptor bit allocation
#    [........] [........] [........] [.....ttg]  
#     '------------------------------------|'|'-->  1 gc bit, assume 0 during execution
#                                          | '--->  2 tag bits with immediateness/pointer info
#  - tag bit allocation                    '-----> 29 payload bits for pointer / immediate data 
#     + ...00g] -> payload is pointer to a pair (will use lists a lot)
#     + ...01g] -> payload is pointer to an object, the car of which holds type info (see below)
#     + ...10g] -> payload is a (signed) integer
#     + ...11g] -> payload is an immediate value with some encoding
#          '-----> 1 if immediate, 0 if pointer
#  - tagged objects
#     + car is a fixnum -> function, where the fixnum is a pointer to the (native) code
#     + others defined as needed (null, bool, etc (can be created by setting a bit in a fixnum))
#        o string = list of integers (chars/code points)
#        o symbol = likewise, but interned and different tag
#        o bignum = -||-
#        o vector = not applicable (could use complete binary trees?)
#  - register use and calling conventions
#     + use CPS
#     + push a register end marker to stack and keep only one frame (local variables) there
#     + keep env in a separate register (?)
#     + possibly also global env (?)
#     + multi-value returns using normal calls
#     + registers are preserved across calls (modulo moving fp etc)
#        o clobberer fixes if necessary (syscalls)

## syscalls @ /usr/include/asm/unistd_32.h

.comm heap,100,32 # 100 words, 50 cells
.comm toemit,4,4    # pointer to use for initial one-char writes (and end of heap)
.text

star: # preserve regs, emit a star (for debugging)
   pushl %eax
   pushl %ebx
   pushl %ecx
   pushl %edx
   movl $42, (toemit)      # *
   movl $4, %eax           # syscall num (write)
   movl $1, %ebx           # fd
   movl $toemit, %ecx      # buf
   movl $1, %edx           # count
   int $0x80               # make syscall
   popl %ecx
   popl %edx
   popl %ebx
   popl %eax
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

init_freelist: # chain freelist to %esi
   movl $heap, %esi    # pos
   movl $50, %ecx      # counter, 50 cells in 100 words
nextlist:
   cmpl $0, %ecx     # maybe stop
   je donelist
   call star
   movl %esi, %eax     # set pos+2words to cdr
   addl $8, %eax
   movl %eax, 4(%esi)
   movl %eax, %esi
   subl $1, %ecx
   jmp nextlist
donelist:
   movl $heap, %esi
   ret

.globl _start
_start:
   call init_freelist
   pushl $42
   call halt

