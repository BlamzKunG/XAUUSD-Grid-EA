//+------------------------------------------------------------------+
//|                             XAUUSD_Adaptive_MeanReversion_EA.mq5 |
//|                                  Copyright 2026, BlamzKunG        |
//|                          https://github.com/BlamzKunG/XAUUSD-Grid-EA |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, BlamzKunG"
#property link        "https://github.com/BlamzKunG/XAUUSD-Grid-EA"
#property version     "1.10"
#property description "High-Performance Adaptive Mean-Reversion Grid EA for XAUUSD (Gold)"
#property description "Optimized: Single-Pass Basket Stats, Cached Indicators & Multi-TF Filters"
#property strict

//--- Standard Library Includes
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_TP_MODE
{
   TP_MODE_HYBRID         = 0, // Hybrid (Money Target OR ATR Distance)
   TP_MODE_PERCENT_BALANCE= 1, // % of Balance Target (e.g. 0.5%)
   TP_MODE_FIXED_USD      = 2, // Fixed USD Target ($)
   TP_MODE_ATR_DISTANCE   = 3  // Weighted Average Entry +/- (ATR * Factor)
};

enum ENUM_LOT_STRATEGY
{
   LOT_STRAT_FIXED        = 0, // Fixed Lot (e.g. 0.01 every level)
   LOT_STRAT_MILD_MULT    = 1, // Mild Multiplier (1.10x - 1.20x max)
   LOT_STRAT_RISK_DYNAMIC = 2  // Dynamic Lot (Calculated from Equity % Risk)
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct SBasketInfo
{
   int      count;
   double   total_lots;
   double   profit;
   double   breakeven;
   double   lowest_price;
   double   highest_price;
   double   last_lot;
   double   last_price;
   datetime oldest_time;
   datetime newest_time;

   void Reset()
   {
      count         = 0;
      total_lots    = 0.0;
      profit        = 0.0;
      breakeven     = 0.0;
      lowest_price  = DBL_MAX;
      highest_price = 0.0;
      last_lot      = 0.0;
      last_price    = 0.0;
      oldest_time   = 0;
      newest_time   = 0;
   }
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

//=== 1. GENERAL & IDENTIFICATION ===
input group "=== [1] General & Identification ==="
input ulong                InpMagicNumber          = 20250301;       // Magic Number
input string               InpTradeComment         = "XAU_MeanRev";  // Order Comment Prefix
input bool                 InpAllowNewEntries      = true;           // Allow Opening New Baskets

//=== 2. TIMEFRAMES & FILTER SETUP ===
input group "=== [2] Multi-Timeframe Filter Setup ==="
input ENUM_TIMEFRAMES      InpEntryTF              = PERIOD_M15;     // Entry Timeframe (M15 Recommended)
input ENUM_TIMEFRAMES      InpTrendTF              = PERIOD_H1;      // Trend Filter Timeframe (H1 Recommended)

// H1 Trend Filter (EMA 50 / 200 + ADX)
input int                  InpEMA_Fast             = 50;             // [H1] Fast EMA Period
input int                  InpEMA_Slow             = 200;            // [H1] Slow EMA Period
input int                  InpMaxEMADiffPoints     = 2000;           // [H1] Max Distance between EMA50 & EMA200 (Points)
input int                  InpADX_Period           = 14;             // [H1] ADX Period
input double               InpMaxADXForEntry       = 28.0;           // [H1] Max ADX for Entry (Above this = Strong Trend)
input double               InpTrendEscapeADX       = 32.0;           // [H1] Trend Escape ADX (Trigger Emergency Freeze)

// M15 Mean-Reversion Entry Filters (RSI + Bollinger Bands)
input int                  InpRSI_Period           = 14;             // [M15] RSI Period
input double               InpBuyRSI_Level         = 35.0;           // [M15] Buy Oversold RSI Level (RSI < Level)
input double               InpSellRSI_Level        = 65.0;           // [M15] Sell Overbought RSI Level (RSI > Level)
input int                  InpBB_Period            = 20;             // [M15] Bollinger Bands Period
input double               InpBB_Deviation         = 2.0;            // [M15] Bollinger Bands Deviation

//=== 3. DYNAMIC GRID ENGINE ===
input group "=== [3] Dynamic ATR Grid Engine ==="
input int                  InpATR_Period           = 14;             // [M15] ATR Period
input double               InpGridATRMultiplier    = 1.4;            // Grid Step ATR Multiplier
input double               InpMinGridStepUSD       = 3.5;            // Minimum Grid Step ($ USD price distance, e.g. $3.50)
input double               InpMaxGridStepUSD       = 12.0;           // Maximum Grid Step ($ USD price distance, e.g. $12.00)
input int                  InpMaxGridLevels        = 5;              // Maximum Grid Levels per Basket (Strict Cap)

//=== 4. LOT MANAGEMENT & SIZING ===
input group "=== [4] Lot Management & Sizing ==="
input ENUM_LOT_STRATEGY    InpLotStrategy          = LOT_STRAT_FIXED;// Lot Strategy (Fixed / Mild Mult / Dynamic)
input double               InpInitialLot           = 0.01;           // Initial Lot Size
input double               InpLotMultiplier        = 1.15;           // Mild Lot Multiplier (Keep <= 1.20)
input double               InpMaxSingleLot         = 0.10;           // Max Lot Size per Single Order
input double               InpMaxExposureLots      = 0.25;           // Max Cumulative Lots in a Basket
input double               InpRiskPerBasketPct     = 3.0;            // Max Equity Risk % per Basket (for Dynamic Sizing)

//=== 5. BASKET TAKE PROFIT & EXITS ===
input group "=== [5] Basket Take Profit ==="
input ENUM_TP_MODE         InpTPMode               = TP_MODE_HYBRID; // Take Profit Mode
input double               InpBasketTPPercent      = 0.50;           // Basket TP (% of Balance, e.g. 0.5%)
input double               InpBasketTPUSD          = 15.0;           // Basket TP ($ USD Fixed, e.g. $15.00)
input double               InpBasketTP_ATR_Factor  = 0.30;           // TP Distance from Weighted Average (ATR_M15 * Factor)
input bool                 InpUseBasketTrailing    = true;           // Enable Basket Trailing Stop
input double               InpTrailStartUSD        = 10.0;           // Trail Start Target ($ USD)
input double               InpTrailStepUSD         = 3.0;            // Trail Step / Lock-in Distance ($ USD)

//=== 6. STOP LOSS & EMERGENCY PROTECTION ===
input group "=== [6] Risk Management & Emergency SL ==="
input double               InpEquityStopPercent    = 8.0;            // Equity Drawdown Hard Stop % (Close All & Pause)
input bool                 InpUseEmergencyATR_SL   = true;           // Emergency SL based on ATR(H1) from First Entry
input double               InpEmergencySL_ATR_Mult = 3.5;            // Emergency SL ATR(H1) Multiplier (e.g. 3.5x H1 ATR)
input bool                 InpUseTrendEscape       = true;           // Enable Trend Escape Safety Cut
input double               InpTrendEscapeMaxLossUSD= 60.0;           // Max Loss to Trigger Trend Escape Cut ($ USD)
input double               InpMarginLevelFreeze    = 200.0;          // Margin Guard: Stop New Grid if Margin Level % < threshold
input double               InpMarginEmergencyCut   = 120.0;          // Margin Emergency: Cut worst losing order if Margin % < threshold
input double               InpDailyLossLimitPct    = 3.0;            // Daily Max Loss Limit (% of Balance, 0 to disable)
input double               InpDailyProfitTargetPct = 1.5;            // Daily Profit Target (% of Balance, 0 to disable)
input int                  InpCooldownMinutes      = 15;             // Cooldown Buffer after Basket Close (Minutes)

//=== 7. TIME & SPREAD FILTERS ===
input group "=== [7] Time & Spread Filters ==="
input bool                 InpUseSpreadFilter      = true;           // Enable Max Spread Filter
input int                  InpMaxSpreadPoints      = 45;             // Max Allowed Spread (Points)
input bool                 InpUseTimeFilter        = true;           // Enable Trading Session Filter
input int                  InpStartHour            = 7;              // Session Start Hour (UTC / Server Time)
input int                  InpEndHour              = 21;             // Session End Hour (UTC / Server Time)
input bool                 InpAvoidAsianNight      = false;          // Avoid Low Liquidity Asian Midnight (22:00-06:00)
input bool                 InpFridayCloseEarly     = true;           // Stop Opening on Friday Afternoon
input int                  InpFridayStopHour       = 18;             // Friday Stop Hour

//=== 8. DASHBOARD & VISUALS ===
input group "=== [8] Dashboard & Visuals ==="
input bool                 InpShowDashboard        = true;           // Show Real-time HUD Dashboard

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS & STATE VARIABLES                                 |
//+------------------------------------------------------------------+
CTrade         g_trade;
CPositionInfo  g_pos;
CAccountInfo   g_account;
CSymbolInfo    g_symbol;

// Indicator Handles
int            g_h_rsi_m15       = INVALID_HANDLE;
int            g_h_bb_m15        = INVALID_HANDLE;
int            g_h_atr_m15       = INVALID_HANDLE;
int            g_h_atr_h1        = INVALID_HANDLE;
int            g_h_adx_h1        = INVALID_HANDLE;
int            g_h_ema_fast_h1   = INVALID_HANDLE;
int            g_h_ema_slow_h1   = INVALID_HANDLE;

// Cached Indicator Data
datetime       g_last_bar_time   = 0;
double         g_cached_rsi      = 50.0;
double         g_cached_bb_upper = 0.0;
double         g_cached_bb_lower = 0.0;
double         g_cached_atr_m15  = 4.0;
double         g_cached_atr_h1   = 15.0;
double         g_cached_adx_h1   = 15.0;
double         g_cached_ema_fast = 0.0;
double         g_cached_ema_slow = 0.0;

// Daily & State Tracking
datetime       g_last_day_reset  = 0;
datetime       g_last_basket_close_time = 0;
double         g_day_start_balance = 0.0;
double         g_realized_pl_day = 0.0;
bool           g_daily_lockout   = false;
bool           g_equity_stop_hit = false;

// Basket Trailing State
double         g_buy_peak_profit = 0.0;
double         g_sell_peak_profit= 0.0;

// First Entry Reference Prices
double         g_buy_first_price = 0.0;
double         g_sell_first_price= 0.0;

// Single-Pass Basket Stats
SBasketInfo    g_buy_basket;
SBasketInfo    g_sell_basket;

// Forward Declarations
void UpdateBasketInfo();
void RefreshIndicatorCache();
bool CheckEntryFilters(ENUM_POSITION_TYPE posType, string &reason);
bool CheckTrendEscape(ENUM_POSITION_TYPE posType);
double CalculateDynamicGridStepUSD();
double CalculateNextLot(ENUM_POSITION_TYPE posType, int currentLevel);
double NormalizeLotSize(double lot);
bool OpenOrder(ENUM_POSITION_TYPE posType, double lot, int level);
void ManageBasketExits();
void ManageGridExpansion();
void CheckNewEntries();
bool ProcessSafetyGuards();
void CloseBasketPositions(ENUM_POSITION_TYPE posType);
void CloseAllPositions();
void CutWorstOrder();
double CalculateAccountDrawdownPercent();
void CheckDailyReset(bool forceRecalculate);
void ResetDailyState();
void RenderHUD();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!g_symbol.Name(_Symbol))
   {
      Print("[ERROR] Failed to initialize SymbolInfo for ", _Symbol);
      return INIT_FAILED;
   }
   g_symbol.Refresh();

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   // Initialize M15 Indicator Handles
   g_h_rsi_m15 = iRSI(_Symbol, InpEntryTF, InpRSI_Period, PRICE_CLOSE);
   g_h_bb_m15  = iBands(_Symbol, InpEntryTF, InpBB_Period, 0, InpBB_Deviation, PRICE_CLOSE);
   g_h_atr_m15 = iATR(_Symbol, InpEntryTF, InpATR_Period);

