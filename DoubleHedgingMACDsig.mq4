#include <MyLib.mqh>
#define MAGIC   20200212
#define COMMENT "HedgingTrailMACDsig"

// 外部パラメータ
extern double LotsRate=0.8; // 口座残高に対する注文ロットの割合
extern double MaxLots=2; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
extern double TrailPro=10.0; // Trailing Propotion
extern double OrderWidth=0.02; // 注文幅
extern double ProfitWidthStart=0.02; // 利益幅、観察幅を過ぎるとオーダーからの利益幅分以上での利確が保証される
//extern double TrOrObWStart=0.01; // トレール注文 観察幅 Trailing Order Observe Width
//extern double TrOrStWStart=0.005; // トレール注文 ストップ幅 Trailing Order Stop Width
extern double TrStObWStart=0.005; // トレーリングストップ 観察幅 Trailing Stop Observe Width
//extern double TrStStWStart=0.003; // トレーリングストップ ストップ幅 Trailing Stop Stop Width
extern double advantage=0; // アドバンテージ、両建てがすべて解消されるまでの利益分
extern int MACDFastPeriod=5;
extern int MACDSlowPeriod=10;
extern int MACDSigPeriod=9;
extern double MACDOrderLevel=0.05;
extern double MACDStopLevel=0.1;
extern double TotalAdvantage=0; // 過去も含めた合計アドバンテージ
extern bool EveningUp=false; // 
extern int ProfitGuaranteeLevel=1; // 利益保証機能のレベル
extern bool DoubleHedgingFunc=false; // 2重両建て機能
extern double InclinationLevel=0.005;

// static double OrderWidth=OrderWidthStart; // 注文幅,0.02くらいから注文、低すぎるとタイムアウトになる
static double ProfitWidth=ProfitWidthStart; // 利益幅、観察幅を過ぎるとオーダーからの利益幅分以上での利確が保証される
//static double TrOrObW=TrOrObWStart; // トレール注文 観察幅 Trailing Order Observe Width
//static double TrOrStW=TrOrStWStart; // トレール注文 ストップ幅 Trailing Order Stop Width
static double TrStObW=TrStObWStart; // トレーリングストップ 観察幅 Trailing Stop Observe Width
//static double TrStStW=TrStStWStart; // トレーリングストップ ストップ幅 Trailing Stop Stop Width
static int TradeFinishNum=0; // すべての取引が終わった回数
static int EndFlag=0;

//static double a=0;
bool MACDsig(int type){
   double sig1=iMACD(NULL,0,MACDFastPeriod,MACDSlowPeriod,MACDSigPeriod,PRICE_CLOSE,MODE_SIGNAL,1);
   double sig2=iMACD(NULL,0,MACDFastPeriod,MACDSlowPeriod,MACDSigPeriod,PRICE_CLOSE,MODE_SIGNAL,2);
   double inclination=sig1-sig2;
   //Print("inclination=",inclination);
   if(type==OP_BUYSTOP && sig1>=MACDOrderLevel && inclination>InclinationLevel)return(true); // 買いのストップ注文保留があり注文するとき
   else if(type==OP_SELLSTOP && sig1<=-MACDOrderLevel && inclination<-InclinationLevel)return(true); // 売りのストップ注文保留があり注文するとき
   else if( type==OP_BUY && ((sig2>MACDStopLevel&&MACDStopLevel>=sig1)||(sig2>MACDOrderLevel&&MACDOrderLevel>=sig1)) ){
      return(true); // 買いのポジションがありストップするとき
   }   
   else if( type==OP_SELL && ((sig2<-MACDStopLevel&&-MACDStopLevel<=sig1)||(sig2<-MACDOrderLevel&&-MACDOrderLevel<=sig1)) ){
      return(true); // 売りのポジションがありストップするとき
   }   
   return(false);
}

