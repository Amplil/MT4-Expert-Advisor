#include <MyLib.mqh>
#define MAGIC   20191206
#define COMMENT "HedgingTrail"

// 外部パラメータ
extern double LotsRate=0.2; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
extern double ObserveWidth=0.005; // 観察幅
extern double StopWidth=0.003; // ストップ幅
extern double OrderWidth=0.003; // 注文幅

void OnTick(){
   static int BuyFlag=0,SellFlag=0;
   static double advantage=0;
   int BuyFlagNow=0,SellFlagNow=0,BuyTicket=0,SellTicket=0;
   double spread=Ask-Bid;
   double Lots=AccountBalance()*25*LotsRate/Bid/100000; // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット
   if(Lots>2)Lots=2;
   else if(Lots<0.1){
      Print("Not enough lots");
      return; // ロット数が少ないときは終了する
   }
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGIC) continue;
      switch(OrderType()){
         case OP_BUY:{
            BuyFlagNow=1;
            BuyTicket=OrderTicket();
         }
         case OP_SELL:{
            SellFlagNow=1;
            SellTicket=OrderTicket();
         }
         case OP_BUYSTOP:BuyFlagNow=2;
         case OP_SELLSTOP:SellFlagNow=2;
      }
   }
   Print("BuyFlagNow=",BuyFlagNow," , SellFlagNow=",SellFlagNow);
   if(BuyFlagNow==0){
      MyOrderSend(OP_BUYSTOP,Lots,Ask+OrderWidth,Slippage,0,0,COMMENT,MAGIC);
      BuyFlagNow=1;
   }
   if(SellFlagNow==0){
      MyOrderSend(OP_SELLSTOP,Lots,Bid-OrderWidth,Slippage,0,0,COMMENT,MAGIC);
      SellFlagNow=1;
   }
   if(BuyFlagNow==1 && SellFlagNow==1)advantage=0;
   if(BuyFlagNow==1 || SellFlagNow==1)TrailingOrder(ObserveWidth,StopWidth,MAGIC);
   if(BuyFlag==2&&SellFlag==2 && (BuyFlagNow==1||SellFlagNow==1)){ // 両建てが解消されたときにアドバンテージを加算する
      if(OrderSelect(OrdersHistoryTotal()-1,SELECT_BY_POS,MODE_HISTORY)==false)return;
      advantage+=OrderProfit();
   }
   if(BuyFlagNow==2 && SellFlagNow==1){ // スプレッド分を抜いた含み損があるならば過去のアドバンテージを使う
      if(OrderSelect(BuyTicket,SELECT_BY_TICKET)==false)return;
      if(OrderProfit()+100000*Lots*spread<0)
         TrailingStopPrice(OP_BUY,Ask+advantage/(100000*Lots),ObserveWidth,StopWidth,MAGIC); // priceは買ったときでみるからaskの値段
   }
   else if(BuyFlagNow==1 && SellFlagNow==2){ // スプレッド分を抜いた含み損があるならば過去のアドバンテージを使う
      if(OrderSelect(SellTicket,SELECT_BY_TICKET)==false)return;
      if(OrderProfit()+100000*Lots*spread<0)
         TrailingStopPrice(OP_SELL,Bid-advantage/(100000*Lots),ObserveWidth,StopWidth,MAGIC); // priceは売ったときでみるからbidの値段
   }
   else if(BuyFlagNow==2 && SellFlagNow==2)TrailingStop(ObserveWidth,StopWidth,MAGIC); // 両建てのときはアドバンテージを使わない
   BuyFlag=BuyFlagNow;
   SellFlag=SellFlagNow;
}