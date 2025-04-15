;
; PS2 Keyboard and mouse to Archimedes V0.16
; (C) 2013 Ian Bradbury
;

        list    p=pic16F628a

W               equ     0x00
F               equ     0x01
Z               equ     0x02
C               equ     0x00


INDF        EQU     0x00
TMR0        equ     0x01
PCL         EQU     0x02
STATUS      equ     0x03
FSR         EQU     0x04
PORTA       equ     0x05
PORTB       equ     0x06
PCLATH      EQU     0x0A
INTCON	    EQU     0x0B
PIR1        EQU     0x0C
T2CON	    EQU     0x12

RCSTA       EQU     0x18
TXREG       EQU     0x19
RCREG       EQU     0x1A
CMCON       EQU     0x1f

OPTION_REG  EQU     0x81
TRISA       equ     0x85
TRISB       equ     0x86
PIE1        EQU     0x8C
PR2         EQU     0x92
TXSTA       EQU     0x98
SPBRG       EQU     0x99




ps2data             equ 0x20
archerrorflags      equ 0x21
ps2errorflags       equ 0x22
ps2detectedflags    equ 0x23
mousebits           equ 0x24            ; 1st byte of mouse data packet
mousex              equ 0x25            ; 2nd byte of mouse data packet
mousey              equ 0x26            ; 3rd byte of mouse data packet
lastmousebits	    equ 0x27
mousebitschanged    equ 0x28
delaycnt            equ 0x29
archdata            equ 0x2A
delaycount          equ 0x2B
ps2activeflags      equ	0x2C
temp_w              equ	0x2D
temp_sta            equ 0x2E
irqtemp             equ 0x2F
ps2datamask         equ 0x30
ps2clockmask        equ 0x31
lastps2activeflags  equ 0x32
bitcount            equ 0x33
ps2paritycount      equ 0x34
lastarchkeycode     equ 0x35
lastleds            equ 0x36
delaycnt2           equ 0x37
keyflags            equ 0x38
timeout0            equ	0x39
timeout1            equ	0x3a
bitmask             equ 0x3b
rxflag              equ 0x3c
backflag            equ 0x3d
ackflag             equ 0x3e
rxbuffer            equ 0x3f
arcstate            equ 0x40
windowskeyflags     equ 0x41
shiftkeyflags       equ 0x42
keyboardmode        equ 0x43
archdirection       equ 0x44
translateflags      equ 0x45
archkey             equ 0x46
shiftkeyflagstemp   equ 0x47
keydownflags        equ 0x48
lastshiftkeyflags   equ 0x49
keycode1            equ 0x4a
keycode2            equ 0x4b
specialkeyflags     equ 0x4c
startdelay0         equ 0x4d
startdelay1         equ 0x4e
startdelay2         equ 0x4f
startdelayflag      equ 0x50
resetdelay0         equ 0x51
resetdelay1         equ 0x52
prevleds            equ 0x53




ps2mousedata		equ b'00000001'
ps2mouseclock   	equ b'00100000'
ps2keyboarddata		equ b'00001000'
ps2keyboardclock   	equ b'00010000'


kb_HRST equ b'11111111'
kb_RAK1 equ b'11111110'
kb_RAK2 equ b'11111101'
kb_RQPD equ b'01000000'
kb_PDAT equ b'11100000'
kb_RQID equ b'00100000'
kb_KBID equ b'10000000'
kb_KDDA equ b'11000000'
kb_KUDA equ b'11010000'
kb_RQMP equ b'00100010'
kb_BACK equ b'00111111'

kb_NACK equ b'00110000'
kb_SACK equ b'00110001'
kb_MACK equ b'00110010'
kb_SMAK equ b'00110011'

kb_ACK  equ b'00110000'
kb_ACKM equ b'11111100'

kb_LEDS equ b'00000000'
kb_PRST equ b'00100001'


;archimedes power up sequence
;LEDS0
;HRST sequence
;NACK
;RQID
;HRST
;SACK <-- probably test point for power on keys as mouse not enabled
;<kb keys held down>
;LEDS0
;HRST sequence
;NACK
;RQID
;LEDS1
;SMAK
;<kb keys held down>
;HRST sequence
;NACK
;RQID
;LEDS1
;SMAK
;<kb keys held down>



mov     macro   dest,val   ; load imm value to register
        movlw   val
        movwf   dest
        endm

djne    macro   var,label ; dec register & jump if <>0
        decfsz  var
        goto    label
        endm

beq     macro   label
        skpnz
        goto    label
        endm

bne     macro   label
        skpz
        goto    label
        endm



; --------- main routine -----------
        org 0
        goto start
;------------------------------------------------------------------ int code
        org 4 ;int code
intstart
        movwf   temp_w
        swapf   STATUS,w
        movwf   temp_sta 
        btfss   INTCON,0
        goto    tryserial
        
        movfw   PORTB           
        movwf   irqtemp
        bcf     INTCON,0 
        btfsc   irqtemp,6 	; test TX to arc and invert
        bcf     PORTA,3
        btfss   irqtemp,6
        bsf     PORTA,3

        btfsc   irqtemp,7 	; test RX from arc and invert
        bcf     PORTA,2
        btfss   irqtemp,7
        bsf     PORTA,2

tryserial
        btfss   PIR1,5  ;serial RX flag set
        goto    exitirq
;serial (18 cycles so far)
        btfsc 	RCSTA,1
        goto  	overrunRX
        movfw 	RCREG   ;clear RCIF
        movwf   irqtemp
        xorlw	kb_BACK
        beq	validback
        xorlw   kb_ACK ^ kb_BACK        ;ACK xor BACK
        andlw	kb_ACKM
        bne	saverxbyte
;validack
        movfw   irqtemp
        movwf	ps2activeflags
        bsf     ackflag,0
        
        ;repeat code saves goto cycles
        swapf   temp_sta,w
        movwf   STATUS
        swapf   temp_w,f
        swapf   temp_w,w
        retfie

overrunRX
        bcf   	RCSTA,4
        movfw   RCREG
        bsf   	RCSTA,4
        goto    exitirq
validback
        bsf     backflag,0
        goto    exitirq

saverxbyte
        movfw	irqtemp
        movwf	rxbuffer
        bsf     rxflag,0
exitirq
        swapf   temp_sta,w
        movwf   STATUS
        swapf   temp_w,f
        swapf   temp_w,w
        retfie

;cycle count, 
;invert only = 23
;overrun = 30
;validback = 33
;validack = 36
;saverxbyte = 37


kbtranslate
        addwf  PCL,f
