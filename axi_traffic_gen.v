
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07/02/2024 12:15:09 AM
// Design Name:
// Module Name: nnuti_axi3_traffic_generator
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

/*

// Things I would like to add:
- parameters for WRITE and READ to generate logic...
- method to exit to IDLE if slave doesn't finish the write or read... (leaves us idle for X or more clock cycles)
- parameter to change IP to handle AXI3 or AXI4 parameters

AXI3
- no QoS
- 16 beats in a burst max
AXI4
- adds "fixed-length bursts"
- yes QoS
- supports atomic (ex: read-modify-write transactions...) complete without interference
- supports AXI4-lite and AXI4-stream
- 256 beats in a burst max
*/

module axi_traffic_gen #(
    parameter ADDR_W=32,
    parameter DATA_W=64
)
(
  /**************** Write Address Channel Signals ****************/
  output reg [ADDR_W-1:0]              m_axi_awaddr, // address (done)
  output reg [3-1:0]                   m_axi_awprot = 3'b000, // protection - privilege and securit level of transaction
  output reg                           m_axi_awvalid, // (done)
  input  wire                          m_axi_awready, // (done)
  output reg [3-1:0]                   m_axi_awsize = $clog2(DATA_W/8), //3'b011, // burst size - size of each transfer in the burst 3'b011 for 8 bytes
  output reg [2-1:0]                   m_axi_awburst = 2'b01, // fixed burst = 00, incremental = 01, wrapped burst = 10
  output reg [4-1:0]                   m_axi_awcache = 4'b0000, //4'b0011, // cache type - how transaction interacts with caches
  output reg [4-1:0]                   m_axi_awlen, // number of data transfers in the burst (0-255) (done)
  output reg [1-1:0]                   m_axi_awlock = 1'b0, // lock type - indicates if transaction is part of locked sequence
  output reg [4-1:0]                   m_axi_awqos = 4'b0000, // quality of service - transaction indication of priority level
  output reg [4-1:0]                   m_axi_awregion = 4'b0000, // region identifier - identifies targetted region
  /**************** Write Data Channel Signals ****************/
  output reg [DATA_W-1:0]              m_axi_wdata, // (done)
  output reg [DATA_W/8-1:0]            m_axi_wstrb, // (done)
  output reg                           m_axi_wvalid, // set to 1 when data is ready to be transferred (done)
  input  wire                          m_axi_wready, // (done)
  output reg                           m_axi_wlast, // if awlen=0 then set wlast (done)
  /**************** Write Response Channel Signals ****************/
  input  wire [2-1:0]                  m_axi_bresp, // (done) write response - status of the write transaction (00 = okay, 01 = exokay, 10 = slverr, 11 = decerr)
  input  wire                          m_axi_bvalid, // (done) write response valid - 0 = response not valid, 1 = response is valid
  output reg                           m_axi_bready, // (done) write response ready - 0 = not ready, 1 = ready
  /**************** Read Address Channel Signals ****************/
  output reg [ADDR_W-1:0]              m_axi_araddr, // address
  output reg [3-1:0]                   m_axi_arprot = 3'b000, // protection - privilege and securit level of transaction
  output reg                           m_axi_arvalid, // 
  input  wire                          m_axi_arready, // 
  output reg [3-1:0]                   m_axi_arsize = $clog2(DATA_W/8), //3'b011, // burst size - size of each transfer in the burst 3'b011 for 8 bytes
  output reg [2-1:0]                   m_axi_arburst = 2'b01, // fixed burst = 00, incremental = 01, wrapped burst = 10
  output reg [4-1:0]                   m_axi_arcache = 4'b0000, //4'b0011, // cache type - how transaction interacts with caches
  output reg [4-1:0]                   m_axi_arlen, // number of data transfers in the burst (0-255) (done)
  output reg [1-1:0]                   m_axi_arlock = 1'b0, // lock type - indicates if transaction is part of locked sequence
  output reg [4-1:0]                   m_axi_arqos = 4'b0000, // quality of service - transaction indication of priority level
  output reg [4-1:0]                   m_axi_arregion = 4'b0000, // region identifier - identifies targetted region
  /**************** Read Data Channel Signals ****************/
  output reg                           m_axi_rready, // read ready - 0 = not ready, 1 = ready
  input  wire [DATA_W-1:0]             m_axi_rdata, // 
  input  wire                          m_axi_rvalid, // read response valid - 0 = response not valid, 1 = response is valid
  input  wire                          m_axi_rlast, // =1 when on last read
  /**************** Read Response Channel Signals ****************/
  input  wire [2-1:0]                  m_axi_rresp, // read response - status of the read transaction (00 = okay, 01 = exokay, 10 = slverr, 11 = decerr)
  /**************** System Signals ****************/
  input wire                           aclk,
  input wire                           aresetn,
  /**************** User Control Signals ****************/  
  input  wire                          user_start,
  input  wire                          user_w_r, // 0 = write, 1 = read
  input  wire [3:0]                    user_burst_len_in,
  input  wire [DATA_W/8-1:0]           user_data_strb,
  input  wire [DATA_W-1:0]             user_data_in,
  input  wire [ADDR_W-1:0]             user_addr_in,
  output reg                           user_free,
  output reg                           user_stall_w_data, // can this be caused by all of these: m_axi_awready, m_axi_awvalid, m_axi_wvalid, m_axi_wready
  output reg                           user_stall_r_data,
  output reg  [1:0]                    user_status,
  output reg  [DATA_W-1:0]             user_data_out,
  output reg                           user_data_out_en
);
   
