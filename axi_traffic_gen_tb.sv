`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/02/2024 11:48:24 PM
// Design Name: 
// Module Name: axi_traffic_gen_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;

module axi_traffic_gen_tb();
//
xil_axi_uint slv_mem_agent_verbosity = 0;
design_1_axi_vip_0_0_slv_mem_t slv_mem_agent;

//
reg aclk;
reg aresetn;
wire aresetn_out;
//
// singlex2, 16, singlex3, 16, 16, singlex2

`define ADDR_W 32
`define DATA_W 64

reg  [`ADDR_W-1:0] u_addr [0:9] = 
{
    'h10000000, //0
    'h10000040, //0
    'h10000080, //15
    'h10000C00, //0
    'h10000C40, //0
    'h10000C80, //0
    'h10000CC0, //15
    'h100010C0, //15
    'h10001500, //0
    'h10001540  //0
};

reg  [3:0]  u_b_len [0:9] =
{
'h0,
'h0,
'd15,
'h0,
'h0,
'h0,
'd15,
'd15,
'h0,
'h0
};

bit  [`DATA_W-1:0] u_data_in [0:54] =
{
'hF8F4F2F1,
'h87654321,
'h0000000A,'h000000BA,'h00000CBA,'h0000DCBA,'h000EDCBA,'h00FEDCBA,'h0AFEDCBA,'hBAFEDCBA,'h0BAFEDCB,'h00BAFEDC,'h000BAFED,'h0000BAFE,'h00000BAF,'h000000BA,'h0000000B,'h00000000,
'h12345678,
'h08060402,
'h07050301,
'h1000000A,'h200000BA,'h30000CBA,'h4000DCBA,'h500EDCBA,'h60FEDCBA,'h7AFEDCBA,'h8AFEDCBA,'h9BAFEDCB,'hA0BAFEDC,'hB00BAFED,'hC000BAFE,'hD0000BAF,'hE00000BA,'hF000000B,'h10000000,
'h00000000,'h11111111,'h22222222,'h33333333,'h44444444,'h55555555,'h66666666,'h77777777,'h88888888,'h99999999,'hAAAAAAAA,'hBBBBBBBB,'hCCCCCCCC,'hDDDDDDDD,'hEEEEEEEE,'hFFFFFFFF,
'hBADCAFEE,
'hDEADBEEF
};

bit  [`DATA_W-1:0] u_data_out [0:54];

reg   [7:0] u_pix_len [0:9] =
{
'b11111111,
'b11111111,
'b11111111,
'b11111111,
'b11111111,
'b11111111,
'b00001111,
'b11110000,
'b00000001,
'b11100000
};

reg         user_start;

wire        user_free;
wire        user_stall_data;
wire [1:0]  user_status;
//

