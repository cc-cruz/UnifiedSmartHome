# HOW BAD DO YOU WANT THIS SHIT MAN? (v1)

## 1. Executive Summary

This ddoc outlines a strategy to achieve US $45k+ MRR within 9 months for the smart lock platform(no name yet). The core plan involves reaching 
~15,000-17,000 active "doors" (managed units) through a multi-channel approach targeting regional builders, national multifamily managers, security dealers, and short-term rental operators. Key success factors include streamlining provisioning, automating billing, providing robust support, and optimizing per-unit economics, potentially accelerated by recent changes in Apple's App Store policies regarding external payments.

## 2. Target Market & Opportunity

The primary goal is to secure recurring revenue from ~15,400 doors (mixed property manager/homeowner) to achieve US $45k MRR, based on current estimated net margins.

**Target Door Calculation:**

| Seat type                  | Est. Net margin / door* | Doors needed for US $45k MRR |
| :------------------------- | :-------------------- | :--------------------------- |
| Property-manager account   | ≈ US $3.00            | 15,000                       |
| Home-owner seat (Apple IAP)| ≈ US $2.80            | 16,500                       |
| Mixed (60% PM / 40% HO)    | ≈ US $2.92            | ≈ 15,400                     |

_*Assumes baseline pricing and splits detailed in Section 6._

## 3. Channel Strategy

A four-track parallel approach aims to reach ~20k doors within the first year:

| Track                                                   | Door Potential (12 mo) | Key Advantages                               | Early Actions (0-90 days)                                                                 |
| :------------------------------------------------------ | :--------------------- | :------------------------------------------- | :---------------------------------------------------------------------------------------- |
| **A. Regional Builders (Clone Camelot)**                | 7 – 8 k                | Same sales cycle, existing cadence           | • Package "Smart Ready" kit + P&L one-pager<br>• Work NAHB Builder Show leads<br>• Offer -10% seat cost incentive |
| **B. National Multifamily Managers (≥ 10k units)**      | 5 – 10 k               | 100% opt-in, Stripe billing (no Apple split) | • Finish Yardi & RealPage unit-sync APIs<br>• Run 60-day pilot (2-3 sites) w/ baseline KPIs |
| **C. White-label (Low-voltage/Security Dealers)**       | 2 – 3 k                | Hundreds of homes/dealer, zero builder lift  | • Produce dealer portal + co-branding guide<br>• Pay 15% recurring rev-share                 |
| **D. Short-Term Rental Operators (Airbnb "pro hosts")** | 1 – 2 k                | OpEx spend, immediate self-check-in ROI      | • Publish Airbnb iCal/API auto-keying<br>• In-app "connect Airbnb account" flow        |

## 4. Product & Operational Requirements for Scale

-   **Operator-Grade Administration:** Portfolio hierarchy, bulk seat import, SSO (OAuth 2 / SAML).
-   **Rapid Provisioning:** QR-coded device bags, on-site claiming app (< 10 min for 20 devices), Birdseye health dashboard for site superintendents.
-   **Billing Automation:** Usage-based webhooks triggering Stripe Connect payouts per partner.
-   **Scalable Support:** Outsource Tier-1 chat/phone support, retain Tier-2/3 internally.

## 5. 90-Day Execution Timeline

| Week | Milestone                                 | KPIs                                                            |
| :--- | :---------------------------------------- | :-------------------------------------------------------------- |
| 0-2  | Builder/installer partner kit frozen      | Deck + margin calculator published                              |
| 0-4  | Yardi & RealPage connectors in beta       | 1-click unit-sync < 10 s per 1,000 units                        |
| 4-6  | First regional-builder MoU signed         | ≥ 1,000 forecast doors                                          |
| 6-8  | Multifamily pilot live (2 sites, 400 units) | 85% self-check-in success, support tickets < 0.1 / door         |
| 8-12 | Dealer channel open (5 launch dealers)    | 250 doors sold, all-digital onboarding time < 1 h               |

