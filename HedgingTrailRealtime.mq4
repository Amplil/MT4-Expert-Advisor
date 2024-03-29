#include <MyLib.mqh>
#define MAGIC   20191210
#define COMMENT "HedgingTrailRealtime"

// 外部パラメータ
extern double LotsRate=0.8; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
extern double TrailPro=10.0; // Trailing Propotion
extern double OrderWidthStart=0.02; // 注文幅,0.02くらいから注文、低すぎるとタイムアウトになる
extern double TrOrObWStart=0.01; // トレール注文 観察幅 Trailing Order Observe Width
extern double TrOrStWStart=0.005; // トレール注文 ストップ幅 Trailing Order Stop Width
extern double TrStObWStart=0.005; // トレーリングストップ 観察幅 Trailing Stop Observe Width
extern double TrStStWStart=0.003; // トレーリングストップ ストップ幅 Trailing Stop Stop Width

static double OrderWidth=OrderWidthStart; // 注文幅,0.02くらいから注文、低すぎるとタイムアウトになる
static double TrOrObW=TrOrObWStart; // トレール注文 観察幅 Trailing Order Observe Width
static double TrOrStW=TrOrStWStart; // トレール注文 ストップ幅 Trailing Order Stop Width
static double TrStObW=TrStObWStart; // トレーリングストップ 観察幅 Trailing Stop Observe Width
static double TrStStW=TrStStWStart; // トレーリングストップ ストップ幅 Trailing Stop Stop Width

static double a=0;

void OnTick(){
   static int printi=0;

   static int BuyFlag=0,SellFlag=0;
   static double advantage=0;
   static double BuyStartPrice=0; // 買いのトレール注文のスタート価格
   static double SellStartPrice=0; // 売りのトレール注文のスタート価格
   int BuyFlagNow=0,SellFlagNow=0,BuyTicket=0,SellTicket=0;
   double BuyPrice=0,SellPrice=0,PriceWidth=0; // 買いの注文価格,売りの注文価格,価格幅
   double spread=Ask-Bid;
   double Lots=AccountBalance()*25*LotsRate/Bid/100000; // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット
   if(Lots>2)Lots=2; // 2lotsでも警告が出てしまったので、それ以下でやる
   else if(Lots<0.1){
      Comment("Not enough lots");
      return; // ロット数が少ないときは終了する
   }
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MAGIC) continue;
      switch(OrderType()){
         case OP_BUY:
            BuyFlagNow=2;
            BuyTicket=OrderTicket();
            BuyPrice=OrderOpenPrice();
            break;
         case OP_SELL:
            SellFlagNow=2;
            SellTicket=OrderTicket();
            SellPrice=OrderOpenPrice();
            break;
      }
   }
   if(BuyFlag==1)BuyFlagNow=1;
   if(SellFlag==1)SellFlagNow=1;
   //Print("OrdersTotal()=",OrdersTotal()," , BuyFlagNow=",BuyFlagNow," , SellFlagNow=",SellFlagNow);
   if(BuyFlagNow==0){
      BuyStartPrice=Ask;
      BuyFlagNow=1;
   }
   if(SellFlagNow==0){
      SellStartPrice=Bid;
      SellFlagNow=1;
   }
   if(BuyFlagNow==1 && SellFlagNow==1){
      advantage=0; // 両方とも利確されたらアドバンテージをリセットする
      OrderWidth=OrderWidthStart; // 幅もリセット
      TrOrObW=TrOrObWStart;
      TrOrStW=TrOrStWStart;
      TrStObW=TrStObWStart;
      TrStStW=TrStStWStart;
      Comment("Reset Trail Width");
   }   
   else{
      if(BuyFlagNow==2 && SellFlagNow==1)PriceWidth=MathAbs(BuyPrice-Ask);
      else if(BuyFlagNow==1 && SellFlagNow==2)PriceWidth=MathAbs(SellPrice-Bid);
      else if(BuyFlagNow==2 && SellFlagNow==2)PriceWidth=MathAbs(BuyPrice-SellPrice+spread);
      OrderWidth=TrailPro*PriceWidth*OrderWidthStart;
      TrOrObW=TrailPro*PriceWidth*TrOrObWStart;
      TrOrStW=TrailPro*PriceWidth*TrOrStWStart;
      if(BuyFlagNow==2 && SellFlagNow==2){ // 両建てならトレーリングストップでproposalあり
         TrStObW=TrailPro*PriceWidth*TrStObWStart;
         TrStStW=TrailPro*PriceWidth*TrStStWStart;
      }
      else{ // 片方だけならトレーリングストップでproposalなし
         TrStObW=TrStObWStart;
         TrStStW=TrStStWStart;
      }
      if(++printi==10){      
         printi=0;
         Comment("TrailPro*PriceWidth=",TrailPro*PriceWidth," ,\n OrderWidth=", OrderWidth," ,\n TrOrObW=", TrOrObW," ,\n TrOrStW=", TrOrStW," ,\n TrStObW=",TrStObW," ,\n TrStStW=",TrStStW);
      }
   }
   if(BuyFlagNow==1 && TrailingOrderSig(OP_BUYSTOP,BuyStartPrice,OrderWidth,TrOrObW,TrOrStW)==1){
      MyOrderSend(OP_BUY,Lots,Ask,Slippage,0,0,COMMENT,MAGIC);
      BuyFlagNow=2;
   }   
   else if(SellFlagNow==1 && TrailingOrderSig(OP_SELLSTOP,SellStartPrice,OrderWidth,TrOrObW,TrOrStW)==1){
      MyOrderSend(OP_SELL,Lots,Bid,Slippage,0,0,COMMENT,MAGIC);
      SellFlagNow=2;
   }   
   //if(BuyFlagNow==1 || SellFlagNow==1)TrailingOrder(TrOrObW,TrOrStW,MAGIC);
   else if(BuyFlag==2&&SellFlag==2 && (BuyFlagNow==1||SellFlagNow==1)){ // 両建てが解消されたときにアドバンテージを加算する
      if(OrderSelect(OrdersHistoryTotal()-1,SELECT_BY_POS,MODE_HISTORY)==false)return;
      advantage+=OrderProfit();
   }
   else if(BuyFlagNow==2 && SellFlagNow==1){ // スプレッド分を抜いた含み損があるならば過去のアドバンテージを使う
      if(OrderSelect(BuyTicket,SELECT_BY_TICKET)==false)return;
      if(OrderProfit()+100000*Lots*spread<0){
         //if(advantage!=a){
         //Comment("advantage: ",advantage);
         a=advantage;
         //}
         //else Print("Not Changed advantage");
         TrailingStopPrice(OP_BUY,Ask+advantage/(100000*Lots),TrStObW,TrStStW,MAGIC); // priceは買ったときでみるからaskの値段
      }
   }
   else if(BuyFlagNow==1 && SellFlagNow==2){ // スプレッド分を抜いた含み損があるならば過去のアドバンテージを使う
      if(OrderSelect(SellTicket,SELECT_BY_TICKET)==false)return;
      if(OrderProfit()+100000*Lots*spread<0){
         //Comment("advantage: ",advantage);
         TrailingStopPrice(OP_SELL,Bid-advantage/(100000*Lots),TrStObW,TrStStW,MAGIC); // priceは売ったときでみるからbidの値段
      }   
   }
   else if(BuyFlagNow==2 && SellFlagNow==2)TrailingStop(TrStObW,TrStStW,MAGIC); // 両建てのときはアドバンテージを使わない
   BuyFlag=BuyFlagNow;
   SellFlag=SellFlagNow;
}