export function mapAccountTypeToRole(accountType: string): string {
  switch (accountType) {
    case "presidency_employee":
      return "admin0";
    case "dean":
      return "admin1";
    case "employee":
    case "doctor":
      return "admin2";
    case "worker":
      // Workers remain regular members; their access is controlled by
      // accountType and the group audience rather than admin permissions.
      return "user";
    default:
      return "user";
  }
}

export function mapDepartmentToGroup(department: string): string {
  switch (department) {
    case "طب الاسنان":
      return "main_dentist";
    case "الصيدلة":
      return "main_pharmacy";
    case "هندسة العمارة":
      return "main_architecture";
    case "هندسة الحاسوب":
      return "main_computer";
    case "إدارة الأعمال":
      return "main_business";
    case "الهندسة المدنية":
      return "main_civil";
    case "هندسة الإتصالات":
      return "main_communication";
    case "عامل":
      return "main_worker";
    default:
      return "main_general";
  }
}

export function mapAccountTypeToSpecialGroup(accountType: string): string | null {
  switch (accountType) {
    case "presidency_employee":
      return "main_presidency_employee";
    case "dean":
      return "main_dean";
    case "employee":
      return "main_employee";
    case "doctor":
      return "main_doctor";
    case "worker":
      return "main_worker";
    default:
      return null;
  }
}

export function buildDefaultGroupNames(department: string, accountType: string): string[] {
  const names = ["main_wpu", mapDepartmentToGroup(department)];
  const specialGroup = mapAccountTypeToSpecialGroup(accountType);

  if (specialGroup) {
    names.push(specialGroup);
  }

  return [...new Set(names)];
}
