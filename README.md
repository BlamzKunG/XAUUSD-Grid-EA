# 🏆 XAUUSD Advanced 4-Layer Grid Trading EA (MQL5)

[![MQL5](https://img.shields.io/badge/MQL5-Expert%20Advisor-blue.svg)](https://www.mql5.com)
[![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-orange.svg)](https://www.metatrader5.com)
[![Asset](https://img.shields.io/badge/Asset-XAUUSD%20%7C%20Gold-yellow.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An institutional-grade, multi-layered **Grid Trading Expert Advisor for MetaTrader 5 (MT5)** specifically designed and tuned for the extreme volatility and liquidity characteristics of **XAUUSD (Gold)**.

---

## ⚠️ คำเตือนความเสี่ยง (Risk Disclaimer)
> **สำคัญมาก:** การเทรดทองคำ (XAUUSD) ด้วยระบบ Grid มีความเสี่ยงสูงเนื่องจากทองคำมีแนวโน้มวิ่งเป็น Trend รุนแรงเมื่อมีข่าวเศรษฐกิจสำคัญ (เช่น NFP, CPI, สงคราม, อัตราดอกเบี้ย Fed) 
> 
> EA ตัวนี้ถูกออกแบบขึ้นมาโดยมี **4-Layer Architecture** พร้อมระบบ **Market Filters, Drawdown Guards, Margin Protection** และ **Automated Hedging Recovery** เพื่อควบคุมความเสี่ยงอย่างเคร่งครัด ควรทดสอบ Backtest และ Forward Test ในบัญชี Demo ให้เข้าใจระบบอย่างละเอียดก่อนใช้งานจริง

---

## 🏛️ สถาปัตยกรรมระบบ 4 ชั้น (4-Layer System Architecture)

```
┌────────────────────────────────────────────────────────┐
│               LAYER 1: MARKET FILTER                   │
│   - ATR(14) Volatility Filter (High Volatility Pause)  │
│   - Trend / Regime Filter (EMA 200 & ADX Sideway Check)│
│   - Session & Time Filter (London/NY, Asian Guard)     │
│   - Max Spread Filter                                  │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│               LAYER 2: GRID ENGINE                     │
│   - Dynamic ATR & Expanding Grid Step (Multiplier)     │
│   - Safe Lot Sizing (1.0x - 1.25x Multiplier Cap)      │
│   - Bi-directional / Trend-Following / Sideway Modes   │
│   - Max Grid Levels & Max Exposure Lots Cap            │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│               LAYER 3: RISK MANAGEMENT                 │
│   - Tier 1: Soft Freeze (Stop New Grids at X% DD)      │
│   - Tier 2: Margin Guard (Stop at 200%, Cut at 130%)   │
│   - Tier 3: Emergency Hard Stop (Auto Close at Y% DD)  │
│   - Daily Profit Target & Daily Max Loss Lockout       │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│               LAYER 4: RECOVERY & HEDGE                │
│   - Automated Delta-Neutral Smart Hedge Order          │
│   - Stale Basket Holding Time Decay (Target Reduction) │
│   - Dynamic Volume-Weighted Breakeven Trailing Exit    │
└────────────────────────────────────────────────────────┘
```

---

## 🌟 ฟังก์ชันและจุดเด่นสำคัญ (Key Features)

### 1. 🛡️ Market Filter Layer (ตัวกรองสภาวะตลาด)
* **ATR Volatility Filter:** เช็ค `ATR(14)` บน H1 หากความผันผวนสูงเกินกำหนด (เช่น ข่าวแรง) EA จะไม่ออกไม้เปิดกริดใหม่
* **Trend & Sideway Regime Filter:**
  * **EMA 200 Filter:** ตรวจสอบตำแหน่งราคาเทียบกับเส้น EMA200
  * **ADX Filter:** ตรวจสอบความแรงของ Trend หาก `ADX > 30` (Trend แรงมาก) EA จะหยุดเปิด Grid รอบใหม่เพื่อไม่สวนเทรนด์
* **Session Filter:** กำหนดชั่วโมงเทรดที่สภาพคล่องสูง (London / New York) และหลีกเลี่ยงช่วงดึกตลาดเอเชียที่มี Spread กว้าง
* **Friday Early Stop:** หยุดเปิดกริดใหม่ช่วงบ่ายวันศุกร์เพื่อลดความเสี่ยง Gap ข้ามสัปดาห์

### 2. ⚙️ Grid Engine Layer (กลไกการออกและคุมไม้)
* **Volume-Weighted Basket Breakeven:** คำนวณจุดคุ้มทุนแบบถ่วงน้ำหนักตามขนาด Lot จริง
  $$\text{Basket Breakeven} = \frac{\sum (\text{Lot}_i \times \text{OpenPrice}_i)}{\sum \text{Lot}_i}$$
* **Dynamic ATR Step + Expanding Distance:** ระยะห่างระหว่างไม้สามารถขยายกว้างขึ้นตามลำดับไม้ (เช่น 250, 275, 302, 332 points) ช่วยให้ทนทางและลากได้ไกลกว่ากริดทั่วไป
* **Safe Lot Multiplier:** แนะนำตัวคูณ `1.10 - 1.25` เพื่อป้องกัน Lot บวมเร็วแบบ Martingale ดั้งเดิม

### 3. 🎯 Basket Exit & Trailing Profit (การทำกำไรแบบยกชุด)
* **Basket USD Target:** ปิดรวบทุกไม้เมื่อกำไรรวมถึงเป้าหมาย ($ USD)
* **Basket Trailing Stop:** เมื่อกำไรรวมถึงจุดเปิด Trailing ระบบจะยก Floor ล็อกกำไรตามยอดกำไรสูงสุด ป้องกันกำไรหายเมื่อราคากลับตัว

### 4. 🚨 Multi-tiered Risk Management (การควบคุมความเสี่ยงหลายระดับ)
* **Soft DD Freeze (เช่น 12% DD):** หยุดเปิดไม้กริดเพิ่มทันทีเมื่อเริ่มติดลบถึงระดับเตือนภัย
* **Margin Level Guard:** 
  * หาก Margin Level < 200% → หยุดขยายไม้
  * หาก Margin Level < 130% → ตัดไม้ที่ขาดทุนมากสุดทิ้ง 1 ไม้ เพื่อรักษา Margin
* **Hard Emergency Stop (เช่น 20% DD):** ปิดออเดอร์ทั้งหมดทันทีพร้อมส่งเสียงแจ้งเตือนและ Push Notification ไปยังมือถือ
* **Daily Loss / Daily Profit Limits:** ตั้งเป้ากำไรรายวันและตัดขาดทุนรายวันอัตโนมัติ

### 5. 🔄 Recovery & Smart Hedge Layer (ระบบกู้สถานการณ์)
* **Smart Hedge Locking:** หากราคาติดลบจนครบ `MaxGridLevels` ระบบจะเปิดออเดอร์ฝั่งตรงข้ามเพื่อล็อก Drawdown และความเสี่ยงทันที
* **Stale Basket Decay:** หากกริดค้างเกิน X ชั่วโมง (เช่น 48 ชม.) ระบบจะปรับลดเป้าหมาย Basket TP ลงอัตโนมัติเพื่อให้หลุดออกจากตลาดได้เร็วขึ้น

### 6. 📊 Real-Time On-Chart Dashboard (หน้าจอแสดงผลบนกราฟ)
* แสดงสถานะการทำงานของตัวกรองทุกตัว (Pass / Reason)
* รายละเอียด Buy Basket / Sell Basket (Levels, Lots, Breakeven, Floating P/L, Trailing Status)
* สถานะพอร์ต (Balance, Equity, Margin Level, Real-time DD%, Today Realized P/L)

---

## 📋 พารามิเตอร์การตั้งค่า (Input Parameters)

| หมวดหมู่ | พารามิเตอร์ | ค่าเริ่มต้น | คำอธิบาย |
| :--- | :--- | :--- | :--- |
| **General** | `InpMagicNumber` | `888123` | เลขระบุออเดอร์ประจำ EA |
| | `InpGridDirection` | `GRID_DIR_BOTH` | ทิศทางกริด (Both / Buy Only / Sell Only / Auto Trend) |
| **Market Filters** | `InpUseSpreadFilter` | `true` | เปิด/ปิดการตรวจ Spread |
| | `InpMaxSpreadPoints` | `45` | Spread สูงสุดที่ยอมรับได้ (Points) |
| | `InpUseATRFilter` | `true` | เปิด/ปิด ATR Volatility Filter |
| | `InpMaxATR_Points` | `600` | ATR สูงสุดที่ยอมให้เปิดรอบใหม่ (Points) |
| | `InpTrendFilterMode` | `TREND_FILTER_SIDEWAY` | โหมดกรองเทรนด์ (EMA Direction / Sideway Only / Off) |
| | `InpUseADXFilter` | `true` | เปิด/ปิด ADX Filter |
| | `InpMaxADXThreshold`| `30.0` | ADX สูงสุดสำหรับภาวะ Sideway |
| | `InpUseSessionFilter` | `true` | เปิด/ปิด ตัวกรองเวลาเทรด |
| **Grid Engine** | `InpLotMode` | `LOT_MODE_FIXED` | โหมดคำนวณ Lot (Fixed / Risk % of Equity) |
| | `InpInitialLot` | `0.01` | ขนาด Lot ไม้แรก |
| | `InpLotMultiplier` | `1.25` | ตัวคูณ Lot ต่อไม้ (แนะนำไม่เกิน 1.30) |
| | `InpBaseGridDistancePts`| `250` | ระยะกริดพื้นฐาน (Points: 250 = $2.50) |
| | `InpGridStepMultiplier`| `1.10` | ตัวคูณขยายระยะห่างไม้ถัดไป |
| | `InpMaxGridLevels` | `8` | จำนวนไม้สูงสุดต่อทิศทาง |
| **Basket Exit** | `InpBasketTP_USD` | `15.0` | เป้าหมายกำไรรวมต่อชุด ($ USD) |
| | `InpUseBasketTrailing` | `true` | เปิด/ปิด Basket Trailing Stop |
| | `InpTrailStartUSD` | `12.0` | กำไรขั้นต่ำที่จะเริ่มเปิด Trailing ($ USD) |
| | `InpTrailStepUSD` | `4.0` | ระยะถอยหลังล็อกกำไร ($ USD) |
| **Risk Guards** | `InpMaxDrawdownPercent`| `20.0` | Hard Stop ตัดขาดทุนทั้งพอร์ตเมื่อ DD ถึง % |
| | `InpDrawdownFreezePct` | `12.0` | หยุดเปิดไม้เพิ่มเมื่อ DD ถึง % |
| | `InpMarginLevelFreeze` | `200.0` | หยุดเปิดไม้เพิ่มเมื่อ Margin Level ต่ำกว่า % |
| | `InpMarginEmergencyCut`| `130.0` | ปิดไม้ที่ลบมากสุดเมื่อ Margin ต่ำกว่า % |
| **Recovery** | `InpRecoveryMode` | `RECOVERY_MODE_HEDGE` | โหมดกู้พอร์ต (Hedge Lock / Time Target Reduce) |
| | `InpHedgeLotRatio` | `1.0` | สัดส่วน Lot ของไม้ Hedge (1.0 = 100% Lock) |

---

## 📁 ไฟล์ Presets ที่เตรียมไว้ให้

ในโฟลเดอร์ `presets/`:
1. **`Conservative_XAUUSD.set`** (ความเสี่ยงต่ำ):
   - Grid Distance กว้างขึ้น (300 pts), Lot Multiplier 1.15x, Max 6 Levels
   - เหมาะกับเงินทุนเริ่มต้น $1,000 - $3,000 หรือผู้ที่เน้นความปลอดภัยสูง
2. **`Balanced_XAUUSD.set`** (มาตรฐาน - แนะนำ):
   - Grid Distance 250 pts, Lot Multiplier 1.25x, Max 8 Levels
   - เหมาะสำหรับการรัน Gold อัตโนมัติทั่วไป
3. **`Aggressive_XAUUSD.set`** (ความเสี่ยงสูง / ผลตอบแทนเร็ว):
   - Grid Distance 200 pts, Lot Multiplier 1.30x, Max 10 Levels

---

## 🛠️ วิธีการติดตั้งและใช้งานบน MT5

1. คัดลอกไฟล์ `XAUUSD_Advanced_Grid_EA.mq5` ไปไว้ที่โฟลเดอร์:
   `MQL5/Experts/` ใน MT5 Data Folder ของท่าน (กด `File` -> `Open Data Folder` บน MT5)
2. เปิด **MetaEditor** (กด `F4`) แล้วกด **Compile** (`F7`)
3. ในโปรแกรม MT5 เปิดกราฟ **XAUUSD (Gold)** แนะนำ Timeframe **M5 หรือ M15**
4. ลาก EA ลงบนกราฟ และตรวจสอบว่าได้ติ๊กเปิด **"Allow Algo Trading"**
5. เลือกโหลด Preset จากโฟลเดอร์ `presets/` ตามระดับความเสี่ยงที่ต้องการ

---

## 🧪 คำแนะนำสำหรับการ Backtest
* ใช้โหมด **"Every tick based on real ticks"** (Tick Data จริง) เพื่อความแม่นยำสูงสุด
* ทดสอบครอบคลุมช่วงวิกฤตความผันผวนสูง (เช่น ช่วงสงคราม 2022-2024, การปรับดอกเบี้ย Fed)
* ทดสอบ Stress Test ด้วย Spread ที่สูงกว่าปกติ 2-3 เท่า

---

## 📄 License
Project released under the [MIT License](LICENSE).
