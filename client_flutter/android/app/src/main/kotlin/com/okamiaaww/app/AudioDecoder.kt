package com.okamiaaww.app

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder

object AudioDecoder {
    private const val TAG = "AudioDecoder"
    
    // RAM Cache to store the last decoded song to prevent redundant decoding
    private var cachedFilePath: String? = null
    private var cachedTargetSampleRate: Int = -1
    private var cachedPcmData: FloatArray? = null

    private fun cacheKeyFor(filePath: String, targetSampleRate: Int): String {
        // filePath can be a raw URL (http://...) which contains '/' and ':'
        // characters that are invalid/dangerous as a single filename — using
        // it directly caused every disk-cache write for network sources to
        // fail (tried to write into non-existent nested directories).
        val digest = java.security.MessageDigest.getInstance("MD5")
            .digest(filePath.toByteArray())
        val hash = digest.joinToString("") { "%02x".format(it) }
        return "$hash.$targetSampleRate.pcm"
    }

    @Synchronized
    fun decodeFileToPcmFloat(filePath: String, targetSampleRate: Int): FloatArray? {
        if (filePath == cachedFilePath && targetSampleRate == cachedTargetSampleRate && cachedPcmData != null) {
            Log.i(TAG, "Returning decoded PCM from RAM cache for: $filePath")
            return cachedPcmData
        }

        // Disk caching only makes sense for local files: we cache next to the
        // source file's own directory (proven writable, same as before) and
        // skip disk caching entirely for network URLs — the RAM cache still
        // covers repeat plays within the same session.
        val isNetworkUrl = filePath.startsWith("http://") || filePath.startsWith("https://")
        val pcmFile = if (!isNetworkUrl) {
            val parentDir = java.io.File(filePath).parentFile
            if (parentDir != null) java.io.File(parentDir, cacheKeyFor(filePath, targetSampleRate)) else null
        } else {
            null
        }
        if (pcmFile != null && pcmFile.exists() && pcmFile.length() > 0) {
            try {
                Log.i(TAG, "Loading decoded PCM from Disk Cache: ${pcmFile.absolutePath}")
                val raf = java.io.RandomAccessFile(pcmFile, "r")
                val channel = raf.channel
                val mappedByteBuffer = channel.map(java.nio.channels.FileChannel.MapMode.READ_ONLY, 0, channel.size())
                mappedByteBuffer.order(ByteOrder.nativeOrder())
                val floatBuffer = mappedByteBuffer.asFloatBuffer()
                val result = FloatArray(floatBuffer.remaining())
                floatBuffer.get(result)
                channel.close()
                raf.close()
                
                cachedFilePath = filePath
                cachedTargetSampleRate = targetSampleRate
                cachedPcmData = result
                return result
            } catch (e: Exception) {
                Log.e(TAG, "Failed to read from disk cache, re-decoding...", e)
            }
        }

        val extractor = MediaExtractor()
        try {
            Log.i(TAG, "Decoding file path: $filePath")
            if (filePath.startsWith("http://") || filePath.startsWith("https://")) {
                Log.i(TAG, "Using network URL for extractor")
                extractor.setDataSource(filePath, null)
            } else {
                Log.i(TAG, "Using local file for extractor")
                val fis = java.io.FileInputStream(java.io.File(filePath))
                extractor.setDataSource(fis.fd)
                fis.close()
            }
            var audioTrackIndex = -1
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME)
                Log.i(TAG, "Track $i mime: $mime")
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    format = f
                    break
                }
            }
            if (audioTrackIndex == -1 || format == null) {
                Log.e(TAG, "No audio track found for: $filePath")
                return null
            }
            extractor.selectTrack(audioTrackIndex)

            val mime = format.getString(MediaFormat.KEY_MIME) ?: return null
            Log.i(TAG, "Creating decoder for mime: $mime")
            val codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            
            
            val info = MediaCodec.BufferInfo()
            var isEOS = false
            var outputEOS = false

            var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val durationUs = format.getLong(MediaFormat.KEY_DURATION)
            
            // Estimate size and pre-allocate
            val estimatedMonoSamples = ((durationUs / 1000000.0) * sampleRate).toInt()
            var finalBuffer = FloatArray(estimatedMonoSamples + (estimatedMonoSamples / 5)) // +20% buffer
            var writePos = 0
            var reusableShortArray = ShortArray(65536)

            while (!outputEOS) {
                if (!isEOS) {
                    val inputIndex = codec.dequeueInputBuffer(10000)
                    if (inputIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputIndex)
                        if (inputBuffer != null) {
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                isEOS = true
                            } else {
                                val presentationTimeUs = extractor.sampleTime
                                codec.queueInputBuffer(inputIndex, 0, sampleSize, presentationTimeUs, 0)
                                extractor.advance()
                            }
                        }
                    }
                }

                val outputIndex = codec.dequeueOutputBuffer(info, 10000)
                if (outputIndex >= 0) {
                    val outputBuffer = codec.getOutputBuffer(outputIndex)
                    if (outputBuffer != null) {
                        val formatOutput = codec.outputFormat
                        sampleRate = formatOutput.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channelCount = formatOutput.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        
                        outputBuffer.position(info.offset)
                        outputBuffer.limit(info.offset + info.size)
                        
                        val shortBuffer = outputBuffer.order(ByteOrder.nativeOrder()).asShortBuffer()
                        val remaining = shortBuffer.remaining()
                        val frames = remaining / channelCount
                        
                        if (writePos + frames > finalBuffer.size) {
                            val newBuf = FloatArray(finalBuffer.size * 2 + frames)
                            System.arraycopy(finalBuffer, 0, newBuf, 0, writePos)
                            finalBuffer = newBuf
                        }
                        
                        if (reusableShortArray.size < remaining) {
                            reusableShortArray = ShortArray(remaining * 2)
                        }
                        shortBuffer.get(reusableShortArray, 0, remaining)
                        
                        if (channelCount == 2) {
                            for (i in 0 until frames) {
                                val l = reusableShortArray[i * 2].toFloat() / 32768f
                                val r = reusableShortArray[i * 2 + 1].toFloat() / 32768f
                                finalBuffer[writePos++] = (l + r) * 0.5f
                            }
                        } else {
                            for (i in 0 until frames) {
                                finalBuffer[writePos++] = reusableShortArray[i].toFloat() / 32768f
                            }
                        }
                    }
                    codec.releaseOutputBuffer(outputIndex, false)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputEOS = true
                    }
                } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    // format changed
                }
            }
            codec.stop()
            codec.release()
            extractor.release()

            // Trim array to actual size
            val exactBuffer = FloatArray(writePos)
            System.arraycopy(finalBuffer, 0, exactBuffer, 0, writePos)

            // Resample if needed
            val finalData = if (sampleRate != targetSampleRate && targetSampleRate > 0) {
                resample(exactBuffer, sampleRate, targetSampleRate)
            } else {
                exactBuffer
            }
            
            // Store in RAM cache
            cachedFilePath = filePath
            cachedTargetSampleRate = targetSampleRate
            cachedPcmData = finalData
            
            // Save to Disk Cache (local files only — see pcmFile above)
            if (pcmFile != null) {
                try {
                    Log.i(TAG, "Saving decoded PCM to Disk Cache: ${pcmFile.absolutePath}")
                    val raf = java.io.RandomAccessFile(pcmFile, "rw")
                    val channel = raf.channel
                    val bytes = finalData.size * 4L
                    val mappedByteBuffer = channel.map(java.nio.channels.FileChannel.MapMode.READ_WRITE, 0, bytes)
                    mappedByteBuffer.order(ByteOrder.nativeOrder())
                    mappedByteBuffer.asFloatBuffer().put(finalData)
                    channel.close()
                    raf.close()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to save to disk cache", e)
                }
            }
            
            return finalData

        } catch (e: Exception) {
            Log.e(TAG, "Error decoding file", e)
            return null
        }
    }
    
    private fun resample(input: FloatArray, inputSampleRate: Int, targetSampleRate: Int): FloatArray {
        if (inputSampleRate == targetSampleRate) return input
        val ratio = inputSampleRate.toDouble() / targetSampleRate.toDouble()
        val outLength = (input.size / ratio).toInt()
        val output = FloatArray(outLength)
        val inSize = input.size
        for (i in 0 until outLength) {
            val inIndex = i * ratio
            val indexInt = inIndex.toInt()
            val frac = (inIndex - indexInt).toFloat()
            val s1 = if (indexInt < inSize) input[indexInt] else 0f
            val s2 = if (indexInt + 1 < inSize) input[indexInt + 1] else 0f
            output[i] = s1 + (s2 - s1) * frac
        }
        return output
    }
}
