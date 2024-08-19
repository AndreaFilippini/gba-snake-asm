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
	.equ MAX_LENGTH,	0x02010000
	.equ SNAKE_LENGTH,	0x02010004
	.equ SNAKE_DIR_X,	0x02010008
	.equ SNAKE_DIR_Y,	0x0201000C
	.equ SNAKE_LOC_X,	0x02010010
	.equ SNAKE_LOC_Y,	0x02010014
	.equ APPLE_LOC_X,	0x02020000
	.equ APPLE_LOC_Y,	0x02020004
	.equ GAME_SPEED,	0x02020008
	.equ SPEED_VALUE,	0x100

main:
	push {r0, lr}
	bl .random
	bl .enable_bg
	bl .load_pal
	bl .load_all_tile
	bl .render_walls
	bl .set_snake_prop
	bl .spawn_apple
.loop:
	@ ;;;;;;;;;;;;;;MAIN GAME;;;;;;;;;;;;;;;
	bl .vid_sync
	bl .wait_timer
	bl .snake_render
	bl .snake_update
	b .loop

@ // VBlank timing
.vid_sync:
	push {r0-r1, lr}
	ldr r0, .VCOUNT
	.vid_sync_loop:
		ldrh r1, [r0]
		cmp r1, #160
		bge .vid_sync_loop
	.vid_sync_loop_2:
		ldrh r1, [r0]
		cmp r1, #160
		blt .vid_sync_loop_2
	pop {r0-r1, pc}

@ // enable BG0 and set its properties
.enable_bg:
	push {r0-r1, lr}
	ldr r0, .DISPCNT
	ldr r1, = (0 | (1 << 8))
	strh r1, [r0]
	ldr r0, .BG0CNT
	ldr r1, = (8 << 8)
	strh r1, [r0]
	pop {r0-r1, pc}

.text
.align	2
	.DISPCNT: 	.word REG_BASE + 0x0
	.VCOUNT: 	.word REG_BASE + 0x6
	.BG0CNT: 	.word REG_BASE + 0x8

