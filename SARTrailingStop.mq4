// マイライブラリー
#include <MyLib.mqh>

// マジックナンバー
#define MAGIC   20191102
#define COMMENT "SARTrailingStop"

// 外部パラメータ
extern double LotsRate=0.2; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
extern double sl=0.1; // 損切り条件の値

// エントリー関数
extern double step=0.02; // パラボリックステップ
extern double maximum=0.2; // パラボリック上限
extern int RSIperiod=15; // RSIの期間
extern double RSIUpperLevel=60; // RSIアッパーレベル
extern double RSILowerLevel=40; // RSIロワーレベル
extern int TSPoint=2; // RSIの期間

int EntrySignal(int magic){

   // 移動平均の計算
   double SARNow=iSAR(NULL,0,step,maximum,1);
   double SARBefo=iSAR(NULL,0,step,maximum,2);
   double rsi=iRSI(NULL,0,RSIperiod,PRICE_CLOSE,1);

   int ret = 0;
   // 買いシグナル
   if(SARBefo>Ask && SARNow<Ask && rsi>RSIUpperLevel){
      ret=1; // クロスの傾きが大きくなければエントリーしない
   }
   // 売りシグナル
   if(SARBefo<Ask && SARNow>Ask && rsi<RSILowerLevel){
      ret=-1; // クロスの傾きが大きくなければエントリーしない
   }

   return(ret);
}
  
void OnTick(){
   static datetime BeforeTime=0;
   if(OrdersTotal()<=3 && Time[0]>BeforeTime){ // 注文が3つ以下のとき,チャートが更新されたとき
      double Lots=AccountBalance()*25*LotsRate/Ask/100000; // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット
      BeforeTime=Time[0];
      if(Lots<0.1)return; // ロット数が少ないときは終了する
      // エントリーフラグ
      int sig_entry=EntrySignal(MAGIC);
      // 買い注文
      if(sig_entry>0){
         MyOrderSend(OP_BUY,Lots,Ask,Slippage,Ask-sl,0,COMMENT,MAGIC);
         double rsi=iRSI(NULL,0,RSIperiod,PRICE_CLOSE,1);
      }
      // 売り注文
      if(sig_entry<0){
         MyOrderSend(OP_SELL,Lots,Bid,Slippage,Bid+sl,0,COMMENT,MAGIC);
         rsi=iRSI(NULL,0,RSIperiod,PRICE_CLOSE,1);
      }
   }
   MyTrailingStop(TSPoint, MAGIC);
}