//+------------------------------------------------------------------+
//|                                                        MyLib.mq4 |
//|                                   Copyright (c) 2009, Toyolab FX |
//|                                         http://forex.toyolab.com |
//+------------------------------------------------------------------+
#property copyright "Copyright (c) 2009, Toyolab FX"
#property link      "http://forex.toyolab.com"
#property library

// マイライブラリー
#include <MyLib.mqh>

// 注文時の矢印の色
color ArrowColor[6] = {Blue, Red, Blue, Red, Blue, Red};

// 注文待ち時間(秒)
uint MyOrderWaitingTime = 10;

// 現在のポジションのロット数（＋：買い －：売り）
double MyCurrentOrders(int type, int magic)
{
   double lots = 0.0;

   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;

      switch(type)
      {
         case OP_BUY:
            if(OrderType() == OP_BUY) lots += OrderLots();
            break;
         case OP_SELL:
            if(OrderType() == OP_SELL) lots -= OrderLots();
            break;
         case OP_BUYLIMIT:
            if(OrderType() == OP_BUYLIMIT) lots += OrderLots();
            break;
         case OP_SELLLIMIT:
            if(OrderType() == OP_SELLLIMIT) lots -= OrderLots();
            break;
         case OP_BUYSTOP:
            if(OrderType() == OP_BUYSTOP) lots += OrderLots();
            break;
         case OP_SELLSTOP:
            if(OrderType() == OP_SELLSTOP) lots -= OrderLots();
            break;
         case MY_OPENPOS:
            if(OrderType() == OP_BUY) lots += OrderLots();
            if(OrderType() == OP_SELL) lots -= OrderLots();
            break;
         case MY_LIMITPOS:
            if(OrderType() == OP_BUYLIMIT) lots += OrderLots();
            if(OrderType() == OP_SELLLIMIT) lots -= OrderLots();
            break;
         case MY_STOPPOS:
            if(OrderType() == OP_BUYSTOP) lots += OrderLots();
            if(OrderType() == OP_SELLSTOP) lots -= OrderLots();
            break;
         case MY_PENDPOS:
            if(OrderType() == OP_BUYLIMIT || OrderType() == OP_BUYSTOP) lots += OrderLots();
            if(OrderType() == OP_SELLLIMIT || OrderType() == OP_SELLSTOP) lots -= OrderLots();
            break;
         case MY_BUYPOS:
            if(OrderType() == OP_BUY || OrderType() == OP_BUYLIMIT || OrderType() == OP_BUYSTOP) lots += OrderLots();
            break;
         case MY_SELLPOS:
            if(OrderType() == OP_SELL || OrderType() == OP_SELLLIMIT || OrderType() == OP_SELLSTOP) lots -= OrderLots();
            break;
         case MY_ALLPOS:
            if(OrderType() == OP_BUY || OrderType() == OP_BUYLIMIT || OrderType() == OP_BUYSTOP) lots += OrderLots();
            if(OrderType() == OP_SELL || OrderType() == OP_SELLLIMIT || OrderType() == OP_SELLSTOP) lots -= OrderLots();
            break;
         default:
            Print("[CurrentOrdersError] : Illegel order type("+type+")");
            break;
      }
      if(lots != 0) break;
   }
   return(lots);
}

// 注文を送信する
bool MyOrderSend(int type, double lots, double price, int slippage, double sl, double tp, string comment, int magic)
{
   price = NormalizeDouble(price, Digits);
   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);
 
   uint starttime = GetTickCount();
   while(true)
   {
      if(GetTickCount() - starttime > MyOrderWaitingTime*1000)
      {
         Print("OrderSend timeout. Check the experts log.");
         return(false);
      }
      if(IsTradeAllowed() == true)
      {
         RefreshRates();
         if(OrderSend(Symbol(), type, lots, price, slippage, sl, tp, comment, magic, 0, ArrowColor[type]) != -1) return(true);
         int err = GetLastError();
         Print("[OrderSendError] : ", err, " ", ErrorDescription(err));
         if(err == ERR_INVALID_PRICE) break;
         if(err == ERR_INVALID_STOPS) break;
      }
      Sleep(100);
   }
   return(false);
}

// オープンポジションを変更する
bool MyOrderModify(double sl, double tp, int magic)
{
   int ticket = 0;
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL)
      {
         ticket = OrderTicket();
         break;
      }
   }
   if(ticket == 0) return(false);

   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);

   if(sl == 0) sl = OrderStopLoss();
   if(tp == 0) tp = OrderTakeProfit();

   if(OrderStopLoss() == sl && OrderTakeProfit() == tp) return(false);

   uint starttime = GetTickCount();
   while(true)
   {
      if(GetTickCount() - starttime > MyOrderWaitingTime*1000)
      {
         Alert("OrderModify timeout. Check the experts log.");
         return(false);
      }
      if(IsTradeAllowed() == true)
      {
         if(OrderModify(ticket, 0, sl, tp, 0, ArrowColor[type]) == true) return(true);
         int err = GetLastError();
         Print("[OrderModifyError] : ", err, " ", ErrorDescription(err));
         if(err == ERR_NO_RESULT) break;
         if(err == ERR_INVALID_STOPS) break;
      }
      Sleep(100);
   }
   return(false);
}

