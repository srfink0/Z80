;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Read a character string from the terminal at 1200 baud, no parity, and 1 start and 1 stop bit  ;
; The string is terminated with the Enter key                                                    ;
; The total delay between bits sent to the terminal should be 830 us (.83 ms)1/1200 = .83        ;
; The Z80 clock will be 2Mhz                                                                     ;  
; Note: the terminal will send bits from the keyboard, starting with the LSB                     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;     
	ORG	0000H

SWITCH_PORT EQU 0
LED_PORT EQU 1
TERMINAL_INPUT_PORT EQU 2
TERMINAL_OUT_PORT EQU 3
HALF_DELAY_COUNT EQU 57
DELAY_COUNT1 EQU 113
DELAY_COUNT2 EQU 238
DELAY_COUNT3 EQU 117
DELAY_COUNT4 EQU 116
DELAY_COUNT5 EQU 119
TITLE_LENGTH EQU EndTitle - title
WELCOME_LENGTH EQU EndGreeting - greeting
PROMPT_LENGTH	EQU	Endprompt - prompt
EOL_LENGTH	EQU	EndOfLine - EOL
MESSAGE_LENGTH EQU EndMessage - message
EXIT_MESSAGE_LENGTH EQU EndExitMessage - exitMessage
Start:
	LD	HL,title
	LD	B,TITLE_LENGTH
	CALL WriteString
ShowPrompt:
	LD	A,0
	OUT	(LED_PORT),A 	;Clear the leds	
	LD	HL,prompt
	LD	B,PROMPT_LENGTH
	CALL WriteString
;Clear the input buffer
	LD	HL,str
	LD	B,80
Clear:
	LD	(HL),10
	INC	HL
	DJNZ Clear
;
	LD	HL,str
	LD	D,0
	CALL ReadChar
;
	LD	HL,str
	LD	B,0
Search:
	LD	A,(HL)
	OR	20H		;To uppercase
	CP	'x'	;Exit program if user enters X or x
	JR	NZ,Continue
	LD	A,0
	OUT	(LED_PORT),A 	;Clear the leds
	LD	HL,exitMessage
	LD	B,EXIT_MESSAGE_LENGTH
	CALL WriteString	
	HALT
Continue:	
	LD	A,13	;Look for <Enter>
	CP	(HL)
	JR	Z,found
	INC	HL
	INC	B
	JR	Search
found:
	IN	A,(SWITCH_PORT)
	CP	1
	JR	Z,DisplayName
	LD	HL,message
	LD	B,MESSAGE_LENGTH
	CALL WriteString
	JP	Wait
DisplayName:
	INC	B
	INC	B
	LD	HL,str
	CALL WriteString
Wait:	
	LD	B,EOL_LENGTH
	LD	HL,EOL
	CALL WriteString
;	
	LD  BC,5000	
	CALL Delay
	
	LD	A,55H
	OUT	(LED_PORT),A 	;Clear the leds
	LD  BC,11000	
	CALL Delay
	JP	ShowPrompt
			
ReadChar:
	LD	B,8		;Initialize the bit counter
	LD	D,0		;Initialize the RESULT
; Look for the Start bit (0)
Loops:
	IN	A,(TERMINAL_INPUT_PORT)
	BIT	7,A	;Test D7
	JP	NZ,Loops	;Received a start bit? No, loop
	LD	C,8
InitLoop:
	DEC	C
	JP	NZ,InitLoop
; 
; ; Wait 1/2 bit time
	; LD	C,HALF_DELAY_COUNT
; Delay1:
	; DEC	C
	; JP	NZ,Delay1	
; ; Verify the Start bit	
	; IN	A,(INPUT_PORT)
	; BIT	7,A	;Test D7
	; JP	NZ,Loops	;Still low? No, start over
;Prepare to read the character

Top:
	SRL	D	;Shift bit of result
	LD	C,DELAY_COUNT1
Delay2:
	DEC	C
	JP	NZ,Delay2
	IN	A,(TERMINAL_INPUT_PORT)
	BIT	7,A	;Test D7
	JP	Z,Reset
	SET	7,D	;Set bit in result
	JP	Bot
Reset:
	RES	7,D	;Too keep the time of the loop the same in either case
	JP	Bot	;Dummy inst
Bot:	
	DEC	B	;Decrement bit counter
	JP	NZ,Top ;Go process the next char bit
	LD	(HL),D	;Store the current read char
	LD	A,D		;Get last char read
	CP	A,13	;Enter (CR) pressed?
	JP	NZ,NotCR	;No, continue
	RET			;Yes, we are done reading the string
NotCR:
	OUT	(LED_PORT),A
	INC	HL
; Wait for 2 stop bits
	LD	C,DELAY_COUNT2
Delay3:
	DEC	C
	JP	NZ,Delay3
	JP	ReadChar
;	
DELAY:
	PUSH	BC
	LD		BC,10	
DELAY_LOOP:	
    DEC     BC
    LD      A,B    				
    OR      C
    JR      NZ,DELAY_LOOP
	POP		BC
	DEC		BC
	LD      A,B    				
    OR      C
    JR      NZ,DELAY
	RET
	
WriteString:
;
NextChar:
	LD	E,(HL)
	PUSH BC
	PUSH HL
	CALL WriteChar
	POP  HL
	POP	 BC
	INC	HL
	DJNZ NextChar
	RET
;
; Subroutine to display one character on the terminal screen
;	
WriteChar:
;
;	Start with high values on the RX pin
;
	LD	D,1
	LD	B,100
Loop:
	LD	A,1
	OUT	(TERMINAL_OUT_PORT),A
	DJNZ Loop
;
; Send a start bit (0)	
;
	LD	A,0
	LD	B,DELAY_COUNT3
	OUT	(TERMINAL_OUT_PORT),A	
StartLoop:
	DEC	B
	JP 	NZ,StartLoop
;	
;	Send a char, one bit at a time with the .83 delay between bits
;
	LD	A,E		;Get Char to display
	LD	H,9
	DEC	H
;
; The Main Loop will take .83 milliseconds	
MainLoop:	
	OUT	(TERMINAL_OUT_PORT),A
	RRCA		;4 t states, GET NEXT BIT OF CHARACTER
	LD	B,DELAY_COUNT4	
DelayLoop:
	DEC	B
	JP	NZ,DelayLoop	;Wait 
	DEC	H
	JP	NZ,MainLoop
;
; Send a stop bit
;
	OUT	(C),D	
	RET
;
title db 'The venerable Z80 Demo',13,10
EndTitle equ $
greeting db 'Welcome '
EndGreeting equ $
Prompt	db	'Please enter your name or X to exit: '
EndPrompt equ $
EOL	db	13,10,'End of Line',13,10
EndOfLine equ $
message db 'Unknown Name',13,10
EndMessage equ $
ExitMessage db 13,10,'Have a nice Day!',13,10
EndExitMessage equ $
; RAM AREA (A15 is high)
	ORG	8000H
;SwitchSetting ds 1	
str DS  80
 		
	END	Start
	
	

	
		
		
				
				
	
			
	
	
		