//+------------------------------------------------------------------+
//|                                     XAUUSD_Advanced_Grid_EA.mq5  |
//|                                  Copyright 2026, BlamzKunG        |
//|                          https://github.com/BlamzKunG/XAUUSD-Grid-EA |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, BlamzKunG"
#property link        "https://github.com/BlamzKunG/XAUUSD-Grid-EA"
#property version     "2.10"
#property description "High-Performance 4-Layer Grid Trading System for XAUUSD (Gold)"
#property description "Optimized: Single-Pass Basket Stats, Cached Indicators & Throttled HUD"
#property strict

//--- Standard Library Includes
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_GRID_DIRECTION
{
   GRID_DIR_BOTH        = 0, // Both (Buy and Sell Grids)
   GRID_DIR_BUY_ONLY    = 1, // Buy Grid Only
   GRID_DIR_SELL_ONLY   = 2, // Sell Grid Only
   GRID_DIR_AUTO_TREND  = 3  // Auto (Follow EMA Trend Filter)
};

enum ENUM_LOT_MODE
{
   LOT_MODE_FIXED       = 0, // Fixed Initial Lot
   LOT_MODE_RISK_EQUITY = 1  // Auto Lot (% of Equity)
};

enum ENUM_TREND_FILTER_MODE
{
   TREND_FILTER_OFF      = 0, // Disabled
   TREND_FILTER_EMA      = 1, // EMA 200 Direction (Buy above / Sell below)
   TREND_FILTER_SIDEWAY  = 2  // Sideway Only (Price near EMA + Low ADX)
};