// オープンポジションを決済する
bool MyOrderClose(int slippage, int magic)
{
   int ticket = 0;
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL)
      {
         ticket = OrderTicket();
         break;
      }
   }
   if(ticket == 0) return(false);

   uint starttime = GetTickCount();
   while(true)
   {
      if(GetTickCount() - starttime > MyOrderWaitingTime*1000)
      {
         Alert("OrderClose timeout. Check the experts log.");
         return(false);
      }
      if(IsTradeAllowed() == true)
      {
         RefreshRates();
         if(OrderClose(ticket, OrderLots(), OrderClosePrice(), slippage, ArrowColor[type]) == true) return(true);
         int err = GetLastError();
         Print("[OrderCloseError] : ", err, " ", ErrorDescription(err));
         if(err == ERR_INVALID_PRICE) break;
      }
      Sleep(100);
   }
   return(false);
}

// 待機注文をキャンセルする
bool MyOrderDelete(int magic)
{
   int ticket = 0;
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
      {
         ticket = OrderTicket();
         break;
      }
   }
   if(ticket == 0) return(false);

   uint starttime = GetTickCount();
   while(true)
   {
      if(GetTickCount() - starttime > MyOrderWaitingTime*1000)
      {
         Alert("OrderDelete timeout. Check the experts log.");
         return(false);
      }
      if(IsTradeAllowed() == true)
      {
         if(OrderDelete(ticket) == true) return(true);
         int err = GetLastError();
         Print("[OrderDeleteError] : ", err, " ", ErrorDescription(err));
      }
      Sleep(100);
   }
   return(false);
}


// 書籍のトレーリングストップ
void MyTrailingStop(int ts,int magic){
   if(Digits==3 || Digits==5)ts*=10;
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != magic) continue;
      if(OrderType()==OP_BUY){
         double newsl=Bid-ts*Point;
         if(newsl>=OrderOpenPrice() && newsl>OrderStopLoss())MyOrderModify(newsl,0,magic);
         break;
      }
      if(OrderType()==OP_SELL){
         newsl=Ask+ts*Point;
         if(newsl<=OrderOpenPrice() && (newsl<OrderStopLoss() || OrderStopLoss()==0))MyOrderModify(newsl,0,magic);
         break;
      }
   }
}
// チケットを指定して決済
bool TicketClose(int ticket,int slippage){
   uint starttime = GetTickCount();
   while(true)
   {
      int type = OrderType();
      if(GetTickCount() - starttime > MyOrderWaitingTime*1000)
      {
         Alert("OrderClose timeout. Check the experts log.");
         return(false);
      }
      if(IsTradeAllowed() == true)
      {
         RefreshRates();
         if(OrderClose(ticket, OrderLots(), OrderClosePrice(),slippage,ArrowColor[type]) == true) return(true);
         int err = GetLastError();
         Print("[OrderCloseError] : ", err, " ", ErrorDescription(err));
         if(err == ERR_INVALID_PRICE) break;
      }
      Sleep(100);
   }
   return(false);
}
// 注文の含み損益がマイナスの場合決済
void LossCutClose(int slippage,int magic){
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i,SELECT_BY_POS)==false) break;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=magic) continue;
      int type=OrderType();
      if(type==OP_BUY || type==OP_SELL){
         int ticket=OrderTicket();
         if(OrderProfit()<0)TicketClose(ticket,slippage);
         if(OrderStopLoss()==0)TicketClose(ticket,slippage); // OrderModifyがまだ実行されておらず、損切り値が設定されていない場合も損切り
      }
   }
}
/*
// 観察幅とストップ幅のあるトレーリングストップ
void TrailingStop(double ObserveWidth,double StopWidth,int magic){
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=magic) continue;
      if(OrderType()==OP_BUY){
         double newsl=Bid-StopWidth;
         if(Bid>OrderOpenPrice()+ObserveWidth && newsl>OrderStopLoss())MyOrderModify(newsl,0,magic);
      }
      if(OrderType()==OP_SELL){
         newsl=Ask+StopWidth;
         if(Ask<OrderOpenPrice()-ObserveWidth && (newsl<OrderStopLoss() || OrderStopLoss()==0))MyOrderModify(newsl,0,magic);
      }
   }
}
// 価格からの観察幅とストップ幅のあるトレーリングストップ
void TrailingStopPrice(int type,double price,double ObserveWidth,double StopWidth,int magic){
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=magic) continue;
      if(type==OP_BUY && OrderType()==type){
         double newsl=Bid-StopWidth;
         Print("Stop Bid newsl: ",newsl);
         if(Bid>price+ObserveWidth && newsl>OrderStopLoss())MyOrderModify(newsl,0,magic);
      }
      if(type==OP_SELL && OrderType()==type){
         newsl=Ask+StopWidth;
         Print("Stop Ask newsl: ",newsl);
         if(Ask<price-ObserveWidth && (newsl<OrderStopLoss() || OrderStopLoss()==0))MyOrderModify(newsl,0,magic);
      }
   }
}

// 観察幅、ストップ幅のあるトレール注文,逆指値注文に対してされる,注文幅OrderWidthは逆指値注文で設定される
void TrailingOrder(double ObserveWidth,double StopWidth,int magic){
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS)==false)break;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=magic) continue;
      if(OrderType()==OP_BUYSTOP){
         double newsl=Ask+StopWidth;
         Print("Order Ask newsl: ",newsl);
         if(Ask<OrderOpenPrice()-ObserveWidth && newsl<OrderOpenPrice())OrderModifyProcess(OrderTicket(),newsl,0,0,0);
      }
      if(OrderType()==OP_SELLSTOP){
         newsl=Bid-StopWidth;
         Print("Order Bid newsl: ",newsl);
         if(Bid>OrderOpenPrice()+ObserveWidth && newsl>OrderOpenPrice())OrderModifyProcess(OrderTicket(),newsl,0,0,0);
      }
   }
}

// 観察幅、ストップ幅のあるトレール注文,逆指値注文に対してされる,StartPriceは買いならask値,売りならbid値,注文幅OrderWidthは逆指値注文で設定される
void TrailingOrderPrice(int type,double StartPrice,double ObserveWidth,double StopWidth,int magic){
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS)==false)break;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=magic) continue;
      if(type==OP_BUYSTOP && OrderType()==type){
         double newsl=Ask+StopWidth;
         if(Ask<StartPrice-ObserveWidth && newsl<OrderOpenPrice())OrderModifyProcess(OrderTicket(),newsl,0,0,0);
      }
      if(type==OP_SELLSTOP && OrderType()==type){
         newsl=Bid-StopWidth;
         if(Bid>StartPrice+ObserveWidth && newsl>OrderOpenPrice())OrderModifyProcess(OrderTicket(),newsl,0,0,0);
      }
   }
}
*/

