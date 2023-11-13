#property link          "https://www.earnforex.com/metatrader-indicators/BB-Breakout-MTF/"
#property version       "1.00"
#property strict
#property copyright     "EarnForex.com - 2023"
#property description   "This indicator shows the status of the Bollinger Bands indicator's signals for multiple timeframes."
#property description   "Switch between breakout, pullback, and re-entry signals."
#property description   ""
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of this software cannot be held responsible for any damage or loss."
#property description   ""
#property description   "Find more on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window
#property indicator_buffers 1

#include <MQLTA Utils.mqh> // For panel edits.

enum ENUM_BB_SIGNAL_TYPE
{
    BB_SIGNAL_TYPE_PULLBACK, // Pullback
    BB_SIGNAL_TYPE_BREAKOUT, // Breakout
    BB_SIGNAL_TYPE_REENTRY // Re-entry
};

enum ENUM_CANDLE_TO_CHECK
{
    CURRENT_CANDLE = 0,  // Current
    CLOSED_CANDLE = 1    // Previous
};

input string Comment_1 = "====================";          // Indicator settings
input int BBPeriod = 20;                                  // BB Period
input int BBShift = 0;                                    // BB Shift
input ENUM_APPLIED_PRICE BBAppliedPrice = PRICE_CLOSE;    // BB Applied Price
input double BBDeviation = 2;                             // BB Deviation
input ENUM_CANDLE_TO_CHECK CandleToCheck = CLOSED_CANDLE; // Candle to use for analysis
input ENUM_BB_SIGNAL_TYPE SignalType = BB_SIGNAL_TYPE_PULLBACK; // Signal Type
input string Comment_2b = "===================="; // Enabled timeframes
input bool TFM1 = true;                           // Enable M1
input bool TFM5 = true;                           // Enable M5
input bool TFM15 = true;                          // Enable M15
input bool TFM30 = true;                          // Enable M30
input bool TFH1 = true;                           // Enable H1
input bool TFH4 = true;                           // Enable H4
input bool TFD1 = true;                           // Enable D1
input bool TFW1 = true;                           // Enable W1
input bool TFMN1 = true;                          // Enable MN1
input string Comment_3 = "====================";  // Notification options
input bool EnableNotify = false;                  // Enable notifications
input bool SendAlert = true;                      // Native alerts
input bool SendEmail = false;                     // Email alerts
input bool SendApp = false;                       // Push-notifications with alerts
input string Comment_4 = "====================";  // Graphical objects
input bool DrawWindowEnabled = true;              // Draw window
input int Xoff = 20;                              // Horizontal spacing for the control panel
input int Yoff = 20;                              // Vertical spacing for the control panel
input string IndicatorName = "BBMTF";             // Indicator name

double LastBreakout[9];

bool Positive = false;
bool Negative = false;
bool Neutral = false;
bool Unknown = false;

bool TFEnabled[9];
int TFValues[9];
string TFText[9];
int IndCurr[9];

double BufferZero[1];

double LastAlertDirection = 2; // Signal that was alerted on previous alert. Double because BufferZero is double. "2" because "0", "1", and "-1" are taken for signals.

double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovX, PanelMovY, PanelLabX, PanelLabY, PanelRecX;