   // Initialize H1 Indicator Handles
   g_h_atr_h1      = iATR(_Symbol, InpTrendTF, InpATR_Period);
   g_h_adx_h1      = iADX(_Symbol, InpTrendTF, InpADX_Period);
   g_h_ema_fast_h1 = iMA(_Symbol, InpTrendTF, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_h_ema_slow_h1 = iMA(_Symbol, InpTrendTF, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   if(g_h_rsi_m15 == INVALID_HANDLE || g_h_bb_m15 == INVALID_HANDLE || g_h_atr_m15 == INVALID_HANDLE ||
      g_h_atr_h1 == INVALID_HANDLE || g_h_adx_h1 == INVALID_HANDLE || g_h_ema_fast_h1 == INVALID_HANDLE ||
      g_h_ema_slow_h1 == INVALID_HANDLE)
   {
      Print("[ERROR] Failed to initialize indicator handles.");
      return INIT_FAILED;
   }

   ResetDailyState();
   RefreshIndicatorCache();
   UpdateBasketInfo();

   EventSetTimer(1);

   Print("=====================================================");
   Print(" [XAUUSD Adaptive Mean-Reversion EA v1.10] Optimized Initialized");
   Print(" Symbol: ", _Symbol, " | Magic: ", InpMagicNumber);
   Print("=====================================================");

   if(InpShowDashboard && !MQLInfoInteger(MQL_OPTIMIZATION))
      RenderHUD();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   if(g_h_rsi_m15 != INVALID_HANDLE) IndicatorRelease(g_h_rsi_m15);
   if(g_h_bb_m15 != INVALID_HANDLE) IndicatorRelease(g_h_bb_m15);
   if(g_h_atr_m15 != INVALID_HANDLE) IndicatorRelease(g_h_atr_m15);
   if(g_h_atr_h1 != INVALID_HANDLE) IndicatorRelease(g_h_atr_h1);
   if(g_h_adx_h1 != INVALID_HANDLE) IndicatorRelease(g_h_adx_h1);
   if(g_h_ema_fast_h1 != INVALID_HANDLE) IndicatorRelease(g_h_ema_fast_h1);
   if(g_h_ema_slow_h1 != INVALID_HANDLE) IndicatorRelease(g_h_ema_slow_h1);

   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function (High Speed)                                |
//+------------------------------------------------------------------+
void OnTick()
{
   g_symbol.RefreshRates();

   // 1. Refresh Indicator Cache on new M15 bar
   datetime currentBarTime = iTime(_Symbol, InpEntryTF, 0);
   if(currentBarTime != g_last_bar_time)
   {
      g_last_bar_time = currentBarTime;
      RefreshIndicatorCache();
      CheckDailyReset(true);
   }

   // 2. Single-Pass Basket Stats Update
   UpdateBasketInfo();

   // 3. Safety Guards & Drawdown Protection
   if(ProcessSafetyGuards())
      return;

   // 4. Manage Basket Take Profit & Trailing Stop
   ManageBasketExits();

   // 5. Manage Grid Expansion
   ManageGridExpansion();

   // 6. Check for New Basket Entries
   CheckNewEntries();
}

//+------------------------------------------------------------------+
//| Timer function (1-second tick for HUD & safety)                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   g_symbol.RefreshRates();
   UpdateBasketInfo();
   ProcessSafetyGuards();

   if(InpShowDashboard && !MQLInfoInteger(MQL_OPTIMIZATION))
      RenderHUD();
}

//+------------------------------------------------------------------+
//| SINGLE-PASS BASKET STATISTICS                                    |
//+------------------------------------------------------------------+
void UpdateBasketInfo()
{
   g_buy_basket.Reset();
   g_sell_basket.Reset();

   double sumBuyPriceLot = 0.0;
   double sumSellPriceLot = 0.0;

   int totalPositions = PositionsTotal();
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Symbol() == _Symbol && g_pos.Magic() == InpMagicNumber)
         {
            ENUM_POSITION_TYPE pType = g_pos.PositionType();
            double volume  = g_pos.Volume();
            double price   = g_pos.PriceOpen();
            double pnl     = g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
            datetime time  = g_pos.Time();

            if(pType == POSITION_TYPE_BUY)
            {
               g_buy_basket.count++;
               g_buy_basket.total_lots += volume;
               g_buy_basket.profit += pnl;
               sumBuyPriceLot += (volume * price);

               if(price < g_buy_basket.lowest_price) g_buy_basket.lowest_price = price;
               if(price > g_buy_basket.highest_price) g_buy_basket.highest_price = price;

               if(g_buy_basket.oldest_time == 0 || time < g_buy_basket.oldest_time)
                  g_buy_basket.oldest_time = time;
               if(time > g_buy_basket.newest_time)
               {
                  g_buy_basket.newest_time = time;
                  g_buy_basket.last_lot    = volume;
                  g_buy_basket.last_price  = price;
               }
            }
            else if(pType == POSITION_TYPE_SELL)
            {
               g_sell_basket.count++;
               g_sell_basket.total_lots += volume;
               g_sell_basket.profit += pnl;
               sumSellPriceLot += (volume * price);

               if(price < g_sell_basket.lowest_price) g_sell_basket.lowest_price = price;
               if(price > g_sell_basket.highest_price) g_sell_basket.highest_price = price;

               if(g_sell_basket.oldest_time == 0 || time < g_sell_basket.oldest_time)
                  g_sell_basket.oldest_time = time;
               if(time > g_sell_basket.newest_time)
               {
                  g_sell_basket.newest_time = time;
                  g_sell_basket.last_lot    = volume;
                  g_sell_basket.last_price  = price;
               }
            }
         }
      }
   }

   if(g_buy_basket.total_lots > 0)
      g_buy_basket.breakeven = NormalizeDouble(sumBuyPriceLot / g_buy_basket.total_lots, _Digits);
   if(g_sell_basket.total_lots > 0)
      g_sell_basket.breakeven = NormalizeDouble(sumSellPriceLot / g_sell_basket.total_lots, _Digits);

   if(g_buy_basket.lowest_price == DBL_MAX) g_buy_basket.lowest_price = 0.0;
   if(g_sell_basket.lowest_price == DBL_MAX) g_sell_basket.lowest_price = 0.0;
}