## 6. Pricing & Unit Economics Analysis

This section explores baseline economics and potential adjustments based on pricing levers and external factors like App Store policy changes.

### 6.1. Baseline Economics (Camelot Model Reference)

-   **Property Manager (PM) Seat:** $6 list price, 50% wholesale discount.
    -   Net to Platform: $3.00
    -   Net to Partner: $3.00
-   **Homeowner (HO) Seat:** $7.99 list price via Apple IAP.
    -   Apple Fee (30%): $2.40
    -   Remaining for Split: $5.59
    -   Net to Platform (50%): $2.80
    -   Net to Partner (50%): $2.80
-   **Doors for $45k MRR (Baseline):** 15,000 (PM) or 16,500 (HO) or ~15,400 (Mixed).

### 6.2. Potential Levers to Adjust Economics

| # | Lever Description                                          | New Per-Door $ Flow* (Platform / Partner) | Δ vs. Baseline      | Doors for $45k MRR (Platform) | Notes / Considerations                                                                    |
| :- | :--------------------------------------------------------- | :---------------------------------------- | :------------------ | :---------------------------- | :---------------------------------------------------------------------------------------- |
| 1 | Cut channel discount to 40% (keep $6 PM list)              | $3.60 / $2.40                             | +20% / –20%         | 12,500                        | Must replace partner value (e.g., marketing funds, concierge provisioning).             |
| 2 | Raise PM list to $7 (keep 50% discount)                    | $3.50 / $3.50                             | +17% / +17%         | 12,900                        | Sub-market vs competitors ($8-9). Soft-launch with new builders first.                |
| 3 | Tiered PM price: $6 (1-5k doors), $5 (>5k doors)           | $3 → $2.50 / $3 → $2.50                   | –17% large accounts | ~18,000 (if all @ $5) | Rewards large REITs, lowers take on smaller wins. Use Stripe coupons.                  |
| 4 | Add "$1 Compliance Pack" add-on (70% Platform / 30% Partner) | +$0.70 / +$0.30 (on top of base)          | +23% / +10%         | ~12,800 (70% attach)  | Upsell opportunity. Gate behind feature flag for preview.                               |
| 5 | Retire $4.99 HO tier, keep only $7.99                      | $2.80 Platform / $2.80 Partner (IAP)      | +60% (vs $4.99 net) | 10,700 HO seats             | Assumes shallow price elasticity; low churn impact expected.                            |
| 6 | Bypass Apple IAP for PM-owned condos (bill via Stripe)     | $3.50 Platform / $3.50 Partner ($7 list)  | +17% (vs PM $3 net) | 12,900                        | Permitted by Apple Guideline 3.1.3-b (Jan 2025 rev). Requires SSO bridge & landing page. |

_*Rounded figures. HO assumes 30% Apple fee then 50/50 split unless otherwise noted._

### 6.3. Impact of May 2025 Court Ruling (US Only)

**Ruling Summary:** Apple cannot block external payment links or charge commissions on purchases outside the app (US storefront). The 30% "Apple Tax" is effectively removed for web checkouts.

**Revised US Homeowner Economics:**

| Seat Type      | List Price | Collection Method | Platform Net* | Partner Net* | Δ vs. Old IAP Net |
| :------------- | :--------- | :---------------- | :------------ | :----------- | :---------------- |
| HO (Old - IAP) | $7.99      | Apple IAP (30%)   | $2.80         | $2.80        | —                 |
| HO (New - Web) | $7.99      | Web + Stripe      | $3.73         | $3.73        | +$0.93 (+33%)     |

_*After Stripe's ~2.9% + $0.30, then 50/50 split._

**Revised Doors Needed for $45k MRR (Platform Share, US Mix):**

| Mix             | Avg. Platform Net / Door | Doors → $45k | Change vs. Baseline |
| :-------------- | :----------------------- | :----------- | :------------------ |
| 100% PM         | $3.00                    | 15,000       | 0                   |
| 60% PM / 40% HO | $3.29                    | 13,700       | -1,700              |
| 100% HO         | $3.73                    | 12,100       | -4,400              |

