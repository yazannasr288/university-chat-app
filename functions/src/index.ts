import { setGlobalOptions } from "firebase-functions/v2";

setGlobalOptions({
  region: "us-central1",
  memory: "256MiB",
  cpu: "gcf_gen1",
  maxInstances: 3,
  minInstances: 0,
});
import * as admin from "firebase-admin";

admin.initializeApp();
export * from "./functions/events";
export * from "./functions/bulk-import";
export * from "./functions/sessions";
export * from "./functions/messages";
export * from "./functions/admin-users";
export * from "./functions/groups";
export * from "./functions/users";
export * from "./functions/dashboard";
export * from "./functions/monitoring";