reg  [`ADDR_W-1:0] user_addr_in;
reg  [3:0]  user_burst_len_in;
bit  [`DATA_W-1:0] user_data_in;
bit  [`DATA_W-1:0] user_data_out;
reg         user_data_out_en;
reg  [7:0]  user_pixels_1_2;
int         running_index;
//
reg axi_ready;
//
reg user_w_r;
//
reg compare_w_r_arrays;
integer cmp_it;

integer file, i;

initial
begin
    axi_ready = 0;
    slv_mem_agent = new("slave vip agent",d1w0.design_1_i.axi_vip_0.inst.IF);
    slv_mem_agent.set_agent_tag("Slave VIP");
    slv_mem_agent.set_verbosity(slv_mem_agent_verbosity);
    slv_mem_agent.start_slave();
    //slv_mem_agent.mem_model.pre_load_mem("compile.sh", 0);
    slv_mem_agent.mem_model.pre_load_mem("vip_mem_out.mem", 0);
    //slv_mem_agent.mem_model.set_mem_depth(1024);

    axi_ready = 1;
end

initial
begin
    aclk = 0;
    aresetn = 0;
    user_addr_in = 'h0;
    user_burst_len_in = 'h0;
    user_data_in = 'h0;
    user_pixels_1_2 = 'h0;
    user_start = 'h0;
    user_w_r = 'h0;
    compare_w_r_arrays = 0;
end

always
begin
    #8ns aclk = ~aclk;
end

initial
begin
    wait(axi_ready);
    aresetn = 1;
    #5us;
    
    #10us;
    
    @(posedge aclk);
    user_start      = 1'd0;
    running_index   = 'd0;
    
    //#5ms;
    
    for(int i = 0; i < 10; i++)
    begin
        wait(user_free);
        @(posedge aclk);
    
        user_addr_in        = u_addr[i];
        user_burst_len_in   = u_b_len[i];
        user_pixels_1_2     = u_pix_len[0]; //u_pix_len[i];
        user_data_in        = u_data_in[running_index];
        @(posedge aclk);
        user_start          = 1'd1;
        running_index++;
        
        @(posedge aclk);
        wait(~user_free);
        
        if(u_pix_len[0] == 'd0)
        begin
            continue;
        end
        
        else
        begin
            for(int b = 0; b < u_b_len[i]; b++)
            begin
           
                //running_index++;
                @(negedge user_stall_data);
                @(posedge aclk);
                
                //@(posedge aclk_out);
                user_data_in = u_data_in[running_index];
                running_index++;
            end
        end
        user_start          = 1'd0;
    end
    
    //
    wait(user_free);
    #10us;
   
    running_index   = 'd0;
    user_w_r = 'h1;
    
    for(int i = 0; i < 10; i++)
    begin
        wait(user_free);
        @(posedge aclk);
        
        user_addr_in        = u_addr[i];
        user_burst_len_in   = u_b_len[i];
        //user_pixels_1_2     = u_pix_len[i];
        //user_data_in        = u_data_in[running_index];
        user_start          = 1'd1;
        
        @(posedge aclk);
        
        for(int b = 0; b < u_b_len[i]+1; b++)
        begin
            //@(posedge user_data_out_en);
            if(~user_data_out_en) wait(user_data_out_en);
            @(posedge aclk);
            if(user_stall_data) wait(~user_stall_data);
            u_data_out[running_index] = user_data_out;
            running_index++;
        end
        
        user_start          = 1'd0;
    end
    
    #10us;
    running_index   = 'd0;

    for(cmp_it = 0; cmp_it < 10; cmp_it++)
    begin
    
        longint current_addr = u_addr[i];
    
        for(int i = 0; i < u_b_len[cmp_it]+1; i++)
        begin
        
            current_addr += ((`DATA_W)*i);
        
            if(u_data_in[cmp_it] == u_data_out[cmp_it])
            begin
                $error("ADDRESS: %X, BURST LENGTH: %d, DATA WRITTEN: %X, DATA READ: %X, NOT EQUAL", current_addr, u_b_len[cmp_it]+1, u_data_in[running_index], u_data_out[running_index]);
                break;
            end
            
            else
            begin
                $display("ADDRESS: %X, BURST LENGTH: %d, DATA WRITTEN: %X, DATA READ: %X, NOT EQUAL", current_addr, u_b_len[cmp_it]+1, u_data_in[running_index], u_data_out[running_index]);
            end
            
            running_index++;
         end
    end
    
    $finish;
end
    
design_1_wrapper d1w0(
    .aclk_0(aclk),
    .aresetn_0(aresetn),
    .user_addr_in_0(user_addr_in),
    .user_burst_len_in_0(user_burst_len_in),
    .user_data_in_0(user_data_in),
    .user_data_out_0(user_data_out),
    .user_data_out_en_0(user_data_out_en),
    .user_data_strb_0(user_pixels_1_2),
    .user_free_0(user_free),
    .user_stall_data_0(user_stall_data),
    .user_start_0(user_start),
    .user_status_0(user_status),
    .user_w_r_0(user_w_r)
    );

endmodule