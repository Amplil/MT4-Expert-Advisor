#include <MyLib.mqh>
#define MAGIC   20200325
#define COMMENT "speed"
#include <MyLib.mqh>

// 外部パラメータ
extern double LotsRate=0.8; // 口座残高に対する注文ロットの割合
extern double MaxLots=2; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
extern double OpenDiffLevel=0.03; // OpenDiffのシグナルレベル
extern double ObserveWidth=0.006; // トレーリングストップ 観察幅 Trailing Stop Observe Width
extern double StopWidth=0.003; // トレーリングストップ ストップ幅 Trailing Stop Stop Width
extern double OrderLimitTime=30; // 注文の期限（秒）


void OnTick(){
   static datetime BeforeTime=0;
   static int TrailFlag=0,type=0;
   static double StartPrice=0;
   int PosTotal=0; // オープンしているポジションの数
   /*
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()==Symbol())PosTotal++;
   }
   */
   if(Time[0]>BeforeTime){ // チャートが更新されたとき、かつ何も注文していないとき
      double spread=Ask-Bid;
      double Lots=AccountBalance()*25*LotsRate/Bid/100000; // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット
      double HighDiff=iCustom(NULL,0,"OpenDiff",0,0);
      double LowDiff=iCustom(NULL,0,"OpenDiff",1,0);      
      int StartTime=60*TimeMinute(Time[0])+TimeSeconds(Time[0]);      
      int CurrentTime=60*Minute()+Seconds();      
      Comment("StartTime=",StartTime,"\nCurrentTime=",CurrentTime,"\nSpendTime=",CurrentTime-StartTime);
     
      //TrailFlag=1;
      MyOrderClose(Slippage,MAGIC); // 2つポジションが残っていた場合を考えて2回実行
      //MyOrderClose(Slippage,MAGIC); // 2つポジションが残っていた場合を考えて2回実行
      MyOrderDelete(MAGIC); // 待機注文が残っていたら取り消し
      if(Lots>MaxLots)Lots=MaxLots; // 2lotsでも警告が出てしまったので、それ以下でやる→短時間のうちにオープンを繰り返したからかもしれない
      else if(Lots<0.1){
         Comment("Not enough lots");
         return; // ロット数が少ないときは終了する
      }
      if(CurrentTime-StartTime<OrderLimitTime){
         // 買い注文
         if(HighDiff>OpenDiffLevel){
            //double OrderPrice=Close[1]+spread+OrderWidth;
            MyOrderSend(OP_BUY,Lots,Ask,Slippage,0,0,COMMENT,MAGIC);
            BeforeTime=Time[0];
         }
         // 売り注文
         else if(LowDiff<-OpenDiffLevel){
            //OrderPrice=Close[1]-OrderWidth;
            MyOrderSend(OP_SELL,Lots,Bid,Slippage,0,0,COMMENT,MAGIC);
            BeforeTime=Time[0];
         }
      }   
   }
   //TrailingOrder(type,StartPrice,toow,tosw,MAGIC);
   TrailingStop(ObserveWidth,StopWidth,MAGIC);
}