int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName);

    CleanChart();

    TFEnabled[0] = TFM1;
    TFEnabled[1] = TFM5;
    TFEnabled[2] = TFM15;
    TFEnabled[3] = TFM30;
    TFEnabled[4] = TFH1;
    TFEnabled[5] = TFH4;
    TFEnabled[6] = TFD1;
    TFEnabled[7] = TFW1;
    TFEnabled[8] = TFMN1;
    TFValues[0] = PERIOD_M1;
    TFValues[1] = PERIOD_M5;
    TFValues[2] = PERIOD_M15;
    TFValues[3] = PERIOD_M30;
    TFValues[4] = PERIOD_H1;
    TFValues[5] = PERIOD_H4;
    TFValues[6] = PERIOD_D1;
    TFValues[7] = PERIOD_W1;
    TFValues[8] = PERIOD_MN1;
    TFText[0] = "M1";
    TFText[1] = "M5";
    TFText[2] = "M15";
    TFText[3] = "M30";
    TFText[4] = "H1";
    TFText[5] = "H4";
    TFText[6] = "D1";
    TFText[7] = "W1";
    TFText[8] = "MN1";
    Positive = false;
    Negative = false;

    SetIndexBuffer(0, BufferZero);
    SetIndexStyle(0, DRAW_NONE);

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;

    PanelMovX = (int)MathRound(60 * DPIScale);
    PanelMovY = (int)MathRound(20 * DPIScale);
    PanelLabX = (PanelMovX + 1) * 2 + 1;
    PanelLabY = PanelMovY;
    PanelRecX = PanelLabX + 4;

    CalculateLevels();

    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    CalculateLevels();

    FillBuffers();
    if (EnableNotify)
    {
        Notify();
    }

    if (DrawWindowEnabled) DrawPanel();

    return rates_total;
}

void OnDeinit(const int reason)
{
    CleanChart();
}

//+------------------------------------------------------------------+
//| Processes key presses and mouse clicks.                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_KEYDOWN)
    {
        if (lparam == 27) // Escape key pressed.
        {
            ChartIndicatorDelete(0, 0, IndicatorName);
        }
    }
    if (id == CHARTEVENT_OBJECT_CLICK) // Timeframe switching.
    {
        if (StringFind(sparam, "-P-TF-") >= 0)
        {
            string ClickDesc = ObjectGetString(0, sparam, OBJPROP_TEXT);
            ChangeChartPeriod(ClickDesc);
        }
    }
}

//+------------------------------------------------------------------+
//| Delets all chart objects created by the indicator.               |
//+------------------------------------------------------------------+
void CleanChart()
{
    ObjectsDeleteAll(ChartID(), IndicatorName);
}

//+------------------------------------------------------------------+
//| Switch chart timeframe.                                          |
//+------------------------------------------------------------------+
void ChangeChartPeriod(string Button)
{
    StringReplace(Button, "*", "");
    int NewPeriod = 0;
    if (Button == "M1") NewPeriod = PERIOD_M1;
    if (Button == "M5") NewPeriod = PERIOD_M5;
    if (Button == "M15") NewPeriod = PERIOD_M15;
    if (Button == "M30") NewPeriod = PERIOD_M30;
    if (Button == "H1") NewPeriod = PERIOD_H1;
    if (Button == "H4") NewPeriod = PERIOD_H4;
    if (Button == "D1") NewPeriod = PERIOD_D1;
    if (Button == "W1") NewPeriod = PERIOD_W1;
    if (Button == "MN1") NewPeriod = PERIOD_MN1;
    ChartSetSymbolPeriod(0, Symbol(), NewPeriod);
}

