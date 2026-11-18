import { readFileSync } from 'node:fs';
import { parseCsv } from './csv.js';

export type Network = 'tier1' | 'tier2' | 'oon';
export const NETWORKS: readonly Network[] = ['tier1', 'tier2', 'oon'];

export type CostShare = 'no_charge' | 'copay' | 'coinsurance' | 'not_covered' | 'varies';

export interface Benefit {
  serviceId: string;
  service: string;
  costShare: CostShare;
  copay: number;
  coinsurancePct: number;
  deductibleApplies: boolean;
  limitPerYear?: number;
}

export interface Limits {
  individual: number;
  family: number;
}

export interface Plan {
  id: string;
  name: string;
  deductible: Record<Network, Limits>;
  oopMax: Record<Network, Limits>;
  /** serviceId -> network -> benefit */
  benefits: Map<string, Record<Network, Benefit>>;
}

// Compiled code runs from dist/, so the CSVs are read from the source folder.
const assets = new URL('../src/assets/', import.meta.url);
const readCsv = (name: string) => parseCsv(readFileSync(new URL(name, assets), 'utf8'));

export function loadPlans(): Plan[] {
  const plans = new Map<string, Plan>();

  for (const row of readCsv('plans.csv')) {
    const id = row['plan_id']!;
    const network = row['network'] as Network;
    let plan = plans.get(id);
    if (!plan) {
      plan = {
        id,
        name: row['plan_name']!,
        deductible: {} as Record<Network, Limits>,
        oopMax: {} as Record<Network, Limits>,
        benefits: new Map(),
      };
      plans.set(id, plan);
    }
    plan.deductible[network] = {
      individual: Number(row['deductible_individual']),
      family: Number(row['deductible_family']),
    };
    plan.oopMax[network] = {
      individual: Number(row['oop_max_individual']),
      family: Number(row['oop_max_family']),
    };
  }

  for (const row of readCsv('benefits.csv')) {
    const plan = plans.get(row['plan_id']!);
    if (!plan) throw new Error(`benefits.csv references unknown plan ${row['plan_id']}`);
    const serviceId = row['service_id']!;
    const byNetwork = plan.benefits.get(serviceId) ?? ({} as Record<Network, Benefit>);
    byNetwork[row['network'] as Network] = {
      serviceId,
      service: row['service']!,
      costShare: row['cost_share'] as CostShare,
      copay: Number(row['copay_usd'] || 0),
      coinsurancePct: Number(row['coinsurance_pct'] || 0),
      deductibleApplies: row['deductible_applies'] === 'true',
      ...(row['limit_per_year'] ? { limitPerYear: Number(row['limit_per_year']) } : {}),
    };
    plan.benefits.set(serviceId, byNetwork);
  }

  return [...plans.values()];
}