enum ENUM_RECOVERY_MODE
{
   RECOVERY_MODE_NONE    = 0, // Disabled (Hold / Wait for DD Cut)
   RECOVERY_MODE_HEDGE   = 1, // Smart Hedge Lock Order
   RECOVERY_MODE_REDUCE  = 2  // Time-based Target Reduction & Emergency DCA
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct SBasketStats
{
   int      count;
   double   total_lots;
   double   profit;
   double   breakeven;
   double   lowest_price;
   double   highest_price;
   double   last_lot;
   datetime oldest_time;
   datetime newest_time;
   ulong    hedge_ticket;

   void Reset()
   {
      count         = 0;
      total_lots    = 0.0;
      profit        = 0.0;
      breakeven     = 0.0;
      lowest_price  = DBL_MAX;
      highest_price = 0.0;
      last_lot      = 0.0;
      oldest_time   = 0;
      newest_time   = 0;
      hedge_ticket  = 0;
   }
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

//=== 1. GENERAL & MAGIC SETTINGS ===
input group "=== [1] General & Identification ==="
input ulong                InpMagicNumber          = 888123;         // Magic Number
input string               InpTradeComment         = "XAUUSD_Grid";  // Order Comment Prefix
input ENUM_GRID_DIRECTION  InpGridDirection        = GRID_DIR_BOTH;  // Grid Trading Direction
input bool                 InpAllowNewGrids        = true;           // Allow Initial Grid Openings

//=== 2. MARKET FILTER LAYER ===
input group "=== [2] Market Filter Layer ==="
input bool                 InpUseSpreadFilter      = true;           // [Spread] Enable Max Spread Filter
input int                  InpMaxSpreadPoints      = 45;             // [Spread] Max Allowed Spread (Points)

input bool                 InpUseATRFilter         = true;           // [ATR] Enable High Volatility Filter
input ENUM_TIMEFRAMES      InpATRTimeframe         = PERIOD_H1;      // [ATR] ATR Timeframe
input int                  InpATRPeriod            = 14;             // [ATR] ATR Period
input double               InpMaxATR_Points        = 750;            // [ATR] Max ATR Value in Points (Pause if exceeded)

input ENUM_TREND_FILTER_MODE InpTrendFilterMode    = TREND_FILTER_SIDEWAY; // [Trend] Trend / Regime Filter
input ENUM_TIMEFRAMES      InpTrendTimeframe       = PERIOD_H1;      // [Trend] Trend Filter Timeframe
input int                  InpEMA_Period           = 200;            // [Trend] EMA Period
input int                  InpMaxEMADistancePoints = 1500;           // [Trend] Max Distance from EMA for Sideway (Points)

input bool                 InpUseADXFilter         = true;           // [ADX] Enable ADX Trend Strength Filter
input int                  InpADXPeriod            = 14;             // [ADX] ADX Period
input double               InpMaxADXThreshold      = 32.0;           // [ADX] Max ADX (Pause if ADX > threshold, Trend too strong)

input bool                 InpUseSessionFilter     = true;           // [Session] Enable Trading Time Filter
input int                  InpSessionStartHour     = 7;              // [Session] Start Hour (Server Time, e.g. 07:00)
input int                  InpSessionEndHour       = 21;             // [Session] End Hour (Server Time, e.g. 21:00)
input bool                 InpAvoidAsianNight      = false;          // [Session] Avoid Low-Liquidity Asian Midnight (22:00-06:00)
input bool                 InpFridayCloseEarly     = true;           // [Session] Stop Opening on Friday Afternoon
input int                  InpFridayStopHour       = 18;             // [Session] Friday Stop Hour

//=== 3. GRID ENGINE LAYER ===
input group "=== [3] Grid Engine Layer ==="
input ENUM_LOT_MODE        InpLotMode              = LOT_MODE_FIXED; // Lot Sizing Mode
input double               InpInitialLot           = 0.01;           // Initial Lot Size (if Fixed)
input double               InpRiskPercent          = 0.5;            // Risk Percent of Equity (if Auto Lot)
input double               InpLotMultiplier        = 1.20;           // Lot Multiplier per Level (Recommended: 1.1 - 1.25)
input double               InpMaxSingleLot         = 0.50;           // Max Lot Size per Single Order
input double               InpMaxTotalLots         = 2.50;           // Max Cumulative Lots per Basket

input int                  InpBaseGridDistancePts  = 250;            // Base Grid Step Distance (Points, e.g. 250 = $2.50)
input double               InpGridStepMultiplier   = 1.10;           // Grid Step Multiplier (Expanding Grid Distance)
input bool                 InpUseDynamicATRStep    = true;           // Dynamic Grid Step based on ATR
input double               InpDynamicATRMultiplier = 0.50;           // ATR Multiplier for Dynamic Step
input int                  InpMaxGridLevels        = 8;              // Max Grid Levels per Direction

//=== 4. BASKET PROFIT & EXIT LAYER ===
input group "=== [4] Basket Profit & Exit Layer ==="
input double               InpBasketTP_USD         = 15.0;           // Basket TP Target in Account Currency ($ USD)
input int                  InpBasketTP_Points      = 100;            // Basket TP in Points above/below Breakeven (0 to disable)
input double               InpBasketTP_Percent     = 0.0;            // Basket TP in % of Balance (0 to disable)

input bool                 InpUseBasketTrailing    = true;           // Enable Basket Trailing Stop
input double               InpTrailStartUSD        = 12.0;           // Trail Start Target ($ USD)
input double               InpTrailStepUSD         = 4.0;            // Trail Step / Lock-in Distance ($ USD)

//=== 5. RISK MANAGEMENT & DRAWDOWN GUARDS ===
input group "=== [5] Risk Management & DD Guards ==="
input double               InpMaxDrawdownPercent   = 20.0;           // Hard Stop: Max Allowed Floating Drawdown % (Emergency Close All)
input double               InpDrawdownFreezePct    = 12.0;           // Soft Guard: Freeze New Grid Orders if DD % > threshold
input double               InpMarginLevelFreeze    = 200.0;          // Margin Guard: Stop New Grid Orders if Margin Level % < threshold
input double               InpMarginEmergencyCut   = 130.0;          // Margin Emergency: Cut worst losing trade if Margin Level % < threshold
input double               InpMaxDailyLossUSD      = 100.0;          // Max Daily Loss ($ USD, 0 to disable)
input double               InpDailyProfitTargetUSD = 150.0;          // Daily Profit Target ($ USD, 0 to disable)
input bool                 InpSendAlertOnGuard     = true;           // Send Terminal & Push Notifications on DD Alerts

//=== 6. RECOVERY & HEDGE LAYER ===
input group "=== [6] Recovery & Hedge Layer ==="
input ENUM_RECOVERY_MODE   InpRecoveryMode         = RECOVERY_MODE_HEDGE; // Recovery Mechanism
input double               InpHedgeLotRatio        = 1.0;            // Hedge Volume Ratio (1.0 = 100% Volume Locked)
input int                  InpMaxGridHoldHours     = 48;             // Max Holding Time for Grid Basket (Hours before Target Reduction)
input double               InpStaleTargetReduction = 0.50;           // Target Profit Reduction Multiplier for Stale Grids (e.g. 50%)

//=== 7. DASHBOARD & VISUALS ===
input group "=== [7] Dashboard & Visuals ==="
input bool                 InpShowDashboard        = true;           // Show On-Chart HUD Dashboard

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS & STATE VARIABLES                                 |
//+------------------------------------------------------------------+
CTrade         g_trade;
CPositionInfo  g_pos;
CAccountInfo   g_account;
CSymbolInfo    g_symbol;

// Indicator Handles
int            g_h_atr           = INVALID_HANDLE;
int            g_h_ema           = INVALID_HANDLE;
int            g_h_adx           = INVALID_HANDLE;

// Cached Indicator Data (Updated on New Bar / Throttled)
datetime       g_last_indicator_time = 0;
double         g_cached_atr_points   = 0.0;
double         g_cached_ema_val      = 0.0;
double         g_cached_adx_val      = 0.0;

// Daily Tracking
datetime       g_last_day_reset  = 0;
datetime       g_last_deal_scan  = 0;
double         g_day_start_equity= 0.0;
double         g_realized_pl_day = 0.0;
bool           g_daily_lockout   = false;
bool           g_emergency_locked= false;

// Trailing Basket Peak State
double         g_buy_peak_profit = 0.0;
double         g_sell_peak_profit= 0.0;

// Single-Pass Basket Stats
SBasketStats   g_buy_stats;
SBasketStats   g_sell_stats;

// Forward Declarations
void UpdateBasketStatistics();
void RefreshIndicatorCache();
bool CheckMarketFilters(ENUM_POSITION_TYPE direction, string &failReason);
int CalculateGridStep(int currentLevel);
void ManageInitialGridEntries();
void ManageOpenGrids();
bool OpenGridPosition(ENUM_POSITION_TYPE posType, double lot, int level);
void ManageBasketExits();
bool ProcessDrawdownGuards();
void ManageRecoveryLayer();
void CloseHedgePosition(ENUM_POSITION_TYPE originalPosType);
bool IsGridStale(ENUM_POSITION_TYPE posType);
double CalculateInitialLot();
double NormalizeLot(double lot);
void CloseBasket(ENUM_POSITION_TYPE posType);
void CloseAllEAOrders();
void CutWorstLosingPosition();
double CalculateAccountDrawdownPercent();
void CheckDailyReset(bool forceRecalculate);
void ResetDailyMetrics();
void RenderDashboard();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!g_symbol.Name(_Symbol))
   {
      Print("[ERROR] Failed to initialize CSymbolInfo for ", _Symbol);
      return INIT_FAILED;
   }
   g_symbol.Refresh();

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   if(InpUseATRFilter || InpUseDynamicATRStep)
   {
      g_h_atr = iATR(_Symbol, InpATRTimeframe, InpATRPeriod);
      if(g_h_atr == INVALID_HANDLE)
      {
         Print("[ERROR] Failed to initialize ATR indicator handle.");
         return INIT_FAILED;
      }
   }

