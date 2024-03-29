#define MAGIC   20200504
#define COMMENT "WindmillSigLessTrail"
#include <stderror.mqh>
#include <stdlib.mqh>

// 外部パラメータ

extern double MaxLots=0.2; // 口座残高に対する最大の注文ロットの割合
//extern double MaxLotsRate=0.8; // 口座残高に対する最大の注文ロットの割合
extern double OnceLots=0.1; // 1回の注文のロット数

extern double frictionK=0.001; // 摩擦係数
extern double sig_dtMax=500; // ミリ秒
extern double sig_dtMin=100; // ミリ秒
extern double WindmillResetTime=180; // 秒
extern double SigLevel=20; // Windmill Signalのシグナルレベル

//extern double TakeProfit=1; // 最初に設定する利食い幅
extern double ObserveWidth=0.006; // トレーリングストップ 観察幅 Trailing Stop Observe Width
extern double StopWidth=0.002; // トレーリングストップ ストップ幅 Trailing Stop Stop Width
//extern double LimitTime=2; // 決済期限(分)
/*
extern int MACDFastPeriod=5;
extern int MACDSlowPeriod=10;
extern int MACDSigPeriod=9;
extern double MACDLevel=0.05;
*/
//extern string OrderPosition="Both"; // Buy,Sell,or Both
extern uint DelTime=3; //注文キャンセルの制限時間（秒）
extern bool mail=true; // 証拠金使用率のメールお知らせ機能
extern double SendMailLevel=90; // 証拠金使用率のメールお知らせ機能
extern bool MarketFollower=true; // 順張り
extern bool ResistanceDealing=true; // 逆張り
extern bool BuyEntry=true; // 買い建て
extern bool SellEntry=true; // 売り建て
int Slippage=1; // スリッページ
color ArrowColor[6] = {Blue, Red, Blue, Red, Blue, Red};

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
   //Print("Modify error.");
   return(0);
}
// 現在価格で指値クローズ、最初から指値が設定されている場合何もしない
bool TicketLimitClose(int ticket,int slippage){
   double ModifyPrice=0;
   if(OrderSelect(ticket,SELECT_BY_TICKET)==false)return(false);
   int type = OrderType();
   if(OrderTakeProfit()!=0){
      Print("TicketLimitClose:Already setting TakeProfit.");
      return(false);
   }
   for(int i=0;i<3;i++){
      if(type==OP_BUY)ModifyPrice=Bid;
      else if(type==OP_SELL)ModifyPrice=Ask;
      int result=OrderModifyProcess(ticket,0,0,ModifyPrice,0);
      if(result==1)return(true);
      else if(result==ERR_INVALID_TICKET){
         Print("But invalid ticket is OK.");
         return(true);
      }
      else if(result==ERR_INVALID_STOPS){
         Print("But invalid stops is OK. Switching market order");
         TicketClose(ticket,slippage);
         return(true);
      }
      Sleep(100);
   }   
   Print("Limit Order:Trying 3times, But false.");
   return(false);
}

// チケットを指定して決済
bool TicketClose(int ticket,int slippage){
   //uint starttime = GetTickCount();
   for(int i=0;i<3;i++){
      int type=OrderType(); // ticketの指定をしなくていいのか
      /*
      if(GetTickCount() - starttime > MyOrderWaitingTime*1000){
         Alert("OrderClose timeout. Check the experts log.");
         return(false);
      }
      */
      if(IsTradeAllowed()==true){
         RefreshRates();
         if(OrderClose(ticket, OrderLots(), OrderClosePrice(),slippage,ArrowColor[type]) == true) return(true);
         int err = GetLastError();
         Print("[OrderCloseError] : ", err, " ", ErrorDescription(err));
         //if(err == ERR_INVALID_PRICE) break;
      }
      Sleep(1000);
   }
   Print("OrderClose error. Check the experts log.");
   return(false);
}

