// マイライブラリー
#include <MyLib.mqh>

// マジックナンバー
#define MAGIC   20191025
#define COMMENT "MA2CrossBinary"

// 外部パラメータ
extern double Lots = 0.1;
extern int Slippage = 3;
extern double sl=0.1; // 損切り条件の値
extern double tp=0.1; // 利確条件の値
// extern double DiffLevel=0.0003; // MA差の売買許可レベル

// エントリー関数
extern int FastMAPeriod =60; // 短期SMAの期間
extern int SlowMAPeriod =120; // 長期SMAの期間
extern int MAKairiPeriod=120; // 移動平均乖離率の期間
extern double MAKairiLevel=0.05; // 移動平均乖離率のレベル
int EntrySignal(int magic)
{

   // 移動平均の計算
   double fastSMA1 = iMA(NULL, 0, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double fastSMA2 = iMA(NULL, 0, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 2);
   double slowSMA1 = iMA(NULL, 0, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slowSMA2 = iMA(NULL, 0, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 2);
   double makairi=iCustom(NULL,0,"MAKairi",MAKairiPeriod,0,0);

   int ret = 0;
   // 買いシグナル
   if(fastSMA2<=slowSMA2 && fastSMA1>slowSMA1 && makairi>MAKairiLevel) ret=1; // クロスの傾きが大きくなければエントリーしない
   // 売りシグナル
   if(fastSMA2>=slowSMA2 && fastSMA1<slowSMA1 && makairi<-MAKairiLevel) ret=-1; // クロスの傾きが大きくなければエントリーしない

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

