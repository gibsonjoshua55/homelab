import type { RecurringExpense } from './calculate.js';
import type { TaxRates, UncoveredExpense } from './finances.js';

// Edit this file to describe the year you expect.

export const YEAR = 2027;

/** Paid twice a month. */
const PAYCHECKS_PER_YEAR = 24;

/** Yearly premium per plan, keyed by plan_id from plans.csv. */
export const annualPremiums: Record<string, number> = {
  base_4000: 270.29 * PAYCHECKS_PER_YEAR,
  opt_up_1000: 383.56 * PAYCHECKS_PER_YEAR,
};

/** Yearly FSA contribution per plan. $3,500 is the max; unspent money is lost at year end. */
export const fsaContributions: Record<string, number> = {
  base_4000: 3500,
  opt_up_1000: 3500,
};

/** Marginal tax rates: what a pre-tax dollar of premium or FSA contribution avoids. */
export const tax: TaxRates = {
  federal: 0.22,
  state: 0.045,
  fica: 0.0765,
  premiumsPreTax: true,
};

// Allowed amounts (the plan's negotiated price) per visit. They only change the result for
// services charged as coinsurance; copay services cost the copay regardless.
const THERAPY_SESSION = 150;
const PT_SESSION = 150;

export const expenses: RecurringExpense[] = [
  // Mental health therapy every 2 weeks each, less a few missed sessions.
  {
    person: 'me',
    serviceId: 'mh_office_visit',
    network: 'tier2',
    allowedAmount: THERAPY_SESSION,
    timesPerYear: 22,
  },
  {
    person: 'wife',
    serviceId: 'mh_office_visit',
    network: 'tier2',
    allowedAmount: THERAPY_SESSION,
    timesPerYear: 22,
  },
  // Physical therapy, up to the plan's 20-visit yearly limit.
  {
    person: 'wife',
    serviceId: 'outpatient_rehab',
    network: 'tier2',
    allowedAmount: PT_SESSION,
    timesPerYear: 20,
  },
  // Continuous glucose monitors: a 90-day mail-order fill, four times a year. Billed as a
  // preferred brand drug (drug tier 2): $150 on Base, $75 on Opt Up.
  {
    person: 'wife',
    serviceId: 'rx_mail_preferred_brand',
    network: 'tier2',
    timesPerYear: 4,
  },
  // Other prescriptions: $10-15/month. Modeled as monthly generic fills priced at the
  // midpoint; when the drug costs less than the copay you pay the drug's price instead.
  {
    person: 'wife',
    serviceId: 'rx_retail_generic',
    network: 'tier2',
    allowedAmount: 12.5,
    timesPerYear: 12,
  },
];

/** Costs the plan doesn't cover at all. These are the same under every plan. */
export const uncoveredExpenses: UncoveredExpense[] = [
  {
    person: 'wife',
    description: 'Non-covered prescription',
    amount: 200,
    timesPerYear: 12,
    fsaEligible: true,
  },
];
