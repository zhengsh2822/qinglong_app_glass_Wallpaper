package com.qlapp.qinglong_app

import android.os.SystemClock
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.Executors

/**
 * 独立时间校准模块（思路参考「时间精确校准」模块的 chrony 方案）
 *
 * 悬浮窗时间不再跟随系统时间（系统时间可能被手动修改或自动校时不准确），
 * 而是通过 SNTP 从多个 NTP 服务器独立取时：
 * - 多源冗余：阿里云 / 腾讯云 / 国家授时中心 / Cloudflare / Google，结果取中位数抗抖动
 * - 往返校正：标准 SNTP 算法，用单调时钟测量往返延迟抵消网络延迟
 * - 单调维持：校准后记录「校准绝对时间 + 校准时刻单调时钟」，之后用
 *   SystemClock.elapsedRealtime() 流逝推导当前校准时间 → 系统时间被改动不会影响悬浮窗显示
 * - 周期校准：由 MainActivity 定时触发（默认 30 分钟一次），避免长时间累计漂移
 */
object NtpTimeSync {
    // 多源 NTP 服务器（与 chrony.conf 的 pool/server 对应）
    private val NTP_SERVERS = arrayOf(
        "ntp.aliyun.com",
        "ntp.tencent.com",
        "cn.pool.ntp.org",
        "time.cloudflare.com",
        "time.google.com"
    )
    private const val NTP_PORT = 123
    private const val SNTP_TIMEOUT_MS = 4000
    // NTP 纪元 1900-01-01 到 Unix 纪元 1970-01-01 的秒差
    private const val NTP_EPOCH_OFFSET = 2208988800L
    // 合理偏移上限：单日以内视为可信，超出（服务器异常/应答伪造）丢弃
    private const val MAX_TRUSTED_OFFSET_MS = 24L * 3600 * 1000

    private val executor = Executors.newCachedThreadPool()

    // 校准基准：校准时刻的 NTP 绝对时间（epoch 毫秒）与该时刻的单调时钟（毫秒）
    @Volatile private var refNtpTimeMs = 0L
    @Volatile private var refElapsedMs = 0L
    // 最近一次校准偏移量（NTP - 系统时间，毫秒）与校准时刻（系统 epoch 毫秒）
    @Volatile private var lastOffsetMs = 0L
    @Volatile private var lastCalibratedAtMs = 0L
    @Volatile private var calibrating = false
    @Volatile private var calibrated = false

    /** 是否已有一次成功的独立校准 */
    val isCalibrated: Boolean get() = calibrated

    /** 最近一次偏移量（毫秒，NTP - 系统时间；0 表示尚未校准） */
    val lastOffset: Long get() = lastOffsetMs

    /** 最后校准时刻（系统 epoch 毫秒），0 表示从未校准 */
    val lastCalibratedAt: Long get() = lastCalibratedAtMs

    /** 独立校准时间（epoch 毫秒）= 校准绝对时间 + 单调时钟流逝 */
    fun now(): Long {
        val refNtp = refNtpTimeMs
        val refElapsed = refElapsedMs
        if (refNtp > 0 && refElapsed > 0) {
            return refNtp + (SystemClock.elapsedRealtime() - refElapsed)
        }
        // 尚未校准：退回系统时间，避免悬浮窗无时间显示（校准完成后自动跳变）
        return System.currentTimeMillis()
    }

    /** 触发一次异步校准（多源 SNTP 并发取时，取中位数；成功则更新校准基准） */
    fun calibrate(callback: (() -> Unit)? = null) {
        if (calibrating) return
        calibrating = true
        executor.execute {
            try {
                val offsets = java.util.concurrent.CopyOnWriteArrayList<Long>()
                val threads = NTP_SERVERS.map { host ->
                    Thread {
                        sntpOffset(host)?.let { offsets.add(it) }
                    }
                }
                threads.forEach { it.start() }
                threads.forEach { it.join(SNTP_TIMEOUT_MS + 1500L) }
                if (offsets.isNotEmpty()) {
                    offsets.sort()
                    // 取中位数，抗单个异常服务器导致的偏移抖动
                    applyOffset(offsets[offsets.size / 2])
                }
            } finally {
                calibrating = false
                callback?.invoke()
            }
        }
    }