// AXI FSM ---------------------------------------------------
    localparam IDLE             = 3'b000;
    localparam WRITE            = 3'b001;
    localparam WRITE_RESPONSE   = 3'b010;
    localparam READ_RESPONSE    = 3'b011;
    localparam DEACTIVATE_START = 3'b100;
       
    reg [2:0] axi_cs, axi_ns;
    reg [7:0] w_data_counter;
   
    always @ (posedge aclk or negedge aresetn)
    begin
        if(~aresetn)
        begin
            axi_cs <= IDLE;
        end
       
        else
        begin
            axi_cs <= axi_ns;
        end
    end
   
    always @ (*)
    begin
        case(axi_cs)
        IDLE:
        begin
            if(m_axi_awready & user_start & ~user_w_r)
            begin
                axi_ns = WRITE;
            end

            else if(m_axi_arready & user_start & user_w_r)
            begin
                axi_ns = READ_RESPONSE;
            end
           
            else
            begin
                axi_ns = IDLE;
            end
        end
       
        WRITE:
        begin
            if((w_data_counter == user_burst_len_in) && m_axi_wready)
            begin
                axi_ns = WRITE_RESPONSE;
            end
           
            else
            begin
                axi_ns = WRITE;
            end
        end
       
        WRITE_RESPONSE:
        begin
            if(m_axi_bvalid)
            begin
                if(user_start) axi_ns = DEACTIVATE_START;
                else axi_ns = IDLE;
            end
            else axi_ns = WRITE_RESPONSE;
        end

        READ_RESPONSE:
        begin
            if(m_axi_rlast & m_axi_rvalid)
            begin
                if(user_start) axi_ns = DEACTIVATE_START;
                else axi_ns = IDLE;
            end
           
            else
            begin
                axi_ns = READ_RESPONSE;
            end
        end
        
        DEACTIVATE_START:
        begin
            if(user_start) axi_ns = DEACTIVATE_START;
            else axi_ns = IDLE;
        end
       
        default: axi_ns = IDLE;
        endcase
    end

// AXI WRITE ---------------------------------------------------
    always @ (posedge aclk)
    begin
//
        if(axi_cs == IDLE || axi_cs == WRITE_RESPONSE) w_data_counter <= 'h0;
       
        else if(axi_cs == WRITE && m_axi_wready && w_data_counter < user_burst_len_in)
        begin
            w_data_counter <= w_data_counter + 1'b1;
        end
       
        else w_data_counter <= w_data_counter;
//
    end
    
    always @ (*)
    begin
        m_axi_awvalid <= ((axi_cs==IDLE) && (axi_ns==WRITE)) ? 1 : 0;
        m_axi_awlen   <= ((axi_cs==IDLE) && (axi_ns==WRITE)) ? user_burst_len_in : 0;
        m_axi_awaddr  <= ((axi_cs==IDLE) && (axi_ns==WRITE)) ? user_addr_in : 0;
        m_axi_wvalid  <= (axi_cs==WRITE) ? 1 : 0;
        m_axi_wdata   <= (axi_cs==WRITE) ? user_data_in : 0;
        m_axi_wstrb   <= (axi_cs==WRITE) ? user_data_strb : 0;
        m_axi_wlast   <= ((axi_cs==WRITE)&&(w_data_counter == user_burst_len_in)) ? 1'b1 : 1'b0;
        m_axi_bready  <= ((axi_cs == WRITE_RESPONSE)&& m_axi_bvalid) ? 1'b1 : 'h0;
    end

// AXI READ ---------------------------------------------------    
    always @ (*)
    begin
        m_axi_araddr      <= ((axi_cs==IDLE) && (axi_ns==READ_RESPONSE)) ? user_addr_in : 0;
        m_axi_arlen       <= ((axi_cs==IDLE) && (axi_ns==READ_RESPONSE)) ? user_burst_len_in : 0;
        m_axi_arvalid     <= ((axi_cs==IDLE) && (axi_ns==READ_RESPONSE)) ? 1 : 0;
        m_axi_rready      <= (axi_cs==READ_RESPONSE) ? 1 : 0;
        user_data_out     <= #1 (axi_cs==READ_RESPONSE) ? m_axi_rdata : 0;
        user_data_out_en  <= #1 (axi_cs==READ_RESPONSE) ? m_axi_rvalid : 0;
    end

// STATUS   ---------------------------------------------------
    always @ (posedge aclk)
    begin

        if(((axi_cs == WRITE_RESPONSE)&& m_axi_bvalid))
        begin
            user_status <= m_axi_bresp;
        end

        else if(((axi_cs == READ_RESPONSE)&& m_axi_rvalid))
        begin
            user_status <= m_axi_rresp;
        end
        
        else
        begin
            user_status <= 'h0;
        end
    end

    always @ (*)
    begin
        user_stall_w_data = (~m_axi_wready) ? 1'b0 : 1'b1;
        user_stall_r_data = (~m_axi_rvalid) ? 1'b1 : 1'b0;
        
        user_free       = (axi_ns == IDLE) ? 1'b1 : 1'b0;
    end
// STATUS   ---------------------------------------------------
endmodule
