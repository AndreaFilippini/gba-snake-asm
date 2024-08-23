	.text
	.align	2
	.global	main
	.code	16
	.thumb_func
	.type	main, %function

	.equ REG_BASE, 		0x04000000
	.equ PLTT,		0x05000000
	.equ VRAM,		0x06000000
	.equ RANDOM,		0x02000000
	.equ TILE_SIZE,		0x20
	.equ TOTAL_TILE,	0x4
	.equ DISPLAY_WIDTH,	240
	.equ DISPLAY_HEIGHT,	160
	.equ DEF_MAX_LEN,	200
	.equ DEF_INIT_LEN,	5
	.equ MAX_LENGTH,	0x02010000
	.equ SNAKE_LENGTH,	0x02010004
	.equ SNAKE_DIR_X,	0x02010008
	.equ SNAKE_DIR_Y,	0x0201000C
	.equ SNAKE_LOC_X,	0x02010010
	.equ SNAKE_LOC_Y,	0x02010014
	.equ APPLE_LOC_X,	0x02020000
	.equ APPLE_LOC_Y,	0x02020004
	.equ GAME_SPEED,	0x02030000
	.equ PROC_INPUT,	0x02030004
	.equ SPEED_VALUE,	0x3
	.equ KEY_A,		0x01
	.equ KEY_B,		0x02
	.equ KEY_RIGHT,		0x10
	.equ KEY_LEFT,		0x20
	.equ KEY_UP,		0x40
	.equ KEY_DOWN,		0x80

main:
	push {r0-r1, lr}
.reset:	
	bl .random			@ set random seed
	bl .enable_bg			@ enable screen visualization
	bl .load_pal			@ load palette
	bl .load_all_tile		@ load tile of snake, walls and apple
	bl .set_snake_prop		@ set initial values for snake
	bl .spawn_apple			@ spawn apple at random location
.loop:
	@ ;;;;;;;;;;;;;; MAIN GAME ;;;;;;;;;;;;;;;
	bl .vid_sync			@ synchronization before loading screen elements
	bl .key_pressed			@ process input
	bl .incr_timer			@ increment timer for game speed
	ldr r1, = SPEED_VALUE		@ load speed of the game
	cmp r0, r1			@ compare speed with internal timer
	ble .loop			@ continue waiting cycle until the timer reaches the value of the game speed

	bl .reset_timer			@ reset internal timer to zero
	bl .check_eat			@ check if the snake eat the apple
	cmp r0, #0			@ if the return value is zero, it means the snake didn't eat the apple
	beq .loop_render		@ continue with the rendering of the screen elements

	bl .add_snake_block		@ otherwise, increase the length of the snake
	bl .spawn_apple			@ generates a new apple

	.loop_render:
	bl .clean_buffer		@ clean screen buffer
	bl .render_apple		@ render apple to screen
	bl .snake_render		@ render snake to screen
	bl .snake_update		@ update snake position
	bl .render_walls		@ render walls to screen
	bl .render_screen		@ render all elements to screen
	bl .reset_processed_input	@ reset internal flag to receive new inputs

	ldr r0, .SNAKE_X		@ pointer to x location of the snake's head
	ldr r1, .SNAKE_Y		@ pointer to y location of the snake's head
	ldr r0, [r0]			@ x location of the snake's head
	ldr r1, [r1]			@ y location of the snake's head
	bl .get_tile_index		@ get tile index at snake's head location
	cmp r0, #1			@ if it's a wall
	beq .end_game			@ the game ends
	bl .snake_eat_itself		@ check if the snake ate itself
	cmp r0, #1			@ if the return value is 1, it means that the snake has eaten a part of itself
	beq .end_game			@ so the game ends
	b .loop				@ otherwise, continue the game

.end_game:
	bl .clean_snake_blocks		@ clean snake old data from previous game
	b .reset			@ return to reset part to start a new game
	pop {r0-r1, pc}

