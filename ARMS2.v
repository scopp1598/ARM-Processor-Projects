module ARMS2( clk, ibus, enable, dataFromMuxAfterCache, reset, /*addressFromProcessorToArbiter,*/daddrbus, dataFromProcessorToArbiter, opcode3, iaddrbus);
	input clk;//The One Wire
	input [31:0] ibus;//The Instruction
	input reset;//Used to reset almost every wire in the CPU to 0.
	input enable;//enable goes to all the things that use a clock, except the register file.
	input [63:0] dataFromMuxAfterCache;//used for loads, going into the WB module
	
	//output [63:0] addressFromProcessorToArbiter;//This is the daddrbus
	output [63:0] dataFromProcessorToArbiter;//this is tbus_hold4, used only with stores.
	output [63:0] iaddrbus;//Instruction address bus //NOT USED.
	output [10:0] opcode3;  		//From memoryBus used in databus driver and Writeback Bus  
	output [63:0] daddrbus;//Goes into Writeback Bus, becomes daddrbus_hold1
	//inout  [63:0] databus;//becomes test, goes into Writeback Bus, becomes databus_hold1
	
	
	//==== Insturction ====\\
	wire [31:0] ibus_hold2;
	wire [31:0] ibus_hold3;
	wire [31:0] ibus_hold4;
	
	//==== Branch and PC Circuitry ====\\
	wire [63:0] currentAddress;//Leaving the pcCircuitry and going into the PC bus, and becomes iaddrbus
	wire [63:0] oldAddress1;//Leaves Branch Circuitry and enters IF/ID. Becomes oldAddress2
	wire [63:0] oldAddress2;//Leaves IF/ID and entered the Branch Circuitry.
	//=================================\\
	
	//==== The Clocked Instruction ====\\
	wire [31:0] ibus_hold;//after clocking the ibus. goes into decoder and signExtension
	//=========================\\
	
	//==== Carry Into the ALU ====\\
	wire Cin_hold1;//Carry in, being clocked in executionBus, going to ALU.
	wire Cin;//leaving executionBus going to ALU.
	//============================\\
	
	//==== ALU Operation Selector ====\\
	wire [2:0] S_hold1;//Selector, being clocked in executionBus, and goes to ALU.
    wire [2:0] S;//leaving executionBus going to ALU.
	//================================\\
		
	//==== Sign Extension ====\\
	wire [63:0] sign_hold1;//Outut from sign extension. being clocked in executionBus. Used with I type instructions.
	wire [63:0] sign_hold2;//Output from execution bus. going to mux2, Used with I type instructions
	wire [63:0] signed_address;//output from the Address Mux, going into the branch ALU to be shifted by 2.
	//========================\\
	
	//==== RS Field: abus ====\\
	wire [31:0] Aselect;//leaving decoder. going to regfile. Becomes abus_hold1
	wire [63:0] abus_hold1;//leaving regfile going to executionBus.
	wire [63:0] abus;//Going into the ALU
	wire [63:0] abus_hold2;//abus_hold2 is storing abus. Used to pipeline abus if needed.
	//========================\\
	
	
	//==== RT Field: bbus ====\\
    wire [31:0] Bselect;//leaving decoder. going to regfile. Becomes bbus_hold1
	wire [63:0] bbus_hold1;//leaving regfile going to executionBus. Becomes bbus_hold2
	wire [63:0] bbus_hold2;//leaving executionBus going to mux2. Also being routed to the memoryBus and being clocked, becomes bbus.
    wire [63:0] bbus;//The output of mux2 which goes to the ALU
    //========================\\
	
	//==== databus ====\\	
	//inout [63:0] databus;//Databus is an inout port used to transfer data via LDUR and STUR
	wire [63:0] databusBuff;//is the output from the DATABUS_DRIVER going into writeback stage.
    wire [63:0] databus_hold1;//leaving writeBack going to mux3.
	//=================\\
		
	//==== dadderbus ====\\
	wire [63:0] dbus_hold0;//leaving alu. Used with NZVC register
	wire [63:0] dbus_hold1;//leaving the mux after the ALU. going to be clocked in memoryBus. becomes daddrbus once clocked in memoryBus
	wire [63:0] daddrbus_hold1;//leaving writeback going to mux3. After the mux3, becomes dbus_hold2 
	wire [63:0] dbus_hold2;//gets intercepted by branch decision, and then checked if its a MOVZ. Becomes dbus_hold3
    //dadderbus is an output, so it is declared uptop
	//===================\\	
		
	//==== Dselect ===\\
	wire [31:0] Dselect;	  //Leaving the Dselect Ternary operator and going into register file.
	wire [31:0] Dselect_hold1;//Being clocked in executionBus. Becomes Dselect_hold2
	wire [31:0] Dselect_hold2;//Leaving executionBus, being clocked in memoryBus. 
	wire [31:0] Dselect_hold3;//leabing memoryBus, going to writeback 
	wire [31:0] Dselect_hold4;//leaving writeback, used in DMUX. becomes Dselect.
	//================\\
	
	//==== Opcode Bits====\\
	wire [10:0] opcode1; 		//From the decoder. going to executionBus.                                       
	wire [10:0] opcode2;  		//From executionBus going to memoryBus  
	//output [10:0] opcode3;  		//From memoryBus used in databus driver and Writeback Bus                       
	wire [10:0] opcode4;  		//From Writeback Bus used in mux3 for dbus; and the ternary operator for Dselect 
    //====================================\\
    
    //==== Moved Immediate ====\\
    wire [63:0] movedOutput1;	//From the decoder, going to executionBus
    wire [63:0] movedOutput2;	//From the executionBus going into a mux after the ALU to intercept the the data because of MOVZ instruction.
    //=========================\\
    
    //==== Immediate Flag ====\\
	wire Imm_hold1;//Immediate flag, used in mux1, then being clocked in executionBus
	wire Imm_hold2;//Leaving ExecutionBus being used in mux2
    //========================\\
	
	//======== FLAGS ========\\
	wire branchFlag;//Flag to determine if the branch is taken or not. 1 = took branch, 0 = did not take branch.
	wire V;// Overflow signal from ALU
	wire C;//Cout from ALU, goes into Memory Bus becomes C_hold1
	wire [3:0] NZVC; //The NZVC flags where {N, Z, V, C} == {3, 2, 1, 0}, N = 3.
	//=======================\\
		
	//==== Shamt: Shift Ammount ====\\
	wire [5:0] shamt1;//Partitioned values from the ibus_hold, used with LSL and RSL
	wire [5:0] shamt2;
	wire [5:0] shamt3;
	wire [5:0] shamt4;
	
	wire [63:0] shiftedValue1;//This is abus_hold1 << shamt1  or  abus_hold1 >> shamt1
	wire [63:0] shiftedValue2;
	wire [63:0] shiftedValue3;
	wire [63:0] shiftedValue4;
	//==============================\\	

	//==== Extra Wires From Decoder ====\\
	wire [8:0]  DT_address1;//Partitioned bits from the ibus_hold. Used with D type instructions.
	wire [8:0]  DT_address2;
	wire [63:0] DT_address_hold2;//The sign extended DT_address2. Going into the MUX before ALU Becomes DT_address_hold3
	wire [63:0] DT_address_hold3_OR_bbus;//Coming out of the MUX going into the ALU
	wire [63:0] BR_address1;//Partitioned bits from the ibus_hold, used with B type instructions.
	wire [63:0] COND_BR_address1;//Partitioned bits from the ibus_hold, used with CD type instructions.
	//==================================\\

	//==== Tbus ====\\
	wire [31:0] Tselect;//Tselect comes out of the decoder and goes into the reg file.
	wire [63:0] tbus_hold1;//Tbus_hold1 is the data from a register when the selector bits are [4:0]
	wire [63:0] tbus_hold2;//after beging clocked in executionBus
	wire [63:0] tbus_hold3;//after the STUR mux.
	wire [63:0] tbus_hold4;//after memoryBus, going into the STUR logic. Going to the data cache Arbiter. This is getting assigned to dataFromProcessorToArbiter
	//=================\\

    //==== New Program Counter ====\
    wire [31:0] instructionAddressBus;
    wire [31:0] ibus;
    

    //programCounter #(32'h00001000) programCount(.clk(clk), .enable(enable), .instructionAddress(instructionAddressBus) );
    
    //instructionMemory instructionCache(.pc(instructionAddressBus), .instruction(ibus) );

	//Program Counter Not Needed
	pc programCounterOLD(.clk(clk), .reset(reset), .iaddrbus_in(currentAddress), .iaddrbus_out(iaddrbus));
	
	//Branch ALUs
	branchALUs branchALUS(.iaddrbus(iaddrbus), .sign_hold1(signed_address),  .oldAddress_in(oldAddress2),  .branchFlag2(branchFlag), .reset(reset), .clk(clk),
	                                                           /*Outputs >>*/.oldAddress_out(oldAddress1), .currentAddress(currentAddress) );
	
	//Instruction Fetch
	instFetchBus IF_ID(.clk(clk),  	.ibus(ibus),            .oldAddress1(oldAddress1), .reset(reset), .enable(enable),
	                        	   	.ibus_hold(ibus_hold),  .oldAddress2(oldAddress2) );
    
    //Decode the ARM Insctruction
    ARMdecoder myARM_Decoder(/*Inputs >> */.ibus_hold(ibus_hold), 		.reset(reset), 
    						 /*Outputs >>*/.Aselect(Aselect), 			.Bselect(Bselect),	 		.Dselect_hold1(Dselect_hold1), 
                                           .Imm(Imm_hold1),   			.S(S_hold1),       			.Cin(Cin_hold1), 
                                           .opcode(opcode1), 	 		.sign_hold1(sign_hold1),	.shamt(shamt1),		 			 
                                           .DT_address(DT_address1), 	.BR_address(BR_address1), 	.COND_BR_address(COND_BR_address1), 
                                           .Tselect(Tselect),			.movedOutput(movedOutput1) 
                                           );
	//Address Mux
	assign signed_address = (reset == 1'b1) ? 64'h0000000000000000 :
							(opcode1 == 11'h0A0) ? BR_address1 :
							((opcode1 == 11'h2A0) || //BEQ
							 (opcode1 == 11'h2A8) || //BNE
							 (opcode1 == 11'h2B8) || //BLT
							 (opcode1 == 11'h2C0) || //BGE
							 (opcode1 == 11'h5A0) || //CBZ
							 (opcode1 == 11'h5A8)	 //CBNZ
							 ) ? COND_BR_address1 : 
							 COND_BR_address1;

	//Register File
	regfile myRegFile(.clk(clk), .Aselect(Aselect), .Bselect(Bselect), .Dselect(Dselect), .Tselect(Tselect), .dbus(dbus_hold2),
	               /*Outputs >>*/.abus(abus_hold1), .bbus(bbus_hold1), .tbus(tbus_hold1), .registerVal(registerVal));
	
	//Logical Shifter for LSL LSR instructions
	logicalShifter ARM_LS(.abus_hold1(abus_hold1), .shamt1(shamt1), .opcode1(opcode1), .shiftedValue(shiftedValue1));
	
    //Branch Decisions
	ARM_BranchDecisions ARM_BranchDecisions(.reset(reset), .abus_hold1(abus_hold1), .bbus_hold1(bbus_hold1), .opcode1(opcode1), .branchFlag(branchFlag), .NZVC(NZVC), .tbus_hold1(tbus_hold1));
	
	
	//Execution Bus    /*Inputs                      Outputs*/
	executionBus exBus(	.clk(clk), .reset(reset),
	                    .enable(enable),
	           			.Imm_in(Imm_hold1),                 .Imm(Imm_hold2),
	           			.Cin_in(Cin_hold1),                 .Cin(Cin),
	           			.S_in(S_hold1),                     .S(S),
	           			.abus_hold(abus_hold1),             .abus(abus),
	           			.bbus_hold1(bbus_hold1),            .bbus_hold2(bbus_hold2),
	           			.sign_hold1(sign_hold1),            .sign_hold2(sign_hold2),
	           			.Dselect_hold1(Dselect_hold1),      .Dselect_hold2(Dselect_hold2), 
	           			.opcode_in(opcode1),                .opcode_out(opcode2), 
		       			.movedOutput1(movedOutput1),		.movedOutput2(movedOutput2),
		       			.shiftedValue1(shiftedValue1),		.shiftedValue2(shiftedValue2),
		       			.tbus_hold1(tbus_hold1),			.tbus_hold2(tbus_hold2),
		       			.DT_address1(DT_address1),          .DT_address2(DT_address2),
		       			.ibus_hold(ibus_hold),              .ibus_hold2(ibus_hold2)
		         		);
	
               
	//Mux2: Works with the Immediate Instructions The mux before the main ALU.
	myMux mux2(.ifTrue(sign_hold2), .ifFalse(bbus_hold2), .Imm(Imm_hold2), .mux_out(bbus));
    
    assign abus_hold2 = abus;//Just making an abus_hold2 at this stage. Used with STUR MUX
    
    //SignExtend DT_address2
    assign DT_address_hold2 = (DT_address2[8]) ? {55'h7F_FFFF_FFFF_FFFF, DT_address2} : {55'b0, DT_address2} ;
    	
    //MUX to pick either DT_address2 or bbus, going into the ALU
    assign DT_address_hold3_OR_bbus = (opcode2 == 11'h7C0 || opcode2 == 11'h7C2) ? DT_address_hold2 : bbus;
    	
    //STUR MUX
    assign tbus_hold3 = (opcode2 == 11'h7C0) ? tbus_hold2 : abus_hold2;
    
    //The ALU
	alu64 alu64(.a(abus), .b(DT_address_hold3_OR_bbus), .d(dbus_hold0), .Cin(Cin), .S(S), .Cout(C), .V(V));//missing V and Cout
	
	//NZVC Register Setting
	NZVC_Register NZVC_Flags(.opcode2(opcode2), .dbus_hold0(dbus_hold0), .V(V), .C(C), .NZVC(NZVC));
	
	//MUX after main ALU
	assign dbus_hold1 = (opcode2 == 11'h694) ? movedOutput2 :	//checking if the instruction was a MOVZ
						(opcode2 == 11'h69B || opcode2 == 11'h69A) ? shiftedValue2 : //checking if the instruction was either LSL or LSR
						dbus_hold0;
	

	//Memory Bus		//Inputs							Outputs
	memoryBus memBus(	.clk(clk), .reset(reset),
	                    .enable(enable),
						.dbus_hold(dbus_hold1), 			.dbus(daddrbus),
						.Dselect_hold2(Dselect_hold2),  	.Dselect(Dselect_hold3),
						.opcode_in(opcode2),  				.opcode_out(opcode3),
						.C(C),  				 			.C_hold1(C_hold1),
						.shiftedValue2(shiftedValue2), 		.shiftedValue3(shiftedValue3),
						.tbus_hold3(tbus_hold3),			.tbus_hold4(tbus_hold4),
						.ibus_hold2(ibus_hold2),            .ibus_hold3(ibus_hold3)
	           			);
		
		
	//==== Databus Driver ====\\
	//assign addressFromProcessorToArbiter = daddrbus;//This is the data address going into the arbiter for the data cache.
    assign dataFromProcessorToArbiter = tbus_hold4;//This is the data itself going into the data cache when stores are performed.            
    //ARM_databus_driver DATABUS_DRIVER(.databus(databus), .reset(reset), .tbus_hold4_buff(tbus_hold4), .opcode3(opcode3), .databus_out(databusBuff));
    //sharedCache cache(.opcode3(opcode3), .dataAddressBus(daddrbus), .dataIn(tbus_hold4), .dataOut(databusBuff), .storeCheck());
    
    //========================\\
	
	//Writeback Bus	//Inputs									Outputs
	writeback	wb(	.clk(clk), .reset(reset),
	                .enable(enable),
					.databus_in(dataFromMuxAfterCache),			.databus_out(databus_hold1),
					.daddrbus_in(daddrbus),      				.daddrbus_out(daddrbus_hold1),
					.Dselect_hold3(Dselect_hold3),  			.Dselect(Dselect_hold4),
					.opcode_in(opcode3),    					.opcode_out(opcode4),
					.shiftedValue3(shiftedValue3),				.shiftedValue4(shiftedValue4),
					.ibus_hold3(ibus_hold3),                    .ibus_hold4(ibus_hold4)
	          		);
	
    //==== Mux 3 ====\\ 
    //Used to pick either dadderbus or databus depending on the opcode. {STUR, LDUR}
	assign dbus_hold2 = (opcode4 == 11'h7C0 || opcode4 == 11'h7C2) ? databus_hold1 : daddrbus_hold1;
	//===============\\
	
    //ternary operator to either make Dselect register 0 for STUR, BEQ, and BNE, BLT, BGE, B, CBNZ CBZ respectively.
	assign Dselect = ( 	(opcode4 == 11'h7C0) || //STUR
						(opcode4 == 11'h2A0) || //BEQ
						(opcode4 == 11'h2A1) || //BNE
						(opcode4 == 11'h2B8) || //BLT
						(opcode4 == 11'h2C0) || //BGE
						(opcode4 == 11'h0A0) || //B
						(opcode4 == 11'h5A8) || //CBNZ
						(opcode4 == 11'h5A0)
					 ) ? 64'h8000000000000000 : Dselect_hold4;
endmodule









module arbiter (p0_opcode3, p1_opcode3, p0_address, p1_address, p0_data, p1_data, address, data, opcode3, p0_enable, p1_enable, allowedAccess);
    input [10:0] p0_opcode3;
    input [10:0] p1_opcode3;
    
    input [63:0] p0_address;//this is the address going into the cache either to store or load.
    input [63:0] p1_address;
    
    input [63:0] p0_data;//This is the data to store into the cache.
    input [63:0] p1_data;
    
    output reg [63:0] address;//This comes out of the arbiter and tells the cache where to store data into the cache and where to load from the cache.
    output reg [63:0] data;//This is the data that comes out of the cache when a load is performed.
    output reg [10:0] opcode3;//Goes into the Cache to tell it if it is a load or a store.
    
    output reg p0_enable;//This tells the processor that it can enable its clock or not. 1 means go, 0 means stall.
    output reg p1_enable;
    
    //allowedAccess goes around the cache and into the inverse mux.
    output reg allowedAccess;//0 corresponds to processor 0 needing the cache.(p0 has access to the cache)  1 corresponds to processor 1 needing to use the cache. 
    
    reg lastWent;//0 for p0, 1 for p1
    
    initial begin
        lastWent = 1'b1;//we say that p1 went first, when the first instance of conflict occurs, processor 0 is told to go first.
        p0_enable = 1'b1;
        p1_enable = 1'b1;
        
    end
    
    always @(*)begin
        //11'h458 == ADD opcode
        if( ( (p0_opcode3 == 11'h7C2) || (p0_opcode3 == 11'h7C0) ) && ( (p1_opcode3 == 11'h7C2) || (p1_opcode3 == 11'h7C0) ) )begin//if both processors are trying to access the cache at once reguardless if they want to do a load or store.
            case (lastWent)
                0:  begin
                        lastWent = 1'b1;//
                        p0_enable = 1'b0;
                        p1_enable = 1'b1;
                        opcode3 = p1_opcode3;//when the processor is enabled, you want to pipe through its information to the cache.
                        address = p1_address;
                        data = p1_data;
                        allowedAccess = 1'b1;
                    end
                   
                1:  begin
                        lastWent = 1'b0;
                        p0_enable = 1'b1;
                        p1_enable = 1'b0;
                        opcode3 = p0_opcode3;
                        address = p0_address;
                        data = p0_data; 
                        allowedAccess = 1'b0;
                    end
            endcase
        end
        else begin
            p0_enable = 1'b1;
            p1_enable = 1'b1;
            if(p0_opcode3 == 11'h7C2 || p0_opcode3 == 11'h7C0)begin
                lastWent = 1'b0;
                opcode3 = p0_opcode3;
                address = p0_address;
                data = p0_data;
                allowedAccess = 1'b0;     
            end
            if(p1_opcode3 == 11'h7C2 || p1_opcode3 == 11'h7C0)begin
                lastWent = 1'b1;
                opcode3 = p1_opcode3;
                address = p1_address;
                data = p1_data;   
                allowedAccess = 1'b1; 
            end
        end
    end
    
    
    
endmodule

module arbiterMux (allowedAccess, data, /*address,*/ p0_dataFromCacheToProcessor, /*p0_addressFromCacheToProcessor,*/ p1_dataFromCacheToProcessor /*,p1_addressFromCacheToProcessor*/);
    input allowedAccess;//0 corresponds to processor 0 needing the cache.(p0 has access to the cache)  1 corresponds to processor 1 needing to use the cache. 
    input [63:0] data;//This is the data from the cache.
    //input [63:0] address;//This is the location in which the cache has been accessed. (stores and loads)
    
    output reg [63:0] p0_dataFromCacheToProcessor;
    //output p0_addressFromCacheToProcessor;
        
    output reg [63:0] p1_dataFromCacheToProcessor;
    //output p1_addressFromCacheToProcessor;
    
    always@(*)begin//maybe change this to just data.
        case(allowedAccess)
            0:  begin
                    p0_dataFromCacheToProcessor = data;
                    p1_dataFromCacheToProcessor = 64'hzzzzzzzzzzzzzzzz;
                end
            1:  begin
                    p1_dataFromCacheToProcessor = data;
                    p0_dataFromCacheToProcessor = 64'hzzzzzzzzzzzzzzzz;                    
                end
        endcase
    end
    
    
endmodule


//enable now will go to everything that has a clock.
module programCounter #(parameter position = 32'h00000000)(clk, enable, instructionAddress);
    input clk;
    input enable;//enable comes from the arbiter
    output reg [31:0] instructionAddress;
    //reg  [31:0] instructionAddress
    reg counter;
    
    initial begin
        counter = 0;
        //instructionAddress = position;
    end
    
    always @(posedge clk) begin
        if(enable) begin
            if(counter < 1)begin
                counter = 1;
                instructionAddress = position;
            end
            else begin
                instructionAddress = instructionAddress + 32'h00000004;
            end
        end
    end
    
endmodule

module instructionMemory #(parameter addOffset = 12'h500)(pc, instruction);

    parameter shamt = 6'b000000;//used in R type instructions.
    
    //==== R Types ====\\
        parameter ADD    = 11'b10001011000;//458
        parameter ADDS  = 11'b10101011000;//558
        parameter AND    = 11'b10001010000;//450
        parameter ORR    = 11'b10101010000;//550
        parameter ANDS  = 11'b11101010000;//750
        parameter EOR    = 11'b11001010000;//650
        parameter SUBS  = 11'b11101011000;//758
        parameter SUB    = 11'b11001011000;//658
        
        parameter LSL    = 11'b11010011011;//69B
        parameter LSR    = 11'b11010011010;//69A
        
        //==== I Types ====\\
        parameter EORI    = 10'b1101001000;//690
        parameter ANDI    = 10'b1001001000;//490
        parameter ANDIS    = 10'b1111001000;//790
        parameter ADDI    = 10'b1001000100;//488
        parameter ADDIS    = 10'b1011000100;//588
        parameter SUBI    = 10'b1101000100;//688
        parameter SUBIS    = 10'b1111000100;//788
        parameter ORRI    = 10'b1011001000;//590
    
        //==== B Types ====\\
        parameter B        = 6'b000101;    //0A0
        parameter BEQ    = 8'b01010101;    //2A8
        parameter BNE    = 8'b01010110;    //2B0
        parameter BLT    = 8'b01010111;    //2B8
        parameter BGE    = 8'b01011000;    //2C0
        
        //==== D Types ====\\
        parameter LDUR    = 11'b11111000010;//7C2
        parameter STUR     = 11'b11111000000;//7C0
    
        //==== CB Type ====\\
        parameter CBNZ    = 8'b10110101;//5A8
        parameter CBZ    = 8'b10110100;//5A0
        
        //==== IW Type ====\\
        parameter MOVZ    = 9'b110100101;//691
        parameter quad0    = 2'b00;
        parameter quad1    = 2'b01;
        parameter quad2    = 2'b10;
        parameter quad3 = 2'b11;
        //=================\\
    
    input [31:0] pc;
    output reg [31:0] instruction; 
    
    reg [31:0] instructionAddress [0:39];
    reg [31:0] instructionData [0:39];
    reg [5:0] idx;
    reg instructionMiss;
    
    always@(pc) begin : search
       
        for(idx = 0; idx < 40; idx = idx + 1) begin
            if(pc == instructionAddress[idx]) begin 
                instruction = instructionData[idx];
		disable search;
		instructionMiss = 0;
            end 
        end
	instruction = 32'hzzzzzzzz;
	instructionMiss = 1;
    end
    
    
    initial begin 
    
      instructionAddress[0]  = 32'h00000000;    instructionData[0] = {ADDI, addOffset, 5'b11111, 5'b00001};
      instructionAddress[1]  = 32'h00000004;    instructionData[1] = 32'h00000000;
      instructionAddress[2]  = 32'h00000008;    instructionData[2] = 32'h00000000;
      instructionAddress[3]  = 32'h0000000c;    instructionData[3] = {LDUR,  9'h000,   2'b00, 5'b00001, 5'b00010};
      instructionAddress[4]  = 32'h00000010;    instructionData[4] = {LDUR,  9'h010,   2'b00, 5'b00001, 5'b00011};
      instructionAddress[5]  = 32'h00000014;    instructionData[5] = {LDUR,  9'h020,   2'b00, 5'b00001, 5'b00100};
      instructionAddress[6]  = 32'h00000018;    instructionData[6] = {LDUR,  9'h030,   2'b00, 5'b00001, 5'b00101};
      instructionAddress[7]  = 32'h0000001c;    instructionData[7] = {LDUR,  9'h040,   2'b00, 5'b00001, 5'b00110};
      instructionAddress[8]  = 32'h00000020;    instructionData[8] = {LDUR,  9'h050,   2'b00, 5'b00001, 5'b00111};
      instructionAddress[9]  = 32'h00000024;    instructionData[9] = {LDUR,  9'h060,   2'b00, 5'b00001, 5'b01000};
      instructionAddress[10] = 32'h00000028;    instructionData[10] = {LDUR,  9'h070,   2'b00, 5'b00001, 5'b01001};
      instructionAddress[11] = 32'h0000002c;    instructionData[11] = {LDUR,  9'h008,   2'b00, 5'b00001, 5'b01010};
      instructionAddress[12] = 32'h00000030;    instructionData[12] = {LDUR,  9'h018,   2'b00, 5'b00001, 5'b01011};
      instructionAddress[13] = 32'h00000034;    instructionData[13] = {LDUR,  9'h028,   2'b00, 5'b00001, 5'b01100};
      instructionAddress[14] = 32'h00000038;    instructionData[14] = {LDUR,  9'h038,   2'b00, 5'b00001, 5'b01101};
      instructionAddress[15] = 32'h0000003c;    instructionData[15] = {LDUR,  9'h048,   2'b00, 5'b00001, 5'b01110};
      instructionAddress[16] = 32'h00000040;    instructionData[16] = {LDUR,  9'h058,   2'b00, 5'b00001, 5'b01111};
      instructionAddress[17] = 32'h00000044;    instructionData[17] = {LDUR,  9'h068,   2'b00, 5'b00001, 5'b10000};
      instructionAddress[18] = 32'h00000048;    instructionData[18] = {LDUR,  9'h078,   2'b00, 5'b00001, 5'b10001};
      instructionAddress[19] = 32'h0000004c;    instructionData[19] = {ADD,   5'd10,    shamt ,   5'd2,    5'd2};
      instructionAddress[20] = 32'h00000050;    instructionData[20] = {ADD,   5'd11,    shamt ,   5'd3,    5'd3};
      instructionAddress[21] = 32'h00000054;    instructionData[21] = {ADD,   5'd12,    shamt ,   5'd4,    5'd4};
      instructionAddress[22] = 32'h00000058;    instructionData[22] = {ADD,   5'd13,    shamt ,   5'd5,    5'd5};
      instructionAddress[23] = 32'h0000005c;    instructionData[23] = {ADD,   5'd14,    shamt ,   5'd6,    5'd6};
      instructionAddress[24] = 32'h00000060;    instructionData[24] = {ADD,   5'd15,    shamt ,   5'd7,    5'd7};
      instructionAddress[25] = 32'h00000064;    instructionData[25] = {ADD,   5'd16,    shamt ,   5'd8,    5'd8};
      instructionAddress[26] = 32'h00000068;    instructionData[26] = {ADD,   5'd17,    shamt ,   5'd9,    5'd9};
      instructionAddress[27] = 32'h0000006c;    instructionData[27] = {STUR,  9'h008,         2'b00,   5'd1,            5'd2};
      instructionAddress[28] = 32'h00000070;    instructionData[28] = {STUR,  9'h018,         2'b00,   5'd1,            5'd3};
      instructionAddress[29] = 32'h00000074;    instructionData[29] = {STUR,  9'h028,         2'b00,   5'd1,            5'd4};
      instructionAddress[30] = 32'h00000078;    instructionData[30] = {STUR,  9'h038,         2'b00,   5'd1,            5'd5};
      instructionAddress[31] = 32'h0000007c;    instructionData[31] = {STUR,  9'h048,         2'b00,   5'd1,            5'd6};
      instructionAddress[32] = 32'h00000080;    instructionData[32] = {STUR,  9'h058,         2'b00,   5'd1,            5'd7};
      instructionAddress[33] = 32'h00000084;    instructionData[33] = {STUR,  9'h068,         2'b00,   5'd1,            5'd8};
      instructionAddress[34] = 32'h00000088;    instructionData[34] = {STUR,  9'h078,         2'b00,   5'd1,            5'd9};
      instructionAddress[35] = 32'h0000008c;    instructionData[35] = 32'h00000000;
      instructionAddress[36] = 32'h00000090;    instructionData[36] = 32'h00000000;
      instructionAddress[37] = 32'h00000094;    instructionData[37] = 32'h00000000;
      instructionAddress[38] = 32'h00000098;    instructionData[38] = 32'h00000000;
      instructionAddress[39] = 32'h0000009c;    instructionData[39] = 32'h00000000;
      
        
    end
    
endmodule




module sharedCache(opcode3, dataAddressBus, dataIn, dataOut, storeCheck, miss);

	input [10:0] opcode3;
	input [63:0] dataAddressBus; //Used to select which register to read and write to. //DataAddressBus = 64'h3628964EDDEEESDS
	input [63:0] dataIn;//The data being stored into the cache.
	output reg [63:0] dataOut;//The data being loaded from the cache.
	output reg [63:0] storeCheck;
	output reg miss;
		 
	reg [63:0] block0Address [0:15];
	reg [63:0] block1Address [0:15];

	reg [63:0] block0Data [0:15];
	reg [63:0] block1Data [0:15];
	 
	reg [4:0] idx;
	
	wire blockOffset = dataAddressBus[3];
	wire [11:0] address = dataAddressBus[11:0];
		
	initial begin 
	
		block0Address[0] = 12'h500; block0Data[0] = 64'd100;//100  
		block1Address[0] = 12'h508; block1Data[0] = 64'd000;//000 
		block0Address[1] = 12'h510; block0Data[1] = 64'd101;//101 
		block1Address[1] = 12'h518; block1Data[1] = -64'd001;//-1
		block0Address[2] = 12'h520; block0Data[2] = 64'd102;//102
		block1Address[2] = 12'h528; block1Data[2] = -64'd002;//-2
		block0Address[3] = 12'h530; block0Data[3] = 64'd103;//103
		block1Address[3] = 12'h538; block1Data[3] = -64'd003;//-3
		block0Address[4] = 12'h540; block0Data[4] = 64'd104;//104
		block1Address[4] = 12'h548; block1Data[4] = -64'd004;//-4
		block0Address[5] = 12'h550; block0Data[5] = 64'd105;//105
		block1Address[5] = 12'h558; block1Data[5] = -64'd005;//-5
		block0Address[6] = 12'h560; block0Data[6] = 64'd106;//106
		block1Address[6] = 12'h568; block1Data[6] = -64'd006;//-6
		block0Address[7] = 12'h570; block0Data[7] = 64'd107;//107
		block1Address[7] = 12'h578; block1Data[7] = -64'd007;//-7
		block0Address[8] = 12'h580; block0Data[8] = 64'd108;//108
		block1Address[8] = 12'h588; block1Data[8] = -64'd008;//-8
		block0Address[9] = 12'h590; block0Data[9] = 64'd109;//109
		block1Address[9] = 12'h598; block1Data[9] = -64'd009;//-9
		
		
		block0Address[10] = 12'h5A0; block0Data[10] = 64'd110;//110
		block1Address[10] = 12'h5A8; block1Data[10] = -64'd010;//-10
		block0Address[11] = 12'h5B0; block0Data[11] = 64'd111;//111
		block1Address[11] = 12'h5B8; block1Data[11] = -64'd011;//-11
		block0Address[12] = 12'h5C0; block0Data[12] = 64'd112;//112
		block1Address[12] = 12'h5C8; block1Data[12] = -64'd012;//-12
		block0Address[13] = 12'h5D0; block0Data[13] = 64'd113;//113
		block1Address[13] = 12'h5D8; block1Data[13] = -64'd013;//-13
		block0Address[14] = 12'h5E0; block0Data[14] = 64'd114;//114
		block1Address[14] = 12'h5E8; block1Data[14] = -64'd014;//-14
		block0Address[15] = 12'h5F0; block0Data[15] = 64'd115;//115
		block1Address[15] = 12'h5F8; block1Data[15] = -64'd015;//-15
        
        miss = 0;
		
	end

	always@(opcode3, dataAddressBus, dataIn, blockOffset, address) begin : search 
		
		if(blockOffset) begin //If block offset == 1
			for(idx = 0; idx < 5'b1_0000; idx = idx + 1) begin//iterate through all the blocks for block 1 
				if(address == block1Address[idx]) begin
					case(opcode3)
						11'h7C0:begin block1Data[idx] = dataIn;  
						              storeCheck = block1Data[idx];
						        end//store
						11'h7C2:begin dataOut = block1Data[idx]; end//load
						default:begin dataOut = 64'hzzzzzzzzzzzzzzzz; end
					endcase
					miss = 0;
					disable search;
				end//end of if(address...
				else begin 
				    miss = 1;
				    dataOut = 64'hzzzzzzzzzzzzzzzz; 
				end
			end//End of for loop
		end//end of if(blockOffset)
	
		else begin//else if blockOffset == 0
			
			for(idx = 0; idx < 5'b1_0000; idx = idx + 1) begin //Iterate through all the blocks for blockOffset 0
				
				if(address == block0Address[idx]) begin//If the address matches the address with block offset 0
					
					case(opcode3)
						
						11'h7C0:begin block0Data[idx] = dataIn; 
					                  storeCheck = block0Data[idx];
					            end//store
						11'h7C2:begin dataOut = block0Data[idx]; end//load
						default:begin dataOut = 64'hzzzzzzzzzzzzzzzz; end
						
					endcase
					miss = 0;
					disable search;
				end
				else begin
				    miss = 1;
				    dataOut = 64'hzzzzzzzzzzzzzzzz; 
				end
			end
			
		end
	
	end 
	 
    
endmodule 



//Program Counter
module pc(clk, reset, iaddrbus_in, iaddrbus_out);
    input clk;
    input reset;
    input [63:0] iaddrbus_in;
    output reg [63:0] iaddrbus_out;//instruction address bus.
    
    //initial iaddrbus_out = 32'b0;
    always @(posedge clk) begin        
        iaddrbus_out = (reset) ? 32'b0 : iaddrbus_in;
    end
endmodule


module branchALUs(iaddrbus, sign_hold1, oldAddress_in, branchFlag2, reset, currentAddress, oldAddress_out, clk);
    input clk;
    input [63:0] iaddrbus; 
    input [63:0] sign_hold1;
    input [63:0] oldAddress_in;
    input branchFlag2;
    input reset;
    
    output [63:0] currentAddress;//This is the address that goes into the program counter. Whatever address for the current instruction is being executed at that time.
    output [63:0] oldAddress_out;//Used if not branching. Just go to the next instruction in line.
    
    //you can't do oldAddress_out = oldAddress_out, its not C code. you need to use a new wire.
    wire [63:0] oldAddress_out2;//this is the output from the pcALU.
    wire [63:0] newAddress, newAddress2;//The new address to jump to when branching.
    wire [63:0] sign_shift, sign_shift2;//Sign Extension multiplied by 4.
    wire [63:0] test;//test needs to be a 64'b number because you want to get rid of the don't cares. You cant get rid of all the don't cares with only 3 bits.

    //==== Resets ====\\
    assign sign_shift      = (reset == 1'b1) ? 64'h0000000000000000 : sign_shift2; 
    assign newAddress      = (reset == 1'b1) ? 64'h0000000000000000 : newAddress2;
    assign oldAddress_out  = (reset == 1'b1) ? 64'h0000000000000000 : oldAddress_out2;
    assign test = (reset) ? 64'h0000000000000000 : 64'h0000000000000004;
    assign branchFlag = (reset == 1'b1) ? 1'b0 : branchFlag2;
    //================\\ 
    
    //Performing the multiplication by 4
    assign sign_shift2 = sign_hold1 << 2;
    
    //The ALU that takes in the sign extension                       
    alu64 SignALU( .d(newAddress2), .Cout(), .V(), .a(sign_shift2), .b(oldAddress_in), .Cin(1'b0), .S(3'b010));//hard coding an add
    
    //========= MUX =========\\							
    assign currentAddress = (reset == 1'b1) ? 64'b0 : ( (branchFlag) ? newAddress : oldAddress_out);  
    //=======================\\
    
    //The ALU that increments the program counter by 4, even if the branch was not taken. (Keeps PC in sync)
    alu64 pcALU(.d(oldAddress_out2), .Cout(), .V(), .a(test), .b(iaddrbus), .Cin(1'b0), .S(3'b010));//hard coding an add
endmodule


module instFetchBus(clk, ibus, ibus_hold, oldAddress1, oldAddress2, reset, enable);
	input clk;
	input reset;
	input [31:0] ibus;
	input [63:0] oldAddress1;
	input enable;
	
	output reg [31:0] ibus_hold;
	output reg [63:0] oldAddress2;
	
	always @(posedge clk) begin
	   if(enable)begin
           if(reset)begin
              ibus_hold = 32'b0;
              oldAddress2 = 64'b0; 
           end else begin
              ibus_hold = ibus;
              oldAddress2 = oldAddress1;
           end
	   end
	end
endmodule


module ARMdecoder(ibus_hold, reset, Aselect, Bselect, Dselect_hold1, Imm, S, Cin, opcode, sign_hold1, DT_address, BR_address, COND_BR_address, movedOutput, shamt, Tselect);
    input reset;
    input  [31:0] ibus_hold;
    
    output [31:0] Aselect, Bselect;
    output [31:0] Tselect;//This is going to be the Tbus, used with STUR.
    output [31:0] Dselect_hold1;
    output [2:0] S;
    output Imm;
    output Cin;
    output [10:0] opcode;//The extended opcode.
    output [63:0] sign_hold1;//sign extension of the immediate value in I type instructions.
    output [8:0] DT_address;//used in D type instructions
    output [63:0] BR_address;//used in B type instructions
    output [63:0] COND_BR_address;//used in CB instructions
    output [63:0] movedOutput;//The immediate LSL 16 bits.
    output [5:0] shamt;//shift ammount. used with Logical Shift Left, and Logical Shift Right.

    wire [15:0] MOVE_immediate;//used in IW instructions
 
 	assign Tselect = Dselect_hold1;
    assign shamt = ibus_hold[15:10];
    assign DT_address = ibus_hold[20:12];
    assign MOVE_immediate = ibus_hold[20:5];
    
    ARMopcode ARMopcode_decoder(.ibus_hold(ibus_hold), .Imm(Imm), .S(S), .Cin(Cin), .gen_opcode(opcode) );//opcode
    
    ARM_rn_decoder rnDecoderA(.rnBits(ibus_hold[9:5]  ), .rn_out(Aselect));//Aselect
    ARM_rm_decoder rmDecoderB(.rmBits(ibus_hold[20:16]), .rm_out(Bselect));//Bselect
    ARM_rd_decoder rdDecoderD(.rdBits(ibus_hold[4:0]  ), .rd_out(Dselect_hold1));//Dselect
    
    ARM_sign_extension ARM_Sign_Extend(.ibus_hold(ibus_hold), .sign_hold1(sign_hold1) );//Sign Extension
    branchExtension BranchExtension(.ibus_hold(ibus_hold), .branchAddress(BR_address));
    CondBranchExtension CondBranchExtension(.ibus_hold(ibus_hold), .COND_BR_address(COND_BR_address));
    
    ARM_Moves ARM_MoveWide(.ibus_hold(ibus_hold), .MOVE_immediate(MOVE_immediate), .movedOutput(movedOutput));
endmodule


//Takes in the first 11 bits and decifer it
module ARMopcode(ibus_hold, Imm, S, Cin, gen_opcode);
    input [31:0] ibus_hold;
    output reg [2:0] S;
    output reg Imm;
    output reg Cin;
    output reg [10:0] gen_opcode;//A generic opcode with 0's appended on the right end if necessary.
    								 
    reg SUPERFLAG; initial SUPERFLAG = 1'b0;
    reg [10:0] opcodeZ;
    always @(ibus_hold) begin
    	opcodeZ = ibus_hold[31:21];
		//==== Checking if the Instruction is a B type instruction ====\\
		if(opcodeZ[10:5] == 6'b000101)begin//B
			Imm = 1'b0;
			S = 3'b010;
			Cin = 1'b0;
			gen_opcode = 11'b00010100000;
		end
		else if(opcodeZ[10:3] == 8'b01010101)begin//BEQ
			Imm = 1'b0;
			S = 3'b010;
			Cin = 1'b0;
			gen_opcode = 11'b01010101000;
		end
		else if(opcodeZ[10:3] == 8'b01010110)begin//BNE
			Imm = 1'b0;
			S = 3'b010;
			Cin = 1'b0;	
			gen_opcode = 11'b01010110000;
		end
		else if(opcodeZ[10:3] == 8'b01010111)begin//BLT
			Imm = 1'b0;
			S = 3'b010;
			Cin = 1'b0;
			gen_opcode = 11'b01010111000;	
		end
		else if(opcodeZ[10:3] == 8'b01011000)begin//BGE
			Imm = 1'b0;
			S = 3'b010;
			Cin = 1'b0;
			gen_opcode = 11'b01011000000;	
		end
		//==== Checking if the instruction is a Conditional Branch type Instruction ====\\
		else if(opcodeZ[10:3] == 8'b10110101)begin//CBNZ
			Imm = 1'b0;
			S = 3'b010;
			Cin = 1'b0;
			gen_opcode = 11'b10110101000;
		end
		else if(opcodeZ[10:3] == 8'b10110100)begin//CBZ
			Imm = 1'b0;
			S = 3'b010;
			Cin = 1'b0;
			gen_opcode = 11'b10110100000;
		end
		
		//==== Checking if the instruction is an I type instruction ====\\
		else if((opcodeZ[4:1] == 4'b0100 || opcodeZ[4:1] == 4'b1000) && opcodeZ[7:5] == 3'b100)begin
			gen_opcode = opcodeZ[10:1] << 1;//Bit Shifting the opcode by 1 to append one 0 on the end.
			case(opcodeZ[10:8])
				3'b100:	begin
							case(opcodeZ[4])
								1'b1:	begin//ANDI
											S = 3'b110;
											Cin = 1'b0;
											Imm = 1'b1;
										end
								1'b0:	begin//ADDI
											S = 3'b010;
											Cin = 1'b0;
											Imm = 1'b1;
										end
							endcase
						end
				3'b101:	begin
							case(opcodeZ[4])
								1'b1:	begin//ORRI
											S = 3'b100;
											Cin = 1'b0;
											Imm = 1'b1;
										end
								1'b0:	begin//ADDIS
											S = 3'b010;
											Cin = 1'b0;
											Imm = 1'b1;
										end
							endcase
						end
				3'b110:	begin
							case(opcodeZ[4])
								1'b1:	begin//EORI
											S = 3'b000;
											Cin = 1'b0;
											Imm = 1'b1;
										end
								1'b0:	begin//SUBI
								        	S = 3'b011;
											Cin = 1'b1;
											Imm = 1'b1;
										end
							endcase
						end
				3'b111:	begin
							case(opcodeZ[4])
								1'b1:	begin//ANDIS
                   							S = 3'b110;
											Cin = 1'b0;
											Imm = 1'b1;
										end
								1'b0:	begin//SUBIS
											S = 3'b011;
											Cin = 1'b1;
											Imm = 1'b1;
										end
							endcase
						end
			endcase
		end
		//==== End of I Type Instructions ====\\
		
		//==== D Type Instrucitons ====\\
		else if(opcodeZ == 11'b11111000010)begin//LDUR 11'h7C2
			//Examples on page 14 of the lecture slides.
			S = 3'b010;//This is add because you want to add to the address.
			Cin = 1'b0;//Think of an array.
			Imm = 1'b0;
			gen_opcode = opcodeZ;
		end
		else if(opcodeZ == 11'b11111000000)begin//STUR 11'h7C0
			//Examples on page 14 of the lecture slides.
			S = 3'b010;//This is add because you want to add to the address.
			Cin = 1'b0;//Think of an array.
			Imm = 1'b0;
			gen_opcode = opcodeZ;
		end
		//==== End of D Type Instructions ====\\
		
		//==== IW Type Instructions ====\\
		//Immediate Wide.
		else if(opcodeZ[10:2] == 9'b110100101)begin//MOVZ - Move Wide With Zeros
			//MOVEZ loads a 16 bit constant and sets all other bits to zero.
			//Take 16 Immediate bits, left shift them 16 bits and insert it into the destination register.
			//Example on page 97 of the lecture slides.
			S = 3'b010;
			Cin = 1'b0;
			Imm = 1'b1;
			gen_opcode = 11'b11010010100;
		end
		//==== End of IW Type Instructions ====\\
		
		
		//==== Checking if the instruction is an R type instruction ====\\
		else if(opcodeZ[2:0] == 3'b000 && opcodeZ[6:4] == 3'b101)begin
			gen_opcode = opcodeZ;
			case(opcodeZ[10:7])
				4'b1000:	begin
								case(opcodeZ[3])
									1'b1:	begin//ADD
						                    	S = 3'b010;
												Cin = 1'b0;
												Imm = 1'b0;	
											end
									1'b0: 	begin//AND
								            	S = 3'b110;
												Cin = 1'b0;
												Imm = 1'b0;
											end
								endcase
							end
				4'b1010:	begin
								case(opcodeZ[3])
									1'b1:	begin//ADDS
												S = 3'b010;
												Cin = 1'b0;
												Imm = 1'b0;
											end
									1'b0: 	begin//ORR
												S = 3'b100;
												Cin = 1'b0;
												Imm = 1'b0;
											end
								endcase
							end
				4'b1100:	begin
								case(opcodeZ[3])
									1'b1:	begin//SUB
												S = 3'b011;
												Cin = 1'b1;
												Imm = 1'b0;
											end
									1'b0: 	begin//EOR
												S = 3'b000;
												Cin = 1'b0;
												Imm = 1'b0;
											end
								endcase
							end
				4'b1110:	begin
								case(opcodeZ[3])
									1'b1:	begin//SUBS
												S = 3'b011;
												Cin = 1'b1;
												Imm = 1'b0;
											end
									1'b0: 	begin//ANDS
                   								S = 3'b110;
												Cin = 1'b0;
												Imm = 1'b0;
											end
								endcase
							end
			endcase
		end//end of 'most' R type instructions		
		else if(opcodeZ == 11'b11010011011)begin//LSL
			//We will have to overide the output from the ALU with this instruction
			S = 3'b010;
			Cin = 1'b0;
			Imm = 1'b0;
			gen_opcode = opcodeZ;
		end
		else if(opcodeZ == 11'b11010011010)begin//LSR
			//we will have overide the output from the ALU with this instruction.
			S = 3'b010;
			Cin = 1'b0;
			Imm = 1'b0;
			gen_opcode = opcodeZ;
		end
		//==== End of R Type instructions ====\\
    end//end of always @(ibus_hold)
    
endmodule



module ARM_rn_decoder(rnBits, rn_out);
	input [4:0] rnBits;
	output [31:0] rn_out;

	//building a table on the fly. Elimates 32 case statements
	wire [31:0] slider;
	assign slider = 32'h00000001;
	
	assign rn_out = slider << rnBits;
endmodule



module ARM_rm_decoder(rmBits, rm_out);
	input [4:0] rmBits;
	output [31:0] rm_out;

	//building a table on the fly. Elimates 32 case statements
	wire [31:0] slider;
	assign slider = 32'h00000001;
	
	assign rm_out = slider << rmBits;
endmodule


module ARM_rd_decoder(rdBits, rd_out);
	input [4:0] rdBits;
	output [31:0] rd_out;

	//building a table on the fly. Elimates 32 case statements
	wire [31:0] slider;
	assign slider = 32'h00000001;
	
	assign rd_out = slider << rdBits;
endmodule


module ARM_sign_extension(ibus_hold, sign_hold1);
    //input reset;
    input [31:0] ibus_hold;
    output [63:0] sign_hold1;
    
    
    assign sign_hold1[63:12] = 52'h0000000000000;
    assign sign_hold1[11:0]  = ibus_hold[21:10]; 

endmodule

module branchExtension(ibus_hold, branchAddress);
	input [31:0] ibus_hold;
	output reg [63:0] branchAddress;
	
	//Used when needed, Used with unconditional branches.
	//creating a sign extension of the branch address.
/*	assign branchAddress[63:26] = (ibus_hold[25] == 1'b1) ? 38'h3FFFFFFFFF : 38'h0000000000 ; 
	assign branchAddress[25:0] = ibus_hold[25:0];*/
	initial branchAddress = 64'h0000000000000000;

	always @(ibus_hold)begin
		case(ibus_hold[25])
			1'b1:	branchAddress[63:26] = 38'h3FFFFFFFFF;
			1'b0:	branchAddress[63:26] = 38'h0000000000;
			default: branchAddress = 64'h0000000000000000;
		endcase
		branchAddress[25:0] = ibus_hold[25:0];
	end

endmodule



//one dollar teriyaki at by the quincy market area, google kaloon.

module CondBranchExtension(ibus_hold, COND_BR_address);
	input [31:0] ibus_hold;
	output reg [63:0] COND_BR_address;

	//Conditional Branch Extension.
/*	assign COND_BR_address[63:19] = (ibus_hold[23] == 1'b1) ?  45'h1FFFFFFFFFFF : 45'h000000000000;
	assign COND_BR_address[18:0] = ibus_hold[23:5];*/
	initial COND_BR_address = 64'h0000000000000000;
	
	always @(ibus_hold)begin
		case(ibus_hold[23])
			1'b1:	COND_BR_address[63:19] = 45'h1FFFFFFFFFFF;
			1'b0:	COND_BR_address[63:19] = 45'h000000000000;
			default:	COND_BR_address = 64'h0000000000000000;
		endcase
		
		COND_BR_address[18:0] = ibus_hold[23:5];
	end

endmodule

module ARM_Moves(ibus_hold, MOVE_immediate, movedOutput);
	input [31:0] ibus_hold;
	input [15:0] MOVE_immediate;
	output reg [63:0] movedOutput;
	
	always @(ibus_hold)begin
		case(ibus_hold[31:23])//The 9bit opcode to put into a case statement.
			11'b110100101:	begin//is the 9 bit opcode MOVZ
								case(ibus_hold[22:21])//This is the quad code, aka second appendage of opcode.
									2'b00:	movedOutput = MOVE_immediate << 0;//first 16 bits
									2'b01:	movedOutput = MOVE_immediate << 16;//second 16 bits 
									2'b10:	movedOutput = MOVE_immediate << 32;//third 16 bits 
									2'b11:  movedOutput = MOVE_immediate << 48;//fourth 16 bits
								endcase
							end
			//allow for future instructions to be added here.
		endcase
	end
endmodule

module regfile(clk, Aselect, Bselect, Dselect, Tselect, dbus, abus, bbus, tbus, registerVal);
	input clk;
	input [31:0] Aselect, Bselect, Dselect, Tselect;
	input [63:0] dbus;//This is the data going in to the data bus. then 32 flipflops.
	output [63:0] abus, bbus, tbus;//This takes the output from the triBuffers.
	output [63:0] registerVal;
	
    register register31(.clk(clk), .dbus(32'b0), .Aselect(Aselect[31]), .Bselect(Bselect[31]), .Dselect(Dselect[31]), .Tselect(Tselect[31]), .abus(abus), .bbus(bbus), .tbus(tbus), .registerVal(registerVal));
    register register[30:0](.clk(clk), .dbus(dbus[63:0]), .Aselect(Aselect[30:0]), .Bselect(Bselect[30:0]), .Dselect(Dselect[30:0]), .Tselect(Tselect[30:0]), .abus(abus), .bbus(bbus), .tbus(tbus), .registerVal(registerVal));
endmodule



//making 32 flip flops
module register(clk, dbus, Aselect, Bselect, Dselect, Tselect, abus, bbus, tbus, registerVal);
	input clk;
	input Aselect, Bselect, Dselect, Tselect;
	input [63:0] dbus;
	output [63:0] abus, bbus, tbus;
	output reg [63:0] registerVal;

	initial begin
		registerVal = 64'b0;
	end 

	always @(negedge clk)begin
		if(Dselect) begin
			registerVal = dbus;
		end
	end

	//creating 32 tri state buffers
	assign abus = Aselect ? registerVal : 64'bz;
	assign bbus = Bselect ? registerVal : 64'bz;
	assign tbus = Tselect ? registerVal : 64'bz;
	
endmodule




module logicalShifter(abus_hold1, shamt1, opcode1, shiftedValue);
	input [63:0] abus_hold1;
	input [5:0] shamt1;//why is shamt1 6 bits
	input [10:0] opcode1;//used to select either LSL or LSR
	output [63:0] shiftedValue;
	
	assign shiftedValue = 	(opcode1 == 11'h69B) ? abus_hold1 << shamt1 :
						  	(opcode1 == 11'h69A) ? abus_hold1 >> shamt1 : 
						  	64'b0;
	
endmodule


module ARM_BranchDecisions(reset, abus_hold1, bbus_hold1, ibus_hold, opcode1, branchFlag, NZVC, tbus_hold1);
    input reset;
    input [3:0] NZVC;
    input [31:0] ibus_hold;
    input [63:0] abus_hold1;
    input [63:0] bbus_hold1;
    input [63:0] tbus_hold1;
    input [10:0] opcode1;
    output reg branchFlag;
    
    //reg SUPERFLAG; initial SUPERFLAG = 1'b0;

	//always @(abus_hold1 or bbus_hold1)begin
	always @(NZVC or ibus_hold or opcode1)begin
		if(reset)begin
			branchFlag = 1'b0;
		end 
		else begin
			branchFlag =( opcode1 == 11'h0A0) ? 1'b1 : //B, if the instruction is an unconditional branch, then branch.
						((opcode1 == 11'h5A0) && (tbus_hold1 == 64'b0)) ? 1'b1 : //CBZ, compare and branch on zero
						((opcode1 == 11'h5A8) && (tbus_hold1 != 64'b0)) ? 1'b1 : //CBNZ, compare and branch on not zero.
						((opcode1 == 11'h2A8) && (NZVC[2] == 1'b1)) ? 1'b1 : //BEQ Branch if Equal, Unsigned: if Z == 1
						((opcode1 == 11'h2B0) && (NZVC[2] == 1'b0)) ? 1'b1 : //BNE Branch if Not Equal, Unsigned: if Z == 0 
						((opcode1 == 11'h2B8) && (NZVC[3] != NZVC[1])) ? 1'b1 : //BLT Branch if Less Than, Signed: 
						((opcode1 == 11'h2C0) && (NZVC[3] == NZVC[1])) ? 1'b1 : //BGE Branch if Greater Than or Equal To, Signed
						1'b0;
			//SUPERFLAG = ((opcode1 == 11'h5A8) && (NZVC[2] == 1'b0)) ? 1'b1 : 1'b0;
		end
	end
	
endmodule






/*

    always @(ibus_hold)begin
        //branchFlag = branchFlagBuff;
        if(reset)begin
        	branchFlag = 1'b0;
        end
        else begin								   //Flag Conditions
        	branchFlag =  (opcode1 == 11'h0A0) ? 1'b1 : //B, if the instruction is an unconditional branch, then branch.
        				 ((opcode1 == 11'h5A0) && (NZVC[2] == 1'b1)) ? 1'b1 : //CBZ, compare and branch on zero
        				 ((opcode1 == 11'h5A8) && (NZVC[2] == 1'b0)) ? 1'b1 : //CBNZ, compare and branch on not zero.
        				 ((opcode1 == 11'h2A8) && (NZVC[2] == 1'b1)) ? 1'b1 : //BEQ Branch if Equal, Unsigned: if Z == 1
						 ((opcode1 == 11'h2B0) && (NZVC[2] == 1'b0)) ? 1'b1 : //BNE Branch if Not Equal, Unsigned: if Z = 0 
						 ((opcode1 == 11'h2B8) && (NZVC[3] != NZVC[1])) ? 1'b1 : //BLT Branch if Less Than, Signed: 
						 ((opcode1 == 11'h2C0) && (NZVC[3] == NZVC[1])) ? 1'b1 : //BGE Branch if Greater Than or Equal To, Signed
						 1'b0;
						 //Signed means if the left most bit is a 1, the number is a negative.
        end
    end 






branchFlag = ((opcode1 == 11'h2A8) && (abus_hold1 == bbus_hold1)) ? 1'b1 : //BEQ Branch if Equal, Unsigned
						 ((opcode1 == 11'h2B0) && (abus_hold1 != bbus_hold1)) ? 1'b1 : //BNE Branch if Not Equal, Unsigned
						 ((opcode1 == 11'h2B8) && (abus_hold1 <  bbus_hold1)) ? 1'b1 : //BLT Branch if Less Than, Signed: Signed means if the left most bit is a 1, the number is a negative.
						 ((opcode1 == 11'h2C0) && (abus_hold1 >= bbus_hold1)) ? 1'b1 : //BGE Branch if Greater Than or Equal To, Signed
						 1'b0;


	//old ternary operator.
    assign branchFlagBuff = (opcode1 == 11'h2A8) ? //BEQ
                            ( (abus_hold1 == bbus_hold1)?1'b1:1'b0 ) : 
                                ( (opcode1 == 11'h2B0) //BNE
                                    ? ( (abus_hold1 != bbus_hold1)?1'b1:1'b0 ) : 
                                        1'b0 );

*/




//    wire branchFlag2;
//    assign branchFlag2 = (reset) ? 1'b0 : 1'b0;
    
//						   //Flag Conditions
//	assign branchFlag =  (!reset) ? branchFlag2 : //This is why you never branch. always picking 0. because reset will always be low.
//						 ( opcode1 == 11'h0A0) ? 1'b1 : //B, if the instruction is an unconditional branch, then branch.
//						 ((opcode1 == 11'h5A0) && (NZVC[2] == 1'b1)) ? 1'b1 : //CBZ, compare and branch on zero
//						 ((opcode1 == 11'h5A8) && (NZVC[2] == 1'b0)) ? 1'b1 : //CBNZ, compare and branch on not zero.
//						 ((opcode1 == 11'h2A8) && (NZVC[2] == 1'b1)) ? 1'b1 : //BEQ Branch if Equal, Unsigned: if Z == 1
//						 ((opcode1 == 11'h2B0) && (NZVC[2] == 1'b0)) ? 1'b1 : //BNE Branch if Not Equal, Unsigned: if Z = 0 
//						 ((opcode1 == 11'h2B8) && (NZVC[3] != NZVC[1])) ? 1'b1 : //BLT Branch if Less Than, Signed: 
//						 ((opcode1 == 11'h2C0) && (NZVC[3] == NZVC[1])) ? 1'b1 : //BGE Branch if Greater Than or Equal To, Signed
//						 1'b0;
//						 //Signed means if the left most bit is a 1, the number is a negative.


//Execution Bus is the execution state of the pipeline.
					//Inputs			//Outputs
module executionBus(clk, 
					reset,
					enable, 
					Imm_in, 			Imm, 
					Cin_in, 			Cin, 
					S_in, 				S, 
					abus_hold, 			abus, 
					bbus_hold1, 		bbus_hold2, 
					sign_hold1, 		sign_hold2, 
					Dselect_hold1, 		Dselect_hold2, 
					opcode_in, 			opcode_out, 
					movedOutput1, 		movedOutput2, 
					shiftedValue1, 		shiftedValue2,  
					tbus_hold1, 		tbus_hold2,
					DT_address1,        DT_address2,
					ibus_hold,          ibus_hold2
					);
	
	//Inputs							//Outputs
	input clk;							
	input reset;
	input enable;                    	
	input Imm_in;                   	output reg Imm;                                 
	input Cin_in;                   	output reg Cin;                 
	input [2:0] S_in;               	output reg [2:0] S;             
	input [63:0] abus_hold;         	output reg [63:0] abus;         
	input [63:0] bbus_hold1;        	output reg [63:0] bbus_hold2;   
	input [63:0] sign_hold1;	    	output reg [63:0] sign_hold2;   
	input [31:0] Dselect_hold1;     	output reg [31:0] Dselect_hold2;
	input [10:0] opcode_in;         	output reg [10:0] opcode_out;      
	input [63:0] movedOutput1;      	output reg [63:0] movedOutput2; 
	input [63:0] shiftedValue1;     	output reg [63:0] shiftedValue2;
	input [63:0] tbus_hold1;        	output reg [63:0] tbus_hold2;   
	input [8:0] DT_address1;            output reg [8:0] DT_address2;
	input [31:0] ibus_hold;             output reg [31:0]ibus_hold2;

                

	//clock everything!
	always @(posedge clk) begin
	   if(enable)begin
           if(reset)begin
                Imm = 1'b0;
                Cin = 1'b0;
                S = 3'b0;
                abus = 64'b0;
                bbus_hold2 = 64'b0;
                sign_hold2 = 64'b0;
                Dselect_hold2 = 32'b0;
                opcode_out = 12'b0;
                movedOutput2 = 64'b0;
                shiftedValue2 = 64'b0;
                tbus_hold2 = 64'b0;
                DT_address2 = 9'b0;
                ibus_hold2 = 32'b0;
           end else begin
                Imm = Imm_in;
                Cin = Cin_in;
                S = S_in;
                abus = abus_hold;
                bbus_hold2 = bbus_hold1;
                sign_hold2 = sign_hold1;
                Dselect_hold2 = Dselect_hold1;
                opcode_out = opcode_in;
                movedOutput2 = movedOutput1;
                shiftedValue2 = shiftedValue1;
                tbus_hold2 = tbus_hold1;
                DT_address2 = DT_address1;
                ibus_hold2 = ibus_hold;
           end
       end
	end
endmodule




module myMux(ifTrue, ifFalse, Imm, mux_out);
	input [63:0] ifTrue;
	input [63:0] ifFalse;
	input Imm;
	
	output [63:0] mux_out;
	
	assign mux_out = Imm ? ifTrue : ifFalse;
	
endmodule



module alu64 (d, Cout, V, a, b, Cin, S);
   output[63:0] d;
   output Cout, V;
   input [63:0] a, b;
   input Cin;
   input [2:0] S;
   
   wire [63:0] c, g, p;
   wire gout, pout;
   
   alu_cell mycell[63:0] (.d(d), .g(g), .p(p), .a(a), .b(b), .c(c), .S(S));
   
   lac6 lac(.c(c), .gout(gout), .pout(pout), .Cin(Cin), .g(g), .p(p));

   overflow ov(.Cout(Cout), .V(V), .g(gout), .p(pout), .c31(c[63]), .Cin(Cin));   
  
endmodule


module alu_cell (d, g, p, a, b, c, S);
   output d, g, p;
   input a, b, c;
   input [2:0] S;      
   reg g,p,d,cint,bint;
     
   always @(a,b,c,S,p,g) begin 
     bint = S[0] ^ b;
     g = a & bint;
     p = a ^ bint;
     cint = S[1] & c;
    
    //maybe structure this as a case statement.
    //But, dont fix what isn't broken.
    
      if(S[2]==0)
         begin
            d = p ^ cint;
         end
         
       else if(S[2]==1)
          begin
             if((S[1]==0) & (S[0]==0)) begin
                d = a | b;
                end
             else if ((S[1]==0) & (S[0]==1)) begin
                d = ~(a | b);
                end
             else if ((S[1]==1) & (S[0]==0)) begin
                d = (a & b);
                end   
             else
                d = 0;
                end
       end             
endmodule


module overflow (Cout, V, g, p, c31, Cin);
   output Cout, V;
   input g, p, c31, Cin;
   
   assign Cout = g|(p&Cin);
   assign V = Cout^c31;   
endmodule


module lac(c, gout, pout, Cin, g, p);

   output [1:0] c;
   output gout;
   output pout;
   input Cin;
   input [1:0] g;
   input [1:0] p;

   assign c[0] = Cin;
   assign c[1] = g[0] | ( p[0] & Cin );
   assign gout = g[1] | ( p[1] & g[0] );
   assign pout = p[1] & p[0];
	
endmodule


module lac2 (c, gout, pout, Cin, g, p);
   output [3:0] c;
   output gout, pout;
   input Cin;
   input [3:0] g, p;
   
   wire [1:0] cint, gint, pint;
   
   lac leaf0(.c(c[1:0]), .gout(gint[0]), .pout(pint[0]), .Cin(cint[0]), .g(g[1:0]), .p(p[1:0]));
   
   lac leaf1(.c(c[3:2]), .gout(gint[1]), .pout(pint[1]), .Cin(cint[1]), .g(g[3:2]), .p(p[3:2]));
   
   lac root(.c(cint), .gout(gout), .pout(pout), .Cin(Cin), .g(gint), .p(pint) );
endmodule   


module lac3 (c, gout, pout, Cin, g, p);
   output [7:0] c;
   output gout, pout;
   input Cin;
   input [7:0] g, p;
   
   wire [1:0] cint, gint, pint;
   
   lac2 leaf0( .c(c[3:0]), .gout(gint[0]), .pout(pint[0]), .Cin(cint[0]), .g(g[3:0]), .p(p[3:0]));
   
   lac2 leaf1(.c(c[7:4]), .gout(gint[1]), .pout(pint[1]), .Cin(cint[1]), .g(g[7:4]), .p(p[7:4]));
   
   lac root(.c(cint), .gout(gout), .pout(pout), .Cin(Cin), .g(gint), .p(pint));
endmodule
      

module lac4 (c, gout, pout, Cin, g, p);
   output [15:0] c;
   output gout, pout;
   input Cin;
   input [15:0] g, p;
   
   wire [1:0] cint, gint, pint;
   
   lac3 leaf0(.c(c[7:0]), .gout(gint[0]), .pout(pint[0]), .Cin(cint[0]), .g(g[7:0]), .p(p[7:0]));
   
   lac3 leaf1(.c(c[15:8]), .gout(gint[1]), .pout(pint[1]), .Cin(cint[1]), .g(g[15:8]), .p(p[15:8]));
   
   lac root(.c(cint), .gout(gout), .pout(pout), .Cin(Cin), .g(gint), .p(pint));
endmodule
      

module lac5 (c, gout, pout, Cin, g, p);
   output [31:0] c;
   output gout, pout;
   input Cin;
   input [31:0] g, p;
   
   wire [1:0] cint, gint, pint;
   
   lac4 leaf0(.c(c[15:0]), .gout(gint[0]), .pout(pint[0]), .Cin(cint[0]), .g(g[15:0]), .p(p[15:0]));
   
   lac4 leaf1(.c(c[31:16]), .gout(gint[1]), .pout(pint[1]), .Cin(cint[1]), .g(g[31:16]), .p(p[31:16]));
   
   lac root(.c(cint), .gout(gout), .pout(pout), .Cin(Cin), .g(gint), .p(pint));
endmodule

module lac6(c, gout, pout, Cin, g, p);
	output [63:0] c;
   output gout, pout;
   input Cin;
   input [63:0] g, p;
	
	wire [1:0] cint, gint, pint;
	
	lac5 leaf0( .c(c[31:0]), .gout(gint[0]), .pout(pint[0]), .Cin(cint[0]), .g(g[31:0]), .p(p[31:0]) );
	
	lac5 leaf1( .c(c[63:32]), .gout(gint[1]), .pout(pint[1]), .Cin(cint[1]), .g(g[63:32]), .p(p[63:32]) );
	
	lac root(.c(cint), .gout(gout), .pout(pout), .Cin(Cin), .g(gint), .p(pint));
endmodule


module NZVC_Register(opcode2, dbus_hold0, V, C, NZVC);
	input [10:0] opcode2;//The opcode after the being clocked in the execution bus.
	input [63:0] dbus_hold0;//the output from the alu.
	input V;//from the ALU to signify if an oVerflow occured.
	input C;//from the ALU to signify if a carryout of the most significant bit, or a borrow into the most significant bit.
	
	//{N, Z, V, C} == {3, 2, 1, 0}, Example NZVC[3] = N.
	output reg [3:0] NZVC;//These are the NZVC bits that are set when performing a set instruction.
	initial NZVC = 4'b0000;
	
	always @(dbus_hold0)begin
		NZVC[3] = (dbus_hold0[63] == 1'b1) ? 1'b1 : 1'b0;//If the MSB is a 1, then the number is a negative number.
		NZVC[2] = (dbus_hold0 == 64'b0) ? 1'b1 : 1'b0;//If the entire result from the ALU is 0, then set the Z bit.
		NZVC[1] = V;//is this actually correct? My be a bug later.
		NZVC[0] = C;//is this actually correct?
	end
endmodule


//Memory Bus is the memory stage of the pipeline.
					//Inputs		//Outputs
module memoryBus(	clk, 
					reset,
					enable, 
					dbus_hold, 		dbus, 
					Dselect_hold2, 	Dselect, 
					opcode_in, 		opcode_out, 
					C, 				C_hold1, 
					shiftedValue2, 	shiftedValue3, 
					tbus_hold3, 	tbus_hold4,
					ibus_hold2,     ibus_hold3 
					);
					
	//Inputs							//Outputs				
	input clk;
	input reset;
	input enable;
	input [63:0] dbus_hold;				output reg [63:0] dbus;
	input [31:0] Dselect_hold2;			output reg [31:0] Dselect;
	input C;							output reg C_hold1;
	input [10:0] opcode_in;				output reg [10:0] opcode_out;
	input [63:0] shiftedValue2;			output reg [63:0] shiftedValue3;
	input [63:0] tbus_hold3;			output reg [63:0] tbus_hold4;
	input [31:0] ibus_hold2;            output reg [31:0] ibus_hold3;
	
	always @(posedge clk) begin
           if(enable)begin
           if(reset) begin
                dbus = 64'b0;
                Dselect = 32'b0;
                C_hold1 = 1'b0;
                opcode_out = 12'b0;
                shiftedValue3 = 64'b0;
                tbus_hold4 = 64'b0;
                ibus_hold3 = 32'b0;
           end else begin
                dbus = dbus_hold;
                Dselect = Dselect_hold2;
                C_hold1 = C;
                opcode_out = opcode_in;
                shiftedValue3 = shiftedValue2;
                tbus_hold4 = tbus_hold3;
                ibus_hold3 = ibus_hold2;
           end
        end
	end
endmodule

module ARM_databus_driver(databus, reset, tbus_hold4_buff, opcode3, databus_out);
	inout [63:0] databus;
	input reset;
	input [63:0] tbus_hold4_buff;
	input [10:0] opcode3;
	output [63:0] databus_out;
																	//11'h7C0 == STUR
	assign databus 		= (reset == 1'b1) ? 64'h0000000000000000 : (opcode3 == 11'h7C0) ? tbus_hold4_buff : 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;//adding the reset to the databus.//ORIGINAL
    assign databus_out	= (reset == 1'b1) ? 64'h0000000000000000 : databus ;   
endmodule



//Writeback is the writeback stage of the CPU
					//Inputs		//Outputs
module writeback(	clk, 
					reset,
					enable,
					databus_in, 	databus_out,
					daddrbus_in,  	daddrbus_out, 
					Dselect_hold3, 	Dselect, 
					opcode_in, 		opcode_out,  
					shiftedValue3, 	shiftedValue4,
					ibus_hold3,     ibus_hold4
					);
    
    //Inputs							//Outputs
    input clk;
    input reset;
    input enable;    
    input [63:0] databus_in;		    output reg [63:0] databus_out;
    input [63:0] daddrbus_in;		    output reg [63:0] daddrbus_out;
    input [10:0] opcode_in;			    output reg [10:0] opcode_out;
    input [31:0] Dselect_hold3;		    output reg [31:0] Dselect;
    input [63:0] shiftedValue3;		    output reg [63:0] shiftedValue4;
    input [31:0] ibus_hold3;            output reg [31:0] ibus_hold4;
    

    always @(posedge clk)begin
        if(enable)begin
            if(reset) begin
                databus_out = 64'b0; //may cause problems
                daddrbus_out = 64'b0;
                Dselect = 32'b0;
                opcode_out = 12'b0;
               // C_hold2 = 1'b0;
                shiftedValue4 = 64'b0;
                ibus_hold4 = 32'b0;
            end else begin
                databus_out = databus_in;
                daddrbus_out = daddrbus_in;
                Dselect = Dselect_hold3;
                opcode_out = opcode_in;
                shiftedValue4 = shiftedValue3;
                ibus_hold4 = ibus_hold3;
            end
        end
    end
    
endmodule