// ストップMACD
void StopMACD(int ticket,double ObserveWidth,double ProfitW){
   static double BuySL=0,SellSL=0;
   if(OrderSelect(ticket,SELECT_BY_TICKET) == false) return;
   if(OrderTakeProfit()!=0)return;
   if(OrderType()==OP_BUY){
      if(ProfitW!=0 && BuySL==0 && Bid>OrderOpenPrice()+ObserveWidth){ // ProfitWが0のときは利益確保を設けない
         BuySL=OrderOpenPrice()+ProfitW; // ask価格である注文価格にSL価格を合わせる
         Print("Set BuySL:",BuySL);
      }
      if(OrderProfit()>0 && ((BuySL!=0&&Bid<=BuySL) || MACDsig(OP_BUY)==true)){
         TicketLimitClose(ticket,3);
         BuySL=0;
      }
   }
   else if(OrderType()==OP_SELL){
      if(ProfitW!=0 && SellSL==0 && Ask<OrderOpenPrice()-ObserveWidth){ // ProfitWが0のときは利益確保を設けない
         SellSL=OrderOpenPrice()-ProfitW; // bid価格である注文価格にSL価格を合わせる
         Print("Set SellSL:",SellSL);
      }
      if(OrderProfit()>0 && ((SellSL!=0&&SellSL<=Ask) || MACDsig(OP_SELL)==true)){
         TicketLimitClose(ticket,3);
         SellSL=0;
      }
   }
}
// 価格からのストップMACD
void StopPriceMACD(int ticket,double price,double ObserveWidth,double ProfitW){
   static double BuySL=0,SellSL=0;
   if(OrderSelect(ticket,SELECT_BY_TICKET) == false) return;
   if(OrderTakeProfit()!=0)return;
   if(OrderType()==OP_BUY){
      if(ProfitW!=0 && BuySL==0 && Bid>price+ObserveWidth){ // ProfitWが0のときは利益確保を設けない
         BuySL=price+ProfitW; // ask価格である注文価格にSL価格を合わせる
         Print("Set BuySL:",BuySL);
      }
      if(OrderProfit()>0 && ((BuySL!=0&&Bid<=BuySL) || MACDsig(OP_BUY)==true)){
         TicketLimitClose(ticket,3);
         BuySL=0;
      }
   }
   else if(OrderType()==OP_SELL){
      if(ProfitW!=0 && SellSL==0 && Ask<price-ObserveWidth){ // ProfitWが0のときは利益確保を設けない
         SellSL=price-ProfitW; // bid価格である注文価格にSL価格を合わせる
         Print("Set SellSL:",SellSL);
      }
      if(OrderProfit()>0 && ((SellSL!=0&&SellSL<=Ask) || MACDsig(OP_SELL)==true)){
         TicketLimitClose(ticket,3);
         SellSL=0;
      }   
   }
}
// priceからの注文幅のあるMACD注文
int OrderPriceMACD(int type,double StartPrice,double Lots){
   if(type==OP_BUYSTOP){
      if((StartPrice!=0&&Bid>StartPrice+OrderWidth) || MACDsig(OP_BUYSTOP)==true){ // priceは売りのオープン価格か買いのクローズ価格だからどちらもBid価格
         if(StartPrice!=0&&Bid>StartPrice+OrderWidth)Print("Stop Loss Order Buy");
         MyOrderSend(OP_BUY,Lots,Ask,Slippage,0,0,COMMENT,MAGIC);
         return(1);
      }
   }
   else if(type==OP_SELLSTOP){
      if((StartPrice!=0&&Ask<=StartPrice-OrderWidth) || MACDsig(OP_SELLSTOP)==true){ // priceは買いのオープン価格か売りのクローズ価格だからどちらもAsk価格
         if(StartPrice!=0&&Ask<StartPrice-OrderWidth)Print("Stop Loss Order Sell");
         MyOrderSend(OP_SELL,Lots,Bid,Slippage,0,0,COMMENT,MAGIC);
         return(1);
      }
   }
   return(0);
}