@ // VBlank timing
.vid_sync:
	push {r0-r1, lr}
	ldr r0, .VCOUNT			@ internal counter for synchronisation with screen display
	.vid_sync_loop:
		ldrh r1, [r0]		@ get the counter value
		cmp r1, #160		@ compare it with the value 160
		bge .vid_sync_loop      @ if it is greater, it means that the synchronisation cycle is over
	.vid_sync_loop_2:		@ i need to wait for the next one
		ldrh r1, [r0]		@ get the counter value
		cmp r1, #160		@ compare it with the value 160
		blt .vid_sync_loop_2	@ wait for the next synchronisation cycle while the counter value is less than 160
	pop {r0-r1, pc}

@ // enable BG0 and set its properties
.enable_bg:
	push {r0-r1, lr}
	ldr r0, .DISPCNT		@ load the pointer responsible for managing the screen I/O
	ldr r1, = (0 | (1 << 8))	@ set the eighth bit to 1 to activate BG0 and the first three bits to 0 to activate tilemap mode
	strh r1, [r0]			@ write the value into the memory
	ldr r0, .BG0CNT			@ load the pointer responsible for managing the BG0
	ldr r1, = (8 << 8)		@ set the eighth bit to 8 to indicate the memory area from which to take the raw
	strh r1, [r0]			@ write the value into the memory
	pop {r0-r1, pc}

.text
.align	2
	.DISPCNT: 	.word REG_BASE + 0x0
	.VCOUNT: 	.word REG_BASE + 0x6
	.BG0CNT: 	.word REG_BASE + 0x8