basecodes
        retlw 0xff  ;0x00
        retlw 0x09  ;0x01  F9
        retlw 0xff  ;0x02
        retlw 0x05  ;0x03  F5
        retlw 0x03  ;0x04  F3
        retlw 0x01  ;0x05  F1
        retlw 0x02  ;0x06  F2
        retlw 0x0c  ;0x07  F12
        retlw 0xff  ;0x08
        retlw 0x0a  ;0x09  F10
        retlw 0x08  ;0x0A  F8
        retlw 0x06  ;0x0B  F6
        retlw 0x04  ;0x0C  F4
        retlw 0x26  ;0x0D  Tab
        retlw 0x10  ;0x0E  ` ~
        retlw 0xff  ;0x0F
        retlw 0xff  ;0x10
        retlw 0x5e  ;0x11  Left Alt
        retlw 0x4c  ;0x12  Left Shift
        retlw 0xff  ;0x13
        retlw 0x5d  ;0x14  Left Ctrl
        retlw 0x27  ;0x15  Q
        retlw 0x11  ;0x16  1 !
        retlw 0xff  ;0x17
        retlw 0xff  ;0x18
        retlw 0xff  ;0x19
        retlw 0x4e  ;0x1A  Z
        retlw 0x3d  ;0x1B  S
        retlw 0x3c  ;0x1C  A
        retlw 0x28  ;0x1D  W
        retlw 0x12  ;0x1E  2 @
        retlw 0xff  ;0x1F
        retlw 0xff  ;0x20
        retlw 0x50  ;0x21  C
        retlw 0x4f  ;0x22  X
        retlw 0x3e  ;0x23  D
        retlw 0x29  ;0x24  E
        retlw 0x14  ;0x25  4 $
        retlw 0x13  ;0x26  3 #
        retlw 0xff  ;0x27
        retlw 0xff  ;0x28
        retlw 0x5f  ;0x29  Space
        retlw 0x51  ;0x2A  V
        retlw 0x3f  ;0x2B  F
        retlw 0x2b  ;0x2C  T
        retlw 0x2a  ;0x2D  R
        retlw 0x15  ;0x2E  5 %
        retlw 0xff  ;0x2F
        retlw 0xff  ;0x30
        retlw 0x53  ;0x31  N
        retlw 0x52  ;0x32  B
        retlw 0x41  ;0x33  H
        retlw 0x40  ;0x34  G
        retlw 0x2c  ;0x35  Y
        retlw 0x16  ;0x36  6 ^
        retlw 0xff  ;0x37
        retlw 0xff  ;0x38
        retlw 0xff  ;0x39
        retlw 0x54  ;0x3A  M
        retlw 0x42  ;0x3B  J
        retlw 0x2d  ;0x3C  U
        retlw 0x17  ;0x3D  7 &
        retlw 0x18  ;0x3E  8 *
        retlw 0xff  ;0x3F
        retlw 0xff  ;0x40
        retlw 0x55  ;0x41  , <
        retlw 0x43  ;0x42  K
        retlw 0x2e  ;0x43  I
        retlw 0x2f  ;0x44  O
        retlw 0x1a  ;0x45  0 )
        retlw 0x19  ;0x46  9 (
        retlw 0xff  ;0x47
        retlw 0xff  ;0x48
        retlw 0x56  ;0x49  . >
        retlw 0x57  ;0x4A  / ?
        retlw 0x44  ;0x4B  L
        retlw 0x45  ;0x4C  ; :
        retlw 0x30  ;0x4D  P
        retlw 0x1b  ;0x4E  - _
        retlw 0xff  ;0x4F
        retlw 0xff  ;0x50
        retlw 0xff  ;0x51
        retlw 0x46  ;0x52  ' "
        retlw 0xff  ;0x53
        retlw 0x31  ;0x54  [ {
        retlw 0x1c  ;0x55  = +
        retlw 0xff  ;0x56
        retlw 0xff  ;0x57
        retlw 0x3b  ;0x58  Caps Lock    
        retlw 0x58  ;0x59  Right Shift
        retlw 0x47  ;0x5A  Enter
        retlw 0x32  ;0x5B  ] }
        retlw 0xff  ;0x5C
        retlw 0x33  ;0x5D  \ |
        retlw 0xff  ;0x5E
        retlw 0xff  ;0x5F
        retlw 0xff  ;0x60
        retlw 0x1d  ;0x61  £
        retlw 0xff  ;0x62
        retlw 0xff  ;0x63
        retlw 0xff  ;0x64
        retlw 0xff  ;0x65
        retlw 0x1e  ;0x66  Backspace
        retlw 0xff  ;0x67
        retlw 0xff  ;0x68
        retlw 0x5a  ;0x69  Keypad 1 End
        retlw 0xff  ;0x6A
        retlw 0x48  ;0x6B  Keypad 4 Cursor Left
        retlw 0x37  ;0x6C  Keypad 7 Home
        retlw 0xff  ;0x6D
        retlw 0xff  ;0x6E
        retlw 0xff  ;0x6F
        retlw 0x65  ;0x70  Keypad 0 Insert
        retlw 0x66  ;0x71  Keypad . Delete
        retlw 0x5b  ;0x72  Keypad 2 Cursor Down
        retlw 0x49  ;0x73  Keypad 5
        retlw 0x4a  ;0x74  Keypad 6 Cursor Right
        retlw 0x38  ;0x75  Keypad 8 Cursor Up
        retlw 0x00  ;0x76  Esc
        retlw 0x22  ;0x77  Num lock
        retlw 0x0b  ;0x78  F11
        retlw 0x4b  ;0x79  Keypad +
        retlw 0x5c  ;0x7A  Keypad 3 Page Down
        retlw 0x3a  ;0x7B  Keypad -
        retlw 0x24  ;0x7C  Keypad *
        retlw 0x39  ;0x7D  Keypad 9 Page Up
        retlw 0x0e  ;0x7E  Scroll Lock
        retlw 0xff  ;0x7F
        retlw 0xff  ;0x80
        retlw 0xff  ;0x81
        retlw 0xff  ;0x82
        retlw 0x07  ;0x83  F7
        retlw 0x0d  ;0x84  print screen with left or right alt

;fragmentary extended E0 keycodes

e0base1 equ     0x11

e0part1
        retlw 0x60  ;0x11  RIGHT ALT
        retlw 0xff  ;0x12  modifier for print screen, edit group with numlock & numeric / (ignore)
        retlw 0xff  ;0x13
        retlw 0x61  ;0x14  RIGHT CTRL

e0base2 equ     0x4a

e0part2
        retlw 0x23  ;0x4A  Keypad /
        retlw 0xff  ;0x4b
        retlw 0xff  ;0x4c
        retlw 0xff  ;0x4d
        retlw 0xff  ;0x4e
        retlw 0xff  ;0x4f
        retlw 0xff  ;0x50
        retlw 0xff  ;0x51
        retlw 0xff  ;0x52
        retlw 0xff  ;0x53
        retlw 0xff  ;0x54
        retlw 0xff  ;0x55
        retlw 0xff  ;0x56
        retlw 0xff  ;0x57
        retlw 0xff  ;0x58
        retlw 0xff  ;0x59  modifier for edit group with numlock & numeric / (ignore)
        retlw 0x67  ;0x5A  Keypad ENTER
        retlw 0xff  ;0x5b
        retlw 0xff  ;0x5c
        retlw 0xff  ;0x5d
        retlw 0xff  ;0x5e
        retlw 0xff  ;0x5f
        retlw 0xff  ;0x60
        retlw 0xff  ;0x61
        retlw 0xff  ;0x62
        retlw 0xff  ;0x63
        retlw 0xff  ;0x64
        retlw 0xff  ;0x65
        retlw 0xff  ;0x66
        retlw 0xff  ;0x67
        retlw 0xff  ;0x68
        retlw 0x35  ;0x69  End
        retlw 0xff  ;0x6a
        retlw 0x62  ;0x6B  LEFT ARROW
        retlw 0x20  ;0x6C  HOME
        retlw 0xff  ;0x6d
        retlw 0xff  ;0x6e
        retlw 0xff  ;0x6f
        retlw 0x1f  ;0x70  INSERT
        retlw 0x34  ;0x71  DELETE
        retlw 0x63  ;0x72  DOWN ARROW
        retlw 0xff  ;0x73
        retlw 0x64  ;0x74  RIGHT ARROW
        retlw 0x59  ;0x75  UP ARROW
        retlw 0xff  ;0x76
        retlw 0x0f  ;0x77  pausebreak without ctrl (Actually E1 code prefix, not E0)
        retlw 0xff  ;0x78
        retlw 0xff  ;0x79
        retlw 0x36  ;0x7A  PG DN
        retlw 0xff  ;0x7b
        retlw 0x0d  ;0x7C  Print Screen
        retlw 0x21  ;0x7D  PG UP
        retlw 0x0f  ;0x7e  pausebreak with ctrl
e0part3


;	PORTA bits & dir
;       0 = kb err              (OUT)
;       1 = mouse err           (OUT)
;       2 = !RX	from ARC via B7 (OUT)
;       3 = !TX to ARC via B6	(OUT)
;       4 = Reset to ARC        (OUT)
;       5 = normal/game         (ALWAYS IN)


;   PORTB bits & dir
;       0 = MS DATA             (IN)
;       1 = serial port RX      (IN) - Serial IN
;       2 = serial port TX      (IN) - Serial OUT
;       3 = KB DATA             (IN)
;       4 = KB CLK              (IN)
;       5 = MS CLK              (IN)
;       6 = TX to ARC via A4    (IN)		
;       7 = !RX from ARC via A2 (IN)


start
        
        clrwdt
        clrf 	STATUS
        clrf  	PCLATH ; so jump tables work!
        
        movlw   0x07        ;Turn comparators off
        movwf   CMCON

        movlw   b'00010100'	; port A setup
        movwf   PORTA		
        movlw   b'00000000'	; port B setup
        movwf   PORTB           

        mov     FSR,TRISA
        mov     INDF,b'11110000' ;reset as an input
        mov     FSR,TRISB
        mov     INDF,b'11111111'

        mov     FSR,OPTION_REG
        mov     INDF,b'00000000'  ;TURN ON PORTB PULLUPS

        ;SERIAL PORT
        mov   	FSR,SPBRG
        mov   	INDF,0x27 	 ;31250 BAUD with 20 Mhz xtal
        mov   	FSR,TXSTA
        mov   	INDF,b'00000100' ;BRGH
        mov   	FSR,RCSTA
        mov   	INDF,b'10000000' ;SPEN
        mov   	FSR,TXSTA
        mov   	INDF,b'01100101'  ;b'00100100' ;TXEN TX9 TX9D
        mov   	FSR,RCSTA
        mov   	INDF,b'10010000' ;CREN

        mov 	FSR,PIE1
        bsf     INDF,5   	; enable serial interrupt


        mov     FSR,TRISB	; leave FSR pointing at TRISB
        bcf   	RCSTA,4
        bsf   	RCSTA,4
        movfw 	RCREG
        clrf    rxflag
        clrf    backflag
        clrf    ackflag
        clrf    keyboardmode
        movlw   0x03
        btfss   PORTA,5
        movwf   keyboardmode
        mov     INTCON,0xC8	; enable serial and rbif interrupts
        clrf    startdelayflag
        clrf    startdelay0
        clrf    startdelay1
        movlw   0xfa
        movwf   startdelay2     ;roughly 3 sec delay
        goto	powerupstart

restarterrorkeyb
        bsf     PORTA,0
        bcf     PORTA,1
        goto	restart
restarterrormouse
        bcf     PORTA,0
        bsf 	PORTA,1
        goto	restart
restarterrorarch
        bsf 	PORTA,0
        bsf 	PORTA,1
restart
        call    delay1ms
        call 	setps2keyboard
        call    ps2inhibit
        call	setps2mouse
        call    ps2inhibit

        movlw   kb_HRST
        call    txbyte

powerupstart

        movlw   0x03
        movwf   ps2activeflags
        movwf   lastps2activeflags
        clrf	lastmousebits
        clrf    lastleds
        clrf    keyflags
        clrf    windowskeyflags
        clrf    shiftkeyflags
        clrf    lastshiftkeyflags
        clrf    translateflags
        clrf    keydownflags
        clrf    specialkeyflags
        movlw	0xff
        movwf   prevleds
        movwf	lastarchkeycode
        clrf    ps2detectedflags

        clrf    arcstate
        clrf    resetdelay0
        clrf    resetdelay1

        clrf    rxflag

mainscanlooprel
        movfw   arcstate
        bne     mainscanloop

        call 	setps2keyboard
        btfsc   lastps2activeflags,0
        call	ps2release

        call	setps2mouse
        btfsc   lastps2activeflags,1
        call	ps2release

mainscanloop
        btfss   startdelayflag,0  
        call    startcountdown

        movfw   arcstate
        skpz
        call    resetcountdown

        btfsc 	rxflag,0
        goto    keyboardarc

        btfss   PORTB,4               ; wait for keyboard clock (start bit)
        goto    keyboardps2
ignorekeyboardps2  

        btfss   PORTB,5               ; wait for mouse clock (start bit)
        goto	mouseps2
ignoremouseps2        

        movfw   ps2activeflags
        xorwf   lastps2activeflags,w
        beq     mainscanloop
        goto    mkstatechange


startcountdown
        incf 	startdelay0,f
        skpnz
        incf	startdelay1,f
        skpnz
        incf	startdelay2,f
        skpz
        return
        bsf     startdelayflag,0
        movlw   kb_HRST
        goto    txbyte

resetcountdown
        incf 	resetdelay0,f
        skpnz
        incf	resetdelay1,f
        skpz
        return       
        clrf    arcstate                ;if here then reset sequence failed so try again       
        movlw   kb_HRST
        goto    txbyte

keyboardarc
        movfw 	rxbuffer 
        movwf   archdata
        clrf    rxflag

        movfw   arcstate
        beq     normaloperation
        xorlw   0x01
        bne     notstate1
        
        movfw   archdata
        xorlw   kb_RAK2
        beq     gotrak2

        incf    arcstate,f
        movlw   kb_HRST
        call    txbyte
        goto    mainscanloop

gotrak2
        decf    arcstate,f
        movlw   kb_RAK2
        call    txbyte
        goto    mainscanlooprel

notstate1
        movfw   arcstate
        xorlw   0x02
        bne     restarterrorarch
        
        movfw   archdata
        xorlw   kb_RAK1
        beq     gotrak1
        movlw   kb_HRST
        call    txbyte
        goto    mainscanloop


gotrak1
        decf    arcstate,f
        movlw   kb_RAK1
        call    txbyte
        goto    mainscanloop


normaloperation

        movfw   archdata
        xorlw   kb_HRST
        beq     dohrst   
        movfw   archdata
        xorlw   kb_RAK1
        beq     dohrst   
        movfw   archdata
        andlw   0xF8
        beq     setleds
        movfw   archdata
        xorlw   kb_RQID
        beq     sendID
        movfw   archdata
        andlw   0xF0
        xorlw   kb_RQPD
        beq     sendPD
        movfw   archdata
        xorlw   kb_PRST
        beq     doprst
        movfw   archdata
        xorlw   kb_RQMP
        beq     sendMP

        ;unknown arc keyboard command if here

        goto    restarterrorarch


dohrst
        call 	setps2keyboard
        call    ps2inhibit
        call	setps2mouse
        call    ps2inhibit
        clrf    ps2activeflags
        clrf    lastps2activeflags
        movlw   kb_HRST
        call    txbyte
        movlw   0x02
        movwf   arcstate
        clrf    resetdelay0
        clrf    resetdelay1
        bsf     startdelayflag,0
        goto    mainscanloop     

setleds
        clrf	lastleds
        btfsc	archdata,0
        bsf     lastleds,2
        btfsc	archdata,1
        bsf     lastleds,1
        btfsc	archdata,2
        bsf     lastleds,0

        btfss   startdelayflag,0
        goto    mainscanloop

        btfss   lastps2activeflags,0
        goto    mainscanloop
        btfss   ps2detectedflags,0
        goto    mainscanloop

        movfw   lastleds        
        xorwf   prevleds,w
        beq     mainscanloop
        

        call	setps2mouse
        call    ps2inhibit
        call 	setps2keyboard

        movlw   0xed            ; set leds command to kb
        call	ps2transmit
        movfw	ps2errorflags
        bne     restarterrorkeyb
        call    ps2receive
        movfw	ps2errorflags
        bne     restarterrorkeyb
        movfw   ps2data
        xorlw   0xFA            ; fa ack 
        bne     restarterrorkeyb

        movfw	lastleds
        movwf   prevleds
        call	ps2transmit
        movfw	ps2errorflags
        bne     restarterrorkeyb

        call    ps2receive
        movfw	ps2errorflags
        bne     restarterrorkeyb
        movfw   ps2data
        xorlw   0xFA            ; fa ack 
        bne     restarterrorkeyb

        goto    mainscanlooprel

sendID
        movlw   kb_KBID
        iorlw   0x01
        call    txbyte
        goto    mainscanloop

sendPD
        movfw   archdata
        andlw   0x0F
        iorlw   kb_PDAT
        call    txbyte
        goto    mainscanloop

doprst
        goto    mainscanloop

sendMP
        call	setps2mouse
        call    ps2inhibit
        call 	setps2keyboard
        call    ps2inhibit

        movlw   0x00
        call    txbyte
        call    waitrxBACK
        btfsc   archerrorflags,7
        goto	restarterrorarch
        movlw   0x00
        call    txbyte
        call    waitrxACK
        btfsc   archerrorflags,7
        goto	restarterrorarch
        goto    mainscanlooprel   

mkstatechange
        movfw   arcstate
        bne     mainscanloop            ;still in reset so ignore        

        movfw   ps2activeflags
        xorwf   lastps2activeflags,w
        andlw   0x01
        beq     initps2keyboardfail     ;no change in kb state

        btfsc   ps2activeflags,0
        goto    doinitps2keyboard

        call    setps2keyboard
        call    ps2inhibit
        goto    initps2keyboardfail
doinitps2keyboard

        call	setps2mouse
        call    ps2inhibit

        call 	setps2keyboard
initps2keyboard
        movlw   0xed            ; set leds command to kb
        call	ps2transmit
        btfsc   ps2errorflags,7
        goto    initps2keyboardfail
        movfw	ps2errorflags
        bne     initps2keyboard
        call    ps2receive
        btfsc   ps2errorflags,7
        goto    initps2keyboardfail
        movfw	ps2errorflags
        bne     initps2keyboard
        movfw   ps2data
        xorlw   0xFA            ; fa ack 
        bne     initps2keyboard

        movfw	lastleds
        call	ps2transmit
        btfsc   ps2errorflags,7
        goto    initps2keyboardfail
        movfw	ps2errorflags
        bne     initps2keyboard
        
        call    ps2receive
        btfsc   ps2errorflags,7
        goto    initps2keyboardfail
        movfw	ps2errorflags
        bne     initps2keyboard
        movfw   ps2data
        xorlw   0xFA            ; fa ack 
        bne     initps2keyboard
        
        call    delay20us
        
        bsf     ps2detectedflags,0

        call	ps2inhibit

        movlw   0x4c
        btfsc   shiftkeyflags,0
        call    sendarchkeydown

        movlw   0x58
        btfsc   shiftkeyflags,1
        call    sendarchkeydown

        movlw   0x3b
        btfsc   shiftkeyflags,2
        call    sendarchkeydown

        movlw   0x61
        btfsc   shiftkeyflags,3
        call    sendarchkeydown

        movlw   0x5e
        btfsc   shiftkeyflags,4
        call    sendarchkeydown

        movlw   0x60
        btfsc   shiftkeyflags,5
        call    sendarchkeydown

        movfw	lastarchkeycode
        xorlw	0xff
        beq	initps2keyboardfail		; ignore invalid scancodes
        
        movfw	lastarchkeycode
        call	sendarchkeydownwithtranslation
        btfsc   archerrorflags,7
        goto	restarterrorarch


initps2keyboardfail

        movfw   ps2activeflags
        xorwf   lastps2activeflags,w
        andlw   0x02
        beq     initps2mousefail     ;no change in mouse state

        btfsc   ps2activeflags,1
        goto    doinitps2mouse

        call    setps2mouse
        call    ps2inhibit
        goto    initps2mousefail

doinitps2mouse
        call    setps2keyboard
        call    ps2inhibit
        call    setps2mouse
initps2mouse
        movlw   0xf4            ; "Enable Data Reporting" command to mouse
        call	ps2transmit
        btfsc   ps2errorflags,7
        goto    initps2mousefail
        movfw	ps2errorflags
        bne     initps2mouse

        call    ps2receive
        btfsc   ps2errorflags,7
        goto    initps2mousefail
        movfw	ps2errorflags
        bne     initps2mouse
        movfw	ps2data
        xorlw   0xfa
        bne     initps2mouse
        bsf     ps2detectedflags,1

initps2mousefail

        movfw   ps2activeflags
        movwf   lastps2activeflags
        goto	mainscanlooprel

testhotswapkb
        movfw   arcstate
        bne     mainscanlooprel         ;reset underway
        bsf     startdelayflag,0
        movlw   kb_HRST
        call    txbyte
        goto	mainscanlooprel

keyboardps2
        btfss   lastps2activeflags,0
        goto    ignorekeyboardps2   
        movwf   arcstate
        bne     ignorekeyboardps2

        call	setps2mouse
        call    ps2inhibit

        call    setps2keyboard

        ;read 	ps2 keyboard here

        call    ps2receive             
        movfw	ps2errorflags
        bne     restarterrorkeyb

        movfw	ps2data
        xorlw	0xaa		      ; could be kb reset hot swap
        beq     testhotswapkb

        movfw	ps2data
        xorlw	0xE1
        beq     pausebreak

        movfw	ps2data
        xorlw	0xE0
        beq     extendedcode

        movfw	ps2data
        xorlw	0xF0
        beq     breakcode

        movlw 	e0part1-basecodes
        subwf 	ps2data,w
        btfsc 	STATUS,C
        goto   	mainscanlooprel		; ignore invalid scancodes

        movfw	ps2data
sendmake
        call 	kbtranslatewithmode
        movwf	archdata
        xorlw	0xff
        beq     mainscanlooprel		; ignore invalid scancodes

        movfw	archdata
        xorwf	lastarchkeycode,w
        beq     mainscanlooprel 	; ignore typematic repeat code

        call    testshiftkeys
        movfw	shiftkeyflagstemp
        beq     savecode
        xorwf   shiftkeyflags,w
        andwf   shiftkeyflagstemp,w
        bne     dontsavecode     
        goto    mainscanlooprel 	; ignore typematic repeat code on shift keys
savecode
        movfw   archdata
        movwf	lastarchkeycode
dontsavecode
        call	ps2inhibit
        movfw	archdata
        call	sendarchkeydownwithtranslation
        btfsc   archerrorflags,7
        goto	restarterrorarch

        goto	mainscanlooprel


breakcode
        call    ps2receive               
        movfw	ps2errorflags
        bne     restarterrorkeyb
        movlw 	e0part1-basecodes
        subwf 	ps2data,w
        btfsc 	STATUS,C
        goto   	mainscanlooprel		; ignore invalid scancodes

        movfw	ps2data
sendbreak
        call 	kbtranslatewithmode
        movwf	archdata
        xorlw	0xff
        beq     mainscanlooprel		; ignore invalid scancodes

        call    testshiftkeys
        movfw	shiftkeyflagstemp
        bne     dontclearcode
        movfw   archdata
        xorwf   lastarchkeycode,w
        bne     dontclearcode           ;new key pressed before release of old key so don't clear code
        movlw	0xff
        movwf	lastarchkeycode
dontclearcode
        call	ps2inhibit
        movfw	archdata
        call	sendarchkeyupwithtranslation
        movfw   archdata
        xorlw   0x0f                    ;pausebreak key
        beq     mainscanlooprel         ;if pausebreak up then ignore timeout error as last ACK not sent on reset
        btfsc   archerrorflags,7
        goto	restarterrorarch

        goto	mainscanlooprel


extendedcode
        call    ps2receive             
        movfw	ps2errorflags
        bne     restarterrorkeyb

        movfw	ps2data
        xorlw	0xF0
        beq     extendedbreakcode
        
        movlw 	e0base2 + e0part3 - e0part2 
        subwf 	ps2data,w
        btfsc 	STATUS,C
        goto   	mainscanlooprel		;ignore invalid scancodes
        movlw	e0base2
        subwf 	ps2data,w
        btfss 	STATUS,C
        goto   	trylowermakecodes
e1makecode
        movfw	ps2data
        addlw   e0part2 - basecodes - e0base2 
        goto 	sendmake

trylowermakecodes
        movlw   e0base1 + e0part2 - e0part1
        subwf 	ps2data,w
        btfsc 	STATUS,C
        goto   	testwindowsmakecodes
        movlw	e0base1
        subwf 	ps2data,w
        btfss 	STATUS,C
        goto   	mainscanlooprel		;ignore invalid scancodes
        movfw	ps2data
        addlw   e0part1 - basecodes - e0base1
        goto 	sendmake

testwindowsmakecodes
        movfw   ps2data
        xorlw   0x1F  ;LEFT WINDOWS
        skpnz
        bsf     windowskeyflags,0

        movfw   ps2data
        xorlw   0x27  ;RIGHT WINDOWS
        skpnz
        bsf     windowskeyflags,1

        movfw   ps2data
        xorlw   0x2F  ;APP KEY
        skpnz
        bsf     windowskeyflags,2
        goto   	mainscanlooprel

extendedbreakcode
        call    ps2receive           
        movfw	ps2errorflags
        bne     restarterrorkeyb
        movlw 	e0base2 + e0part3 - e0part2
        subwf 	ps2data,w
        btfsc 	STATUS,C
        goto   	mainscanlooprel		;ignore invalid scancodes
        movlw	e0base2
        subwf 	ps2data,w
        btfss 	STATUS,C
        goto   	trylowerbreakcodes
e1breakcode
        movfw	ps2data
        addlw   e0part2 - basecodes - e0base2 
        goto 	sendbreak

trylowerbreakcodes

        movlw 	e0base1 + e0part2 - e0part1
        subwf 	ps2data,w
        btfsc 	STATUS,C
        goto   	testwindowsbreakcodes
        movlw	e0base1
        subwf 	ps2data,w
        btfss 	STATUS,C
        goto   	mainscanlooprel		;ignore invalid scancodes
        movfw	ps2data
        addlw   e0part1 - basecodes - e0base1
        goto 	sendbreak

testwindowsbreakcodes
        movfw   ps2data
        xorlw   0x1F  ;LEFT WINDOWS
        skpnz
        bcf     windowskeyflags,0

        movfw   ps2data
        xorlw   0x27  ;RIGHT WINDOWS
        skpnz
        bcf     windowskeyflags,1

        movfw   ps2data
        xorlw   0x2F  ;APP KEY
        skpnz
        bcf     windowskeyflags,2
        goto   	mainscanlooprel
        

pausebreak
        call    ps2receive             
        movfw	ps2errorflags
        bne     restarterrorkeyb
        movfw	ps2data
        xorlw	0xF0
        beq     pausebreakbreak
        movfw	ps2data
        xorlw	0x14
        bne     restarterrorkeyb
        call    ps2receive             
        movfw	ps2errorflags
        bne     restarterrorkeyb
        movfw	ps2data
        xorlw	0x77
        bne     restarterrorkeyb
        goto    e1makecode


pausebreakbreak
        call    ps2receive             
        movfw	ps2errorflags
        bne     restarterrorkeyb
        movfw	ps2data
        xorlw	0x14
        bne     restarterrorkeyb
        call    ps2receive             
        movfw	ps2errorflags
        bne     restarterrorkeyb
        movfw	ps2data
        xorlw	0xF0
        bne     restarterrorkeyb
        call    ps2receive             
        movfw	ps2errorflags
        bne     restarterrorkeyb
        movfw	ps2data
        xorlw	0x77
        bne     restarterrorkeyb
        goto    e1breakcode

mousehotswap
        call    ps2receive            ; receive 00 from mouse
        movfw	ps2errorflags
        bne     restarterrormouse
        movfw   arcstate
        bne     mainscanlooprel         ;reset underway 
        btfss   startdelayflag,0
        goto    mainscanlooprel
        movlw   kb_HRST
        call    txbyte
        goto	mainscanlooprel
        
mouseps2
        btfss   lastps2activeflags,1
        goto    ignoremouseps2
        movwf   arcstate
        bne     ignoremouseps2

        call    setps2keyboard
        call    ps2inhibit

        call	setps2mouse

        call    ps2receive       ; receive byte1 from mouse packet
        movfw	ps2errorflags
        bne     restarterrormouse
        movfw	ps2data
        movwf   mousebits
        xorlw	0xaa		      ; could be mouse reset hot swap
        beq     mousehotswap

        call    ps2receive            ; receive byte2 from mouse packet
        movfw	ps2errorflags
        bne     restarterrormouse
        movfw	ps2data
        movwf   mousex

        call    ps2receive            ; receive byte3 from mouse packet
        movfw	ps2errorflags
        bne     restarterrormouse
        movfw	ps2data
        movwf   mousey

        btfss   ps2detectedflags,1
        goto    mainscanlooprel

        call    delay20us

        call	ps2inhibit	
        movfw	mousex
        iorwf	mousey,w
        beq     nomotion

        movfw	mousex
        andlw	0x7F
        call	txbyte
        call	waitrxBACK
        btfsc   archerrorflags,7
        goto	restarterrorarch
        movfw	mousey
        andlw 	0x7F
        call	txbyte
        call	waitrxACK
        btfsc   archerrorflags,7
        goto	restarterrorarch
nomotion

        movfw	mousebits
        andlw	0x07
        xorwf	lastmousebits,w
        movwf	mousebitschanged
        beq     nobitschanged
        movfw	mousebits
        movwf   lastmousebits
        btfss	mousebitschanged,0
        goto	noleftchange
        movlw	0x70		;archimedes mouse button code		
        btfsc	lastmousebits,0
        iorlw	0x80
        call	sendarchkey
        btfsc   archerrorflags,7
        goto	restarterrorarch
noleftchange
        btfss	mousebitschanged,1
        goto	norightchange
        movlw	0x72		;archimedes mouse button code
        btfsc	lastmousebits,1
        iorlw	0x80
        call	sendarchkey
        btfsc   archerrorflags,7
        goto	restarterrorarch
norightchange
        btfss	mousebitschanged,2
        goto	nobitschanged
        movlw	0x71		;archimedes mouse button code       
        btfsc	lastmousebits,2
        iorlw	0x80
        call	sendarchkey
        btfsc   archerrorflags,7
        goto	restarterrorarch
nobitschanged
        goto	mainscanlooprel

kbtranslatewithmode
        call    kbtranslate
        btfsc   keyboardmode,0
        return
        movwf   archdata
        xorlw   0x5d    ;caps lock
        bne     notcapslock
        movlw   0x3b    ;left ctrl
        return
notcapslock
        movfw   archdata
        xorlw   0x3b    ;left ctrl
        bne     notleftctrl
        movlw   0x5d    ;caps lock
        return
notleftctrl
        movfw   archdata
        xorlw   0x1d    ;£
        bne     notpound
        movlw   0x33    ;\
        return
notpound
        movfw   archdata
        xorlw   0x33    ;\
        bne     notbackslash
        movlw   0x1d    ;£
        return
notbackslash
        movfw   archdata
        return

sendarchkey
        movwf   archdirection
        andlw   0x7f
        btfsc   archdirection,7
        goto    sendarchkeydown
        goto    sendarchkeyup

sendarchkeydownwithtranslation
        movwf   archdata
        movfw   shiftkeyflags
        movwf   lastshiftkeyflags
        call    testshiftkeys
        movfw   shiftkeyflagstemp
        andlw   0x7f
        iorwf   shiftkeyflags,f

        movfw   windowskeyflags
        andlw   0x03
        bne     specialkeysdown
        movfw   shiftkeyflags
        andlw   0xfc ;allow shift keys
        xorlw   0x28
        bne     nospecialkeysdown
specialkeysdown
        movfw   keydownflags
        bne     nospecialkeysdown       ;make sure no translated keys are active before changing mode

        movfw   archdata
        xorlw   0x0f
        bne     notresetdown
        bsf     specialkeyflags,0

        bcf     INTCON,7        ;disable interrupts as read/modify/write of porta in irq routine
        mov     FSR,TRISA
        bcf     INDF,4           ;reset an output
        bcf     PORTA,4          ;make sure reset driven low
waitresetlow
        btfsc   PORTA,4
        goto    waitresetlow
        mov     FSR,TRISB
        bsf     INTCON,7

        return
notresetdown
        movfw   archdata
        xorlw   0x40    ;G ame
        bne     notGdown
        bsf     specialkeyflags,1
        movlw   0x03
        movwf   keyboardmode
        return
notGdown
        movfw   archdata
        xorlw   0x30    ;P artial
        bne     notPdown
        bsf     specialkeyflags,2
        movlw   0x02
        movwf   keyboardmode
        return
notPdown
        movfw   archdata
        xorlw   0x53    ;N ormal
        bne     nospecialkeysdown
        bsf     specialkeyflags,3
        clrf    keyboardmode
        return
nospecialkeysdown


        btfsc   keyboardmode,1
        goto    nodowntranslation

        movfw   archdata
        xorlw   0x1d    ;£¬
        bne     notpounddown
        movlw   0x25    ;#
        movwf   archdata
notpounddown

        movfw   archdata
        xorlw   0x46    ;'"
        bne     notquotes
        bsf     keydownflags,0
        btfss   shiftkeyflags,6
        goto    nodowntranslation
        bsf     translateflags,0
        movlw   0x12    ;2@
        goto    sendarchkeydown
notquotes
        movfw   archdata
        xorlw   0x12    ;2@
        bne     notat
        bsf     keydownflags,1
        btfss   shiftkeyflags,6
        goto    nodowntranslation
        bsf     translateflags,1
        movlw   0x46    ;'"
        goto    sendarchkeydown
notat
        movfw   archdata
        xorlw   0x10    ;`~
        bne     notquote
        bsf     keydownflags,2
        btfss   shiftkeyflags,6
        goto    nodowntranslation
        bsf     translateflags,2
        movlw   0x1d    ;£¬
        goto    sendarchkeydown
