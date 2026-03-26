# Gold Trading EAs for MetaTrader 5

This project contains a collection of Expert Advisors (EAs) for automated trading of Gold (XAUUSD) on the MetaTrader 5 platform. It includes multiple strategies, shared libraries, and a Python script for advanced log analysis.

## Project Structure

The project is organized into a clean and modular structure to ensure clarity and maintainability.

```
.
├── EAs/
│   ├── Adaptive/         # M5 Adaptive Multi-Factor EA
│   ├── M1_Scalper/       # M1 High-Risk Scalper EA
│   ├── Beginner/         # Beginner-friendly Trend Pullback EA
│   └── Include/          # Shared MQL5 library files
├── scripts/
│   └── analyze_ea_logs.py  # Python script for log analysis
├── logs/
│   └── (EA log files are generated here)
├── log_analysis_output/
│   └── (Output from the analysis script)
├── presets/
│   └── (EA input preset files)
├── docs/
│   └── (Supporting documentation)
├── .gitignore
└── README.md             # This file
```

## Expert Advisors

This project includes three distinct Expert Advisors. Each has its own dedicated folder within the `EAs/` directory, containing the main `.mq5` file, any specific `.mqh` include files, and a detailed `README.md`.

### 1. M5 Adaptive Multi-Factor EA

-   **Folder:** `EAs/Adaptive/`
-   **Strategy:** A sophisticated multi-factor model that adapts to changing market conditions on the M5 timeframe. It dynamically selects from multiple sub-strategies (e.g., Trend, Range, Breakout) based on a scoring system.
-   **Risk Model:** Flexible, configurable risk management.
-   **More Info:** See the `EAs/Adaptive/README.md` for a full breakdown of the strategy and its parameters.

### 2. M1 High-Risk Scalper EA

-   **Folder:** `EAs/M1_Scalper/`
-   **Strategy:** An aggressive, high-frequency scalping strategy designed for the M1 timeframe. It aims to capture small, rapid price movements.
-   **Risk Model:** High-risk, high-reward model with features like monetary-based trailing stops.
-   **More Info:** See the `EAs/M1_Scalper/README.md` for a detailed explanation of its aggressive profit-taking mechanisms.

### 3. Beginner Trend Pullback EA

-   **Folder:** `EAs/Beginner/`
-   **Strategy:** A simple, easy-to-understand trend-following strategy that enters on pullbacks to a moving average.
-   **Risk Model:** Basic, percentage-based risk.
-   **More Info:** This EA is self-contained in a single file for simplicity and is a great starting point for learning EA development.

## Installation and Setup

1.  **Clone the Repository:** Clone this repository to your local machine.
2.  **Locate MT5 Data Folder:** Open MetaTrader 5, go to `File -> Open Data Folder`. This will open the terminal's data directory.
3.  **Copy EA Files:**
    -   Copy the entire `EAs` folder from this project into the `MQL5/Experts/` directory inside your MT5 Data Folder.
4.  **Compile EAs:**
    -   In MetaTrader 5, open the **MetaEditor** (or press `F4`).
    -   In the MetaEditor's "Navigator" panel, find the `Experts/EAs` folder.
    -   Right-click on each of the EA folders (`Adaptive`, `M1_Scalper`, `Beginner`) and click **"Compile"**. This will compile all the necessary `.mq5` and `.mqh` files. Check for any errors in the "Errors" tab.
5.  **Refresh Experts List:** Back in the main MT5 terminal, right-click on "Expert Advisors" in the "Navigator" panel and select **"Refresh"**. The EAs should now appear.

## Running the EAs

1.  **Open a Chart:** Open a chart for the desired symbol and timeframe (e.g., `XAUUSD`, `M1` for the Scalper).
2.  **Attach the EA:** Drag the desired EA from the Navigator onto the chart.
3.  **Configure Inputs:** In the "Inputs" tab of the EA's properties window, load a preset file or configure the parameters manually.
4.  **Enable Algo Trading:** In the "Common" tab, ensure that **"Allow Algo Trading"** is checked.
5.  **Confirmation:** Click `OK`. A smiley face icon next to the EA's name on the chart confirms it is running correctly.

## Log Analysis with Python

The project includes a powerful Python script to analyze the standardized log files produced by the EAs.

### Requirements

-   Python 3.9+

### How to Use

1.  **Run the EAs:** Let the EAs run in the Strategy Tester or on a live/demo account to generate log files. These will typically be found in the `MQL5/Logs` or `MQL5/Profiles/Tester` directory.
2.  **Copy Logs:** Copy the relevant `.log` files into the `logs/` directory of this project.
3.  **Run the Script:** Open a terminal or command prompt, navigate to the `scripts/` directory, and run the script:

    ```bash
    cd scripts
    python analyze_ea_logs.py ../logs/*.log
    ```

4.  **View Results:**
    -   A detailed summary will be printed to the console.
    -   Structured output files (`events.csv`, `summary.csv`, `data.json`) will be automatically saved to the `log_analysis_output/` directory for further analysis in tools like Excel or Pandas.
