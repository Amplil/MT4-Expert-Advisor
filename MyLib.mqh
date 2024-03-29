//+------------------------------------------------------------------+
//|                                                        MyLib.mqh |
//|                                   Copyright (c) 2009, Toyolab FX |
//|                                         http://forex.toyolab.com |
//+------------------------------------------------------------------+
#property copyright "Copyright (c) 2009, Toyolab FX"
#property link      "http://forex.toyolab.com"

#include <stderror.mqh>
#include <stdlib.mqh>

#define MY_OPENPOS   6
#define MY_LIMITPOS  7
#define MY_STOPPOS   8
#define MY_PENDPOS   9
#define MY_BUYPOS   10
#define MY_SELLPOS  11
#define MY_ALLPOS   12

#import "MyLib.ex4"
// 現在のポジションのロット数（＋：買い －：売り）
double MyCurrentOrders(int type, int magic);
// 注文を送信する
bool MyOrderSend(int type, double lots, double price, int slippage, double sl, double tp, string comment, int magic);
// オープンポジションを変更する
bool MyOrderModify(double sl, double tp, int magic);
// オープンポジションを決済する
bool MyOrderClose(int slippage, int magic);
// 待機注文をキャンセルする
bool MyOrderDelete(int magic);
// 書籍のトレーリングストップ
void MyTrailingStop(int ts,int magic);
// チケットを指定して決済
bool TicketClose(int ticket,int slippage);
// 注文の含み損益がマイナスの場合決済
void LossCutClose(int slippage,int magic);
// 観察幅とストップ幅のあるトレーリングストップ
void TrailingStop(double ObservWidth,double StopWidth,int magic);
// 価格からの観察幅とストップ幅のあるトレーリングストップ
void TrailingStopPrice(int type,double price,double ObservWidth,double StopWidth,int magic);
// 観察幅、ストップ幅のあるトレール注文
void TrailingOrder(double ObservWidth,double StopWidth,int magic);
// 観察幅、ストップ幅のあるトレール注文,逆指値注文に対してされる,StartPriceは買いならask値,売りならbid値,注文幅OrderWidthは逆指値注文で設定される
void TrailingOrderPrice(int type,double StartPrice,double ObservWidth,double StopWidth,int magic);
// 注文幅、観察幅、ストップ幅のあるトレール注文,逆指値注文に対してされる,StartPriceは買いならask値,売りならbid値,注文幅OrderWidthは逆指値注文で設定される
int TrailingOrderSig(int type,double price,double OrderWidth,double ObserveWidth,double StopWidth);
// 待機注文も含めたエラー処理付きの注文の変更
int OrderModifyProcess(int ticket,double price,double sl,double tp,datetime expiration);
// チケットを指定して指値クローズ
bool TicketLimitClose(int ticket,int slippage);
// 損切り値、利食い値のキャンセル
int SlTpCancel(int ticket);
#import