**Implication:** The ruling significantly accelerates the path to MRR targets by boosting HO margins, reducing the required door count by ~2k-4k.

### 6.4. Recommended Pricing Strategy Path

Combine Levers 2, 4, and 6 (Post-Ruling):

-   Raise PM list price to $7 (Lever 2).
-   Offer "$1 Compliance Pack" add-on (Lever 4).
-   Move US Homeowner payments to Web/Stripe (Lever 6 + Ruling).

**Projected Economics:**

| Door Mix                   | Base Net (Platform) | Add-on Net (70% attach) | Total Net (Platform) |
| :------------------------- | :------------------ | :---------------------- | :------------------- |
| PM Doors (Stripe, $7 List) | $3.50               | +$0.70                  | $4.20                |
| US HO Doors (Web, $7.99)   | $3.73               | —                       | $3.73                |

**Result:** A mix of 10k PM doors and 5k US HO doors yields **~$56k MRR** [(10k * $4.20) + (5k * $3.73)], reaching the target with the original 15k door adoption milestone but significantly improved economics.

## 7. Financial Ramp (Illustrative - Based on Baseline/Early Levers)

| Month | Cumulative Active Doors | MRR (US$ k) | Primary Driver                       |
| :---- | :---------------------- | :---------- | :----------------------------------- |
| M3    | 3,000                   | 9           | Camelot + 1 regional builder       |
| M6    | 8,000                   | 24          | 3 builders + dealer channel        |
| M9    | 14,000                  | 41          | Multifamily roll-out begins        |
| M12   | 18,000                  | 53          | Full national manager + renewals   |

*Note: This ramp can be accelerated by implementing the recommended pricing strategy (Section 6.4) and leveraging the Apple ruling impact.*

## 8. Key Risks & Mitigations

| Risk                                | Impact              | Mitigation                                                                               |
| :---------------------------------- | :------------------ | :--------------------------------------------------------------------------------------- |
| Sales cycle stalls in large REITs   | Delays 5-10k doors  | Pilot within a single region first; auto-email success metrics to VP Ops weekly.         |
| Installer channel churn             | Door attrition      | Annual certification + "co-op MDF" tied to net-retention.                                |
| Apple IAP margin pressure persists  | 30% fee impacts HO  | Steer bulk condo accounts to Stripe (HOA pays). Mitigated significantly by May '25 ruling for US. |
| Apple wins appeal stay              | 30% fee could return | Code-switch: keep IAP SKU dormant, re-enable if needed.                                  |
| Outside-U.S. users still pay 30% fee| Confusion/support   | Geofence web checkout to US store region only.                                           |
| Conversion drop from web redirect | Higher friction     | Auto-fill email/UUID on Stripe page; prominently feature Apple Pay option.             |

## 9. Immediate Next Steps ( actionable tasks )

**Pricing & Financials:**
- [ ] Spreadsheet the pricing tiers & sensitivities (parameterize list price, wholesale %, add-on attach rate).
- [ ] Export financial sensitivity worksheet; parameterize for partner name for quick P&L illustration.

**Product Development:**
- [ ] Gate the "Compliance Pack" add-on behind a feature flag. Plan beta with Camelot pilot.
- [ ] Implement web checkout flow (webview -> Stripe page) for US Homeowner accounts.
- [ ] Keep Apple IAP SKU dormant but available for non-US or potential rollback.
- [ ] Finish Yardi & RealPage unit-sync APIs.

**Business Development & Legal:**
- [ ] Draft reseller agreement amendment re: external payments & add-on pricing.
- [ ] Finalize and publish Builder/Installer partner kit (Deck, P&L calculator).
- [ ] Block time for founder-to-founder intros at local HBA.
- [ ] Prepare messaging for existing partners re: increased share from web payments.

**App Store:**
- [ ] Submit app update replacing "in-app purchase" copy with "secure online checkout" for US users. 