//+------------------------------------------------------------------+
//| REFRESH INDICATOR CACHE                                          |
//+------------------------------------------------------------------+
void RefreshIndicatorCache()
{
   if(g_h_rsi_m15 != INVALID_HANDLE)
   {
      double buf[1];
      if(CopyBuffer(g_h_rsi_m15, 0, 0, 1, buf) > 0) g_cached_rsi = buf[0];
   }

   if(g_h_bb_m15 != INVALID_HANDLE)
   {
      double bufUpper[1], bufLower[1];
      if(CopyBuffer(g_h_bb_m15, 1, 0, 1, bufUpper) > 0) g_cached_bb_upper = bufUpper[0];
      if(CopyBuffer(g_h_bb_m15, 2, 0, 1, bufLower) > 0) g_cached_bb_lower = bufLower[0];
   }

   if(g_h_atr_m15 != INVALID_HANDLE)
   {
      double buf[1];
      if(CopyBuffer(g_h_atr_m15, 0, 0, 1, buf) > 0) g_cached_atr_m15 = buf[0];
   }

   if(g_h_atr_h1 != INVALID_HANDLE)
   {
      double buf[1];
      if(CopyBuffer(g_h_atr_h1, 0, 0, 1, buf) > 0) g_cached_atr_h1 = buf[0];
   }

   if(g_h_adx_h1 != INVALID_HANDLE)
   {
      double buf[1];
      if(CopyBuffer(g_h_adx_h1, 0, 0, 1, buf) > 0) g_cached_adx_h1 = buf[0];
   }

   if(g_h_ema_fast_h1 != INVALID_HANDLE)
   {
      double buf[1];
      if(CopyBuffer(g_h_ema_fast_h1, 0, 0, 1, buf) > 0) g_cached_ema_fast = buf[0];
   }

   if(g_h_ema_slow_h1 != INVALID_HANDLE)
   {
      double buf[1];
      if(CopyBuffer(g_h_ema_slow_h1, 0, 0, 1, buf) > 0) g_cached_ema_slow = buf[0];
   }
}