//+------------------------------------------------------------------+
//| Main function to detect Positive, Negative, Uncertain state.     |
//+------------------------------------------------------------------+
void CalculateLevels()
{
    int EnabledCount = 0;
    int PositiveCount = 0;
    int NegativeCount = 0;
    int NeutralCount = 0;
    int UnknownCount = 0;
    Positive = false;
    Negative = false;
    Neutral = false;
    Unknown = false;
    int Shift = 0;
    if (CandleToCheck == CLOSED_CANDLE) Shift = 1;
    int MaxBars = BBPeriod + Shift + 1;
    ArrayInitialize(LastBreakout, 0);
    for (int i = 0; i < ArraySize(TFValues); i++)
    {
        if (!TFEnabled[i]) continue;
        if (iBars(Symbol(), TFValues[i]) < MaxBars)
        {
            MaxBars = iBars(Symbol(), TFValues[i]);
            Print("Please load more historical candles. Current calculation only on ", MaxBars, " bars for timeframe ", TFText[i], ".");
            if (MaxBars < 0)
            {
                break;
            }
        }
        EnabledCount++;
        string TFDesc = TFText[i];

        for (int j = Shift; j < iBars(Symbol(), TFValues[i]); j++)
        {
            double BB_Main =  iBands(Symbol(), TFValues[i], BBPeriod, BBDeviation, BBShift, BBAppliedPrice, MODE_MAIN,  j);
            double BB_Upper = iBands(Symbol(), TFValues[i], BBPeriod, BBDeviation, BBShift, BBAppliedPrice, MODE_UPPER, j);
            double BB_Lower = iBands(Symbol(), TFValues[i], BBPeriod, BBDeviation, BBShift, BBAppliedPrice, MODE_LOWER, j);
            double O = iOpen( Symbol(), TFValues[i], j);
            double H = iHigh( Symbol(), TFValues[i], j);
            double L = iLow(  Symbol(), TFValues[i], j);
            double C = iClose(Symbol(), TFValues[i], j);
            
            IndCurr[i] = 2; // Pre-load with a 'searching for signal' signal.

            // The cycle goes backwards and uses three signal states until a signal is encountered:
            //  1. No signal - just any normal bar. Continue to search.
            //  2. Neutral signal - a bar toucheing the middle line. End search.
            //  3. Buy/Sell siganl - a bar defined below. End search.

            // Buy on lower breakout, sell on upper breakout, cancel signal after touching the middle line.
            // If the same candle touches the middle line and the bands - check if its bearish/bullish. If it touches all lines - it's a neutral signal.
            if (SignalType == BB_SIGNAL_TYPE_PULLBACK)
            {
                if ((L < BB_Lower) && // Candle pierces the lower line. 
                    (H < BB_Upper))   // Candle doesn't touche the upper line.
                {
                    if ((BB_Main >= L) && (BB_Main <= H) && (C >= O)) // Candle crosses the middle line and isn't bearish.
                    {
                        IndCurr[i] = 0; // Neutral signal.
                    }
                    else IndCurr[i] = 1; // Buy signal.
                    break; // Finished with this timeframe.
                }
                else if ((L > BB_Lower) && // Candle doesn't touche the lower line.
                         (H > BB_Upper))   // Candle pierces the upperline. 
                {
                    if ((BB_Main >= L) && (BB_Main <= H) && (C <= O)) // Candle crosses the middle line and isn't bullish.
                    {
                        IndCurr[i] = 0; // Neutral signal.
                    }
                    else IndCurr[i] = -1; // Sell signal.
                    break; // Finished with this timeframe.
                }
            }
            // Sell on lower breakout, buy on upper breakout, cancel signal after touching the middle line.
            else if (SignalType == BB_SIGNAL_TYPE_BREAKOUT)
            {
                if ((L < BB_Lower) && // Candle pierces the lower line. 
                    (H < BB_Upper))   // Candle doesn't touche the upper line.
                {
                    if ((BB_Main >= L) && (BB_Main <= H) && (C >= O)) // Candle crosses the middle line and isn't bearish.
                    {
                        IndCurr[i] = 0; // Neutral signal.
                    }
                    else IndCurr[i] = -1; // Sell signal.
                    break; // Finished with this timeframe.
                }
                else if ((L > BB_Lower) && // Candle doesn't touche the lower line.
                         (H > BB_Upper))   // Candle pierces the upperline. 
                {
                    if ((BB_Main >= L) && (BB_Main <= H) && (C <= O)) // Candle crosses the middle line and isn't bullish.
                    {
                        IndCurr[i] = 0; // Neutral signal.
                    }
                    else IndCurr[i] = 1; // Buy signal.
                    break; // Finished with this timeframe.
                }
            }
            // Buy on re-enter after closing below the lower line, sell on re-enter after closing above the upper line, cancel signal after touching the middle line. Uses OHLC.
            else if (SignalType == BB_SIGNAL_TYPE_REENTRY)
            {
                if (j + 1 >= iBars(Symbol(), TFValues[i]))
                {
                    IndCurr[i] = 0; // Neutral signal.
                    break;
                }
                double C_prev = iClose(Symbol(), TFValues[i], j + 1);
                
                if ((C_prev < BB_Lower) && // Previous candle closes below the lower line. 
                    (C      > BB_Lower) && // Current candle closes above the lower line.
                    (H      < BB_Main))    // And didn't reach the middle line.
                {
                    IndCurr[i] = 1; // Buy signal.
                    break; // Finished with this timeframe.
                }
                if ((C_prev > BB_Upper) && // Previous candle closes above the uoper line. 
                    (C      < BB_Upper) && // Current candle closes below the upper line.
                    (L      > BB_Main))    // And didn't reach the middle line.
                {
                    IndCurr[i] = -1; // Sell signal.
                    break; // Finished with this timeframe.
                }
            }
            if ((BB_Main >= L) && (BB_Main <= H)) // Candle crosses the middle line.
            {
                IndCurr[i] = 0; // Neutral signal.
                break; // Neutral signal.
            }
        } // End of the cycle through bars for one timeframe.

        if (IndCurr[i] == 1) PositiveCount++;
        else if (IndCurr[i] == -1) NegativeCount++;
        else if (IndCurr[i] == 0) NeutralCount++;
        else if (IndCurr[i] == 2) UnknownCount++;
    }
    
    if (PositiveCount == EnabledCount) Positive = true;
    else if (NegativeCount == EnabledCount) Negative = true;
    else if (NeutralCount == EnabledCount) Neutral = true;
    else if (UnknownCount == EnabledCount) Unknown = true;
}