   if(InpTrendFilterMode != TREND_FILTER_OFF)
   {
      g_h_ema = iMA(_Symbol, InpTrendTimeframe, InpEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(g_h_ema == INVALID_HANDLE)
      {
         Print("[ERROR] Failed to initialize EMA indicator handle.");
         return INIT_FAILED;
      }
   }

   if(InpUseADXFilter)
   {
      g_h_adx = iADX(_Symbol, InpTrendTimeframe, InpADXPeriod);
      if(g_h_adx == INVALID_HANDLE)
      {
         Print("[ERROR] Failed to initialize ADX indicator handle.");
         return INIT_FAILED;
      }
   }

   ResetDailyMetrics();
   RefreshIndicatorCache();
   UpdateBasketStatistics();

   // Set timer for dashboard rendering & safety monitor (1 second)
   EventSetTimer(1);

   Print("=====================================================");
   Print(" [XAUUSD Advanced Grid EA v2.10] Optimized Engine Initialized");
   Print(" Symbol: ", _Symbol, " | Magic: ", InpMagicNumber);
   Print("=====================================================");

   if(InpShowDashboard && !MQLInfoInteger(MQL_OPTIMIZATION))
      RenderDashboard();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   if(g_h_atr != INVALID_HANDLE) IndicatorRelease(g_h_atr);
   if(g_h_ema != INVALID_HANDLE) IndicatorRelease(g_h_ema);
   if(g_h_adx != INVALID_HANDLE) IndicatorRelease(g_h_adx);

   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function (High Speed)                                |
//+------------------------------------------------------------------+
void OnTick()
{
   g_symbol.RefreshRates();

   // 1. Refresh Indicator Cache on new H1/M15 bar
   datetime currentBarTime = iTime(_Symbol, InpATRTimeframe, 0);
   if(currentBarTime != g_last_indicator_time)
   {
      g_last_indicator_time = currentBarTime;
      RefreshIndicatorCache();
      CheckDailyReset(true);
   }

   // 2. Update Basket Statistics in Single Pass
   UpdateBasketStatistics();

   // 3. Process Drawdown Guards
   if(ProcessDrawdownGuards())
      return;

   // 4. Manage Basket Exits
   ManageBasketExits();

   // 5. Manage Recovery / Hedge Layer
   ManageRecoveryLayer();

   // 6. Manage Open Grid Orders
   ManageOpenGrids();

   // 7. Manage Initial Entries
   ManageInitialGridEntries();
}

//+------------------------------------------------------------------+
//| Timer Event Function (Throttled UI & Periodic Safety Checks)      |
//+------------------------------------------------------------------+
void OnTimer()
{
   g_symbol.RefreshRates();
   UpdateBasketStatistics();
   ProcessDrawdownGuards();

   if(InpShowDashboard && !MQLInfoInteger(MQL_OPTIMIZATION))
      RenderDashboard();
}

//+------------------------------------------------------------------+
//| SINGLE-PASS BASKET STATISTICS CALCULATION                        |
//+------------------------------------------------------------------+
void UpdateBasketStatistics()
{
   g_buy_stats.Reset();
   g_sell_stats.Reset();

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
            string comment = g_pos.Comment();
            double volume  = g_pos.Volume();
            double price   = g_pos.PriceOpen();
            double pnl     = g_pos.Profit() + g_pos.Swap() + g_pos.Commission();
            datetime time  = g_pos.Time();

            if(pType == POSITION_TYPE_BUY)
            {
               if(StringFind(comment, "Hedge") >= 0)
               {
                  g_sell_stats.hedge_ticket = g_pos.Ticket();
               }
               else
               {
                  g_buy_stats.count++;
                  g_buy_stats.total_lots += volume;
                  g_buy_stats.profit += pnl;
                  sumBuyPriceLot += (volume * price);

                  if(price < g_buy_stats.lowest_price) g_buy_stats.lowest_price = price;
                  if(price > g_buy_stats.highest_price) g_buy_stats.highest_price = price;

                  if(g_buy_stats.oldest_time == 0 || time < g_buy_stats.oldest_time)
                     g_buy_stats.oldest_time = time;
                  if(time > g_buy_stats.newest_time)
                  {
                     g_buy_stats.newest_time = time;
                     g_buy_stats.last_lot = volume;
                  }
               }
            }
            else if(pType == POSITION_TYPE_SELL)
            {
               if(StringFind(comment, "Hedge") >= 0)
               {
                  g_buy_stats.hedge_ticket = g_pos.Ticket();
               }
               else
               {
                  g_sell_stats.count++;
                  g_sell_stats.total_lots += volume;
                  g_sell_stats.profit += pnl;
                  sumSellPriceLot += (volume * price);

                  if(price < g_sell_stats.lowest_price) g_sell_stats.lowest_price = price;
                  if(price > g_sell_stats.highest_price) g_sell_stats.highest_price = price;

                  if(g_sell_stats.oldest_time == 0 || time < g_sell_stats.oldest_time)
                     g_sell_stats.oldest_time = time;
                  if(time > g_sell_stats.newest_time)
                  {
                     g_sell_stats.newest_time = time;
                     g_sell_stats.last_lot = volume;
                  }
               }
            }
         }
      }
   }

   if(g_buy_stats.total_lots > 0)
      g_buy_stats.breakeven = NormalizeDouble(sumBuyPriceLot / g_buy_stats.total_lots, _Digits);
   if(g_sell_stats.total_lots > 0)
      g_sell_stats.breakeven = NormalizeDouble(sumSellPriceLot / g_sell_stats.total_lots, _Digits);

   if(g_buy_stats.lowest_price == DBL_MAX) g_buy_stats.lowest_price = 0.0;
   if(g_sell_stats.lowest_price == DBL_MAX) g_sell_stats.lowest_price = 0.0;
}