//+------------------------------------------------------------------+
//| ENTRY FILTER CHECK                                               |
//+------------------------------------------------------------------+
bool CheckEntryFilters(ENUM_POSITION_TYPE posType, string &reason)
{
   reason = "PASS";

   // 1. General EA Lockouts
   if(g_equity_stop_hit)
   {
      reason = "EQUITY_STOP_LOCKED";
      return false;
   }
   if(g_daily_lockout)
   {
      reason = "DAILY_LOCKOUT";
      return false;
   }
   if(!InpAllowNewEntries)
   {
      reason = "NEW_ENTRIES_DISABLED";
      return false;
   }

   // 2. Post-Basket Cooldown Timer
   if(g_last_basket_close_time > 0 && InpCooldownMinutes > 0)
   {
      long elapsedSeconds = (long)(TimeCurrent() - g_last_basket_close_time);
      if(elapsedSeconds < (InpCooldownMinutes * 60))
      {
         long remainingMins = (InpCooldownMinutes * 60 - elapsedSeconds) / 60;
         reason = StringFormat("COOLDOWN (%d min left)", remainingMins + 1);
         return false;
      }
   }

   // 3. Mutual Basket Exclusion
   if(posType == POSITION_TYPE_BUY && g_sell_basket.count > 0)
   {
      reason = "SELL_BASKET_ACTIVE";
      return false;
   }
   if(posType == POSITION_TYPE_SELL && g_buy_basket.count > 0)
   {
      reason = "BUY_BASKET_ACTIVE";
      return false;
   }

   // 4. Max Spread Filter
   if(InpUseSpreadFilter)
   {
      long currentSpread = g_symbol.Spread();
      if(currentSpread > InpMaxSpreadPoints)
      {
         reason = StringFormat("HIGH_SPREAD (%d > %d)", currentSpread, InpMaxSpreadPoints);
         return false;
      }
   }

   // 5. Session & Time Filter
   if(InpUseTimeFilter)
   {
      MqlDateTime dt;
      TimeCurrent(dt);

      if(InpFridayCloseEarly && dt.day_of_week == 5 && dt.hour >= InpFridayStopHour)
      {
         reason = "FRIDAY_EARLY_STOP";
         return false;
      }

      if(InpAvoidAsianNight && (dt.hour >= 22 || dt.hour < 6))
      {
         reason = "ASIAN_NIGHT_FILTER";
         return false;
      }

      if(dt.hour < InpStartHour || dt.hour > InpEndHour)
      {
         reason = StringFormat("OFF_SESSION (%02d:00)", dt.hour);
         return false;
      }
   }

   // 6. H1 Trend Filter (ADX & EMA Sideway Check)
   if(g_cached_adx_h1 > InpMaxADXForEntry)
   {
      reason = StringFormat("H1_ADX_HIGH (%.1f > %.1f Trend)", g_cached_adx_h1, InpMaxADXForEntry);
      return false;
   }

   if(g_cached_ema_fast > 0 && g_cached_ema_slow > 0)
   {
      double emaDistPts = MathAbs(g_cached_ema_fast - g_cached_ema_slow) / _Point;
      if(emaDistPts > InpMaxEMADiffPoints)
      {
         reason = StringFormat("EMA_DIST_HIGH (%.0f > %d)", emaDistPts, InpMaxEMADiffPoints);
         return false;
      }
   }

   // 7. M15 Mean-Reversion Signals (RSI & Bollinger Bands)
   if(posType == POSITION_TYPE_BUY && g_cached_rsi >= InpBuyRSI_Level)
   {
      reason = StringFormat("RSI_NOT_OVERSOLD (%.1f >= %.1f)", g_cached_rsi, InpBuyRSI_Level);
      return false;
   }
   if(posType == POSITION_TYPE_SELL && g_cached_rsi <= InpSellRSI_Level)
   {
      reason = StringFormat("RSI_NOT_OVERBOUGHT (%.1f <= %.1f)", g_cached_rsi, InpSellRSI_Level);
      return false;
   }

   double currentPrice = (posType == POSITION_TYPE_BUY) ? g_symbol.Ask() : g_symbol.Bid();
   if(posType == POSITION_TYPE_BUY && g_cached_bb_lower > 0 && currentPrice > g_cached_bb_lower)
   {
      reason = "PRICE_ABOVE_LOWER_BB";
      return false;
   }
   if(posType == POSITION_TYPE_SELL && g_cached_bb_upper > 0 && currentPrice < g_cached_bb_upper)
   {
      reason = "PRICE_BELOW_UPPER_BB";
      return false;
   }

   // 8. Margin Level Guard
   double marginLevel = g_account.MarginLevel();
   if(marginLevel > 0 && marginLevel < InpMarginLevelFreeze)
   {
      reason = StringFormat("MARGIN_FROZEN (%.1f%% < %.1f%%)", marginLevel, InpMarginLevelFreeze);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| CHECK NEW BASKET ENTRIES                                         |
//+------------------------------------------------------------------+
void CheckNewEntries()
{
   if(g_buy_basket.count == 0 && g_sell_basket.count == 0)
   {
      string buyReason;
      if(CheckEntryFilters(POSITION_TYPE_BUY, buyReason))
      {
         double lot = CalculateNextLot(POSITION_TYPE_BUY, 0);
         if(OpenOrder(POSITION_TYPE_BUY, lot, 0))
         {
            g_buy_first_price = g_symbol.Ask();
            g_buy_peak_profit = 0.0;
         }
         return;
      }

      string sellReason;
      if(CheckEntryFilters(POSITION_TYPE_SELL, sellReason))
      {
         double lot = CalculateNextLot(POSITION_TYPE_SELL, 0);
         if(OpenOrder(POSITION_TYPE_SELL, lot, 0))
         {
            g_sell_first_price = g_symbol.Bid();
            g_sell_peak_profit = 0.0;
         }
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| MANAGE GRID EXPANSION                                            |
//+------------------------------------------------------------------+
void ManageGridExpansion()
{
   double marginLevel = g_account.MarginLevel();
   if(marginLevel > 0 && marginLevel < InpMarginLevelFreeze)
      return;

   double currentDD = CalculateAccountDrawdownPercent();
   if(currentDD >= (InpEquityStopPercent * 0.75))
      return;

   double gridStepUSD = CalculateDynamicGridStepUSD();

   // 1. Manage BUY Basket Grid Expansion
   if(g_buy_basket.count > 0 && g_buy_basket.count < InpMaxGridLevels)
   {
      if(!CheckTrendEscape(POSITION_TYPE_BUY))
      {
         double lastBuyPrice = (g_buy_basket.last_price > 0) ? g_buy_basket.last_price : g_buy_basket.lowest_price;
         double targetBuyPrice = lastBuyPrice - gridStepUSD;

         if(g_symbol.Ask() <= targetBuyPrice)
         {
            double nextLot = CalculateNextLot(POSITION_TYPE_BUY, g_buy_basket.count);
            if((g_buy_basket.total_lots + nextLot) <= InpMaxExposureLots)
            {
               OpenOrder(POSITION_TYPE_BUY, nextLot, g_buy_basket.count);
            }
         }
      }
   }

   // 2. Manage SELL Basket Grid Expansion
   if(g_sell_basket.count > 0 && g_sell_basket.count < InpMaxGridLevels)
   {
      if(!CheckTrendEscape(POSITION_TYPE_SELL))
      {
         double lastSellPrice = (g_sell_basket.last_price > 0) ? g_sell_basket.last_price : g_sell_basket.highest_price;
         double targetSellPrice = lastSellPrice + gridStepUSD;

         if(g_symbol.Bid() >= targetSellPrice)
         {
            double nextLot = CalculateNextLot(POSITION_TYPE_SELL, g_sell_basket.count);
            if((g_sell_basket.total_lots + nextLot) <= InpMaxExposureLots)
            {
               OpenOrder(POSITION_TYPE_SELL, nextLot, g_sell_basket.count);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| MANAGE BASKET EXITS                                              |
//+------------------------------------------------------------------+
void ManageBasketExits()
{
   // 1. BUY Basket Exits
   if(g_buy_basket.count > 0)
   {
      bool exitTriggered = false;

      // Option 1: Money / % Balance Target
      if(InpTPMode == TP_MODE_HYBRID || InpTPMode == TP_MODE_PERCENT_BALANCE || InpTPMode == TP_MODE_FIXED_USD)
      {
         double targetUSD = InpBasketTPUSD;
         if(InpTPMode == TP_MODE_PERCENT_BALANCE || InpTPMode == TP_MODE_HYBRID)
            targetUSD = g_account.Balance() * (InpBasketTPPercent / 100.0);

         if(g_buy_basket.profit >= targetUSD)
            exitTriggered = true;
      }

      // Option 2: Weighted Average + ATR Target Distance
      if(InpTPMode == TP_MODE_HYBRID || InpTPMode == TP_MODE_ATR_DISTANCE)
      {
         double tpPrice = g_buy_basket.breakeven + (g_cached_atr_m15 * InpBasketTP_ATR_Factor);
         if(g_symbol.Bid() >= tpPrice && g_buy_basket.profit > 0)
            exitTriggered = true;
      }

      // Option 3: Basket Trailing Stop
      if(InpUseBasketTrailing)
      {
         if(g_buy_basket.profit >= InpTrailStartUSD)
         {
            if(g_buy_basket.profit > g_buy_peak_profit)
               g_buy_peak_profit = g_buy_basket.profit;

            double trailingFloor = g_buy_peak_profit - InpTrailStepUSD;
            if(g_buy_basket.profit <= trailingFloor && trailingFloor > 0)
               exitTriggered = true;
         }
         else
         {
            g_buy_peak_profit = 0.0;
         }
      }

      // Option 4: Emergency Distance Stop Loss (ATR H1 based from First Entry)
      if(InpUseEmergencyATR_SL && g_buy_first_price > 0)
      {
         double emergencySL = g_buy_first_price - (g_cached_atr_h1 * InpEmergencySL_ATR_Mult);
         if(g_symbol.Bid() <= emergencySL)
            exitTriggered = true;
      }

      if(exitTriggered)
      {
         CloseBasketPositions(POSITION_TYPE_BUY);
         g_buy_peak_profit = 0.0;
         g_buy_first_price = 0.0;
         g_last_basket_close_time = TimeCurrent();
         CheckDailyReset(true);
      }
   }
   else
   {
      g_buy_peak_profit = 0.0;
      g_buy_first_price = 0.0;
   }

   // 2. SELL Basket Exits
   if(g_sell_basket.count > 0)
   {
      bool exitTriggered = false;

      if(InpTPMode == TP_MODE_HYBRID || InpTPMode == TP_MODE_PERCENT_BALANCE || InpTPMode == TP_MODE_FIXED_USD)
      {
         double targetUSD = InpBasketTPUSD;
         if(InpTPMode == TP_MODE_PERCENT_BALANCE || InpTPMode == TP_MODE_HYBRID)
            targetUSD = g_account.Balance() * (InpBasketTPPercent / 100.0);

         if(g_sell_basket.profit >= targetUSD)
            exitTriggered = true;
      }

      if(InpTPMode == TP_MODE_HYBRID || InpTPMode == TP_MODE_ATR_DISTANCE)
      {
         double tpPrice = g_sell_basket.breakeven - (g_cached_atr_m15 * InpBasketTP_ATR_Factor);
         if(g_symbol.Ask() <= tpPrice && g_sell_basket.profit > 0)
            exitTriggered = true;
      }

      if(InpUseBasketTrailing)
      {
         if(g_sell_basket.profit >= InpTrailStartUSD)
         {
            if(g_sell_basket.profit > g_sell_peak_profit)
               g_sell_peak_profit = g_sell_basket.profit;

            double trailingFloor = g_sell_peak_profit - InpTrailStepUSD;
            if(g_sell_basket.profit <= trailingFloor && trailingFloor > 0)
               exitTriggered = true;
         }
         else
         {
            g_sell_peak_profit = 0.0;
         }
      }

      if(InpUseEmergencyATR_SL && g_sell_first_price > 0)
      {
         double emergencySL = g_sell_first_price + (g_cached_atr_h1 * InpEmergencySL_ATR_Mult);
         if(g_symbol.Ask() >= emergencySL)
            exitTriggered = true;
      }

      if(exitTriggered)
      {
         CloseBasketPositions(POSITION_TYPE_SELL);
         g_sell_peak_profit = 0.0;
         g_sell_first_price = 0.0;
         g_last_basket_close_time = TimeCurrent();
         CheckDailyReset(true);
      }
   }
   else
   {
      g_sell_peak_profit = 0.0;
      g_sell_first_price = 0.0;
   }
}

//+------------------------------------------------------------------+
//| TREND ESCAPE FILTER CHECK                                        |
//+------------------------------------------------------------------+
bool CheckTrendEscape(ENUM_POSITION_TYPE posType)
{
   if(!InpUseTrendEscape) return false;

   if(posType == POSITION_TYPE_BUY)
   {
      if(g_cached_adx_h1 >= InpTrendEscapeADX && g_cached_ema_fast < g_cached_ema_slow && g_symbol.Bid() < g_cached_ema_slow)
      {
         double loss = MathAbs(g_buy_basket.profit);
         if(loss >= InpTrendEscapeMaxLossUSD && g_buy_basket.profit < 0)
         {
            CloseBasketPositions(POSITION_TYPE_BUY);
            g_last_basket_close_time = TimeCurrent();
            CheckDailyReset(true);
         }
         return true;
      }
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      if(g_cached_adx_h1 >= InpTrendEscapeADX && g_cached_ema_fast > g_cached_ema_slow && g_symbol.Ask() > g_cached_ema_slow)
      {
         double loss = MathAbs(g_sell_basket.profit);
         if(loss >= InpTrendEscapeMaxLossUSD && g_sell_basket.profit < 0)
         {
            CloseBasketPositions(POSITION_TYPE_SELL);
            g_last_basket_close_time = TimeCurrent();
            CheckDailyReset(true);
         }
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| PROCESS SAFETY GUARDS                                            |
//+------------------------------------------------------------------+
bool ProcessSafetyGuards()
{
   double currentDD = CalculateAccountDrawdownPercent();
   double marginLevel = g_account.MarginLevel();

   // 1. Equity Hard Stop
   if(InpEquityStopPercent > 0 && currentDD >= InpEquityStopPercent)
   {
      CloseAllPositions();
      g_equity_stop_hit = true;
      Alert(StringFormat("[CRITICAL] XAUUSD EA Equity Stop Hit (%.2f%% DD). Trading PAUSED.", currentDD));
      return true;
   }

   // 2. Margin Emergency Cut
   if(marginLevel > 0 && marginLevel < InpMarginEmergencyCut)
   {
      CutWorstOrder();
      return false;
   }

   // 3. Daily Loss Limit Check
   if(InpDailyLossLimitPct > 0)
   {
      double maxDailyLossMoney = g_day_start_balance * (InpDailyLossLimitPct / 100.0);
      if(g_realized_pl_day <= -maxDailyLossMoney)
      {
         if(!g_daily_lockout)
         {
            g_daily_lockout = true;
            Alert("[DAILY LIMIT] Daily Max Loss Limit reached. Trading paused for today.");
         }
      }
   }

   // 4. Daily Profit Goal Check
   if(InpDailyProfitTargetPct > 0)
   {
      double targetDailyMoney = g_day_start_balance * (InpDailyProfitTargetPct / 100.0);
      if(g_realized_pl_day >= targetDailyMoney)
      {
         if(!g_daily_lockout)
         {
            g_daily_lockout = true;
            Alert("[DAILY GOAL] Daily Profit Target hit! Profits locked for today.");
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| EXECUTION & ORDER PLACEMENT                                      |
//+------------------------------------------------------------------+
bool OpenOrder(ENUM_POSITION_TYPE posType, double lot, int level)
{
   lot = NormalizeLotSize(lot);
   string comment = StringFormat("%s_L%d", InpTradeComment, level);

   bool success = false;
   if(posType == POSITION_TYPE_BUY)
      success = g_trade.Buy(lot, _Symbol, g_symbol.Ask(), 0, 0, comment);
   else
      success = g_trade.Sell(lot, _Symbol, g_symbol.Bid(), 0, 0, comment);

   return success;
}

//+------------------------------------------------------------------+
//| CALCULATIONS & HELPERS                                           |
//+------------------------------------------------------------------+
double CalculateDynamicGridStepUSD()
{
   double calculatedStep = g_cached_atr_m15 * InpGridATRMultiplier;
   if(calculatedStep < InpMinGridStepUSD) calculatedStep = InpMinGridStepUSD;
   if(calculatedStep > InpMaxGridStepUSD) calculatedStep = InpMaxGridStepUSD;
   return calculatedStep;
}

double CalculateNextLot(ENUM_POSITION_TYPE posType, int currentLevel)
{
   if(InpLotStrategy == LOT_STRAT_FIXED || currentLevel == 0)
      return NormalizeLotSize(InpInitialLot);

   if(InpLotStrategy == LOT_STRAT_MILD_MULT)
   {
      double lastLot = (posType == POSITION_TYPE_BUY) ? g_buy_basket.last_lot : g_sell_basket.last_lot;
      if(lastLot <= 0) lastLot = InpInitialLot;
      double nextLot = lastLot * InpLotMultiplier;
      return MathMin(NormalizeLotSize(nextLot), InpMaxSingleLot);
   }

   if(InpLotStrategy == LOT_STRAT_RISK_DYNAMIC)
   {
      double equity = g_account.Equity();
      double maxBasketRiskUSD = equity * (InpRiskPerBasketPct / 100.0);
      double approxLot = maxBasketRiskUSD / (InpMaxGridLevels * 1000.0);
      return MathMin(NormalizeLotSize(approxLot), InpMaxSingleLot);
   }

   return NormalizeLotSize(InpInitialLot);
}

double NormalizeLotSize(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lotStep > 0)
      lot = MathFloor(lot / lotStep) * lotStep;

   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   return NormalizeDouble(lot, 2);
}

void CloseBasketPositions(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Symbol() == _Symbol && g_pos.Magic() == InpMagicNumber && g_pos.PositionType() == posType)
            g_trade.PositionClose(g_pos.Ticket());
      }
   }
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Symbol() == _Symbol && g_pos.Magic() == InpMagicNumber)
            g_trade.PositionClose(g_pos.Ticket());
      }
   }
}

void CutWorstOrder()
{
   ulong worstTicket = 0;
   double worstPnl = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Symbol() == _Symbol && g_pos.Magic() == InpMagicNumber)
         {
            if(g_pos.Profit() < worstPnl)
            {
               worstPnl = g_pos.Profit();
               worstTicket = g_pos.Ticket();
            }
         }
      }
   }

   if(worstTicket > 0)
      g_trade.PositionClose(worstTicket);
}

double CalculateAccountDrawdownPercent()
{
   double balance = g_account.Balance();
   double equity  = g_account.Equity();

   if(balance <= 0) return 0.0;
   if(equity >= balance) return 0.0;

   return ((balance - equity) / balance) * 100.0;
}

void CheckDailyReset(bool forceRecalculate)
{
   MqlDateTime dt;
   TimeCurrent(dt);

   datetime dayStart = (datetime)(TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec));
   if(g_last_day_reset != dayStart)
   {
      ResetDailyState();
      g_last_day_reset = dayStart;
      forceRecalculate = true;
   }

   if(forceRecalculate)
   {
      HistorySelect(dayStart, TimeCurrent());
      double pnl = 0.0;
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
               HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
            {
               pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
         }
      }
      g_realized_pl_day = pnl;
   }
}

void ResetDailyState()
{
   g_day_start_balance = g_account.Balance();
   g_realized_pl_day   = 0.0;
   g_daily_lockout     = false;
}

//+------------------------------------------------------------------+
//| RENDER HUD DASHBOARD                                             |
//+------------------------------------------------------------------+
void RenderHUD()
{
   string buyReason, sellReason;
   bool buyPass = CheckEntryFilters(POSITION_TYPE_BUY, buyReason);
   bool sellPass = CheckEntryFilters(POSITION_TYPE_SELL, sellReason);

   double currentDD = CalculateAccountDrawdownPercent();
   double marginLevel = g_account.MarginLevel();
   double stepUSD = CalculateDynamicGridStepUSD();

   string status = "ACTIVE";
   if(g_equity_stop_hit) status = "EQUITY_STOP_HIT";
   else if(g_daily_lockout) status = "DAILY_LOCKOUT";
   else if(currentDD >= (InpEquityStopPercent * 0.75)) status = "DD_GRID_FROZEN";

   string dash = "";
   dash += "=========================================================\n";
   dash += "   XAUUSD ADAPTIVE MEAN-REVERSION GRID EA  v1.10\n";
   dash += StringFormat("   Status: [%s] | Magic: %d | Symbol: %s\n", status, InpMagicNumber, _Symbol);
   dash += "=========================================================\n";
   dash += StringFormat(" [Market Regime] H1 ADX: %.1f (Max: %.1f) | M15 ATR: $%.2f | Step: $%.2f\n", g_cached_adx_h1, InpMaxADXForEntry, g_cached_atr_m15, stepUSD);
   dash += StringFormat(" [Indicators]    M15 RSI(14): %.1f | Spread: %d pts\n", g_cached_rsi, g_symbol.Spread());
   dash += StringFormat(" [Entry Signals] Buy: [%s] | Sell: [%s]\n", (buyPass ? "READY" : buyReason), (sellPass ? "READY" : sellReason));
   dash += "---------------------------------------------------------\n";
   if(g_buy_basket.count > 0)
   {
      dash += StringFormat(" [BUY BASKET]  Levels: %d/%d | Lots: %.2f | Avg BE: %.2f | P/L: $%.2f\n", g_buy_basket.count, InpMaxGridLevels, g_buy_basket.total_lots, g_buy_basket.breakeven, g_buy_basket.profit);
      if(g_buy_peak_profit > 0)
         dash += StringFormat("               Trailing -> Peak: $%.2f (Floor: $%.2f)\n", g_buy_peak_profit, g_buy_peak_profit - InpTrailStepUSD);
   }
   if(g_sell_basket.count > 0)
   {
      dash += StringFormat(" [SELL BASKET] Levels: %d/%d | Lots: %.2f | Avg BE: %.2f | P/L: $%.2f\n", g_sell_basket.count, InpMaxGridLevels, g_sell_basket.total_lots, g_sell_basket.breakeven, g_sell_basket.profit);
      if(g_sell_peak_profit > 0)
         dash += StringFormat("               Trailing -> Peak: $%.2f (Floor: $%.2f)\n", g_sell_peak_profit, g_sell_peak_profit - InpTrailStepUSD);
   }
   if(g_buy_basket.count == 0 && g_sell_basket.count == 0)
   {
      dash += " [BASKET STATUS] No active baskets. Scanning for mean-reversion setups...\n";
   }
   dash += "---------------------------------------------------------\n";
   dash += StringFormat(" Balance: $%.2f | Equity: $%.2f | Margin Lvl: %.1f%%\n", g_account.Balance(), g_account.Equity(), marginLevel);
   dash += StringFormat(" Current DD: %.2f%% (Equity Stop: %.1f%%) | Today P/L: $%.2f\n", currentDD, InpEquityStopPercent, g_realized_pl_day);
   dash += "=========================================================";

   Comment(dash);
}
//+------------------------------------------------------------------+
