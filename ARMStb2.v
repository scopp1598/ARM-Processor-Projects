module ARMStb2();
    
    reg clk;//input to cpu
    //reg [31:0] instruction;//input to cpu
   // wire [63:0] instructionAddress;//output from cpu
    reg reset;
    //integer counter;
    
    //reg superFlag;
    
    
    
    wire[31:0] instructionAddressBus0;//From the PC 0 telling the instructionCache0 which instruction to output to processor 0.
    wire[31:0] instructionAddressBus1;
    wire[31:0] ibus0;//leaves instructionCache0 going to processor 0.
    wire[31:0] ibus1;//Leaves instruction cache and is the instruction to the processor.
    wire[10:0] p0_opcode3;//coming from the processor0 going to the arbiter.
    wire[10:0] p1_opcode3;//coming from the processor1 going to the arbiter.
    wire [63:0] addressFromProcessorToArbiter0;//This is the address for stores, leaving the processor0 going to the arbiter
    wire [63:0] addressFromProcessorToArbiter1;//this is the address for stores, leaving the processor1 going to the arbiter
    wire [63:0] dataFromProcessorToArbiter0;//This is the data for stores, leaving the processor0 going to the arbiter.
    wire [63:0] dataFromProcessorToArbiter1;//this is the data for stores, leaving the processor1 going to the arbiter.    
    
    wire [63:0] addressToCache;//leaving the arbiter going to the data cache.
    wire [63:0] dataToCache;//leaving the arbiter going to the data cache
    wire [10:0] arbiterOpcode3;//leaving the arbiter, going around the cache into the mux after the cache.
    
    wire p0_enable;//leaving the arbiter, going to the processor0.
    wire p1_enable;//leaving the arbiter, going to the processor1.
    
    wire [63:0] dataFromCacheToMux;//leaving the cache, going to the inverseMux
    wire [63:0] dataFromCacheToProcessor0;//leaving the inverseMux, going to processor0
    wire [63:0] dataFromCacheToProcessor1;//leaving the inverseMux, going to processor1
    
    //Allowed access leaves the arbiter, goes around the D$ and into the inverse mux after the cache.
    wire allowedAccess;//0 corresponds to processor 0 needing the cache.(p0 has access to the cache)  1 corresponds to processor 1 needing to use the cache. 
    
        
    programCounter #(32'h00000000) programCounter0( /*Inputs*/
                                                    .clk(clk), 
                                                    .enable(p0_enable),//Comes from the arbiter 
                                                    /*Outputs*/
                                                    .instructionAddress(instructionAddressBus0) //Goes to the I$
                                                    );
    programCounter #(32'h00000000) programCounter1( /*Inputs*/
                                                    .clk(clk), 
                                                    .enable(p1_enable),//Comes from the arbiter 
                                                    /*Outputs*/
                                                    .instructionAddress(instructionAddressBus1) //Goes to the I$
                                                    );
    
    instructionMemory #(12'h500) instructionCache0( /*Inputs*/
                                                    .pc(instructionAddressBus0), 
                                                    /*Output*/
                                                    .instruction(ibus0) 
                                                    );
                                                
    instructionMemory #(12'h580) instructionCache1( /*Inputs*/
                                                    .pc(instructionAddressBus1), 
                                                    /*Output*/
                                                    .instruction(ibus1) 
                                                    );
                    

    
    ARMS2 processor0(   /*Inputs*/
                        .clk(clk), 
                        .ibus(ibus0), 
                        .enable(p0_enable), 
                        .reset(reset), 
                        .dataFromMuxAfterCache(dataFromCacheToProcessor0), 
                        
                        /*Outputs*/
                        .iaddrbus(instructionAddress),/*NOT USED, IF IT AIN"T BROKE THEN DON'T FIX IT*/ 
                        //.addressFromProcessorToArbiter(addressFromProcessorToArbiter0),
                        .daddrbus(addressFromProcessorToArbiter0),
                        .dataFromProcessorToArbiter(dataFromProcessorToArbiter0),
                        .opcode3(p0_opcode3)
                        );
                        
    ARMS2 processor1(   /*Inputs*/
                        .clk(clk), 
                        .ibus(ibus1), 
                        .enable(p1_enable), 
                        .reset(reset), 
                        .dataFromMuxAfterCache(dataFromCacheToProcessor1), 
                         
                        /*Outputs*/
                        .iaddrbus(instructionAddress),/*NOT USED, IF IT AIN"T BROKE THEN DON'T FIX IT*/ 
                        //.addressFromProcessorToArbiter(addressFromProcessorToArbiter0),
                        .daddrbus(addressFromProcessorToArbiter1),
                        .dataFromProcessorToArbiter(dataFromProcessorToArbiter1),
                        .opcode3(p1_opcode3)
                        );
                        
    arbiter ArbiterNumeroUno(   /*Input*/
                                .p0_opcode3(p0_opcode3), 
                                .p1_opcode3(p1_opcode3), 
                                .p0_address(addressFromProcessorToArbiter0), 
                                .p1_address(addressFromProcessorToArbiter1), 
                                .p0_data(dataFromProcessorToArbiter0), 
                                .p1_data(dataFromProcessorToArbiter1), 
                                /*Outputs*/
                                .address(addressToCache),   //to shared cache
                                .data(dataToCache),         //to shared cache
                                .opcode3(arbiterOpcode3),   //to shared cache
                                .p0_enable(p0_enable),      //to processor0
                                .p1_enable(p1_enable),      //to processor1
                                .allowedAccess(allowedAccess)//to inverse mux after cache
                                );                        
                                                
    sharedCache SharedDataCache(/*Inputs*/ 
                                .dataAddressBus(addressToCache), 
                                .dataIn(dataToCache),
                                .opcode3(arbiterOpcode3),
                                /*Outputs*/
                                .dataOut(dataFromCacheToMux), //Goes to the inverseMux
                                .storeCheck(),//NOT USED, Probe 
                                .miss()//NOT USED, Probe
                                );
                                
    arbiterMux inverseMux(  /*Inputs*/
                            .allowedAccess(allowedAccess), 
                            .data(dataFromCacheToMux), 
                            /*Outputs*/
                            .p0_dataFromCacheToProcessor(dataFromCacheToProcessor0), 
                            .p1_dataFromCacheToProcessor(dataFromCacheToProcessor1)
                            );
    
    initial begin
        clk = 0;
        
        repeat(200) begin 
            #1 clk = ~clk;
        end//end of repear
    end//end of initial begin
       
        
        
        
