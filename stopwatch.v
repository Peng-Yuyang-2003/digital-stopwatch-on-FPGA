module stopwatch
(	
	input   wire    clock,
	input   wire    buttonA,
	input   wire    buttonB,
	output  reg     [8:0] wrnum,
	output  reg     [8:0] rdnum,
	output  reg     [2:0] state,
	output	reg	    [6:0]	LED1,
	output	reg	    [6:0]	LED2,
	output	reg	    [6:0]	LED3,
	output	reg	    [6:0]	LED4,
	output	reg   	[6:0]	LED5,
	output	reg	    [6:0]	LED6,
	output	reg   	[6:0]	LED7,
	output	reg	    [6:0]	LED8
);

//周期变为0.01s的clk信号
reg	[25:0]	cnt100;
always@(posedge clock)
begin
	cnt100 <= (cnt100 == 26'd500000)?26'd0:cnt100+1'b1; 
end
wire	clk = (cnt100 == 26'd250000) ? 1'b1 : 1'b0;

//计数单元
reg [11:0]  ms=00;//毫秒位
reg [7:0]   s=00;//秒位
reg         stop  = 0;
reg         rst   = 1;

always@(posedge clock or negedge rst or posedge stop) begin
  if(!rst)
    ms <= 000;
  else if(stop) 
    ms <= ms;
  else if(clk) 
  begin
    if(ms[7:4]==4'b1001)
      begin
        ms[7:4]<=0;
        ms[11:8]<=1;
      end
    else if(ms[3:0]==4'b1001)
      begin
        ms[3:0]<=0;
        ms[7:4]<=ms[7:4]+4'b0001;
      end
    else if(ms < 12'b000100000000)
      ms[3:0] <= ms[3:0] + 4'b0001;
  else
    ms <= 000;
  end
end



always@(posedge ms[8:8] or negedge rst or posedge stop) begin
  if(!rst)
    s <= 00;
  else if(stop) 
    s <= s;
  else if(s[3:0]==4'b1001)
    begin
      s[3:0]<=0;
      s[7:4]<=s[7:4]+1;
    end
  else 
    s <= s + 1;
end


//按键模块
reg [19:0] checktimeA;	
reg [19:0] checktimeB;
reg [31:0] countA;
reg [31:0] countB;	
reg        newA;  
reg        newB;
reg        lastA; 
reg        lastB;
wire       flag_upA; 
wire       flag_upB;
reg [3:0]  buttonstate=4'b0000;//AB长短

//按键A
always @(posedge clock)
	begin
		if (checktimeA == 20'd499_999)
			begin
				checktimeA <= 20'd0;
				newA <= buttonA;
			end
		else
			checktimeA <= checktimeA +1'b1;
	end

always @(posedge clock)
	begin
		lastA <= newA;
	end

assign flag_upA = (~lastA) & newA;	 
 
always @(posedge clock )
	begin
		if (newA == 0)
			countA <= countA +1'b1;
		else if (newA == 1)
			countA <= 32'd0;
	end


always @(posedge clock )
	begin
		if (countA >= 32'd49_999_999)buttonstate[0] <=1;
		else if(countA >= 32'd999_999)
			begin
				if (flag_upA==1)buttonstate[1] <= 1;//长按
				else buttonstate[1:0]=2'b00;//短按
			end
		else 
		    begin
              buttonstate[1:0]=2'b00;
            end
	end

//按键B
always @(posedge clock )
	begin
		if (checktimeB == 20'd499_999)
			begin
				checktimeB <= 20'd0;
				newB <= buttonB;
			end
		else
			checktimeB <= checktimeB +1'b1;
	end


always @(posedge clock)
	begin
		lastB <= newB;
	end
 
assign flag_upB = (~lastB) & newB;

always @(posedge clock )
	begin
		if (newB == 0)
			countB <= countB +1'b1;
		else if (newB == 1)
			countB <= 32'd0;
	end

always @(posedge clock )
	begin
		if (countB >= 32'd49_999_999)buttonstate[2] <=1;
		else if(countB >= 32'd999_999)
			begin
				if (flag_upB==1)buttonstate[3] <= 1;//长按
				else buttonstate[3:2]=2'b00;//短按
			end
		else 
		    begin
              buttonstate[3:2]=2'b00;
            end
	end

//状态单元-核心部分
reg [1:0] current_state=2'b00;//modeSET在哪里变化？
reg [3:0] cnta;
reg [3:0] cntb;

reg [15:0] storage[8:0];//存九条数据

always @(posedge clock) begin
    case(current_state[1:0])
        2'b00:begin//清零
          rst<=0;
          stop<=1;
          leddrive1<=0;
          leddrive2<=0;
          leddrive3<=0;
          leddrive4<=0;
          leddrive5<=0;
          leddrive6<=0;
          leddrive7<=0;
          leddrive8<=0;
		  storage[8]<=0;
		  storage[7]<=0;
		  storage[6]<=0;
		  storage[5]<=0;
		  storage[4]<=0;
		  storage[3]<=0;
		  storage[2]<=0;
		  storage[1]<=0;
          if(buttonstate[1])
            current_state[1:0]=2'b01;
        end
        2'b01:begin//计时
          rst<=1;
          stop<=0;
          leddrive1 <= ms[3:0];//显示当前时间
          leddrive2 <= ms[7:4];
          leddrive3 <= s[3:0];
          leddrive4 <= s[7:4];
          leddrive5 <= storage[cnta][3:0];//显示一个存储的时间
          leddrive6 <= storage[cnta][7:4];
          leddrive7 <= storage[cnta][11:8];
          leddrive8 <= storage[cnta][15:12];
          if(buttonstate[0])
            current_state[1:0]<=2'b00;
          else if(buttonstate[1])
            current_state[1:0]<=2'b10;
          else if(buttonstate[3])
          begin
          storage[cnta][7:0] <= ms[7:0];
          storage[cnta][15:8] <= s[7:0];//存储写进去
          end
          else if(s==8'b01100000)//时间到了会暂停
            stop<=1;
        end
        2'b10:begin//暂停
          rst<=1;
          stop<=1;
          leddrive1 <= ms[3:0];//显示当前时间
          leddrive2 <= ms[7:4];
          leddrive3 <= s[3:0];
          leddrive4 <= s[7:4];
          leddrive5 <= storage[cntb][3:0];//显示一个存储的时间
          leddrive6 <= storage[cntb][7:4];
          leddrive7 <= storage[cntb][11:8];
          leddrive8 <= storage[cntb][15:12];
          if(buttonstate[0])
            current_state[1:0]<=2'b00;
        end
    endcase
end

//存储和读取单元
//写入
  always@(posedge buttonstate[3] or negedge rst) begin
    if(!rst)begin
         cnta <= 4'b0000;
    end
    else if(cnta==8)
        begin
        cnta=4'b0000;
        end
    else if(cnta < 4'b1001)
            if(current_state[1:0] == 2'b01)begin//计时状态开始写入，并移位
              cnta <= cnta + 4'b0001;
            end
            else begin
              cnta <= cnta;
            end
    else begin
        cnta <= 4'b0000;    
    end
   end

//读取
  always@(posedge buttonstate[3] or negedge rst) begin
    if(!rst)begin
         cntb <= 4'b00;
    end
    else if(cntb==8)
        begin
        cntb[3:0]=4'b0000;
        end
    else if(cntb < 4'b1001)
            if(current_state[1:0] == 4'b10)begin//暂停状态开始读取，并移位
              cntb <= cntb + 4'b0001;
			end
            else begin
              cntb <= 4'b0000;
           end
    else begin
        cntb <= 4'b0000;   //初值   
    end
   end




//显示单元
always @(*) begin
  case(current_state[1:0])
    2'b00:begin
      state=3'b100;
    end
    2'b01:begin
      state=3'b010;
    end
    2'b10:begin
      state=3'b001;
    end
  endcase
end
always @(*)
begin
		case(cnta)
    4'd0: wrnum = 9'b100_000_000;
		4'd1: wrnum = 9'b010_000_000;
		4'd2: wrnum = 9'b001_000_000;
		4'd3: wrnum = 9'b000_100_000; 
		4'd4: wrnum = 9'b000_010_000;
		4'd5: wrnum = 9'b000_001_000; 
		4'd6: wrnum = 9'b000_000_100; 
		4'd7: wrnum = 9'b000_000_010; 
		4'd8: wrnum = 9'b000_000_001; 
    default : wrnum = 9'b000_000_000;
		endcase
end
always @(*)
begin
		case(cntb)
    4'd0: rdnum = 9'b100_000_000;
		4'd1: rdnum = 9'b010_000_000;
		4'd2: rdnum = 9'b001_000_000;
		4'd3: rdnum = 9'b000_100_000; 
		4'd4: rdnum = 9'b000_010_000;
		4'd5: rdnum = 9'b000_001_000; 
		4'd6: rdnum = 9'b000_000_100; 
		4'd7: rdnum = 9'b000_000_010; 
		4'd8: rdnum = 9'b000_000_001; 
    default : rdnum = 9'b000_000_000;
        endcase
end
reg	  	[3:0]	  leddrive1=4'b1101;
reg	  	[3:0]	  leddrive2=4'b0010;
reg	  	[3:0]	  leddrive3=4'b0011;
reg	  	[3:0]	  leddrive4=4'b0100;
reg	  	[3:0]	  leddrive5=4'b0101;
reg	  	[3:0]	  leddrive6=4'b0110;
reg	  	[3:0]	  leddrive7=4'b0101;
reg	  	[3:0]	  leddrive8=4'b0110;
always @(*)
begin
		case(leddrive4)
		4'h1: LED1 = 7'b1111001;
		4'h2: LED1 = 7'b0100100;
		4'h3: LED1 = 7'b0110000; 
		4'h4: LED1 = 7'b0011001;
		4'h5: LED1 = 7'b0010010; 
		4'h6: LED1 = 7'b0000010; 
		4'h7: LED1 = 7'b1111000; 
		4'h8: LED1 = 7'b0000000; 
		4'h9: LED1 = 7'b0011000; 
		4'h0: LED1 = 7'b1000000;
    default : LED1 = 7'b0111111;
		endcase
end
always @(*)
begin
		case(leddrive3)
		4'h1: LED2 = 7'b1111001;
		4'h2: LED2 = 7'b0100100;
		4'h3: LED2 = 7'b0110000; 
		4'h4: LED2 = 7'b0011001;
		4'h5: LED2 = 7'b0010010; 
		4'h6: LED2 = 7'b0000010; 
		4'h7: LED2 = 7'b1111000; 
		4'h8: LED2 = 7'b0000000; 
		4'h9: LED2 = 7'b0011000; 
		4'h0: LED2 = 7'b1000000;
    default : LED2 = 7'b0111111;
		endcase
end
always @(*)
begin
		case(leddrive2)
		4'h1: LED3 = 7'b1111001;
		4'h2: LED3 = 7'b0100100;
		4'h3: LED3 = 7'b0110000; 
		4'h4: LED3 = 7'b0011001;
		4'h5: LED3 = 7'b0010010; 
		4'h6: LED3 = 7'b0000010; 
		4'h7: LED3 = 7'b1111000; 
		4'h8: LED3 = 7'b0000000; 
		4'h9: LED3 = 7'b0011000; 
		4'h0: LED3 = 7'b1000000;
    default : LED3 = 7'b0111111;
		endcase
end
always @(*)
begin
		case(leddrive1)
		4'h1: LED4 = 7'b1111001;
		4'h2: LED4 = 7'b0100100;
		4'h3: LED4 = 7'b0110000; 
		4'h4: LED4 = 7'b0011001;
		4'h5: LED4 = 7'b0010010; 
		4'h6: LED4 = 7'b0000010; 
		4'h7: LED4 = 7'b1111000; 
		4'h8: LED4 = 7'b0000000; 
		4'h9: LED4 = 7'b0011000; 
		4'h0: LED4 = 7'b1000000;
    default : LED4 = 7'b0111111;
		endcase
end
always @(*)
begin
		case(leddrive8)
		4'h1: LED5 = 7'b1111001;
		4'h2: LED5 = 7'b0100100;
		4'h3: LED5 = 7'b0110000; 
		4'h4: LED5 = 7'b0011001;
		4'h5: LED5 = 7'b0010010; 
		4'h6: LED5 = 7'b0000010; 
		4'h7: LED5 = 7'b1111000; 
		4'h8: LED5 = 7'b0000000; 
		4'h9: LED5 = 7'b0011000; 
		4'h0: LED5 = 7'b1000000;
    default : LED5 = 7'b0111111;
		endcase
end
always @(*)
begin
		case(leddrive7)
		4'h1: LED6 = 7'b1111001;
		4'h2: LED6 = 7'b0100100;
		4'h3: LED6 = 7'b0110000; 
		4'h4: LED6 = 7'b0011001;
		4'h5: LED6 = 7'b0010010; 
		4'h6: LED6 = 7'b0000010; 
		4'h7: LED6 = 7'b1111000; 
		4'h8: LED6 = 7'b0000000; 
		4'h9: LED6 = 7'b0011000; 
		4'h0: LED6 = 7'b1000000;
    default : LED6 = 7'b0111111;
		endcase
end
always @(*)
begin
		case(leddrive6)
		4'h1: LED7 = 7'b1111001;
		4'h2: LED7 = 7'b0100100;
		4'h3: LED7 = 7'b0110000; 
		4'h4: LED7 = 7'b0011001;
		4'h5: LED7 = 7'b0010010; 
		4'h6: LED7 = 7'b0000010; 
		4'h7: LED7 = 7'b1111000; 
		4'h8: LED7 = 7'b0000000; 
		4'h9: LED7 = 7'b0011000; 
		4'h0: LED7 = 7'b1000000;
    default : LED7 = 7'b0111111;
		endcase
end
always @(*)
begin
		case(leddrive5)
		4'h1: LED8 = 7'b1111001;
		4'h2: LED8 = 7'b0100100;
		4'h3: LED8 = 7'b0110000; 
		4'h4: LED8 = 7'b0011001;
		4'h5: LED8 = 7'b0010010; 
		4'h6: LED8 = 7'b0000010; 
		4'h7: LED8 = 7'b1111000; 
		4'h8: LED8 = 7'b0000000; 
		4'h9: LED8 = 7'b0011000; 
		4'h0: LED8 = 7'b1000000;
    default : LED8 = 7'b0111111;
		endcase
end
endmodule
