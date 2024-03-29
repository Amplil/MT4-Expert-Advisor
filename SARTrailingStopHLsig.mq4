// マイライブラリー
#include <MyLib.mqh>

// マジックナンバー
#define MAGIC   20191103
#define COMMENT "SARTrailingStopHL"

// 外部パラメータ
extern double LotsRate=0.2; // 口座残高に対する注文ロットの割合
extern int Slippage=3; // スリッページ
extern double sl=0.05; // 損切り条件の値

// エントリー関数
extern double step=0.01; // パラボリックステップ
extern double maximum=0.1; // パラボリック上限
extern int TSPoint=10; // トレーリングストップのポイント
extern int BandPeriod=20; // ハイローの期間

uint MyOrderWaitingTime = 10;   // 注文待ち時間(秒)
color ArrowColor[6] = {Blue, Red, Blue, Red, Blue, Red};
 // チケットを指定して決済
bool TicketClose(int ticket){
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
         if(OrderClose(ticket, OrderLots(), OrderClosePrice(),Slippage,ArrowColor[type]) == true) return(true);
         int err = GetLastError();
         Print("[OrderCloseError] : ", err, " ", ErrorDescription(err));
         if(err == ERR_INVALID_PRICE) break;
      }
      Sleep(100);
   }
   return(false);
}

int EntrySignal(int magic){

   // 移動平均の計算
   double SARNow=iSAR(NULL,0,step,maximum,1);
   double SARBefo=iSAR(NULL,0,step,maximum,2);
   double h1=High[iHighest(NULL,0,MODE_HIGH,BandPeriod,1)];
   double h2=High[iHighest(NULL,0,MODE_HIGH,BandPeriod,2)];
   double l1=Low[iLowest(NULL,0,MODE_LOW,BandPeriod,1)];
   double l2=Low[iLowest(NULL,0,MODE_LOW,BandPeriod,2)];
   static int Hsig=0;
   static int Lsig=0;

   if(h2<h1 && Hsig>=0)Hsig++;
   else if(h2>h1 && Hsig<=0)Hsig--;
   else if((h2<h1 && Hsig<0) || (h2>h1 && Hsig>0))Hsig=0;
   if(l2<l1 && Lsig>=0)Lsig++;
   else if(l2>l1 && Lsig<=0)Lsig--;
   else if((l2<l1 && Lsig<0) || (l2>l1 && Lsig>0))Lsig=0;
   
   Print("  Hsig: ",Hsig,"  Lsig: ",Lsig);
   
   int ret = 0;
   // 買いシグナル
   if(SARBefo>Bid && SARNow<Bid && Hsig>=3 && Lsig>=1){
      ret=1;
   }
   // 売りシグナル
   else if(SARBefo<Bid && SARNow>Bid && Hsig<=-1 && Lsig<=-3){
      ret=-1;
   }

   return(ret);
}
  
void OnTick(){
   static datetime BeforeTime=0;
   if(OrdersTotal()<=3 && Time[0]>BeforeTime){ // 注文が3つ以下のとき,チャートが更新されたとき
      double Lots=AccountBalance()*25*LotsRate/Bid/100000; // レバレッジ25倍、LotsRate分のロット、1通貨10万ロット
      BeforeTime=Time[0];
      if(Lots<0.1){
         Print("Not enough money");
         return; // ロット数が少ないときは終了する
      }
      // エントリーフラグ
      int sig_entry=EntrySignal(MAGIC);
      // 買い注文
      if(sig_entry>0){
         MyOrderSend(OP_BUY,Lots,Ask,Slippage,Ask-sl,0,COMMENT,MAGIC);
      }
      // 売り注文
      if(sig_entry<0){
         MyOrderSend(OP_SELL,Lots,Bid,Slippage,Bid+sl,0,COMMENT,MAGIC);
      }
   }
   MyTrailingStop(TSPoint, MAGIC);
   /*
   for(int i=0; i<OrdersTotal(); i++){
      if(OrderSelect(i, SELECT_BY_POS) == false) break;
      if(OrderSymbol() != Symbol() || OrderMagicNumber()!=MAGIC) continue;
      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL){
         double sar=iSAR(NULL,0,step,maximum,1);
         int ticket = OrderTicket();
         if(OrderProfit()<0){
            if((type==OP_BUY && sar>Bid)||(type==OP_SELL && sar<Bid)){
               TicketClose(ticket);
            }
         }
      }
   }
   */
}