// 観察幅とストップ幅のあるトレーリングストップ,リアルタイム,幅が狭くても対応できる
void TrailingStop(double ObserveWidth,double StopWidth,int magic){
   static double BuySL=0,SellSL=0;
   static int BuyTicket=0,SellTicket=0;
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=magic) continue;
      if(OrderType()==OP_BUY){
         double newsl=Bid-StopWidth;
         if(Bid>OrderOpenPrice()+ObserveWidth && newsl>BuySL){
            BuySL=newsl;
            BuyTicket=OrderTicket();
            Comment("BuyModify:",newsl);
         }   
         if(BuySL!=0 && BuySL>=Bid){
            //TicketClose(BuyTicket,3);
            TicketLimitClose(BuyTicket,3); // 指値で利確できなかった場合、またトレーリングストップを行う
            BuySL=0;
         }
      }
      if(OrderType()==OP_SELL){
         newsl=Ask+StopWidth;
         if(Ask<OrderOpenPrice()-ObserveWidth && (newsl<SellSL || SellSL==0)){
            SellSL=newsl;
            SellTicket=OrderTicket();
            Comment("SellModify:",newsl);
         }   
         if(SellSL!=0 && SellSL<=Ask){
            //TicketClose(SellTicket,3);
            TicketLimitClose(SellTicket,3); // 指値で利確できなかった場合、またトレーリングストップを行う
            SellSL=0;
         }
      }
   }
}
// 価格からの観察幅とストップ幅のあるトレーリングストップ
void TrailingStopPrice(int type,double price,double ObserveWidth,double StopWidth,int magic){
   static double BuySL=0,SellSL=0;
   static int BuyTicket=0,SellTicket=0;
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=magic) continue;
      if(type==OP_BUY && OrderType()==type){
         double newsl=Bid-StopWidth;
         if(Bid>price+ObserveWidth && newsl>BuySL){
            BuySL=newsl;
            BuyTicket=OrderTicket();
            Comment("Stop BuySL: ",BuySL);
         }
         if(BuySL!=0 && BuySL>=Bid){
            //TicketClose(BuyTicket,3);
            TicketLimitClose(BuyTicket,3); // 指値で利確できなかった場合、またトレーリングストップを行う
            BuySL=0;
         }
      }
      if(type==OP_SELL && OrderType()==type){
         newsl=Ask+StopWidth;
         if(Ask<price-ObserveWidth && (newsl<SellSL || SellSL==0)){
            SellSL=newsl;
            SellTicket=OrderTicket();
            Comment("Stop SellSL: ",SellSL);
         }   
         if(SellSL!=0 && SellSL<=Ask){
            //TicketClose(SellTicket,3);
            TicketLimitClose(SellTicket,3); // 指値で利確できなかった場合、またトレーリングストップを行う
            SellSL=0;
         }
      }
   }
}

