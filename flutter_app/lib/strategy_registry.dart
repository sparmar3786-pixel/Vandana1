import 'package:flutter/material.dart';

class StrategyRegistry {
  static const Map<String, List<String>> categories = {
    'OI / Position': ['Long Buildup','Short Buildup','Short Covering','Long Unwinding','Fresh OI Addition','OI Flush','OI Shift','OI Migration','OI Concentration','OI Concentration Shift','OI Concentration Break','OI Cluster Migration','Maximum OI Strike','Maximum Change-in-OI Strike','OI Wall Break','OI Wall Rebuild','OI Wall Removal','OI Accumulation','OI Distribution','OI Velocity','OI Acceleration','OI Normalization','OI Divergence','CE/PE OI Imbalance','CE/PE OI Spread','Cross-Strike OI Rotation','ATM OI Battle','ATM OI Migration'],
    'Premium / Price': ['Premium Momentum','Premium Velocity','Premium Acceleration','Premium Explosion','Premium Collapse','Premium Reversal','Premium/OI Divergence','Price/OI Divergence','Price/Volume Divergence','Price Acceptance','Price Rejection','Rapid LTP Repricing','Price Stalling','Intrinsic/Extrinsic Value','Time-Value Compression','Moneyness Tracking'],
    'Volume': ['Volume Confirmation','Volume Spike','Volume Explosion','Volume/OI Ratio','Volume Acceleration','Volume Normalization','Volume Divergence','Volume + Price Confirmation','Volume + OI Confirmation','Multi-Strike Volume Expansion'],
    'CE/PE': ['CE Independent Engine','PE Independent Engine','CE/PE Pressure Index','CE/PE Premium Spread','CE/PE Volume Spread','CE/PE Chain Imbalance','Call-Writing Zone','Put-Writing Zone','Call-Unwinding Zone','Put-Unwinding Zone','CE Resistance Ladder','PE Support Ladder','CE→PE Rotation','PE→CE Rotation','Call Buyer Trap','Put Buyer Trap','Call Writer Trap','Put Writer Trap'],
    'Short-Covering / Seller': ['Seller Pressure Detection','Probable Short-Covering Zone','Premium ↑ + OI ↓','Short-Covering + Volume','Multi-Strike Short Covering','Broad Short-Covering Wave','Short-Covering Confirmation','Short-Covering Failure','Short-Covering Exhaustion','Seller Absorption','Buyer Absorption','Seller Defence Zone','Seller Defence Failure','Position Exit Detection','Position Re-entry Detection','Position Flip Detection','Position Rotation','Position Exhaustion'],
    'Strike / Option Chain': ['ATM Strategy','ITM Strategy','OTM Strategy','ATM ±3 Strike Map','ATM ±5 Strike Map','Nearest OI Cluster','Nearest Volume Cluster','Highest Change-OI Cluster','Strike Pressure Gradient','Strike Momentum Ranking','Strike Liquidity Ranking','Strike Migration','Strike Flip','Strike Rejection','Strike Acceptance','Repeated Strike Defence','Strike Defence Failure','OI Wall Strategy','Option Chain Pressure Score','Chain-Wide Momentum Burst'],
    'Support / Resistance': ['OI Support','OI Resistance','Dynamic Support/Resistance','Support Breakdown','Resistance Breakout','Previous Day High','Previous Day Low','Day High Breakout','Day Low Breakdown','Previous Close Reaction','Weekly Level Reaction','OI Support/Resistance Rotation'],
    'Trend / Price Action': ['EMA 8/13 Crossover','EMA 20/50 Trend','VWAP Reclaim','VWAP Breakdown','VWAP Reversal','Opening Range Breakout','Range Breakout','Range Breakdown','Range Rejection','Trend Continuation','Trend Reversal','Momentum Expansion','Momentum Exhaustion','Pullback Entry','Breakout + Retest','Breakdown + Retest','Failed Breakout','Failed Breakdown','Higher High + Higher Low','Lower High + Lower Low','Break of Structure','Market Structure Break','Change of Character','Structure Retest','Range Expansion','Range Contraction','Compression → Expansion'],
    'RSI / MACD / Volatility': ['RSI Momentum','RSI Overbought','RSI Oversold','RSI Divergence','MACD Momentum','MACD Crossover','MACD Divergence','EMA + RSI','EMA + MACD','RSI + MACD + OI','ATR Expansion','ATR Contraction','Bollinger Squeeze','Bollinger Expansion','Bollinger Breakout','Volatility Compression','Volatility Expansion','Volatility Normalization'],
    'Greeks / IV': ['Delta Momentum','Delta-based Strike Selection','Gamma Expansion','Gamma Risk Zone','Gamma-Sensitive Strike Detection','Theta Decay','Theta Acceleration','Theta vs Momentum','Vega Expansion','IV Expansion','IV Crush','IV Confirmation','IV Skew','Call/Put IV Difference','IV Surface Shift','Realized vs Implied Volatility','IV + OI Confirmation'],
    'Expiry': ['Expiry-Day Premium Decay','Expiry ATM Compression','Expiry Strike Pinning','Expiry Breakout','Expiry Breakdown','Expiry Short Covering','Expiry Long Unwinding','Expiry Gamma Expansion','Expiry Compression','Expiry Expansion','Days-to-Expiry Adjustment','Expiry Distance Adjustment','Weekly/Monthly Expiry Behaviour','Expiry Transition','Post-Expiry Reset','Expiry OI Migration','Last-Hour Momentum','Last-Hour Reversal'],
    'Liquidity / Microstructure': ['Liquidity Expansion','Liquidity Exhaustion','Liquidity Sweep','Liquidity Grab + Reversal','Liquidity Grab + Continuation','Liquidity Void','Liquidity Refill','Liquidity Concentration','Bid-Ask Spread Expansion','Bid-Ask Spread Compression','LTP vs Mid-Price Divergence','Tick Momentum','Tick Reversal','Consecutive Up/Down Moves','Absorption Detection','Aggressive Buying','Aggressive Selling'],
    'Trap / Reversal': ['Bull Trap','Bear Trap','Buyer Trap','Seller Trap','False OI Signal','False Volume Signal','False Breakout Reversal','False Breakdown Reversal','Exhaustion → Reversal','Extreme OI → Reversal','Extreme Premium → Reversal','Momentum Reversal','Multi-Strike Reversal','Opposite-Side Reversal','Opposite-Side Override'],
    'Market Regime': ['Strong Bull Regime','Strong Bear Regime','Sideways/Range Regime','High-Volatility Regime','Low-Volatility Regime','Breakout Regime','Mean-Reversion Regime','Expiry Compression Regime','Expansion Regime','Regime Switching','Adaptive Momentum','Adaptive Mean Reversion'],
    'Quant / Statistical': ['Z-Score Extreme','Rolling Z-Score','Mean Reversion','Momentum Factor','Relative Strength','Rolling Correlation','Beta Relationship','Volatility-Adjusted Momentum','Return Distribution','Statistical Outlier Detection','Anomaly Detection','Percentile Extreme Detection','Momentum Normalization','Volatility Normalization'],
    'Cross-Index / Market Breadth': ['NIFTY vs BANKNIFTY Divergence','BANKNIFTY vs FINNIFTY Divergence','NIFTY vs SENSEX Divergence','Index Relative Strength','Index Relative Momentum','Index Relative Volatility','Index Leadership Detection','Breadth Confirmation','Breadth vs Index Divergence','Sector Strength Confirmation','Sector Rotation','Market Leadership Shift','Risk-On/Risk-Off Detection','Index Divergence'],
    'Fibonacci / Classical Levels': ['Fibonacci Retracement','Fibonacci Extension','Swing Retracement','Pivot Points','CPR','CPR Breakout','CPR Rejection','Opening Range + Pivot','Previous Close Level','Weekly Reference Level'],
    'Entry / Exit / Risk': ['Early Entry','Confirmation Entry','Retest Entry','Late Entry Filter','Chasing Filter','Dynamic Stop Loss','Structure Stop Loss','Premium Stop Loss','ATR Stop Loss','Trailing Stop','Break-Even Shift','Partial Target','Target Extension','Risk/Reward Gate','Maximum-Loss Filter','Gap-Risk Filter','Wide-Spread Filter','Low-Liquidity Filter','Time Exit','OI-Wall Target','R:R Target'],
    'Signal Intelligence': ['Strategy Conflict Engine','Multi-Confirmation Engine','Weak-Signal Suppression','Late-Signal Suppression','Signal Expiry Timer','Signal Cooldown','Duplicate-Signal Filter','Contradiction Detector','Repeated-Failure Suppression','Opposite-Side Strong-Signal Block','No-Trade Intelligence','Data-Quality Signal Gate'],
    'Data / Reliability': ['Timestamp Chronology','Data Freshness','Timestamp Synchronization','Missing Tick Detection','Abnormal Tick Detection','Data Gap Detection','Duplicate Tick Detection','API Latency Monitor','Feed Recovery Detection','Market-Status Validation','Exchange-Mismatch Protection','Invalid Strike Protection','Missing OI Protection','Missing Volume Protection','Stale Quote Block'],
    'Backtest / Validation': ['Strategy-wise Backtest','Index-wise Backtest','CE-vs-PE Backtest','Expiry-vs-Non-expiry Backtest','Time-window Backtest','Strike-distance Backtest','Market-regime Backtest','Walk-Forward Testing','Out-of-Sample Testing','Monte-Carlo Trade Sequence Analysis','Parameter Sensitivity','Strategy Robustness Test','Slippage Sensitivity','Transaction-Cost Sensitivity','Forward Paper Validation','Live-vs-Backtest Drift Detection','Maximum Drawdown','Average R','Expectancy','Profit Factor','Consecutive Wins/Losses','Time-of-Day Performance'],
    'AI / Strategy Discovery': ['Multi-Model Agreement','Multi-Model Disagreement','AI Data-Quality Check','AI Stale-Data Detection','AI Contradiction Detection','AI Evidence Trace','AI Hallucination Guard','AI Final WAIT Override','Pattern Discovery','Candidate Strategy Discovery','Strategy Behaviour Memory','Strategy Failure-Pattern Analysis','Market-Regime Behaviour Memory'],
    'Final Decision Engine': ['CALL Qualification','PUT Qualification','CALL vs PUT Conflict','Opposite-Side Override','Liquidity Gate','Risk/R:R Gate','Data-Quality Gate','Confidence/Confirmation Gate','Final WAIT','NO QUALIFYING TRADE'],
  };