endmodule









       
    
    
    
    
//        superFlag = 0;
//        reset = 0;
//        //#2
//        //reset = 0;
//        #2 
//        counter = counter + 1;
//        instruction = 32'h00000000;
        
//        #2
//                     //opcode  Imm	   Source	 Destination
//        instruction = {ADDI, 12'h500, 5'b11111, 5'b00001};
        
//        #2
//        instruction = 32'h00000000;//Needed because timing diagram
//        #2
//        instruction = 32'h00000000;//The ADDI does not write back in time 
//        #2
        
//        //FIRST BATCH OF LOADS
//        //             opcode DT_address      op2    rn	     Destination
//        instruction = {LDUR,  9'h000,   2'b00, 5'b00001, 5'b00010};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn	     Destination
//        instruction = {LDUR,  9'h010,   2'b00, 5'b00001, 5'b00011};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn	     Destination
//        instruction = {LDUR,  9'h020,   2'b00, 5'b00001, 5'b00100};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn	     Destination
//        instruction = {LDUR,  9'h030,   2'b00, 5'b00001, 5'b00101};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h040,   2'b00, 5'b00001, 5'b00110};//You need all 32 bits here     
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h050,   2'b00, 5'b00001, 5'b00111};//You need all 32 bits here 
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h060,   2'b00, 5'b00001, 5'b01000};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h070,   2'b00, 5'b00001, 5'b01001};//You need all 32 bits here
//        //counted12 #2
        