// 注文幅、観察幅、ストップ幅のあるトレール注文,逆指値注文に対してされる,StartPriceは買いならask値,売りならbid値,注文幅OrderWidthは逆指値注文で設定される
int TrailingOrderSig(int type,double price,double OrderWidth,double ObserveWidth,double StopWidth){
   static double BuySL=0,SellSL=0;
   if(type==OP_BUYSTOP){
      double newsl=Ask+StopWidth;
      if(Ask<price-ObserveWidth && (newsl<BuySL || BuySL==0)){
         BuySL=newsl;
         Comment("Order BuySL: ",BuySL);
      }
      if((BuySL!=0&&BuySL<=Ask) || Ask>=price+OrderWidth){
         if(BuySL!=0&&BuySL<=Ask)Print("Trailing Order");
         else Print("Stop Loss Order");
         //MyOrderSend(OP_BUY,lots,Ask,3,0,0,COMMENT,MAGIC);
         BuySL=0;
         return(1);
      }
   }   
   if(type==OP_SELLSTOP){
      newsl=Bid-StopWidth;
      if(Bid>price+ObserveWidth && newsl>SellSL){
         SellSL=newsl;
         Comment("Order SellSL: ",SellSL);
      }   
      if((SellSL!=0&&SellSL>=Bid) || Bid<=price-OrderWidth){
         if(SellSL!=0&&SellSL>=Bid)Print("Trailing Order");
         else Print("Stop Loss Order");
         //MyOrderSend(OP_SELL,lots,Bid,3,0,0,COMMENT,MAGIC);
         SellSL=0;
         return(1);
      }
   }
   return(0);
}

// 待機注文も含めたエラー出力付きの注文の変更
int OrderModifyProcess(int ticket,double price,double sl,double tp,datetime expiration){
   if(ticket == 0) return(0);
   if(OrderSelect(ticket,SELECT_BY_TICKET)==false)return(0);
   sl=NormalizeDouble(sl, Digits);
   tp=NormalizeDouble(tp, Digits);
   if(price==0)price=OrderOpenPrice();
   if(sl == 0) sl=OrderStopLoss();
   if(tp == 0) tp=OrderTakeProfit();
   if(IsTradeAllowed() == true){
      if(OrderModify(ticket,price,sl,tp,expiration,ArrowColor[OrderType()]) == true) return(1);
      int err = GetLastError();
      Print("[OrderDeleteError] : ", err, " ", ErrorDescription(err));
      return(err);
   }
   Print("Modify error.");
   return(0);
}
// 最初から上抜けているところを指値クローズはエラーとなりできなかった
// 現在価格で指値クローズ
bool TicketLimitClose(int ticket,int slippage){
   double ModifyPrice=0;
   if(OrderSelect(ticket,SELECT_BY_TICKET)==false)return(false);
   int type = OrderType();
   for(int i=0;i<10;i++){
      if(type==OP_BUY)ModifyPrice=Bid;
      else if(type==OP_SELL)ModifyPrice=Ask;
      int result=OrderModifyProcess(ticket,0,0,ModifyPrice,0);
      if(result==1)return(true);
      else if(result==ERR_INVALID_TICKET){
         Print("But invalid ticket is OK.");
         return(true);
      }
      else if(result==ERR_INVALID_STOPS){
         Print("Switching market order");
         TicketClose(ticket,slippage);
         return(true);
      }
      Sleep(100);
   }   
   Print("Limit Order:Trying 10 times, But false.");
   return(false);
}

// 損切り値、利食い値のキャンセル
int SlTpCancel(int ticket){
   if(ticket == 0) return(0);
   if(OrderSelect(ticket,SELECT_BY_TICKET)==false)return(0);
   if(OrderStopLoss()==0 && OrderTakeProfit()==0)return(0);
   double price=OrderOpenPrice();
   if(IsTradeAllowed() == true){
      if(OrderModify(ticket,price,0,0,0,ArrowColor[OrderType()]) == true) return(1);
      int err = GetLastError();
      Print("[OrderDeleteError] : ", err, " ", ErrorDescription(err));
      return(err);
   }
   Print("Modify error.");
   return(0);
}
