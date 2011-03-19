## lol - low-level lisp

#  Milestone 1: 
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
#  - bootup:
#     + symbol interning will probably require some hackery
#        o construct all in-heap values after startup?
#        o have a builtin preloaded heap?
#  - register use and calling conventions
#     + use the native stack for parameter passing
#        o probably push a marker to denote end of stack
#        o have gc check that all roots in stack (values sans immediate bit) are in heap-range
#           * for return addresses looking like pointers they will be above or below
#     + each function call pushes the object (usually closure) implicitly to stack below the arguments
#        o when the code starts to run, stack has [return-addr <clos> <a1> .. <an> return-addr' ...]
#        o or it is kept in a separate register, which is pushed/popped on calls?
#     + MUST SUPPORT CONSTANT SPACE TAILCALLS
#     + pass all arguments in stack, and have special meaning for some registers
#  - special registers
#     + free pointer
#     + closure (unless in stack)
#     + nargs (only when making call)
#     + return value (unless at top of stack (support multiple return values?))
#     + continuation? (could autopush/pop like the closure, if necessary)

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

