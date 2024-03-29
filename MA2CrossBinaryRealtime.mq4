//+------------------------------------------------------------------+
//|                                                    MA2Cross1.mq4 |
//|                                   Copyright (c) 2009, Toyolab FX |
//|                                         http://forex.toyolab.com |
//+------------------------------------------------------------------+
#property copyright "Copyright (c) 2009, Toyolab FX"
#property link      "http://forex.toyolab.com"

// マイライブラリー
#include <MyLib.mqh>

// マジックナンバー
#define MAGIC   20191023
#define COMMENT "MA2CrossBinaryRealtime"

// 外部パラメータ
extern double Lots = 0.1;
extern int Slippage = 3;
extern double sl=0.05; // 損切り条件の値
extern double tp=0.05; // 利確条件の値
extern double DiffLevel=0.0001; // MA差の売買許可レベル

// エントリー関数
// extern int FastMAPeriod =10; // 短期SMAの期間
// extern int SlowMAPeriod =20; // 長期SMAの期間

double ave(double &data[]){
   double sum = 0.0;
   for (int i=0; i<ArraySize(data); i++)
      sum+=data[i];
   return sum/ArraySize(data);
}
void UpdateData(double &data[], double UpdatePrice){
	for(int i=0; i<ArraySize(data)-1; i++){
		data[i] = data[i+1];
	}
	data[ArraySize(data)-1]=UpdatePrice;
}
void UpdateMA(double& ma, double &data[]){ // 移動平均の計算、アップデートのみ行えばよい
   int size=ArraySize(data);
	ma=(ma*size+data[size-1]-data[0])/size; // 更新回数がsizeに満たない場合、maは小さい値となる
}

int EntrySignal(int magic){
   static double FastMAData[300]={0.},SlowMAData[500]={0.},fastMAbefo=0.,slowMAbefo=0.,fastMA=0.,slowMA=0.;
   UpdateData(FastMAData,Ask);
   UpdateData(SlowMAData,Ask);
   UpdateMA(fastMA,FastMAData);
   UpdateMA(slowMA,SlowMAData);

   int ret = 0;
   // 買いシグナル
   if(fastMAbefo<=slowMAbefo && fastMA>slowMA && slowMAbefo-fastMAbefo+fastMA-slowMA>DiffLevel) ret = 1; // クロスの傾きが大きくなければエントリーしない
   // 売りシグナル
   if(fastMAbefo>=slowMAbefo && fastMA<slowMA && fastMAbefo-slowMAbefo+slowMA-fastMA>DiffLevel) ret = -1; // クロスの傾きが大きくなければエントリーしない
   
   fastMAbefo=fastMA;
   slowMAbefo=slowMA;
   return(ret);
}
  
void OnTick(){
   // エントリーフラグ
   int sig_entry = EntrySignal(MAGIC);
   // 買い注文
   if(sig_entry > 0){
      MyOrderSend(OP_BUY, Lots, Ask, Slippage,Ask-sl,Ask+tp, COMMENT, MAGIC);
   }
   // 売り注文
   if(sig_entry < 0){
      MyOrderSend(OP_SELL, Lots, Bid, Slippage,Bid+sl,Bid-tp, COMMENT, MAGIC);
   }
   return(0);
}