notquote
        movfw   archdata
        xorlw   0x25    ;#(num-pad)
        bne     nothash
        bsf     keydownflags,3
        btfss   shiftkeyflags,6
        goto    nodowntranslation
        bsf     translateflags,3
        movlw   0x10    ;`~
        goto    sendarchkeydown
nothash
        movfw   archdata
        xorlw   0x13    ;3#
        bne     notthree
        bsf     keydownflags,4
        btfss   shiftkeyflags,6
        goto    nodowntranslation
        bsf     translateflags,4

        movlw   0x4c
        btfsc   shiftkeyflags,0
        call    sendarchkeyup
        movlw   0x58
        btfsc   shiftkeyflags,1
        call    sendarchkeyup
        movlw   0x1d    ;£¬
        call    sendarchkeydown
        call    delay50ms
        movlw   0x1d    ;£¬
        call    sendarchkeyup
        movlw   0x4c
        btfsc   shiftkeyflags,0
        call    sendarchkeydown
        movlw   0x58
        btfsc   shiftkeyflags,1
        call    sendarchkeydown 
        return 

notthree   

        call    fixifshiftchanged
        
nodowntranslation
        movfw   archdata
sendarchkeydown
        clrf    archerrorflags
        btfss   ps2detectedflags,0
        return
        movwf   archkey

        xorlw   0xff
        skpnz
        return
        swapf	archkey,w
        andlw	0x07
        iorlw	kb_KDDA
        call	txbyte
        call	waitrxBACK
        btfsc   archerrorflags,7
        return
        movfw	archkey
        andlw	0x0f
        iorlw	kb_KDDA
        call	txbyte
        goto	waitrxACK

fixifshiftchanged
        movfw   shiftkeyflags
        xorwf   lastshiftkeyflags,w
        andlw   0x40
        skpnz
        return
        ;if here then shift key changed so check state of translation keys and modify if necessary

        mov     bitmask,0x01
        mov     keycode1,0x46    ;'"
        mov     keycode2,0x12    ;2@
        call    fixuptranslation

        mov     bitmask,0x02
        mov     keycode1,0x12    ;2@
        mov     keycode2,0x46    ;'"
        call    fixuptranslation

        mov     bitmask,0x04
        mov     keycode1,0x10    ;`~
        mov     keycode2,0x1d    ;£¬
        call    fixuptranslation

        mov     bitmask,0x08
        mov     keycode1,0x25    ;#(num-pad)
        mov     keycode2,0x10    ;`~
        call    fixuptranslation

        mov     bitmask,0x10
        mov     keycode1,0x13    ;3#
        mov     keycode2,0xff    ;£ special case ignore
        ;falls into
fixuptranslation
        movfw   bitmask
        andwf   keydownflags,w
        skpnz
        return
        xorwf   keydownflags,f     ;invert keydownflag if set so clear
        andwf   translateflags,w
        bne     untranslate
        movfw   keycode1
        goto    sendarchkeyup
untranslate
        xorwf   translateflags,f   ;invert translateflag if set so clear
        movfw   keycode2
        goto    sendarchkeyup


sendarchkeyupwithtranslation
        movwf   archdata
        movfw   shiftkeyflags
        movwf   lastshiftkeyflags
        call    testshiftkeys
        movfw   shiftkeyflagstemp
        andlw   0x7f
        xorlw   0xff
        andwf   shiftkeyflags,f

        movfw   archdata
        xorlw   0x0f
        bne     notresetup

        call    delay50ms       ; delays hardware reset and software reset

        btfss   specialkeyflags,0
        goto    nospecialkeysup
        bcf     specialkeyflags,0

        bcf     INTCON,7        ;disable interrupts as read/modify/write of porta in irq routine
        mov     FSR,TRISA
        bsf     PORTA,4          ;make sure reset high
        bsf     INDF,4            ;reset an input
        mov     FSR,TRISB
        bsf     INTCON,7

        return
        
notresetup
        movfw   archdata
        xorlw   0x40    ;G ame
        bne     notGup
        btfss   specialkeyflags,1
        goto    nospecialkeysup
        bcf     specialkeyflags,1
        return
notGup
        movfw   archdata
        xorlw   0x30    ;P artial
        bne     notPup
        btfss   specialkeyflags,2
        goto    nospecialkeysup
        bcf     specialkeyflags,2
        return
notPup
        movfw   archdata
        xorlw   0x53    ;N ormal
        bne     nospecialkeysup
        btfss   specialkeyflags,3
        goto    nospecialkeysup
        bcf     specialkeyflags,3
        return
nospecialkeysup


        btfsc   keyboardmode,1
        goto    nouptranslation

        movfw   archdata
        xorlw   0x1d    ;£¬
        bne     notpoundup
        movlw   0x25    ;#
        movwf   archdata
notpoundup

        movfw   archdata
        xorlw   0x46    ;'"
        bne     notquotesup
        btfss   keydownflags,0
        return
        bcf     keydownflags,0
        btfss   translateflags,0
        goto    nouptranslation
        bcf     translateflags,0
        movlw   0x12    ;2@
        goto    sendarchkeyup
notquotesup
        movfw   archdata
        xorlw   0x12    ;2@
        bne     notatup
        btfss   keydownflags,1
        return
        bcf     keydownflags,1
        btfss   translateflags,1
        goto    nouptranslation
        bcf     translateflags,1
        movlw   0x46    ;'"
        goto    sendarchkeyup
notatup
        movfw   archdata
        xorlw   0x10    ;`~
        bne     notquoteup
        btfss   keydownflags,2
        return
        bcf     keydownflags,2
        btfss   translateflags,2
        goto    nouptranslation
        bcf     translateflags,2
        movlw   0x1d    ;£¬
        goto    sendarchkeyup
