import { defineSecret } from "firebase-functions/params";

export const PIN_PEPPER = defineSecret("PIN_PEPPER");
export const BULK_IMPORT_AES_KEY_B64 = defineSecret(
	"BULK_IMPORT_AES_KEY_B64",
);
