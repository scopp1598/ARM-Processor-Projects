//Modeled after a testbench by Dr. Marpaung; by Michael Hickey
//LEGv8 instructions as found from the LEGv8 Green Sheet.
//Quick 12-Bit 2's Complement http://www.exploringbinary.com/twos-complement-converter/
`timescale 1ns/10ps
module ARMStb();
    //Parameter tests: the number of tests to run.
    parameter tests = 160;//The highest index of iname you have goes here. aka highest index + 4; because of the NOPS
    parameter hiNn  = tests - 4;//this is the 'H'ighest 'I'ndex that is 'N'ot a 'N'OP instruction
    
    reg  [31:0] instrbus;
    reg  [31:0] instrbusin[0:tests];//the instruction I am sending into my CPU.
    
    wire [63:0] iaddrbus;//wire output from the CPU, this is my vlaue of my instruciton address bus
    reg  [63:0] iaddrbusout[0:tests]; //This is what the PC counter should be
    
    wire [63:0] daddrbus;//These are wire outputs from the CPU
    reg  [63:0] daddrbusout[0:tests];
    
    wire [63:0] databus;//a wire output from the CPU
    reg  [63:0] databusk;//we can send information into the CPU via databus, by assigning databus = databusk
    reg  [63:0] databusin[0:tests];//This is what we are sending in.
    reg  [63:0] databusout[0:tests];//This is what we should get as an output from the CPU
    
    wire [10:0] gen_opcode;//wire output from the CPU, my value
    reg  [10:0] gen_opcodeOut[0:tests];//This is what the gen_opcode should be.
    
    wire [63:0] registerVal;//wire output from the CPU. These are the values stored at the register.
    reg  [63:0] registerValOut[0:tests];//This is what the value should be at that time.
    
    reg  clk, reset;
    reg  clkd;//crtical to cycling through the test bench
    
    reg [63:0] dontcare;
    reg [24*8:1] iname[0:tests];//iname is a string used to display the instruction as assembly code, in the console.
    
    integer error;//the number or errors.
    integer k;//used to cycle through the tests. The inxes of the instruction. 
    integer ntests;//the number of tests, you can have. Calculated by  (no. instructions) + (no. loads) + 2*(no. stores) = 1 + 0 + 2*0 = 1
    
    parameter shamt = 6'b000000;//used in R type instructions.
    
    //==== R Types ====\\
    parameter ADD	= 11'b10001011000;//458
    parameter ADDS  = 11'b10101011000;//558
    parameter AND	= 11'b10001010000;//450
    parameter ORR	= 11'b10101010000;//550
    parameter ANDS  = 11'b11101010000;//750
    parameter EOR	= 11'b11001010000;//650
    parameter SUBS  = 11'b11101011000;//758
    parameter SUB	= 11'b11001011000;//658
    
    parameter LSL	= 11'b11010011011;//69B
    parameter LSR	= 11'b11010011010;//69A
    
    //==== I Types ====\\
    parameter EORI	= 10'b1101001000;//690
    parameter ANDI	= 10'b1001001000;//490
    parameter ANDIS	= 10'b1111001000;//790
    parameter ADDI	= 10'b1001000100;//488
    parameter ADDIS	= 10'b1011000100;//588
    parameter SUBI	= 10'b1101000100;//688
    parameter SUBIS	= 10'b1111000100;//788
    parameter ORRI	= 10'b1011001000;//590

	//==== B Types ====\\
	parameter B		= 6'b000101;	//0A0
	parameter BEQ	= 8'b01010101;	//2A8
	parameter BNE	= 8'b01010110;	//2B0
	parameter BLT	= 8'b01010111;	//2B8
	parameter BGE	= 8'b01011000;	//2C0
	
	//==== D Types ====\\
	parameter LDUR	= 11'b11111000010;//7C2
	parameter STUR 	= 11'b11111000000;//7C0

	//==== CB Type ====\\
	parameter CBNZ	= 8'b10110101;//5A8
	parameter CBZ	= 8'b10110100;//5A0
	
	//==== IW Type ====\\
	parameter MOVZ	= 9'b110100101;//691
	parameter quad0	= 2'b00;
	parameter quad1	= 2'b01;
	parameter quad2	= 2'b10;
	parameter quad3 = 2'b11;
	//=================\\


    //ARMS dut(.reset(reset),.clk(clk),.iaddrbus(iaddrbus),.ibus(instrbus),.daddrbus(daddrbus),.databus(databus) );
    
    initial begin
    //CTRL+SHIFT+U capitalize letters in selection.
        //==== Instruction List ====\\
                                            //      Time Writen     Time when Instr       
                                            //     	to Register     was first CLKed
        iname[0] = "ADDI  X0, X31, #4095";  //     	65ns            30ns            
        iname[1] = "ORRI  X1, X31, #512";	//		75ns			40ns
        iname[2] = "EORI  X2, X31, #1911";	//		85ns			50ns
        iname[3] = "ADDI  X3, X31, #3549";	//		95ns			60ns
		iname[4] = "ADDI  X4, X31, #69";	//		105ns			70ns
        iname[5] = "ADD   X5, X31, X0";		//		115ns			80ns
        iname[6] = "LDUR  X7, [X3, #0]";	//		125ns			90ns
        iname[7] = "STUR  X2, [X1, #0]";  	//		135ns			100ns/NA
        iname[8] = "LSL   X8, X2, #20";		//		145ns			110ns
        iname[9] = "LSR	  X9, X3, #4";		//		155ns			120ns
        iname[10] = "ADDIS X9, X10, #4094";	//		165ns			130ns
        iname[11] = "SUBIS  X9, X10, #0";	//		175ns			140ns
        iname[12] = "ANDIS  X9, X9, #4095";	//		185ns			150ns
        iname[13] = "ADDS  X10, X9, X8";	//		195ns			160ns
        iname[14] = "ANDS  X10, X9, X8";	//		205ns			170ns
        iname[15] = "SUBS  X11, X31, X5";	//		215ns			180ns
        iname[16] ="MOVZ X12, #2AAA, LSL 16";//		225ns			190ns
        iname[17] ="MOVZ X13, #2AAA, LSL 32";//		235ns			200ns
        iname[18] ="MOVZ X14, #2AAA, LSL 48";//		245ns			210ns
        									//branching to 78
        iname[19] = "CBNZ  X0, #10";	    //		255ns			220ns/NA
        iname[20] = "EOR  X15, X31, X0";	//		265ns			230ns
        iname[21] = "MOVZ X14, #2AAA, LSL 0";//		275ns			240ns
        iname[22] = "SUBIS  X16, X3, #3549";//		285ns			250ns
        									//Branching to C4
        iname[23] = "B  #16";				//		295ns			260ns
        iname[24] = "LSL  X17, X8, #40";	//		305ns			270ns
        iname[25] = "LSR  X18, X3, #52";	//		315ns			280ns
        iname[26] = "LDUR  X19, [X8, #0]";	//		325ns			290ns
        iname[27] = "ANDS  X20, X14, X13";	//		335ns			300ns
        									//Branching to 138
        iname[28] = "BEQ #25";				//		345ns			310ns/NA
        iname[29] = "ADDS X21, X14, X5";	//		355ns			320ns
        iname[30] = "SUBIS X22, X13, #2045";//		345ns			330ns
        									//Branching to 2D0
        iname[31] = "BNE #100";				//		355ns			340ns/NA
        iname[32] = "SUB  X23, X14, X18";	//		365ns			350ns
        									//Branching to 20C
        iname[33] = "BGE #-50";				//		375ns			360ns/NA
        iname[34] = "ADD  X24, X19, X22";	//		385ns			370ns
        									//Not Branching
        iname[35] = "BEQ #150";				//		395ns			380ns/NA
        iname[36] = "ADD X25, X22, X15";	//		405ns			390ns
        iname[37] = "ADDI X26, X22, #2048";//		415ns			400ns
        iname[38] = "ADDIS X27, X24, #3864";//		425ns			410ns
        iname[39] = "ADDS X28, X22, X25";	//		435ns			420ns
        iname[40] = "AND X29, X26, X25";	//		445ns			430ns
        iname[41] = "ANDI X30, X5, #2047";	//		455ns			440ns
        iname[42] = "ANDIS X1, X1, #0";		//		465ns			450ns
        iname[43] = "ANDS X2, X23, X26";	//		475ns			460ns
        									//Not Branching
        iname[44] = "CBNZ X31, #300";		//		485ns			470ns
        									//Branching to ffffffffffffffe0
        iname[45] = "CBZ X31, #-150";		//		495ns			480ns
        iname[46] = "EOR X3, X29, X22";		//		505ns			490ns
        iname[47] = "EORI X4, X23, 1995";	//		515ns			500ns
        iname[48] = "LDUR X5, [X12, #0]";	//		525ns			510ns
        iname[49] = "LSL X5, X29, #11";		//		535ns			520ns
        iname[50] = "LSR X6, X23, #63";		//		545ns			530ns
        iname[51] ="MOVZ X7, #5A5A, LSL 16";//		555ns			540ns
        iname[52] = "ORR X8, X3, X4";		//		565ns			550
        iname[53] = "ORRI X9, X6, #1010";	//		575ns			560
        iname[54] = "STUR X25, [X22, #0]";	//		585ns			570
        iname[55] = "SUB X10, X23, X22";	//		595ns			580
        iname[56] = "SUBI X11, X30, #444";	//		605ns			590
        iname[57] = "SUBIS X12, X4, #545";	//		615ns			600
        iname[58] = "SUBS X13, X15, X16";	//		625ns			610
        iname[59] = "EOR X14, X5, X16";		//		635ns			620
        iname[60] = "EOR X15, X6, X24";		//		645ns			630
        iname[61] = "EORI X16, X22, #3086"; //		655ns			640
        iname[62] = "EORI X17, X12, #1111";	//		665ns			650
        iname[63] = "ADD X18, X31, X22";	//		675ns			660
        iname[64] = "ADD X19, X22, X22";	//		685ns			670
        iname[65] = "ADDI X20 X23, #16";	//		695ns			680
        iname[66] = "AND X21, X12, X28";	//		705ns			690
        iname[67] = "ANDI X22, X28, #2047";	//		715ns			700
        iname[68] = "ANDIS X23, X29, #2047";//		725ns			710
        									//Branching to 1F7C                  
        iname[69] = "B #2000";				//		735ns			720   
        iname[70] = "ORRI X24, X2, #2047";	//		745ns			730      
        iname[71] = "ORR X25, X3, X4";		//		755ns			740
        iname[72] = "ORR X26, X31, X31";	//		765ns			750  
        iname[73] = "SUB X27, X2, X19";		//		775ns			760 
        iname[74] = "SUBI X28, X3, #1995";	//		785ns			770 
        iname[75] = "SUBIS X29, X4, #1234";	//		795ns 			780
        iname[76] = "SUBS X30, X5, X19";	//		805ns 			790
        iname[77] = "ADD X1, X13, X23";		//		815ns 			800
        iname[78] = "ADDI X2, X23, #1234";	//		825ns 			810
        iname[79] = "ADDIS X3, X24, #999";	//		835ns 			820
        iname[80] = "ADDS X4, X25, X23";	//		845ns 			830
        iname[81] = "AND X5, X30, X12";		//		855ns 			840
        iname[82] = "ANDI X6, X21, #343";	//		865ns 			850
        iname[83] = "ANDIS X7, X22, #500";	//		875ns 			860
        iname[84] = "ANDS X8, X23, X30";	//		885ns 			870
        iname[85] = "ANDIS X9, X22, #909";	//		895ns 			880
        iname[86] = "EOR X10, X12, X14";	//		905ns 			890
        iname[87] = "EORI X11, X22, #117";	//		915ns 			900
        iname[88] = "ORR X12, X12, X12";	//		925ns 			910
        iname[89] = "ORRI X13, X21, #345";	//		935ns 			920
        iname[90] = "SUB X14, X23, X21";	//		945ns 			930
        iname[91] = "SUBI X15, X2, X1";		//		955ns  			940
        iname[92] = "SUBIS X16, X31, #787";	//		965ns  			950
        iname[93] = "SUBS X17, X18, X15";	//		975ns  			960
        iname[94] = "ADD X18, X9, X4";		//		985ns  			970
        iname[95] = "ADDI X19, X12, 666";	//		995ns  			980
        iname[96] = "ADDIS X20, X12, #1029";//		1005ns 			990
        iname[97] = "ADDS X21, X17, X1";	//		1015ns 			1000
        iname[98] = "AND X22, X21, X2";		//		1025ns 			1010
        iname[99] = "ANDI X23, X15, #2000";	//		1035ns 			1020
        iname[100] = "ANDIS X24, X11, #1111";//		1045ns			1030
        iname[101] = "LDUR X25, [X12, #0]";	//		1055ns 			1040
        iname[102] = "LSL X26, X22, #32";	//		1065ns 			1050
        iname[103] = "LSR X27, X21, #12";	//		1075ns 			1060
        iname[104] = "MOVZ X28, #32767, LSL 0";//	1085ns 			1070
        iname[105] = "ORR X29, X26, X11";	//		1095ns 			1080
        iname[106] = "ORRI X30, X21, #0xAAA";//NEG	1105ns 			1090
        iname[107] = "STUR X1, [X12, #0]";	//		1115ns 			1100
        iname[108] = "SUB X2, X22, X3";		//		1125ns 			1110
        iname[109] = "SUBI X3, X12, #0xFAD";//NEG	1135ns 			1120
        iname[110] = "SUBIS X4, X12, #456";	//		1145ns 			1130
        iname[111] = "SUBS X5, X12, X12";	//		1155ns 			1140
        									//Branching to 0000000000001854		
        iname[112] = "B #-500";				//		1165ns  		1150
        iname[113] = "ADD X5, X19, X20";	//		1175ns  		1160
        iname[114] = "ADDI X6, X22, #0xDAB";//NEG	1185ns  		1170
        iname[115] = "ADDIS X7, X3, #0xBAD";//NEG	1195ns  		1180
        iname[116] = "ADDS X8, X4, X8";		//		1205ns  		1190
        iname[117] = "AND X9, X3, X2";		//		1215ns  		1200
        iname[118] = "ANDI X10, X20, #0xCAF";//NEG	1225ns  		1210
        iname[119] = "ANDIS X11, X23, #0x6B2";//	1235ns  		1220
        iname[120] = "ANDS X12, X12, X23";	//		1245ns  		1230
        									//Branching to 0000000000041880
        iname[121] = "CBNZ, X10, #65535";	//		1255ns  		1240
        iname[122] = "EOR, X13, X11, X23";	//		1265ns  		1250
        iname[123] = "EORI X14, X22, #456";	//		1275ns  		1260
        iname[124] = "LDUR X15, [X15, #0]";	//		1285ns  		1270
        iname[125] = "LSL X16, X21, #22";	//		1295ns  		1280
        iname[126] = "LSR X17, X22, #45";	//		1305ns  		1290
        iname[127] = "MOVZ X18, #22222, LSL 16";//	1315ns  		1300
        iname[128] = "ORR X19, X2, X1";		//		1325ns  		1310
        iname[129] = "ORRI X20, X12, #4086";//NEG	1335ns  		1320
        iname[130] = "STUR X4, [X22, #0]";	//		1345ns  		1330
        iname[131] = "SUB X5, X21, X2";		//		1355ns  		1340
        iname[132] = "SUBI X6, X2, #888";	//		1365ns  		1350
        iname[133] = "SUBIS X7, X21, #343";	//		1375ns  		1360
        iname[134] = "SUBS X8, X18, X29";	//		1385ns  		1370
        									//Branching to 000000000004196c	
        iname[135] = "BNE #50";				//		1395ns    		1380
        iname[136] = "ADD X9, X3, X29";		//		1405ns     		1390
        iname[137] = "ADDI X10, X2, #1";	//		1415ns     		1400
        iname[138] = "ADDIS X11, X4, #4095";//		1425ns     		1410
        iname[139] = "ADDS X12, X5, X2";	//		1435ns     		1420
        iname[140] = "AND X13, X3, X5";		//		1445ns     		1430
        iname[141] = "ANDI X14, X2, #0xA6A";//NEG	1455ns     		1440
        iname[142] = "ANDIS X15, X2, #543";	//		1465ns     		1450
        iname[143] = "ANDS X16, X2, X7";	//		1475ns     		1460
        									//Not Branching		                   
        iname[144] = "CBZ X12, #4444";		//		1485ns			1480
        iname[145] = "EOR X13, X22, X9";	//		1495ns			1490
        iname[146] = "EORI X14, X23, #0xA6A";//NEG	1505ns			1500
        iname[147] = "LDUR X15, [X23, #0]";	//		1515ns			1510
        iname[148] = "LSL X16, X12, #19";	//		1525ns			1520
        									//
        iname[149] = "BEQ #2000";			//		1535ns			1530
        iname[150] = "LSR X17, X22, #16";	//		1545ns			1540
        iname[151] ="SUBIS X22, X13, #2045";//		1555ns			1550
        iname[152] = "BGE #10 decimal";		//		1565ns			1560
        iname[153] = "ADDI X18, X12, #1";   //		1575ns			1570
        iname[154] = "ADDI X19, X12, #2";	//		1585ns			1580
        iname[155] = "ADDI X20, X12, #3";	//		1595ns			1590
        iname[156] = "BLT #10 decimal";     //		1605ns			1600             
		iname[157] = "NOP";
		iname[158] = "NOP";
		iname[159] = "NOP";
		iname[160] = "NOP";
		iname[161] = "NOP";

        
        //==== End of Instruction List ====\\
        
        dontcare = 64'hx;
        
        //==== Initializing the Instruction List ====\\
        //* ADDI  X20, X31, #-1		FFF = 000 + FFF		65ns
        iaddrbusout		[0] = 64'h0000000000000000;
        //            		opcode  Imm	   Source	 Destination
        instrbusin 		[0]={ADDI, 12'hFFF, 5'b11111, 5'b00000};
        daddrbusout		[0] = 64'h0000000000000fff;
        databusin  		[0] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[0] = dontcare;
        gen_opcodeOut	[0] = ADDI << 1;
		registerValOut	[0] = 64'h0000000000000000;
        
        //* ORRI  X1, X0, #512			200 = 000 | 200		75ns
        iaddrbusout[1] = 64'h0000000000000004;
        //                     opcode     Imm	   abus	     Destination
        instrbusin 		[1] ={ORRI, 	 12'h200, 5'b00001, 5'b00001};
        daddrbusout		[1] = 64'h0000000000000200;
        databusin  		[1] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[1] = dontcare;
        gen_opcodeOut	[1] = ORRI << 1;
		registerValOut	[1] = 64'h0000000000000000;
        
        //* EORI  X2, X31, # 1911		777 = 000 ^ 777		85ns
        iaddrbusout		[2] = 64'h0000000000000008;
        //               		opcode    Imm	  Source    Destination
        instrbusin 		[2] ={EORI, 	 12'h777, 5'b11111, 5'b00010};
        daddrbusout		[2] = 64'h0000000000000777;
        databusin  		[2] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[2] = dontcare;
        gen_opcodeOut	[2] = EORI << 1;
		registerValOut	[2] = 64'h0000000000000000;
        
        //* ADDI  X3, X31, #-547		DDD = 000 + DDD		95ns
        iaddrbusout		[3] = 64'h000000000000000C;
        //                     opcode    Imm	  Source    Destination
        instrbusin 		[3] ={ADDI, 	 12'hDDD, 5'b11111, 5'b00011};
        daddrbusout		[3] = 64'h0000000000000ddd;
        databusin  		[3] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[3] = dontcare;
		gen_opcodeOut	[3] = ADDI << 1;
		registerValOut	[3] = 64'h0000000000000000;

        //* ADDI  X4, X31, #69			045 = 000 + 045		105ns
        iaddrbusout		[4] = 64'h0000000000000010;
        //               4    opcode  Imm	  Source    Destination
        instrbusin 		[4] ={ADDI, 	 12'h045, 5'b11111, 5'b00100};
        daddrbusout		[4] = 64'h0000000000000045;
        databusin  		[4] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[4] = dontcare;
		gen_opcodeOut	[4] = ADDI << 1;
		registerValOut	[4] = 64'h0000000000000000;

		//* ADD  X5, X31, X0			FFFF FFFF = 0000 0000 + FFFF FFFF		115ns
        iaddrbusout		[5] = 64'h0000000000000014;
        //               5    opcode  bbus	  000000    abus	     Destination
        instrbusin 		[5] ={ADD, 	 5'b00000, shamt ,5'b11111, 5'b00101};//You need all 32 bits here.
        daddrbusout		[5] = 64'h0000000000000fff;
        databusin  		[5] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[5] = dontcare;
		gen_opcodeOut	[5] = ADD;
		registerValOut	[5] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* LDUR  X7, [X3, #0]					125ns
        iaddrbusout		[6] = 64'h0000000000000018;
        //               6    opcode DT_address      op2    rn	     Destination
        instrbusin 		[6] ={LDUR,  9'b000000000,   2'b00, 5'b00011, 5'b00111};//You need all 32 bits here.
        daddrbusout		[6] = 64'h0000000000001ddc;
        databusin  		[6] = 64'hBBBBAAAABBBBEEEE;
        databusout 		[6] = dontcare;
		gen_opcodeOut	[6] = LDUR;
		registerValOut	[6] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* STUR  X7, [X1, #0]					135ns
        iaddrbusout		[7] = 64'h000000000000001C;
        //               6    opcode DT_address      op2    M[Rn] 	  myRegister
        instrbusin 		[7] ={STUR,  9'b000000000,   2'b00, 5'b00001, 5'b00010};//You need all 32 bits here.
        daddrbusout		[7] = 64'h00000000000011ff;
        databusin  		[7] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[7] = 64'h0000000000000777;
		gen_opcodeOut	[7] = STUR;
		registerValOut	[7] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* LSL  X8, X2, #20			7770 0000 = 0000 0777 << 20		145ns
        iaddrbusout		[8] = 64'h0000000000000020;
        //               5    opcode  bbus	    shamt    abus	     Destination
        instrbusin 		[8] ={LSL, 	 5'b00000, 6'b010100 ,5'b00010, 5'b01000};//You need all 32 bits here.
        daddrbusout		[8] = 64'h0000000077700000;
        databusin  		[8] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[8] = dontcare;
		gen_opcodeOut	[8] = LSL;
		registerValOut	[8] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* LSR  X9, X3, #4			0FFF FFDD = FFFF FDDD >> 4		155ns
        iaddrbusout		[9] = 64'h0000000000000024;
        //               5    opcode  bbus	    shamt    abus	     Destination
        instrbusin 		[9] ={LSR, 	 5'b00000, 6'b000100 ,5'b00011, 5'b01001};//You need all 32 bits here.
        daddrbusout		[9] = 64'h00000000000000dd;
        databusin  		[9] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[9] = dontcare;
		gen_opcodeOut	[9] = LSR;
		registerValOut	[9] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* ADDIS  X9, X10, #-2				165ns
        iaddrbusout		[10] = 64'h0000000000000028;
        //               5     opcode  Imm		Source	  Dest.
        instrbusin 		[10] ={ADDIS,  12'hFFE, 5'b01010, 5'b01001};//You need all 32 bits here. like always...
        daddrbusout		[10] = 64'h0000000000000ffe;
        databusin  		[10] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[10] = dontcare;
		gen_opcodeOut	[10] = ADDIS;
		registerValOut	[10] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* SUBIS  X9, X10, #0				175ns
        iaddrbusout		[11] = 64'h000000000000002C;
        //               5     opcode  Imm		Source	  Dest.
        instrbusin 		[11] ={SUBIS,  12'h000, 5'b01010, 5'b01001};//You need all 32 bits here. like always...
        daddrbusout		[11] = 64'h0000000000000000;
        databusin  		[11] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[11] = dontcare;
		gen_opcodeOut	[11] = SUBIS;
		registerValOut	[11] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* ANDIS  X9, X9, #-1				185ns
        iaddrbusout		[12] = 64'h0000000000000030;
        //               5     opcode  Imm		Source	  Dest.
        instrbusin 		[12] ={ANDIS,  12'hFFF, 5'b01001, 5'b01001};//You need all 32 bits here. like always...
        daddrbusout		[12] = 64'h00000000000000dd;
        databusin  		[12] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[12] = dontcare;
		gen_opcodeOut	[12] = ANDIS;
		registerValOut	[12] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* ADDS  X10, X9, X8				195ns
        iaddrbusout		[13] = 64'h0000000000000034;
        //               5     opcode  bbus		000000  abus      dest
        instrbusin 		[13] ={ADDS,   5'b01001, shamt, 5'b01000, 5'b01010};//You need all 32 bits here. like always...
        daddrbusout		[13] = 64'h0000000077700ffe;
        databusin  		[13] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[13] = dontcare;
		gen_opcodeOut	[13] = ADDS;
		registerValOut	[13] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* ANDS  X10, X9, X8				205ns
        iaddrbusout		[14] = 64'h0000000000000038;
        //               5     opcode  bbus		000000  abus      dest
        instrbusin 		[14] ={ANDS,   5'b01001, shamt, 5'b01000, 5'b01010};//You need all 32 bits here. like always...
        daddrbusout		[14] = 64'h0000000000000000;
        databusin  		[14] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[14] = dontcare;
		gen_opcodeOut	[14] = ANDS;
		registerValOut	[14] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* SUBS  X11, X31, X5				215ns
        iaddrbusout		[15] = 64'h000000000000003C;
        //               5     opcode  bbus		000000  abus      dest
        instrbusin 		[15] ={SUBS,   5'b00101, shamt, 5'b11111, 5'b01011};//You need all 32 bits here. like always...
        daddrbusout		[15] = 64'hfffffffffffff001;
        databusin  		[15] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[15] = dontcare;
		gen_opcodeOut	[15] = SUBS;
		registerValOut	[15] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* MOVZ  X12, 2AAA, LSL 16				225ns
        iaddrbusout		[16] = 64'h0000000000000040;
        //               5     opcode  op2		16'bit Imm      dest
        instrbusin 		[16] ={MOVZ,   quad1,   16'h2AAA,     5'b01100};//You need all 32 bits here. like always...
        daddrbusout		[16] = 64'h000000002AAA0000;
        databusin  		[16] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[16] = dontcare;
		gen_opcodeOut	[16] = MOVZ;
		registerValOut	[16] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* MOVZ  X13, 2AAA, LSL 32				235ns
        iaddrbusout		[17] = 64'h0000000000000044;
        //               5     opcode  op2		16'bit Imm      dest
        instrbusin 		[17] ={MOVZ,   quad2,   16'h2AAA,     5'b01101};//You need all 32 bits here. like always...
        daddrbusout		[17] = 64'h00002AAA00000000;
        databusin  		[17] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[17] = dontcare;
		gen_opcodeOut	[17] = MOVZ;
		registerValOut	[17] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* MOVZ  X14, 2AAA, LSL 48				245ns
        iaddrbusout		[18] = 64'h0000000000000048;
        //               5     opcode  op2		16'bit Imm      dest
        instrbusin 		[18] ={MOVZ,   quad3,   16'h2AAA,     5'b01110};//You need all 32 bits here. like always...
        daddrbusout		[18] = 64'h2AAA000000000000;
        databusin  		[18] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[18] = dontcare;
		gen_opcodeOut	[18] = MOVZ;
		registerValOut	[18] = 64'h0000000000000000;//The value that is overwritten with a new value.

		// CBNZ  X0, #10					255ns
        iaddrbusout		[19] = 64'h00000000000004C;
        //               5     opcode  conditional branch address	register to check
        instrbusin 		[19] ={CBNZ,   19'h0000A, 					5'b00000};//You need all 32 bits here.
        daddrbusout		[19] = 64'h0000000000000fff;
        databusin  		[19] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[19] = dontcare;
		gen_opcodeOut	[19] = CBNZ;
		registerValOut	[19] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* EOR  X15, X31, X0			FFFF FFFF = 0000 0000 + FFFF FFFF		265ns
        iaddrbusout		[20] = 64'h0000000000000050;
        //               5    opcode      bbus	  000000    abus	     Destination
        instrbusin 		[20] ={EOR, 	 5'b00000, shamt ,5'b11111, 5'b01111};//You need all 32 bits here.
        daddrbusout		[20] = 64'h0000000000000fff;
        databusin  		[20] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[20] = dontcare;
		gen_opcodeOut	[20] = EOR;
		registerValOut	[20] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* MOVZ  X14, X3, LSL 0				275ns
        iaddrbusout		[21] = 64'h0000000000000078;
        //               5     opcode  op2		16'bit Imm      dest
        instrbusin 		[21] ={MOVZ,   quad0,   16'h2AAA,     5'b01110};//You need all 32 bits here. like always...
        daddrbusout		[21] = 64'h0000000000002AAA;
        databusin  		[21] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[21] = dontcare;
		gen_opcodeOut	[21] = MOVZ;
		registerValOut	[21] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* SUBIS  X16, X3, #-547    X3 == -547 therefore -547 - -547 = 0 285ns written to reg file
        iaddrbusout		[22] = 64'h000000000000007C;
		//               5     opcode  Imm		Source	  Dest.
		instrbusin 		[22] ={SUBIS,  12'hDDD, 5'b00011, 5'b10000};//You need all 32 bits here. like always...
		daddrbusout		[22] = 64'h0000000000000000;
		databusin  		[22] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[22] = dontcare;
		gen_opcodeOut	[22] = SUBIS;
		registerValOut	[22] = 64'h0000000000000000;//The value that is overwritten with a new value.

		// B  #16					285ns
        iaddrbusout		[23] = 64'h0000000000000080; 
        //               5     opcode  conditional branch address
        instrbusin 		[23] ={B, 26'h0000010};//You need all 32 bits here.
        daddrbusout		[23] = 64'h0000000000001ffe;
        databusin  		[23] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[23] = dontcare;
		gen_opcodeOut	[23] = B;
		registerValOut	[23] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* LSL  X17, X8, #40				295ns
        iaddrbusout		[24] = 64'h0000000000000084;//5C + 4 + 10*4 = 60+40 = A0
        //               5    opcode     bbus	    shamt    abus	     Destination
        instrbusin 		[24] ={LSL, 	 5'b00000, 6'b101000 ,5'b01000, 5'b10001};//You need all 32 bits here.
        daddrbusout		[24] = 64'h7000000000000000;
        databusin  		[24] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[24] = dontcare;
		gen_opcodeOut	[24] = LSL;
		registerValOut	[24] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//* LSR  X18, X3, #52				305ns when written to reg file.
        iaddrbusout		[25] = 64'h00000000000000C4;
        //               5    opcode      bbus	    shamt    abus	     Destination
        instrbusin 		[25] ={LSR, 	 5'b00000, 6'b110100 ,5'b00011, 5'b10010};//You need all 32 bits here.
        daddrbusout		[25] = 64'h0000000000000000;
        databusin  		[25] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[25] = dontcare;
		gen_opcodeOut	[25] = LSR;
		registerValOut	[25] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* LDUR  X19, [X8, #0]					315ns
        iaddrbusout		[26] = 64'h00000000000000C8;
        //               6    opcode  DT_address      op2    rn	     Destination
        instrbusin 		[26] ={LDUR,  9'b000000000,   2'b00, 5'b01000, 5'b10011};//You need all 32 bits here.
        daddrbusout		[26] = 64'h0000000077700fff;
        databusin  		[26] = 64'hABCDEFABCDEFABCD;
        databusout 		[26] = dontcare;
		gen_opcodeOut	[26] = LDUR;
		registerValOut	[26] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* ANDS  X20, X14, X13				205ns
        iaddrbusout		[27] = 64'h00000000000000CC;
        //               5     opcode  bbus		000000  abus      dest
        instrbusin 		[27] ={ANDS,   5'b01101, shamt, 5'b01110, 5'b10100};//You need all 32 bits here. like always...
        daddrbusout		[27] = 64'h0000000000000000;
        databusin  		[27] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[27] = dontcare;
		gen_opcodeOut	[27] = ANDS;
		registerValOut	[27] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		// BEQ #25					285ns
        iaddrbusout		[28] = 64'h00000000000000D0; 
        //               5     opcode  conditional branch address
        instrbusin 		[28] ={BEQ, 19'h00019, 5'b00000};//You need all 32 bits here.
        daddrbusout		[28] = 64'h0000000000000fff;
        databusin  		[28] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[28] = dontcare;
		gen_opcodeOut	[28] = BEQ;
		registerValOut	[28] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* ADDS  X21, X14, X5				195ns
        iaddrbusout		[29] = 64'h00000000000000D4;
        //               5     opcode  bbus		000000  abus      dest
        instrbusin 		[29] ={ADDS,   5'b00101, shamt, 5'b01110, 5'b10101};//You need all 32 bits here. like always...
        daddrbusout		[29] = 64'h0000000000003aa9;
        databusin  		[29] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[29] = dontcare;
		gen_opcodeOut	[29] = ADDS;
		registerValOut	[29] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		
		//* SUBIS  X22, X13, #2045				175ns
        iaddrbusout		[30] = 64'h0000000000000138;
        //               5     opcode  Imm		Source	  Dest.
        instrbusin 		[30] ={SUBIS,  12'h7FD, 5'b01101, 5'b10110};//You need all 32 bits here. like always...
        daddrbusout		[30] = 64'h00002AA9FFFFF803;
        databusin  		[30] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[30] = dontcare;
		gen_opcodeOut	[30] = SUBIS;
		registerValOut	[30] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		// BNE #100					285ns
        iaddrbusout		[31] = 64'h000000000000013C; 
        //               5     opcode  conditional branch address
        instrbusin 		[31] ={BNE, 19'h00064, 5'b00000};//You need all 32 bits here.
        daddrbusout		[31] = 64'h0000000000001044;
        databusin  		[31] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[31] = dontcare;
		gen_opcodeOut	[31] = BNE;
		registerValOut	[31] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* SUB  X23, X14, X18			
        iaddrbusout		[32] = 64'h0000000000000140;
        //               5    opcode  bbus	  000000    abus	     Destination
        instrbusin 		[32] ={SUB, 	 5'b10010, shamt ,5'b01110, 5'b10111};//You need all 32 bits here.
        daddrbusout		[32] = 64'h0000000000002aaa;
        databusin  		[32] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[32] = dontcare;
		gen_opcodeOut	[32] = SUB;
		registerValOut	[32] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		// BGE #-50					285ns
        iaddrbusout		[33] = 64'h00000000000002D0; 
        //               5     opcode  conditional branch address
        instrbusin 		[33] ={BGE, 19'h7FFCE, 5'b00000};//You need all 32 bits here.
        daddrbusout		[33] = 64'h0000000000002AAA;
        databusin  		[33] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[33] = dontcare;
		gen_opcodeOut	[33] = BGE;
		registerValOut	[33] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* ADD  X24, X19, X22				195ns
        iaddrbusout		[34] = 64'h00000000000002D4;
        //               5     opcode  bbus		000000  abus      dest
        instrbusin 		[34] ={ADD,   5'b10110, shamt, 5'b10011, 5'b11000};//You need all 32 bits here. like always...
        daddrbusout		[34] = 64'hABCE1A55CDEFA3D0;
        databusin  		[34] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[34] = dontcare;
		gen_opcodeOut	[34] = ADD;
		registerValOut	[34] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		// BEQ #150					285ns
        iaddrbusout		[35] = 64'h000000000000020C; 
        //               5     opcode  conditional branch address
        instrbusin 		[35] ={BEQ, 19'h00096, 5'b00000};//You need all 32 bits here.
        daddrbusout		[35] = 64'h00002aaa00000847;
        databusin  		[35] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[35] = dontcare;
		gen_opcodeOut	[35] = BEQ;
		registerValOut	[35] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ADD X25, X22, X15
        iaddrbusout		[36] = 64'h0000000000000210;
        //               5     opcode  bbus		000000  abus      dest
        instrbusin 		[36] ={ADD,   5'b01111, shamt, 5'b10110, 5'b11001};//You need all 32 bits here. like always...
        daddrbusout		[36] = 64'h00002aaa00000802;
        databusin  		[36] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[36] = dontcare;
		gen_opcodeOut	[36] = ADD;
		registerValOut	[36] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* ADDI X26, X22, #-2048				175ns
        iaddrbusout		[37] = 64'h0000000000000214;
        //               5     opcode  Imm		Source	  Dest.
        instrbusin 		[37] ={ADDI,  12'h800, 5'b10110, 5'b11010};//You need all 32 bits here. like always...
        daddrbusout		[37] = 64'h00002aaa00000003;
        databusin  		[37] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[37] = dontcare;
		gen_opcodeOut	[37] = ADDI;
		registerValOut	[37] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ADDIS X27, X24, #-232
		iaddrbusout		[38] = 64'h0000000000000218;
		//               5     opcode  Imm		Source	  Dest.
		instrbusin 		[38] ={ADDI,  12'hF18, 5'b11000, 5'b11011};//You need all 32 bits here. like always...
		daddrbusout		[38] = 64'habce1a55cdefb2e8;
		databusin  		[38] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[38] = dontcare;
		gen_opcodeOut	[38] = ADDI;
		registerValOut	[38] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ADDS X28, X22, X25
        iaddrbusout		[39] = 64'h000000000000021C;
		//               5     opcode  bbus		000000  abus      dest
		instrbusin 		[39] ={ADDS,   5'b11001, shamt, 5'b10110, 5'b11100};//You need all 32 bits here. like always...
		daddrbusout		[39] = 64'h0000555400000005;
		databusin  		[39] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[39] = dontcare;
		gen_opcodeOut	[39] = ADDS;
		registerValOut	[39] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//AND X29, X26, X25
		iaddrbusout		[40] = 64'h0000000000000220;
		//               5     opcode  bbus		000000  abus      dest
		instrbusin 		[40] ={AND,   5'b11001, shamt, 5'b11010, 5'b11101};//You need all 32 bits here. like always...
		daddrbusout		[40] = 64'h00002aaa00000002;
		databusin  		[40] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[40] = dontcare;
		gen_opcodeOut	[40] = AND;
		registerValOut	[40] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ANDI X30, X5, #2047
		iaddrbusout		[41] = 64'h0000000000000224;
		//               5     opcode  Imm		Source	  Dest.
		instrbusin 		[41] ={ANDI,  12'h7FF, 5'b00101, 5'b11110};//You need all 32 bits here. like always...
		daddrbusout		[41] = 64'h00000000000007FF;
		databusin  		[41] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[41] = dontcare;
		gen_opcodeOut	[41] = ANDI;
		registerValOut	[41] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ANDIS X1, X1, #0
		iaddrbusout		[42] = 64'h0000000000000228;
		//               5     opcode  Imm		Source	  Dest.
		instrbusin 		[42] ={ANDIS,  12'h000, 5'b00001, 5'b00001};//You need all 32 bits here. like always...
		daddrbusout		[42] = 64'h0000000000000000;
		databusin  		[42] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[42] = dontcare;
		gen_opcodeOut	[42] = ANDIS;
		registerValOut	[42] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ANDS X2, X23, X26
		iaddrbusout		[43] = 64'h000000000000022C;
		//               5     opcode  bbus		000000  abus      dest
		instrbusin 		[43] ={ANDS,   5'b11010, shamt, 5'b10111, 5'b00010};//You need all 32 bits here. like always...
		daddrbusout		[43] = 64'h0000000000000002;
		databusin  		[43] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[43] = dontcare;
		gen_opcodeOut	[43] = ANDS;
		registerValOut	[43] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//CBNZ X31, #300
        iaddrbusout		[44] = 64'h000000000000230;
		//               5     opcode  conditional branch address	register to check
		instrbusin 		[44] ={CBNZ,   19'h0012C, 					5'b11111};//You need all 32 bits here.
		daddrbusout		[44] = 64'h00002aaa2aaa0847;
		databusin  		[44] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[44] = dontcare;
		gen_opcodeOut	[44] = CBNZ;
		registerValOut	[44] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//CBNZ X31, #-150
        iaddrbusout		[45] = 64'h000000000000234;
		//               5     opcode  conditional branch address	register to check
		instrbusin 		[45] ={CBZ,   19'b1111111111101101010,      5'b11111};//You need all 32 bits here.
		daddrbusout		[45] = 64'h0000000000000000;
		databusin  		[45] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[45] = dontcare;
		gen_opcodeOut	[45] = CBZ;
		registerValOut	[45] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//EOR X3, X29, X22
		iaddrbusout		[46] = 64'h0000000000000238;
		//               5     opcode  bbus		000000  abus      dest
		instrbusin 		[46] ={EOR,   5'b10110, shamt, 5'b11101, 5'b00011};//You need all 32 bits here. like always...
		daddrbusout		[46] = 64'h00000003fffff801;
		databusin  		[46] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[46] = dontcare;
		gen_opcodeOut	[46] = EOR;
		registerValOut	[46] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//EORI X4, X23, 1995
		iaddrbusout		[47] = 64'hFFFFFFFFFFFFFFe0;
		//               5     opcode  Imm		         Source	  Dest.
		instrbusin 		[47] ={EORI,  12'b011111001011, 5'b10111, 5'b00100};//You need all 32 bits here. like always...
		daddrbusout		[47] = 64'h0000000000002d61;
		databusin  		[47] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[47] = dontcare;
		gen_opcodeOut	[47] = EORI;
		registerValOut	[47] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//LDUR X5, [X12, #0]
        iaddrbusout		[48] = 64'hFFFFFFFFFFFFFFe4;
		//               6    opcode DT_address      op2    rn	     Destination
		instrbusin 		[48] ={LDUR,  9'b000000000,   2'b00, 5'b01100, 5'b00101};//You need all 32 bits here.
		daddrbusout		[48] = 64'h00002aaa2aaa0847;
		databusin  		[48] = 64'hCCC000FFFFFFEEEE;
		databusout 		[48] = dontcare;
		gen_opcodeOut	[48] = LDUR;
		registerValOut	[48] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//LSL X5, X29, #11
        iaddrbusout		[49] = 64'hFFFFFFFFFFFFFFe8;
		//               5    opcode  bbus	    shamt    abus	     Destination
		instrbusin 		[49] ={LSL, 	 5'b00000, 6'b001011 ,5'b11101, 5'b00101};//You need all 32 bits here.
		daddrbusout		[49] = 64'h0155500000001000;
		databusin  		[49] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[49] = dontcare;
		gen_opcodeOut	[49] = LSL;
		registerValOut	[49] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//LSR X6, X23, #63
        iaddrbusout		[50] = 64'hFFFFFFFFFFFFFFeC;
		//               5    opcode  bbus	    shamt    abus	     Destination
		instrbusin 		[50] ={LSR, 	 5'b00000, 6'b111111 ,5'b10111, 5'b00110};//You need all 32 bits here.
		daddrbusout		[50] = 64'h0;
		databusin  		[50] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[50] = dontcare;
		gen_opcodeOut	[50] = LSR;
		registerValOut	[50] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//MOVZ X7, 5A5A, LSL 16
        iaddrbusout		[51] = 64'hFFFFFFFFFFFFFFF0;
		//               5     opcode  op2		16'bit Imm      dest
		instrbusin 		[51] ={MOVZ,   quad1,   16'h5A5A,     5'b00111};//You need all 32 bits here. like always...
		daddrbusout		[51] = 64'h000000005A5A0000;
		databusin  		[51] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[51] = dontcare;
		gen_opcodeOut	[51] = MOVZ;
		registerValOut	[51] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* ORR X8, X3, X4				195ns
        iaddrbusout		[52] = 64'hFFFFFFFFFFFFFFF4;
        //               5     opcode  bbus		000000  abus      dest
        instrbusin 		[52] ={ORR,   5'b00100, shamt, 5'b00011, 5'b01000};//You need all 32 bits here. like always...
        daddrbusout		[52] = 64'h00000003fffffd61;
        databusin  		[52] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[52] = dontcare;
		gen_opcodeOut	[52] = ORR;
		registerValOut	[52] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ORRI X9, X6, #1010
		iaddrbusout		[53] = 64'hFFFFFFFFFFFFFFF8;
		//               5     opcode  Imm		         Source	  Dest.
		instrbusin 		[53] ={ORRI,  12'b001111110010, 5'b00110, 5'b01001};//You need all 32 bits here. like always...
		daddrbusout		[53] = 64'h00000000000003f2;
		databusin  		[53] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[53] = dontcare;
		gen_opcodeOut	[53] = ORRI;
		registerValOut	[53] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//* STUR  X25, [X22, #0]					135ns
        iaddrbusout		[54] = 64'hFFFFFFFFFFFFFFFC;
        //               6    opcode DT_address      op2    M[Rn] 	  myRegister //11001
        instrbusin 		[54] ={STUR,  9'b000000000,   2'b00, 5'b10110, 5'b11001};//You need all 32 bits here.
        daddrbusout		[54] = 64'h000055540000004a;
        databusin  		[54] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[54] = 64'h00002aaa00000802;
		gen_opcodeOut	[54] = STUR;
		registerValOut	[54] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUB X10, X23, X22
		iaddrbusout		[55] = 64'h0000000000000000;
		//               5     opcode  bbus		000000  abus      dest
		instrbusin 		[55] ={SUB,   5'b10110, shamt, 5'b10111, 5'b01010};//You need all 32 bits here. like always...
		daddrbusout		[55] = 64'hffffd556000032a7;
		databusin  		[55] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[55] = dontcare;
		gen_opcodeOut	[55] = SUB;
		registerValOut	[55] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUBI X11, X30, #444
		iaddrbusout		[56] = 64'h0000000000000004;
		//               5     opcode  Imm		         Source	  Dest.
		//instrbusin 		[56] ={SUBI,  12'b000110111100??, 5'b11110, 5'b01011};//You need all 32 bits here. like always...
		instrbusin 		[56] ={SUBI,  12'd444, 5'd30, 5'd11};//You need all 32 bits here. like always...
		daddrbusout		[56] = 64'h0000000000000643;
		databusin  		[56] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[56] = dontcare;
		gen_opcodeOut	[56] = SUBI;
		registerValOut	[56] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUBIS X12, X4, #545
		iaddrbusout		[57] = 64'h0000000000000008;
		//               5     opcode  Imm     Source	  Dest.
		//instrbusin 		[56] ={SUBI,  12'b000110111100??, 5'b11110, 5'b01011};//You need all 32 bits here. like always...
		instrbusin 		[57] ={SUBIS,  12'd545, 5'd4, 5'd12};//You need all 32 bits here. like always...
		daddrbusout		[57] = 64'h0000000000002b40;
		databusin  		[57] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[57] = dontcare;
		gen_opcodeOut	[57] = SUBIS;
		registerValOut	[57] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUBS X13, X15, X16
		iaddrbusout		[58] = 64'h000000000000000C;
		//               5     opcode  bbus		000000  abus      dest
		instrbusin 		[58] ={SUBS,   5'd16, shamt, 5'd15, 5'd13};//You need all 32 bits here. like always...
		daddrbusout		[58] = 64'h0000000000000fff;
		databusin  		[58] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[58] = dontcare;
		gen_opcodeOut	[58] = SUBS;
		registerValOut	[58] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//EOR X14, X5, X16
		iaddrbusout		[59] = 64'h0000000000000010;
		//               5     opcode  bbus		000000  abus      dest
		instrbusin 		[59] ={EOR,   5'd16, shamt, 5'd5, 5'd14};//You need all 32 bits here. like always...
		daddrbusout		[59] = 64'h0155500000001000;
		databusin  		[59] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[59] = dontcare;
		gen_opcodeOut	[59] = EOR;
		registerValOut	[59] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//EOR X15, X6, X24
		iaddrbusout		[60] = 64'h0000000000000014;
		//               5     opcode  bbus		000000  abus      dest
		instrbusin 		[60] ={EOR,   5'd24, shamt, 5'd6, 5'd15};//You need all 32 bits here. like always...
		daddrbusout		[60] = 64'habce1a55cdefa3d0;
		databusin  		[60] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[60] = dontcare;
		gen_opcodeOut	[60] = EOR;
		registerValOut	[60] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//EORI X16, X22, #-1010
		iaddrbusout		[61] = 64'h0000000000000018;
		//               5     opcode  Imm     Source	  Dest.
		//instrbusin 		[56] ={SUBI,  12'b000110111100??, 5'b11110, 5'b01011};//You need all 32 bits here. like always...
		instrbusin 		[61] ={EORI,  12'b110000001110, 5'd22, 5'd16};//You need all 32 bits here. like always...
		daddrbusout		[61] = 64'h00002aa9fffff40d;
		databusin  		[61] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[61] = dontcare;
		gen_opcodeOut	[61] = EORI;
		registerValOut	[61] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//EORI X17, X12, #1111
		iaddrbusout		[62] = 64'h000000000000001C;
		//               5     opcode  Imm     Source	  Dest.
		//instrbusin 		[56] ={SUBI,  12'b000110111100??, 5'b11110, 5'b01011};//You need all 32 bits here. like always...
		instrbusin 		[62] ={EORI,  12'd1111, 5'd12, 5'd17};//You need all 32 bits here. like always...
		daddrbusout		[62] = 64'h0000000000002f17;
		databusin  		[62] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[62] = dontcare;
		gen_opcodeOut	[62] = EORI;
		registerValOut	[62] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADD X18, X31, X22
		iaddrbusout		[63] = 64'h0000000000000020;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[63] ={ADD,   5'd22,    shamt,   5'd31,    5'd18};//You need all 32 bits here. like always...
		daddrbusout		[63] = 64'h00002aa9fffff803;
		databusin  		[63] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[63] = dontcare;
		gen_opcodeOut	[63] = ADD;
		registerValOut	[63] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADD X19, X22, X22
		iaddrbusout		[64] = 64'h0000000000000024;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[64] ={ADD,   5'd22,    shamt,   5'd22,    5'd19};//You need all 32 bits here. like always...
		daddrbusout		[64] = 64'h00005553fffff006;
		databusin  		[64] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[64] = dontcare;
		gen_opcodeOut	[64] = ADD;
		registerValOut	[64] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADDI X20 X23, #16
		iaddrbusout		[65] = 64'h0000000000000028;
		//               5     opcode  Imm     Source	  Dest.
		//instrbusin 		[56] ={SUBI,  12'b000110111100??, 5'b11110, 5'b01011};//You need all 32 bits here. like always...
		instrbusin 		[65] ={ADDI,  12'd16, 5'd23, 5'd20};//You need all 32 bits here. like always...
		daddrbusout		[65] = 64'h0000000000002aba;
		databusin  		[65] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[65] = dontcare;
		gen_opcodeOut	[65] = ADDI;
		registerValOut	[65] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//AND X21, X12, X28
		iaddrbusout		[66] = 64'h000000000000002C;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[66] ={AND,   5'd28,    shamt,   5'd12,    5'd21};//You need all 32 bits here. like always...
		daddrbusout		[66] = 64'h0000000000000000;
		databusin  		[66] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[66] = dontcare;
		gen_opcodeOut	[66] = AND;
		registerValOut	[66] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDI X22, X28, #2047
		iaddrbusout		[67] = 64'h0000000000000030;
		//               5     opcode  Imm     Source	  Dest.
		//instrbusin 		[56] ={SUBI,  12'b000110111100??, 5'b11110, 5'b01011};//You need all 32 bits here. like always...
		instrbusin 		[67] ={ANDI,  12'd2047, 5'd28, 5'd22};//You need all 32 bits here. like always...
		daddrbusout		[67] = 64'h0000000000000005;
		databusin  		[67] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[67] = dontcare;
		gen_opcodeOut	[67] = ANDI;
		registerValOut	[67] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDIS X23, X29, #2047
		iaddrbusout		[68] = 64'h0000000000000034;
		//               5     opcode  Imm     Source	  Dest.
		//instrbusin 		[56] ={SUBI,  12'b000110111100??, 5'b11110, 5'b01011};//You need all 32 bits here. like always...
		instrbusin 		[68] ={ANDIS,  12'd2047, 5'd29, 5'd23};//You need all 32 bits here. like always...
		daddrbusout		[68] = 64'h0000000000000002;
		databusin  		[68] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[68] = dontcare;
		gen_opcodeOut	[68] = ANDIS;
		registerValOut	[68] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//B #2000
        iaddrbusout		[69] = 64'h0000000000000038; 
		//               5     opcode  conditional branch address
		instrbusin 		[69] ={B, 26'd2000};//You need all 32 bits here.
		daddrbusout		[69] = 64'h00002aaa00001046;
		databusin  		[69] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[69] = dontcare;
		gen_opcodeOut	[69] = B;
		registerValOut	[69] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ORRI X24, X2, #2047
		iaddrbusout		[70] = 64'h000000000000003C;
		//               5     opcode  Imm     Source	  Dest.
		//instrbusin 		[56] ={SUBI,  12'b000110111100??, 5'b11110, 5'b01011};//You need all 32 bits here. like always...
		instrbusin 		[70] ={ORRI,  12'd2047, 5'd2, 5'd24};//You need all 32 bits here. like always...
		daddrbusout		[70] = 64'h00000000000007ff;
		databusin  		[70] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[70] = dontcare;
		gen_opcodeOut	[70] = ORRI;
		registerValOut	[70] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ORR X25, X3, X4
		iaddrbusout		[71] = 64'h0000000000001F7C;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[71] ={ORR,   5'd4,    shamt,   5'd3,    5'd25};//You need all 32 bits here. like always...
		daddrbusout		[71] = 64'h00000003fffffd61;
		databusin  		[71] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[71] = dontcare;
		gen_opcodeOut	[71] = ORR;
		registerValOut	[71] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ORR X26, X31, X31
		iaddrbusout		[72] = 64'h0000000000001F80;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[72] ={ORR,   5'd31,    shamt,   5'd31,    5'd26};//You need all 32 bits here. like always...
		daddrbusout		[72] = 64'h0000000000000000;
		databusin  		[72] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[72] = dontcare;
		gen_opcodeOut	[72] = ORR;
		registerValOut	[72] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//SUB X27, X2, X19
		iaddrbusout		[73] = 64'h0000000000001F84;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[73] ={SUB,   5'd19,    shamt,   5'd2,    5'd27};//You need all 32 bits here. like always...
		daddrbusout		[73] = 64'hffffaaac00000ffc;
		databusin  		[73] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[73] = dontcare;
		gen_opcodeOut	[73] = SUB;
		registerValOut	[73] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//SUBI X28, X3, #1995
		iaddrbusout		[74] = 64'h0000000000001F88;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[74] ={SUBI,  12'd1995, 5'd3, 5'd28};//You need all 32 bits here. like always...
		daddrbusout		[74] = 64'h00000003fffff036;
		databusin  		[74] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[74] = dontcare;
		gen_opcodeOut	[74] = SUBI;
		registerValOut	[74] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUBIS X29, X4, #1234
		iaddrbusout		[75] = 64'h0000000000001F8C;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[75] ={SUBIS,  12'd1234, 5'd4, 5'd29};//You need all 32 bits here. like always...
		daddrbusout		[75] = 64'h000000000000288f;
		databusin  		[75] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[75] = dontcare;
		gen_opcodeOut	[75] = SUBIS;
		registerValOut	[75] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//SUBS X30, X5, X19
		iaddrbusout		[76] = 64'h0000000000001F90;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[76] ={SUBS,   5'd19,    shamt,   5'd5,    5'd30};//You need all 32 bits here. like always...
		daddrbusout		[76] = 64'h0154faac00001ffa;
		databusin  		[76] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[76] = dontcare;
		gen_opcodeOut	[76] = SUBS;
		registerValOut	[76] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADD X1, X13, X23
		iaddrbusout		[77] = 64'h0000000000001F94;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[77] ={ADD,   5'd23,    shamt,   5'd13,    5'd1};//You need all 32 bits here. like always...
		daddrbusout		[77] = 64'h0000000000001001;
		databusin  		[77] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[77] = dontcare;
		gen_opcodeOut	[77] = ADD;
		registerValOut	[77] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ADDI X2, X23, #1234
		iaddrbusout		[78] = 64'h0000000000001F98;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[78] ={ADDI,  12'd1234, 5'd23, 5'd2};//You need all 32 bits here. like always...
		daddrbusout		[78] = 64'h00000000000004d4;
		databusin  		[78] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[78] = dontcare;
		gen_opcodeOut	[78] = ADDI;
		registerValOut	[78] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ADDIS X3, X24, #999
		iaddrbusout		[79] = 64'h0000000000001F9C;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[79] ={ADDIS,  12'd999, 5'd24, 5'd3};//You need all 32 bits here. like always...
		daddrbusout		[79] = 64'h0000000000000be6;
		databusin  		[79] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[79] = dontcare;
		gen_opcodeOut	[79] = ADDIS;
		registerValOut	[79] = 64'h0000000000000000;//The value that is overwritten with a new value.	
		
		//ADDS X4, X25, X23
		iaddrbusout		[80] = 64'h0000000000001FA0;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[80] ={ADDS,   5'd23,    shamt,   5'd25,    5'd4};//You need all 32 bits here. like always...
		daddrbusout		[80] = 64'h00000003fffffd63;
		databusin  		[80] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[80] = dontcare;
		gen_opcodeOut	[80] = ADDS;
		registerValOut	[80] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//AND X5, X30, X12
		iaddrbusout		[81] = 64'h0000000000001FA4;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[81] ={AND,   5'd12,    shamt,   5'd30,    5'd5};//You need all 32 bits here. like always...
		daddrbusout		[81] = 64'h0000000000000b40;
		databusin  		[81] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[81] = dontcare;
		gen_opcodeOut	[81] = AND;
		registerValOut	[81] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDI X6, X21, #343
		iaddrbusout		[82] = 64'h0000000000001FA8;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[82] ={ANDI,  12'd343, 5'd21, 5'd6};//You need all 32 bits here. like always...
		daddrbusout		[82] = 64'h0000000000000000;
		databusin  		[82] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[82] = dontcare;
		gen_opcodeOut	[82] = ANDI;
		registerValOut	[82] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ANDIS X7, X22, #500
		iaddrbusout		[83] = 64'h0000000000001FAC;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[83] ={ANDIS,  12'd500, 5'd22, 5'd7};//You need all 32 bits here. like always...
		daddrbusout		[83] = 64'h0000000000000004;
		databusin  		[83] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[83] = dontcare;
		gen_opcodeOut	[83] = ANDIS;
		registerValOut	[83] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDS X8, X23, X30
		iaddrbusout		[84] = 64'h0000000000001FB0;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[84] ={ANDS,   5'd23,    shamt,   5'd30,    5'd8};//You need all 32 bits here. like always...
		daddrbusout		[84] = 64'h0000000000000002;
		databusin  		[84] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[84] = dontcare;
		gen_opcodeOut	[84] = ANDS;
		registerValOut	[84] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDIS X9, X22, #909
		iaddrbusout		[85] = 64'h0000000000001FB4;
		//               55    opcode  Imm     Source	  Dest.
		instrbusin 		[85] ={ANDIS,  12'd909, 5'd22, 5'd9};//You need all 32 bits here. like always...
		daddrbusout		[85] = 64'h0000000000000005;
		databusin  		[85] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[85] = dontcare;
		gen_opcodeOut	[85] = ANDIS;
		registerValOut	[85] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//EOR X10, X12, X14
		iaddrbusout		[86] = 64'h0000000000001FB8;
		//               56    opcode  bbus		000000   abus      dest
		instrbusin 		[86] ={EOR,   5'd14,    shamt,   5'd12,    5'd10};//You need all 32 bits here. like always...
		daddrbusout		[86] = 64'h0155500000003b40;
		databusin  		[86] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[86] = dontcare;
		gen_opcodeOut	[86] = EOR;
		registerValOut	[86] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//EORI X11, X22, #117
		iaddrbusout		[87] = 64'h0000000000001FBC;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[87] ={EORI,  12'd117, 5'd22, 5'd11};//You need all 32 bits here. like always...
		daddrbusout		[87] = 64'h0000000000000070;
		databusin  		[87] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[87] = dontcare;
		gen_opcodeOut	[87] = EORI;
		registerValOut	[87] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ORR X12, X12, X12
		iaddrbusout		[88] = 64'h0000000000001FC0;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[88] ={ORR,   5'd12,    shamt,   5'd12,    5'd12};//You need all 32 bits here. like always...
		daddrbusout		[88] = 64'h0000000000002b40;
		databusin  		[88] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[88] = dontcare;
		gen_opcodeOut	[88] = ORR;
		registerValOut	[88] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ORRI X13, X21, #345
		iaddrbusout		[89] = 64'h0000000000001FC4;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[89] ={ORRI,  12'd345, 5'd21, 5'd13};//You need all 32 bits here. like always...
		daddrbusout		[89] = 64'h0000000000000159;
		databusin  		[89] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[89] = dontcare;
		gen_opcodeOut	[89] = ORRI;
		registerValOut	[89] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//SUB X14, X23, X21
		iaddrbusout		[90] = 64'h0000000000001FC8;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[90] ={SUB,   5'd21,    shamt,   5'd23,    5'd14};//You need all 32 bits here. like always...
		daddrbusout		[90] = 64'h0000000000000002;
		databusin  		[90] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[90] = dontcare;
		gen_opcodeOut	[90] = SUB;
		registerValOut	[90] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUBI X15, X2, #696
		iaddrbusout		[91] = 64'h0000000000001FCC;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[91] ={SUBI,  12'd696, 5'd2, 5'd15};//You need all 32 bits here. like always...
		daddrbusout		[91] = 64'h000000000000021c;
		databusin  		[91] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[91] = dontcare;
		gen_opcodeOut	[91] = SUBI;
		registerValOut	[91] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//SUBIS X16, X31, #787
		iaddrbusout		[92] = 64'h0000000000001FD0;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[92] ={SUBIS,  12'd787, 5'd31, 5'd16};//You need all 32 bits here. like always...
		daddrbusout		[92] = 64'hfffffffffffffced;
		databusin  		[92] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[92] = dontcare;
		gen_opcodeOut	[92] = SUBIS;
		registerValOut	[92] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUBS X17, X18, X15
		iaddrbusout		[93] = 64'h0000000000001FD4;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[93] ={SUBS,   5'd15,    shamt,   5'd18,    5'd17};//You need all 32 bits here. like always...
		daddrbusout		[93] = 64'h5432105432105433;
		databusin  		[93] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[93] = dontcare;
		gen_opcodeOut	[93] = SUBS;
		registerValOut	[93] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADD X18, X9, X4
		iaddrbusout		[94] = 64'h0000000000001FD8;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[94] ={ADD,   5'd4,    shamt,   5'd9,    5'd18};//You need all 32 bits here. like always...
		daddrbusout		[94] = 64'h00000003fffffd68;
		databusin  		[94] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[94] = dontcare;
		gen_opcodeOut	[94] = ADD;
		registerValOut	[94] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADDI X19, X12, X31
		iaddrbusout		[95] = 64'h0000000000001FDC;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[95] ={ADDI,  12'd666, 5'd12, 5'd19};//You need all 32 bits here. like always...
		daddrbusout		[95] = 64'h0000000000002dda;
		databusin  		[95] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[95] = dontcare;
		gen_opcodeOut	[95] = ADDI;
		registerValOut	[95] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADDIS X20, X12, #1029
		iaddrbusout		[96] = 64'h0000000000001FE0;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[96] ={ADDIS,  12'd1029, 5'd12, 5'd20};//You need all 32 bits here. like always...
		daddrbusout		[96] = 64'h0000000000002f45;
		databusin  		[96] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[96] = dontcare;
		gen_opcodeOut	[96] = ADDIS;
		registerValOut	[96] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ADDS X21, X17, X1
		iaddrbusout		[97] = 64'h0000000000001FE4;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[97] ={ADDS,   5'd1,    shamt,   5'd17,    5'd21};//You need all 32 bits here. like always...
		daddrbusout		[97] = 64'h5432105432106434;
		databusin  		[97] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[97] = dontcare;
		gen_opcodeOut	[97] = ADDS;
		registerValOut	[97] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//AND X22, X21, X2
		iaddrbusout		[98] = 64'h0000000000001FE8;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[98] ={AND,   5'd2,    shamt,   5'd21,    5'd22};//You need all 32 bits here. like always...
		daddrbusout		[98] = 64'h0000000000000000;
		databusin  		[98] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[98] = dontcare;
		gen_opcodeOut	[98] = AND;
		registerValOut	[98] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDI X23, X15, #2000
		iaddrbusout		[99] = 64'h0000000000001FEC;
		//               5     opcode IMM    abus      dest
		instrbusin 		[99] ={ANDI,  12'd2000,        5'd15, 5'd23};//You need all 32 bits here. like always...
		daddrbusout		[99] = 64'h0000000000000210;
		databusin  		[99] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[99] = dontcare;
		gen_opcodeOut	[99] = ANDI;
		registerValOut	[99] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDIS X24, X11, #1111
		iaddrbusout		[100] = 64'h0000000000001FF0;
		//               5     opcode   IMM        abus      dest
		instrbusin 		[100] ={ANDIS,  12'd1111,  5'd11,    5'd24};//You need all 32 bits here. like always...
		daddrbusout		[100] = 64'h0000000000000050;
		databusin  		[100] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[100] = dontcare;
		gen_opcodeOut	[100] = ANDIS;
		registerValOut	[100] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//LDUR X25, [X12, #0]
        iaddrbusout		[101] = 64'h0000000000001FF4;
		//               6    opcode  DT_address      op2    rn	     Destination
		instrbusin 		[101] ={LDUR,  9'b000000000,   2'b00, 5'd25, 5'd12};//You need all 32 bits here.
		daddrbusout		[101] = 64'h00002aae000005a8;
		databusin  		[101] = 64'h1234567890111213;
		databusout 		[101] = dontcare;
		gen_opcodeOut	[101] = LDUR;
		registerValOut	[101] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//LSL X26, X22, #32
        iaddrbusout		[102] = 64'h0000000000001FF8;
		//               5    opcode     bbus	    shamt    abus	     Destination
		instrbusin 		[102] ={LSL, 	 5'd0,      6'd32,   5'd22,      5'd26};//You need all 32 bits here.
		daddrbusout		[102] = 64'h0000000000000000;
		databusin  		[102] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[102] = dontcare;
		gen_opcodeOut	[102] = LSL;
		registerValOut	[102] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//LSR X27, X22, #12
		iaddrbusout		[103] = 64'h0000000000001FFC;
		//               5    opcode     bbus	    shamt    abus	     Destination
		instrbusin 		[103] ={LSR, 	 5'd0,      6'd12,   5'd22,       5'd27};//You need all 32 bits here.
		daddrbusout		[103] = 64'h0;
		databusin  		[103] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[103] = dontcare;
		gen_opcodeOut	[103] = LSR;
		registerValOut	[103] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//MOVZ X28, #32767, LSL 0
        iaddrbusout		[104] = 64'h0000000000002000;
		//               5     opcode  op2		16'bit Imm      dest
		instrbusin 		[104] ={MOVZ,   quad0,   16'd32767,     5'd28};//You need all 32 bits here. like always...
		daddrbusout		[104] = 64'h0000000000007fff;
		databusin  		[104] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[104] = dontcare;
		gen_opcodeOut	[104] = MOVZ;
		registerValOut	[104] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ORR X29, X26, X11
		iaddrbusout		[105] = 64'h0000000000002004;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[105] ={ORR,   5'd11,    shamt,   5'd26,    5'd29};//You need all 32 bits here. like always...
		daddrbusout		[105] = 64'h0000000000000070;
		databusin  		[105] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[105] = dontcare;
		gen_opcodeOut	[105] = ORR;
		registerValOut	[105] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ORRI X30, X21, #AAA
		iaddrbusout		[106] = 64'h0000000000002008;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[106] ={ORRI,  12'hAAA, 5'd21, 5'd30};//You need all 32 bits here. like always...
		daddrbusout		[106] = 64'h5432105432106ebe;
		databusin  		[106] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[106] = dontcare;
		gen_opcodeOut	[106] = ORRI;
		registerValOut	[106] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//STUR X1, [X12, #0]
        iaddrbusout		[107] = 64'h000000000000200C;
		//               6    opcode DT_address        op2    M[Rn] 	  myRegister
		instrbusin 		[107] ={STUR,  9'b000000000,   2'b00, 5'd12,      5'd1};//You need all 32 bits here.
		daddrbusout		[107] = 64'h1234812290111a5a;
		databusin  		[107] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[107] = 64'h0000000000001001;
		gen_opcodeOut	[107] = STUR;
		registerValOut	[107] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//SUB X2, X22, X3
		iaddrbusout		[108] = 64'h0000000000002010;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[108] ={SUB,   5'd3,    shamt,   5'd22,    5'd2};//You need all 32 bits here. like always...
		daddrbusout		[108] = 64'hfffffffffffff41a;
		databusin  		[108] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[108] = dontcare;
		gen_opcodeOut	[108] = SUB;
		registerValOut	[108] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUBI X3, X12, #FAD
		iaddrbusout		[109] = 64'h0000000000002014;
		//               5     opcode  Imm              Source	  Dest.
		instrbusin 		[109] ={SUBI,  12'hFAD, 5'd12, 5'd3};//You need all 32 bits here. like always...
		daddrbusout		[109] = 64'h1234567890110266;
		databusin  		[109] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[109] = dontcare;
		gen_opcodeOut	[109] = SUBI;
		registerValOut	[109] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//SUBIS X4, X12, #456
		iaddrbusout		[110] = 64'h0000000000002018;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[110] ={SUBIS,  12'd456, 5'd12, 5'd4};//You need all 32 bits here. like always...
		daddrbusout		[110] = 64'h123456789011104b;
		databusin  		[110] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[110] = dontcare;
		gen_opcodeOut	[110] = SUBIS;
		registerValOut	[110] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUBS X5, X12, X12
		iaddrbusout		[111] = 64'h000000000000201C;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[111] ={SUBS,   5'd12,    shamt,   5'd12,    5'd5};//You need all 32 bits here. like always...
		daddrbusout		[111] = 64'h0000000000000000;
		databusin  		[111] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[111] = dontcare;
		gen_opcodeOut	[111] = SUBS;
		registerValOut	[111] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//B #-500
        iaddrbusout		[112] = 64'h0000000000002020; 
		//               5     opcode  conditional branch address
		instrbusin 		[112] ={B, 26'b11111111111111111000001100};//You need all 32 bits here.
		daddrbusout		[112] = 64'hfffffffffffffced;
		databusin  		[112] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[112] = dontcare;
		gen_opcodeOut	[112] = B;
		registerValOut	[112] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADD X5, X19, X20
		iaddrbusout		[113] = 64'h0000000000002024;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[113] ={ADD,   5'd20,    shamt,   5'd19,    5'd5};//You need all 32 bits here. like always...
		daddrbusout		[113] = 64'h0000000000005d1f;
		databusin  		[113] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[113] = dontcare;
		gen_opcodeOut	[113] = ADD;
		registerValOut	[113] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADDI X6, X22, #DAB
		iaddrbusout		[114] = 64'h0000000000001854;
		//               5   			IMM     ABUS    DEST
		instrbusin 		[114] ={ADDI,  12'hDAB, 5'd22, 5'd6};//You need all 32 bits here. like always...
		daddrbusout		[114] = 64'h0000000000000dab;
		databusin  		[114] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[114] = dontcare;
		gen_opcodeOut	[114] = ADDI;
		registerValOut	[114] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADDIS X7, X3, #BAD
		iaddrbusout		[115] = 64'h0000000000001858;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[115] ={ADDIS,  12'hBAD, 5'd3, 5'd7};//You need all 32 bits here. like always...
		daddrbusout		[115] = 64'h1234567890110e13;
		databusin  		[115] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[115] = dontcare;
		gen_opcodeOut	[115] = ADDIS;
		registerValOut	[115] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ADDS X8, X4, X8
		iaddrbusout		[116] = 64'h000000000000185C;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[116] ={ADDS,   5'd8,    shamt,   5'd4,    5'd8};//You need all 32 bits here. like always...
		daddrbusout		[116] = 64'h123456789011104d;
		databusin  		[116] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[116] = dontcare;
		gen_opcodeOut	[116] = ADDS;
		registerValOut	[116] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//AND X9, X3, X2
		iaddrbusout		[117] = 64'h0000000000001860;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[117] ={AND,   5'd2,    shamt,   5'd3,    5'd9};//You need all 32 bits here. like always...
		daddrbusout		[117] = 64'h1234567890110002;
		databusin  		[117] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[117] = dontcare;
		gen_opcodeOut	[117] = AND;
		registerValOut	[117] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDI X10, X20, #CAF
		iaddrbusout		[118] = 64'h0000000000001864;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[118] ={ANDI,  12'hCAF, 5'd20, 5'd10};//You need all 32 bits here. like always...
		daddrbusout		[118] = 64'h0000000000000c05;
		databusin  		[118] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[118] = dontcare;
		gen_opcodeOut	[118] = ANDI;
		registerValOut	[118] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ANDIS X11, X23, #6B2
		iaddrbusout		[119] = 64'h0000000000001868;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[119] ={ANDIS,  12'h6B2, 5'd23, 5'd11};//You need all 32 bits here. like always...
		daddrbusout		[119] = 64'h0000000000000210;
		databusin  		[119] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[119] = dontcare;
		gen_opcodeOut	[119] = ANDIS;
		registerValOut	[119] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDS X12, X12, X23
		iaddrbusout		[120] = 64'h000000000000186C;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[120] ={ANDS,   5'd23,    shamt,   5'd12,    5'd12};//You need all 32 bits here. like always...
		daddrbusout		[120] = 64'h0000000000000210;
		databusin  		[120] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[120] = dontcare;
		gen_opcodeOut	[120] = ANDS;
		registerValOut	[120] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//CBNZ, X10, #65535
        iaddrbusout		[121] = 64'h0000000000001870;
		//               5     opcode  conditional branch address	register to check
		instrbusin 		[121] ={CBNZ,   19'd65535, 					5'd10};//You need all 32 bits here.
		daddrbusout		[121] = 64'h0000000000000000;
		databusin  		[121] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[121] = dontcare;
		gen_opcodeOut	[121] = CBNZ;
		registerValOut	[121] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//EOR, X13, X11, X23
		iaddrbusout		[122] = 64'h0000000000001874;
		//               56    opcode  bbus		000000   abus      dest
		instrbusin 		[122] ={EOR,   5'd23,    shamt,   5'd11,    5'd13};//You need all 32 bits here. like always...
		daddrbusout		[122] = 64'h0000000000000000;
		databusin  		[122] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[122] = dontcare;
		gen_opcodeOut	[122] = EOR;
		registerValOut	[122] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//EORI X14, X22, #456
		iaddrbusout		[123] = 64'h0000000000041870;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[123] ={EORI,  12'd456, 5'd22, 5'd14};//You need all 32 bits here. like always...
		daddrbusout		[123] = 64'h00000000000001c8;
		databusin  		[123] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[123] = dontcare;
		gen_opcodeOut	[123] = EORI;
		registerValOut	[123] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//LDUR X15, [X15, #0]
        iaddrbusout		[124] = 64'h0000000000041874;
		//               6    opcode  DT_address      op2    rn	     Destination
		instrbusin 		[124] ={LDUR,  9'b000000000,   2'b00, 5'd15, 5'd15};//You need all 32 bits here.
		daddrbusout		[124] = 64'h00002aaa00000a63;
		databusin  		[124] = 64'h8080808080808080;
		databusout 		[124] = dontcare;
		gen_opcodeOut	[124] = LDUR;
		registerValOut	[124] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//LSL X16, X21, #22
        iaddrbusout		[125] = 64'h0000000000041878;
		//               5    opcode     bbus	    shamt    abus	     Destination
		instrbusin 		[125] ={LSL, 	 5'd0,      6'd22,   5'd21,      5'd16};//You need all 32 bits here.
		daddrbusout		[125] = 64'h150c84190d000000;
		databusin  		[125] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[125] = dontcare;
		gen_opcodeOut	[125] = LSL;
		registerValOut	[125] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//LSR X17, X22, #45
		iaddrbusout		[126] = 64'h000000000004187C;
		//               5    opcode     bbus	    shamt    abus	     Destination
		instrbusin 		[126] ={LSR, 	 5'd0,      6'd45,   5'd22,       5'd17};//You need all 32 bits here.
		daddrbusout		[126] = 64'h0000000000000000;
		databusin  		[126] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[126] = dontcare;
		gen_opcodeOut	[126] = LSR;
		registerValOut	[126] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//MOVZ X18, #22222, LSL 16
		iaddrbusout		[127] = 64'h0000000000041880;
		//               5     opcode  op2		16'bit Imm      dest
		instrbusin 		[127] ={MOVZ,   quad1,   16'd22222,     5'd18};//You need all 32 bits here. like always...
		daddrbusout		[127] = 64'h0000000056ce0000;
		databusin  		[127] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[127] = dontcare;
		gen_opcodeOut	[127] = MOVZ;
		registerValOut	[127] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ORR X19, X2, X1
		iaddrbusout		[128] = 64'h0000000000041884;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[128] ={ORR,   5'd1,    shamt,   5'd2,    5'd19};//You need all 32 bits here. like always...
		daddrbusout		[128] = 64'hfffffffffffff41b;
		databusin  		[128] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[128] = dontcare;
		gen_opcodeOut	[128] = ORR;
		registerValOut	[128] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		 
		//ORRI X20, X12, #-10
		iaddrbusout		[129] = 64'h0000000000041888;
		//               5     opcode  Imm               Source	  Dest.
		instrbusin 		[129] ={ORRI,  12'b111111110110, 5'd12, 5'd20};//You need all 32 bits here. like always...
		daddrbusout		[129] = 64'h0000000000000ff6;
		databusin  		[129] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[129] = dontcare;
		gen_opcodeOut	[129] = ORRI;
		registerValOut	[129] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//STUR X4, [X22, #0]
		iaddrbusout		[130] = 64'h000000000004188C;
		//               6    opcode DT_address        op2    M[Rn] 	  myRegister
		instrbusin 		[130] ={STUR,  9'b000000000,   2'b00, 5'd22,      5'd4};//You need all 32 bits here.
		daddrbusout		[130] = 64'h00002aaa00000847;
		databusin  		[130] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[130] = 64'h123456789011104b;
		gen_opcodeOut	[130] = STUR;
		registerValOut	[130] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//SUB X5, X21, X2
		iaddrbusout		[131] = 64'h0000000000041890;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[131] ={SUB,   5'd2,    shamt,   5'd21,    5'd5};//You need all 32 bits here. like always...
		daddrbusout		[131] = 64'h543210543210701a;
		databusin  		[131] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[131] = dontcare;
		gen_opcodeOut	[131] = SUB;
		registerValOut	[131] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUBI X6, X2, #888
		iaddrbusout		[132] = 64'h0000000000041894;
		//               5     opcode  Imm              Source	  Dest.
		instrbusin 		[132] ={SUBI,  12'd888, 5'd2, 5'd6};//You need all 32 bits here. like always...
		daddrbusout		[132] = 64'hfffffffffffff0a2;
		databusin  		[132] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[132] = dontcare;
		gen_opcodeOut	[132] = SUBI;
		registerValOut	[132] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//SUBIS X7, X21, #343
		iaddrbusout		[133] = 64'h0000000000041898;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[133] ={SUBIS,  12'd343, 5'd21, 5'd7};//You need all 32 bits here. like always...
		daddrbusout		[133] = 64'h54321054321062dd;
		databusin  		[133] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[133] = dontcare;
		gen_opcodeOut	[133] = SUBIS;
		registerValOut	[133] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//SUBS X8, X18, X29
		iaddrbusout		[134] = 64'h000000000004189C;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[134] ={SUBS,   5'd29,    shamt,   5'd18,    5'd8};//You need all 32 bits here. like always...
		daddrbusout		[134] = 64'h0000000056cdff90;
		databusin  		[134] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[134] = dontcare;
		gen_opcodeOut	[134] = SUBS;
		registerValOut	[134] = 64'h0000000000000000;//The value that is overwritten with a new value.

		//BNE #50
        iaddrbusout		[135] = 64'h00000000000418A0; 
		//               5     opcode  conditional branch address
		instrbusin 		[135] ={BNE, 19'd50, 5'b00000};//You need all 32 bits here.
		daddrbusout		[135] = 64'h00002aaa56ce0847;
		databusin  		[135] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[135] = dontcare;
		gen_opcodeOut	[135] = BNE;
		registerValOut	[135] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADD X9, X3, X29
		iaddrbusout		[136] = 64'h00000000000418A4;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[136] ={ADD,   5'd29,    shamt,   5'd3,    5'd9};//You need all 32 bits here. like always...
		daddrbusout		[136] = 64'h12345678901102d6;
		databusin  		[136] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[136] = dontcare;
		gen_opcodeOut	[136] = ADD;
		registerValOut	[136] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADDI X10, X2, #1
		iaddrbusout		[137] = 64'h000000000004196C;
		//               5   			IMM     ABUS    DEST
		instrbusin 		[137] ={ADDI,  12'd1, 5'd2, 5'd10};//You need all 32 bits here. like always...
		daddrbusout		[137] = 64'hfffffffffffff41b;
		databusin  		[137] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[137] = dontcare;
		gen_opcodeOut	[137] = ADDI;
		registerValOut	[137] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ADDIS X11, X4, #-1
		iaddrbusout		[138] = 64'h0000000000041970;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[138] ={ADDIS,  12'hFFF, 5'd4, 5'd11};//You need all 32 bits here. like always...
		daddrbusout		[138] = 64'h123456789011204a;
		databusin  		[138] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[138] = dontcare;
		gen_opcodeOut	[138] = ADDIS;
		registerValOut	[138] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ADDS X12, X5, X2
		iaddrbusout		[139] = 64'h0000000000041974;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[139] ={ADDS,   5'd2,    shamt,   5'd5,    5'd12};//You need all 32 bits here. like always...
		daddrbusout		[139] = 64'h5432105432106434;
		databusin  		[139] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[139] = dontcare;
		gen_opcodeOut	[139] = ADDS;
		registerValOut	[139] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//AND X13, X3, X5
		iaddrbusout		[140] = 64'h0000000000041978;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[140] ={AND,   5'd5,    shamt,   5'd3,    5'd13};//You need all 32 bits here. like always...
		daddrbusout		[140] = 64'h1030105010100002;
		databusin  		[140] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[140] = dontcare;
		gen_opcodeOut	[140] = AND;
		registerValOut	[140] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDI X14, X2, #A6A
		iaddrbusout		[141] = 64'h000000000004197C;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[141] ={ANDI,  12'hA6A, 5'd2, 5'd14};//You need all 32 bits here. like always...
		daddrbusout		[141] = 64'h000000000000000a;
		databusin  		[141] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[141] = dontcare;
		gen_opcodeOut	[141] = ANDI;
		registerValOut	[141] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ANDIS X15, X2, #543
		iaddrbusout		[142] = 64'h0000000000041980;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[142] ={ANDIS,  12'd543, 5'd2, 5'd15};//You need all 32 bits here. like always...
		daddrbusout		[142] = 64'h000000000000001a;
		databusin  		[142] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[142] = dontcare;
		gen_opcodeOut	[142] = ANDIS;
		registerValOut	[142] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//ANDS X16, X2, X7
		iaddrbusout		[143] = 64'h0000000000041984;
		//               5     opcode  bbus		000000   abus      dest
		instrbusin 		[143] ={ANDS,   5'd7,    shamt,   5'd2,    5'd16};//You need all 32 bits here. like always...
		daddrbusout		[143] = 64'h5432105432106018;
		databusin  		[143] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[143] = dontcare;
		gen_opcodeOut	[143] = ANDS;
		registerValOut	[143] = 64'h0000000000000000;//The value that is overwritten with a new value.		
				
		//CBZ X12, #4444
        iaddrbusout		[144] = 64'h0000000000041988;
		//               5     opcode  conditional branch address	register to check
		instrbusin 		[144] ={CBZ,   19'd4444, 					5'd12};//You need all 32 bits here.
		daddrbusout		[144] = 64'h0000000000007419;
		databusin  		[144] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[144] = dontcare;
		gen_opcodeOut	[144] = CBZ;
		registerValOut	[144] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//EOR X13, X22, X9
		iaddrbusout		[145] = 64'h000000000004198C;
		//               56    opcode  bbus		000000   abus      dest
		instrbusin 		[145] ={EOR,   5'd9,    shamt,   5'd22,    5'd13};//You need all 32 bits here. like always...
		daddrbusout		[145] = 64'h12345678901102d6;
		databusin  		[145] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[145] = dontcare;
		gen_opcodeOut	[145] = EOR;
		registerValOut	[145] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//EORI X14, X23, #A6A
		iaddrbusout		[146] = 64'h0000000000041990;
		//               5     opcode  Imm     Source	  Dest.
		instrbusin 		[146] ={EORI,  12'hA6A, 5'd23, 5'd14};//You need all 32 bits here. like always...
		daddrbusout		[146] = 64'h000000000000087a;
		databusin  		[146] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[146] = dontcare;
		gen_opcodeOut	[146] = EORI;
		registerValOut	[146] = 64'h0000000000000000;//The value that is overwritten with a new value.		
			
		//LDUR X15, [X23, #0]
        iaddrbusout		[147] = 64'h0000000000041994;
		//               6    opcode  DT_address      op2    rn	     Destination
		instrbusin 		[147] ={LDUR,  9'b000000000,   2'b00, 5'd23, 5'd15};//You need all 32 bits here.
		daddrbusout		[147] = 64'h00002aaa56ce0a57;
		databusin  		[147] = 64'h6666666666666666;
		databusout 		[147] = dontcare;
		gen_opcodeOut	[147] = LDUR;
		registerValOut	[147] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//LSL X16, X12, #19
		iaddrbusout		[148] = 64'h0000000000041998;
		//               5    opcode     bbus	    shamt    abus	     Destination
		instrbusin 		[148] ={LSL, 	 5'd0,      6'd19,   5'd12,      5'd16};//You need all 32 bits here.
		daddrbusout		[148] = 64'h82a1908321a00000;
		databusin  		[148] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[148] = dontcare;
		gen_opcodeOut	[148] = LSL;
		registerValOut	[148] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//BEQ #2000
        iaddrbusout		[149] = 64'h000000000004199C; 
		//               5     opcode  conditional branch address
		instrbusin 		[149] ={BEQ, 19'd2000, 5'b00000};//You need all 32 bits here.
		daddrbusout		[149] = 64'h54323afe88de685f;
		databusin  		[149] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[149] = dontcare;
		gen_opcodeOut	[149] = BEQ;
		registerValOut	[149] = 64'h0000000000000000;//The value that is overwritten with a new value.	
		
		//LSR X17, X22, #16
		iaddrbusout		[150] = 64'h00000000000419A0;
		//               5    opcode     bbus	    shamt    abus	     Destination
		instrbusin 		[150] ={LSR, 	 5'd0,      6'd16,   5'd22,       5'd17};//You need all 32 bits here.
		daddrbusout		[150] = 64'h0000000000000000;
		databusin  		[150] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[150] = dontcare;
		gen_opcodeOut	[150] = LSR;
		registerValOut	[150] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
		//* SUBIS  X22, X13, #2045				175ns
        iaddrbusout		[151] = 64'h00000000000419A4;
        //               5     opcode  Imm		Source	  Dest.
        instrbusin 		[151] ={SUBIS,  12'h7FD, 5'b01101, 5'b10110};//You need all 32 bits here. like always...
        daddrbusout		[151] = 64'h123456789010fad9;
        databusin  		[151] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout 		[151] = dontcare;
		gen_opcodeOut	[151] = SUBIS;
		registerValOut	[151] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		
		
		//BLT #10
        iaddrbusout		[152] = 64'h00000000000419A8; 
		//               5     opcode  conditional branch address
		instrbusin 		[152] ={BLT, 19'd0010, 5'b00000};//You need all 32 bits here.
		daddrbusout		[152] = 64'h54323afe88de5c7a;
		databusin  		[152] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[152] = dontcare;
		gen_opcodeOut	[152] = BLT;
		registerValOut	[152] = 64'h0000000000000000;//The value that is overwritten with a new value.
		
		//ADDI X18, X12, #1
        iaddrbusout		[153] = 64'h000000000000419AC;
		//               4    opcode  Imm	  Source    Destination
		instrbusin 		[153] ={ADDI, 	 12'h001, 5'd12, 5'd18};
		daddrbusout		[153] = 64'h5432105432106435;
		databusin  		[153] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[153] = dontcare;
		gen_opcodeOut	[153] = ADDI << 1;
		registerValOut	[153] = 64'h0000000000000000;
		
		//ADDI X19, X12, #2
        iaddrbusout		[154] = 64'h00000000000419B0;
		//               4    opcode  Imm	  Source    Destination
		instrbusin 		[154] ={ADDI, 	 12'h002, 5'd12, 5'd19};
		daddrbusout		[154] = 64'h5432105432106436;
		databusin  		[154] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[154] = dontcare;
		gen_opcodeOut	[154] = ADDI << 1;
		registerValOut	[154] = 64'h0000000000000000;
		
		//ADDI X20, X12, #3
		iaddrbusout		[155] = 64'h00000000000419b4;
		//               4    opcode  Imm	  Source    Destination
		instrbusin 		[155] ={ADDI, 	 12'h003, 5'd12, 5'd20};
		daddrbusout		[155] = 64'h5432105432106437;
		databusin  		[155] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[155] = dontcare;
		gen_opcodeOut	[155] = ADDI << 1;
		registerValOut	[155] = 64'h0000000000000000;
		
		//BGE #10 decimal
        iaddrbusout		[156] = 64'h00000000000419b8; 
		//               5     opcode  conditional branch address
		instrbusin 		[156] ={BGE, 19'd0010, 5'b00000};//You need all 32 bits here.
		daddrbusout		[156] = 64'h54323afe88de5c7a;
		databusin  		[156] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
		databusout 		[156] = dontcare;
		gen_opcodeOut	[156] = BGE;
		registerValOut	[156] = 64'h0000000000000000;//The value that is overwritten with a new value.		
		
				
		//==== No Operation to allow the tests to finish ====\\
		//===================================================\\
        //* NOP
        iaddrbusout[hiNn + 1] = 64'h00000000000419BC;
        instrbusin [hiNn + 1] = 64'b0000000000000000000000000000000000000000000000000000000000000000;//being sent into ibus
        daddrbusout[hiNn + 1] = dontcare;
        databusin  [hiNn + 1] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout [hiNn + 1] = dontcare;
        gen_opcodeOut[hiNn + 1] = dontcare;

        
        //* NOP
        iaddrbusout[hiNn + 2] = 64'h00000000000419E4;
        instrbusin [hiNn + 2] = 64'b0000000000000000000000000000000000000000000000000000000000000000;
        daddrbusout[hiNn + 2] = dontcare;
        databusin  [hiNn + 2] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout [hiNn + 2] = dontcare;
        gen_opcodeOut[hiNn + 2] = dontcare;

        
        //* NOP
        iaddrbusout[hiNn + 3] = 64'h00000000000419C0;
        instrbusin [hiNn + 3] = 32'b0000000000000000000000000000000000000000000000000000000000000000;
        daddrbusout[hiNn + 3] = dontcare;
        databusin  [hiNn + 3] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout [hiNn + 3] = dontcare;
        gen_opcodeOut[hiNn + 3] = dontcare;

        
        //* NOP
        iaddrbusout[hiNn + 4] = 64'h00000000000419e8;
        instrbusin [hiNn + 4] = 32'b0000000000000000000000000000000000000000000000000000000000000000;
        daddrbusout[hiNn + 4] = dontcare;
        databusin  [hiNn + 4] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout [hiNn + 4] = dontcare;
        gen_opcodeOut[hiNn + 4] = dontcare;

        
        //* NOP
        iaddrbusout[hiNn + 5] = 64'h00000000000419eC;
        instrbusin [hiNn + 5] = 32'b0000000000000000000000000000000000000000000000000000000000000000;
        daddrbusout[hiNn + 5] = dontcare;
        databusin  [hiNn + 5] = 64'bzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz;
        databusout [hiNn + 5] = dontcare;
        gen_opcodeOut[hiNn + 5] = dontcare;

        
        //==== End of Initializing the Instruction List ====\\
        
        
        // (no. instructions) + (no. loads) + 2*(no. stores) = 1 + 0 + 2*0 = 1
        ntests = tests-1;//this will change based on the number of instructions you have, loads, and stores. (tests-1 is not good, change it)
        
        $timeformat(-9,1,"ns",12);//Initializing the time format
    end// End of initial begin for the instruction list
    
    
    assign databus = clkd ? 64'bz : databusk;
    
    //Change inputs in middle of period (falling edge).
    initial begin//Verifying if the outputs are correct or not.
        //==== Resetting the CPU with Reset as 1 ====\\
        error = 0;
        clkd =1;
        clk=1;
        $display ("Time=%t\n  clk=%b", $realtime, clk);
        databusk = 32'bz;
        
        //extended reset to set up PC MUX
        reset = 1;
        $display ("reset=%b", reset);
        #5
        clk=0;
        clkd=0;
        $display ("Time=%t\n  clk=%b", $realtime, clk);
        #5
        clk=1;
        clkd=1;
        $display ("Time=%t\n  clk=%b", $realtime, clk);
        #5
        clk=0;
        clkd=0;
        $display ("Time=%t\n  clk=%b", $realtime, clk);
        #5
        $display ("Time=%t\n  clk=%b", $realtime, clk);
        //==== Done Resetting the CPU and PC ====\\
        
        //==== Verifying if Outputs are Correct ====\\
    for (k=0; k<= tests; k=k+1) begin/*Begin 1*/
        //k is the number of tests to run. So if I put the parameter tests here, it will run N number of tests.
        clk=1;
        $display ("Time=%t\n  clk=%b", $realtime, clk);
        #2
        clkd=1;
        #3
        $display ("Time=%t\n  clk=%b", $realtime, clk);
        reset = 0;
        $display ("reset=%b", reset);
    
    
        //set load data for 3rd previous instruction
        if (k >=3)
          databusk = databusin[k-3];
    
        //check PC for this instruction
        if (k >= 0) begin
          $display ("  Testing PC for instruction %d", k);
          $display ("    Your iaddrbus =    %b aka %h", iaddrbus, iaddrbus);
          $display ("    Correct iaddrbus = %b aka %h", iaddrbusout[k], iaddrbusout[k]);
          if (iaddrbusout[k] !== iaddrbus) begin
            $display ("    -------------ERROR. A Mismatch Has Occured-----------");
            error = error + 1;
          end
        end
    
        //put next instruction on ibus
        instrbus=instrbusin[k];
        
        $display ("  instrbus=%b %b %b %b aka %h for instruction %d: %s", instrbus[31:21], instrbus[20:10], instrbus[9:5] ,instrbus[4:0], instrbus, k, iname[k]);
    
        //check data address from 3rd previous instruction
        if ( (k >= 3) && (daddrbusout[k-3] !== dontcare) ) begin
          $display ("  Testing data address for instruction %d:", k-3);
          $display ("  %s", iname[k-3]);
          $display ("    Your daddrbus =    %b aka %h", daddrbus, daddrbus);
          $display ("    Correct daddrbus = %b aka %h", daddrbusout[k-3], daddrbusout[k-3]);
          if (daddrbusout[k-3] !== daddrbus) begin
            $display ("    -------------ERROR. A Mismatch Has Occured-----------");
            error = error + 1;
          end
        end
    	
        //check store data from 3rd previous instruction
        if ( (k >= 3) && (databusout[k-3] !== dontcare) ) begin
          $display ("  Testing store data for instruction %d:", k-3);
          $display ("  %s", iname[k-3]);
          $display ("    Your databus =     %b aka %h", databus, databus);
          $display ("    Correct databus =  %b aka %h", databusout[k-3], databusout[k-3]);
          if (databusout[k-3] !== databus) begin
            $display ("    -------------ERROR. A Mismatch Has Occured-----------");
            error = error + 1;
          end
        end
    
//		//Opcodes work, and do not need to be checked anymore.
//    	//Checking the Opcode for the instruction.
//    	if ((k >= 1) && (gen_opcodeOut[k] !== dontcare))begin
//    		$display ("  Testing Extended Opcode for Instruction %d:", k);
//    	    $display ("  %s", iname[k]);
//    	    $display ("    Your Opcode =    %b aka %h", gen_opcode, gen_opcode);
//    	    $display ("    Correct Opcode = %b aka %h", gen_opcodeOut[k-1], gen_opcodeOut[k-1]);
//    	    if (gen_opcodeOut[k-1] !== gen_opcode) begin
//    	    	$display ("    -------------ERROR. A Mismatch Has Occured-----------");
//				error = error + 1;
//			end
//    	end
    	
    	//Registers are now fine and do not need to be checked anymore.
    	//Testing abus from register file. //I am checking too early, i need to check 5ns later because the data has not been written to the regfile.
    	//For example, test 5, at 75ns the register should contain 0000 0200. But I am checking the bbus at 70ns, that is too early to check it.
//    	if ((k >= 0) && (registerValOut[k] !== dontcare))begin
//    		$display ("  Testing the value at the rd in the RegFile when Instruction %d enters the pipeline	%d:", k, k);
//    		$display ("  %s", iname[k]);
//			$display ("    Your register value =    %b aka %h", registerVal, registerVal);
//			$display ("    Correct register value = %b aka %h", registerValOut[k], registerValOut[k]);
//    		if (registerValOut[k] !== registerVal) begin
//				$display ("    -------------ERROR. A Mismatch Has Occured-----------");
//				error = error + 1;
//			end
//    	end

    
        clk = 0;
        $display ("Time=%t\n  clk=%b", $realtime, clk);
        #2
        clkd = 0;
        #3
        $display ("Time=%t\n  clk=%b", $realtime, clk);
      end/*End 1*/
      //==== End of Verifying If Outputs are Correct ====\\
    
      if ( error !== 0) begin
        $display("--------- SIMULATION UNSUCCESFUL - MISMATCHES HAVE OCCURED ----------");
        $display(" No. Of Errors = %d", error);
      end
      if ( error == 0)
        $display("---------YOU DID IT!! SIMULATION SUCCESFULLY FINISHED----------");
    end//End of initial begin for checking if the outputs are correct or not.
    
    
    
endmodule