@ // load color palette for snake walls and apple
.load_pal:
	push {r0-r4, lr}
	ldr r0, .PALETTE
	ldr r1, .CLR_WHITE
	ldr r2, .CLR_RED
	ldr r3, .CLR_BLUE
	ldr r4, .CLR_GREEN
	strh r1, [r0]
	strh r2, [r0, #2]
	strh r3, [r0, #4]
	strh r4, [r0, #6]
	pop {r0-r4, pc}

.text
.align	2
	.PALETTE: 	.word PLTT + 0x2
	.CLR_WHITE:	.word (31 | (31 << 5) | (31 << 10))
	.CLR_RED:	.word (28 | (10 << 5) | (10 << 10))
	.CLR_BLUE:	.word (10 | (28 << 5) | (10 << 10))
	.CLR_GREEN:	.word (10 | (10 << 5) | (28 << 10))

@ // load number of tiles specified
.load_all_tile:
	push {r0, lr}
	mov r0, #0
	.load_tile_loop:
		add r0, r0, #1
		bl .load_single_tile
		cmp r0, #TOTAL_TILE
		bne .load_tile_loop
	pop {r0, pc}

@ // load 8x8 tile based on value of first arg
.load_single_tile:
	push {r0-r5, lr}
	mov r5, r0
	lsl r1, r0, #4
	lsl r2, r0, #8
	lsl r3, r0, #12
	orr r0, r1
	orr r0, r2
	orr r0, r3
	lsl r1, r0, #8
	orr r0, r1
	lsl r1, r0, #8
	orr r0, r1
	mov r2, #(TILE_SIZE / 4)
	ldr r1, .VRAM_TILE
	mov r4, #TILE_SIZE
	mul r5, r4
	add r1, r1, r5
	.single_tile_loop:
		str r0, [r1]
		add r1, r1, #4
		sub r2, r2, #1
		cmp r2, #0
		bne .single_tile_loop
	pop {r0-r5, pc}

.text
.align	2
	.VRAM_TILE: 	.word VRAM

@ // render tile on screen based on x, y and index
.render_tile:
	push {r0-r3, lr}
	ldr r3, .VRAM_BG0
	lsl r0, r0, #1
	lsl r1, r1, #6
	add r0, r0, r1
	add r0, r0, r3
	strh r2, [r0]
	@bl __aeabi_idiv
	pop {r0-r3, pc}

.text
.align	2
	.VRAM_BG0: 	.word VRAM + 0x4000

@ // render wall on screen border
.render_walls:
	push {r0-r2, lr}
	mov r0, #0
	mov r1, #0
	mov r2, #1
	.render_walls_loop:
		cmp r1, #0
		beq .put_tile
		cmp r1, #((DISPLAY_HEIGHT / 8) - 1)
		beq .put_tile
		cmp r0, #0
		beq .put_tile
		cmp r0, #((DISPLAY_WIDTH / 8) - 1)
		bne .incr_counter
		.put_tile:
		bl .render_tile
		.incr_counter:
			add r0, r0, #1
			cmp r0, #(DISPLAY_WIDTH / 8)
			bne .render_walls_loop
			mov r0, #0
			add r1, r1, #1
			cmp r1, #(DISPLAY_HEIGHT / 8)
			bne .render_walls_loop
	pop {r0-r2, pc}

@ // generate random values	
.random:
	push {r1-r2}
	ldr r0, .RANDOM_VAL
	ldr r1, [r0]
	ldr r2, .SEED
	mul r1, r2
	ldr r2, = 0x1073
	add r1, r2
	str r1, [r0]
	lsr r0, r1, #16
	pop {r1-r2}
	bx lr

.text
.align	2
	.RANDOM_VAL: 	.word RANDOM
	.SEED:		.word 0x41C64E61

@ // spawn apple tile
.spawn_apple:
	push {r0-r3, lr}
	bl .random
	mov r1, #((DISPLAY_WIDTH / 8) - 2)
	bl __aeabi_uidivmod
	add r0, r1, #1

	push {r0}
	bl .random
	mov r1, #((DISPLAY_HEIGHT / 8) - 2)
	bl __aeabi_uidivmod
	add r1, r1, #1
	pop {r0}

	ldr r2, .APPLE_X
	ldr r3, .APPLE_Y
	str r0, [r2]
	str r1, [r3]

	mov r2, #2
	bl .render_tile
	pop {r0-r3, pc}

.text
.align	2
	.APPLE_X: 	.word APPLE_LOC_X
	.APPLE_Y:	.word APPLE_LOC_Y

@ // wait for the timer before updating the frame
.wait_timer:
	push {r0-r2, lr}
	ldr r1, = SPEED_VALUE
	.speed_loop:
		sub r1, r1, #1
		cmp r1, #0
		bne .speed_loop
	pop {r0-r2, pc}

@ // update snake position
.snake_update:
	push {r0-r6, lr}
	ldr r0, .SNAKE_X
	ldr r1, .DIR_X
	ldr r2, [r0]
	ldr r3, [r1]
	add r2, r2, r3
	str r2, [r0]

	ldr r0, .SNAKE_Y
	ldr r1, .DIR_Y
	ldr r2, [r0]
	ldr r3, [r1]
	add r2, r2, r3
	str r2, [r0]

	pop {r0-r6, pc}

@ // show snake on screen
.snake_render:
	push {r0-r6, lr}
	ldr r5, .SNAKE_X
	ldr r6, .SNAKE_Y
	mov r2, #3
	ldr r3, .SNAKE_LEN
	ldr r3, [r3]
	mov r4, #0
	.snake_render_loop:
		ldr r0, [r5]
		ldr r1, [r6]
		bl .render_tile
		add r5, r5, #8
		add r6, r6, #8
		add r4, r4, #1
		cmp r4, r3
		bne .snake_render_loop
	pop {r0-r6, pc}

@ // set initial snake properties
.set_snake_prop:
	push {r0-r3, lr}
	mov r0, #((DISPLAY_WIDTH / 8) / 2)
	mov r1, #((DISPLAY_HEIGHT / 8) / 2)
	ldr r2, .SNAKE_X
	ldr r3, .SNAKE_Y
	str r0, [r2]
	str r1, [r3]
	ldr r2, .SNAKE_LEN
	mov r0, #1
	str r0, [r2]
	ldr r2, .MAX_LEN
	mov r0, #5
	str r0, [r2]

	ldr r0, .DIR_X
	mov r1, #1
	str r1, [r0]
	ldr r0, .DIR_Y
	mov r1, #0
	str r1, [r0]
	pop {r0-r3, pc}

.text
.align	2
	.SNAKE_X: 	.word SNAKE_LOC_X
	.SNAKE_Y:	.word SNAKE_LOC_Y
	.MAX_LEN:	.word MAX_LENGTH
	.SNAKE_LEN:	.word SNAKE_LENGTH
	.DIR_X:		.word SNAKE_DIR_X
	.DIR_Y:		.word SNAKE_DIR_Y
	.SPEED:		.word GAME_SPEED