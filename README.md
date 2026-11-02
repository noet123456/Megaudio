# Megaudio

Trình nghe nhạc Hi-Res offline cho Windows / Android / Web
## Tính năng

- **Thư viện theo thư mục**: chọn folder nhạc (hỗ trợ folder trống, quét đệ quy subfolder, nút quét lại) — MP3 / FLAC / WAV / DSF / AAC / OGG / M4A
- **Parser metadata nhị phân tự viết**: FLAC STREAMINFO + VORBIS_COMMENT, WAV RIFF, DSF, ID3v2 (TIT2/TPE1/TALB/TCON) — đọc sample rate, bit depth, genre, tag thật
- **Cover art nhúng**: FLAC PICTURE block và ID3v2 APIC (MP3/WAV/DSF), extract nền cho toàn bộ playlist
- **Thư viện phân loại**: Tất cả bài hát (A→Z), Nghệ sĩ, Album (kèm album tự tạo), Thể loại, Playlist tự tạo
- **Phát nhạc**: tua ±10s, previous/next, 3 chế độ (tuần tự / lặp 1 bài / shuffle **theo thể loại**)
- **Lịch sử & thống kê**: nghe gần đây, lâu chưa nghe
- **Phổ âm** bật/tắt (mô phỏng)
- **Android**: media session đầy đủ — khung thông báo media (cover, tên bài, play/pause, ±10s, next/prev), lock screen, nút tai nghe/Bluetooth

## Công nghệ

- Flutter + just_audio (Windows Media Foundation / ExoPlayer) + audio_service (Android media session)
- Provider state management, SharedPreferences cho persistence
- UI tự viết theo design system Walkman trong `lib/theme/app_colors.dart`

## Build

```powershell
# Windows / Android APK / Web, mỗi version một folder riêng trong Releases\
Set-ExecutionPolicy -Scope Process Bypass -Force
.\tools\build_release.ps1

# Chỉ một platform
.\tools\build_release.ps1 -Targets windows
.\tools\build_release.ps1 -Targets apk
```

Script tự đọc version từ `pubspec.yaml` và xuất ra `Releases\v<version>\{windows,android,web}`.

Yêu cầu: Flutter SDK (>= 3.x), JDK 17 cho build Android (đặt `JAVA_HOME` hoặc chỉnh `tools/build_release.ps1`).

## Kiểm thử headless

```powershell
dart run tools/scan_test.dart     # quét folder "bẩn", parse metadata, cover art
dart run tools/tag_check.dart     # kiểm tra tag của một file cụ thể
```

## Cấu trúc

```
lib/
  models/       Song + lịch sử nghe
  providers/    PlayerProvider (thư viện, hàng đợi, shuffle, lịch sử)
  screens/      Home + thư viện + player + equalizer
  services/     Audio player, Android media handler, parser nhị phân
  utils/        IO facade (native/web), icon shim
  widgets/      Song row, cover, mini player, drawer, spectrum
tools/          Build script + test headless
```
