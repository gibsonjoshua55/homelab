import type { Network, Plan } from './plans.js';

/** One claim: a single visit, fill or service on a given day. */
export interface Expense {
  person: string;
  serviceId: string;
  network: Network;
  /**
   * The plan's allowed amount (negotiated price), not the provider's billed charge. Only
   * needed when the benefit is coinsurance or not covered; copays don't depend on it.
   */
  allowedAmount?: number;
  date: Date;
}

/** Something that happens on a regular schedule, expanded into individual expenses. */
export interface RecurringExpense {
  person: string;
  serviceId: string;
  network: Network;
  /** See Expense.allowedAmount. */
  allowedAmount?: number;
  timesPerYear: number;
}

export interface Breakdown {
  deductible: number;
  copays: number;
  coinsurance: number;
  notCovered: number;
  total: number;
}

export interface YearResult {
  byPerson: Map<string, Breakdown>;
  total: Breakdown;
}

const emptyBreakdown = (): Breakdown => ({ deductible: 0, copays: 0, coinsurance: 0, notCovered: 0, total: 0 });

/** Spreads each recurring expense evenly across the year. */
export function expandRecurring(recurring: RecurringExpense[], year: number): Expense[] {
  const start = Date.UTC(year, 0, 1);
  const yearMs = Date.UTC(year + 1, 0, 1) - start;
  return recurring.flatMap(({ timesPerYear, ...rest }) =>
    Array.from({ length: timesPerYear }, (_, i) => ({
      ...rest,
      date: new Date(start + Math.floor((i * yearMs) / timesPerYear)),
    })),
  );
}

// Tier 1 and Tier 2 are both in-network and share one out-of-pocket max; out-of-network
// accumulates separately (Schedule of Benefits: "do not cross-accumulate"). Deductibles are
// tracked per network: Tier 1's is $0, so only Tier 2 and out-of-network ever accumulate.
const oopGroup = (network: Network) => (network === 'oon' ? 'oon' : 'in');

class Accumulator {
  private byPerson = new Map<string, number>();
  private family = 0;

  constructor(private readonly limits: { individual: number; family: number }) {}

  /** How much more this person can put toward the limit (embedded individual + family). */
  remaining(person: string): number {
    const individual = this.limits.individual - (this.byPerson.get(person) ?? 0);
    const family = this.limits.family - this.family;
    return Math.max(0, Math.min(individual, family));
  }

  add(person: string, amount: number) {
    this.byPerson.set(person, (this.byPerson.get(person) ?? 0) + amount);
    this.family += amount;
  }
}

/** Calculates what the household pays out of pocket for a year of expenses on one plan. */
export function calculateYear(plan: Plan, expenses: Expense[]): YearResult {
  const deductibles = new Map<Network, Accumulator>();
  const oops = new Map<string, Accumulator>();
  const visits = new Map<string, number>();
  const byPerson = new Map<string, Breakdown>();
  const total = emptyBreakdown();

  const deductibleFor = (n: Network) => {
    if (!deductibles.has(n)) deductibles.set(n, new Accumulator(plan.deductible[n]));
    return deductibles.get(n)!;
  };
  const oopFor = (n: Network) => {
    const group = oopGroup(n);
    if (!oops.has(group)) oops.set(group, new Accumulator(plan.oopMax[n]));
    return oops.get(group)!;
  };

  const sorted = [...expenses].sort((a, b) => a.date.getTime() - b.date.getTime());

  for (const e of sorted) {
    const benefit = plan.benefits.get(e.serviceId)?.[e.network];
    if (!benefit) throw new Error(`${plan.id} has no benefit for service "${e.serviceId}" (${e.network})`);

    const paid = emptyBreakdown();
    const visitKey = `${e.person}|${e.serviceId}|${oopGroup(e.network)}`;
    const visitCount = (visits.get(visitKey) ?? 0) + 1;
    visits.set(visitKey, visitCount);
    const overLimit = benefit.limitPerYear !== undefined && visitCount > benefit.limitPerYear;
    const allowed = (why: string) => {
      if (e.allowedAmount === undefined) {
        throw new Error(`${plan.id}: "${e.serviceId}" (${e.network}) ${why}, so it needs an allowedAmount`);
      }
      return e.allowedAmount;
    };

    if (overLimit || benefit.costShare === 'not_covered') {
      // Not covered: the member pays it all and it doesn't count toward any limit.
      paid.notCovered = allowed(overLimit ? 'is over its yearly limit' : 'is not covered');
    } else if (benefit.costShare === 'varies') {
      throw new Error(`"${e.serviceId}" depends on place of service; use a more specific service`);
    } else if (benefit.costShare !== 'no_charge') {
      const oop = oopFor(e.network);
      let oopLeft = oop.remaining(e.person);

      if (benefit.costShare === 'copay') {
        paid.copays = Math.min(benefit.copay, e.allowedAmount ?? Infinity, oopLeft);
      } else {
        let rest = allowed('is charged as coinsurance');
        if (benefit.deductibleApplies) {
          const ded = deductibleFor(e.network);
          const towardDeductible = Math.min(rest, ded.remaining(e.person));
          ded.add(e.person, towardDeductible);
          paid.deductible = Math.min(towardDeductible, oopLeft);
          oopLeft -= paid.deductible;
          rest -= towardDeductible;
        }
        paid.coinsurance = Math.min((rest * benefit.coinsurancePct) / 100, oopLeft);
      }

      oop.add(e.person, paid.deductible + paid.copays + paid.coinsurance);
    }

    paid.total = paid.deductible + paid.copays + paid.coinsurance + paid.notCovered;
    const person = byPerson.get(e.person) ?? emptyBreakdown();
    for (const key of Object.keys(paid) as (keyof Breakdown)[]) {
      person[key] += paid[key];
      total[key] += paid[key];
    }
    byPerson.set(e.person, person);
  }

  return { byPerson, total };
}
