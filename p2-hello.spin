' mostly stolen from Chip's P2 ROM monitor

CON
        BASE = $e80
        CLOCK_FREQ = 60000000
        BAUD = 115200
        SERIAL_TX = 90  ' must be in the port c
        SERIAL_RX = 91
        CR = $0d
        LF = $0a

DAT
                byte    0[BASE]

                org

start           reps    #$1F6-@reserves+@start,#1      'clear reserves
                setinda reserves
                mov     inda++,#0

                setp    tx_pin
                mov     dirc,dirc_mask          'make tx pin an output

                jmptask #rx_task,#%0010         'enable serial receiver task
                settask #%%1010

                ' wait for the user to start the terminal emulator
                mov     x,#5
:pause          getcnt  w
                add     w,freq
                passcnt w
                djnz    x,#:pause

                setptra hello_addr              'print hello message
                call    #tx_string              'print hello/error message

idle            call    #rx
                cmp     x,#CR wz
        if_nz   jmp     #:next
                call    #tx
                mov     x,#LF
:next           call    #tx
                jmp     #idle

'
'
' Print string (@ptra)
'
tx_string       rdbyte  x,ptra++                'get chr
tx_string_ret   tjz     x,#0                    'if 0, done
                call    #tx                     'other?
                jmp     #tx_string

'
'
' Transmit chr (x)
'
tx              shl     x,#1                    'insert start bit
                setb    x,#9                    'set stop bit

                getcnt  w                       'get initial time

:loop           add     w,period                'add bit period to time
                passcnt w                       'loop until bit period elapsed
                shr     x,#1            wc      'get next bit into c
                setpc   tx_pin                  'write c to tx pin
                tjnz    x,#:loop                'loop until bits done

tx_ret          ret

'
'
' Receive chr (x)
'
rx              call    #rx_check               'wait for rx chr
        if_z    jmp     #rx

rx_ret          ret
'
'
' Check receiver, z=0 if chr (x)
'
rx_check        or      rx_tail,#$80            'if start or rollover, reset tail

                getspb  rx_temp         wz      'if head uninitialized, z=1
        if_nz   cmp     rx_temp,rx_tail wz      'if head-tail mismatch, byte ready, z=0

        if_nz   getspa  rx_temp                 'preserve spa
        if_nz   setspa  rx_tail                 'get tail
        if_nz   popar   x                       'get byte at tail
        if_nz   getspa  rx_tail                 'update tail
        if_nz   setspa  rx_temp                 'restore spa

rx_check_ret    ret


'************************
'* Serial Receiver Task *
'************************

rx_task         chkspb                  wz      'if start or rollover, reset head
        if_z    setspb  #$80

                mov     rx_bits,#9              'ready for 8 data bits + 1 stop bit

                neg     rx_time,period          'get -0.5 period
                sar     rx_time,#1

                jp      rx_pin,#$               'wait for start bit

                subcnt  rx_time                 'get time + 0.5 period for initial 1.5 period delay

:bit            rcr     rx_data,#1              'rotate c into byte
                add     rx_time,period          'add 1 period
                passcnt rx_time                 'wait for center of next bit
                getp    rx_pin          wc      'read rx pin into c
                djnz    rx_bits,#:bit           'loop until 8 data bits + 1 stop bit received

                shr     rx_data,#32-8           'align byte
                pushb   rx_data                 'store byte at head, inc head

                jmp     #rx_task                'wait for next byte


'*************
'* Constants *
'*************

hello           byte    CR, LF, "Hello, Propeller II!", CR, LF, 0
                long
hello_addr      long    @hello
rx_pin          long    SERIAL_RX
tx_pin          long    SERIAL_TX
dirc_mask       long    1 << (SERIAL_TX - 64)
period          long    CLOCK_FREQ / BAUD
freq            long    CLOCK_FREQ


'*************
'* Variables *
'*************

reserves

w               res     1                       'main task
x               res     1
y               res     1
z               res     1

rx_tail         res     1                       'serial receiver task
rx_temp         res     1
rx_time         res     1
rx_data         res     1
rx_bits         res     1
