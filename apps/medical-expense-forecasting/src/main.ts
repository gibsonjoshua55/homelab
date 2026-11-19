import { expandRecurring } from './calculate.js';
import { annualCost, marginalRate, type AnnualCost } from './finances.js';
import { annualPremiums, expenses, fsaContributions, tax, uncoveredExpenses, YEAR } from './household.js';
import { loadPlans } from './plans.js';

const usd = (n: number) => `${n < 0 ? '-' : ''}$${Math.round(Math.abs(n)).toLocaleString('en-US')}`;
const pct = (n: number) => `${(n * 100).toFixed(2).replace(/\.?0+$/, '')}%`;

const plans = loadPlans();
const claims = expandRecurring(expenses, YEAR);
const people = [...new Set([...expenses, ...uncoveredExpenses].map((e) => e.person))];

const results = plans.map((plan) => {
  const premium = annualPremiums[plan.id];
  const fsaContribution = fsaContributions[plan.id];
  if (premium === undefined || fsaContribution === undefined) {
    throw new Error(`household.ts needs a premium and FSA contribution for ${plan.id}`);
  }
  return { plan, cost: annualCost(plan, claims, { premium, fsaContribution, tax, uncovered: uncoveredExpenses }) };
});

console.log(`Medical expense forecast for ${YEAR}\n`);
console.log('Covered care:');
for (const e of expenses) {
  const price = e.allowedAmount === undefined ? '' : `, $${e.allowedAmount.toFixed(2)} allowed each`;
  console.log(`  ${e.person}: ${e.timesPerYear}x ${e.serviceId} (${e.network}${price})`);
}
console.log('Not covered:');
for (const u of uncoveredExpenses) {
  console.log(`  ${u.person}: ${u.timesPerYear}x ${u.description} ($${u.amount.toFixed(2)} each${u.fsaEligible ? ', FSA-eligible' : ''})`);
}
console.log();

type Row = [label: string, value: (c: AnnualCost) => number] | [heading: string];
const rows: Row[] = [
  ['Spending'],
  ['Premiums', (c) => c.premium],
  ...people.map((p): Row => [`Covered care: ${p}`, (c) => c.coveredByPerson.get(p)?.total ?? 0]),
  ...uncoveredExpenses.map((u, i): Row => [`Not covered: ${u.description} (${u.person})`, (c) => c.uncovered[i]!.total]),
  ['Total spending', (c) => c.totalSpending],
  ['How it gets paid'],
  ['Premiums (payroll)', (c) => c.premium],
  ['From FSA', (c) => c.fsaUsed],
  ['With take-home pay', (c) => c.paidPostTax],
  ['FSA money left unspent (lost)', (c) => c.fsaForfeited],
  [`Tax savings at ${pct(marginalRate(tax))} (${pct(tax.federal)} federal + ${pct(tax.state)} state + ${pct(tax.fica)} FICA)`],
  [`On premiums${tax.premiumsPreTax ? '' : ' (premiums are after-tax)'}`, (c) => -c.taxSavedOnPremium],
  ['On FSA contribution', (c) => -c.taxSavedByFsa],
  ['Net cost', (c) => c.netCost],
];

const header = ['', ...results.map((r) => r.plan.id)];
const table = rows.map((row) => (row.length === 1 ? [row[0]] : ['  ' + row[0], ...results.map((r) => usd(row[1](r.cost)))]));
const widths = header.map((h, i) => Math.max(h.length, ...table.filter((t) => t.length > 1).map((t) => t[i]!.length)));
const line = (cells: string[]) => cells.map((c, i) => (i === 0 ? c.padEnd(widths[0]!) : c.padStart(widths[i]!))).join('  ');

console.log(line(header));
for (const cells of table) console.log(cells.length === 1 ? `\n${cells[0]}` : line(cells));
console.log();

const [best, ...others] = [...results].sort((a, b) => a.cost.netCost - b.cost.netCost);
for (const other of others) {
  const premiumGap = (other.cost.premium - other.cost.taxSavedOnPremium) - (best!.cost.premium - best!.cost.taxSavedOnPremium);
  const careGap = other.cost.netCost - best!.cost.netCost - premiumGap;
  console.log(
    `${best!.plan.id} is cheaper than ${other.plan.id} by ${usd(other.cost.netCost - best!.cost.netCost)}/yr after taxes: ` +
      `its premiums cost ${usd(Math.abs(premiumGap))} ${premiumGap < 0 ? 'more' : 'less'} after tax savings, ` +
      `and care costs ${usd(Math.abs(careGap))} ${careGap > 0 ? 'less' : 'more'}.`,
  );
}
