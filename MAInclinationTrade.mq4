#include <MyLib.mqh>
#define MAGIC   20191127
#define COMMENT "MAInclinationTrade"

// 外部パラメータ
extern double LotsRate=0.2; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
extern double ObservWidth=0.005; // トレーリングストップ 観察幅 Trailing Stop Observ Width
extern double StopWidth=0.02; // トレーリングストップ ストップ幅 Trailing Stop Stop Width
extern double sl=0.01; // 損切り幅
extern double InclinationLevel=0.003; // 傾きレベル
extern int MAPeriod = 10;
extern int Diff = 1;

void OnTick(){
   static datetime BeforeTime=0;
   if(Time[0]>BeforeTime && OrdersTotal()==0){ // チャートが更新されたとき、かつ何も注文していないとき
      double inclination=iCustom(NULL,0,"MAShiftDiff",MAPeriod,Diff,0,1);
      double inclination_old=iCustom(NULL,0,"MAShiftDiff",MAPeriod,Diff,0,2);
      static int ChanceFlag=0;
      double Lots=AccountBalance()*25*LotsRate/Bid/100000; // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット
      BeforeTime=Time[0];
      if(Lots<0.1){
         Print("Not enough lots");
         return; // ロット数が少ないときは終了する
      }
      if(inclination_old<=0 && inclination>0)ChanceFlag=1; // 傾き指標が上抜けたとき
      if(inclination_old>=0 && inclination<0)ChanceFlag=-1; // 傾き指標が下抜けたとき
      //Print("inclination: ",inclination);
      // 買い注文
      if(inclination>=InclinationLevel && ChanceFlag==1){
         ChanceFlag=0;
         MyOrderSend(OP_BUY,Lots,Ask,Slippage,Ask-sl,0,COMMENT,MAGIC);
      }
      // 売り注文
      else if(inclination<=-InclinationLevel && ChanceFlag==-1){
         ChanceFlag=0;
         MyOrderSend(OP_SELL,Lots,Bid,Slippage,Bid+sl,0,COMMENT,MAGIC);
      }
   }
   TrailingStop(ObservWidth,StopWidth,MAGIC);
}