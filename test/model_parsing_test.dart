import 'package:alwatanyachat/data/models/chat_message.dart';
import 'package:alwatanyachat/data/models/group_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage parsing', () {
    test('normalizes loosely typed Firestore values without crashing', () {
      final message = ChatMessage.fromMap('message-1', <String, dynamic>{
        'type': 7,
        'message': 42,
        'sender': true,
        'senderId': 99,
        'time': '1234',
        'pollQuestion': 123,
        'pollOptions': <Object>['A', 2, true],
        'uploadProgress': 4.5,
      });

      expect(message.type, '7');
      expect(message.message, '42');
      expect(message.sender, 'true');
      expect(message.senderId, '99');
      expect(message.pollQuestion, '123');
      expect(message.pollOptions, <String>['A', '2', 'true']);
      expect(message.uploadProgress, 1);
    });

    test('accepts a malformed poll option field as an empty list', () {
      final message = ChatMessage.fromMap('message-2', <String, dynamic>{
        'pollOptions': 'not-a-list',
        'uploadProgress': -2,
      });

      expect(message.pollOptions, isEmpty);
      expect(message.uploadProgress, 0);
    });

    test('preserves cache-safe fields on a round trip', () {
      const original = ChatMessage(
        id: 'message-3',
        type: 'file',
        message: 'Document',
        sender: 'Sender',
        senderId: 'sender-id',
        time: 9000,
        fileName: 'document.pdf',
        storagePath: 'groups/g/messages/m/document.pdf',
        replyToMessageId: 'message-1',
        replyToText: 'Earlier message',
      );

      final restored = ChatMessage.fromCacheMap(original.toCacheMap());
      expect(restored.id, original.id);
      expect(restored.fileName, original.fileName);
      expect(restored.storagePath, original.storagePath);
      expect(restored.replyToMessageId, original.replyToMessageId);
    });
  });

  group('GroupModel parsing', () {
    test('deduplicates and trims admin and member identifiers', () {
      final group = GroupModel.fromMap(<String, dynamic>{
        'groupId': 'g',
        'adminId': 'admin',
        'adminIds': <Object>[' admin ', 'second', 'second', ''],
        'memberIds': <Object>[' one ', 'one', 'two', ''],
      });

      expect(group.adminIds, <String>['admin', 'second']);
      expect(group.memberIds, <String>['one', 'two']);
    });

    test('uses stable defaults for incomplete cache data', () {
      final group = GroupModel.fromMap(const <String, dynamic>{});
      expect(group.groupId, isEmpty);
      expect(group.isActive, isTrue);
      expect(group.unreadCount, 0);
      expect(group.memberIds, isEmpty);
    });
  });
}
