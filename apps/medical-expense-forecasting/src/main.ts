import { calculateYear, expandRecurring, type YearResult } from './calculate.js';
import { annualPremiums, expenses, YEAR } from './household.js';
import { loadPlans, type Plan } from './plans.js';

const usd = (n: number) => `$${Math.round(n).toLocaleString('en-US')}`;

const plans = loadPlans();
const claims = expandRecurring(expenses, YEAR);
const people = [...new Set(expenses.map((e) => e.person))];

console.log(`Medical expense forecast for ${YEAR}\n`);
console.log('Expenses:');
for (const e of expenses) {
  const price = e.allowedAmount === undefined ? '' : `, $${e.allowedAmount.toFixed(2)} allowed each`;
  console.log(`  ${e.person}: ${e.timesPerYear}x ${e.serviceId} (${e.network}${price})`);
}
console.log();

const results: { plan: Plan; result: YearResult; premium: number | undefined }[] = plans.map((plan) => ({
  plan,
  result: calculateYear(plan, claims),
  premium: annualPremiums[plan.id],
}));

const columns = ['Plan', ...people, 'Deductible', 'Copays', 'Coinsurance', 'Not covered', 'Out of pocket', 'Premium', 'Total'];
const rows = results.map(({ plan, result, premium }) => [
  plan.id,
  ...people.map((p) => usd(result.byPerson.get(p)?.total ?? 0)),
  usd(result.total.deductible),
  usd(result.total.copays),
  usd(result.total.coinsurance),
  usd(result.total.notCovered),
  usd(result.total.total),
  premium === undefined ? '?' : usd(premium),
  premium === undefined ? '?' : usd(result.total.total + premium),
]);
const widths = columns.map((c, i) => Math.max(c.length, ...rows.map((r) => r[i]!.length)));
const line = (cells: string[]) => cells.map((c, i) => (i === 0 ? c.padEnd(widths[i]!) : c.padStart(widths[i]!))).join('  ');
console.log(line(columns));
for (const row of rows) console.log(line(row));
console.log();

const allPremiumsKnown = results.every((r) => r.premium !== undefined);
const cost = (r: (typeof results)[number]) => r.result.total.total + (allPremiumsKnown ? r.premium! : 0);
const [best, ...others] = [...results].sort((a, b) => cost(a) - cost(b));

for (const other of others) {
  const oopSavings = other.result.total.total - best!.result.total.total;
  if (allPremiumsKnown) {
    const premiumDiff = best!.premium! - other.premium!;
    console.log(
      `${best!.plan.id} is cheaper by ${usd(cost(other) - cost(best!))}/yr: ` +
        `${usd(Math.abs(premiumDiff))} ${premiumDiff < 0 ? 'less' : 'more'} in premiums, ` +
        `${usd(Math.abs(oopSavings))} ${oopSavings >= 0 ? 'less' : 'more'} out of pocket than ${other.plan.id}.`,
    );
  } else {
    console.log(
      `${best!.plan.id} costs ${usd(oopSavings)}/yr less out of pocket than ${other.plan.id}. ` +
        `It's the better deal if its premium is less than ${usd(oopSavings)}/yr (${usd(oopSavings / 12)}/mo) more.`,
    );
  }
}
