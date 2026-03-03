TITLE Number Reverser

; Author: Anthony Sokry
; Last Modified: 03/03/26
; Description: This program will read an ASCII-formatted file containg 
; a list of comma-separated signed integers. Then prints them out in 
; reverse ordering as strings to the terminal window. If the file has 
; multiple line inputs, then each line will be outputted separately.
; (e.g. "Input Line 1" becomes "Reversed Input Line 1", 
; "Input Line 2" becomes "Reversed Input Line 2", etc.)

INCLUDE Irvine32.inc

; ---------------------------------------------------------------------------------
; Name: mGetString
;
; Get a string from user input and saves it.
;
; Preconditions: prompt and userInput must be a string of type BYTE. strLength and 
;	byteCount are integers.
;
; Receives:
;	prompt		= prompt address
;	userInput	= string address
;	strLength	= string length
;	byteCount	= byte count
;
; Returns: 
;	userInput	= user inputted string
;	byteCount	= amount of bytes read
; ---------------------------------------------------------------------------------
mGetString MACRO prompt, userInput, strLength, byteCount
	; Push registers
	PUSH    EDX
	PUSH	EAX
	PUSH	ECX

	; Display prompt
	mDisplayString prompt

	; Get file name
	MOV		EDX, userInput
	MOV		ECX, strLength
	CALL	ReadString
	MOV		byteCount, EAX
	CALL	CrLf

	; Pop registers
	POP		ECX
	POP		EAX
	POP		EDX
ENDM

; ---------------------------------------------------------------------------------
; Name: mReadFile
;
; Open and read a file.
;
; Preconditions: all parameters are a string of type BYTE.
;
; Receives:
;	name		= file name address
;	nameError	= file name error message address
;	buffer		= file buffer address
;	readError	= read error message address
;
; Returns: 
;	buffer		= contents of file compressed as a single line
; ---------------------------------------------------------------------------------
mReadFile MACRO	name, nameError, buffer, readError
	LOCAL _ValidName, _Close, _Quit			; Local Labels
	
	; Push Registers
	PUSH	EDX
	PUSH	EAX
	PUSH	ECX

	; Attempt to Open File
	MOV		EDX, name
	CALL	OpenInputFile

	; Verify File
	CMP		EAX, INVALID_HANDLE_VALUE
	JNE	   _validName						; filename is valid
	mDisplayString nameError  
	CALL	CrLf
	JMP    _Quit

	; Read File
_ValidName:
	MOV		EDX, buffer 
	MOV		ECX, MAX_FILE_SIZE-1
	CALL	ReadFromFile
	JNC    _Close							;jump if errors
	mDisplayString readError
	CALL	CrLf
	JMP    _Quit

	; Quit Program
	_Quit:
	Invoke ExitProcess,0

	; Close File
	_Close:
	CALL	CloseFile

	; Pop Registers
	POP		ECX
	POP		EAX
	POP		EDX
ENDM

; ---------------------------------------------------------------------------------
; Name: mDisplayString
;
; Prints provided string.
;
; Preconditions: parameter is a string of type BYTE.
;
; Receives:
;	string		= string address
; ---------------------------------------------------------------------------------
mDisplayString MACRO string
	; Push Registers
	PUSH	EDX

	; Print String
	MOV		EDX, string
	CALL	WriteString

	; Pop Registers
	POP		EDX
ENDM

; ---------------------------------------------------------------------------------
; Name: mDisplayChar
;
; Prints provided character.
;
; Preconditions: parameter is a character.
;
; Receives:
;	character	= character to be printed
; ---------------------------------------------------------------------------------
mDisplayChar MACRO character
	; Push Registers
	PUSH	EAX

	; Print Character
	MOV		AL, character
	CALL	WriteChar

	; Pop Registers
	POP		EAX
ENDM

; Main Constants
INTS_PER_LINE = 24
MAX_INT = 200
DELIMITER = ','
MAX_FILE_SIZE = 5000

; ASCII Code
ASCII_MINUS = 45
ASCII_COMMA = 44
ASCII_ZERO = 48
CARRIAGE_RETURN = 13

; Sentinel value for terminating reverse order
SENTINEL_VALUE = 222

.data
; Prompt
prompt			BYTE	"Enter file name (include extension): ",0
						