@ // load color palette for snake walls and apple
.load_pal:
	push {r0-r4, lr}
	ldr r0, .PALETTE		@ load the pointer to the memory area responsible for palette storage
	ldr r1, .CLR_WHITE		@ load the value that maps the white colour in AGB format
	ldr r2, .CLR_RED		@ load the value that maps the red colour in AGB format
	ldr r3, .CLR_GREEN		@ load the value that maps the green colour in AGB format
	ldr r4, .CLR_GREEN_W		@ load the value that maps the dark green colour in AGB format
	strh r1, [r0]			@ write the value of white colour in the memory
	strh r2, [r0, #2]		@ write the value of white red in the memory, 2 bytes forward of the pointer
	strh r3, [r0, #4]		@ write the value of white green in the memory, 4 bytes forward of the pointer
	strh r4, [r0, #6]		@ write the value of white dark green in the memory, 6 bytes forward of the pointer
	pop {r0-r4, pc}

.text
.align	2
	.PALETTE: 	.word PLTT + 0x2
	.CLR_WHITE:	.word (31 | (31 << 5) | (31 << 10))
	.CLR_RED:	.word (28 | (10 << 5) | (10 << 10))
	.CLR_GREEN_W:	.word (8 | (24 << 5) | (8 << 10))
	.CLR_GREEN:	.word (10 | (28 << 5) | (10 << 10))

@ // load number of tiles specified
.load_all_tile:
	push {r0, lr}
	mov r0, #0			@ set tile counter to 0
	.load_tile_loop:
		add r0, r0, #1		@ increment the counter value
		bl .load_single_tile	@ add a tile into the memory
		cmp r0, #TOTAL_TILE	@ compare the value of the counter with the total number of tiles
		bne .load_tile_loop	@ if it's different, keep adding tiles in the memory
	pop {r0, pc}

@ // load 8x8 tile based on value of first arg
.load_single_tile:
	push {r0-r5, lr}		@ function to build 32 bytes, so a single 8x8 tile, with the same value as the counter for each digit
	mov r5, r0			@ move the counter value to a temporary register
	lsl r1, r0, #4			@ shift counter value by 4 bits to the left
	lsl r2, r0, #8			@ shift counter value by 8 bits to the left
	lsl r3, r0, #12			@ shift counter value by 12 bits to the left
	orr r0, r1			@ add the same number of the counter to itself (e.g. counter = 1, r0 = 11)
	orr r0, r2			@ add the same counter value in front to the previous value (e.g. counter = 1, r0 = 1X1)
	orr r0, r3			@ add the same counter value in front to the previous value (e.g. counter = 1, r0 = 1XX1)
	lsl r1, r0, #8			@ shift the 16 bits containing the same value for each positional digit by 8 bit
	orr r0, r1			@ make the or with itself, adding the same value in front (e.g. r1 = 11110000, r0 = 11111111)
	lsl r1, r0, #8			@ use the same mechanism to generate a final value of 4 bytes
	orr r0, r1			@ make the or with itself, adding the same value in front (e.g. r1 = 1111111100000000, r0 = 1111111111111111)
	mov r2, #(TILE_SIZE / 4)	@ the size of a tile is 32bit, but writing 4 bytes at each iteration, divide the total size by 4
	ldr r1, .VRAM_TILE		@ load the pointer to the area responsible for tile storage
	mov r4, #TILE_SIZE		@ loading the size of a single tile
	mul r5, r4			@ multiply it by the original counter value, obtaining the relative offset from which to start writing
	add r1, r1, r5			@ add the offset to the base pointer
	.single_tile_loop:
		str r0, [r1]		@ write the 4 bytes previously generated in the memory
		add r1, r1, #4		@ incrementing the pointer by 4 bytes
		sub r2, r2, #1		@ decrement the counter
		cmp r2, #0		@ compare the counter value with zero
		bne .single_tile_loop	@ if not, continue to generate the tile in the memory
	pop {r0-r5, pc}

.text
.align	2
	.VRAM_TILE: 	.word VRAM

@ // render tile on screen based on x, y and index
.render_tile:
	push {r0-r3, lr}
	ldr r3, .VRAM_BUFF		@ load the pointer to the area responsible for bg0's raw
	lsl r0, r0, #1			@ multiply the x coordinate by two, because each tile occupies two bytes
	lsl r1, r1, #6			@ multiply the y coordinate by 64, because each line occupies 64 bytes
	add r0, r0, r1			@ add the offset generated by the x coordinate to the base pointer
	add r0, r0, r3			@ add the offset generated by the y coordinate to the base pointer
	strh r2, [r0]			@ write the tile index at the offset identified by the pointer
	pop {r0-r3, pc}

@ // get tile on screen based on x and y
.get_tile_index:
	push {r1-r3}
	ldr r3, .VRAM_BUFF		@ load the pointer to the area responsible for bg0's raw
	lsl r0, r0, #1			@ multiply the x coordinate by two, because each tile occupies two bytes
	lsl r1, r1, #6			@ multiply the y coordinate by 64, because each line occupies 64 bytes
	add r0, r0, r1			@ add the offset generated by the x coordinate to the base pointer
	add r0, r0, r3			@ add the offset generated by the y coordinate to the base pointer
	ldrh r0, [r0]			@ read the tile index at the offset identified by the pointer and return it
	pop {r1-r3}
	bx lr

@ // copy from buffer to bg0
.render_screen:
	push {r0-r3, lr}
	ldr r0, .VRAM_BUFF		@ load the screen buffer pointer
	ldr r1, .VRAM_BG0		@ load the pointer to the raw bg0
	ldr r2, = 0x2000		@ load the size to be copied from the source to the destination, divided by two
	swi 0xB				@ copying 2 bytes at a time from r0 ro r1
	pop {r0-r3, pc}

@ // clean buffer
.clean_buffer:
	push {r0-r3, lr}
	ldr r0, .VRAM_EMPTY		@ load the pointer to the empty buffer
	ldr r1, .VRAM_BUFF		@ load the screen buffer pointer
	ldr r2, = 0x2000		@ load the size to be copied from the source to the destination, divided by two
	swi 0xB				@ copying 2 bytes at a time from r0 ro r1
	pop {r0-r3, pc}

.text
.align	2
	.VRAM_BG0: 	.word VRAM + 0x4000
	.VRAM_BUFF: 	.word VRAM + 0x8000
	.VRAM_EMPTY: 	.word VRAM + 0xC000
	.DMASRC: 	.word REG_BASE + 0xB0
	.DMADST: 	.word REG_BASE + 0xB4
	.DMACNT: 	.word REG_BASE + 0xB8

@ // render wall on screen border
.render_walls:
	push {r0-r2, lr}				@ function to render walls around the edges
	mov r0, #0					@ initialize the counter for the x coordinate to 0
	mov r1, #0					@ initialize the counter for the y coordinate to 0
	mov r2, #1					@ index for the wall tile
	.render_walls_loop:
		cmp r1, #0				@ if i'm in the upper edge of the screen
		beq .put_tile				@ then add a tile
		cmp r1, #((DISPLAY_HEIGHT / 8) - 1)	@ if i'm in the lower edge of the screen
		beq .put_tile				@ then add a tile
		cmp r0, #0				@ if i'm in the left edge of the screen
		beq .put_tile				@ then add a tile
		cmp r0, #((DISPLAY_WIDTH / 8) - 1)	@ if i'm not in the right edge of the screen
		bne .incr_counter			@ increase the counters and continue to iterate
		.put_tile:
		bl .render_tile				@ add the tile to the render buffer
		.incr_counter:
			add r0, r0, #1			@ increment x counter
			cmp r0, #(DISPLAY_WIDTH / 8)	@ compare its value with the maximum value possibile, specifically the right edge
			bne .render_walls_loop		@ if i haven't reached the edge yet, keep iterating
			mov r0, #0			@ otherwise, set the x counter to zero
			add r1, r1, #1			@ and increment the counter of y coordinate
			cmp r1, #(DISPLAY_HEIGHT / 8)	@ compare the y value with the maximum value possibile, specifically the bottom edge
			bne .render_walls_loop 		@ if i haven't reached the edge yet, keep iterating
	pop {r0-r2, pc}

@ // generate random values	
.random:
	push {r1-r2}
	ldr r0, .RANDOM_VAL		@ load pointer to the random value location
	ldr r1, [r0]			@ read its value
	ldr r2, .SEED			@ load the value of the random seed
	mul r1, r2			@ multiply that by the old random value
	ldr r2, = 0x1073		@ load another arbitrary value
	add r1, r2			@ and add it to the final random value
	str r1, [r0]			@ and write it back to the memory
	lsr r0, r1, #16			@ isolate the most significant part, shift its value by 16 bit on the right, and return it
	pop {r1-r2}
	bx lr

.text
.align	2
	.RANDOM_VAL: 	.word RANDOM
	.SEED:		.word 0x41C64E61

@ // get new random apple location 
.spawn_apple:
	push {r0-r3, lr}
	bl .random				@ get a random value
	mov r1, #((DISPLAY_WIDTH / 8) - 2)	@ set the range of the possible value of x as (x - 2), where 2 are the two edge walls
	bl __aeabi_uidivmod			@ perform the modulo operation and get the rest
	add r0, r1, #1				@ shift the random x value by 1, so as to fall in the useful part of the arena

	push {r0}				@ save the x value on the stack for later
	bl .random				@ get a random value
	mov r1, #((DISPLAY_HEIGHT / 8) - 2)	@ set the range of the possible value of y as (x - 2), where 2 are the two edge walls
	bl __aeabi_uidivmod			@ perform the modulo operation and get the rest
	add r1, r1, #1				@ shift the random y value by 1, so as to fall in the useful part of the arena
	pop {r0}				@ restore the previous x value from the stack

	ldr r2, .APPLE_X			@ load the pointer of apple x coordinate
	ldr r3, .APPLE_Y			@ load the pointer of apple y coordinate
	str r0, [r2]				@ write the apple x coordinate with the new random value
	str r1, [r3]				@ write the apple y coordinate with the new random value
	pop {r0-r3, pc}

@ // spawn apple tile
.render_apple:
	push {r0-r2, lr}
	ldr r0, .APPLE_X		@ load the pointer of apple x coordinate
	ldr r1, .APPLE_Y		@ load the pointer of apple y coordinate
	ldr r0, [r0]			@ read the x coordinate of the apple
	ldr r1, [r1]			@ read the y coordinate of the apple
	mov r2, #2			@ set the tile index of the apple
	bl .render_tile			@ render the apple tile in the buffer
	pop {r0-r2, pc}

@ // check if apple was eaten by the snake
.check_eat:
	push {r1-r4}
	mov r4, #0			@ assume initially that the snake didn't eat the apple, with value 0
	ldr r0, .APPLE_X		@ load the pointer of apple x coordinate
	ldr r1, .APPLE_Y		@ load the pointer of apple y coordinate
	ldr r2, .SNAKE_X		@ load the pointer of snake's head x coordinate
	ldr r3, .SNAKE_Y		@ load the pointer of snake's head y coordinate
	ldr r0, [r0]			@ read the x coordinate of the apple
	ldr r1, [r1]			@ read the y coordinate of the apple
	ldr r2, [r2]			@ read the x coordinate of the snake's head
	ldr r3, [r3]			@ read the y coordinate of the snake's head
	cmp r0, r2			@ compare the x coordinate of the apple with the one of snake's head
	bne .check_eat_return		@ if they are different, the snake didn't eat the apple
	cmp r1, r3			@ compare the y coordinate of the apple with the one of snake's head
	bne .check_eat_return		@ if they are different, the snake didn't eat the apple
	mov r4, #1			@ the coordinates are equal, the snake ate the apple and return 1 
	.check_eat_return:
	mov r0, r4			@ move the return value from the temporary register and return it
	pop {r1-r4}
	bx lr
.text
.align	2
	.APPLE_X: 	.word APPLE_LOC_X
	.APPLE_Y:	.word APPLE_LOC_Y

@ // increment timer speed
.incr_timer:
	push {r1}
	ldr r1, .SPEED			@ load the pointer of the counter that contains the speed of the game
	ldrh r0, [r1]			@ read its value
	add r0, r0, #1			@ increment the internal timer
	strh r0, [r1]			@ write the new incremented value into the memory
	pop {r1}			@ and return it
	bx lr

@ // reset timer speed
.reset_timer:
	push {r0, lr}
	ldr r0, .SPEED			@ load the pointer of the counter that contains the speed of the game
	mov r1, #0			@ set the speed counter value to zero
	str r1, [r0]			@ and write the new value into the memory
	pop {r0, pc}

@ // add new snake block
.add_snake_block:
	push {r0-r1, lr}
	ldr r0, .SNAKE_LEN		@ load the pointer that contains the snake's length
	ldr r1, [r0]			@ read its value
	add r1, r1, #1			@ increment that value
	str r1, [r0]			@ and write it into the memory
	pop {r0-r1, pc}

@ // check if the snake eats itself
.snake_eat_itself:
	push {r1-r7}
	mov r7, #1				@ assume initially that the snake ate itself, with value 1
	ldr r0, .SNAKE_X			@ load the pointer of snake's head x coordinate
	ldr r1, .SNAKE_Y			@ load the pointer of snake's head y coordinate
	ldr r2, .SNAKE_LEN			@ load the pointer that contains the snake's length	
	ldr r2, [r2]				@ read the current snake length
	ldr r3, [r0]				@ read the x coordinate of the snake's head
	ldr r4, [r1]				@ read the y coordinate of the snake's head

	.snake_eat_itself_loop:
		add r0, r0, #8			@ increase the x coordinate pointer to the next piece of the snake
		add r1, r1, #8			@ increase the y coordinate pointer to the next piece of the snake
		ldr r5, [r0]			@ read the x coordinate of the next piece of the snake
		ldr r6, [r1]			@ read the y coordinate of the next piece of the snake
		cmp r3, r5			@ compare the x coordinate of the current piece with the one of the head
		bne .snake_eat_itself_incr	@ if they are not equal, increase the values of the counter
		cmp r4, r6			@ compare the y coordinate of the current piece with the one of the head
		beq .snake_eat_itself_return	@ if they are equal, the snake ate a piece of itself

		.snake_eat_itself_incr:
		sub r2, r2, #1			@ otherwise, decrease the pieces counter
		cmp r2, #0			@ compare the counter value with zero
		bne .snake_eat_itself_loop	@ if it's different, it means that there are still some snake pieces to iterate on

	.snake_eat_itself_no:
	mov r7, #0				@ if i didn't found any match, it means the snake did not eat itself and return 0
	
	.snake_eat_itself_return:
	mov r0, r7				@ move the return value from the temporary register and return it
	pop {r1-r7}
	bx lr

@ // clean snake blocks locations x and y from the memory
.clean_snake_blocks:
	push {r0-r3, lr}
	ldr r0, .SNAKE_X			@ load the pointer of snake's head x coordinate
	ldr r1, .SNAKE_Y			@ load the pointer of snake's head y coordinate
	ldr r2, .SNAKE_LEN			@ load the pointer that contains the snake's length
	ldr r2, [r2]				@ read the current snake length
	mov r3, #0				@ set the register to a null value
	.clean_snake_blocks_loop:
		str r3, [r0]			@ write the null value to x coordinate of the current piece
		str r3, [r1]			@ write the null value to y coordinate of the current piece
		add r0, r0, #8			@ increase the x coordinate pointer to the next piece of the snake
		add r1, r1, #8			@ increase the y coordinate pointer to the next piece of the snake
		sub r2, r2, #1			@ decrease the pieces counter
		cmp r2, #0			@ compare the counter value with zero
		bne .clean_snake_blocks_loop	@ if it's different, it means that there are still some snake pieces to iterate on
	pop {r0-r3, pc}

@ // update snake position
.snake_update:
	push {r0-r6, lr}
	ldr r0, .SNAKE_X			@ load the pointer of snake's head x coordinate
	ldr r1, .SNAKE_Y			@ load the pointer of snake's head y coordinate
	ldr r2, .SNAKE_LEN			@ load the pointer that contains the snake's length
	ldr r2, [r2]				@ read the current snake length
	.snake_update_loop:
		sub r2, r2, #1			@ decrease the pieces counter
		cmp r2, #0			@ compare the counter value with zero
		beq .snake_update_set		@ if it's different, it means that there are still some snake pieces to iterate on
		sub r3, r2, #1			@ get the previous index of the current snake piece
		lsl r4, r2, #3			@ get the offset of the current snake piece
		lsl r3, r3, #3			@ get the offset of the previous snake piece
		ldr r5, [r0, r3]		@ read the x coordinate of the previous piece
		ldr r6, [r1, r3]		@ read the y coordinate of the previous piece
		str r5, [r0, r4]		@ write the x value of the previous piece at the memory location of the current piece
		str r6, [r1, r4]		@ write the y value of the previous piece at the memory location of the current piece
		b .snake_update_loop		@ continue to iterate on every snake piece

	.snake_update_set:			@ after shifting all the coordinates of a position, update the head's position
	ldr r2, .DIR_X				@ load the pointer that contains the speed value on the x-axis
	ldr r3, [r0]				@ read the x coordinate of snake's head
	ldr r4, [r2]				@ read the speed value on the x-axis
	add r3, r3, r4				@ add it to the current position of the snake's head
	str r3, [r0]				@ write the new value in the memory
	ldr r2, .DIR_Y				@ load the pointer that contains the speed value on the y-axis
	ldr r3, [r1]				@ read the y coordinate of snake's head
	ldr r4, [r2]				@ read the speed value on the y-axis
	add r3, r3, r4				@ add it to the current position of the snake's head
	str r3, [r1]				@ write the new value in the memory
	pop {r0-r6, pc}

@ // show snake on screen
.snake_render:
	push {r0-r6, lr}
	ldr r5, .SNAKE_X			@ load the pointer of snake's head x coordinate
	ldr r6, .SNAKE_Y			@ load the pointer of snake's head y coordinate
	ldr r3, .SNAKE_LEN			@ load the pointer that contains the snake's length
	ldr r3, [r3]				@ read the current snake length
	mov r4, #0				@ set the counter to zero
	.snake_render_loop:
		ldr r0, [r5]			@ read the x coordinate of the current snake piece
		ldr r1, [r6]			@ read the y coordinate of the current snake piece
		cmp r4, #0			@ compare the counter with the value zero
		bne .snake_body_render		@ if they are different, it means that i'm rendering the body

		mov r2, #4			@ otherwise i'm rendering the head, use a different tile with a different color
		b .snake_render_call		@ jump to rendering instructions

		.snake_body_render:
		mov r2, #3			@ set the tile index for the body of the snake

		.snake_render_call:
		bl .render_tile			@ render the snake tile to the buffer
		add r5, r5, #8			@ increase the x coordinate pointer to the next piece of the snake
		add r6, r6, #8			@ increase the y coordinate pointer to the next piece of the snake
		add r4, r4, #1			@ increment the counter
		cmp r4, r3			@ compare the value of the counter with the snake's length
		bne .snake_render_loop		@ if it's different, it means that there are still some snake pieces to iterate on
	pop {r0-r6, pc}

@ // set initial snake properties
.set_snake_prop:
	push {r0-r6, lr}
	ldr r0, .DIR_X				@ load the pointer that contains the speed value on the x-axis
	mov r1, #1				@ set the x speed to 1 by default
	str r1, [r0]				@ write the value in the memory
	ldr r0, .DIR_Y				@ load the pointer that contains the speed value on the y-axis
	mov r1, #0				@ set the y speed to 0 by default
	str r1, [r0]				@ write the value in the memory

	mov r0, #((DISPLAY_WIDTH / 8) / 2)	@ find the x coordinate in the middle of the screen as the point from which to start the game
	mov r1, #((DISPLAY_HEIGHT / 8) / 2)	@ find the y coordinate in the middle of the screen as the point from which to start the game

	ldr r2, .SNAKE_X			@ load the pointer of snake's head x coordinate
	ldr r3, .SNAKE_Y			@ load the pointer of snake's head y coordinate
	str r0, [r2]				@ write the x coordinate of the beginning of the game
	str r1, [r3]				@ write the y coordinate of the beginning of the game

	ldr r5, .SNAKE_LEN			@ load the pointer that contains the snake's length
	mov r4, #DEF_INIT_LEN			@ load the default value for the snake's length
	str r4, [r5]				@ write its value into the memory
	mov r5, #0				@ set the counter to zero
	.create_snake_blocks:
		lsl r6, r5, #3			@ multiply the counter value by 8 to get the offset of the current snake piece
		str r0, [r2, r6]		@ write the x coordinate of the current part with that offset
		str r1, [r3, r6]		@ write the y coordinate of the current part with that offset
		add r5, r5, #1			@ increment the counter value
		cmp r5, r4			@ compare the counter with the snake's length
		bne .create_snake_blocks	@ if it's different, it means that there are still some snake pieces to iterate on

	pop {r0-r6, pc}

@ // reset processed input
.reset_processed_input:
	push {r0, lr}
	ldr r0, .PROCESSED			@ load the pointer that contains a flag to indicate if an input has been entered
	mov r1, #0				@ reset that flag to zero
	str r1, [r0]				@ write that value into the memory
	pop {r0, pc}

@ // manage key pression
.key_pressed:
	push {r0-r5, lr}
	ldr r5, .PROCESSED			@ load the pointer that contains a flag to indicate if an input has been entered
	ldr r1, [r5]				@ read the flag value
	cmp r1, #0				@ compare the value of the flag with zero
	bne .key_pressed_return			@ if it's different, it means that an input has been entered that needs to be processed

	ldr r2, .DIR_X				@ load the pointer that contains the speed value on the x-axis
	ldr r3, .DIR_Y				@ load the pointer that contains the speed value on the y-axis
	ldr r0, .KEY				@ load the pointer containing the value of the key inputs
	ldrb r0, [r0]				@ read current key pressed value
	add r0, r0, #1				@ since it's in negative logic, initially add 0
	neg r0, r0				@ and negate the value to get corresponding positive value
	mov r1, #KEY_UP				@ load the bit mask for the up key
	and r1, r0				@ perform the and operation between the mask and the value of the key pressed
	cmp r1, #0				@ compare the and result with zero
	bne .key_pressed_up			@ if the value is not zero, it means that the up key has been pressed
	mov r1, #KEY_DOWN			@ load the bit mask for the down key
	and r1, r0				@ perform the and operation between the mask and the value of the key pressed
	cmp r1, #0				@ compare the and result with zero
	bne .key_pressed_down			@ if the value is not zero, it means that the down key has been pressed
	mov r1, #KEY_RIGHT			@ load the bit mask for the right key
	and r1, r0				@ perform the and operation between the mask and the value of the key pressed
	cmp r1, #0				@ compare the and result with zero
	bne .key_pressed_right			@ if the value is not zero, it means that the right key has been pressed
	mov r1, #KEY_LEFT			@ load the bit mask for the left key
	and r1, r0				@ perform the and operation between the mask and the value of the key pressed
	cmp r1, #0				@ compare the and result with zero
	bne .key_pressed_left			@ if the value is not zero, it means that the left key has been pressed
	b .key_pressed_return			@ otherwise, no key has been pressed

	.key_pressed_up:
	ldr r4, [r3]				@ read the speed value on the y-axis
	cmp r4, #0				@ compare the value with zero
	bne .key_pressed_return			@ if it's different, it means that the snake already has a certain vertical speed
	mov r0, #0				@ otherwise, set the horizontal speed to 0
	mov r1, #1				@ set the vertical speed to -1, to point up
	neg r1, r1				@ negating the value 1
	b .key_pressed_dir			@ jump to instructions with which to save new speeds

	.key_pressed_down:
	ldr r4, [r3]				@ read the speed value on the y-axis
	cmp r4, #0				@ compare the value with zero
	bne .key_pressed_return			@ if it's different, it means that the snake already has a certain vertical speed
	mov r0, #0				@ otherwise, set the horizontal speed to 0
	mov r1, #1				@ set the vertical speed to 1, to point down
	b .key_pressed_dir			@ jump to instructions with which to save new speeds

	.key_pressed_right:
	ldr r4, [r2]				@ read the speed value on the x-axis
	cmp r4, #0				@ compare the value with zero
	bne .key_pressed_return			@ if it's different, it means that the snake already has a certain horizontal speed
	mov r0, #1				@ otherwise, set the horizontal speed to 1, to point right
	mov r1, #0				@ set the vertical speed to 0
	b .key_pressed_dir			@ jump to instructions with which to save new speeds
	
	.key_pressed_left:
	ldr r4, [r2]				@ read the speed value on the x-axis
	cmp r4, #0				@ compare the value with zero
	bne .key_pressed_return			@ if it's different, it means that the snake already has a certain horizontal speed
	mov r0, #1				@ otherwise, set the horizontal speed to -1, to point left
	neg r0, r0				@ negating the value 1
	mov r1, #0				@ set the vertical speed to 0 
	b .key_pressed_dir			@ jump to instructions with which to save new speeds

	.key_pressed_dir:
	str r0, [r2]				@ write the new horizontal speed
	str r1, [r3]				@ write the new vertical speed
	mov r1, #1				@ set the flag for processing a new input to 1
	str r1, [r5]				@ write the value into the memory

	.key_pressed_return:
	pop {r0-r5, pc}

.text
.align	2
	.SNAKE_X: 	.word SNAKE_LOC_X
	.SNAKE_Y:	.word SNAKE_LOC_Y
	.SNAKE_LEN:	.word SNAKE_LENGTH
	.DIR_X:		.word SNAKE_DIR_X
	.DIR_Y:		.word SNAKE_DIR_Y
	.SPEED:		.word GAME_SPEED
	.KEY:		.word REG_BASE + 0x130
	.PROCESSED:	.word PROC_INPUT