//+------------------------------------------------------------------+
//| Fills indicator buffers.                                         |
//+------------------------------------------------------------------+
void FillBuffers()
{
    if (Positive) BufferZero[0] = 1;
    else if (Negative) BufferZero[0] = -1;
    else BufferZero[0] = 0;
}

//+------------------------------------------------------------------+
//| Alert processing.                                                |
//+------------------------------------------------------------------+
void Notify()
{
    if (!EnableNotify) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    if (LastAlertDirection == 2)
    {
        LastAlertDirection = BufferZero[0]; // Avoid initial alert when just attaching the indicator to the chart.
        return;
    }
    if (BufferZero[0] == LastAlertDirection) return; // Avoid alerting about the same signal.
    LastAlertDirection = BufferZero[0];
    string SituationString = "UNCERTAIN";
    if (Positive) SituationString = "BUY";
    if (Negative) SituationString = "SELL";

    string SignalString = "";
    if (SignalType == BB_SIGNAL_TYPE_BREAKOUT) SignalString = "Breakout";
    else if (SignalType == BB_SIGNAL_TYPE_PULLBACK) SignalString = "Pullback";
    else if (SignalType == BB_SIGNAL_TYPE_REENTRY) SignalString = "Re-entry";

    if (SendAlert)
    {
        string AlertText = Symbol() + " Notification: BB MTF Signal (" + SignalString + "): " + SituationString + ".";
        Alert(AlertText);
    }
    if (SendEmail)
    {
        string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
        string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\nNotification for " + Symbol() + "\r\n";
        EmailBody += "BB MTF Signal (" + SignalString + "): " + SituationString + ".";
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + Symbol() + " - BB MTF Signal (" + SignalString + "): " + SituationString + ".";
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
}

string PanelBase = IndicatorName + "-P-BAS";
string PanelLabel = IndicatorName + "-P-LAB";
string PanelDAbove = IndicatorName + "-P-DABOVE";
string PanelDBelow = IndicatorName + "-P-DBELOW";
string PanelSig = IndicatorName + "-P-SIG";
//+------------------------------------------------------------------+
//| Main panel drawing function.                                     |
//+------------------------------------------------------------------+
void DrawPanel()
{
    string IndicatorNameTextBox = "MT BB";
    if (SignalType == BB_SIGNAL_TYPE_PULLBACK) IndicatorNameTextBox += " (Pullback)";
    else if (SignalType == BB_SIGNAL_TYPE_BREAKOUT) IndicatorNameTextBox += " (Breakout)";
    else if (SignalType == BB_SIGNAL_TYPE_REENTRY) IndicatorNameTextBox += " (Re-entry)";
    int Rows = 1;
    ObjectCreate(0, PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, PanelBase, OBJPROP_XDISTANCE, Xoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_YDISTANCE, Yoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 2) * 1 + 2);
    ObjectSetInteger(0, PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelBase, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_COLOR, clrBlack);

    DrawEdit(PanelLabel,
             Xoff + 2,
             Yoff + 2,
             PanelLabX,
             PanelLabY,
             true,
             10,
             "Multi-Timeframe Indicator",
             ALIGN_CENTER,
             "Consolas",
             IndicatorNameTextBox,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);

    for (int i = 0; i < ArraySize(TFValues); i++)
    {
        if (!TFEnabled[i]) continue;
        string TFRowObj = IndicatorName + "-P-TF-" + TFText[i];
        string IndCurrObj = IndicatorName + "-P-ICURR-V-" + TFText[i];
        string TFRowText = TFText[i];
        string IndCurrText = "";
        string IndCurrToolTip = "";

        color IndCurrBackColor = clrKhaki;
        color IndCurrTextColor = clrNavy;
        color IndPrevDiffBackColor = clrKhaki;
        color IndPrevDiffTextColor = clrNavy;

        if (IndCurr[i] == 1)
        {
            IndCurrText = CharToString(225); // Up arrow.
            IndCurrToolTip = "Buy Signal";
            IndCurrBackColor = clrDarkGreen;
            IndCurrTextColor = clrWhite;
        }
        else if (IndCurr[i] == -1)
        {
            IndCurrText = CharToString(226); // Down arrow.
            IndCurrToolTip = "Sell Signal";
            IndCurrBackColor = clrDarkRed;
            IndCurrTextColor = clrWhite;
        }
        else if (IndCurr[i] == 0)
        {
            IndCurrText = CharToString(128); // Neutral.
            IndCurrToolTip = "No Signal";
            IndCurrBackColor = clrKhaki;
            IndCurrTextColor = clrBlack;
        }
        else if (IndCurr[i] == 2)
        {
            IndCurrText = CharToString(160); // Unknown.
            IndCurrToolTip = "Unknown";
            IndCurrBackColor = clrKhaki;
            IndCurrTextColor = clrBlack;
        }

        DrawEdit(TFRowObj,
                 Xoff + 2,
                 Yoff + (PanelMovY + 1) * Rows + 2,
                 PanelMovX,
                 PanelLabY,
                 true,
                 8,
                 "Situation Detected in the Timeframe",
                 ALIGN_CENTER,
                 "Consolas",
                 TFRowText,
                 false,
                 clrNavy,
                 clrKhaki,
                 clrBlack);

        DrawEdit(IndCurrObj,
                 Xoff + PanelMovX + 4,
                 Yoff + (PanelMovY + 1) * Rows + 2,
                 PanelMovX,
                 PanelLabY,
                 true,
                 8,
                 IndCurrToolTip,
                 ALIGN_CENTER,
                 "Wingdings",
                 IndCurrText,
                 false,
                 IndCurrTextColor,
                 IndCurrBackColor,
                 clrBlack);

        Rows++;
    }
    string SigText = "";
    color SigColor = clrNavy;
    color SigBack = clrKhaki;
    if (Positive)
    {
        SigText = "Buy";
        SigColor = clrWhite;
        SigBack = clrDarkGreen;
    }
    else if (Negative)
    {
        SigText = "Sell";
        SigColor = clrWhite;
        SigBack = clrDarkRed;
    }
    else if (Neutral)
    {
        SigText = "Neutral";
    }
    else if (Unknown)
    {
        SigText = "Unknown";
    }
    else
    {
        SigText = "Uncertain";
    }

    DrawEdit(PanelSig,
             Xoff + 2,
             Yoff + (PanelMovY + 1) * Rows + 2,
             PanelLabX,
             PanelLabY,
             true,
             8,
             "Situation Considering All Timeframes",
             ALIGN_CENTER,
             "Consolas",
             SigText,
             false,
             SigColor,
             SigBack,
             clrBlack);

    Rows++;

    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 1) * Rows + 3);
}
//+------------------------------------------------------------------+