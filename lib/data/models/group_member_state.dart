class GroupMemberState {
  final String uid;
  final int lastDeliveredMessageTime;
  final int lastReadMessageTime;

  const GroupMemberState({
    required this.uid,
    required this.lastDeliveredMessageTime,
    required this.lastReadMessageTime,
  });

  factory GroupMemberState.fromMap(String id, Map<String, dynamic> map) {
    return GroupMemberState(
      uid: (map['uid'] ?? id).toString(),
      lastDeliveredMessageTime: int.tryParse(
            map['lastDeliveredMessageTime']?.toString() ?? '0',
          ) ??
          0,
      lastReadMessageTime: int.tryParse(
            map['lastReadMessageTime']?.toString() ?? '0',
          ) ??
          0,
    );
  }
}