// 注文を送信する
int MyOrderSend(int type, double lots, double price, int slippage, double sl, double tp, string comment, int magic){
   // 注文時の矢印の色
   price = NormalizeDouble(price, Digits);
   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);
 
   uint starttime = GetTickCount();
   if(IsTradeAllowed() == true){
      RefreshRates();
      if(OrderSend(Symbol(), type, lots, price, slippage, sl, tp, comment, magic, 0, ArrowColor[type]) != -1) return(0);
      int err = GetLastError();
      Print("[OrderSendError] : ", err, " ", ErrorDescription(err));
      if(err == ERR_INVALID_PRICE) return(err);
      if(err == ERR_INVALID_STOPS) return(err);
   }
   return(-1);
}
double Windmill(){
   static double v=0,PreviousAsk=Ask;
   static uint PreviousTime=GetTickCount();
   static uint CheckTimeV=GetTickCount();
   static double PreviousV=0;
   int si1=0,si2=0;
   double vs=0,dt=0;
   
   dt=GetTickCount()-PreviousTime;
   if(dt>sig_dtMax)dt=sig_dtMax; // dtMaxを上回らないようにする
   else if(dt<sig_dtMin)dt=sig_dtMin; // dtMinを下回らないようにする
   
   if(dt!=0)vs=10000*(Ask-PreviousAsk)/dt;
   else vs=0;
   
   if(vs>0)si1=1;
   else if(vs==0)si1=0;
   else if(vs<0)si1=-1;
   
   v+=si1*pow(vs,2)*dt;
   if(v>0)si2=1;
   else if(v==0)si2=0;
   else if(v<0)si2=-1;
   
   if(MathAbs(v)<frictionK*dt)v=0;
   else v-=si2*frictionK*dt;
   
   if(v*PreviousV<=0)CheckTimeV=GetTickCount();
   if(GetTickCount()-CheckTimeV>WindmillResetTime*1000){ // WindmillResetTimeだけリッセットされずに経過したら
      v=0;
      CheckTimeV=GetTickCount();
   }
   PreviousTime=GetTickCount();
   PreviousAsk=Ask;
   PreviousV=v;
   return(v);
}
bool OrderDel(){
   int ticket = 0;
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MAGIC) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL){
         ticket = OrderTicket();
         break;
      }
   }
   if(ticket == 0) return(false);

   if(IsTradeAllowed() == true){
      if(OrderDelete(ticket) == true) return(true);
      int err = GetLastError();
      Print("[OrderDeleteError] : ", err, " ", ErrorDescription(err));
   }
   return(false);
}