  static const Map<String, List<String>> advanced = {
    'Volatility Surface': ['IV Surface Slope','IV Surface Curvature','IV Smile/Skew Change','ATM IV vs OTM IV Divergence','Term-Structure Slope','Term-Structure Inversion','Moneyness-IV Interaction'],
    'Order Flow / Vega': ['Vega-Weighted Net Demand','Vega Flow Acceleration','Vega Flow Reversal','Delta-vs-Vega Flow Separation','Directional-Flow vs Volatility-Flow Separation','Delta-Informed Flow','Vega-Informed Flow','Directional Information Score','Volatility Information Score','Combined Information Imbalance'],
    'Cross-Option Flow': ['Same-Expiry Cross-Strike Flow','Same-Strike CE/PE Flow','Cross-Maturity Flow','Delta-Bucket Flow','Vega-Bucket Flow','Aggregate Option-Flow Pressure'],
    'Trade Classification': ['Buyer-Initiated vs Seller-Initiated Classification','Aggressor-Side Volume','Trade-Size Buckets','Large-Lot Flow','Small-Lot Flow','Trade-Flow Imbalance','Flow Persistence','Flow Reversal'],
    'Multi-Leg Recognition': ['Long Call','Long Put','Covered Call','Covered Put','Bull Call Spread','Bear Call Spread','Bull Put Spread','Bear Put Spread','Long Straddle','Short Straddle','Long Strangle','Short Strangle','Butterfly','Iron Butterfly','Condor','Iron Condor','Ratio Spread','Collar','Strip','Strap','Calendar Spread','Diagonal Spread','Box/Jelly Roll'],
    'Advanced Microstructure': ['Equal High Sweep','Equal Low Sweep','Potential Liquidity Event','Historical Volatility Expansion','IV Rank Context','IV Percentile Context','Premium Mispricing Detection','Broad-Market Confirmation','Strategy Debounce','Signal Confirmation Window','Stale-Signal Auto Expiry','Sudden-Reversal Protection','Extreme-Volatility Block','Low-Confidence Suppression','Duplicate-Entry Suppression','Risk Escalation Filter','Event/Expiry Risk Filter'],
    'Strategy Discovery Pipeline': ['Historical Pattern Discovery','Candidate Strategy Generation','Backtest Gate','Out-of-Sample Gate','Robustness Gate','Paper Validation Gate','Live-vs-Backtest Drift Gate','Strategy Registry Memory'],
  };

