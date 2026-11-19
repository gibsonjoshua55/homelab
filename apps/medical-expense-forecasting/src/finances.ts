import { calculateYear, type Breakdown, type Expense } from './calculate.js';
import type { Plan } from './plans.js';

export interface TaxRates {
  /** Marginal federal income tax bracket. */
  federal: number;
  /** Marginal state income tax rate. */
  state: number;
  /**
   * Social Security (6.2%) + Medicare (1.45%). Pre-tax payroll deductions skip these too,
   * except Social Security stops applying above its yearly wage base per earner.
   */
  fica: number;
  /** Whether premiums come out of the paycheck before tax (a Section 125 plan). */
  premiumsPreTax: boolean;
}

/** A cost the health plan doesn't cover at all, the same under every plan. */
export interface UncoveredExpense {
  person: string;
  description: string;
  amount: number;
  timesPerYear: number;
  /** Whether the FSA can pay for it (prescribed drugs can, even when insurance won't). */
  fsaEligible: boolean;
}

export interface FinanceInputs {
  premium: number;
  fsaContribution: number;
  tax: TaxRates;
  uncovered: UncoveredExpense[];
}

export interface AnnualCost {
  premium: number;
  /** What the plan leaves you to pay for covered care: copays, deductible, coinsurance. */
  covered: Breakdown;
  coveredByPerson: Map<string, Breakdown>;
  uncovered: { expense: UncoveredExpense; total: number }[];
  /** Every dollar spent on health care this year, before any tax savings. */
  totalSpending: number;
  fsaEligible: number;
  fsaContribution: number;
  fsaUsed: number;
  /** FSA money not spent by year end, which is lost. */
  fsaForfeited: number;
  /** Health spending paid with take-home (already taxed) money. */
  paidPostTax: number;
  taxSavedOnPremium: number;
  taxSavedByFsa: number;
  /** What the year actually costs: spending + lost FSA money - tax saved. */
  netCost: number;
}

export const marginalRate = (tax: TaxRates) => tax.federal + tax.state + tax.fica;

const sum = (values: number[]) => values.reduce((a, b) => a + b, 0);

export function annualCost(plan: Plan, claims: Expense[], inputs: FinanceInputs): AnnualCost {
  const { premium, fsaContribution, tax } = inputs;
  const { byPerson, total: covered } = calculateYear(plan, claims);
  const uncovered = inputs.uncovered.map((expense) => ({ expense, total: expense.amount * expense.timesPerYear }));

  const totalSpending = premium + covered.total + sum(uncovered.map((u) => u.total));
  // Everything the plan leaves you to pay for covered care is a medical expense the FSA can pay.
  const fsaEligible = covered.total + sum(uncovered.filter((u) => u.expense.fsaEligible).map((u) => u.total));
  const fsaUsed = Math.min(fsaContribution, fsaEligible);
  const fsaForfeited = fsaContribution - fsaUsed;

  // Premiums come from payroll, so the rest is paid either from the FSA or with take-home pay.
  const paidPostTax = totalSpending - premium - fsaUsed;

  const rate = marginalRate(tax);
  const taxSavedOnPremium = tax.premiumsPreTax ? premium * rate : 0;
  const taxSavedByFsa = fsaContribution * rate;

  return {
    premium,
    covered,
    coveredByPerson: byPerson,
    uncovered,
    totalSpending,
    fsaEligible,
    fsaContribution,
    fsaUsed,
    fsaForfeited,
    paidPostTax,
    taxSavedOnPremium,
    taxSavedByFsa,
    netCost: totalSpending + fsaForfeited - taxSavedOnPremium - taxSavedByFsa,
  };
}
