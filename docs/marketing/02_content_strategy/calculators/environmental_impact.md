# Environmental Impact Calculator

## Calculator Interface
```javascript
// Input Fields
{
  propertyUnits: number,          // Number of units in property
  annualTurnoverRate: percentage, // Default: 20%
  currentLockSystem: select       // Traditional | Smart | Mixed
}

// Calculation Formulas
const calculations = {
  // Metal Waste
  annualTurnovers: propertyUnits * (annualTurnoverRate / 100),
  metalWastePounds: annualTurnovers * 1.5, // Average 1.5 lbs per lock
  
  // Carbon Footprint
  locksmithVisits: annualTurnovers * 2,    // Average 2 visits per turnover
  carbonEmissions: locksmithVisits * 8.887, // 8.887 kg CO2 per service visit
  
  // Cost Savings
  locksmithCosts: locksmithVisits * 150,    // Average $150 per visit
  hardwareCosts: annualTurnovers * 100      // Average $100 per new lock
}
```

## Results Display
```
[Interactive Dashboard]

1. Annual Environmental Impact
   • Metal Waste: {metalWastePounds} lbs
   • CO2 Emissions: {carbonEmissions} kg
   • Trees Needed: {carbonEmissions / 48} trees*

2. 5-Year Environmental Impact
   • Metal Waste: {metalWastePounds * 5} lbs
   • CO2 Emissions: {carbonEmissions * 5} kg
   • Trees Needed: {(carbonEmissions * 5) / 48} trees*

3. Cost Analysis
   • Annual Savings: ${locksmithCosts + hardwareCosts}
   • 5-Year Savings: ${(locksmithCosts + hardwareCosts) * 5}

* Based on average tree CO2 absorption of 48kg per year
```

## Visual Elements
```
[Real-time Visualizations]
• Metal waste comparison (traditional vs smart)
• Carbon footprint visualization
• Cost savings graph
• Environmental impact equivalencies

[Shareable Results]
• PDF report generation
• Social media sharing buttons
• Email report option
``` 