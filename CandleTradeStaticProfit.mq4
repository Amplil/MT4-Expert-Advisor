#include <MyLib.mqh>
#define MAGIC   20191107
#define COMMENT "CandleTradeStaticProfit"

// 外部パラメータ
extern double LotsRate=0.2; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
extern double tp=0.02; // 利食い幅(スプレッドを含まない)

void OnTick(){
   static datetime BeforeTime=0;
   if(Time[0]>BeforeTime){ // チャートが更新されたとき
      double spread=Ask-Bid;
      double Lots=AccountBalance()*25*LotsRate/Bid/100000; // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット
      BeforeTime=Time[0];
      MyOrderClose(Slippage,MAGIC); // 注文が残っていたら決済
      if(Lots<0.1){
         Print("Not enough money");
         return; // ロット数が少ないときは終了する
      }
      // 買い注文
      if(Open[1]<Close[1] && High[1]-Bid>tp+spread){
         MyOrderSend(OP_BUY,Lots,Ask,Slippage,0,Bid+tp,COMMENT,MAGIC); // 最新のバーはティックが更新される度に値が変わってしまうため、確定された１つ前のバーを指定する
      }
      // 売り注文
      else if(Open[1]>Close[1] && Bid-Low[1]>tp+spread){
         MyOrderSend(OP_SELL,Lots,Bid,Slippage,0,Ask-tp,COMMENT,MAGIC); // 最新のバーはティックが更新される度に値が変わってしまうため、確定された１つ前のバーを指定する
      }
      // 買い注文
      else if(Open[1]<Close[1] && High[1]-Bid>spread){
         MyOrderSend(OP_BUY,Lots,Ask,Slippage,0,High[1]+spread,COMMENT,MAGIC); // 最新のバーはティックが更新される度に値が変わってしまうため、確定された１つ前のバーを指定する
      }
      // 売り注文
      else if(Open[1]>Close[1] && Bid-Low[1]>spread){
         MyOrderSend(OP_SELL,Lots,Bid,Slippage,0,Low[1],COMMENT,MAGIC); // 最新のバーはティックが更新される度に値が変わってしまうため、確定された１つ前のバーを指定する
      }
   }
}