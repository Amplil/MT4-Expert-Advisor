// マイライブラリー
#include <MyLib.mqh>

// マジックナンバー
#define MAGIC   20191025
#define COMMENT "MA2CrossBinary"

// 外部パラメータ
extern double Lots = 0.1;
extern int Slippage = 3;
extern double sl=0.03; // 損切り条件の値
extern double tp=0.03; // 利確条件の値

// エントリー関数
extern double step=0.02; // パラボリックステップ
extern double maximum=0.2; // パラボリック上限
extern int RSIperiod=30; // RSIの期間
extern double RSIUpperLevel=55; // RSIアッパーレベル
extern double RSILowerLevel=45; // RSIロワーレベル

int EntrySignal(int magic)
{

   // 移動平均の計算
   double SARNow=iSAR(NULL,0,step,maximum,1);
   double SARBefo=iSAR(NULL,0,step,maximum,2);
   double rsi=iRSI(NULL,0,RSIperiod,PRICE_CLOSE,1);

   int ret = 0;
   // 買いシグナル
   if(SARBefo>Ask && SARNow<Ask && rsi>RSIUpperLevel) ret=1; // クロスの傾きが大きくなければエントリーしない
   // 売りシグナル
   if(SARBefo<Ask && SARNow>Ask && rsi<RSIUpperLevel) ret=-1; // クロスの傾きが大きくなければエントリーしない

   return(ret);
}
  
void OnTick(){
   static datetime BeforeTime=0;
   if(Time[0]>BeforeTime){ // チャート更新による売買許可
      // エントリーフラグ
      int sig_entry = EntrySignal(MAGIC);
      BeforeTime=Time[0];
      // 買い注文
      if(sig_entry > 0){
         MyOrderSend(OP_BUY, Lots, Ask, Slippage,Ask-sl,Ask+tp, COMMENT, MAGIC);
      }
      // 売り注文
      if(sig_entry < 0){
         MyOrderSend(OP_SELL, Lots, Bid, Slippage,Bid+sl,Bid-tp, COMMENT, MAGIC);
      }
   }   
}

