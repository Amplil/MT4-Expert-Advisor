#include <MyLib.mqh>
#define MAGIC   20191109
#define COMMENT "CandleTradeTrailingStop"

// 外部パラメータ
extern double LotsRate=0.2; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
extern double OrderWidth=0.02; // 注文幅
extern double toow=0.005; // トレール注文 観察幅 Trailing Order Observ Width
extern double tosw=0.01; // トレール注文 ストップ幅 Trailing Order Stop Width
extern double tsow=0.03; // トレーリングストップ 観察幅 Trailing Stop Observ Width
extern double tssw=0.01; // トレーリングストップ ストップ幅 Trailing Stop Stop Width
extern double sl=0.1; // 損切り幅

void OnTick(){
   static datetime BeforeTime=0;
   static int TrailFlag=0,type=0;
   static double StartPrice=0;
   if(Time[0]>BeforeTime){ // チャートが更新されたとき
      double spread=Ask-Bid;
      double Lots=AccountBalance()*25*LotsRate/Bid/100000; // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット
      BeforeTime=Time[0];
      TrailFlag=1;
      LossCutClose(Slippage,MAGIC); // 注文の含み損益がマイナスの場合決済
      MyOrderDelete(MAGIC); // 待機注文が残っていたら取り消し
      if(Lots<0.1){
         Print("Not enough lots");
         return; // ロット数が少ないときは終了する
      }
      // 買い注文
      if(Open[1]<Close[1]){
         double OrderPrice=Close[1]+spread+OrderWidth;
         if(Ask>=OrderPrice)MyOrderSend(OP_BUY,Lots,Ask,Slippage,Ask-sl,0,COMMENT,MAGIC);
         else{
            type=OP_BUYSTOP;
            StartPrice=Ask;
            MyOrderSend(type,Lots,OrderPrice,Slippage,Ask-sl,0,COMMENT,MAGIC);
         }
      }
      // 売り注文
      else if(Open[1]>Close[1]){
         OrderPrice=Close[1]-OrderWidth;
         if(Bid<=OrderPrice)MyOrderSend(OP_SELL,Lots,Bid,Slippage,Bid+sl,0,COMMENT,MAGIC);
         else{
            type=OP_SELLSTOP;
            StartPrice=Bid;
            MyOrderSend(type,Lots,OrderPrice,Slippage,Bid+sl,0,COMMENT,MAGIC);
         }
      }
   }
   TrailingOrder(type,StartPrice,toow,tosw,MAGIC);
   TrailingStop(tsow,tssw,MAGIC);
}