//+------------------------------------------------------------------+
//| REFRESH INDICATOR CACHE                                          |
//+------------------------------------------------------------------+
void RefreshIndicatorCache()
{
   if(g_h_atr != INVALID_HANDLE)
   {
      double buf[1];
      if(CopyBuffer(g_h_atr, 0, 0, 1, buf) > 0)
         g_cached_atr_points = buf[0] / _Point;
   }

   if(g_h_ema != INVALID_HANDLE)
   {
      double buf[1];
      if(CopyBuffer(g_h_ema, 0, 0, 1, buf) > 0)
         g_cached_ema_val = buf[0];
   }

   if(g_h_adx != INVALID_HANDLE)
   {
      double buf[1];
      if(CopyBuffer(g_h_adx, 0, 0, 1, buf) > 0)
         g_cached_adx_val = buf[0];
   }
}

//+------------------------------------------------------------------+
//| LAYER 1: MARKET FILTER LAYER FUNCTIONS                          |
//+------------------------------------------------------------------+
bool CheckMarketFilters(ENUM_POSITION_TYPE direction, string &failReason)
{
   failReason = "PASS";

   if(g_emergency_locked)
   {
      failReason = "EMERGENCY_LOCKED";
      return false;
   }
   if(g_daily_lockout)
   {
      failReason = "DAILY_LIMIT_HIT";
      return false;
   }
   if(!InpAllowNewGrids)
   {
      failReason = "NEW_GRIDS_DISABLED";
      return false;
   }

   // Spread Filter
   if(InpUseSpreadFilter)
   {
      long currentSpread = g_symbol.Spread();
      if(currentSpread > InpMaxSpreadPoints)
      {
         failReason = StringFormat("SPREAD_HIGH (%d > %d)", currentSpread, InpMaxSpreadPoints);
         return false;
      }
   }

   // Session & Time Filter
   if(InpUseSessionFilter)
   {
      MqlDateTime dt;
      TimeCurrent(dt);

      if(InpFridayCloseEarly && dt.day_of_week == 5 && dt.hour >= InpFridayStopHour)
      {
         failReason = "FRIDAY_STOP_HOUR";
         return false;
      }

      if(InpAvoidAsianNight && (dt.hour >= 22 || dt.hour < 6))
      {
         failReason = "ASIAN_NIGHT_FILTER";
         return false;
      }

      if(dt.hour < InpSessionStartHour || dt.hour > InpSessionEndHour)
      {
         failReason = StringFormat("OFF_SESSION (%02d:00)", dt.hour);
         return false;
      }
   }

   // ATR Volatility Filter
   if(InpUseATRFilter && g_cached_atr_points > InpMaxATR_Points)
   {
      failReason = StringFormat("ATR_TOO_HIGH (%.0f > %.0f)", g_cached_atr_points, InpMaxATR_Points);
      return false;
   }

   // ADX Trend Strength Filter
   if(InpUseADXFilter && g_cached_adx_val > InpMaxADXThreshold)
   {
      failReason = StringFormat("ADX_TOO_STRONG (%.1f > %.1f)", g_cached_adx_val, InpMaxADXThreshold);
      return false;
   }

   // Trend / EMA 200 Filter
   if(InpTrendFilterMode != TREND_FILTER_OFF && g_cached_ema_val > 0)
   {
      double currentPrice = (direction == POSITION_TYPE_BUY) ? g_symbol.Ask() : g_symbol.Bid();
      double distPoints = MathAbs(currentPrice - g_cached_ema_val) / _Point;

      if(InpTrendFilterMode == TREND_FILTER_EMA)
      {
         if(direction == POSITION_TYPE_BUY && currentPrice < g_cached_ema_val)
         {
            failReason = "BELOW_EMA200 (BEARISH)";
            return false;
         }
         if(direction == POSITION_TYPE_SELL && currentPrice > g_cached_ema_val)
         {
            failReason = "ABOVE_EMA200 (BULLISH)";
            return false;
         }
      }
      else if(InpTrendFilterMode == TREND_FILTER_SIDEWAY)
      {
         if(distPoints > InpMaxEMADistancePoints)
         {
            failReason = StringFormat("EMA_DIST_HIGH (%.0f > %d)", distPoints, InpMaxEMADistancePoints);
            return false;
         }
      }
   }

   // Margin Guard
   double marginLevel = g_account.MarginLevel();
   if(marginLevel > 0 && marginLevel < InpMarginLevelFreeze)
   {
      failReason = StringFormat("MARGIN_FROZEN (%.1f%% < %.1f%%)", marginLevel, InpMarginLevelFreeze);
      return false;
   }

   // Drawdown Freeze Check
   double currentDD = CalculateAccountDrawdownPercent();
   if(currentDD >= InpDrawdownFreezePct)
   {
      failReason = StringFormat("DD_FROZEN (%.1f%% >= %.1f%%)", currentDD, InpDrawdownFreezePct);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Grid Step                                      |
//+------------------------------------------------------------------+
int CalculateGridStep(int currentLevel)
{
   int baseStep = InpBaseGridDistancePts;

   if(InpUseDynamicATRStep && g_cached_atr_points > 0)
   {
      int dynamicStep = (int)(g_cached_atr_points * InpDynamicATRMultiplier);
      baseStep = MathMax(InpBaseGridDistancePts, dynamicStep);
   }

   double expandedStep = (double)baseStep;
   if(currentLevel > 0 && InpGridStepMultiplier > 1.0)
   {
      expandedStep = baseStep * MathPow(InpGridStepMultiplier, currentLevel);
   }

   return (int)MathRound(expandedStep);
}

//+------------------------------------------------------------------+
//| LAYER 2: GRID ENGINE LAYER FUNCTIONS                            |
//+------------------------------------------------------------------+
void ManageInitialGridEntries()
{
   // Buy Grid Initial Entry
   if(g_buy_stats.count == 0 && (InpGridDirection == GRID_DIR_BOTH || InpGridDirection == GRID_DIR_BUY_ONLY || InpGridDirection == GRID_DIR_AUTO_TREND))
   {
      string failReason;
      if(CheckMarketFilters(POSITION_TYPE_BUY, failReason))
      {
         bool allowBuy = true;
         if(InpGridDirection == GRID_DIR_AUTO_TREND && g_cached_ema_val > 0)
            allowBuy = (g_symbol.Ask() >= g_cached_ema_val);

         if(allowBuy)
         {
            double lot = CalculateInitialLot();
            OpenGridPosition(POSITION_TYPE_BUY, lot, 0);
            g_buy_peak_profit = 0.0;
         }
      }
   }

   // Sell Grid Initial Entry
   if(g_sell_stats.count == 0 && (InpGridDirection == GRID_DIR_BOTH || InpGridDirection == GRID_DIR_SELL_ONLY || InpGridDirection == GRID_DIR_AUTO_TREND))
   {
      string failReason;
      if(CheckMarketFilters(POSITION_TYPE_SELL, failReason))
      {
         bool allowSell = true;
         if(InpGridDirection == GRID_DIR_AUTO_TREND && g_cached_ema_val > 0)
            allowSell = (g_symbol.Bid() <= g_cached_ema_val);

         if(allowSell)
         {
            double lot = CalculateInitialLot();
            OpenGridPosition(POSITION_TYPE_SELL, lot, 0);
            g_sell_peak_profit = 0.0;
         }
      }
   }
}

void ManageOpenGrids()
{
   double marginLevel = g_account.MarginLevel();
   if(marginLevel > 0 && marginLevel < InpMarginLevelFreeze)
      return;

   if(CalculateAccountDrawdownPercent() >= InpDrawdownFreezePct)
      return;

   // 1. Manage BUY Grid Expansion
   if(g_buy_stats.count > 0 && g_buy_stats.count < InpMaxGridLevels)
   {
      int stepPoints = CalculateGridStep(g_buy_stats.count);
      double targetNextBuyPrice = g_buy_stats.lowest_price - (stepPoints * _Point);

      if(g_symbol.Ask() <= targetNextBuyPrice)
      {
         double lastLot = (g_buy_stats.last_lot > 0) ? g_buy_stats.last_lot : InpInitialLot;
         double nextLot = NormalizeLot(lastLot * InpLotMultiplier);
         nextLot = MathMin(nextLot, InpMaxSingleLot);

         if((g_buy_stats.total_lots + nextLot) <= InpMaxTotalLots)
         {
            OpenGridPosition(POSITION_TYPE_BUY, nextLot, g_buy_stats.count);
         }
      }
   }

   // 2. Manage SELL Grid Expansion
   if(g_sell_stats.count > 0 && g_sell_stats.count < InpMaxGridLevels)
   {
      int stepPoints = CalculateGridStep(g_sell_stats.count);
      double targetNextSellPrice = g_sell_stats.highest_price + (stepPoints * _Point);

      if(g_symbol.Bid() >= targetNextSellPrice)
      {
         double lastLot = (g_sell_stats.last_lot > 0) ? g_sell_stats.last_lot : InpInitialLot;
         double nextLot = NormalizeLot(lastLot * InpLotMultiplier);
         nextLot = MathMin(nextLot, InpMaxSingleLot);

         if((g_sell_stats.total_lots + nextLot) <= InpMaxTotalLots)
         {
            OpenGridPosition(POSITION_TYPE_SELL, nextLot, g_sell_stats.count);
         }
      }
   }
}

bool OpenGridPosition(ENUM_POSITION_TYPE posType, double lot, int level)
{
   lot = NormalizeLot(lot);
   string comment = StringFormat("%s_L%d", InpTradeComment, level);

   bool success = false;
   if(posType == POSITION_TYPE_BUY)
      success = g_trade.Buy(lot, _Symbol, g_symbol.Ask(), 0, 0, comment);
   else
      success = g_trade.Sell(lot, _Symbol, g_symbol.Bid(), 0, 0, comment);

   return success;
}

//+------------------------------------------------------------------+
//| LAYER 3: BASKET TAKE PROFIT & TRAILING EXIT LAYER                |
//+------------------------------------------------------------------+
void ManageBasketExits()
{
   // 1. Manage BUY Basket Exits
   if(g_buy_stats.count > 0)
   {
      double targetUSD = InpBasketTP_USD;
      if(InpRecoveryMode == RECOVERY_MODE_REDUCE && IsGridStale(POSITION_TYPE_BUY))
         targetUSD *= InpStaleTargetReduction;

      bool hitUSD_TP     = (targetUSD > 0 && g_buy_stats.profit >= targetUSD);
      bool hitPercent_TP = (InpBasketTP_Percent > 0 && g_buy_stats.profit >= (g_account.Balance() * InpBasketTP_Percent / 100.0));
      bool hitPoints_TP  = (InpBasketTP_Points > 0 && g_buy_stats.breakeven > 0 && g_symbol.Bid() >= (g_buy_stats.breakeven + (InpBasketTP_Points * _Point)));
      bool hitTrailing_TP= false;

      if(InpUseBasketTrailing)
      {
         if(g_buy_stats.profit >= InpTrailStartUSD)
         {
            if(g_buy_stats.profit > g_buy_peak_profit)
               g_buy_peak_profit = g_buy_stats.profit;

            double trailingFloor = g_buy_peak_profit - InpTrailStepUSD;
            if(g_buy_stats.profit <= trailingFloor && trailingFloor > 0)
               hitTrailing_TP = true;
         }
         else
         {
            g_buy_peak_profit = 0.0;
         }
      }

      if(hitUSD_TP || hitPercent_TP || hitPoints_TP || hitTrailing_TP)
      {
         CloseBasket(POSITION_TYPE_BUY);
         g_buy_peak_profit = 0.0;
         CloseHedgePosition(POSITION_TYPE_BUY);
         CheckDailyReset(true);
      }
   }
   else
   {
      g_buy_peak_profit = 0.0;
   }

   // 2. Manage SELL Basket Exits
   if(g_sell_stats.count > 0)
   {
      double targetUSD = InpBasketTP_USD;
      if(InpRecoveryMode == RECOVERY_MODE_REDUCE && IsGridStale(POSITION_TYPE_SELL))
         targetUSD *= InpStaleTargetReduction;

      bool hitUSD_TP     = (targetUSD > 0 && g_sell_stats.profit >= targetUSD);
      bool hitPercent_TP = (InpBasketTP_Percent > 0 && g_sell_stats.profit >= (g_account.Balance() * InpBasketTP_Percent / 100.0));
      bool hitPoints_TP  = (InpBasketTP_Points > 0 && g_sell_stats.breakeven > 0 && g_symbol.Ask() <= (g_sell_stats.breakeven - (InpBasketTP_Points * _Point)));
      bool hitTrailing_TP= false;

      if(InpUseBasketTrailing)
      {
         if(g_sell_stats.profit >= InpTrailStartUSD)
         {
            if(g_sell_stats.profit > g_sell_peak_profit)
               g_sell_peak_profit = g_sell_stats.profit;

            double trailingFloor = g_sell_peak_profit - InpTrailStepUSD;
            if(g_sell_stats.profit <= trailingFloor && trailingFloor > 0)
               hitTrailing_TP = true;
         }
         else
         {
            g_sell_peak_profit = 0.0;
         }
      }

      if(hitUSD_TP || hitPercent_TP || hitPoints_TP || hitTrailing_TP)
      {
         CloseBasket(POSITION_TYPE_SELL);
         g_sell_peak_profit = 0.0;
         CloseHedgePosition(POSITION_TYPE_SELL);
         CheckDailyReset(true);
      }
   }
   else
   {
      g_sell_peak_profit = 0.0;
   }
}

//+------------------------------------------------------------------+
//| LAYER 4: RISK MANAGEMENT & DRAWDOWN GUARDS                      |
//+------------------------------------------------------------------+
bool ProcessDrawdownGuards()
{
   double currentDD = CalculateAccountDrawdownPercent();
   double marginLevel = g_account.MarginLevel();

   // Tier 3: Emergency Hard Stop
   if(InpMaxDrawdownPercent > 0 && currentDD >= InpMaxDrawdownPercent)
   {
      CloseAllEAOrders();
      g_emergency_locked = true;

      if(InpSendAlertOnGuard)
      {
         Alert(StringFormat("[CRITICAL] XAUUSD EA Emergency Stop! DD reached %.2f%%", currentDD));
         SendNotification(StringFormat("[CRITICAL] XAUUSD EA Emergency Stop! DD reached %.2f%% on %s", currentDD, _Symbol));
      }
      return true;
   }

   // Tier 2: Margin Emergency Cut
   if(marginLevel > 0 && marginLevel < InpMarginEmergencyCut)
   {
      CutWorstLosingPosition();
      return false;
   }

   // Daily Loss Limit Check
   if(InpMaxDailyLossUSD > 0 && g_realized_pl_day <= -InpMaxDailyLossUSD)
   {
      if(!g_daily_lockout)
      {
         g_daily_lockout = true;
         if(InpSendAlertOnGuard)
            Alert(StringFormat("[DAILY LIMIT] XAUUSD EA Max Daily Loss hit: -$%.2f", InpMaxDailyLossUSD));
      }
   }

   // Daily Profit Target Check
   if(InpDailyProfitTargetUSD > 0 && g_realized_pl_day >= InpDailyProfitTargetUSD)
   {
      if(!g_daily_lockout)
      {
         g_daily_lockout = true;
         if(InpSendAlertOnGuard)
            Alert(StringFormat("[DAILY GOAL] XAUUSD EA Profit Target hit: +$%.2f", InpDailyProfitTargetUSD));
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| LAYER 5: RECOVERY & HEDGE LAYER                                 |
//+------------------------------------------------------------------+
void ManageRecoveryLayer()
{
   if(InpRecoveryMode != RECOVERY_MODE_HEDGE) return;

   // 1. Check BUY Basket for Hedge Trigger
   if(g_buy_stats.count >= InpMaxGridLevels && g_buy_stats.hedge_ticket == 0)
   {
      int stepPoints = CalculateGridStep(g_buy_stats.count);
      double hedgeTriggerPrice = g_buy_stats.lowest_price - (stepPoints * _Point);

      if(g_symbol.Bid() <= hedgeTriggerPrice)
      {
         double hedgeLot = NormalizeLot(g_buy_stats.total_lots * InpHedgeLotRatio);
         g_trade.Sell(hedgeLot, _Symbol, g_symbol.Bid(), 0, 0, InpTradeComment + "_HedgeBuy");
      }
   }

   // 2. Check SELL Basket for Hedge Trigger
   if(g_sell_stats.count >= InpMaxGridLevels && g_sell_stats.hedge_ticket == 0)
   {
      int stepPoints = CalculateGridStep(g_sell_stats.count);
      double hedgeTriggerPrice = g_sell_stats.highest_price + (stepPoints * _Point);

      if(g_symbol.Ask() >= hedgeTriggerPrice)
      {
         double hedgeLot = NormalizeLot(g_sell_stats.total_lots * InpHedgeLotRatio);
         g_trade.Buy(hedgeLot, _Symbol, g_symbol.Ask(), 0, 0, InpTradeComment + "_HedgeSell");
      }
   }
}

void CloseHedgePosition(ENUM_POSITION_TYPE originalPosType)
{
   ulong targetTicket = (originalPosType == POSITION_TYPE_BUY) ? g_buy_stats.hedge_ticket : g_sell_stats.hedge_ticket;
   if(targetTicket > 0)
      g_trade.PositionClose(targetTicket);
}

bool IsGridStale(ENUM_POSITION_TYPE posType)
{
   if(InpMaxGridHoldHours <= 0) return false;
   datetime oldestTime = (posType == POSITION_TYPE_BUY) ? g_buy_stats.oldest_time : g_sell_stats.oldest_time;
   if(oldestTime == 0) return false;

   long holdSeconds = (long)(TimeCurrent() - oldestTime);
   return (holdSeconds >= (InpMaxGridHoldHours * 3600));
}

//+------------------------------------------------------------------+
//| HELPER & CALCULATION FUNCTIONS                                   |
//+------------------------------------------------------------------+
double CalculateInitialLot()
{
   if(InpLotMode == LOT_MODE_FIXED)
      return NormalizeLot(InpInitialLot);

   double equity = g_account.Equity();
   double riskMoney = equity * (InpRiskPercent / 100.0);
   double calculatedLot = riskMoney / 1000.0;
   return NormalizeLot(calculatedLot);
}

double NormalizeLot(double lot)
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

void CloseBasket(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Symbol() == _Symbol && g_pos.Magic() == InpMagicNumber && g_pos.PositionType() == posType)
         {
            g_trade.PositionClose(g_pos.Ticket());
         }
      }
   }
}

void CloseAllEAOrders()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Symbol() == _Symbol && g_pos.Magic() == InpMagicNumber)
         {
            g_trade.PositionClose(g_pos.Ticket());
         }
      }
   }
}