    private fun applyOffset(offsetMs: Long) {
        if (kotlin.math.abs(offsetMs) > MAX_TRUSTED_OFFSET_MS) return
        val nowElapsed = SystemClock.elapsedRealtime()
        val nowSystem = System.currentTimeMillis()
        refNtpTimeMs = nowSystem + offsetMs
        refElapsedMs = nowElapsed
        lastOffsetMs = offsetMs
        lastCalibratedAtMs = nowSystem
        calibrated = true
    }

    /**
     * 对单个 NTP 服务器做一次 SNTP 往返校正。
     * 返回 offset（NTP 绝对时间 - 本地系统时间，毫秒）；失败返回 null。
     */
    private fun sntpOffset(host: String): Long? {
        var socket: DatagramSocket? = null
        return try {
            socket = DatagramSocket()
            socket.soTimeout = SNTP_TIMEOUT_MS
            val address = InetAddress.getByName(host)
            val buffer = ByteArray(48)
            // LI=0 VN=3 Mode=3（client）
            buffer[0] = 0x1B.toByte()
            // transmit timestamp 填本地系统时间（NTP 格式）
            writeNtpTimestamp(buffer, 40, System.currentTimeMillis() / 1000.0)
            val sendTicks = SystemClock.elapsedRealtime()
            socket.send(DatagramPacket(buffer, 48, address, NTP_PORT))
            val response = DatagramPacket(ByteArray(48), 48)
            socket.receive(response)
            val recvTicks = SystemClock.elapsedRealtime()
            val data = response.data
            val originate = readNtpTimestamp(data, 24) // 服务器回显我们发送的 transmit
            val receive = readNtpTimestamp(data, 32)
            val transmit = readNtpTimestamp(data, 40)
            // 本地发送/接收时刻（unix 秒）：用单调时钟差值换算，避免系统时间被改导致往返失真
            val nowSec = System.currentTimeMillis() / 1000.0
            val rttMs = recvTicks - sendTicks
            val sendSec = nowSec - rttMs / 1000.0
            val recvSec = nowSec
            // 标准 SNTP 偏移：offset = ((receive - send) + (transmit - recv)) / 2
            val offsetSec = ((receive - sendSec) + (transmit - recvSec)) / 2.0
            if (offsetSec.isFinite() && kotlin.math.abs(offsetSec) < 24 * 3600) {
                (offsetSec * 1000).toLong()
            } else {
                null
            }
        } catch (e: Exception) {
            null
        } finally {
            socket?.close()
        }
    }

    // ===== NTP 64 位时间戳（1900 纪元，32 位秒 + 32 位小数）读写 =====

    private fun writeNtpTimestamp(buffer: ByteArray, offset: Int, unixSeconds: Double) {
        val ntpSeconds = unixSeconds + NTP_EPOCH_OFFSET
        val intPart = ntpSeconds.toLong()
        val fracPart = ((ntpSeconds - intPart) * 4294967296.0).toLong()
        writeUInt32(buffer, offset, intPart)
        writeUInt32(buffer, offset + 4, fracPart)
    }

    private fun readNtpTimestamp(buffer: ByteArray, offset: Int): Double {
        val allZero = (0 until 8).all {
            buffer[offset + it] == 0.toByte()
        }
        if (allZero) return 0.0
        val intPart = readUInt32(buffer, offset)
        val fracPart = readUInt32(buffer, offset + 4)
        return intPart + fracPart / 4294967296.0 - NTP_EPOCH_OFFSET
    }

    private fun writeUInt32(buffer: ByteArray, offset: Int, value: Long) {
        buffer[offset] = (value ushr 24).toByte()
        buffer[offset + 1] = (value ushr 16).toByte()
        buffer[offset + 2] = (value ushr 8).toByte()
        buffer[offset + 3] = value.toByte()
    }

    private fun readUInt32(buffer: ByteArray, offset: Int): Long {
        return ((buffer[offset].toLong() and 0xFF) shl 24) or
                ((buffer[offset + 1].toLong() and 0xFF) shl 16) or
                ((buffer[offset + 2].toLong() and 0xFF) shl 8) or
                (buffer[offset + 3].toLong() and 0xFF)
    }
}
