export class DateUtil {
  public static formatTime(timestamp: number): string {
    let date = new Date(timestamp);
    let now = new Date();
    let hours = date.getHours().toString().padStart(2, '0');
    let minutes = date.getMinutes().toString().padStart(2, '0');
    let timeStr = hours + ':' + minutes;

    let isToday = date.getFullYear() === now.getFullYear() &&
      date.getMonth() === now.getMonth() &&
      date.getDate() === now.getDate();

    if (isToday) {
      return timeStr;
    }

    let yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    let isYesterday = date.getFullYear() === yesterday.getFullYear() &&
      date.getMonth() === yesterday.getMonth() &&
      date.getDate() === yesterday.getDate();

    if (isYesterday) {
      return '昨天 ' + timeStr;
    }

    let month = (date.getMonth() + 1).toString().padStart(2, '0');
    let day = date.getDate().toString().padStart(2, '0');
    return month + '/' + day + ' ' + timeStr;
  }

  public static formatDate(timestamp: number): string {
    let date = new Date(timestamp);
    let now = new Date();
    let isToday = date.getFullYear() === now.getFullYear() &&
      date.getMonth() === now.getMonth() &&
      date.getDate() === now.getDate();
    if (isToday) {
      return '今天 ' + DateUtil.formatTime(timestamp);
    }
    return DateUtil.formatTime(timestamp);
  }

  /** 格式化为完整日期时间（如：2026-06-24 15:00） */
  public static formatDateTime(timestamp: number): string {
    let date = new Date(timestamp);
    let year: string = date.getFullYear().toString();
    let month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    let day: string = date.getDate().toString().padStart(2, '0');
    let hours: string = date.getHours().toString().padStart(2, '0');
    let minutes: string = date.getMinutes().toString().padStart(2, '0');
    return year + '-' + month + '-' + day + ' ' + hours + ':' + minutes;
  }
}
