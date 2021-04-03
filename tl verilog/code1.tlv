\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/RISC-V_MYTH_Workshop
   
   m4_include_lib(['https://raw.githubusercontent.com/sajalgoyal/new/main/macro.tlv?token=AEMC5ZEGXNCT43GWI2BZEILAIMTBQ'])
\TLV imem_test(@_stage)
   // Instruction Memory containing program defined by m4_asm(...) instantiations.
   @_stage
      \SV_plus
         // The program in an instruction memory.
         logic [31:0] instrs [0:M4_NUM_INSTRS-1];
         assign instrs = '{
            m4_instr0['']m4_forloop(['m4_instr_ind'], 1, M4_NUM_INSTRS, [', m4_echo(['m4_instr']m4_instr_ind)'])
         };
      /M4_IMEM_HIER
         $instr[31:0] = *instrs\[#imem\];
      ?$imem_rd_en
         $imem_rd_data1[31:0] = /imem[$imem_rd_addr]$instr;
         $imem_rd_data2[31:0] = /imem[$imem_rd_addr + 1'b1]$instr;
         
\TLV rf_test(@_rd, @_wr)
   // Reg File
   @_wr
      /xreg[31:0]
         $wr_supinstr1 = |cpu$rf_wr_en_supinstr1 && (|cpu$rf_wr_index_supinstr1 != 5'b0) && (|cpu$rf_wr_index_supinstr1 == #xreg);
         $wr_supinstr2 = |cpu$rf_wr_en_supinstr2 && (|cpu$rf_wr_index_supinstr2 != 5'b0) && (|cpu$rf_wr_index_supinstr2 == #xreg);
         $value[31:0] = |cpu$reset       ?   #xreg                 :
                        $wr_supinstr1        ?   |cpu$rf_wr_data_supinstr1 :
                        $wr_supinstr2        ?   |cpu$rf_wr_data_supinstr2 :
                                             $RETAIN;
   @_rd
      ?$rf_rd_en_rs1_supinstr1
         $rf_rd_data_rs1_supinstr1[31:0] = /xreg[$rf_rd_index_rs1_supinstr1]>>m4_stage_eval(@_wr - @_rd + 1)$value;
      ?$rf_rd_en_rs1_supinstr2
         $rf_rd_data_rs1_supinstr2[31:0] = /xreg[$rf_rd_index_rs1_supinstr2]>>m4_stage_eval(@_wr - @_rd + 1)$value;
      ?$rf_rd_en_rs2_supinstr1
         $rf_rd_data_rs2_supinstr1[31:0] = /xreg[$rf_rd_index_rs2_supinstr1]>>m4_stage_eval(@_wr - @_rd + 1)$value;
      ?$rf_rd_en_rs2_supinstr2
         $rf_rd_data_rs2_supinstr2[31:0] = /xreg[$rf_rd_index_rs2_supinstr2]>>m4_stage_eval(@_wr - @_rd + 1)$value;
      //`BOGUS_USE($rf_rd_data01 $rf_rd_data02 $rf_rd_data11 $rf_rd_data12) 

\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   
   m4_asm(ADD, r10, r0, r0)             // Initialize r10 to 0.
   m4_asm(ADDI, r11, r0, 1011)          //  Initialize r11 to 11.
   
   m4_asm(ADDI, r12, r0, 1100)        //  Initialize r12 to 12.
   m4_asm(ADDI, r13, r0, 1101)        //  Initialize r13 (a0) to 13.
   
   m4_asm(ADD, r14, r10, r11)            // r14 = r10 + r11
   m4_asm(ADD, r15, r12, r13)           //   r15 = r12 + r13
   

   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)
   
   |cpu
      @0
         $reset = *reset;
         
         //MODIFIED NEXT PC LOGIC FOR INCLUDING BRANCH INSTRCUTIONS
         $pc[31:0] = >>1$reset ? 32'b0 :
                      /sup_instr[0]>>1$taken_branch ? | /sup_instr[0]>>1$br_target_pc :
                      /sup_instr[1]>>1$taken_branch ? | /sup_instr[1]>>1$br_target_pc :
                     >>1$pc + 32'd8; //if the previous cycle reset =1 then pc = 0 else pc = pc + 4
         //FETCH
      
      @1
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];
         $imem_rd_en = !$reset;
         /sup_instr[1:0]
            $instr[31:0] = (#sup_instr == 0) ? /top|cpu$imem_rd_data1 : /top|cpu$imem_rd_data2;  //////DOUBT, is it /sup_instr[0]$instr = $imem_rd_data1;
         
      /sup_instr[1:0]
         //INSTRUCTION TYPES DECODE         
         @1
            $is_u_instr = $instr[6:2] ==? 5'b0x101;

            $is_s_instr = $instr[6:2] ==? 5'b0100x;

            $is_r_instr = $instr[6:2] ==? 5'b01011 ||
                          $instr[6:2] ==? 5'b011x0 ||
                          $instr[6:2] ==? 5'b10100;

            $is_j_instr = $instr[6:2] ==? 5'b11011;

            $is_i_instr = $instr[6:2] ==? 5'b0000x ||
                          $instr[6:2] ==? 5'b001x0 ||
                          $instr[6:2] ==? 5'b11001;

            $is_b_instr = $instr[6:2] ==? 5'b11000;

            //INSTRUCTION IMMEDIATE DECODE
            $imm[31:0] = $is_i_instr ? {{21{$instr[31]}}, $instr[30:20]} :
                         $is_s_instr ? {{21{$instr[31]}}, $instr[30:25], $instr[11:7]} :
                         $is_b_instr ? {{20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0} :
                         $is_u_instr ? {$instr[31:12], 12'b0} :
                         $is_j_instr ? {{12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0} :
                                       32'b0;



            //INSTRUCTION DECODE
            $opcode[6:0] = $instr[6:0];


            //INSTRUCTION FIELD DECODE
            $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
            ?$rs2_valid
               $rs2[4:0] = $instr[24:20];

            $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
            ?$rs1_valid
               $rs1[4:0] = $instr[19:15];

            $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
            ?$funct3_valid
               $funct3[2:0] = $instr[14:12];

            $funct7_valid = $is_r_instr ;
            ?$funct7_valid
               $funct7[6:0] = $instr[31:25];

            $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
            ?$rd_valid
               $rd[4:0] = $instr[11:7];
            //INSTRUCTION DECODE
            $dec_bits[10:0] = {$funct7[5], $funct3, $opcode};
            $is_beq = $dec_bits ==? 11'bx_000_1100011;
            $is_bne = $dec_bits ==? 11'bx_001_1100011;
            $is_blt = $dec_bits ==? 11'bx_100_1100011;
            $is_bge = $dec_bits ==? 11'bx_101_1100011;
            $is_bltu = $dec_bits ==? 11'bx_110_1100011;
            $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
            $is_addi = $dec_bits ==? 11'bx_000_0010011;
            $is_add = $dec_bits ==? 11'b0_000_0110011;

            `BOGUS_USE ($is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu $is_addi $is_add)
      
      @1
         // supinstr means different instr pipes in superscalar contex.
         $rf_rd_en_rs1_supinstr1 = /sup_instr[0]$rs1_valid;   //since we cannot check the validity on the hierarchy, so we assign it to new variable
         $rf_rd_en_rs2_supinstr1 = /sup_instr[0]$rs2_valid;
         $rf_rd_index_rs1_supinstr1[4:0] = /sup_instr[0]$rs1;
         $rf_rd_index_rs2_supinstr1[4:0] = /sup_instr[0]$rs2;
         
         $rf_rd_en_rs1_supinstr2 = /sup_instr[1]$rs1_valid;
         $rf_rd_en_rs2_supinstr2 = /sup_instr[1]$rs2_valid;
         $rf_rd_index_rs1_supinstr2[4:0] = /sup_instr[1]$rs1;
         $rf_rd_index_rs2_supinstr2[4:0] = /sup_instr[1]$rs2;
         
         /sup_instr[1:0]
            $src1_value[31:0] = (#sup_instr == 0) ? /top|cpu$rf_rd_data_rs1_supinstr1[31:0] : /top|cpu$rf_rd_data_rs1_supinstr2[31:0];
            $src2_value[31:0] = (#sup_instr == 0) ? /top|cpu$rf_rd_data_rs2_supinstr1[31:0] : /top|cpu$rf_rd_data_rs2_supinstr2[31:0];

      @1
         /sup_instr[1:0]
            $result[31:0] = $is_addi ? $src1_value + $imm :
                            $is_add ? $src1_value + $src2_value :
                            32'bx ;

            //REGISTER FILE WRITE
         $rf_wr_en_supinstr1 = /sup_instr[0]$rd_valid && /sup_instr[0]$rd != 5'b0;
         $rf_wr_index_supinstr1[4:0] = /sup_instr[0]$rd;
         $rf_wr_data_supinstr1[31:0] = /sup_instr[0]$result;
         
         $rf_wr_en_supinstr2 = /sup_instr[1]$rd_valid && /sup_instr[1]$rd != 5'b0;
         $rf_wr_index_supinstr2[4:0] = /sup_instr[1]$rd;
         $rf_wr_data_supinstr2[31:0] = /sup_instr[1]$result;
         
         /sup_instr[1:0]
            //BRANCH INSTRUCTIONS
            $taken_branch = $is_beq ? ($src1_value == $src2_value):
                            $is_bne ? ($src1_value != $src2_value):
                            $is_blt ? (($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31])):
                            $is_bge ? (($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31])):
                            $is_bltu ? ($src1_value < $src2_value):
                            $is_bgeu ? ($src1_value >= $src2_value):
                                       1'b0;
            `BOGUS_USE($taken_branch)
            
            //BRANCH INSTRUCTIONS 2
            $br_target_pc[31:0] = /top|cpu$pc +$imm;         //TESTBENCH
         *passed = |cpu/xreg[14]>>5$value == (0+11) && |cpu/xreg[15]>>5$value == (12+13) ;
         

   *failed = 1'b0;
   

   |cpu
      m4+imem_test(@1)    // Args: (read stage)
      m4+rf_test(@1, @1)  // Args: (read stage, write stage) - if equal, no register bypass is required//m4+dmem(@4)    // Args: (read/write stage)
   
   m4+cpu_viz(@1)    // For visualisation, argument should be at least equal to the last stage of CPU logic
                       // @4 would work for all labs
\SV
   endmodule