; File Related
fileName		BYTE	21 DUP(0)
fileBuffer      BYTE    MAX_FILE_SIZE DUP(?)
bytesRead		DWORD	?
fileNameError   BYTE    "Invalid fileName... Please ensure the file is in the same directory as the ASM file.",13,10,0
fileReadError   BYTE    "Error in Reading File.",0

; Integer Array
intArray		SDWORD	1000 DUP(?)

; Print Strings
reverseOrder	BYTE	"Reverse Order:",13,10,0
endProgram		BYTE	"!!!End of Program!!!",13,10,0

.code
main PROC

	; Get File Name
	mGetString OFFSET prompt, OFFSET fileName, SIZEOF fileName-1, bytesRead

	; Read File
	mReadFile OFFSET fileName, OFFSET fileNameError, OFFSET fileBuffer, OFFSET fileReadError

	; Parse Ints
	PUSH	OFFSET fileBuffer
	PUSH	OFFSET intArray
	CALL	ParseIntsFromString

	; Print Ints in Reverse
	PUSH	OFFSET intArray
	CALL	WriteIntsReverse

	Invoke ExitProcess,0
main ENDP

; ---------------------------------------------------------------------------------
; Name: ParseIntsFromString
;
; Parse through a string containing integer readings and converts the individual   
;	integers from ASCII to numeric value, then stores them in an array. 
;
; Preconditions: 1st parameter must be a string of type BYTE and 2nd parameter is 
;	an array of type SDWORD
;
; Receives:
;	[EBP + 12]	= file buffer address
;	[EBP + 8]	= integer array address
;
; Returns: 
;	[EBP + 8]	= array of integers as numeric values
; ---------------------------------------------------------------------------------
ParseIntsFromString PROC
	; Push Registers
	PUSH	EBP
	MOV		EBP, ESP
	PUSH	EDI
	PUSH	ESI
	PUSH	ECX
	PUSH	EAX
	PUSH	EBX
	PUSH	EDX

	; Register Setup
	MOV		EDI, [EBP + 8]
	MOV		ESI, [EBP + 12]
	MOV		ECX, 0
	MOV		EBX, 0
	MOV		EDX, 0

	; Start of loop
	CLD
_Loop:
	LODSB

	; Check if character is a BACKSLASH
	CMP		AL, CARRIAGE_RETURN	
	JNE	   _Continue
_GetNextInt:
	LODSB
	INC		ECX								; Increment pass \r\n in list
	CMP		ECX, 2
	JE	   _Continue
	JMP	   _GetNextInt
_Continue:
	MOV		ECX, 0

	; Check if character is a Null-Terminate
	CMP		AL, 0
	JE	   _End

	; Check if character is a MINUS
	CMP		AL, ASCII_MINUS
	JE	   _NegativeIsTrue

	; Check if character is a COMMA
	CMP		AL, ASCII_COMMA
	JE	   _SaveToArray

	; Check if previous digit is zero (not ascii zero)
	CMP		EDX, 0
	JNE	   _ConcatenateDigit
	SUB		AL, ASCII_ZERO					; Convert character to number
	MOVSX	AX, AL
	MOVSX	EAX, AX
	ADD		EDX, EAX						; Save number to EDX
	JMP	   _Loop

	; Concatenate Digits
_ConcatenateDigit:
	SUB		AL, ASCII_ZERO
	MOVSX	AX, AL
	MOVSX	EAX, AX
	IMUL	EDX, 10
	ADD		EDX, EAX
	JMP	   _Loop

	; Remember Sign
_NegativeIsTrue:
	MOV		EBX, 1
	JMP	   _Loop
	
	; Save to Array
_SaveToArray:
	MOV		EAX, EDX
	CMP		EBX, 0							; check if number is negative
	JE	   _Save
	NEG		EAX								; make integer into negative integer
_Save:
	MOV		[EDI], EAX
	ADD		EDI, 4
	MOV		EBX, 0
	MOV		EDX, 0
	JMP	   _Loop

	; Append SENTINEL_VALUE to array, 222 > 200(MAX_INT)
_End:
	MOV		ECX, INTS_PER_LINE
	MOV		EBX, SENTINEL_VALUE
_Fill:
	MOV		[EDI], EBX
	ADD		EDI, 4
	LOOP   _Fill

	; Pop Registers
	POP		EDX
	POP		EBX
	POP		EAX
	POP		ECX
	POP		ESI
	POP		EDI
	POP		EBP
	RET		8
ParseIntsFromString ENDP

