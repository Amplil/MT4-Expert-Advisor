// マイライブラリー
#include <MyLib.mqh>

// マジックナンバー
#define MAGIC   20191104
#define COMMENT "SARMultiTime"

// 外部パラメータ
extern double LotsRate=0.2; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
extern double sl=0.1; // 損切り条件の値

// エントリー関数
extern double step=0.01; // パラボリックステップ
extern double maximum=0.1; // パラボリック上限
extern int TSPoint=15; // トレーリングストップのポイント
extern double stepLong=0.01; // パラボリックステップ
extern double maximumLong=0.1; // パラボリック上限


int EntrySignal(int magic){

   // 移動平均の計算
   double SARNow=iSAR(NULL,0,step,maximum,1);
   double SARBefo=iSAR(NULL,0,step,maximum,2);
   double SARLong=iSAR(NULL,PERIOD_M15,stepLong,maximumLong,1);
   
   int ret = 0;
   // 買いシグナル
   if(SARBefo>Bid && SARNow<Bid && SARLong<Bid){
      ret=1;
   }
   // 売りシグナル
   else if(SARBefo<Bid && SARNow>Bid && SARLong>Bid){
      ret=-1;
   }

   return(ret);
}
  
void OnTick(){
   static datetime BeforeTime=0;
   if(OrdersTotal()<=3 && Time[0]>BeforeTime){ // 注文が3つ以下のとき,チャートが更新されたとき
      double Lots=AccountBalance()*25*LotsRate/Bid/100000; // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット
      BeforeTime=Time[0];
      if(Lots<0.1){
         Print("Not enough money");
         return; // ロット数が少ないときは終了する
      }
      // エントリーフラグ
      int sig_entry=EntrySignal(MAGIC);
      // 買い注文
      if(sig_entry>0){
         MyOrderSend(OP_BUY,Lots,Ask,Slippage,Ask-sl,0,COMMENT,MAGIC);
      }
      // 売り注文
      if(sig_entry<0){
         MyOrderSend(OP_SELL,Lots,Bid,Slippage,Bid+sl,0,COMMENT,MAGIC);
      }
   }
   MyTrailingStop(TSPoint, MAGIC);
}