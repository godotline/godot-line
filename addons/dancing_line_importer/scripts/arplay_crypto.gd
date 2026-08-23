@tool
extends RefCounted
class_name ArplayCrypto

## 用法：
##   ArplayCrypto.readLevel(path)              # 读取并解析为关卡 JSON Dictionary
##   ArplayCrypto.extract(path [, outDir])     # 落盘提取 Resources/{Meshes,Sprites,Scripts}

## 内置派生参数（enc/mask 成对，还原算法见 _unmask）
const _E1: String = "e58871db8637ebc9db86511563f460b3e48314"
const _E2: String = "84d74ecc6df24c46b0d77d1a823ac23f"
const _E3: String = "265f5c6032502c80e39eb80290"
const _E4: String = "7e1972609fb1820e9cd39b0163c5a87a"

const _ITERATIONS: int = 1000
const _DK_LEN: int = 48
const PNG_MAGIC_HEX: String = "89504e470d0a1a0a"

## 派生参数缓存（迭代开销较大）
static var _cachedKeys: Dictionary = {}


# ==================== 公共 API ====================

## 读取 .arplay 并解析为关卡 JSON（失败返回空 Dictionary）
static func readLevel(arplayPath: String) -> Dictionary:
	var raw := readLevelBytes(arplayPath)
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("ArplayCrypto: 提取完成但内容不是合法的关卡 JSON：%s" % arplayPath)
	return {}


## 读取原始字节：返回 gzip 还原后的内容字节（即关卡 JSON 原文），失败返回空数组
static func readLevelBytes(arplayPath: String) -> PackedByteArray:
	var file := FileAccess.open(arplayPath, FileAccess.READ)
	if file == null:
		push_error("ArplayCrypto: 无法读取文件 %s（错误 %d）。" % [arplayPath, FileAccess.get_open_error()])
		return PackedByteArray()
	var cipher := file.get_buffer(file.get_length())
	file.close()

	if cipher.size() < 32 or cipher.size() % 16 != 0:
		push_error("ArplayCrypto: 文件大小不符合分块对齐要求：%s（%d 字节）" % [arplayPath, cipher.size()])
		return PackedByteArray()

	var keys := _deriveKeys()
	var keyBytes: PackedByteArray = keys["key"]
	var ivBytes: PackedByteArray = keys["iv"]
	var ctx := AESContext.new()
	var err: Error = ctx.start(AESContext.MODE_CBC_DECRYPT, keyBytes, ivBytes)
	if err != OK:
		push_error("ArplayCrypto: 数据上下文启动失败（错误 %d）。" % err)
		return PackedByteArray()
	var plain := ctx.update(cipher)
	ctx.finish()

	return _inflate(_stripPkcs7(plain))


## 落盘提取：向 outDir 写出 {Meshes,Sprites,Scripts}，并在其上一级目录写出
## level.arplay.json；outDir 为空时默认 <arplay 所在目录>/Resources（产物仍在原文件夹）。
## 失败返回空 Dictionary，成功返回 { data, counts, baseDir, jsonPath }。
static func extract(arplayPath: String, outDir: String = "") -> Dictionary:
	var data := readLevel(arplayPath)
	if data.is_empty():
		return {}

	var baseDir := outDir if not outDir.is_empty() else arplayPath.get_base_dir().path_join("Resources")
	var counts: Dictionary = {}
	_writeAssets(baseDir, "Meshes", data.get("meshes", []) as Array, "fileName", false, counts)
	_writeAssets(baseDir, "Sprites", data.get("sprites", []) as Array, "fileName", true, counts)
	_writeAssets(baseDir, "Scripts", data.get("scripts", []) as Array, "path", false, counts)

	return { "data": data, "counts": counts, "baseDir": baseDir }


# ==================== 提取落盘 ====================

