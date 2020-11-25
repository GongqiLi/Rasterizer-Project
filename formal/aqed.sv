
// ------------------------------------------------------------------
//   Design Unit:    AQED_rtl
// ------------------------------------------------------------------

module aqed (clk, rst, exec, tri_R10S, color_R10U, validTri_R10H, screen_RnnnnS, subSample_RnnnnU);
   parameter SIGFIG = 24; // Bits in color and position.
   parameter RADIX = 10; // Fraction bits in color and position
   parameter VERTS = 3; // Maximum Vertices in triangle
   parameter AXIS = 3; // Number of axis foreach vertex 3 is (x,y,z).
   parameter COLORS = 3; // Number of color channels



  //BMC Controlled Inputs
   input logic clk;
   input logic rst;
   input logic exec; // If 1'b1, indicates either: (a) the current input should be sent as the original input to the accelerator on that cycle; (b) If the original input has already been sent, send the duplicate. 
   input logic signed [SIGFIG-1:0] tri_R10S[VERTS-1:0][AXIS-1:0]; // Tri Position 
   input logic unsigned [SIGFIG-1:0] color_R10U[COLORS-1:0];
   input logic validTri_R10H; //Valid Data for Operation
   input logic signed [SIGFIG-1:0] screen_RnnnnS[1:0]; // Screen Dimensions
   input logic [3:0] subSample_RnnnnU; // SubSample_Interval



  //Signals modified by A-QED before fed to rast
   logic unsigned [SIGFIG-1:0] color_R10U_out[COLORS-1:0];
   logic signed [SIGFIG-1:0] screen_RnnnnS_out[1:0]; 
   logic signed [SIGFIG-1:0] tri_R10S_out[VERTS-1:0][AXIS-1:0];


   
  //Output Signals from rast to be analyzed by A-QED
   logic halt_RnnnnL;
   logic signed [SIGFIG-1:0] hit_R18S[AXIS-1:0]; // Hit Location
   logic unsigned [SIGFIG-1:0] color_R18U[COLORS-1:0]; // Color of Tri
   logic hit_valid_R18H;      



// ------------------------------------------------------------------   
//Signals to create A-QED  



  // Signals to send original and duplicate inputs  
   logic signed [SIGFIG-1:0] screen_RnnnnS_orig[1:0]; // stores the value of screen_RnnnnS marked as original
   logic signed [SIGFIG-1:0] tri_R10S_orig[VERTS-1:0][AXIS-1:0]; // stores the value of tri_R10S marked as original 
   logic unsigned [SIGFIG-1:0] color_R10U_orig[COLORS-1:0]; // stores the value of color_R10U marked as original 
   logic signed [31:0] orig_val; // stores the position of the original input in the sequence
   logic signed [31:0] dup_val; // stores the position of the duplicate input in the sequence
   logic orig_issued; // remains high once the original input is issued to prevent A-QED from sending another original
   logic dup_issued; // remains high once the duplicate input is issued to prevent A-QED from sending another duplicate
   logic issue_orig; // 1'b1 if original input is to be fed to the accelerator
   logic issue_dup; // 1'b1 if duplicate input is to be fed to the accelerator
   logic issue_other; // 1'b1 if any input other than the original and duplicate input is to be fed to the accelerator
   logic [31:0]in_count; // keeps track of the sequence number of the input being fed to the accelerator



  // Signals to analyze rast outputs  
   logic dup_done; // 1'b1 if duplicate output has been produced by the accelerator
   logic qed_check; // 1'b1 if the orignal and duplicate outputs are the same
   logic signed [SIGFIG-1:0] hit_R18S_orig_sequence[AXIS-1:0][32]; // stores the value of output subsequence of hit_R18S generated from the original input 
   logic unsigned [SIGFIG-1:0] color_R18U_orig_sequence[COLORS-1:0][32]; // stores the output subsequence of color_R18U generated from the original input      
   logic signed [SIGFIG-1:0] hit_R18S_dup_sequence[AXIS-1:0][32]; // stores the output subsequence of hit_R18S generated from the duplicate input
   logic unsigned [SIGFIG-1:0] color_R18U_dup_sequence[COLORS-1:0][32]; // stores the value of output subsequence of color_R18U generated from the duplicate input      
   logic signed [31:0] out_sequence_count; // keeps track of the sequence number of the output being produced from the accelerator
   logic [4:0] orig_array_index; // used to index into the array for the original output subsequence
   logic [4:0] dup_array_index; // used to index into the array for the duplicate output subsequence
   logic halt_RnnnnL_d5; // halt_RnnnnL delayed by 5 cycles
   logic halt_RnnnnL_d6; // halt_RnnnnL delayed by 6 cycles
