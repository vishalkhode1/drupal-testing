<?php

/**
 * Formats the log to display on terminal.
 *
 * @param string $message
 *   The message to log.
 * @param string $type
 *   The log type.
 */
function format_log(string $message, string $type = 'info'): string {
  return match ($type) {
    'error' => "\033[31m [error]\033[0m $message ",
    'success' => "\033[32m [success]\033[0m $message",
    'warning' => "\033[33m [warning] $message",
    default => "\033[36m [info]\033[0m $message",
  };
}

/**
 * Logs the message.
 *
 * @param string $message
 *   The message to log.
 * @param string $type
 *   The log type.
 */
function log_message(string $message, string $type = "info"): void {
  $message = format_log($message, $type) . PHP_EOL;
  print($message);
  flush();
  sleep(1);
}
