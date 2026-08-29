# MetaTrader 5 Expert Advisors Collection

[![MQL5](https://img.shields.io/badge/Language-MQL5-blue.svg)](https://www.mql5.com)
[![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-orange.svg)](https://www.metatrader5.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A collection of algorithmic trading Expert Advisors (EAs) and parameter presets for MetaTrader 5 (MT5).

---

## Repository Structure

```text
.
├── Experts/                      # MQL5 Expert Advisor source files (.mq5)
│   ├── XAUUSD_Advanced_Grid_EA.mq5
│   └── XAUUSD_Adaptive_MeanReversion_EA.mq5
├── presets/                      # Parameter preset files (.set)
│   ├── Advanced_Grid/            # Presets for Advanced Grid EA
│   │   ├── Conservative_XAUUSD.set
│   │   ├── Balanced_XAUUSD.set
│   │   └── Aggressive_XAUUSD.set
│   └── MeanReversion_Grid/       # Presets for Mean-Reversion Grid EA
│       ├── SmallAccount_500USD.set
│       ├── Standard_2000USD.set
│       └── Pro_5000USD.set
├── LICENSE                       # MIT License
└── README.md                     # Repository documentation
```

---

## Available EAs and Presets

| Expert Advisor (.mq5) | Recommended Timeframe / Asset | Preset Directory |
| :--- | :--- | :--- |
| [`Experts/XAUUSD_Advanced_Grid_EA.mq5`](Experts/XAUUSD_Advanced_Grid_EA.mq5) | XAUUSD (M5 / M15) | [`presets/Advanced_Grid/`](presets/Advanced_Grid/) |
| [`Experts/XAUUSD_Adaptive_MeanReversion_EA.mq5`](Experts/XAUUSD_Adaptive_MeanReversion_EA.mq5) | XAUUSD (M15) | [`presets/MeanReversion_Grid/`](presets/MeanReversion_Grid/) |

---

## Installation and Setup (MT5)

1. Clone or Download Repository:
   ```bash
   git clone https://github.com/BlamzKunG/XAUUSD-Grid-EA.git
   ```
2. Copy Files to MT5 Data Folder:
   - In MetaTrader 5, click File -> Open Data Folder.
   - Copy all `.mq5` files from `Experts/` into `MQL5/Experts/`.
   - Copy the `presets/` folder into `MQL5/Presets/`.
3. Compile:
   - Open MetaEditor (F4).
   - Open the target EA from the Navigator panel.
   - Click Compile (F7) and ensure 0 errors, 0 warnings.
4. Attach to Chart:
   - Drag the compiled EA from MT5 Navigator onto your chart.
   - In the EA settings popup, check "Allow Algo Trading".
   - (Optional) Click Load in the Inputs tab to select a `.set` file from `presets/`.

---

## Backtesting Guidelines

- Execution Model: Use "Every tick based on real ticks" for accurate simulation.
- Spread: Test with realistic broker spreads and perform stress tests with elevated spreads.
- Forward Testing: Validate any EA on a Demo account before live deployment.

---

## Adding New EAs to this Collection

When contributing or adding new EAs to this repository:
1. Place the MQL5 source file in the [`Experts/`](Experts/) directory.
2. Place associated `.set` files in a dedicated subfolder under [`presets/<EA_Name>/`](presets/).
3. Add an entry to the [Available EAs and Presets](#available-eas-and-presets) table above.

---

## License and Disclaimer

- License: Distributed under the MIT License.
- Risk Disclaimer: Trading foreign exchange, commodities, and CFDs carries a high level of risk. These Expert Advisors are provided for educational and research purposes. Use at your own discretion.