void OnTick(){
   //static datetime OrderTime=0;
   static int OrderFlag=0;
   static double PreviousSig=0;
   static uint OrderTickTime=0;
   static datetime CheckTime1=0,CheckTime2=0; // 0のため最初は待ち時間なしにチェックする
   static double BuySL=0,SellSL=0;
   
   double spread=Ask-Bid;
   //double MaxLots=NormalizeDouble(AccountBalance()*25*MaxLotsRate/Bid/100000,1); // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット、口座残高からの割合で決める
   //double DepositMaintenanceRate=NormalizeDouble(100*AccountBalance()/AccountFreeMargin(),1); // 証拠金維持率
   double MarginRatio=NormalizeDouble(100*AccountMargin()/AccountEquity(),1); // 証拠金使用率=100*必要証拠金÷純資産
   //double macd=iMACD(NULL,0,MACDFastPeriod,MACDSlowPeriod,MACDSigPeriod,PRICE_CLOSE,MODE_SIGNAL,1);
   int BuyFlag=0,SellFlag=0;
   //int PosTotal=0; // オープンしているポジションの数
   //int ticket=0;
   //double v=0;
   double sig=0;
   int BuyTicket=0,SellTicket=0;
   /*
   if(!(OrderPosition=="Buy" || OrderPosition=="Sell" || OrderPosition=="Both")){
      Comment("Error: OrderPosition is Buy,Sell,or Both");
      return;
   }
   */
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()==Symbol()){
         if(OrderType()==OP_BUY){
            BuyFlag++;
            BuyTicket=OrderTicket(); // 最後のチケットだけを拾い、その１つだけのトレーリングストップを行う
         }
         else if(OrderType()==OP_SELL){
            SellFlag++;
            SellTicket=OrderTicket(); // 最後のチケットだけを拾い、その１つだけのトレーリングストップを行う
         }   
      }
   }
   /*
   if(MarginRatio>95){ // 証拠金使用率が95%を上回ったとき(ロスカット対策)
      for(i=0; i<OrdersTotal(); i++){
         if(OrderSelect(i, SELECT_BY_POS) == false) break;
         if(OrderSymbol()==Symbol() && (OrderType()==OP_BUY||OrderType()==OP_SELL)){ // ポジションが古いものから決済
            TicketClose(OrderTicket(),Slippage);
            Print("Position Close."); // クローズ
            break; // 1回だけクローズする
         }
      }
   }
   */
   if(MarginRatio>SendMailLevel && Time[0]>CheckTime2 && mail==true){ // 90%を上回ったら１バーごとにメール
      SendMail("MT4:OANDA","Margin Ratio is "+MarginRatio+"%.");
      Print("Margin Ratio is Over "+MarginRatio+"%.");
      CheckTime2=Time[0];
   }

   if(GetTickCount()-OrderTickTime>DelTime*1000 && (OrderFlag==1 || Time[0]>CheckTime1)){ // 1秒以上経つまたはCheckTime以上経っていればキャンセル
      CheckTime1=Time[0]; // リセット
      //Print("Check Limit Order.");
      if(OrderDel()){
         Print("Order Delete."); // 待機中文があればキャンセル
         OrderFlag=0;
      }   
   }
   
   
   //v=iCustom(NULL,0,"Windmill",1,frictionK,sig_dtMax,sig_dtMin,0,0); // Windmillシグナル
   //v=iCustom(NULL,0,"Windmill",0,1); // Windmillシグナル
   //if(Time[0]>BeforeTime){ // チャートが更新されたとき、かつ何も注文していないとき

   //int StartTime=60*TimeMinute(Time[0])+TimeSeconds(Time[0]);      
   //int CurrentTime=60*Minute()+Seconds();      
   //Comment("StartTime=",StartTime,"\nCurrentTime=",CurrentTime,"\nSpendTime=",CurrentTime-StartTime);
      
   sig=Windmill();
   if(PreviousSig*sig<=0)OrderFlag=0; // プラスマイナスが反転もしくはsig=0になったらフラグをおろす
   
   //MyOrderClose(Slippage,MAGIC); // 2つポジションが残っていた場合を考えて2回実行
   //MyOrderDelete(MAGIC); // 待機注文が残っていたら取り消し
   /*
   if(Lots>MaxLots)Lots=MaxLots; // 2lotsでも警告が出てしまったので、それ以下でやる→短時間のうちにオープンを繰り返したからかもしれない
   else if(Lots<0.1){
      Comment("Not enough lots");
      return; // ロット数が少ないときは終了する
   }
   */
   if(OrderFlag==0){
      if(MarketFollower==true){ // 順張り
         // 買い
         if(sig>=SigLevel && BuyFlag*OnceLots<MaxLots && BuyEntry==true){
            //MyOrderSend(OP_BUYLIMIT,OnceLots,Ask,Slippage,0,Ask+TakeProfit,COMMENT,MAGIC);
            MyOrderSend(OP_BUYLIMIT,OnceLots,Ask,Slippage,0,0,COMMENT,MAGIC);
            PreviousSig=sig;
            OrderFlag=1;
            CheckTime1=Time[0];
            OrderTickTime=GetTickCount();
            //SendMail("MT4:OANDA","Open BUY LIMIT");
         }
         // 売り
         else if(sig<=-SigLevel && SellFlag*OnceLots<MaxLots && SellEntry==true){
            //MyOrderSend(OP_SELLLIMIT,OnceLots,Bid,Slippage,0,Bid-TakeProfit,COMMENT,MAGIC);
            MyOrderSend(OP_SELLLIMIT,OnceLots,Bid,Slippage,0,0,COMMENT,MAGIC);
            PreviousSig=sig;
            OrderFlag=1;
            CheckTime1=Time[0];
            OrderTickTime=GetTickCount();
            //SendMail("MT4:OANDA","Open SELL LIMIT");
         }
      }   
      
      if(ResistanceDealing==true){ // 逆張り
         // 買い
         if(sig<=-SigLevel && BuyFlag*OnceLots<MaxLots && BuyEntry==true){
            //MyOrderSend(OP_BUYLIMIT,OnceLots,Ask,Slippage,0,Ask+TakeProfit,COMMENT,MAGIC);
            MyOrderSend(OP_BUYLIMIT,OnceLots,Ask,Slippage,0,0,COMMENT,MAGIC);
            PreviousSig=sig;
            OrderFlag=1;
            CheckTime1=Time[0];
            OrderTickTime=GetTickCount();
            //SendMail("MT4:OANDA","Open BUY LIMIT");
         }
         // 売り
         else if(sig>=SigLevel && SellFlag*OnceLots<MaxLots && SellEntry==true){
            //MyOrderSend(OP_SELLLIMIT,OnceLots,Bid,Slippage,0,Bid-TakeProfit,COMMENT,MAGIC);
            MyOrderSend(OP_SELLLIMIT,OnceLots,Bid,Slippage,0,0,COMMENT,MAGIC);
            PreviousSig=sig;
            OrderFlag=1;
            CheckTime1=Time[0];
            OrderTickTime=GetTickCount();
            //SendMail("MT4:OANDA","Open SELL LIMIT");
         }
      }   
   }
   // トレーリングストップ
   if(BuyTicket!=0){
      double newsl=Bid-StopWidth;
      if(OrderSelect(BuyTicket,SELECT_BY_TICKET) == false){
         Print("Trailing Stop:Select Error");
         return;
      }
      if(Bid>OrderOpenPrice()+ObserveWidth && newsl>BuySL){
         BuySL=newsl;
         //BuyTicket=OrderTicket();
         //Comment("BuyModify:",newsl);
      }   
      if(BuySL!=0 && BuySL>=Bid && Bid>OrderOpenPrice()+ObserveWidth-StopWidth){
         //TicketClose(BuyTicket,Slippage); // スリッページは小さくする
         TicketLimitClose(BuyTicket,Slippage); // 指値で利確できなかった場合、またトレーリングストップを行う
         BuySL=0;
      }
   }
   if(SellTicket!=0){
      newsl=Ask+StopWidth;
      if(OrderSelect(SellTicket,SELECT_BY_TICKET) == false){
         Print("Trailing Stop:Select Error");
         return;
      }
      if(Ask<OrderOpenPrice()-ObserveWidth && (newsl<SellSL || SellSL==0)){
         SellSL=newsl;
         //SellTicket=OrderTicket();
         //Comment("SellModify:",newsl);
      }   
      if(SellSL!=0 && SellSL<=Ask && Ask<OrderOpenPrice()-ObserveWidth+StopWidth){
         //TicketClose(SellTicket,Slippage); // スリッページは小さくする
         TicketLimitClose(SellTicket,Slippage); // 指値で利確できなかった場合、またトレーリングストップを行う
         SellSL=0;
      }
   }
   
   Comment("windmill=",sig,"\nBuyFlag=",BuyFlag,"\nSellFlag=",SellFlag,"\nOrderFlag=",OrderFlag,"\nMarginRatio=",MarginRatio,"%");   
}