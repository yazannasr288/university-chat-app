export function normalizeSyrianPhone(input: string): string | null {
  const raw = String(input ?? "")
    .trim()
    .replace(/[\s-]+/g, "");

  if (raw.startsWith("+9639") && raw.length === 13) return raw;
  if (raw.startsWith("009639") && raw.length === 14) return `+${raw.substring(2)}`;
  if (raw.startsWith("09") && raw.length === 10) return `+963${raw.substring(1)}`;
  if (raw.startsWith("9") && raw.length === 9) return `+963${raw}`;
  return null;
}
