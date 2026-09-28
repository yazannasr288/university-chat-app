abstract final class AppStorageFolders {
  static const String groupIcons = 'group_icons';
  static const String profileImages = 'profile_images';
  static const String chatImages = 'chat_images';
  static const String chatVideos = 'chat_videos';
  static const String chatAudio = 'chat_audio';
  static const String chatVideoThumbnails = 'chat_video_thumbnails';
  static const String files = 'files';

  static const Set<String> imageFolders = {
    groupIcons,
    profileImages,
    chatImages,
    chatVideoThumbnails,
  };

  static bool isImageFolder(String folder) => imageFolders.contains(folder);
  static bool isVideoFolder(String folder) => folder == chatVideos;
  static bool isAudioFolder(String folder) => folder == chatAudio;
  static bool isGenericFileFolder(String folder) => folder == files;
}
