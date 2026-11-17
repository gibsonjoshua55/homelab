# 2027 Angle Health plans: machine-readable benefits

Transcribed from the four PDFs in this folder (Schedule of Benefits + Summary of Benefits and Coverage for each plan). Coverage period: 01/01/2027 – 12/31/2027. Plan type: PPO, Individual/Family.

| File | What it holds |
| --- | --- |
| [plans.csv](plans.csv) | Deductible and out-of-pocket max per plan × network |
| [benefits.csv](benefits.csv) | Cost-sharing per plan × service × network (402 rows) |
| This file | Rules that apply across services, exclusions, the SBC coverage examples, and discrepancies between the PDFs |

## Plans

| plan_id | Name | SBC plan code |
| --- | --- | --- |
| `base_4000` | Base Plan – Angle Nomi Traditional 4000 | ANG NOMI TRAD 4000 6000 |
| `opt_up_1000` | Opt Up Plan – Angle Nomi Traditional 1000 | ANG NOMI TRAD 1000 2000 |

Premiums are not in these documents; they're "provided separately".

## Networks

| network | Schedule of Benefits name | SBC name | Notes |
| --- | --- | --- | --- |
| `tier1` | Tier 1 In-Network | Preferred Network Provider | $0 deductible; most services no charge |
| `tier2` | Tier 2 In-Network | In-Network Provider | Copays, or 20% coinsurance after deductible |
| `oon` | Out-of-Network | Out-of-Network Provider | Mostly 50% coinsurance after deductible; balance billing possible |

## Plan comparison

Everything not listed here is identical between the two plans.

| Item | Base (`base_4000`) | Opt Up (`opt_up_1000`) |
| --- | --- | --- |
| Tier 2 deductible (ind / fam) | $4,000 / $8,000 | $1,000 / $2,000 |
| OON deductible (ind / fam) | $8,000 / $16,000 | $5,000 / $10,000 |
| Tier 1 & Tier 2 OOP max (ind / fam) | $6,000 / $12,000 | $2,000 / $4,000 |
| OON OOP max (ind / fam) | $12,000 / $24,000 | $10,000 / $20,000 |
| Tier 2 copay: primary care, virtual primary care, lab, mental health office/virtual | $25 | $10 |
| Tier 2 copay: specialist, virtual specialist, rehab, habilitation, acupuncture, chiropractic | $75 | $30 |
| Urgent care copay (Tier 1 and Tier 2) | $85 | $50 |
| Rx retail 31-day: generic / preferred / non-preferred | $20 / $60 / $85 | $10 / $30 / $60 |
| Rx mail 90-day: generic / preferred / non-preferred | $50 / $150 / $212.50 | $25 / $75 / $150 |

Same in both: $500 ER facility copay (all networks), 20% Tier 2 coinsurance, 50% OON coinsurance, 20% specialty Rx after deductible.

## Reading benefits.csv

| Column | Values |
| --- | --- |
| `cost_share` | `no_charge`, `copay`, `coinsurance`, `not_covered`, `varies` (depends on place of service) |
| `copay_usd` | Flat amount per visit/fill when `cost_share = copay` |
| `coinsurance_pct` | Member's share of the allowed amount when `cost_share = coinsurance` |
| `deductible_applies` | `true` if the deductible must be met before the coinsurance applies. Empty for not-covered/varies |
| `limit_per_year`, `limit_unit`, `limit_scope` | Plan-year caps, e.g. 20 visits, 60 days. Limits are per plan year |
| `precert` | `required`, `certain_services`, `required_except_emergency`, or empty |

Prescription drug rows: the PDFs show one in-network column for pharmacy, so `tier1` and `tier2` rows are identical. Drug tiers (generic, preferred brand, non-preferred brand, specialty) are in the `service` name and are unrelated to network tiers.

## Cost-sharing rules

These come from the Schedule of Benefits preamble and the SBC, and apply to every service.