// ------------------------------------------------------------------   



  /*
     Write the conditions for which issue_orig, issue_dup and issue_other will go high
     To feed rast with a valid input, the input-ready signal and input-valid signal need to be high i.e. the accelerator is ready to accept an input and the input being sent is a valid one.
     issue_dup can never go high before issue_orig; issue_other can go high only when issue_other can go high only when issue_orig and issue_dup are not high.   
     Signals to use: exec, validTri_R10H, orig_issued, dup_issued and halt_RnnnnL
  */     
   assign issue_orig = exec & ~orig_issued & validTri_R10H & halt_RnnnnL; 
   assign issue_other = ~issue_dup & ~issue_orig & validTri_R10H & halt_RnnnnL;
   assign issue_dup = exec & orig_issued & ~dup_issued & validTri_R10H & halt_RnnnnL;



// ------------------------------------------------------------------   


  /*
     Write the conditions for which orig_issued and dup_issued will go high
     Note once orig_issued or dup_issued go high, they remain high henceforth. 
     Signals to use: issue_orig, issue_dup
  */     
   always @(posedge clk)
      begin
         if (rst) begin
            orig_issued <= 'b0;
	    dup_issued <= 'b0;
         end else if (issue_orig) begin
            orig_issued <= 'b1;
         end else if (issue_dup) begin
            dup_issued <= 'b1;
         end 
 
      end 

// ------------------------------------------------------------------   


            //       The yellow squares mean that those properties are unprocessed.
      // The blue dot means that you are using an assumption in the BMC.

 // Interesting. It should give a counter example. Try writing assertions to check the A-QED module. Some properties to check are is the dup_done ever 1, is original and duplicate inputs ever issued, etc
   // The tcl script is written to execute only the assert_qed_match assertion. To run any other assertion of your own, right click on that assertion in the property table and click on prove property. If it shows a lightning bolt, then the BMC is running for that assertion. Have you tried that

     
      // You can look at what the hash tree should do in the rasterizer gold.c. The rasterizer including every module inside it should have the same output for the same input. Any exception to that would be considered a bug. So, you need to fix the hash module if you think that it can't pass.
      // For any counter example that JasperGold gives, you want to keep clicking "why" until you find the root-cause of the counter example. Eventually, the cause of the counter-example will either trace back to the rasterizer module or to the A-QED module. If it traces back to the A-QED module, then you know there is a bug there.
      
      // So, a hack of checking the A-QED module is to see if its keeping track of the original and duplicate inputs i.e., the in_count, orig_val and dup_val are being updated properly and similarly on the output side. If u wanna do it by debugging the traces, then yes. Try to see which signals are different in the fanin cone of the original and the duplicate output
      // valid_R18H might be buggy because you are capturing the output sequence correctly (while halt_d5 is low). 
      
      // 2. The rasterizer including every module in it should always produce the same output for the same input. It is safe to consider anything otherwise as bug.

      /*
     Store original_input values and store the sequence number of the original and duplicate inputs
     Signals to use: tri_R10S, color_R10U, screen_RnnnnS
  */     
   always @(posedge clk)
      begin	
        if (rst) begin
           tri_R10S_orig <= '{default:0};
	        color_R10U_orig <= '{default:0}; 
           screen_RnnnnS_orig <= '{default:0};
           orig_val <= 32'h0000_FFFF;
           in_count <= 'b0;
	        dup_val <= 32'h0000_FFFF;
        end else begin 
            if (issue_orig) begin
               /*
               Code goes here
                  */
               tri_R10S_orig <= tri_R10S;
               color_R10U_orig <= color_R10U;
               screen_RnnnnS_orig <= screen_RnnnnS;
               orig_val <= in_count;
               in_count <= in_count + 1;
            end if (issue_dup) begin
                  /*
               Code goes here
                  */
               dup_val <= in_count;
               in_count <= in_count + 1;
            end if (issue_other) begin
               in_count <= in_count + 1;
            end
         end 
     end

