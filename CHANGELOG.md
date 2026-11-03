# Changelog

Mỗi mục tương ứng một bản build và được dùng làm release notes trên GitHub.

## v1.9.2+15
- **Sửa lỗi giao diện:** thanh thu gọn (mini player) bị giãn tràn toàn màn hình khi mở các mục phân loại (Tất cả bài hát, Nghệ sĩ, Album, Thể loại, Playlist, Nghe gần đây, Lâu chưa nghe).
- Nguyên nhân: `Column` bên trong thanh dùng `mainAxisSize` mặc định là `max` nên giãn hết chiều cao còn trống của `Scaffold.bottomNavigationBar`; đã đổi sang `min`.
- Thanh thu gọn giờ cao cố định (~58dp + vùng an toàn) và hiển thị giống nhau trên mọi màn hình.

## v1.9.1+14
- **Widget màn hình chính:** căn giữa tên bài, nghệ sĩ và cụm nút điều khiển trong ô vuông.
- **Sửa lỗi nút widget không phản hồi:** media button trước đó gửi tới sai package; nay dùng đúng `MediaButtonReceiver` của app với `KEYCODE_MEDIA_*` (giống nút trên khung thông báo).
- Mở app bằng activity PendingIntent (được phép khởi chạy từ launcher) thay vì `startActivity()` trong BroadcastReceiver.

## v1.9.0+13
- **Widget màn hình chính Android (2x2):** cover làm nền, gradient thích ứng theo độ sáng cover (sáng → nền trắng chữ đen, tối → nền đen chữ trắng), tên bài, thanh thời gian phát, nút bài trước / play-pause / bài tiếp.
- Bài không có cover hiển thị logo đĩa Megaudio.
- Nút điều khiển hoạt động qua media session (không cần mở app).

## v1.8.1+12
- Đổi tên hiển thị trong app: drawer thành **MEGAUDIO**.
- Đổi package Dart thành `megaudio`, class `MegaudioApp` / `MegaudioAudioHandler`.
- Đổi Android namespace + applicationId thành `com.noet123456.megaudio`.

## v1.8.0+11
- Đổi tên app thành **Megaudio** (Windows title, Android label, web manifest, MaterialApp title).
- Binary Windows đổi thành `megaudio.exe`; cập nhật script build.

## v1.7.1+10
- Bỏ tiêu đề trong AppBar (chỉ còn logo và các thao tác).

## v1.7.0+9
- **Bỏ hoàn toàn chế độ nghe online** (YouTube/Audius), gỡ dependency mạng và quyền INTERNET.
- Lịch sử nghe cũ có bài online được tự lọc bỏ khi nạp.

## v1.6.0+8
- Chế độ tìm kiếm AUTO (đã gỡ ở v1.7.0): gộp 2 nguồn, chấm điểm độ khớp, lọc cover/karaoke/remix.

## v1.5.0+7
- Nguồn online Audius (nhanh, hợp pháp) + YouTube dự phòng.
- Shuffle theo **thể loại** thay vì album.
- Thanh thu gọn xuất hiện ở mọi màn hình.
- Android: media session, khung thông báo media, lock screen, nút tai nghe/Bluetooth.

## v1.4.1+6
- Timeout request online, kiểm tra kết nối, debounce tìm kiếm.

## v1.4.0+5
- Chế độ Online lần đầu (stream), drawer menu, offline home dạng lưới phân loại.

## v1.3.0+4
- Thiết kế lại toàn bộ UI theo phong cách Walkman (nền đen, monochrome, accent hổ phách).

## v1.2.0+3
- Sửa lỗi Android không load được thư mục (quyền storage).
- Quét đệ quy thư mục con, cho phép thư mục trống, nút quét lại.
- Sửa vòng lặp vô hạn parser WAV và race condition khi load bài.

## v1.1.0+2
- Bản đầu tiên: thư viện theo thư mục, FLAC/WAV/DSF/MP3, cover art, seek ±10s, 3 chế độ phát, phổ âm.
