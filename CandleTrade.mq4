// マイライブラリー
#include <MyLib.mqh>

// マジックナンバー
#define MAGIC   20191106
#define COMMENT "CandleTrade"

// 外部パラメータ
extern double LotsRate=0.2; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
  
void OnTick(){
   static datetime BeforeTime=0;
   if(Time[0]>BeforeTime){ // 注文が3つ以下のとき,チャートが更新されたとき
      double spread=Ask-Bid;
      double Lots=AccountBalance()*25*LotsRate/Bid/100000; // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット
      BeforeTime=Time[0];
      MyOrderClose(Slippage,MAGIC); // オープン済み注文が残っていたら決済
      MyOrderDelete(MAGIC); // 待機注文が残っていたら取り消し
      if(Lots<0.1){
         Print("Not enough money");
         return; // ロット数が少ないときは終了する
      }
      // 買い注文
      if(Open[1]<Close[1] && High[1]-Close[1]>spread && High[1]-Bid>spread){ 
         //MyOrderSend(OP_BUYLIMIT,Lots,Close[1],0,0,High[1],COMMENT,MAGIC); // 最新のバーはティックが更新される度に値が変わってしまうため、確定された１つ前のバーを指定する
         Print("ask: ",Ask,"  High[1]: ",High[1],"  Close[1]: ",Close[1]);
         MyOrderSend(OP_BUY,Lots,Ask,Slippage,0,High[1],COMMENT,MAGIC); // 最新のバーはティックが更新される度に値が変わってしまうため、確定された１つ前のバーを指定する
      }
      // 売り注文
      if(Open[1]>Close[1] && Close[1]-Low[1]>spread && Bid-Low[1]>spread){
         //MyOrderSend(OP_SELLLIMIT,Lots,Close[1],0,0,Low[1],COMMENT,MAGIC); // 最新のバーはティックが更新される度に値が変わってしまうため、確定された１つ前のバーを指定する
         Print("Bid: ",Bid,"  Low[1]: ",Low[1],"  Close[1]: ",Close[1]);
         MyOrderSend(OP_SELL,Lots,Bid,Slippage,0,Low[1],COMMENT,MAGIC); // 最新のバーはティックが更新される度に値が変わってしまうため、確定された１つ前のバーを指定する
      }
   }
}