void OnTick(){
//   static int printi=0;
   static int BuyFlag=-1,SellFlag=-1; // 初期は-1
   static int BuyTicketBf=0,SellTicketBf=0,BuyTicketAf=0,SellTicketAf=0;
   static double BuyPriceBf=0,SellPriceBf=0,BuyPriceAf=0,SellPriceAf=0; // 買いの注文価格,売りの注文価格,決済価格
   static double BuyClosePrice=0,SellClosePrice=0; // 買いの決済価格,売りの決済価格
   static double PriceWidth=0; // 価格幅
   static double UnrealizedLossBf=0; // 過去の含み損、プラス表示
   int BuyFlagNow=0,SellFlagNow=0; // 以前とは違い0はポジションなし、1はポジション1つあり、2はポジション2つありとする
   double TPPrice=0; // アドバンテージを使った利確となる価格、買いの決済だろうと売りの決済だろうと基準線は変わらない
   double spread=Ask-Bid;
   double Lots=NormalizeDouble(AccountFreeMargin()*25*LotsRate/Bid/100000,1); // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット、利用可能な証拠金からの割合で決める
   int PosTotal=0; // オープンしているポジションの数
   //double MADiff=Bid-iMA(NULL,0,MACDFastPeriod,0,MODE_SMA,PRICE_CLOSE,1); // 移動平均乖離、MACDの期間を使う
   //Print("Lots=",Lots);
   if(EveningUp==true && EndFlag==1){
      Comment("End");
      return;
   }
   if(Lots>MaxLots)Lots=MaxLots; // 2lotsでも警告が出てしまったので、それ以下でやる
   else if(Lots<0.1){
      Comment("Not enough lots");
      return; // ロット数が少ないときは終了する
   }
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol()==Symbol())PosTotal++;
   }
   if(PosTotal!=BuyFlag+SellFlag || (BuyFlag==-1&&SellFlag==-1)){ // オープンしているポジションの数が前と違うとき、または初期化されているとき
      for(i=0;i<OrdersTotal();i++){
         if(OrderSelect(i, SELECT_BY_POS) == false) break;
         if(OrderSymbol()!=Symbol()) continue;
         switch(OrderType()){
            case OP_BUY:
               BuyFlagNow++;
               if(BuyFlagNow==1){
                  BuyTicketBf=OrderTicket();
                  BuyPriceBf=OrderOpenPrice();
               }
               else if(BuyFlagNow==2){
                  if(OrderOpenPrice()<BuyPriceBf){
                     BuyTicketAf=OrderTicket();
                     BuyPriceAf=OrderOpenPrice();
                  }
                  else{
                     BuyTicketAf=BuyTicketBf;
                     BuyPriceAf=BuyPriceBf;
                     BuyTicketBf=OrderTicket();
                     BuyPriceBf=OrderOpenPrice();
                  }
               }
               break;
            case OP_SELL:
               SellFlagNow++;
               if(SellFlagNow==1){
                  SellTicketBf=OrderTicket();
                  SellPriceBf=OrderOpenPrice();
               }
               else if(SellFlagNow==2){
                  if(OrderOpenPrice()>SellPriceBf){
                     SellTicketAf=OrderTicket();
                     SellPriceAf=OrderOpenPrice();
                  }   
                  else{
                     SellTicketAf=SellTicketBf;
                     SellPriceAf=SellPriceBf;
                     SellTicketBf=OrderTicket();
                     SellPriceBf=OrderOpenPrice();
                  }
               }
               break;
         }
      }
      UnrealizedLossBf=0;
      if(BuyFlagNow>=1){
         if(OrderSelect(BuyTicketBf,SELECT_BY_TICKET) == false)return;
         UnrealizedLossBf+=OrderProfit();
      }
      if(SellFlagNow>=1){
         if(OrderSelect(SellTicketBf,SELECT_BY_TICKET) == false)return;
         UnrealizedLossBf+=OrderProfit();
      }
      UnrealizedLossBf=MathAbs(UnrealizedLossBf); // プラス表示のため
   }   
   else{
      BuyFlagNow=BuyFlag;
      SellFlagNow=SellFlag;
   }
   //Print("OrdersTotal()=",OrdersTotal()," , BuyFlagNow=",BuyFlagNow," , SellFlagNow=",SellFlagNow," , BuyFlag=",BuyFlag," , SellFlag=",SellFlag);
   //Print("BuyPriceBf=",BuyPriceBf," , BuyPriceAf=",BuyPriceAf," , SellPriceBf=",SellPriceBf," , SellPriceAf=",SellPriceAf);
   //Print("BuyTicketBf=",BuyTicketBf," , BuyTicketAf=",BuyTicketAf," , SellTicketBf=",SellTicketBf," , SellTicketAf=",SellTicketAf);
   
   if(BuyFlagNow==0 && SellFlagNow==0){
      TotalAdvantage=0; // 両方とも利確されたらアドバンテージをリセットする
      if((BuyFlag==1&&SellFlag==0) || (BuyFlag==0&&SellFlag==1)){ // すべての取引が終わったとき
         TradeFinishNum++;
         //SellClosePrice=0;
         //BuyClosePrice=0;
         //Print("Reset Trail Width and Advantage.");
         if(EveningUp==true){
            EndFlag=1;
            Comment("End");
            return;
         }
      }
      if(MACDsig(OP_BUYSTOP)==true && High[0]<=Bid && High[1]<=Bid){ // 高値以上のときにオープン
         MyOrderSend(OP_BUY,Lots,Ask,Slippage,0,0,COMMENT,MAGIC);
      }   
      else if(MACDsig(OP_SELLSTOP)==true && Low[0]>=Bid && Low[1]>=Bid){ // 安値以下のときにオープン
         MyOrderSend(OP_SELL,Lots,Bid,Slippage,0,0,COMMENT,MAGIC);
      }         
   }   
   else if(BuyFlagNow==1 && SellFlagNow==0){
      if((BuyFlag==0&&SellFlag==0) || (BuyFlag==-1&&SellFlag==-1)){ // 初期化されたときも含む
         PriceWidth=1/TrailPro;
         if(BuyFlag==0&&SellFlag==0)SellClosePrice=0;
         else if(BuyFlag==-1&&SellFlag==-1)SellClosePrice=Ask;
      }
      else if(BuyFlag==1&&SellFlag==1){
         SlTpCancel(BuyTicketBf); // 指値クローズの指値注文が残っていたら削除
         PriceWidth=MathAbs(BuyPriceBf-Ask);
         if(OrderSelect(OrdersHistoryTotal()-1,SELECT_BY_POS,MODE_HISTORY)==True){
            TotalAdvantage+=OrderProfit();
            SellClosePrice=OrderClosePrice();
            Print("TotalAdvantage=",TotalAdvantage);
         }
         else Print("advantage error");
      }
      if(ProfitGuaranteeLevel>=1)ProfitWidth=TrailPro*PriceWidth*ProfitWidthStart;
      else ProfitWidth=0;
      TrStObW=TrStObWStart; // 片方だけならトレーリングストップでproposalなし
      TPPrice=BuyPriceBf-TotalAdvantage/(100000*Lots); // アドバンテージを使う
      StopPriceMACD(BuyTicketBf,TPPrice,TrStObW,ProfitWidth);
      if(SellClosePrice==0)OrderPriceMACD(OP_SELLSTOP,BuyPriceBf,Lots);
      else OrderPriceMACD(OP_SELLSTOP,SellClosePrice,Lots);
   }
   else if(BuyFlagNow==0 && SellFlagNow==1){
      if((BuyFlag==0&&SellFlag==0) || (BuyFlag==0&&SellFlag==1)){ // 初期化されたときも含む
         PriceWidth=1/TrailPro;
         if(BuyFlag==0&&SellFlag==0)BuyClosePrice=0;
         else if(BuyFlag==-1&&SellFlag==-1)BuyClosePrice=Bid;
      }
      else if(BuyFlag==1&&SellFlag==1){
         SlTpCancel(SellTicketBf); // 指値クローズの指値注文が残っていたら削除
         PriceWidth=MathAbs(SellPriceBf-Bid);
         if(OrderSelect(OrdersHistoryTotal()-1,SELECT_BY_POS,MODE_HISTORY)==True){
            TotalAdvantage+=OrderProfit();
            BuyClosePrice=OrderClosePrice();
            Print("TotalAdvantage=",TotalAdvantage);
         }
         else Print("advantage error");
      }
      if(ProfitGuaranteeLevel>=1)ProfitWidth=TrailPro*PriceWidth*ProfitWidthStart;
      else ProfitWidth=0;
      TrStObW=TrStObWStart; // 片方だけならトレーリングストップでproposalなし
      TPPrice=SellPriceBf+TotalAdvantage/(100000*Lots); // アドバンテージを使う
      StopPriceMACD(SellTicketBf,TPPrice,TrStObW,ProfitWidth);
      if(BuyClosePrice==0)OrderPriceMACD(OP_BUYSTOP,SellPriceBf,Lots);
      else OrderPriceMACD(OP_BUYSTOP,BuyClosePrice,Lots);
   }
   
   else if(BuyFlagNow==1 && SellFlagNow==1){
      if((BuyFlag==1&&SellFlag==0) || (BuyFlag==0&&SellFlag==1) || (BuyFlag==-1&&SellFlag==-1)){ // 初期化されたときも含む
         BuyClosePrice=Bid;
         SellClosePrice=Ask;
         PriceWidth=MathAbs(BuyPriceBf-SellPriceBf+spread);
         SlTpCancel(BuyTicketBf);
         SlTpCancel(SellTicketBf);
      }
      if((BuyFlag==2&&SellFlag==1) || (BuyFlag==1&&SellFlag==2)){ // end flag は立てない
         //Print("Reset Trail Width and Advantage.");
         //SellClosePrice=0;
         //BuyClosePrice=0;
         if(OrderSelect(OrdersHistoryTotal()-1,SELECT_BY_POS,MODE_HISTORY)==True){
            TotalAdvantage+=OrderProfit()+advantage;
            if(BuyFlag==2&&SellFlag==1)BuyClosePrice=OrderClosePrice();
            else if(BuyFlag==1&&SellFlag==2)SellClosePrice=OrderClosePrice();
            Print("TotalAdvantage=",TotalAdvantage);
         }
         else Print("advantage error");
         if(TotalAdvantage>UnrealizedLossBf){
            if(TicketClose(BuyTicketBf,Slippage)==true){
               if(TicketClose(SellTicketBf,Slippage)==true){
                  advantage=0;
                  TotalAdvantage=0;
                  Print("All after position close.");
                  return;
               }   
            }
         }
      }
      advantage=0; // 両方とも利確されたらアドバンテージをリセットする
      if(DoubleHedgingFunc==true){ // 2重両建て機能がONのときにオーダー
         if(SellPriceBf+ProfitWidthStart<Bid && Ask<BuyPriceBf-ProfitWidthStart){
            if(MACDsig(OP_BUYSTOP)==true && High[0]<=Bid && High[1]<=Bid){ // 買った価格よりもProfitWidthStart分遠ざかり、高値以上のときにオープン
               MyOrderSend(OP_BUY,Lots,Ask,Slippage,0,0,COMMENT,MAGIC);
            }   
            else if(MACDsig(OP_SELLSTOP)==true && Low[0]>=Bid && Low[1]>=Bid){ // 売った価格よりもProfitWidthStart分遠ざかり、安値以下のときにオープン
               MyOrderSend(OP_SELL,Lots,Bid,Slippage,0,0,COMMENT,MAGIC);
            }   
         }
      }   
      ProfitWidth=TrailPro*PriceWidth*ProfitWidthStart;
      TrStObW=TrailPro*PriceWidth*TrStObWStart; // 両建てならば決済しかない
      //TrStStW=TrailPro*PriceWidth*TrStStWStart;
      if(ProfitGuaranteeLevel>=2)ProfitWidth=TrailPro*PriceWidth*ProfitWidthStart;
      else ProfitWidth=0;
      
      if(BuyClosePrice==0)StopMACD(BuyTicketBf,TrStObW,ProfitWidth); // 両建てのときはアドバンテージを使わない、レベル2で利益確保をする
      else StopPriceMACD(BuyTicketBf,BuyClosePrice,TrStObW,ProfitWidth);
      
      if(SellClosePrice==0)StopMACD(SellTicketBf,TrStObW,ProfitWidth); // 両建てのときはアドバンテージを使わない、レベル2で利益確保をする
      else StopPriceMACD(SellTicketBf,SellClosePrice,TrStObW,ProfitWidth);
   }   
   else if(BuyFlagNow==2&&SellFlagNow==1){
      if((BuyFlag==1&&SellFlag==1) || (BuyFlag==-1&&SellFlag==-1)){ // 初期化されたときも含む
         PriceWidth=1/TrailPro;
         if(BuyFlag==1&&SellFlag==1)SellClosePrice=0;
         else if(BuyFlag==-1&&SellFlag==-1)SellClosePrice=Ask;
      }
      else if(BuyFlag==2&&SellFlag==2){
         SlTpCancel(BuyTicketAf); // 指値クローズの指値注文が残っていたら削除
         PriceWidth=MathAbs(BuyPriceAf-Ask);
         if(OrderSelect(OrdersHistoryTotal()-1,SELECT_BY_POS,MODE_HISTORY)==True){
            advantage+=OrderProfit();
            SellClosePrice=OrderClosePrice();
            Print("advantage=",advantage);
         }
         else Print("advantage error");
         if(TotalAdvantage+advantage>UnrealizedLossBf){
            if(TicketClose(BuyTicketBf,Slippage)==true){
               if(TicketClose(SellTicketBf,Slippage)==true){
                  advantage=0;
                  TotalAdvantage=0;
                  Print("All after position close.");
                  return;
               }
            }
         }
      }
      if(ProfitGuaranteeLevel==2)ProfitWidth=TrailPro*PriceWidth*ProfitWidthStart;
      else ProfitWidth=0; // ProfitGuaranteeLevel==2のときだけ利益確保を行う
      //TrOrObW=TrailPro*PriceWidth*TrOrObWStart;
      //TrOrStW=TrailPro*PriceWidth*TrOrStWStart;
      TrStObW=TrStObWStart; // 片方だけならトレーリングストップでproposalなし
      //TrStStW=TrStStWStart;
      
      TPPrice=BuyPriceAf-advantage/(100000*Lots); // アドバンテージを使う
      StopPriceMACD(BuyTicketAf,TPPrice,TrStObW,ProfitWidth);
      if(SellClosePrice==0)OrderPriceMACD(OP_SELLSTOP,BuyPriceAf,Lots);
      else OrderPriceMACD(OP_SELLSTOP,SellClosePrice,Lots);
   }
   else if(BuyFlagNow==1 && SellFlagNow==2){
      if((BuyFlag==1&&SellFlag==1) || (BuyFlag==-1&&SellFlag==-1)){ // 初期化されたときも含む
         PriceWidth=1/TrailPro;
         if(BuyFlag==1&&SellFlag==1)BuyClosePrice=0;
         else if(BuyFlag==-1&&SellFlag==-1)BuyClosePrice=Bid;
      }
      else if(BuyFlag==2&&SellFlag==2){
         SlTpCancel(SellTicketAf); // 指値クローズの指値注文が残っていたら削除
         PriceWidth=MathAbs(SellPriceAf-Bid);
         if(OrderSelect(OrdersHistoryTotal()-1,SELECT_BY_POS,MODE_HISTORY)==True){
            advantage+=OrderProfit();
            BuyClosePrice=OrderClosePrice();
            Print("advantage=",advantage);
         }
         else Print("advantage error");
         if(TotalAdvantage+advantage>UnrealizedLossBf){
            if(TicketClose(BuyTicketBf,Slippage)==true){
               if(TicketClose(SellTicketBf,Slippage)==true){
                  advantage=0;
                  TotalAdvantage=0;
                  Print("All after position close.");
                  return;
               }
            }
         }
      }
      if(ProfitGuaranteeLevel==2)ProfitWidth=TrailPro*PriceWidth*ProfitWidthStart;
      else ProfitWidth=0; // ProfitGuaranteeLevel==2のときだけ利益確保を行う
      //TrOrObW=TrailPro*PriceWidth*TrOrObWStart;
      //TrOrStW=TrailPro*PriceWidth*TrOrStWStart;
      TrStObW=TrStObWStart; // 片方だけならトレーリングストップでproposalなし
      //TrStStW=TrStStWStart;
      
      TPPrice=SellPriceAf+advantage/(100000*Lots); // アドバンテージを使う
      StopPriceMACD(SellTicketAf,TPPrice,TrStObW,ProfitWidth);
      if(BuyClosePrice==0)OrderPriceMACD(OP_BUYSTOP,SellPriceAf,Lots);
      else OrderPriceMACD(OP_BUYSTOP,BuyClosePrice,Lots);
   }
   else if(BuyFlagNow==2 && SellFlagNow==2){
      if((BuyFlag==2&&SellFlag==1) || (BuyFlag==1&&SellFlag==2) || (BuyFlag==-1&&SellFlag==-1)){ // 初期化されたときも含む
         SlTpCancel(BuyTicketAf);
         SlTpCancel(SellTicketAf);
         PriceWidth=MathAbs(BuyPriceAf-SellPriceAf+spread);
         //BuyClosePrice=0;
         //SellClosePrice=0;
      }
      ProfitWidth=TrailPro*PriceWidth*ProfitWidthStart;
      TrStObW=TrailPro*PriceWidth*TrStObWStart; // 両建てならば決済しかない
      //TrStStW=TrailPro*PriceWidth*TrStStWStart;
      if(ProfitGuaranteeLevel>=2)ProfitWidth=TrailPro*PriceWidth*ProfitWidthStart;
      else ProfitWidth=0;
      StopMACD(BuyTicketBf,TrStObW,ProfitWidth); // 両建てのときはアドバンテージを使わない、レベル2で利益確保をする
      StopMACD(SellTicketBf,TrStObW,ProfitWidth); // 両建てのときはアドバンテージを使わない、レベル2で利益確保をする
   }
   
   BuyFlag=BuyFlagNow;
   SellFlag=SellFlagNow;
   Comment("TrailPro*PriceWidth=",TrailPro*PriceWidth,"\n TrStObW=",TrStObW,"\n ProfitWidth=",ProfitWidth,"\n advantage=",advantage,
   "\n TradeFinishNum=",TradeFinishNum,"\n TPPrice=",TPPrice,"\n BuyClosePrice=",BuyClosePrice,"\n SellClosePrice=",SellClosePrice,"\n TotalAdvantage=",TotalAdvantage,"\n UnrealizedLossBf=",UnrealizedLossBf,"\n PosTotal=",PosTotal);
}