## 将资产数组写出到 baseDir/subDir；sprite 内容为 base64，其余为 UTF-8 文本
static func _writeAssets(baseDir: String, subDir: String, items: Array, nameKey: String, isBase64: bool, counts: Dictionary) -> void:
	var dir: String = baseDir.path_join(subDir)
	DirAccess.make_dir_recursive_absolute(dir)
	var written: int = 0
	for rawItem: Variant in items:
		if not rawItem is Dictionary:
			continue
		var item: Dictionary = rawItem as Dictionary

		var fileName: String = str(item.get(nameKey, ""))
		if fileName.is_empty():
			fileName = "script_%d.lua" % _toIntSafe(item.get("id", 0))

		var blob := PackedByteArray()
		if isBase64:
			blob = Marshalls.base64_to_raw(str(item.get("content", "")))
			if blob.is_empty():
				push_warning("ArplayCrypto: 资源 '%s' 的 base64 内容无效，已跳过。" % fileName)
				continue
			if blob.slice(0, 8).hex_encode() != PNG_MAGIC_HEX:
				push_warning("ArplayCrypto: 贴图 '%s' 不是 PNG 格式（magic=%s）。" % [fileName, blob.slice(0, 8).hex_encode()])
		else:
			blob = str(item.get("content", "")).to_utf8_buffer()

		var path: String = dir.path_join(_sanitize(fileName))
		var assetFile := FileAccess.open(path, FileAccess.WRITE)
		if assetFile == null:
			push_warning("ArplayCrypto: 无法写出 %s，已跳过。" % path)
			continue
		assetFile.store_buffer(blob)
		assetFile.close()
		written += 1
	counts[subDir] = written


static func _sanitize(name: String) -> String:
	var cleaned := name.replace("/", "_").replace("\\", "_").strip_edges()
	return cleaned if not cleaned.is_empty() else "unnamed"


# ==================== 参数派生 ====================

## 内置常量还原：plain[i] = enc[i] ^ mask[i % mask.size()] ^ ((i*31+17) & 0xFF)
static func _unmask(encHex: String, maskHex: String) -> PackedByteArray:
	var enc := encHex.hex_decode()
	var mask := maskHex.hex_decode()
	var out := PackedByteArray()
	out.resize(enc.size())
	for i: int in enc.size():
		out[i] = enc[i] ^ mask[i % mask.size()] ^ ((i * 31 + 17) & 0xFF)
	return out


static func _deriveKeys() -> Dictionary:
	if not _cachedKeys.is_empty():
		return _cachedKeys
	var dk := _pbkdf2HmacSha1(_unmask(_E1, _E2), _unmask(_E3, _E4), _ITERATIONS, _DK_LEN)
	_cachedKeys = {
		"key": dk.slice(0, 32),
		"iv": dk.slice(32, 48),
	}
	return _cachedKeys


## PBKDF2-HMAC-SHA1（RFC 2898）；引擎无内置 PBKDF2，基于 Crypto.hmac_digest 迭代构造
static func _pbkdf2HmacSha1(secret: PackedByteArray, seed: PackedByteArray, iterations: int, dkLen: int) -> PackedByteArray:
	var crypto := Crypto.new()
	var dk := PackedByteArray()
	var block: int = 1
	while dk.size() < dkLen:
		var msg := seed.duplicate()
		msg.append((block >> 24) & 0xFF)
		msg.append((block >> 16) & 0xFF)
		msg.append((block >> 8) & 0xFF)
		msg.append(block & 0xFF)
		var acc: PackedByteArray = crypto.hmac_digest(HashingContext.HASH_SHA1, secret, msg)
		var u := acc.duplicate()
		for _i: int in iterations - 1:
			u = crypto.hmac_digest(HashingContext.HASH_SHA1, secret, u)
			for j: int in u.size():
				acc[j] ^= u[j]
		dk.append_array(acc)
		block += 1
	return dk.slice(0, dkLen)

## 剥离 PKCS#7 填充（填充非法时原样返回，交由 gzip 阶段容错忽略尾部字节）
static func _stripPkcs7(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return data
	var pad: int = data[data.size() - 1]
	if pad < 1 or pad > 16 or pad > data.size():
		return data
	for i: int in pad:
		if data[data.size() - 1 - i] != pad:
			return data
	return data.slice(0, data.size() - pad)


## gzip 解压；优先动态解压到流末尾即止（容忍尾部残留的填充字节），
## 回退按 gzip 尾部 ISIZE 字段整体解压
static func _inflate(data: PackedByteArray) -> PackedByteArray:
	if data.size() < 18 or data[0] != 0x1F or data[1] != 0x8B:
		push_error("ArplayCrypto: 提取结果不是 gzip 流（头部异常），内置参数可能不正确。")
		return PackedByteArray()
	var plain := data.decompress_dynamic(1 << 30, FileAccess.COMPRESSION_GZIP)
	if plain.is_empty():
		plain = data.decompress(data.decode_u32(data.size() - 4), FileAccess.COMPRESSION_GZIP)
	if plain.is_empty():
		push_error("ArplayCrypto: gzip 解压失败。")
	return plain


static func _toIntSafe(value: Variant) -> int:
	if value is float:
		return int(value)
	if value is int:
		return value
	if value is String:
		var text := value as String
		return text.to_int() if text.is_valid_int() else -1
	return -1
