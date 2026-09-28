export const region = "us-central1";


export const mediumCallableOptions = {
  region,
  memory: "512MiB" as const,
  cpu: "gcf_gen1" as const,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 1,
  timeoutSeconds: 120,
} as const;

export const fastCallableOptions = {
  region,
  memory: "256MiB" as const,
  cpu: "gcf_gen1" as const,
  maxInstances: 3,
  minInstances: 0,
  concurrency: 1,
  timeoutSeconds: 60,
} as const;

export const fastMediumCallableOptions = {
  region,
  memory: "512MiB" as const,
  cpu: "gcf_gen1" as const,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 1,
  timeoutSeconds: 180,
} as const;

export const heavyCallableOptions = {
  region,
  memory: "512MiB" as const,
  cpu: "gcf_gen1" as const,
  maxInstances: 1,
  minInstances: 0,
  concurrency: 1,
  timeoutSeconds: 540,
} as const;

export const firestoreTriggerOptions = {
  region,
  memory: "512MiB" as const,
  cpu: "gcf_gen1" as const,
  maxInstances: 1,
  minInstances: 0,
  timeoutSeconds: 300,
} as const;


export const scheduledJobOptions = {
  region,
  memory: "512MiB" as const,
  cpu: "gcf_gen1" as const,
  maxInstances: 1,
  minInstances: 0,
  timeoutSeconds: 300,
} as const;

export const bulkImportChunkOptions = {
  region,
  memory: "512MiB" as const,
  cpu: "gcf_gen1" as const,
  maxInstances: 1,
  minInstances: 0,
  timeoutSeconds: 540,
} as const;