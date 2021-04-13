//+------------------------------------------------------------------+
//|                                                    MA2Cross1.mq4 |
//|                                   Copyright (c) 2009, Toyolab FX |
//|                                         http://forex.toyolab.com |
//+------------------------------------------------------------------+
#property copyright "Copyright (c) 2009, Toyolab FX"
#property link      "http://forex.toyolab.com"

// �}�C���C�u�����[
#include <MyLib.mqh>

// �}�W�b�N�i���o�[
#define MAGIC   20094050
#define COMMENT "MA2Cross1"

// �O���p�����[�^
extern double Lots = 0.1;
extern int Slippage = 3;

// �G���g���[�֐�
extern int FastMAPeriod = 20; // �Z��SMA�̊���
extern int SlowMAPeriod = 40; // ����SMA�̊���
int EntrySignal(int magic)
{
   // �I�[�v���|�W�V�����̌v�Z
   double pos = MyCurrentOrders(MY_OPENPOS, magic);

   // �ړ����ς̌v�Z
   double fastSMA1 = iMA(NULL, 0, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double fastSMA2 = iMA(NULL, 0, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 2);
   double slowSMA1 = iMA(NULL, 0, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double slowSMA2 = iMA(NULL, 0, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 2);

   int ret = 0;
   // �����V�O�i��
   if(pos <= 0 && fastSMA2 <= slowSMA2 && fastSMA1 > slowSMA1) ret = 1;
   // ����V�O�i��
   if(pos >= 0 && fastSMA2 >= slowSMA2 && fastSMA1 < slowSMA1) ret = -1;

   return(ret);
}

// �X�^�[�g�֐�
int start()
{
   // �G���g���[�V�O�i��
   int sig_entry = EntrySignal(MAGIC);

   // ��������
   if(sig_entry > 0)
   {
      MyOrderClose(Slippage, MAGIC);
      MyOrderSend(OP_BUY, Lots, Ask, Slippage, 0, 0, COMMENT, MAGIC);
   }
   // ���蒍��
   if(sig_entry < 0)
   {
      MyOrderClose(Slippage, MAGIC);
      MyOrderSend(OP_SELL, Lots, Bid, Slippage, 0, 0, COMMENT, MAGIC);
   }

   return(0);
}