// ------------------------------------------------------------------   



  /*
     Channel input from the BMC directly to *_out signals if duplicate is not issued, otherwise send the value stored in the *_orig 
     Signals to use: issue_dup, tri_R10S_orig, color_R10U_orig, screen_RnnnnS_orig, tri_R10S, color_R10U, screen_RnnnnS 
  */     
   assign tri_R10S_out = issue_dup ? tri_R10S_orig :tri_R10S; /*Fill*/
   assign color_R10U_out = issue_dup ? color_R10U_orig :color_R10U; /*Fill*/
   assign screen_RnnnnS_out = issue_dup ? screen_RnnnnS_orig :screen_RnnnnS; /*Fill*/

// ------------------------------------------------------------------   



  /*
     Write constraints for input signals. SubSample_RnnnnU is a onehot signal and also needs to be held constant across entire run. 
     If the accelerator is not ready to take in inputs, the host needs to send bubbles by keeping validTri_R10H low.
     Signals to use: issue_dup, tri_R10S_orig, color_R10U_orig, screen_RnnnnS_orig, tri_R10S, color_R10U, screen_RnnnnS 
  */     
        // signal list should be halt_RnnnnL, validTri_R10H, and SubSample_RnnnnU
c: assume property(@(posedge clk)  

   ($onehot(subSample_RnnnnU) && $stable(subSample_RnnnnU))   /*
	Code goes here
       */
       
 );

// ------------------------------------------------------------------   
d: assume property(@(posedge clk)
     ((~halt_RnnnnL) |-> (~validTri_R10H))
);



rast DUT(tri_R10S_out, color_R10U_out, validTri_R10H, screen_RnnnnS_out, subSample_RnnnnU, clk, rst, halt_RnnnnL, hit_R18S, color_R18U, hit_valid_R18H);

c_screen: assume property(@(posedge clk) ~(|DUT.bbox.invalidate_R10H)); // We only want to send triangles that fit within the screen