1. **Allowed amount basis.** Deductible, copay and coinsurance are all computed on the plan's allowed amount, not the provider's billed charge.
2. **Deductible first, then coinsurance.** For services marked `deductible_applies = true`, the member pays 100% of the allowed amount until the deductible is met, then the coinsurance percentage.
3. **Copays are separate from the deductible.** Copays do not reduce the deductible, and deductibles do not reduce copays. Copays and deductibles are in addition to coinsurance.
4. **Embedded deductible.** Each family member only has to meet their own individual deductible. Once the family deductible is met in total, everyone moves to coinsurance even if their individual deductible isn't met.
5. **Embedded out-of-pocket max.** Same structure: each person stops paying at the individual OOP max, and everyone stops paying once the family OOP max is met. After that, covered services are paid at 100% of the allowed amount.
6. **OOP max includes medical and prescription.** Deductibles, copays and coinsurance for both count toward it.
7. **Not counted toward the OOP max:** premiums, non-compliance penalties, balance-billing (charges above the allowed amount), and non-covered services.
8. **No cross-accumulation between in-network and out-of-network.** In-network spend accumulates only to the in-network deductible/OOP; OON only to OON. Same for service-specific visit/day limits. Tier 1 and Tier 2 are both "in-network" and have the same OOP max, so they likely share one accumulator, but the documents don't say so explicitly.
9. **Preauthorization penalty.** If a required preauthorization isn't obtained, benefits "could be reduced by 50% of the total cost of the service" (SBC).
10. **Out-of-network balance billing.** OON providers may bill the difference between their charge and the allowed amount, except for emergency services, air ambulance, or OON providers working at an in-network facility (unless you consented in writing).
11. **No referral needed** to see a specialist.
12. **Preventive care** is covered before the deductible at no charge in-network; it is not covered out-of-network.

## Excluded services (SBC)

Cosmetic surgery, infertility treatment, private-duty nursing, weight loss programs, adult dental care, long-term care, adult routine eye care, hearing aids, non-emergency care when traveling outside the U.S., routine foot care. Children's eye exams, glasses and dental check-ups are also not covered.

Other covered services listed by the SBC: acupuncture, bariatric surgery, chiropractic care. Bariatric surgery is not a line item in the Schedule of Benefits.

## SBC coverage examples

Self-only coverage, Tier 2 in-network providers. These are the insurer's own worked examples and could serve as test cases for the forecast, although the PDFs don't break down the allowed amount per service.

| Example | Total cost | Plan | Deductibles | Copays | Coinsurance | Not covered | **Member pays** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Peg is having a baby (9 months prenatal + hospital delivery) | $12,700 | Base | $4,000 | $517 | $1,483 | $60 | **$6,060** |
| | | Opt Up | $1,000 | $170 | $830 | $60 | **$2,060** |
| Managing Joe's type 2 diabetes (a year of routine care) | $5,600 | Base | $864 | $1,380 | $0 | $20 | **$2,264** |
| | | Opt Up | $864 | $640 | $0 | $20 | **$1,524** |
| Mia's simple fracture (ER visit + follow-up) | $2,800 | Base | $1,614 | $745 | $0 | $0 | **$2,359** |
| | | Opt Up | $1,000 | $600 | $123 | $0 | **$1,723** |

Services included:
- **Peg:** specialist office visits (prenatal), childbirth/delivery professional and facility services, diagnostic tests (ultrasounds, blood work), specialist visit (anesthesia).
- **Joe:** primary care visits (including disease education), diagnostic tests (blood work), prescription drugs, durable medical equipment (glucose meter).
- **Mia:** emergency room care (including supplies), diagnostic test (x-ray), durable medical equipment (crutches), rehabilitation (physical therapy).

## Discrepancies between the PDFs

| Item | Schedule of Benefits | SBC | Used in CSV |
| --- | --- | --- | --- |
| Home health care limit | 100 visits per plan year | 100 days per plan year | 100 visits |
| Home health care preauth | Required | Required for certain services | `required` |
| Pregnancy office visits | Prenatal & postnatal care: 20% after deductible (Tier 2) | Same, but notes cost-sharing doesn't apply to certain preventive prenatal services | 20% after deductible, noted |
| Virtual Doctor on Demand | Footnote: "must be $0 after deductible for qualified HDHPs" | Not mentioned | `no_charge` (neither plan is an HDHP) |
