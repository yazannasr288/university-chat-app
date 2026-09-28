class ChatMessage {
  final String id;
  final String type;
  final String message;
  final String sender;
  final String senderId;
  final String? imageUrl;
  final String? videoUrl;
  final String? videoThumbnailUrl;
  final String? videoThumbnailPath;
  final String? storagePath;
  final String? localThumbnailPath;
  final String? audioUrl;
  final String? fileUrl;
  final String? fileName;
  final String? localFilePath;
  final int? audioDurationMs;
  final int time;
  final String pollQuestion;
  final List<String> pollOptions;
  final int? pollExpiresAt;
  final bool pollIsClosed;
  final String? eventId;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSender;
  final String? replyToType;
  final bool hasPendingWrites;
  final bool isLocalPending;
  final bool isFailed;
  final double uploadProgress;
  final int retryAttempt;
  final int nextRetryAt;

  const ChatMessage({
    required this.id,
    required this.type,
    required this.message,
    required this.sender,
    required this.senderId,
    required this.time,
    this.imageUrl,
    this.videoUrl,
    this.videoThumbnailUrl,
    this.videoThumbnailPath,
    this.storagePath,
    this.localThumbnailPath,
    this.audioUrl,
    this.fileUrl,
    this.fileName,
    this.localFilePath,
    this.audioDurationMs,
    this.pollQuestion = '',
    this.pollOptions = const [],
    this.pollExpiresAt,
    this.pollIsClosed = false,
    this.eventId,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSender,
    this.replyToType,
    this.hasPendingWrites = false,
    this.isLocalPending = false,
    this.isFailed = false,
    this.uploadProgress = 0,
    this.retryAttempt = 0,
    this.nextRetryAt = 0,
  });

  factory ChatMessage.fromMap(
    String id,
    Map<String, dynamic> map, {
    bool hasPendingWrites = false,
  }) {
    final rawPollOptions = map['pollOptions'];
    final pollOptions =
        rawPollOptions is Iterable
            ? rawPollOptions.map((option) => option.toString()).toList()
            : const <String>[];
    final rawUploadProgress =
        double.tryParse(map['uploadProgress']?.toString() ?? '0') ?? 0;

    return ChatMessage(
      id: id,
      type: (map['type'] ?? 'text').toString(),
      message: (map['message'] ?? '').toString(),
      sender: (map['sender'] ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      time: int.tryParse(map['time']?.toString() ?? '0') ?? 0,
      imageUrl: map['imageUrl']?.toString(),
      videoUrl: map['videoUrl']?.toString(),
      videoThumbnailUrl: map['videoThumbnailUrl']?.toString(),
      videoThumbnailPath: map['videoThumbnailPath']?.toString(),
      storagePath: map['storagePath']?.toString(),
      localThumbnailPath: map['localThumbnailPath']?.toString(),
      audioUrl: map['audioUrl']?.toString(),
      fileUrl: map['fileUrl']?.toString(),
      fileName: map['fileName']?.toString(),
      localFilePath: map['localFilePath']?.toString(),
      audioDurationMs: int.tryParse(map['audioDurationMs']?.toString() ?? ''),
      pollQuestion: (map['pollQuestion'] ?? '').toString(),
      pollOptions: pollOptions,
      pollExpiresAt: int.tryParse(map['pollExpiresAt']?.toString() ?? ''),
      pollIsClosed: map['pollIsClosed'] == true,
      eventId: map['eventId']?.toString(),
      replyToMessageId: map['replyToMessageId']?.toString(),
      replyToText: map['replyToText']?.toString(),
      replyToSender: map['replyToSender']?.toString(),
      replyToType: map['replyToType']?.toString(),
      hasPendingWrites: hasPendingWrites || map['hasPendingWrites'] == true,
      isLocalPending: map['isLocalPending'] == true,
      isFailed: map['isFailed'] == true,
      uploadProgress: rawUploadProgress.clamp(0.0, 1.0).toDouble(),
      retryAttempt: int.tryParse(map['retryAttempt']?.toString() ?? '0') ?? 0,
      nextRetryAt: int.tryParse(map['nextRetryAt']?.toString() ?? '0') ?? 0,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? type,
    String? message,
    String? sender,
    String? senderId,
    String? imageUrl,
    String? videoUrl,
    String? videoThumbnailUrl,
    String? videoThumbnailPath,
    String? storagePath,
    String? localThumbnailPath,
    String? audioUrl,
    String? fileUrl,
    String? fileName,
    String? localFilePath,
    int? audioDurationMs,
    int? time,
    String? pollQuestion,
    List<String>? pollOptions,
    int? pollExpiresAt,
    bool? pollIsClosed,
    String? eventId,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSender,
    String? replyToType,
    bool? hasPendingWrites,
    bool? isLocalPending,
    bool? isFailed,
    double? uploadProgress,
    int? retryAttempt,
    int? nextRetryAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      sender: sender ?? this.sender,
      senderId: senderId ?? this.senderId,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      videoThumbnailPath: videoThumbnailPath ?? this.videoThumbnailPath,
      storagePath: storagePath ?? this.storagePath,
      localThumbnailPath: localThumbnailPath ?? this.localThumbnailPath,
      audioUrl: audioUrl ?? this.audioUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      localFilePath: localFilePath ?? this.localFilePath,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      time: time ?? this.time,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      pollOptions: pollOptions ?? this.pollOptions,
      pollExpiresAt: pollExpiresAt ?? this.pollExpiresAt,
      pollIsClosed: pollIsClosed ?? this.pollIsClosed,
      eventId: eventId ?? this.eventId,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSender: replyToSender ?? this.replyToSender,
      replyToType: replyToType ?? this.replyToType,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
      isLocalPending: isLocalPending ?? this.isLocalPending,
      isFailed: isFailed ?? this.isFailed,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      retryAttempt: retryAttempt ?? this.retryAttempt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'type': type,
      'message': message,
      'sender': sender,
      'senderId': senderId,
      'time': time,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (videoThumbnailUrl != null) 'videoThumbnailUrl': videoThumbnailUrl,
      if (storagePath != null) 'storagePath': storagePath,
      if (videoThumbnailPath != null) 'videoThumbnailPath': videoThumbnailPath,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (audioDurationMs != null) 'audioDurationMs': audioDurationMs,
      if (pollQuestion.isNotEmpty) 'pollQuestion': pollQuestion,
      if (pollOptions.isNotEmpty) 'pollOptions': pollOptions,
      if (pollExpiresAt != null) 'pollExpiresAt': pollExpiresAt,
      if (pollIsClosed) 'pollIsClosed': pollIsClosed,
      if (eventId != null) 'eventId': eventId,
      if (replyToMessageId?.trim().isNotEmpty == true)
        'replyToMessageId': replyToMessageId,
      if (replyToText?.trim().isNotEmpty == true) 'replyToText': replyToText,
      if (replyToSender?.trim().isNotEmpty == true)
        'replyToSender': replyToSender,
      if (replyToType?.trim().isNotEmpty == true) 'replyToType': replyToType,
    };
  }

  factory ChatMessage.fromCacheMap(Map<String, dynamic> map) {
    return ChatMessage.fromMap(map['id']?.toString() ?? '', map);
  }

  Map<String, dynamic> toPendingCacheMap() {
    return {
      ...toCacheMap(),
      if (localFilePath?.trim().isNotEmpty == true)
        'localFilePath': localFilePath,
      if (localThumbnailPath?.trim().isNotEmpty == true)
        'localThumbnailPath': localThumbnailPath,
      'hasPendingWrites': hasPendingWrites,
      'isLocalPending': isLocalPending,
      'isFailed': isFailed,
      'uploadProgress': uploadProgress,
      'retryAttempt': retryAttempt,
      'nextRetryAt': nextRetryAt,
    };
  }

  factory ChatMessage.fromPendingCacheMap(Map<String, dynamic> map) {
    return ChatMessage.fromMap(map['id']?.toString() ?? '', map);
  }
}
