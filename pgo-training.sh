#!/usr/bin/env bash
set -euo pipefail

PHP_BIN="${1:-./bin/php7/bin/php}"
ROUNDS=3
DURATION_TARGET=55

if [[ ! -x "$PHP_BIN" ]]; then
    echo "Error: PHP binary not found or not executable at: $PHP_BIN"
    exit 1
fi

echo "=== PGO Training Script for PocketMine-MP PHP Binaries ==="
echo "PHP binary: $PHP_BIN"
echo "Rounds per workload: $ROUNDS"
echo ""

WORKLOADS=(
    "igbinary_serialization"
    "zlib_compression"
    "hashing"
    "leveldb_simulation"
    "string_operations"
    "math_operations"
    "json_operations"
    "file_io"
    "opcode_heavy_loops"
)

total=${#WORKLOADS[@]}
current=0

run_php() {
    "$PHP_BIN" -d error_reporting=0 -d display_errors=0 -r "$1" 2>/dev/null
}

print_progress() {
    local name="$1"
    local idx="$2"
    local total="$3"
    echo "[$idx/$total] Running: $name"
}

igbinary_serialization() {
    run_php '
    $r = 3;
    for ($round = 0; $round < $r; $round++) {
        $worlds = [];
        for ($i = 0; $i < 500; $i++) {
            $worlds[] = [
                "name" => "world_" . $i,
                "seed" => mt_rand(1, 999999999),
                "players" => [],
                "chunks" => [],
                "time" => time(),
                "difficulty" => mt_rand(0, 3),
                "gamemode" => mt_rand(0, 3),
            ];
            for ($p = 0; $p < mt_rand(2, 15); $p++) {
                $worlds[$i]["players"][] = [
                    "uuid" => bin2hex(random_bytes(16)),
                    "name" => "Player" . $p . "_" . $i,
                    "x" => mt_rand(-10000, 10000) / 10,
                    "y" => mt_rand(0, 256) / 1,
                    "z" => mt_rand(-10000, 10000) / 10,
                    "health" => mt_rand(0, 20),
                    "food" => mt_rand(0, 20),
                    "level" => mt_rand(0, 30),
                    "inventory" => array_fill(0, 36, null),
                    "armor" => [null, null, null, null],
                    "hotbar" => [null, null, null, null, null, null, null, null, null],
                ];
            }
            for ($c = 0; $c < 256; $c++) {
                $worlds[$i]["chunks"][$c] = [
                    "x" => mt_rand(-100, 100),
                    "z" => mt_rand(-100, 100),
                    "sections" => array_fill(0, 16, str_repeat("\x00", 256)),
                    "biomeIds" => array_fill(0, 256, mt_rand(0, 38)),
                    "skyLight" => str_repeat("\xff", 2048),
                    "blockLight" => str_repeat("\xff", 2048),
                    "heightmap" => array_fill(0, 256, mt_rand(0, 256)),
                ];
            }
        }
        $packed = igbinary_serialize($worlds);
        $unpacked = igbinary_unserialize($packed);
        unset($packed, $unpacked);
    }
    echo "igbinary OK\n";
    '
}

zlib_compression() {
    run_php '
    $r = 3;
    for ($round = 0; $round < $r; $round++) {
        $payloads = [];
        for ($i = 0; $i < 200; $i++) {
            $size = mt_rand(1024, 65536);
            $data = random_bytes($size);
            $compressed = gzcompress($data, 6);
            $decompressed = gzuncompress($compressed);
            if ($decompressed !== $data) {
                echo "zlib mismatch!\n";
                exit(1);
            }
        }
        for ($level = 1; $level <= 9; $level++) {
            $data = random_bytes(32768);
            $c = gzcompress($data, $level);
            gzuncompress($c);
        }
    }
    echo "zlib OK\n";
    '
}

hashing() {
    run_php '
    $r = 3;
    for ($round = 0; $round < $r; $round++) {
        for ($i = 0; $i < 2000; $i++) {
            $data = random_bytes(mt_rand(32, 4096));
            hash("sha256", $data);
            hash("md5", $data);
            hash("sha1", $data);
            hash("crc32", $data);
            hash_hmac("sha256", $data, "pocketmine-mp-key-" . $i);
        }
        for ($i = 0; $i < 500; $i++) {
            $data = random_bytes(2048);
            hash("xxh128", $data);
            hash("fnv132a", $data);
            hash("fnv164a", $data);
        }
    }
    echo "hashing OK\n";
    '
}

leveldb_simulation() {
    run_php '
    $r = 3;
    for ($round = 0; $round < $r; $round++) {
        $db = [];
        for ($i = 0; $i < 3000; $i++) {
            $key = "chunk_" . mt_rand(0, 100) . "_" . mt_rand(0, 100);
            $value = random_bytes(mt_rand(128, 8192));
            $db[$key] = $value;
        }
        foreach ($db as $k => $v) {
            if (!isset($db[$k])) {
                echo "key missing: $k\n";
            }
        }
        $keys = array_keys($db);
        shuffle($keys);
        $deleteCount = (int)(count($keys) * 0.3);
        for ($i = 0; $i < $deleteCount; $i++) {
            unset($db[$keys[$i]]);
        }
        for ($i = 0; $i < 1500; $i++) {
            $key = "chunk_" . mt_rand(0, 100) . "_" . mt_rand(0, 100);
            $db[$key] = random_bytes(mt_rand(256, 4096));
        }
        ksort($db);
        $prefix = "chunk_5_";
        $matched = [];
        foreach ($db as $k => $v) {
            if (strncmp($k, $prefix, strlen($prefix)) === 0) {
                $matched[] = $k;
            }
        }
        unset($db, $matched);
    }
    echo "leveldb OK\n";
    '
}

string_operations() {
    run_php '
    $r = 3;
    for ($round = 0; $round < $r; $round++) {
        for ($i = 0; $i < 2000; $i++) {
            $str = str_repeat("PocketMine-MP ", mt_rand(10, 200));
            substr($str, mt_rand(0, strlen($str) / 2), mt_rand(10, 100));
            strlen($str);
            strtolower($str);
            strtoupper($str);
            str_replace("Pocket", "Bedrock", $str);
            str_contains($str, "MP");
            str_starts_with($str, "Pocket");
            str_ends_with($str, " ");
            str_pad($str, strlen($str) + 50);
            str_split($str, 32);
        }
        for ($i = 0; $i < 500; $i++) {
            $str = "Player" . mt_rand(1, 99999) . " joined world_" . mt_rand(0, 100);
            preg_match("/^Player(\d+) joined (world_\d+)$/", $str, $m);
            preg_replace("/\d+/", "#", $str);
            preg_split("/\s+/", $str);
            preg_match_all("/\d+/", $str, $all);
        }
        for ($i = 0; $i < 200; $i++) {
            $haystack = str_repeat("abcdef0123456789", mt_rand(50, 200));
            $needle = "f0" . mt_rand(0, 9);
            substr_count($haystack, $needle);
            str_word_count($haystack);
            chunk_split($haystack, 64, "|");
            wordwrap($haystack, 32, "\n");
        }
    }
    echo "string OK\n";
    '
}

math_operations() {
    run_php '
    $r = 3;
    for ($round = 0; $round < $r; $round++) {
        for ($i = 0; $i < 5000; $i++) {
            $a = mt_rand(1, 1000000);
            $b = mt_rand(1, 1000000);
            $a + $b;
            $a - $b;
            $a * $b;
            $b != 0 ? intdiv($a, $b) : 0;
            $b != 0 ? ($a % $b) : 0;
            pow($a, mt_rand(1, 3));
            sqrt($a);
            abs($a - $b);
            min($a, $b);
            max($a, $b);
        }
        for ($i = 0; $i < 1000; $i++) {
            $a = mt_rand(1, 1000000);
            $b = mt_rand(1, 1000000);
            $a & $b;
            $a | $b;
            $a ^ $b;
            ~$a;
            $a << 2;
            $a >> 1;
            decbin($a);
            dechex($a);
            bindec(decbin($a));
        }
        if (function_exists("bcscale")) {
            bcscale(20);
            for ($i = 0; $i < 300; $i++) {
                $a = (string)mt_rand(1, 999999999);
                $b = (string)mt_rand(1, 999999);
                bcadd($a, $b);
                bcsub($a, $b);
                bcmul($a, $b);
                bcdiv($a, $b, 10);
                bcpow($a, "2");
                bcsqrt($a);
                bccomp($a, $b);
            }
        }
        for ($i = 0; $i < 500; $i++) {
            $x = mt_rand(-1000, 1000) / 100;
            $y = mt_rand(-1000, 1000) / 100;
            sin($x);
            cos($y);
            tan($x);
            exp($x);
            log(abs($x) + 1);
            floor($x);
            ceil($x);
            round($x, 2);
            intval($x);
            floatval((string)$x);
        }
        for ($i = 0; $i < 200; $i++) {
            $val = mt_rand(0, 1000000);
            base_convert((string)$val, 10, 16);
            base_convert(dechex($val), 16, 2);
            number_format(mt_rand(1000000, 99999999) / 100, 2, ".", ",");
        }
    }
    echo "math OK\n";
    '
}

json_operations() {
    run_php '
    $r = 3;
    for ($round = 0; $round < $r; $round++) {
        for ($i = 0; $i < 500; $i++) {
            $player = [
                "uuid" => bin2hex(random_bytes(16)),
                "name" => "Player_" . $i,
                "position" => [
                    "x" => mt_rand(-10000, 10000) / 10,
                    "y" => mt_rand(0, 256),
                    "z" => mt_rand(-10000, 10000) / 10,
                    "world" => "world_" . mt_rand(0, 5),
                ],
                "health" => mt_rand(0, 20) / 1,
                "food" => mt_rand(0, 20) / 1,
                "experience" => [
                    "level" => mt_rand(0, 30),
                    "progress" => mt_rand(0, 100) / 100,
                ],
                "inventory" => [],
                "permissions" => ["pocketmine.command.tp", "pocketmine.command.ban"],
                "settings" => [
                    "lang" => "eng",
                    "skin" => [
                        "model" => "standard",
                        "skinId" => bin2hex(random_bytes(16)),
                        "capeId" => "",
                        "skinData" => base64_encode(random_bytes(8192)),
                    ],
                ],
                "firstJoin" => time() - mt_rand(0, 31536000),
                "lastPlayed" => time(),
            ];
            for ($slot = 0; $slot < 36; $slot++) {
                $player["inventory"][$slot] = [
                    "id" => mt_rand(0, 500),
                    "damage" => mt_rand(0, 100),
                    "count" => mt_rand(1, 64),
                    "nbt" => null,
                ];
            }
            $json = json_encode($player, JSON_THROW_ON_ERROR);
            json_decode($json, true, 512, JSON_THROW_ON_ERROR);
        }
        for ($i = 0; $i < 200; $i++) {
            $chunkData = [
                "biomes" => array_fill(0, 256, mt_rand(0, 38)),
                "blocks" => [],
                "skyLight" => base64_encode(random_bytes(2048)),
                "blockLight" => base64_encode(random_bytes(2048)),
                "heightmap" => array_fill(0, 256, mt_rand(0, 256)),
                "tileEntities" => [],
                "entities" => [],
            ];
            for ($sec = 0; $sec < 16; $sec++) {
                $chunkData["blocks"][$sec] = [
                    "blockIds" => base64_encode(random_bytes(4096)),
                    "data" => base64_encode(random_bytes(2048)),
                ];
            }
            for ($e = 0; $e < mt_rand(0, 20); $e++) {
                $chunkData["entities"][] = [
                    "id" => mt_rand(10, 200),
                    "x" => mt_rand(0, 256),
                    "y" => mt_rand(0, 256),
                    "z" => mt_rand(0, 256),
                ];
            }
            $json = json_encode($chunkData, JSON_THROW_ON_ERROR);
            json_decode($json, true, 512, JSON_THROW_ON_ERROR);
        }
        for ($i = 0; $i < 100; $i++) {
            $batch = [];
            for ($p = 0; $p < mt_rand(5, 50); $p++) {
                $batch[] = ["type" => mt_rand(0, 100), "payload" => base64_encode(random_bytes(mt_rand(16, 512)))];
            }
            $json = json_encode($batch, JSON_THROW_ON_ERROR);
            json_decode($json, true, 512, JSON_THROW_ON_ERROR);
        }
    }
    echo "json OK\n";
    '
}

file_io() {
    run_php '
    $tmpDir = sys_get_temp_dir() . "/pgo_training_" . getmypid();
    @mkdir($tmpDir, 0755, true);
    $r = 3;
    for ($round = 0; $round < $r; $round++) {
        $files = [];
        for ($i = 0; $i < 200; $i++) {
            $path = $tmpDir . "/test_" . $round . "_" . $i . ".dat";
            $data = random_bytes(mt_rand(512, 16384));
            file_put_contents($path, $data);
            $files[] = $path;
        }
        foreach ($files as $f) {
            file_get_contents($f);
        }
        foreach ($files as $f) {
            $fp = fopen($f, "rb");
            while (!feof($fp)) {
                fread($fp, 4096);
            }
            fclose($fp);
        }
        foreach ($files as $f) {
            clearstatcache(true, $f);
            filesize($f);
            filemtime($f);
            is_file($f);
            is_dir($tmpDir);
        }
        $appendFiles = [];
        for ($i = 0; $i < 50; $i++) {
            $path = $tmpDir . "/append_" . $round . "_" . $i . ".log";
            $appendFiles[] = $path;
            $fp = fopen($path, "w");
            for ($line = 0; $line < 100; $line++) {
                fwrite($fp, "[" . date("Y-m-d H:i:s") . "] [Server] INFO Line $line of test data for profiling purposes\n");
            }
            fclose($fp);
        }
        foreach ($appendFiles as $f) {
            $fp = fopen($f, "a");
            for ($line = 0; $line < 50; $line++) {
                fwrite($fp, "[" . date("Y-m-d H:i:s") . "] [Server] INFO Appended line $line\n");
            }
            fclose($fp);
        }
        foreach ($files as $f) {
            @unlink($f);
        }
        foreach ($appendFiles as $f) {
            @unlink($f);
        }
        for ($i = 0; $i < 50; $i++) {
            $dir = $tmpDir . "/subdir_" . $round . "_" . $i;
            @mkdir($dir, 0755, true);
            file_put_contents($dir . "/info.json", json_encode(["name" => "dir_$i"]));
            glob($dir . "/*");
            is_dir($dir);
            @rmdir($dir);
        }
        $globPattern = $tmpDir . "/test_" . $round . "_*.dat";
        glob($globPattern);
    }
    $all = glob($tmpDir . "/*");
    if (is_array($all)) {
        foreach ($all as $f) {
            @unlink($f);
        }
    }
    @rmdir($tmpDir);
    echo "fileio OK\n";
    '
}

opcode_heavy_loops() {
    run_php '
    $r = 3;
    for ($round = 0; $round < $r; $round++) {
        $arr = range(1, 3000);
        shuffle($arr);
        usort($arr, function($a, $b) { return $a <=> $b; });
        $arr = array_reverse($arr);
        array_flip($arr);
        array_unique($arr);
        array_chunk($arr, 50);
        array_slice($arr, 100, 500);
        array_map(function($v) { return $v * 2 + 1; }, $arr);
        array_filter($arr, function($v) { return $v % 3 === 0; });
        array_reduce($arr, function($carry, $v) { return $carry + $v; }, 0);
        array_search(1500, $arr);
        in_array(2000, $arr);
        array_count_values($arr);
        array_unique($arr);
        array_merge($arr, range(3001, 4000));
        array_combine(array_slice($arr, 0, 100), array_slice($arr, 0, 100));
        $matrix = [];
        for ($i = 0; $i < 100; $i++) {
            $row = [];
            for ($j = 0; $j < 100; $j++) {
                $row[] = mt_rand(1, 1000);
            }
            $matrix[] = $row;
        }
        for ($i = 0; $i < 100; $i++) {
            for ($j = 0; $j < 100; $j++) {
                $matrix[$i][$j] *= 2;
                $matrix[$i][$j] += $matrix[($i + 1) % 100][$j];
            }
        }
        $tree = [];
        for ($i = 0; $i < 1000; $i++) {
            $node = ["id" => $i, "children" => [], "data" => random_bytes(64)];
            $parent = $i > 0 ? intdiv($i - 1, 2) : 0;
            if (isset($tree[$parent])) {
                $tree[$parent]["children"][] = $i;
            }
            $tree[$i] = $node;
        }
        $visited = [];
        $stack = [0];
        while (!empty($stack)) {
            $nodeId = array_pop($stack);
            $visited[$nodeId] = true;
            if (isset($tree[$nodeId]["children"])) {
                foreach ($tree[$nodeId]["children"] as $child) {
                    if (!isset($visited[$child])) {
                        $stack[] = $child;
                    }
                }
            }
        }
        $state = 0;
        for ($i = 0; $i < 10000; $i++) {
            match ($state) {
                0 => $state = 1,
                1 => $state = 2,
                2 => $state = 3,
                3 => $state = 0,
                default => $state = 0,
            };
        }
        $list = range(1, 2000);
        $result = [];
        $even = array_filter($list, fn($x) => $x % 2 === 0);
        $odd = array_filter($list, fn($x) => $x % 2 !== 0);
        array_walk($even, function(&$v) { $v *= 3; });
        $chunked = array_chunk($list, 100);
        array_map(function($chunk) { return array_sum($chunk); }, $chunked);
    }
    echo "opcode OK\n";
    '
}

for workload in "${WORKLOADS[@]}"; do
    current=$((current + 1))
    print_progress "$workload" "$current" "$total"
    start_time=$(date +%s)
    case "$workload" in
        igbinary_serialization)   igbinary_serialization ;;
        zlib_compression)         zlib_compression ;;
        hashing)                  hashing ;;
        leveldb_simulation)       leveldb_simulation ;;
        string_operations)        string_operations ;;
        math_operations)          math_operations ;;
        json_operations)          json_operations ;;
        file_io)                  file_io ;;
        opcode_heavy_loops)       opcode_heavy_loops ;;
    esac
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    echo "  Completed in ${elapsed}s"
done

echo ""
echo "=== PGO training complete ==="
echo "Total workloads run: $total"
