//+------------------------------------------------------------------+
//|                                  TradeBot_Hedging_Loopifdone.mq4 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#include <MyLib.mqh>
#define MAGIC   20191013
#define COMMENT "TradeBotHedgingLoopifdone"
#define LAST -1
// 外部パラメータ
extern int Slippage = 3;
extern int Rnum_short=5; // 短期RSIデータ数
extern int Rnum_long=15; // 長期RSIデータ数
extern int Anum_short=10; // 短期移動平均線データ数
extern int Anum_long=17; // 長期移動平均線データ数
extern int SignalPeriod = 9;     // MACDのSMAを取る期間(今のところシグナルに関係なし)
// extern double Lots=AccountBalance()*25*0.85/10/Ask;
extern double Lots = 0.5;

uint MyOrderWaitingTime = 10;   // 注文待ち時間(秒)
color ArrowColor[6] = {Blue, Red, Blue, Red, Blue, Red};

datetime hour(int t_hour){
   datetime sec;
   sec=t_hour*3600;
   return(sec);
}
 // チケットを指定して決済
bool TicketClose(int ticket){
   uint starttime = GetTickCount();
   while(true)
   {
      int type = OrderType();
      if(GetTickCount() - starttime > MyOrderWaitingTime*1000)
      {
         Alert("OrderClose timeout. Check the experts log.");
         return(false);
      }
      if(IsTradeAllowed() == true)
      {
         RefreshRates();
         if(OrderClose(ticket, OrderLots(), OrderClosePrice(),Slippage,ArrowColor[type]) == true) return(true);
         int err = GetLastError();
         Print("[OrderCloseError] : ", err, " ", ErrorDescription(err));
         if(err == ERR_INVALID_PRICE) break;
      }
      Sleep(100);
   }
   return(false);
}
// ロングまたはショートのポジションナンバーを指定して価格を表示
double OrderPosPrice(int pos,int pos_num){
   int OrderPosNum=0;
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false)return(-1); // error
      if(OrderSymbol()==Symbol()&&OrderMagicNumber()==MAGIC&&pos==OrderType()){
         OrderPosNum++;
         if(pos_num==OrderPosNum)return(OrderOpenPrice());
      }
   }
   return(0); // Not found
}
// ポジションの注文の総数
int PosOrdersTotal(int pos){
   int OrderPosNum=0;
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false)return(-1); // error
      if(OrderSymbol()==Symbol()&&OrderMagicNumber()==MAGIC&&pos==OrderType())OrderPosNum=i+1;
   }
   return(OrderPosNum);
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
  
//---
   
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   int LongPos=PosOrdersTotal(OP_BUY); // Long Position
   int ShortPos=PosOrdersTotal(OP_SELL); // Short Position
   double RSI_short=iRSI(NULL,PERIOD_M1,Rnum_short,0,0);
   double RSI_long=iRSI(NULL,PERIOD_M1,Rnum_long,0,0);
   double macd=iMACD(NULL,PERIOD_M1,Anum_short,Anum_long,SignalPeriod,0,MODE_MAIN,0);
   double a=AccountBalance();
   double b=Ask-OrderPosPrice(OP_BUY,LongPos);
   double c=-0.01*LongPos;
   double d=AccountBalance()*25*0.85/10/Ask;
   double e=Bid-OrderPosPrice(OP_SELL,ShortPos);
   // オープン
   if((LongPos==0 || (0<LongPos&&LongPos<10&&Ask-OrderPosPrice(OP_BUY,LongPos)<-0.01*LongPos)) && RSI_short<=35&&RSI_long<=35&&macd<=-0.005){
      MyOrderSend(OP_BUY,Lots,Ask,Slippage,0,Ask+0.01,COMMENT,MAGIC);
   }
   if((ShortPos==0 || (0<ShortPos&&ShortPos<10&&0.01*ShortPos<Bid-OrderPosPrice(OP_SELL,ShortPos))) && RSI_short>=65&&RSI_long>=65&&0.005<=macd){
      MyOrderSend(OP_SELL,Lots,Bid,Slippage,0,Bid-0.01,COMMENT,MAGIC);
   }
   // 損切り
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol() != Symbol() || OrderMagicNumber()!=MAGIC) continue;
      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL){
         int ticket = OrderTicket();
         if(TimeCurrent()-OrderOpenTime()>hour(3)){
            if((type==OP_BUY&&RSI_long>=65)||(type==OP_SELL&&RSI_long<=35)){
               TicketClose(ticket);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