; ---------------------------------------------------------------------------------
; Name: WriteIntsReverse
;
; Prints a list of integer values in the reverse order.
;
; Preconditions: parameter is an array of type SDWORD.
;
; Receives:
;	[EBP + 8]	= integer array address
; ---------------------------------------------------------------------------------
WriteIntsReverse PROC
	; Push Registers
	PUSH	EBP
	MOV		EBP, ESP
	PUSH	ESI
	PUSH	ECX
	PUSH	EAX
	PUSH	EBX

	; Register Setup
	MOV		ESI, [EBP + 8]
	ADD		ESI, (INTS_PER_LINE-1)*4		; Start at last int
	MOV		ECX, INTS_PER_LINE

	; Print "Reverse Order:"
	mDisplayString OFFSET reverseOrder

	; Check if int is SENTINEL_VALUE
_SentinelCheck:
	MOV		EBX, [ESI]
	CMP		EBX, SENTINEL_VALUE
	JE	   _End

	; Print int as string
_Loop:
	PUSH	[ESI]
	CALL	WriteVal						; Convert number to string
	mDisplayChar DELIMITER
	SUB		ESI, 4
	LOOP   _Loop
	CALL	CrLf

	; Reset and move to next last int
	MOV		ECX, INTS_PER_LINE
	ADD		ESI, (INTS_PER_LINE*4)*2
	JMP	   _SentinelCheck

	; Print end message
_End:
	CALL	CrLf
	mDisplayString OFFSET endProgram

	; Pop Registers
	POP		EBX
	POP		EAX
	POP		ECX
	POP		ESI
	POP		EBP
	RET		4
WriteIntsReverse ENDP

; ---------------------------------------------------------------------------------
; Name: WriteVal
;
; Converts provided integer value to a string and prints it out.
;
; Preconditions: parameter is an integer of type SDWORD.
;
; Receives:
;	[EBP + 8]	= integer value
; ---------------------------------------------------------------------------------
WriteVal PROC
	; Automatically updates EBP and pushes 16 bytes to stack
	LOCAL inString[8]:BYTE, outString[8]:BYTE 
	
	; Push Registers
	PUSH	EAX
	PUSH	EDI
	PUSH	EBX
	PUSH	EDX
	PUSH	ECX
	PUSH	ESI

	; Register Setup
	MOV		EAX, [EBP + 8]
	LEA		EDI, inString
	MOV		EBX, 10
	MOV		ECX, 0
	MOV		EDX, 0
	MOV		ESI, 0

	CLD
	; Check if int is zero
	CMP		EAX, 0
	JE	   _Save

	; Check if int > zero
	CMP		EAX, 0
	JG	   _Loop

	; If int < 0, remember sign and negate the int
	INC		ESI
	NEG		EAX

	; Start of loop
_Loop:
	MOV		EDX, 0
	DIV		EBX

	; Check if remainder is zero
	CMP		EDX, 0
	JE	   _CheckQuotient
	JMP	   _Save

	; Check if quotient is zero
_CheckQuotient:
	CMP		EAX, 0
	JE	   _EndOfString

	; Save character to inString
_Save:
	ADD		EDX, ASCII_ZERO					; Convert to character
	PUSH	EAX
	MOV		EAX, EDX
	STOSB									; Store character to inString
	INC		ECX
	POP		EAX
	JMP	   _Loop

	; Add sign, if any, and null-terminate to inString
_EndOfString:
	CMP		ESI, 0
	JE	   _Continue
	MOV		AL, '-'
	STOSB									; If negative, store '-' to inString
	INC		ECX
_Continue:
	MOV		AL, 0							; Store null-terminate to inString
	STOSB

	; Get offsets of strings
	LEA		ESI, inString		
	ADD		ESI, ECX
	DEC		ESI								; Offset of last character in inString
	LEA		EDI, outString					; Offset of 1st character in outString

	; Reverse the string and save to outString
_RevLoop:
	STD
    LODSB
    CLD
    STOSB
	LOOP   _RevLoop
	MOV		AL, 0
	STOSB

	; Print outString
	LEA		EDI, outString
	mDisplayString EDI
	
	; Pop Registers
	POP		ESI
	POP		ECX
	POP		EDX
	POP		EBX
	POP		EDI
	POP		EAX

	; For local variables, pop 16 bytes from stack
	ADD		ESP, 16
	RET		4
WriteVal ENDP

END main
