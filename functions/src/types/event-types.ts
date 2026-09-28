export type EventScopeType = "university" | "department" | "group";

export type LocalizedNotificationText = string | { ar: string; en: string };

export type ScopeMeta = {
  department: string;
  targetGroupId: string;
  targetGroupName: string;
  visibilityKeys: string[];
};

export type ResolveScopeMetaArgs = {
  scopeType: EventScopeType;
  groupId: string;
  callerUid: string;
  callerRole: string;
  callerDepartment: string;
};

export type CallerManageEventArgs = {
  callerUid: string;
  callerRole: string;
  callerDepartment: string;
  eventData: Record<string, any>;
};

export type NotifyEventAudienceArgs = {
  eventId: string;
  title: LocalizedNotificationText;
  body: LocalizedNotificationText;
  scopeType: EventScopeType;
  department: string;
  targetGroupId: string;
  dataType: string;
};
