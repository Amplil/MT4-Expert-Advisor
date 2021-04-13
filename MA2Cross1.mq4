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
#define MAGIC   20094050
#define COMMENT "MA2Cross1"

// 外部パラメータ
extern double Lots = 0.1;
extern int Slippage = 3;

// エントリー関数
extern int FastMAPeriod = 20; // 短期SMAの期間
extern int SlowMAPeriod = 40; // 長期SMAの期間
int EntrySignal(int magic)
{
   // オープンポジションの計算
   double pos = MyCurrentOrders(MY_OPENPOS, magic);

   // 移動平均の計算
   double fastSMA1 = iMA(NULL, 0, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double fastSMA2 = iMA(NULL, 0, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 2);
   double slowSMA1 = iMA(NULL, 0, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double slowSMA2 = iMA(NULL, 0, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 2);

   int ret = 0;
   // 買いシグナル
   if(pos <= 0 && fastSMA2 <= slowSMA2 && fastSMA1 > slowSMA1) ret = 1;
   // 売りシグナル
   if(pos >= 0 && fastSMA2 >= slowSMA2 && fastSMA1 < slowSMA1) ret = -1;

   return(ret);
}

// スタート関数
int start()
{
   // エントリーシグナル
   int sig_entry = EntrySignal(MAGIC);

   // 買い注文
   if(sig_entry > 0)
   {
      MyOrderClose(Slippage, MAGIC);
      MyOrderSend(OP_BUY, Lots, Ask, Slippage, 0, 0, COMMENT, MAGIC);
   }
   // 売り注文
   if(sig_entry < 0)
   {
      MyOrderClose(Slippage, MAGIC);
      MyOrderSend(OP_SELL, Lots, Bid, Slippage, 0, 0, COMMENT, MAGIC);
   }

   return(0);
}