  static int get coreCount => categories.values.fold<int>(0, (n, x) => n + x.length);
  static int get advancedCount => advanced.values.fold<int>(0, (n, x) => n + x.length);
  static int get totalCount => coreCount + advancedCount;

  static Widget page(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
    children: [
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        const Icon(Icons.account_tree, size: 30), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('FULL STRATEGY ENGINE', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          Text(coreCount.toString() + ' core + ' + advancedCount.toString() + ' advanced = ' + totalCount.toString() + ' registered modules', style: const TextStyle(fontSize: 12)),
        ])),
      ]))),
      const SizedBox(height: 8),
      ...categories.entries.map((e) => _section(e.key, e.value, false)),
      const SizedBox(height: 8),
      const Text('ADVANCED RESEARCH MODULES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ...advanced.entries.map((e) => _section(e.key, e.value, true)),
    ],
  );

  static Widget _section(String title, List<String> items, bool advancedSection) => Card(
    child: ExpansionTile(
      leading: Icon(advancedSection ? Icons.science : Icons.analytics),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(items.length.toString() + ' modules'),
      children: [
        for (int i = 0; i < items.length; i++)
          ListTile(dense: true, leading: CircleAvatar(radius: 13, child: Text((i + 1).toString(), style: const TextStyle(fontSize: 10))), title: Text(items[i]), trailing: const Icon(Icons.chevron_right, size: 18)),
      ],
    ),
  );
}
