/*
 * MBus Copyright 2015 Regents of the University of Michigan
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

`define ADDR_WIDTH 32
`define DATA_WIDTH 32
`define FUNC_WIDTH 4
`define DYNA_WIDTH 4
`define RSVD_WIDTH 8
`define BROADCAST_CMD_WIDTH 4

`define PRFIX_WIDTH			(`ADDR_WIDTH - `RSVD_WIDTH - `FUNC_WIDTH)
`define SHORT_ADDR_WIDTH 	(`DYNA_WIDTH + `FUNC_WIDTH)

// Watch don counter width
`define WATCH_DOG_WIDTH 20

`define CONTROL_SEQ 2'b10
`define BROADCAST_ADDR 32'hf000_0000

`define IO_HOLD 1'b1
`define IO_RELEASE 1'b0

// DON'T DEFINE POWER_GATING FOR THE FPGA!
//`define POWER_GATING
`ifdef POWER_GATING
`undef POWER_GATING
`endif

// A broadcast message consists of two segaments,
// 0x0A			0xBB_XXXXXX for short address or
// 0xf0000_000A 0xBB_XXXXXX for long address
// Where 0x0A is address field and 0xBB is data field
// "A" is broadcast "channels"
// "BB" is broadcast "commands"

// Broadcast channel, the width should be consistant with `FUNC_WIDTH
`define CHANNEL_ENUM	4'h0
`define CHANNEL_POWER 	4'h1
`define CHANNEL_CTRL	4'h2
`define CHANNEL_MEMBER_EVENT 4'h3

// Broadcast commands, the width should be consistant with `BROADCAST_CMD_WIDTH
// Commands for CHANNEL_ENUM
`define CMD_CHANNEL_ENUM_QUERRY				4'h0
`define CMD_CHANNEL_ENUM_RESPONSE			4'h1
`define CMD_CHANNEL_ENUM_ENUMERATE			4'h2
`define CMD_CHANNEL_ENUM_INVALIDATE			4'h3


// Commands for CHANNEL_POWER
`define CMD_CHANNEL_POWER_ALL_SLEEP			4'h0
`define CMD_CHANNEL_POWER_ALL_WAKE			4'h1
`define CMD_CHANNEL_POWER_SEL_SLEEP			4'h2
`define CMD_CHANNEL_POWER_SEL_WAKE			4'h3
`define CMD_CHANNEL_POWER_SEL_SLEEP_FULL	4'h4

// Commands for Layer controller, the width should match `FUNC_WIDTH
`define LC_CMD_RF_WRITE		4'h0
`define LC_CMD_RF_READ		4'h1
`define LC_CMD_MEM_WRITE	4'h2
`define LC_CMD_MEM_READ		4'h3
`define LC_CMD_MEM_STREAM	2'b01

`ifndef SD
    `define SD #1
`endif
