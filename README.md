# 🏆 Institutional XAUUSD (Gold) EA Suite (MetaTrader 5)

[![MQL5](https://img.shields.io/badge/MQL5-Expert%20Advisors-blue.svg)](https://www.mql5.com)
[![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-orange.svg)](https://www.metatrader5.com)
[![Asset](https://img.shields.io/badge/Asset-XAUUSD%20%7C%20Gold-yellow.svg)]()
[![Architecture](https://img.shields.io/badge/Architecture-Multi--Tier%20Risk%20Guard-red.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A production-grade, institutional suite of **Expert Advisors (EAs) for MetaTrader 5 (MT5)** engineered specifically for **XAUUSD (Gold)**. Built upon the core philosophy of **"Survive First, Profit Later"**, every system in this repository strictly eliminates toxic Martingale (x1.5 / x2.0) and enforces multi-layered risk controls, dynamic ATR-based spacing, market regime filters, and hard emergency equity protection.

---

## 📑 สารบัญระบบ (Table of Contents)
1. [เปรียบเทียบระบบในคลัง (EA Comparison Catalog)](#-ea-comparison-catalog)
2. [หลักการสากลประจำ Suite (Universal Architecture & Core Directives)](#-universal-architecture--core-directives)
3. [รายละเอียดระบบที่ 1: XAUUSD Advanced 4-Layer Grid EA](#-1-xauusd-advanced-4-layer-grid-ea)
4. [รายละเอียดระบบที่ 2: XAUUSD Adaptive Mean-Reversion Grid EA](#-2-xauusd-adaptive-mean-reversion-grid-ea)
5. [แนวทางจัดสรรขนาดพอร์ตและ Presets (Capital Sizing & Presets)](#-capital-sizing--presets)
6. [คู่มือการติดตั้งและการทดสอบ Backtest บน MT5](#-installation--backtesting-guide)
7. [ข้อห้ามสำคัญสำหรับการรัน Grid ทองคำ](#-critical-dos--donts)
8. [Risk Disclaimer & License](#-risk-disclaimer)

---

## 📊 EA Comparison Catalog

| คุณสมบัติ | [1] Advanced 4-Layer Grid EA | [2] Adaptive Mean-Reversion EA |
| :--- | :--- | :--- |
| **ไฟล์ Source Code** | [`XAUUSD_Advanced_Grid_EA.mq5`](Experts/XAUUSD_Advanced_Grid_EA.mq5) | [`XAUUSD_Adaptive_MeanReversion_EA.mq5`](Experts/XAUUSD_Adaptive_MeanReversion_EA.mq5) |
| **แนวคิดกลยุทธ์** | 4-Layer Multi-Filter + Auto-Hedge Recovery | Multi-TF Mean-Reversion Sniper (RSI + BB) |
| **Timeframe หลัก** | M5 / M15 (ATR H1 Filter) | M15 (Entry) + H1 (Trend Filter) |
| **จุดเข้าไม้แรก (Entry)** | กรองสภาวะตลาด (ATR, ADX, EMA, Session) | กรองหลาย TF: RSI < 30 / > 70 + แตะขอบ BB + H1 ADX < 22 |
| **การคำนวณระยะ Grid** | Dynamic ATR + Expanding Multiplier Step | Dynamic ATR(M15) $\times$ Multiplier ($4 - $12 USD) |
| **การคุมจำนวนไม้** | 6 – 8 ไม้ (มีเพดาน Lot รวม) | 3 – 5 ไม้ (Strict Hard Cap) |
| **กลไกการปิดทำกำไร** | Volume-Weighted Basket BE + USD TP + Trailing | Hybrid: % Balance / USD Target / ATR Distance |
| **ระบบกู้สถานการณ์** | Delta-Neutral Smart Hedge Lock | Trend Escape Emergency Cut + ATR H1 Emergency SL |
| **ระดับความเสี่ยง** | ปานกลาง (Balanced / Adaptive) | ต่ำ (Conservative / Capital Preservation) |

---

## 🛡️ Universal Architecture & Core Directives

ระบบทุกตัวใน Repository นี้ถูกพัฒนาขึ้นภายใต้มาตรฐานวิศวกรรมความเสี่ยงระดับเดียวกัน:

```
┌─────────────────────────────────────────────────────────────────┐
│                 1. MARKET REGIME & FILTER LAYER                 │
│  - Multi-TF ATR Volatility Guard (หยุดเมื่อตลาดผันผวนสูงผิดปกติ)      │
│  - ADX Trend Strength Filter (หยุดเมื่อ Trend แรงเกิน ADX > 22-25)│
│  - Session & Spread Guard (เน้น London/NY, เลี่ยง Asian Midnight) │
└────────────────────────────────┬────────────────────────────────┘
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                    2. GRID & LOT ENGINE LAYER                   │
│  - Zero Toxic Martingale: Lot Multiplier ไม่เกิน 1.10x - 1.25x  │
│  - Dynamic Volatility Spacing: ระยะไม้ปรับตาม ATR ทองคำจริง        │
│  - Hard Level Cap: จำกัดจำนวนไม้ 3-8 ไม้เด็ดขาด ไม่ถัวไร้ขีดจำกัด │
└────────────────────────────────┬────────────────────────────────┘
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                 3. BASKET PROFIT & EXIT LAYER                   │
│  - Volume-Weighted Breakeven: คำนวณจุดคุ้มทุนถ่วงน้ำหนักตาม Lot จริง │
│  - Basket Trailing Stop: ยก Floor ล็อกกำไรเมื่อราคากลับตัวแรง       │
│  - Mutual Basket Exclusion: ไม่เปิด Buy/Sell สวนกันจน Margin บวม │
└────────────────────────────────┬────────────────────────────────┘
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│               4. MULTI-TIER RISK MANAGEMENT LAYER               │
│  - Tier 1 (Soft Freeze): หยุดเปิดไม้เพิ่มเมื่อ Drawdown ถึงระดับเตือน│
│  - Tier 2 (Margin Guard): Freeze < 200%, ตัดไม้ลบมากสุด < 120-130%│
│  - Tier 3 (Hard Stop): Emergency Close All เมื่อ DD ชนเพดาน       │
│  - Daily Limits & Cooldown Buffer (หยุดพักหลังจบ Cycle)         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🧩 [1] XAUUSD Advanced 4-Layer Grid EA

### วัตถุประสงค์
ระบบกริดอัจฉริยะที่ผสมผสานตัวกรอง 4 ชั้น พร้อมกลไก **Expanding Grid Distance** (ระยะห่างไม้ขยายขึ้นเรื่อยๆ) และ **Smart Hedge Lock** เพื่อป้องกัน Drawdown ลากยาวเมื่อราคาเกิด Super Trend

### จุดเด่น
1. **Expanding Step Multiplier:** ระยะไม้จะกว้างขึ้นตามลำดับ (เช่น 250 -> 275 -> 302 -> 332 points) ช่วยให้ทนการลากได้ไกลกว่ากริดทั่วไปถึง 2-3 เท่า
2. **Automated Delta-Neutral Hedge:** หากติดลบครบ `MaxGridLevels` ระบบจะเปิดไม้ฝั่งตรงข้ามเพื่อล็อก Drawdown พอร์ตให้อยู่กับที่ทันที
3. **Stale Basket Target Decay:** หากถือไม้นานเกิน 48 ชม. ระบบจะลดเป้ากำไรลงอัตโนมัติเพื่อให้พอร์ตหลุดออกมาถือเงินสดได้เร็วที่สุด

---

## 🎯 [2] XAUUSD Adaptive Mean-Reversion Grid EA

### วัตถุประสงค์
ระบบ Grid สาย Conservative ที่เน้น **"อยู่รอดก่อนกำไร"** จะไม่เปิดไม้พร่ำเพรื่อ แต่จะดักเข้าเฉพาะจุดที่ราคา Overbought/Oversold ในกรอบ Sideway เท่านั้น

### จุดเด่น
1. **Multi-Timeframe Entry Gate:**
   - **H1:** ต้องเป็นตลาด Sideway (`ADX < 22` และ `EMA50/EMA200` ไม่ถ่างเกินกำหนด)
   - **M15:** ราคาต้องแตะขอบ Bollinger Band พร้อมกับ `RSI < 30` (Buy) หรือ `RSI > 70` (Sell)
2. **Trend Escape Protection:** หากถือ Buy อยู่ แต่ตลาดเปลี่ยนโครงสร้างเป็น Strong Downtrend (`H1 ADX > 28` + `Price < EMA200`) ระบบจะหยุดเปิดไม้เพิ่มทันที และตัดขาดทุนหากเกินเพดานที่ยอมรับได้
3. **Emergency SL ตาม ATR H1:** ตั้งระยะฉุกเฉินอิงจากจุดเปิดไม้แรก $Entry \pm (\text{ATR}_{H1} \times 3.0)$
4. **Post-Basket Cooldown Timer:** พักระบบ 30–60 นาทีหลังปิด Basket เพื่อไม่ให้รีบเปิดออเดอร์ซ้ำช่วงตลาดกำลังผันผวน

---

## 💰 Capital Sizing & Presets

ตารางแนะนำการตั้งค่าและขนาดพอร์ตโฟลิโอสำหรับ XAUUSD:

| ขนาดพอร์ต ($) | แนะนำ EA | Preset File | Initial Lot | Multiplier | Max Levels | Equity Stop |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **$500 - $1,000** | Mean-Reversion | [`SmallAccount_500USD.set`](presets/MeanReversion_Grid/SmallAccount_500USD.set) | `0.01` | `1.00x` (Fixed) | 3 ไม้ | 5.0% |
| **$1,000 - $3,000** | Advanced Grid | [`Conservative_XAUUSD.set`](presets/Advanced_Grid/Conservative_XAUUSD.set) | `0.01` | `1.15x` | 6 ไม้ | 15.0% |
| **$2,000 - $5,000** | Mean-Reversion | [`Standard_2000USD.set`](presets/MeanReversion_Grid/Standard_2000USD.set) | `0.01` | `1.15x` | 5 ไม้ | 7.0% |
| **$5,000+** | Advanced Grid | [`Balanced_XAUUSD.set`](presets/Advanced_Grid/Balanced_XAUUSD.set) | `0.01 - 0.02` | `1.25x` | 8 ไม้ | 20.0% |
| **$5,000+** | Mean-Reversion | [`Pro_5000USD.set`](presets/MeanReversion_Grid/Pro_5000USD.set) | `0.02 - 0.03` | `1.20x` | 5 ไม้ | 8.0% |

---

## 📂 โครงสร้าง Repository (Directory Layout)

```
XAUUSD-Grid-EA/
├── Experts/
│   ├── XAUUSD_Advanced_Grid_EA.mq5           # [EA 1] 4-Layer Institutional Grid System
│   └── XAUUSD_Adaptive_MeanReversion_EA.mq5   # [EA 2] Multi-TF Mean-Reversion Precision Grid
├── presets/
│   ├── Advanced_Grid/
│   │   ├── Conservative_XAUUSD.set           # ความเสี่ยงต่ำ ทนลากไกล
│   │   ├── Balanced_XAUUSD.set               # ค่ามาตรฐานแนะนำสำหรับทองคำ
│   │   └── Aggressive_XAUUSD.set             # ผลตอบแทนสูง เน้นรอบไว
│   └── MeanReversion_Grid/
│       ├── SmallAccount_500USD.set           # พอร์ตเล็ก $500 เน้นคุมเสี่ยงสูงสุด
│       ├── Standard_2000USD.set              # พอร์ตขนาดมาตรฐาน $2,000
│       └── Pro_5000USD.set                   # พอร์ตขนาดใหญ่ $5,000+
├── LICENSE                                   # MIT License
└── README.md                                 # คู่มือการใช้งานฉบับสมบูรณ์
```

---

## 🛠️ Installation & Backtesting Guide

### ขั้นตอนการติดตั้งบน MetaTrader 5
1. โคลนหรือดาวน์โหลด Repository นี้
2. คัดลอกไฟล์จากโฟลเดอร์ `Experts/` ไปวางที่ `MQL5/Experts/` ใน MT5 Data Folder ของคุณ (`File` $\rightarrow$ `Open Data Folder`)
3. คัดลอกโฟลเดอร์ `presets/` ไปวางที่ `MQL5/Presets/`
4. เปิดโปรแกรม **MetaEditor (F4)** แล้วกด **Compile (F7)** ที่ไฟล์ EA
5. เปิดกราฟ **XAUUSD (Gold)** แนะนำ Timeframe **M15**
6. ลาก EA ลงบนกราฟ ติ๊กเปิด **"Allow Algo Trading"** แล้วกดโหลดไฟล์ Preset ตามขนาดพอร์ตที่ต้องการ

### คำแนะนำสำหรับการทดสอบ Backtest
* **Model:** เลือก **"Every tick based on real ticks"** (Tick Data จริงจากโบรกเกอร์) เท่านั้น
* **Spread:** ทดสอบจำลองทั้งช่วง Spread ปกติ (20-30 pts) และ Stress Test ด้วย Spread ถ่าง (60-90 pts)
* **Date Range:** ควรทดสอบย้อนหลังครอบคลุมเหตุการณ์ Black Swan สำคัญ เช่น วิกฤต COVID-19, สงคราม 2022-2024, และช่วงประกาศดอกเบี้ย Fed Rate
* **Key Metric:** ให้ความสำคัญกับ **Max Drawdown %** และ **Recovery Factor** มากกว่ายอดกำไรสุทธิ

---

## 🚫 Critical Do's & Don'ts

```
❌ ข้อห้ามเด็ดขาด (DON'TS)
• ห้ามใช้ตัวคูณ Martingale x1.5 หรือ x2.0 กับทองคำ
• ห้ามรัน Grid โดยไม่มีการตั้ง Max Grid Levels และ Equity Stop
• ห้ามเปิดไม้ถัวสวนเทรนด์เมื่อ H1 ADX > 30
• ห้ามถือ Grid ข้ามข่าวระดับ High Impact (NFP / CPI / FOMC) โดยไม่มีระบบป้องกัน
• ห้ามเพิ่ม Lot เพื่อ "เอาคืน" หลังโดน Cut Loss

✅ แนวทางปฏิบัติที่ถูกต้อง (DO'S)
• รันบนบัญชี ECN / Raw Spread ที่มี Spread ทองคำต่ำ
• ใช้ Dynamic ATR Step เพื่อให้ระยะห่างยืดหยุ่นตามความผันผวนจริง
• ตั้ง Equity Drawdown Hard Stop (5% - 15%) เสมอ
• ตรวจสอบ Margin Level เป็นประจำและเลือก Leverage ที่เหมาะสม (1:100 - 1:500)
• ทำ Forward Test บนบัญชี Demo อย่างน้อย 2-4 สัปดาห์ก่อนใช้งานจริง
```

---

## 📄 Risk Disclaimer & License

> **Risk Disclaimer:** การซื้อขายสัญญาซื้อขายส่วนต่าง (CFDs) บนทองคำ (XAUUSD) มีความเสี่ยงสูงและอาจไม่เหมาะสำหรับนักลงทุนทุกคน ผลการดำเนินงานในอดีตไม่ได้รับประกันผลลัพธ์ในอนาคต ซอฟต์แวร์นี้จัดทำขึ้นเพื่อการศึกษาและการวิจัยเชิงกลยุทธ์ ผู้ใช้งานต้องรับผิดชอบต่อความเสี่ยงและผลการตัดสินใจลงทุนของตนเอง

Released under the [MIT License](LICENSE).
