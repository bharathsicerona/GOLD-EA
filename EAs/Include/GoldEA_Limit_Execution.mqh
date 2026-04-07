#pragma once

#include <Trade/Trade.mqh>

struct PendingOrderInfo
{
    ulong ticket;
    int placedBar;
    string strategy;
    bool isBuy;
    double sl;
    double tp;
    double lot;
    double riskDistance;
    ulong logicalTradeId;
    int strategyId;
    string comment;
};

CTrade g_limitTrade;
PendingOrderInfo g_pendingOrder = {0, 0, "", false, 0.0, 0.0, 0.0, 0.0, 0, 0, ""};

void ResetPendingOrder()
{
    g_pendingOrder.ticket = 0;
    g_pendingOrder.placedBar = 0;
    g_pendingOrder.strategy = "";
    g_pendingOrder.isBuy = false;
    g_pendingOrder.sl = 0.0;
    g_pendingOrder.tp = 0.0;
    g_pendingOrder.lot = 0.0;
    g_pendingOrder.riskDistance = 0.0;
    g_pendingOrder.logicalTradeId = 0;
    g_pendingOrder.strategyId = 0;
    g_pendingOrder.comment = "";
}

bool HasPendingOrder()
{
    if(g_pendingOrder.ticket == 0)
        return false;

    if(!OrderSelect(g_pendingOrder.ticket))
    {
        ResetPendingOrder();
        return false;
    }

    ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
    if(state == ORDER_STATE_FILLED || state == ORDER_STATE_CANCELED || state == ORDER_STATE_REJECTED || state == ORDER_STATE_EXPIRED)
    {
        ResetPendingOrder();
        return false;
    }

    return true;
}

double NormalizeEntryPrice(double entry, const bool isBuy)
{
    double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    if(isBuy)
    {
        double maxAllowed = bid - stopLevel;
        if(entry > maxAllowed)
            entry = maxAllowed;
    }
    else
    {
        double minAllowed = ask + stopLevel;
        if(entry < minAllowed)
            entry = minAllowed;
    }

    return NormalizeDouble(entry, _Digits);
}

double RecalculateSL(const bool isBuy, const double entry, const double slDistancePoints)
{
    if(isBuy)
        return NormalizeDouble(entry - slDistancePoints, _Digits);
    return NormalizeDouble(entry + slDistancePoints, _Digits);
}

bool HasAnyPendingOrders()
{
    for(int i = 0; i < OrdersTotal(); i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0)
            continue;
        if(!OrderSelect(ticket))
            continue;

        if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;

        ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
        if(state == ORDER_STATE_PLACED || state == ORDER_STATE_PARTIAL)
            return true;
    }
    return false;
}

double CalculateLimitPrice(const bool isBuy, const double closePrice, const double highPrice, const double lowPrice)
{
    double range = highPrice - lowPrice;
    if(range <= 0.0)
        return closePrice;

    if(isBuy)
        return closePrice - (0.3 * range);
    return closePrice + (0.3 * range);
}

ulong PlaceLimitOrder(const string strategy,
                      const bool isBuy,
                      const double entry,
                      const double sl,
                      const double tp,
                      const double lot,
                      const int currentBar,
                      const ulong logicalTradeId = 0,
                      const string comment = "",
                      const double riskDistance = 0.0,
                      const int strategyId = 0)
{
    g_limitTrade.SetExpertMagicNumber(InpMagicNumber);
    g_limitTrade.SetTypeFillingBySymbol(_Symbol);

    double normalizedEntry = NormalizeEntryPrice(entry, isBuy);
    if(normalizedEntry <= 0.0 || !MathIsValidNumber(normalizedEntry))
    {
        PrintFormat("[GoldEA][REJECTION] INVALID_ENTRY price=%.5f", normalizedEntry);
        return 0;
    }

    bool ok = false;
    if(isBuy)
        ok = g_limitTrade.BuyLimit(lot, normalizedEntry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
    else
        ok = g_limitTrade.SellLimit(lot, normalizedEntry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);

    if(!ok)
        return 0;

    ulong ticket = g_limitTrade.ResultOrder();
    if(ticket == 0)
        return 0;

    g_pendingOrder.ticket = ticket;
    g_pendingOrder.placedBar = currentBar;
    g_pendingOrder.strategy = strategy;
    g_pendingOrder.isBuy = isBuy;
    g_pendingOrder.sl = sl;
    g_pendingOrder.tp = tp;
    g_pendingOrder.lot = lot;
    g_pendingOrder.riskDistance = riskDistance;
    g_pendingOrder.logicalTradeId = logicalTradeId;
    g_pendingOrder.strategyId = strategyId;
    g_pendingOrder.comment = comment;
    return ticket;
}

void ManagePendingExpiry(const int currentBar)
{
    if(!HasPendingOrder())
        return;

    int barsPassed = currentBar - g_pendingOrder.placedBar;
    if(barsPassed < 2)
        return;

    if(g_limitTrade.OrderDelete(g_pendingOrder.ticket))
    {
        PrintFormat("[%s][GoldEA][ORDER] LIMIT_EXPIRED ticket=%I64u bars=%d", g_pendingOrder.strategy, g_pendingOrder.ticket, barsPassed);
        ResetPendingOrder();
    }
}

void HandleOrderFilled(const ulong orderTicket)
{
    if(g_pendingOrder.ticket != orderTicket)
        return;

    PrintFormat("[GoldEA][ORDER] LIMIT_FILLED ticket=%I64u strategy=%s", orderTicket, g_pendingOrder.strategy);
    ResetPendingOrder();
}