notquoteup
        movfw   archdata
        xorlw   0x25    ;#
        bne     nothashup
        btfss   keydownflags,3
        return
        bcf     keydownflags,3
        btfss   translateflags,3
        goto    nouptranslation
        bcf     translateflags,3
        movlw   0x10    ;`~
        goto    sendarchkeyup
nothashup
        movfw   archdata
        xorlw   0x13    ;3#
        bne     nothreeup
        btfss   keydownflags,4
        return
        bcf     keydownflags,4
        btfss   translateflags,4
        goto    nouptranslation
        bcf     translateflags,4
        return
nothreeup

        call    fixifshiftchanged

nouptranslation
        movfw   archdata
sendarchkeyup
        clrf    archerrorflags
        btfss   ps2detectedflags,0
        return
        movwf   archkey


        xorlw   0xff
        skpnz
        return
        swapf	archkey,w
        andlw	0x07
        iorlw	kb_KUDA
        call	txbyte
        call	waitrxBACK
        btfsc   archerrorflags,7
        return
        movfw	archkey
        andlw	0x0f
        iorlw	kb_KUDA
        call	txbyte
        goto	waitrxACK


testshiftkeys
        clrf    shiftkeyflagstemp

        movfw   archdata
        xorlw   0x4c    ;left shift
        skpnz
        bsf     shiftkeyflagstemp,0
        
        movfw   archdata
        xorlw   0x58    ;right shift
        skpnz
        bsf     shiftkeyflagstemp,1

        movfw   archdata
        xorlw   0x3b    ;left ctrl
        skpnz
        bsf     shiftkeyflagstemp,2

        movfw   archdata
        xorlw   0x61    ;right ctrl
        skpnz
        bsf     shiftkeyflagstemp,3

        movfw   archdata
        xorlw   0x5e    ;left alt
        skpnz
        bsf     shiftkeyflagstemp,4

        movfw   archdata
        xorlw   0x60    ;right alt
        skpnz
        bsf     shiftkeyflagstemp,5

        movfw   shiftkeyflagstemp
        andlw   0x03
        skpz
        bsf     shiftkeyflagstemp,6     ;set if either shift key pressed

        movfw   archdata
        xorlw   0x0f    ;pausebreak key (ignored in same way as shift keys)
        skpnz
        bsf     shiftkeyflagstemp,7

        return



waitrxBACK
        clrf    backflag
        call    resetrxtimer
waitrxbackloop
        call    rxtimer
        skpnz
        goto	rxtimeout
        btfss 	rxflag,0
        goto  	nobackbytechk
        movfw   rxbuffer
        xorlw   kb_HRST    ;if hrst waiting in rx buffer then abort
        skpnz
        return
nobackbytechk
        btfss 	backflag,0
        goto  	waitrxbackloop
        return

waitrxACK
        clrf    ackflag
        call    resetrxtimer
waitrxackloop
        call    rxtimer
        skpnz
        goto	rxtimeout
        btfss 	rxflag,0
        goto  	noackbytechk
        movfw   rxbuffer
        xorlw   kb_HRST    ;if hrst waiting in rx buffer then abort
        skpnz
        return
noackbytechk
        btfss 	ackflag,0
        goto  	waitrxackloop
        return

rxbytewait
        call    resetrxtimer
rxbytewaitloop
        call    rxtimer
        skpnz
        goto	rxtimeout
        btfss 	rxflag,0
        goto  	rxbytewaitloop
        clrf    rxflag
        movfw 	rxbuffer
        return
rxtimeout
        bsf	archerrorflags,7
        return

resetrxtimer
        clrf    archerrorflags
        clrf	timeout0
        movlw   0xf0               ;about 16ms timeout 
        movwf	timeout1        
        return

rxtimer
        incf 	timeout0,f
        skpnz
        incf	timeout1,f
        return

txbyte
        btfss   PIR1,4
        goto    txbyte
        movwf   TXREG
        return



ps2receive
        clrf	ps2errorflags
        call  	waitps2clocklo
        btfsc	ps2errorflags,7
        return
        movfw	ps2datamask
        andwf	PORTB,w
        skpz
        bsf     ps2errorflags,0         ;rx start bit error
        call  	waitps2clockhi
        clrf	ps2paritycount
        movlw	0x08
        movwf	bitcount
rxbits
        call  	waitps2clocklo
        btfsc	ps2errorflags,7
        return
        bcf     STATUS,C
        movfw	ps2datamask
        andwf	PORTB,w
        beq     rxbitzero
        incf	ps2paritycount,f
        bsf     STATUS,C
rxbitzero
        rrf     ps2data,f
        call  	waitps2clockhi
        decfsz	bitcount,f
        goto	rxbits
        call  	waitps2clocklo
        btfsc	ps2errorflags,7
        return
        movfw	ps2datamask
        andwf	PORTB,w
        btfss	STATUS,Z
        incf	ps2paritycount,f
        btfss   ps2paritycount,0
        bsf     ps2errorflags,1         ;parity error
        call  	waitps2clockhi
        call  	waitps2clocklo
        btfsc	ps2errorflags,7
        return
        movfw	ps2datamask
        andwf	PORTB,w
        skpnz
        bsf     ps2errorflags,2         ;stop bit error
        goto  	waitps2clockhi


ps2txbit
        rrf     ps2data,f
        btfsc   STATUS,C
        incf    ps2paritycount,f        
        btfsc   STATUS,C
        goto    setps2datahi
        goto    setps2datalo

ps2txparity     
        btfss   ps2paritycount,0
        goto    setps2datahi
        goto    setps2datalo

ps2transmit
        movwf   ps2data
        call    delay20us
        call    setps2clocklo          
        call    delay200us
        call    setps2datalo           
        call    delay20us
        call    ps2release   

        clrf	ps2errorflags
        clrf	ps2paritycount
        movlw	0x08
        movwf	bitcount
txbits
        call  	waitps2clocklo
        btfsc	ps2errorflags,7
        return
        call	ps2txbit
        call  	waitps2clockhi
        decfsz	bitcount,f
        goto	txbits
        call  	waitps2clocklo
        btfsc	ps2errorflags,7
        return
        call    ps2txparity
        call  	waitps2clockhi
        call  	waitps2clocklo
        btfsc	ps2errorflags,7
        return
        call    setps2datahi           ; release bus
        call  	waitps2clockhi
        call  	waitps2clocklo
        btfsc	ps2errorflags,7
        return
        movfw	ps2datamask            ;test ack bit on both edges of clock to workaround buggy keyboards            
        andwf	PORTB,w
        beq 	notxackbiterror
        call  	waitps2clockhi         
        movfw	ps2datamask
        andwf	PORTB,w
        skpz
        bsf     ps2errorflags,3        ;tx ack bit error
        return
notxackbiterror
        call  	waitps2clockhi
        return


waitps2clocklo
        movfw	ps2clockmask
        andwf	PORTB,w
        skpnz
        return
        clrf	timeout0
        movlw   0x80       ;0xf8 = 16ms about 256ms timeout
        movwf	timeout1
waitps2clockloloop
        incf 	timeout0,f
        skpnz
        incf	timeout1,f
        skpnz
        goto	ps2timeout
        movfw	ps2clockmask
        andwf	PORTB,w
        bne     waitps2clockloloop
        return
ps2timeout
        call    setps2datahi    ;ensure data not driven low in abort conditions
        bsf     ps2errorflags,7
        return

waitps2clockhi
        movfw	ps2clockmask
        andwf	PORTB,w
        beq     waitps2clockhi
        return

setps2datalo
        movfw	ps2datamask
        xorlw	0xff
        bcf     INTCON,7        ;disable interrupts as read/modify/write of portb in irq routine
        andwf	PORTB,f
        andwf	INDF,f
        bsf     INTCON,7
        return

setps2datahi
        movfw	ps2datamask
        iorwf	INDF,f
        return

ps2inhibit
setps2clocklo
        movfw	ps2clockmask
        xorlw	0xff
        bcf     INTCON,7        ;disable interrupts as read/modify/write of portb in irq routine
        andwf	PORTB,f
        andwf	INDF,f
        bsf     INTCON,7
        return

ps2release
setps2clockhi
        movfw	ps2clockmask
        iorwf	INDF,f
        return

delay1sec
        call	delay250ms
        call	delay250ms	
        call	delay250ms
delay250ms
        movlw	0xfa
        goto    dodelay
delay50ms
        movlw   0x32
dodelay
        movwf	delaycnt2
delayloop
        call	delay1ms
        decfsz  delaycnt2,f
        goto    delayloop
        return
delay1ms
        call	delay200us 
        call	delay200us	
        call	delay200us
        call	delay200us
delay200us 
        movlw   0xc8            ; delay 200us c8/2.5
        movwf   delaycnt
delaycommon   			;5 cycles @20mhz/4 = 1us
        nop
        nop
        decfsz  delaycnt,f
        goto    delaycommon
        return
delay20us  
        movlw   0x14           ; delay 20us
        movwf   delaycnt
        goto    delaycommon


setps2mouse
        movlw	ps2mousedata
        movwf	ps2datamask
        movlw	ps2mouseclock
        movwf	ps2clockmask
        return

setps2keyboard
        movlw	ps2keyboarddata
        movwf	ps2datamask
        movlw	ps2keyboardclock
        movwf	ps2clockmask
        return

        movlw 'A'
        movlw 'R'
        movlw 'C'
        movlw ' '
        movlw 'K'
        movlw 'E'
        movlw 'Y'
        movlw 'B'
        movlw 'O'
        movlw 'A'
        movlw 'R'
        movlw 'D'
        movlw ' '
        movlw '0'
        movlw '.'
        movlw '1'
        movlw '6'
        movlw '('
        movlw 'c'
        movlw ')'
        movlw ' '
        movlw '2'
        movlw '0'
        movlw '1'
        movlw '3'
        movlw ' '
        movlw 'I'
        movlw 'A'
        movlw 'N'
        movlw ' '
        movlw 'B'
        movlw 'R'
        movlw 'A'
        movlw 'D'
        movlw 'B'
        movlw 'U'
        movlw 'R'
        movlw 'Y'

        org     h'2000'
        data    h'000f',h'000f'    ;set id bits
        data    h'000f',h'000f'    ;set id bits
        org     h'2007'
        data    h'3F42'              ;3F47UNPROT set config bits for my programmer

        END