void CutWorstLosingPosition()
{
   ulong worstTicket = 0;
   double worstLoss = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i))
      {
         if(g_pos.Symbol() == _Symbol && g_pos.Magic() == InpMagicNumber)
         {
            double pnl = g_pos.Profit();
            if(pnl < worstLoss)
            {
               worstLoss = pnl;
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
      ResetDailyMetrics();
      g_last_day_reset = dayStart;
      forceRecalculate = true;
   }

   if(forceRecalculate)
   {
      HistorySelect(dayStart, TimeCurrent());
      double todayPL = 0.0;
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
               HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
            {
               todayPL += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                          HistoryDealGetDouble(ticket, DEAL_SWAP) +
                          HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
         }
      }
      g_realized_pl_day = todayPL;
   }
}

void ResetDailyMetrics()
{
   g_day_start_equity = g_account.Equity();
   g_realized_pl_day  = 0.0;
   g_daily_lockout    = false;
}

//+------------------------------------------------------------------+
//| LAYER 6: ON-CHART HUD DASHBOARD                                  |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   string filterReasonBuy, filterReasonSell;
   bool buyFilterPass = CheckMarketFilters(POSITION_TYPE_BUY, filterReasonBuy);
   bool sellFilterPass = CheckMarketFilters(POSITION_TYPE_SELL, filterReasonSell);

   double currentDD = CalculateAccountDrawdownPercent();
   double marginLevel = g_account.MarginLevel();

   string statusStr = "ACTIVE";
   if(g_emergency_locked) statusStr = "EMERGENCY_LOCKED";
   else if(g_daily_lockout) statusStr = "DAILY_LOCKOUT";
   else if(currentDD >= InpDrawdownFreezePct) statusStr = "DD_FROZEN";
   else if(marginLevel > 0 && marginLevel < InpMarginLevelFreeze) statusStr = "MARGIN_FROZEN";

   string dash = "";
   dash += "=========================================================\n";
   dash += StringFormat("   XAUUSD ADVANCED GRID EA  v2.10  |  Status: [%s]\n", statusStr);
   dash += "=========================================================\n";
   dash += StringFormat(" Symbol: %s | Magic: %d | Spread: %d pts | ATR(14): %.0f pts\n", _Symbol, InpMagicNumber, g_symbol.Spread(), g_cached_atr_points);
   dash += StringFormat(" Filters: Buy [%s] | Sell [%s]\n", (buyFilterPass ? "PASS" : filterReasonBuy), (sellFilterPass ? "PASS" : filterReasonSell));
   dash += "---------------------------------------------------------\n";
   dash += StringFormat(" [BUY GRID]  Levels: %d/%d | Lots: %.2f | BE: %.2f | P/L: $%.2f\n", g_buy_stats.count, InpMaxGridLevels, g_buy_stats.total_lots, g_buy_stats.breakeven, g_buy_stats.profit);
   if(g_buy_peak_profit > 0)
      dash += StringFormat("             Trailing Active -> Peak: $%.2f (Floor: $%.2f)\n", g_buy_peak_profit, g_buy_peak_profit - InpTrailStepUSD);
   if(g_buy_stats.hedge_ticket > 0)
      dash += "             [HEDGE ACTIVE] Position Protected\n";

   dash += StringFormat(" [SELL GRID] Levels: %d/%d | Lots: %.2f | BE: %.2f | P/L: $%.2f\n", g_sell_stats.count, InpMaxGridLevels, g_sell_stats.total_lots, g_sell_stats.breakeven, g_sell_stats.profit);
   if(g_sell_peak_profit > 0)
      dash += StringFormat("             Trailing Active -> Peak: $%.2f (Floor: $%.2f)\n", g_sell_peak_profit, g_sell_peak_profit - InpTrailStepUSD);
   if(g_sell_stats.hedge_ticket > 0)
      dash += "             [HEDGE ACTIVE] Position Protected\n";

   dash += "---------------------------------------------------------\n";
   dash += StringFormat(" Balance: $%.2f | Equity: $%.2f | Margin Lvl: %.1f%%\n", g_account.Balance(), g_account.Equity(), marginLevel);
   dash += StringFormat(" Current DD: %.2f%% (Freeze: %.1f%% | Emergency: %.1f%%)\n", currentDD, InpDrawdownFreezePct, InpMaxDrawdownPercent);
   dash += StringFormat(" Today's Realized P/L: $%.2f (Goal: $%.2f | Max Loss: -$%.2f)\n", g_realized_pl_day, InpDailyProfitTargetUSD, InpMaxDailyLossUSD);
   dash += "=========================================================";

   Comment(dash);
}
//+------------------------------------------------------------------+
