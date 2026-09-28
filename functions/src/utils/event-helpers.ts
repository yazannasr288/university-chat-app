
export function formatEventDate(eventAt: number): string {
	return new Date(eventAt).toLocaleString("en-GB", {
		year: "numeric",
		month: "2-digit",
		day: "2-digit",
		hour: "2-digit",
		minute: "2-digit",
		hour12: false,
	});
}

const MINUTE_MS = 60 * 1000;

type ArabicUnitForms = {
	one: string;
	two: string;
	few: string;
	many: string;
};

function formatArabicUnit(value: number, forms: ArabicUnitForms): string {
	if (value === 1) return forms.one;
	if (value === 2) return forms.two;
	if (value >= 3 && value <= 10) return `${value} ${forms.few}`;
	return `${value} ${forms.many}`;
}

const dayForms: ArabicUnitForms = {
	one: "يوم واحد",
	two: "يومان",
	few: "أيام",
	many: "يوم",
};

const hourForms: ArabicUnitForms = {
	one: "ساعة واحدة",
	two: "ساعتان",
	few: "ساعات",
	many: "ساعة",
};

const minuteForms: ArabicUnitForms = {
	one: "دقيقة واحدة",
	two: "دقيقتان",
	few: "دقائق",
	many: "دقيقة",
};

export function formatRemainingDurationArabic(remainingMs: number): string {
	const totalMinutes = Math.max(1, Math.round(remainingMs / MINUTE_MS));
	const totalHours = Math.floor(totalMinutes / 60);
	const minutes = totalMinutes % 60;

	if (totalHours === 0) {
		return formatArabicUnit(totalMinutes, minuteForms);
	}

	if (totalHours < 48) {
		const parts = [formatArabicUnit(totalHours, hourForms)];

		if (minutes > 0) {
			parts.push(formatArabicUnit(minutes, minuteForms));
		}

		return parts.join(" و ");
	}

	const days = Math.floor(totalHours / 24);
	const hours = totalHours % 24;
	const parts: string[] = [];

	if (days > 0) {
		parts.push(formatArabicUnit(days, dayForms));
	}

	if (hours > 0) {
		parts.push(formatArabicUnit(hours, hourForms));
	}

	if (minutes > 0) {
		parts.push(formatArabicUnit(minutes, minuteForms));
	}

	return parts.join(" و ");
}

function formatEnglishUnit(
	value: number,
	singular: string,
	plural: string,
): string {
	return value === 1 ? `1 ${singular}` : `${value} ${plural}`;
}

export function formatRemainingDurationEnglish(remainingMs: number): string {
	const totalMinutes = Math.max(1, Math.round(remainingMs / MINUTE_MS));
	const totalHours = Math.floor(totalMinutes / 60);
	const minutes = totalMinutes % 60;

	if (totalHours === 0) {
		return formatEnglishUnit(totalMinutes, "minute", "minutes");
	}

	if (totalHours < 48) {
		const parts = [formatEnglishUnit(totalHours, "hour", "hours")];
		if (minutes > 0)
			parts.push(formatEnglishUnit(minutes, "minute", "minutes"));
		return parts.join(" and ");
	}

	const days = Math.floor(totalHours / 24);
	const hours = totalHours % 24;
	const parts: string[] = [];
	if (days > 0) parts.push(formatEnglishUnit(days, "day", "days"));
	if (hours > 0) parts.push(formatEnglishUnit(hours, "hour", "hours"));
	if (minutes > 0) parts.push(formatEnglishUnit(minutes, "minute", "minutes"));
	return parts.join(" and ");
}

export function buildReminderCheckpoints(createdAtMs: number, eventAt: number) {
	const totalDuration = eventAt - createdAtMs;

	const halfAt = createdAtMs + Math.floor(totalDuration / 2);
	const quarterAt = createdAtMs + Math.floor(totalDuration * 0.75);
	const hourAt = eventAt - 60 * 60 * 1000;

	return {
		halfAt,
		quarterAt,
		hourAt,
	};
}

export const eventReminderKeys = ["half", "quarter", "hour"] as const;

export type EventReminderKey = (typeof eventReminderKeys)[number];

export function listEventReminderCheckpoints(
	createdAtMs: number,
	eventAt: number,
): Array<{ key: EventReminderKey; at: number }> {
	const checkpoints = buildReminderCheckpoints(createdAtMs, eventAt);
	const checkpointsByTime = new Map<
		number,
		{ key: EventReminderKey; at: number }
	>();

	for (const key of eventReminderKeys) {
		const at = checkpoints[`${key}At`];
		if (at > createdAtMs && at < eventAt) {
			// The one-hour reminder is the most specific when two formulae land on
			// the exact same instant (for example, a two-hour event).
			checkpointsByTime.set(at, { key, at });
		}
	}

	return [...checkpointsByTime.values()].sort(
		(left, right) => left.at - right.at,
	);
}

export function findNextEventReminderAt({
	createdAtMs,
	eventAt,
	nowMs,
	sentKeys = [],
}: {
	createdAtMs: number;
	eventAt: number;
	nowMs: number;
	sentKeys?: Iterable<EventReminderKey>;
}): number | null {
	const sent = new Set(sentKeys);
	const next = listEventReminderCheckpoints(createdAtMs, eventAt).find(
		({ key }) => !sent.has(key),
	);

	if (!next) return null;
	return Math.max(nowMs, next.at);
}