// you're creating flip flops for the halt signal. The goal is to create 2 signals: halt delayed by 5 cycles, and halt delayed by 6 cycles. So you'll have halt/halt_delayed as the D/Q of the flip flops. The enable should be 1 in this case. 

  /*
     Create the halt_RnnnnL_d5 and halt_RnnnnL_d6 signals.
     Hint: Use the dff modules 
     Signals to use: halt_RnnnnL, clk, rst 
  */     
       /*
	Code goes here
       */
   dff #(
         .WIDTH(1),
         .PIPE_DEPTH(5),
         .RETIME_STATUS(0) // No retime
     )
     d_halt_5
     (
         .clk    (clk                    ),
         .reset  (rst                    ),
         .en     (1'b1            ),
         .in     (halt_RnnnnL   ),
         .out    (halt_RnnnnL_d5          )
     );
   dff #(
      .WIDTH(1),
      .PIPE_DEPTH(6),
      .RETIME_STATUS(0) // No retime
  )
  d_halt_6
  (
      .clk    (clk                    ),
      .reset  (rst                    ),
      .en     (1'b1            ),
      .in     (halt_RnnnnL   ),
      .out    (halt_RnnnnL_d6          )
   );
// ------------------------------------------------------------------   



  /*
     Update out_sequence_count. out_sequence_count increments when an entire output subsequence corresponding to an input has been generated. 
     Signals to use: halt_RnnnnL_d5, halt_RnnnnL_d6 
  */      
   //  We detect the end of an output subsequence by the posedge of halt_d5. 
  // Now, halt_RnnnnL starts from 0 and goes it 1 once the rasterizer enters wait state. 
  // So, we want to skip this first posedge of halt_d5. So, out_sequence_count needs to start from a negative number hence the sign. 
  // You can obviously get rid of the sign and represent the number in binary but thats up to you.

   always @(posedge clk)
     begin
        if (rst) begin
           out_sequence_count <= -32'h0000_0001;
	     end else if(halt_RnnnnL_d5 & ~halt_RnnnnL_d6)
           out_sequence_count <= out_sequence_count + 1;
     end 

// ------------------------------------------------------------------   



  /*
     Store the output subsequences corresponding to the original and the duplicate inputs. Update dup_done when duplicate signal is read. 
     Note that an output needs to be valid to be analyzed. 
     SOME Signals to use: hit_R18S, color_R18U, orig_array_index, dup_array_index, out_sequence_count, halt_RnnnnL_d5 (Note: what else do you need?)   
  */     
   always @(posedge clk)
     begin
        if (rst) begin
	         hit_R18S_orig_sequence <= '{default:0}; 
   	      color_R18U_orig_sequence <= '{default:0};
	         hit_R18S_dup_sequence <= '{default:0}; 
   	      color_R18U_dup_sequence <= '{default:0};
	         orig_array_index <= 'b0;
	         dup_array_index <= 'b0;
	         dup_done <= 'b0;
        end else if ((out_sequence_count == orig_val) && hit_valid_R18H && (~halt_RnnnnL_d5)/*Fill*/) begin
            //hit_R18S_orig_sequence <= hit_R18S;
            hit_R18S_orig_sequence[0][orig_array_index] <= hit_R18S[0];
            hit_R18S_orig_sequence[1][orig_array_index] <= hit_R18S[1];
            hit_R18S_orig_sequence[2][orig_array_index] <= hit_R18S[2];
            color_R18U_orig_sequence[0][orig_array_index] <= color_R18U[0];
            color_R18U_orig_sequence[1][orig_array_index] <= color_R18U[1];
            color_R18U_orig_sequence[2][orig_array_index] <= color_R18U[2];
            orig_array_index <= orig_array_index + 1;
        end else if ((out_sequence_count == dup_val) && hit_valid_R18H && (~halt_RnnnnL_d5)/*Fill*/) begin
            //hit_R18S_dup_sequence <= hit_R18S;
            hit_R18S_dup_sequence[0][dup_array_index] <= hit_R18S[0];
            hit_R18S_dup_sequence[1][dup_array_index] <= hit_R18S[1];
            hit_R18S_dup_sequence[2][dup_array_index] <= hit_R18S[2];
            color_R18U_dup_sequence[0][dup_array_index] <= color_R18U[0];
            color_R18U_dup_sequence[1][dup_array_index] <= color_R18U[1];
            color_R18U_dup_sequence[2][dup_array_index] <= color_R18U[2];
            dup_array_index  <= dup_array_index + 1;
        end 
        else if (out_sequence_count > dup_val)
            dup_done <= 1'b1;
     end 
// ------------------------------------------------------------------   

 
 
  /*
     Write conditions to update qed_check.
     Signals to use: hit_R18S_orig_sequence, color_R18U_orig_sequence, hit_R18S_dup_sequence, color_R18U_dup_sequence  
  */     
   assign qed_check = (hit_R18S_orig_sequence == hit_R18S_dup_sequence) && (color_R18U_orig_sequence == color_R18U_dup_sequence);
// ------------------------------------------------------------------   


  /*
     Write the final qed_check property
     Signals to use: dup_done, qed_check
  */     

   assert property( @(posedge clk) ~dup_done);


      // if there is a dup_done signal, then we need to check if  qed_check is 1
   assert_qed_match : assert property (
       @(posedge clk)
          (dup_done |-> qed_check) );
// ------------------------------------------------------------------   

 
/*   p1 : cover property (
       @(posedge clk)
          out_sequence_count == orig_val  );

   p2 : cover property (
       @(posedge clk)
          dup_issued  );
*/
    


              
endmodule


