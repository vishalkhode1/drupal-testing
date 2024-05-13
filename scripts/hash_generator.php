<?php

require_once './logger.php';

class HashGenerator {
  public static function randomBytesBase64($count = 32) {
    return str_replace(['+', '/', '='], ['-', '_', ''], base64_encode(random_bytes($count)));
  }
}

$characterCount = $argv[1] ?? 55;
if (!is_numeric($characterCount)) {
  log_message("Character count should be numeric.", "error");
  die(1);
}

echo HashGenerator::randomBytesBase64(55);