//        //SECOND BATCH OF LOADS
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h008,   2'b00, 5'b00001, 5'b01010};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h018,   2'b00, 5'b00001, 5'b01011};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h028,   2'b00, 5'b00001, 5'b01100};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h038,   2'b00, 5'b00001, 5'b01101};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h048,   2'b00, 5'b00001, 5'b01110};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h058,   2'b00, 5'b00001, 5'b01111};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h068,   2'b00, 5'b00001, 5'b10000};//You need all 32 bits here
//        #2
//        //             opcode DT_address      op2    rn         Destination
//        instruction = {LDUR,  9'h078,   2'b00, 5'b00001, 5'b10001};//You need all 32 bits here



//        //ADD
//        #2
//        //            opcode     bbus	   000000    abus 	  Destination
//        instruction = {ADD, 	 5'd10,    shamt ,   5'd2,    5'd2};
//        #2
//        //            opcode     bbus       000000    abus       Destination
//        instruction = {ADD,      5'd11,    shamt ,   5'd3,    5'd3};
//        #2
//        //            opcode     bbus       000000    abus       Destination
//        instruction = {ADD,      5'd12,    shamt ,   5'd4,    5'd4};
//        #2
//        //            opcode     bbus       000000    abus       Destination
//        instruction = {ADD,      5'd13,    shamt ,   5'd5,    5'd5};
//        #2
//        //            opcode     bbus       000000    abus       Destination
//        instruction = {ADD,      5'd14,    shamt ,   5'd6,    5'd6};
//        #2
//        //            opcode     bbus       000000    abus       Destination
//        instruction = {ADD,      5'd15,    shamt ,   5'd7,    5'd7};
//        #2
//        //            opcode     bbus       000000    abus       Destination
//        instruction = {ADD,      5'd16,    shamt ,   5'd8,    5'd8};
//        #2
//        //            opcode     bbus       000000    abus       Destination
//        instruction = {ADD,      5'd17,    shamt ,   5'd9,    5'd9};


//        //STUR
//        #2
//        superFlag = 1;
//        //             opcode   DT_address      op2      Destination 	  Source
//        instruction = {STUR,    9'h008,         2'b00,   5'd1,            5'd2};
//        #2
//        //             opcode   DT_address      op2      Destination      Source
//        instruction = {STUR,    9'h018,         2'b00,   5'd1,            5'd3};
//        #2
//        //             opcode   DT_address      op2      Destination       Source
//        instruction = {STUR,    9'h028,         2'b00,   5'd1,            5'd4};
//        #2
//        //             opcode   DT_address      op2      Destination       Source
//        instruction = {STUR,    9'h038,         2'b00,   5'd1,            5'd5};
//        #2
//        //             opcode   DT_address      op2      Destination       Source
//        instruction = {STUR,    9'h048,         2'b00,   5'd1,            5'd6};
//        #2
//        //             opcode   DT_address      op2      Destination       Source
//        instruction = {STUR,    9'h058,         2'b00,   5'd1,            5'd7};
//        #2
//        //             opcode   DT_address      op2      Destination       Source
//        instruction = {STUR,    9'h068,         2'b00,   5'd1,            5'd8};
//        #2
//        //             opcode   DT_address      op2      Destination       Source
//        instruction = {STUR,    9'h078,         2'b00,   5'd1,            5'd9};

//        #2
//        instruction = 32'h00000000;//Needed because timing diagram
//        #2
//        instruction = 32'h00000000;
//        #2
//        instruction = 32'h00000000;//Needed because timing diagram
//        #2
//        instruction = 32'h00000000;
//        #2
//        instruction = 32'h00000000;//Needed because timing diagram
//        #2
//        instruction = 32'h00000000;
//        #2
//        instruction = 32'h00000000;//Needed because timing diagram
//        #2
//        instruction = 32'h00000000;




