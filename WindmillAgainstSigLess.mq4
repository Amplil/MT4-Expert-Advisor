#include <MyLib.mqh>
#define MAGIC   20200415
#define COMMENT "WindmillAgainstSigLess"
//#include <MyLib.mqh>

// 外部パラメータ

extern double MaxLots=0.5; // 口座残高に対する最大の注文ロットの割合
//extern double MaxLotsRate=0.8; // 口座残高に対する最大の注文ロットの割合
extern double OnceLots=0.1; // 1回の注文のロット数
extern int Slippage=3; // スリッページ
//extern double ObserveWidth=0.006; // トレーリングストップ 観察幅 Trailing Stop Observe Width
//extern double StopWidth=0.003; // トレーリングストップ ストップ幅 Trailing Stop Stop Width

extern double frictionK=0.001; // 摩擦係数
extern double sig_dtMax=500; // ミリ秒
extern double sig_dtMin=100; // ミリ秒
extern double WindmillResetTime=180; // 秒

extern double SigLevel=50; // Windmill Signalのシグナルレベル
extern double TakeProfit=0.005; // Windmill Signalのシグナルレベル
//extern double LimitTime=2; // 決済期限(分)
/*
extern int MACDFastPeriod=5;
extern int MACDSlowPeriod=10;
extern int MACDSigPeriod=9;
extern double MACDLevel=0.05;
*/
extern string OrderPosition="Both"; // Buy,Sell,or Both
extern bool mail=true; // 証拠金使用率のメールお知らせ機能

// 注文を送信する
int MyOrderSend(int type, double lots, double price, int slippage, double sl, double tp, string comment, int magic)
{
   // 注文時の矢印の色
   color ArrowColor[6] = {Blue, Red, Blue, Red, Blue, Red};
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
   
   double spread=Ask-Bid;
   //double MaxLots=NormalizeDouble(AccountBalance()*25*MaxLotsRate/Bid/100000,1); // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット、口座残高からの割合で決める
   //double DepositMaintenanceRate=NormalizeDouble(100*AccountBalance()/AccountFreeMargin(),1); // 証拠金維持率
   double MarginRatio=NormalizeDouble(100*AccountMargin()/AccountEquity(),1); // 証拠金使用率=100*必要証拠金÷純資産
   //double macd=iMACD(NULL,0,MACDFastPeriod,MACDSlowPeriod,MACDSigPeriod,PRICE_CLOSE,MODE_SIGNAL,1);
   int BuyFlag=0,SellFlag=0;
   //int PosTotal=0; // オープンしているポジションの数
   int ticket=0;
   //double v=0;
   double sig=0;
   
   if(!(OrderPosition=="Buy" || OrderPosition=="Sell" || OrderPosition=="Both")){
      Comment("Error: OrderPosition is Buy,Sell,or Both");
      return;
   }
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()==Symbol()){
         if(OrderType()==OP_BUY)BuyFlag++;
         else if(OrderType()==OP_SELL)SellFlag++;
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
   if(MarginRatio>90 && Time[0]>CheckTime2 && mail==true){ // 90%を上回ったら１バーごとにメール
      SendMail("MT4:OANDA","Margin Ratio is "+MarginRatio+"%");
      Print("Margin Ratio is Over 90%.");
      CheckTime2=Time[0];
   }

   if(GetTickCount()-OrderTickTime>1000 && (OrderFlag==1 || Time[0]>CheckTime1)){ // 1秒以上経つまたはCheckTime以上経っていればキャンセル
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
      // 買い
      if(sig<=-SigLevel && BuyFlag*OnceLots<MaxLots && (OrderPosition=="Both"||OrderPosition=="Buy")){ // 逆張り
         //MyOrderSend(OP_SELL,Lots,Bid,Slippage,0,Bid-TakeProfit,COMMENT,MAGIC); // TakeProfitはスプレッドを含まない値
         //MyOrderSend(OP_SELLLIMIT,Lots,Bid,Slippage,0,Bid-TakeProfit,COMMENT,MAGIC); // TakeProfitはスプレッドを含まない値
         MyOrderSend(OP_BUYLIMIT,OnceLots,Ask,Slippage,0,Ask+TakeProfit,COMMENT,MAGIC); // 逆張り
         PreviousSig=sig;
         OrderFlag=1;
         CheckTime1=Time[0];
         OrderTickTime=GetTickCount();
         //SendMail("MT4:OANDA","Open BUY LIMIT");
      }
      // 売り
      else if(sig>=SigLevel && SellFlag*OnceLots<MaxLots && (OrderPosition=="Both"||OrderPosition=="Sell")){ // 逆張り
         //MyOrderSend(OP_BUY,Lots,Ask,Slippage,0,Ask+TakeProfit,COMMENT,MAGIC); // TakeProfitはスプレッドを含まない値
         //MyOrderSend(OP_BUYLIMIT,Lots,Ask,Slippage,0,Ask+TakeProfit,COMMENT,MAGIC); // TakeProfitはスプレッドを含まない値
         MyOrderSend(OP_SELLLIMIT,OnceLots,Bid,Slippage,0,Bid-TakeProfit,COMMENT,MAGIC); // 逆張り
         PreviousSig=sig;
         OrderFlag=1;
         CheckTime1=Time[0];
         OrderTickTime=GetTickCount();
         //SendMail("MT4:OANDA","Open SELL LIMIT");
      }
   }
   //TrailingOrder(type,StartPrice,toow,tosw,MAGIC);
   //TrailingStop(ObserveWidth,StopWidth,MAGIC);
   /*
   for(int i=0; i<OrdersTotal(); i++){
      if(ticket=OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()==Symbol()){
         if(OrderFlag==1 && Bid>=OrderOpenPrice()+TakeProfit)TicketLimitClose(ticket,Slippage);
         if(OrderFlag==-1 && Ask<=OrderOpenPrice()-TakeProfit)TicketLimitClose(ticket,Slippage);
         
      }
   }
      */

   Comment("windmill=",sig,"\nBuyFlag=",BuyFlag,"\nSellFlag=",SellFlag,"\nOrderFlag=",OrderFlag,"\nMarginRatio=",MarginRatio,"%");   
}